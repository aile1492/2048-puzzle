# 시스템 아키텍처 문서

**프로젝트**: 2048 Puzzle
**엔진**: Godot 4.6.1 (GDScript)
**대상 플랫폼**: Android (모바일 세로 1080x1920)
**문서 작성일**: 2026-03-23
**역방향 엔지니어링 기준 파일**: scripts/autoload/*, scripts/ui/base_screen.gd, scripts/game/grid_*.gd, scripts/utils/tile_colors.gd

---

## 1. 시스템 개요

전체 아키텍처는 세 개의 계층으로 나뉜다.

- **오토로드 계층**: 씬 트리 최상단에 항상 존재하는 싱글톤 매니저들
- **화면 계층**: ScreenManager가 관리하는 3-레이어 네비게이션
- **게임 로직 계층**: GridLogic(순수 데이터) + GridBoard(비주얼)의 분리 구조

```
=====================================================================
                     AUTOLOAD SINGLETONS (9개)
=====================================================================

  GameManager        SaveManager        AudioManager
  (게임 상태/모드)    (JSON 영속성)       (SFX 풀)

  CoinManager        ThemeManager       ScreenManager
  (코인 경제)         (테마/색상)         (3-레이어 네비)

  PowerUpManager     AdManager          AnalyticsManager
  (파워업 인벤토리)   (광고 미통합)       (분석 미통합)

=====================================================================
                     SCENE TREE (런타임)
=====================================================================

  main_scene.tscn
  └── CanvasLayer: TabLayer      (z=0, 홈 화면 고정)
  │   └── HomeScreen (BaseScreen)
  │
  ├── CanvasLayer: PushLayer     (z=1, 스택 네비게이션)
  │   └── [동적 생성] GameScreen, SettingsScreen, ShopScreen ...
  │
  └── CanvasLayer: PopupLayer    (z=2, 팝업 오버레이)
      └── [동적 생성] PausePopup, GameOverPopup ...

=====================================================================
                     GAME LOGIC (GameScreen 내부)
=====================================================================

  GridBoard (Control)                  GridLogic (RefCounted)
  ├── _grid_logic: GridLogic    ──-->  ├── grid: Array[Array]
  ├── _tiles: Dictionary               ├── score: int
  ├── _empty_cells: Array              ├── history: Array (undo 스택)
  ├── InputHandler                     └── RNG: RandomNumberGenerator
  └── TileScene (x N)

  GridBoard 는 GridLogic 의 시그널을 구독하여
  애니메이션·사운드·햅틱을 처리한다.

=====================================================================
                     UTILITY (정적)
=====================================================================

  TileColors (static)
  ├── LIGHT_TILE_COLORS / DARK_TILE_COLORS (타일 256종)
  └── LIGHT_UI / DARK_UI (UI 팔레트 15종)
```

---

## 2. 오토로드 싱글톤

프로젝트는 9개의 오토로드를 `project.godot`에 선언 순서대로 로드한다.
아래 의존 관계에서 화살표 방향은 "의존한다(호출한다)"를 의미한다.

```
PowerUpManager ──> AdManager
PowerUpManager ──> CoinManager
PowerUpManager ──> SaveManager
PowerUpManager ──> DailySeed (별도 유틸)

AudioManager   ──> SaveManager
ThemeManager   ──> SaveManager
CoinManager    ──> SaveManager
GameManager    ──> (독립)
ScreenManager  ──> (독립, BaseScreen 인터페이스만 사용)
```

### 2.1 GameManager

| 항목 | 내용 |
|------|------|
| 파일 | `scripts/autoload/game_manager.gd` |
| 역할 | 게임 FSM 상태 관리, 현재 모드/그리드 크기/실행 취소 횟수 보유 |
| 상속 | `Node` |

**공개 API**

```gdscript
enum GameState { IDLE, PLAYING, PAUSED, GAME_OVER, WIN, CONTINUE }
enum GameMode  { CLASSIC, BOARD_SIZES, TIME_ATTACK, MOVE_LIMIT,
                 DAILY_CHALLENGE, ZEN, DROP }

var current_state: int
var current_mode: int
var current_grid_size: int
var undo_remaining: int
var continue_used: bool

signal state_changed(new_state: StringName)

func set_state(new_state: int) -> void
func start_game(mode: int, grid_size: int) -> void
func request_undo() -> bool        # ZEN 모드는 무제한
func request_continue() -> bool    # 한 게임당 1회만 허용
```

**상태 전이**

```
IDLE ──start_game()──> PLAYING ──game_over──> GAME_OVER
                              └──game_won──>  WIN
                              └──pause()──>   PAUSED
GAME_OVER ──request_continue()──> CONTINUE ──> PLAYING
```

---

### 2.2 SaveManager

| 항목 | 내용 |
|------|------|
| 파일 | `scripts/autoload/save_manager.gd` |
| 역할 | JSON 파일 저장/로드, 섹션 기반 Key-Value 접근, 백업 파일 유지 |
| 상속 | `Node` |

**공개 API**

```gdscript
signal data_loaded
signal data_saved

const SAVE_PATH:   String = "user://save_data.json"
const BACKUP_PATH: String = "user://save_data.backup.json"

func get_value(section: String, key: String, default: Variant) -> Variant
func set_value(section: String, key: String, value: Variant) -> void
func get_section(section: String) -> Dictionary
func set_section(section: String, value: Dictionary) -> void
func get_data() -> Dictionary
```

**저장 파일 섹션 구조**

| 섹션 | 주요 키 |
|------|---------|
| `settings` | theme, sound, vibration, animation_speed, language |
| `stats` | total_games, best_score_3x3~6x6, highest_tile, current_streak |
| `progress` | level, coins, unlocked_themes, daily_streak |
| `current_game` | 진행 중인 게임 스냅샷 (GridLogic.to_dict()) |
| `powerups` | hammer/shuffle/bomb 수량 및 오늘 광고 사용 횟수 |
| `ad_state` | games_since_interstitial, continue_used_this_game |

**자동 저장 트리거**: `NOTIFICATION_APPLICATION_FOCUS_OUT`, `NOTIFICATION_WM_CLOSE_REQUEST`

---

### 2.3 AudioManager

| 항목 | 내용 |
|------|------|
| 파일 | `scripts/autoload/audio_manager.gd` |
| 역할 | Round-robin SFX 풀(8개 AudioStreamPlayer) 관리 |
| 상속 | `Node` |

**공개 API**

```gdscript
const SFX_POOL_SIZE: int = 8
const SFX_BASE: String = "res://assets/audio/sfx/"

func play_sfx(sfx_name: String, pitch: float = 1.0) -> void
func set_volume(value: int) -> void    # 0-100, 저장됨
func get_volume() -> int
func set_sound_enabled(enabled: bool) -> void
func is_sound_enabled() -> bool
```

사용되는 SFX 이름: `tile_slide`, `tile_spawn`, `merge_small`, `merge_medium`, `merge_large`, `undo`

---

### 2.4 ThemeManager

| 항목 | 내용 |
|------|------|
| 파일 | `scripts/autoload/theme_manager.gd` |
| 역할 | 현재 테마 ID 관리, 테마 변경 시그널 발신 |
| 상속 | `Node` |

**공개 API**

```gdscript
var current_theme: String  # "light" 또는 확장 테마 ID

signal theme_changed(theme_id: String)

func set_theme(theme_id: String) -> void
func is_dark() -> bool   # current_theme != "light"
```

UI 색상 접근 패턴: `TileColors.get_ui_colors(ThemeManager.is_dark())`

---

### 2.5 CoinManager

| 항목 | 내용 |
|------|------|
| 파일 | `scripts/autoload/coin_manager.gd` |
| 역할 | 코인 잔액 관리, 획득/소비 처리 |
| 상속 | `Node` |

**공개 API**

```gdscript
signal coins_changed(new_amount: int)

func get_coins() -> int
func add_coins(amount: int) -> void
func spend_coins(amount: int) -> bool   # 잔액 부족 시 false
```

---

### 2.6 PowerUpManager

| 항목 | 내용 |
|------|------|
| 파일 | `scripts/autoload/powerup_manager.gd` |
| 역할 | 파워업(Hammer/Shuffle/Bomb) 인벤토리, 코인 구매, 광고 획득 |
| 상속 | `Node` |

**공개 API**

```gdscript
const COSTS: Dictionary = {"hammer": 100, "shuffle": 150, "bomb": 200}
const AD_LIMIT_PER_DAY: int = 3

signal powerup_used(type: String)
signal powerup_count_changed(type: String, count: int)

func get_count(type: String) -> int
func use_powerup(type: String) -> bool
func add_powerup(type: String, amount: int) -> void
func purchase_with_coins(type: String) -> bool
func can_watch_ad(type: String) -> bool
func request_ad_powerup(type: String) -> void
func get_cost(type: String) -> int
func get_ad_uses_remaining(type: String) -> int
```

광고 콜백: `AdManager.rewarded_ad_completed` 시그널을 구독하여 `_on_rewarded_ad_completed` 처리.
디버그 플래그: `debug_unlimited = true` 시 인벤토리 수량을 99로 반환.

---

### 2.7 ScreenManager

자세한 내용은 3절 참조.

---

### 2.8 AdManager / AnalyticsManager

두 매니저는 현재 코드베이스에 플레이스홀더로 존재한다 (파일 확인 시 미구현).
PowerUpManager 및 GameManager에서 각각 참조되므로 인터페이스 스텁이 필요하다.

---

## 3. 화면 관리 시스템

### 3-레이어 네비게이션

```
CanvasLayer 계층 (z-index 순)
┌────────────────────────────────────────────────────────┐
│  PopupLayer  (z=2)  항상 최상단                         │
│  ┌──────────┐ ┌──────────┐                             │
│  │PausePopup│ │GameOver  │ ... (동적 생성/해제)          │
│  └──────────┘ └──────────┘                             │
├────────────────────────────────────────────────────────┤
│  PushLayer   (z=1)  화면 스택                           │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐               │
│  │GameScreen│ │Settings  │ │Shop      │ ...            │
│  └──────────┘ └──────────┘ └──────────┘               │
│  (스택 top만 visible)                                   │
├────────────────────────────────────────────────────────┤
│  TabLayer    (z=0)  홈 화면 고정                         │
│  ┌──────────────────────────────┐                      │
│  │  HomeScreen (항상 존재)       │                      │
│  │  (PushLayer 비어있을 때 표시) │                      │
│  └──────────────────────────────┘                      │
└────────────────────────────────────────────────────────┘
```

### 공개 API

```gdscript
func initialize(tab_layer, push_layer, popup_layer: CanvasLayer) -> void

# PushLayer 조작
func push_screen(scene_path: String, data: Dictionary) -> void
func pop_screen() -> void
func replace_screen(scene_path: String, data: Dictionary) -> void
func clear_push_stack() -> void

# PopupLayer 조작
func show_popup(scene_path: String, data: Dictionary) -> BaseScreen
func close_popup(popup: BaseScreen = null) -> void
func close_all_popups() -> void

# 상태 조회
func has_push_screens() -> bool
func has_popups() -> bool
```

### 화면 전환 흐름

```
push_screen() 호출
├── PushStack 비어있으면  HomeScreen.exit() + visible=false
├── PushStack 비어있지 않으면  현재_top.exit() + visible=false
├── scene_path 로드 및 인스턴스화
├── PushLayer.add_child(screen)
└── screen.enter(data)

pop_screen() 호출
├── top.exit() + queue_free()
├── 새 top 있으면  new_top.visible=true + enter()
└── 스택 비어있으면  HomeScreen.visible=true + enter()
```

`data: Dictionary` 매개변수를 통해 이전 화면에서 다음 화면으로 인자를 전달한다.

---

## 4. 게임 로직 분리

### 설계 원칙

2048 게임 로직은 두 클래스로 완전히 분리되어 있다.

| | GridLogic | GridBoard |
|--|-----------|-----------|
| 클래스 | `RefCounted` | `Control` |
| 역할 | 순수 게임 규칙 | 시각적 렌더링 + 입력 |
| 씬 의존성 | 없음 | 있음 |
| 단위 테스트 | 독립 가능 | 불가 |
| 시그널 발신 | tiles_moved, score_changed 등 | move_completed 등 |

### GridLogic 주요 구조

```gdscript
class_name GridLogic
extends RefCounted

# 상태
var grid: Array          # 2D [row][col], 0은 빈 칸
var grid_size: int       # 기본값 4
var score: int
var move_count: int
var highest_tile: int
var history: Array       # 최대 20개 undo 스냅샷

# 시그널
signal tiles_moved(movements: Array)   # Array[TileMovement]
signal tile_spawned(pos: Vector2i, value: int)
signal score_changed(new_score: int, gained: int)
signal game_over
signal game_won

# 핵심 메서드
func initialize(size: int, seed_value: int) -> void
func move(direction: int) -> Dictionary   # {moved, movements, score_gained, ...}
func undo() -> bool
func spawn_tile() -> Vector2i
func is_game_over() -> bool
func to_dict() -> Dictionary             # 직렬화 (세이브용)
func from_dict(data: Dictionary) -> void # 역직렬화 (로드용)

# 파워업
func remove_tile(pos: Vector2i) -> bool
func remove_area(pos: Vector2i) -> Array[Vector2i]
func shuffle_tiles() -> void
```

### GridBoard 주요 구조

```gdscript
extends Control

# 내부 소유
var _grid_logic: GridLogic           # 단독 소유, 외부 공유 없음
var _tiles: Dictionary               # Vector2i -> Tile 노드
var _input_handler: InputHandler     # 스와이프 감지
var _selection_mode: String          # "", "hammer", "bomb"

# 시그널 (상위 GameScreen 이 구독)
signal move_completed(score_gained: int)
signal board_game_over
signal board_game_won
signal animation_started
signal animation_finished
signal tile_selected(pos: Vector2i)  # 파워업 선택 모드

# 공개 API
func initialize(grid_size, board_width, input_handler, seed_value) -> void
func execute_move(direction: int) -> void
func undo() -> bool
func new_game(grid_size, seed_value) -> void
func restore_from_dict(data: Dictionary) -> void
func get_logic() -> GridLogic
func get_score() -> int
func get_highest_tile() -> int
func get_move_count() -> int
func refresh_theme() -> void

# 파워업 모드
func enter_selection_mode(type: String) -> void
func exit_selection_mode() -> void
func apply_hammer(pos: Vector2i) -> bool
func apply_bomb(pos: Vector2i) -> Array[Vector2i]
func apply_shuffle() -> void
```

---

## 5. 데이터 흐름

### 5.1 저장/로드 흐름

```
앱 시작
  └── SaveManager._ready()
        └── _load_data()
              ├── [성공] JSON 파싱 -> _data 채움 -> _ensure_defaults() -> data_loaded 발신
              ├── [실패] 백업 파일 시도 -> 동일 과정
              └── [신규] {} 초기화 -> _ensure_defaults() -> data_loaded 발신

런타임 읽기
  └── 예: ThemeManager._ready()
        └── SaveManager.get_value("settings", "theme", "light")

런타임 쓰기
  └── 예: ThemeManager.set_theme("dark")
        └── SaveManager.set_value("settings", "theme", "dark")
              └── _save_data()
                    ├── 기존 파일을 backup 경로로 복사
                    └── JSON 직렬화 후 SAVE_PATH 에 기록

앱 종료/백그라운드 전환
  └── SaveManager._notification()
        └── _save_data()
```

### 5.2 테마 변경 흐름

```
사용자가 테마 변경 버튼 클릭
  └── ThemeManager.set_theme("dark")
        ├── current_theme = "dark"
        ├── SaveManager.set_value("settings", "theme", "dark")
        └── theme_changed.emit("dark")
              ├── GameScreen._on_theme_changed()
              │     └── GridBoard.refresh_theme()
              │           ├── TileColors.get_ui_colors(true) 로 색상 갱신
              │           ├── _grid_bg.color = ui_colors["grid_bg"]
              │           ├── 빈 셀 색상 업데이트
              │           └── 각 타일 set_value() 재호출 -> 타일 색상 갱신
              └── 기타 화면들 자체 갱신
```

### 5.3 점수 업데이트 흐름

```
사용자 스와이프
  └── InputHandler.swipe_detected (시그널)
        └── GridBoard._on_swipe(direction)
              └── GridBoard.execute_move(direction)
                    └── GridLogic.move(direction)
                          ├── 타일 이동/병합 처리
                          ├── score += score_gained
                          └── score_changed.emit(score, gained)
                                └── [GridBoard는 이 시그널을 직접 구독하지 않음]

                    ├── Tween 애니메이션 시작
                    └── _on_slide_complete() 콜백
                          └── move_completed.emit(score_gained)
                                └── GameScreen._on_move_completed(score_gained)
                                      ├── 현재 점수 표시 업데이트
                                      └── (최고 점수 비교 후 SaveManager 갱신)
```

### 5.4 게임 종료 흐름

```
GridLogic.is_game_over() == true
  └── GridLogic.game_over.emit()
        └── GridBoard._on_game_over()
              └── GridBoard.board_game_over.emit()
                    └── GameScreen._on_board_game_over()
                          ├── GameManager.set_state(GameState.GAME_OVER)
                          ├── 통계 저장 (SaveManager)
                          └── ScreenManager.show_popup("GameOverPopup.tscn", {...})
```

### 5.5 게임 세이브/재개 흐름

```
게임 종료/백그라운드
  └── GameScreen이 GridBoard.get_logic().to_dict() 직렬화
        └── SaveManager.set_section("current_game", dict)

다음 실행 / 홈 화면 Resume 버튼
  └── SaveManager.get_section("current_game") 로 dict 복원
        └── GridBoard.restore_from_dict(dict)
              ├── GridLogic.from_dict(dict)
              └── 타일 노드 재생성
```

---

## 6. UI 구조

### 6.1 BaseScreen 패턴

모든 화면 스크립트는 `BaseScreen`을 상속받는다.

```gdscript
class_name BaseScreen
extends Control

func enter(data: Dictionary = {}) -> void:  # 화면 활성화 시 호출
    pass

func exit() -> void:                        # 화면 비활성화 시 호출
    pass
```

`enter()`와 `exit()`는 `_ready()`/`queue_free()`와 별개다.
팝업이나 푸시된 화면은 숨겨질 때 해제되지 않고 `exit()`만 호출되며, 다시 표시될 때 `enter()`가 재호출된다.

### 6.2 프로그래매틱 UI 구성 원칙

- `.tscn` 파일 없이 GDScript 코드로 UI 노드를 생성한다 (단, `tile.tscn`은 예외).
- 색상은 반드시 `TileColors.get_ui_colors(ThemeManager.is_dark())`를 통해 조회한다.
- 하드코딩된 색상 리터럴은 금지한다.

```gdscript
# 올바른 패턴
var ui_colors: Dictionary = TileColors.get_ui_colors(ThemeManager.is_dark())
label.modulate = ui_colors["header_text"]

# 잘못된 패턴 (금지)
label.modulate = Color("776E65")
```

### 6.3 화면 구조 예시 (GameScreen)

```
GameScreen (BaseScreen)
├── VBoxContainer
│   ├── HeaderRow
│   │   ├── LogoLabel ("2048")
│   │   └── ScoreBox
│   │       ├── ScoreLabel
│   │       └── BestLabel
│   ├── GridBoard (Control)
│   │   ├── GridBackground (ColorRect)
│   │   ├── EmptyCell × (grid_size²) (ColorRect)
│   │   └── Tile × N (tile.tscn 인스턴스)
│   └── PowerUpRow
│       ├── HammerButton
│       ├── ShuffleButton
│       └── BombButton
└── InputHandler (Node)
```

---

## 7. 시그널 맵

아래는 시스템 간 주요 시그널 연결 관계를 나타낸다.

```
발신자                     시그널                         수신자
─────────────────────────────────────────────────────────────────────

[오토로드]
GameManager          state_changed(new_state)       GameScreen (UI 업데이트)
ThemeManager         theme_changed(theme_id)        GridBoard.refresh_theme()
                                                    각 화면 UI 색상 갱신
CoinManager          coins_changed(new_amount)      ShopScreen, HUD 코인 표시
PowerUpManager       powerup_used(type)             GameScreen (파워업 UI 비활성화)
PowerUpManager       powerup_count_changed(t, c)    ShopScreen, 파워업 버튼 수량
SaveManager          data_loaded                    (초기화 완료 알림, 거의 미사용)
AdManager            rewarded_ad_completed(ad_type) PowerUpManager._on_rewarded_ad_completed()

[GridLogic -> GridBoard (내부)]
GridLogic            tiles_moved(movements)         (GridBoard 직접 처리, execute_move 내부)
GridLogic            tile_spawned(pos, value)       (GridBoard 직접 처리)
GridLogic            score_changed(score, gained)   (GridBoard 에서 외부 전파)
GridLogic            game_over                      GridBoard._on_game_over()
GridLogic            game_won                       GridBoard._on_game_won()

[GridBoard -> GameScreen]
GridBoard            move_completed(score_gained)   GameScreen 점수 업데이트
GridBoard            board_game_over                GameScreen 게임오버 팝업
GridBoard            board_game_won                 GameScreen 승리 팝업
GridBoard            animation_started              GameScreen (입력 잠금)
GridBoard            animation_finished             GameScreen (입력 해제)
GridBoard            tile_selected(pos)             GameScreen 파워업 적용

[InputHandler -> GridBoard]
InputHandler         swipe_detected(direction)      GridBoard._on_swipe()
```

---

## 8. 디렉토리 구조

```
/
├── project.godot                     # 엔진 설정, 오토로드 선언
├── default_bus_layout.tres           # 오디오 버스 (SFX)
│
├── scripts/
│   ├── autoload/                     # 오토로드 싱글톤 (9개)
│   │   ├── game_manager.gd
│   │   ├── save_manager.gd
│   │   ├── audio_manager.gd
│   │   ├── coin_manager.gd
│   │   ├── theme_manager.gd
│   │   ├── screen_manager.gd
│   │   ├── powerup_manager.gd
│   │   ├── ad_manager.gd
│   │   └── analytics_manager.gd
│   ├── game/                         # 게임 로직 및 보드
│   │   ├── grid_logic.gd             # 순수 데이터 (RefCounted)
│   │   └── grid_board.gd             # 비주얼/애니메이션 (Control)
│   ├── ui/                           # UI 공통 베이스
│   │   └── base_screen.gd
│   └── utils/                        # 정적 유틸리티
│       └── tile_colors.gd
│
├── scenes/
│   ├── main_scene.tscn               # 진입점 (3-레이어 CanvasLayer)
│   └── game/
│       └── tile.tscn                 # 타일 시각 컴포넌트
│
├── assets/
│   ├── audio/sfx/                    # .wav 파일 (tile_slide, tile_spawn, merge_*)
│   ├── icons/
│   │   └── icon_512.png
│   └── ...
│
├── docs/
│   └── architecture/                 # 아키텍처 결정 기록
│       └── system-architecture.md    # 이 문서
│
├── design/gdd/                       # 게임 디자인 문서
├── tests/                            # 단위/통합 테스트
└── production/
    ├── session-state/active.md       # 세션 상태 (gitignored)
    └── session-logs/                 # 세션 로그 (gitignored)
```

### 파일 배치 규칙

| 규칙 | 설명 |
|------|------|
| 오토로드는 `scripts/autoload/`에만 배치 | `project.godot` 선언 필수 |
| 게임 로직은 `scripts/game/`에 배치 | 비주얼 의존 없는 클래스는 `RefCounted` |
| UI 기반 클래스는 `scripts/ui/`에 배치 | 항상 `BaseScreen` 상속 |
| 정적 유틸은 `scripts/utils/`에 배치 | `class_name` 없어도 무방 |
| `.tscn` UI 파일 생성 금지 | 프로그래매틱 UI 방침 (tile.tscn 예외) |
| 색상 하드코딩 금지 | `TileColors` 통해서만 참조 |
| 세이브 직접 파일 접근 금지 | `SaveManager` API 경유 필수 |
| 오디오 직접 재생 금지 | `AudioManager.play_sfx()` 경유 필수 |

---

*이 문서는 소스 코드로부터 역방향 엔지니어링하여 작성되었습니다. 구현이 변경될 경우 이 문서도 함께 갱신해야 합니다.*
