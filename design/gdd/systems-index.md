# 시스템 인덱스 — 2048 퍼즐 게임

> 최종 갱신: 2026-03-23
> 대상 코드베이스: `scripts/` 전체 GDScript 파일 (총 37개)

---

## 1. 핵심 게임플레이 (Core Gameplay)

### 1.1 그리드 로직 (GridLogic)
- **담당 파일**: `scripts/game/grid_logic.gd`
- **핵심 기능**: 2048 게임의 순수 데이터 계층 — 타일 이동, 병합, 스폰, 승패 판정, 되돌리기(Undo)를 처리하는 RefCounted 클래스 (Node 미사용, 독립 테스트 가능)
- **의존하는 시스템**: 없음 (순수 데이터 클래스)
- **현재 상태**: 완성
- **우선순위**: 핵심

### 1.2 타일 이동 데이터 (TileMovement)
- **담당 파일**: `scripts/game/tile_movement.gd`
- **핵심 기능**: 한 번의 이동에서 단일 타일의 출발 위치, 도착 위치, 병합 여부를 담는 경량 데이터 클래스
- **의존하는 시스템**: 없음
- **현재 상태**: 완성
- **우선순위**: 핵심

### 1.3 그리드 보드 (GridBoard)
- **담당 파일**: `scripts/game/grid_board.gd`
- **핵심 기능**: GridLogic 위에 올라가는 시각 계층 — 타일 슬라이드/병합/스폰 애니메이션, 파워업 선택 모드, 테마 갱신을 담당하는 Control 노드
- **의존하는 시스템**: GridLogic, TileMovement, Tile, InputHandler, ThemeManager, TileColors, AudioManager, Haptics
- **현재 상태**: 완성
- **우선순위**: 핵심

### 1.4 타일 (Tile)
- **담당 파일**: `scripts/game/tile.gd`
- **핵심 기능**: 단일 타일의 배경색, 글자 크기, 스폰/병합 애니메이션을 처리하는 Control 노드
- **의존하는 시스템**: TileColors, ThemeManager
- **현재 상태**: 완성
- **우선순위**: 핵심

### 1.5 입력 핸들러 (InputHandler)
- **담당 파일**: `scripts/game/input_handler.gd`
- **핵심 기능**: 전체 화면 스와이프 제스처를 감지하고, 애니메이션 중 입력을 버퍼링하여 다음 이동에 반영
- **의존하는 시스템**: GridLogic (Direction 열거형 참조)
- **현재 상태**: 완성
- **우선순위**: 핵심

### 1.6 드롭 로직 (DropLogic)
- **담당 파일**: `scripts/game/drop_logic.gd`
- **핵심 기능**: Drop 모드 전용 순수 데이터 클래스 — 열(column)에 타일을 투하하고, 인접 동값 타일 연쇄 병합(BFS), 중력 적용 처리
- **의존하는 시스템**: 없음 (순수 데이터 클래스)
- **현재 상태**: 완성
- **우선순위**: 핵심

### 1.7 드롭 보드 (DropBoard)
- **담당 파일**: `scripts/game/drop_board.gd`
- **핵심 기능**: Drop 모드의 시각 보드 — 열 선택 하이라이트, 위험선(Danger Line), 타일 스폰 애니메이션, 터치 입력으로 열 선택 및 타일 투하 처리
- **의존하는 시스템**: DropLogic, Tile, ThemeManager, TileColors, AudioManager
- **현재 상태**: 완성
- **우선순위**: 핵심

---

## 2. 게임 모드 (Game Modes)

### 2.1 게임 매니저 (GameManager)
- **담당 파일**: `scripts/autoload/game_manager.gd`
- **핵심 기능**: 현재 게임 상태(IDLE/PLAYING/PAUSED/GAME_OVER/WIN/CONTINUE)와 게임 모드(CLASSIC/BOARD_SIZES/TIME_ATTACK/MOVE_LIMIT/DAILY_CHALLENGE/ZEN/DROP)를 관리하는 Autoload 싱글턴
- **의존하는 시스템**: 없음 (다른 시스템이 이 시스템에 의존)
- **현재 상태**: 완성
- **우선순위**: 핵심

### 2.2 게임 화면 (GameScreen)
- **담당 파일**: `scripts/ui/screens/game_screen.gd`
- **핵심 기능**: Classic/Zen/Time Attack/Daily Challenge/Board Sizes 모드의 메인 플레이 화면 — 헤더, 점수, 그리드, 파워업 바를 코드로 빌드하고 모든 게임 루프 이벤트를 조율
- **의존하는 시스템**: GridBoard, InputHandler, GameManager, SaveManager, ScreenManager, PowerUpManager, AudioManager, ThemeManager, TileColors, DailySeed, AnalyticsManager
- **현재 상태**: 완성
- **우선순위**: 핵심

### 2.3 드롭 게임 화면 (DropGameScreen)
- **담당 파일**: `scripts/ui/screens/drop_game_screen.gd`
- **핵심 기능**: Drop 모드 전용 플레이 화면 — NEXT 타일 미리보기, 투하 카운터, 타임 표시를 포함한 Drop 게임 루프 조율
- **의존하는 시스템**: DropBoard, GameManager, SaveManager, ScreenManager, AudioManager, ThemeManager, TileColors
- **현재 상태**: 완성
- **우선순위**: 핵심

### 2.4 일일 시드 (DailySeed)
- **담당 파일**: `scripts/utils/daily_seed.gd`
- **핵심 기능**: 날짜 기반 RNG 시드 생성 및 요일별 목표 점수(4000~7000) 산출 유틸리티 클래스
- **의존하는 시스템**: 없음 (정적 유틸리티)
- **현재 상태**: 완성
- **우선순위**: 핵심

### 2.5 모드 선택 화면 (ModeSelectScreen)
- **담당 파일**: `scripts/ui/screens/mode_select_screen.gd`
- **핵심 기능**: 7가지 게임 모드 카드를 표시하고, 승리 횟수/레벨 기반 잠금 해제 상태를 적용하여 모드 진입 처리
- **의존하는 시스템**: GameManager, SaveManager, ScreenManager, AudioManager, ThemeManager, TileColors
- **현재 상태**: 완성
- **우선순위**: 중요

---

## 3. 경제 / 진행 (Economy / Progression)

### 3.1 코인 매니저 (CoinManager)
- **담당 파일**: `scripts/autoload/coin_manager.gd`
- **핵심 기능**: 코인 잔액 관리 — 획득, 소비, 잔액 조회 및 변경 시그널 방출을 담당하는 Autoload 싱글턴
- **의존하는 시스템**: SaveManager
- **현재 상태**: 완성
- **우선순위**: 중요

### 3.2 파워업 매니저 (PowerUpManager)
- **담당 파일**: `scripts/autoload/powerup_manager.gd`
- **핵심 기능**: Hammer/Shuffle/Bomb 인벤토리 관리 — 코인 구매, 광고 시청 획득(일일 제한 3회), 사용 처리를 담당하는 Autoload 싱글턴
- **의존하는 시스템**: SaveManager, CoinManager, AdManager, DailySeed
- **현재 상태**: 완성
- **우선순위**: 중요

### 3.3 일일 챌린지 팝업 (DailyChallengePopup)
- **담당 파일**: `scripts/ui/popups/daily_challenge_popup.gd`
- **핵심 기능**: 일일 챌린지 시작 전 7일 캘린더, 연속 스트릭, 오늘의 보상 미리보기를 표시하는 팝업
- **의존하는 시스템**: SaveManager, DailySeed, ScreenManager, GameManager, AudioManager, ThemeManager, TileColors
- **현재 상태**: 완성
- **우선순위**: 중요

### 3.4 일일 결과 팝업 (DailyResultPopup)
- **담당 파일**: `scripts/ui/popups/daily_result_popup.gd`
- **핵심 기능**: 일일 챌린지 종료 후 결과(성공/실패), 스트릭 갱신, 코인/파워업 보상 지급을 처리하는 팝업
- **의존하는 시스템**: SaveManager, DailySeed, CoinManager, PowerUpManager, ScreenManager, AudioManager, ThemeManager, TileColors
- **현재 상태**: 완성
- **우선순위**: 중요

---

## 4. UI/UX

### 4.1 기본 화면 (BaseScreen)
- **담당 파일**: `scripts/ui/base_screen.gd`
- **핵심 기능**: 모든 화면 스크립트의 추상 기반 클래스 — `enter(data)` / `exit()` 라이프사이클 인터페이스를 정의
- **의존하는 시스템**: 없음 (다른 화면들이 상속)
- **현재 상태**: 완성
- **우선순위**: 핵심

### 4.2 화면 매니저 (ScreenManager)
- **담당 파일**: `scripts/autoload/screen_manager.gd`
- **핵심 기능**: TabLayer(홈) / PushLayer(화면 스택) / PopupLayer(팝업 스택) 3계층 내비게이션 시스템을 관리하는 Autoload 싱글턴
- **의존하는 시스템**: BaseScreen
- **현재 상태**: 완성
- **우선순위**: 핵심

### 4.3 메인 씬 (MainScene)
- **담당 파일**: `scripts/ui/main_scene.gd`
- **핵심 기능**: 루트 씬 — 3계층 CanvasLayer를 ScreenManager에 등록하고 스플래시 화면을 첫 화면으로 표시
- **의존하는 시스템**: ScreenManager
- **현재 상태**: 완성
- **우선순위**: 핵심

### 4.4 스플래시 화면 (SplashScreen)
- **담당 파일**: `scripts/ui/screens/splash_screen.gd`
- **핵심 기능**: 앱 시작 시 표시되는 1초 스플래시 — 저장된 게임이 있으면 이어하기로, 없으면 홈 화면으로 자동 분기
- **의존하는 시스템**: SaveManager, ScreenManager, ThemeManager, TileColors
- **현재 상태**: 완성
- **우선순위**: 중요

### 4.5 홈 화면 (HomeScreen)
- **담당 파일**: `scripts/ui/screens/home_screen.gd`
- **핵심 기능**: 메인 메뉴 — PLAY 버튼, Daily/Modes/Stats/Theme/Settings/Rank 단축 버튼, 최고 점수 및 코인 표시
- **의존하는 시스템**: SaveManager, CoinManager, ScreenManager, AudioManager, ThemeManager, TileColors
- **현재 상태**: 완성
- **우선순위**: 중요

### 4.6 통계 화면 (StatsScreen)
- **담당 파일**: `scripts/ui/screens/stats_screen.gd`
- **핵심 기능**: 총 게임 수, 승률, 최고 타일, 그리드 크기별 최고 점수, 플레이 시간, 일일 스트릭 등 누적 통계를 표시
- **의존하는 시스템**: SaveManager, ScreenManager, AudioManager, ThemeManager, TileColors
- **현재 상태**: 완성
- **우선순위**: 중요

### 4.7 설정 화면 (SettingsScreen)
- **담당 파일**: `scripts/ui/screens/settings_screen.gd`
- **핵심 기능**: 테마(Light/Dark) 전환, 음량 슬라이더, 애니메이션 속도 선택, 개발자 디버그 옵션(무한 파워업, 세이브 초기화)을 제공
- **의존하는 시스템**: ThemeManager, AudioManager, SaveManager, PowerUpManager, ScreenManager, TileColors
- **현재 상태**: 완성
- **우선순위**: 중요

### 4.8 파워업 바 (PowerupBar)
- **담당 파일**: `scripts/ui/components/powerup_bar.gd`
- **핵심 기능**: 게임 화면 하단의 Hammer/Shuffle/Bomb 버튼 컴포넌트 — 길게 누르면 정보 팝업, 짧게 누르면 파워업 사용 요청, 첫 사용자를 위한 맥동(Pulse) 애니메이션 포함
- **의존하는 시스템**: PowerUpManager, SaveManager, ScreenManager, AudioManager, ThemeManager, TileColors
- **현재 상태**: 완성
- **우선순위**: 중요

### 4.9 게임 오버 팝업 (GameOverPopup)
- **담당 파일**: `scripts/ui/popups/game_over_popup.gd`
- **핵심 기능**: 게임 종료 시 점수/최고 점수/최고 타일/플레이 시간을 표시하고, 광고 시청 후 이어하기 또는 다시 시작 선택 제공
- **의존하는 시스템**: GameManager, ScreenManager, AudioManager, ThemeManager, TileColors
- **현재 상태**: 미완성 (이어하기 버튼의 광고 시청 후 타일 제거 로직 미구현 — TODO Phase 7 주석)
- **우선순위**: 핵심

### 4.10 승리 팝업 (WinPopup)
- **담당 파일**: `scripts/ui/popups/win_popup.gd`
- **핵심 기능**: 2048 타일 달성 시 점수와 +200 코인 보상을 표시하고, "계속하기" 또는 홈 선택 제공
- **의존하는 시스템**: CoinManager, ScreenManager, AudioManager, ThemeManager, TileColors
- **현재 상태**: 버그있음 (계속하기 누를 때 GridBoard에 `continue_after_win()` 전달 경로가 불완전 — `_on_keep_going()`에서 보드 탐색 로직이 빈 상태)
- **우선순위**: 중요

### 4.11 일시정지 팝업 (PausePopup)
- **담당 파일**: `scripts/ui/popups/pause_popup.gd`
- **핵심 기능**: 게임 중 메뉴 버튼으로 열리는 일시정지 화면 — 재개/새 게임/설정/홈 버튼 제공, 진입/퇴장 시 GameManager 상태 자동 전환
- **의존하는 시스템**: GameManager, ScreenManager, AudioManager, ThemeManager, TileColors
- **현재 상태**: 완성
- **우선순위**: 중요

### 4.12 파워업 구매 팝업 (PowerupPurchasePopup)
- **담당 파일**: `scripts/ui/popups/powerup_purchase_popup.gd`
- **핵심 기능**: 파워업 재고가 0일 때 표시 — 코인 구매(비용 표시)와 광고 시청(일일 잔여 횟수 표시) 두 가지 획득 경로 제공
- **의존하는 시스템**: PowerUpManager, CoinManager, ScreenManager, AudioManager, ThemeManager, TileColors
- **현재 상태**: 완성
- **우선순위**: 중요

### 4.13 파워업 정보 팝업 (PowerupInfoPopup)
- **담당 파일**: `scripts/ui/popups/powerup_info_popup.gd`
- **핵심 기능**: 파워업 효과 범위를 3×3 격자 다이어그램으로 시각화하는 정보 카드 팝업 (길게 누르기로 호출, 한국어 설명)
- **의존하는 시스템**: ScreenManager, AudioManager, ThemeManager, TileColors
- **현재 상태**: 완성
- **우선순위**: 부가

### 4.14 확인 팝업 (ConfirmPopup)
- **담당 파일**: `scripts/ui/popups/confirm_popup.gd`
- **핵심 기능**: 범용 확인/취소 다이얼로그 — 제목, 메시지, 확인 버튼 텍스트 및 확인 콜백을 인자로 받아 재사용 가능
- **의존하는 시스템**: ScreenManager, AudioManager, ThemeManager, TileColors
- **현재 상태**: 완성
- **우선순위**: 중요

### 4.15 타일 색상 (TileColors)
- **담당 파일**: `scripts/utils/tile_colors.gd`
- **핵심 기능**: 원작 2048(gabriele cirulli) CSS 색상 값을 기반으로 타일 배경/텍스트 색상 및 UI 색상 딕셔너리를 제공하는 정적 유틸리티 클래스 (Light/Dark 모드)
- **의존하는 시스템**: 없음 (정적 유틸리티, ThemeManager가 사용)
- **현재 상태**: 완성
- **우선순위**: 핵심

### 4.16 테마 매니저 (ThemeManager)
- **담당 파일**: `scripts/autoload/theme_manager.gd`
- **핵심 기능**: 현재 테마(light/dark) 저장 및 변경 시그널 방출을 담당하는 Autoload 싱글턴
- **의존하는 시스템**: SaveManager
- **현재 상태**: 완성 (Phase 4에서 추가 테마 확장 예정 주석)
- **우선순위**: 중요

---

## 5. 인프라 (Infrastructure)

### 5.1 세이브 매니저 (SaveManager)
- **담당 파일**: `scripts/autoload/save_manager.gd`
- **핵심 기능**: JSON 저장/불러오기 — 섹션 기반 키-값 API, 자동 백업 파일 유지, 앱 포커스 상실 시 자동 저장을 제공하는 Autoload 싱글턴
- **의존하는 시스템**: 없음 (모든 Autoload가 의존)
- **현재 상태**: 완성
- **우선순위**: 핵심

### 5.2 오디오 매니저 (AudioManager)
- **담당 파일**: `scripts/autoload/audio_manager.gd`
- **핵심 기능**: AudioStreamPlayer 풀(8개)로 SFX를 재생하고, 볼륨 데시벨 변환 및 저장/복원을 담당하는 Autoload 싱글턴
- **의존하는 시스템**: SaveManager
- **현재 상태**: 완성 (WAV 파일 애셋이 실제로 존재해야 동작, 없으면 무음 처리)
- **우선순위**: 중요

### 5.3 햅틱 (Haptics)
- **담당 파일**: `scripts/utils/haptics.gd`
- **핵심 기능**: 모바일 진동 피드백 — light(20ms)/medium(40ms)/heavy(80ms)/success(150ms) 4단계 강도를 제공하는 정적 유틸리티
- **의존하는 시스템**: SaveManager (진동 설정 여부 확인)
- **현재 상태**: 완성
- **우선순위**: 부가

### 5.4 분석 매니저 (AnalyticsManager)
- **담당 파일**: `scripts/autoload/analytics_manager.gd`
- **핵심 기능**: 게임 시작/종료/승리 이벤트를 로깅하는 Autoload 싱글턴 (디버그 빌드에서 print, 모바일에서 Firebase 연동 예정)
- **의존하는 시스템**: 없음 (스텁 구현)
- **현재 상태**: 미완성 (Firebase 실제 연동 없는 스텁)
- **우선순위**: 부가

---

## 6. 수익화 (Monetization)

### 6.1 광고 매니저 (AdManager)
- **담당 파일**: `scripts/autoload/ad_manager.gd`
- **핵심 기능**: AdMob 배너/전면/보상형 광고를 관리하는 Autoload 싱글턴 (현재 스텁 — 보상형 광고는 즉시 완료 신호 방출)
- **의존하는 시스템**: 없음 (스텁 구현, Phase 7에서 실제 AdMob 플러그인 연동 예정)
- **현재 상태**: 미완성 (스텁 구현, 실제 AdMob SDK 미연동)
- **우선순위**: 중요

---

## 의존성 요약표

| 시스템 | 의존 대상 수 | 역방향 의존(피의존) 수 |
|---|---|---|
| SaveManager | 0 | 11 |
| ThemeManager | 1 (SaveManager) | 17 |
| TileColors | 0 | 18 |
| GameManager | 0 | 5 |
| ScreenManager | 1 (BaseScreen) | 12 |
| GridLogic | 0 | 2 (GridBoard, GameScreen) |
| DropLogic | 0 | 2 (DropBoard, DropGameScreen) |
| CoinManager | 1 (SaveManager) | 4 |
| AdManager | 0 | 1 (PowerUpManager) |
| PowerUpManager | 4 | 4 |
| AudioManager | 1 (SaveManager) | 15 |
| AnalyticsManager | 0 | 1 (GameScreen) |

---

## 현재 상태 요약

| 상태 | 시스템 수 | 시스템 목록 |
|---|---|---|
| 완성 | 22 | GridLogic, TileMovement, GridBoard, Tile, InputHandler, DropLogic, DropBoard, GameManager, GameScreen, DropGameScreen, DailySeed, ModeSelectScreen, CoinManager, PowerUpManager, DailyChallengePopup, DailyResultPopup, BaseScreen, ScreenManager, MainScene, SplashScreen, HomeScreen, StatsScreen, SettingsScreen, PowerupBar, PausePopup, PowerupPurchasePopup, PowerupInfoPopup, ConfirmPopup, TileColors, ThemeManager, SaveManager, AudioManager, Haptics |
| 미완성 | 3 | GameOverPopup (이어하기 광고 미구현), AnalyticsManager (Firebase 스텁), AdManager (AdMob 스텁) |
| 버그있음 | 1 | WinPopup (계속하기 시 GridBoard 연결 경로 불완전) |

---

## Phase 계획 참고

- **Phase 7**: AdManager 실제 AdMob SDK 연동 (`ad_manager.gd` 주석 참고)
- **Phase 4**: ThemeManager 추가 테마 확장 (`theme_manager.gd` 주석 참고)
- **미구현**: GameOverPopup의 보상형 광고 시청 후 하위 3개 타일 제거 로직
- **미구현**: WinPopup의 "계속하기" → GridBoard.continue_after_win() 전달 경로 수정 필요
