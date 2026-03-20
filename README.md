# DuckBar

macOS 메뉴바에서 Claude Code 세션을 실시간으로 모니터링하는 상태 앱입니다. 활성 세션, API 사용률, 토큰 소비, 컨텍스트 창 크기, 비용을 한눈에 확인할 수 있습니다.

![macOS 14+](https://img.shields.io/badge/macOS-14+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

> 🇺🇸 [English README](README.en.md)

## 스크린샷

![DuckBar](screenshot.png)

### 메뉴바
| 라이트모드 | 다크모드 |
|:-:|:-:|
| ![Menubar Light](screenshot_menubar_light.png) | ![Menubar Dark](screenshot_menubar_dark.png) |

### 팝오버
| 라이트모드 | 다크모드 |
|:-:|:-:|
| ![Light](screenshot_light.png) | ![Dark](screenshot_dark.png) |
| ![Light EN](screenshot_light_en.png) | ![Settings Dark](screenshot_settings_dark.png) |
| ![Settings Light](screenshot_settings_light.png) | ![Settings Light EN](screenshot_settings_light_en.png) |

## 요구 사항

- **macOS 14 (Sonoma)** 이상
- **Apple Silicon (arm64)** 및 **Intel (x86_64)** 모두 지원

## 설치

1. [최신 릴리스](https://github.com/rofeels/duckbar/releases/latest)에서 `DuckBar-x.x.x.zip` 다운로드
2. zip 압축 해제 후 `DuckBar.app`을 `/Applications` 폴더로 드래그
3. 처음 실행 시 우클릭 → 열기로 실행 (Gatekeeper 우회)

> 이후 업데이트는 앱 내 **우클릭 → 업데이트 확인...** 으로 자동 설치됩니다.

## 기능

### 메뉴바 아이콘 및 애니메이션
- **오리발 픽셀아트 아이콘** (7x18px): 귀여운 디자인으로 상태를 시각화
- **동적 걷기 애니메이션**: 활성 세션이 있을 때 오리발이 뒤뚱뒤뚱 걷습니다
- **상태별 색상 표시**: 활성(녹색), 대기(주황색), 컴팩팅(파란색), 유휴(회색)

### 세션 모니터링
- **Claude Code 세션 자동 감지**: 터미널, IDE(VS Code, Cursor, Xcode, Zed 등), iTerm2, Warp, WezTerm, Ghostty 지원
- **세션 상태 추적**: 활성(실시간 작업), 대기(최근 활동), 컴팩팅(캐시 정리), 유휴(비활성)
- **실시간 업데이트**: 파일 시스템 감시 + 폴링으로 즉각적인 상태 반영
- **세부 정보 표시**: 작업 디렉토리, 실행 시간, 마지막 활동, 사용 모델, 도구 호출 통계

### API 사용률 및 토큰 추적
- **5시간 사용률**: 5시간 내 API 호출 제한 사용 비율
- **1주 사용률**: 1주일 내 API 호출 제한 사용 비율
- **모델별 주간 제한** (선택): Opus, Sonnet 모델별 주간 사용률
- **5시간/1주 토큰 통계**: 입력, 출력, 캐시 생성, 캐시 읽기 토큰 분리 집계
- **토큰 포맷팅**: 1K, 1.2M 등 스케일 기준 자동 포맷
- **캐시 효율 분석**: 캐시 히트율(%) 시각화

### 비용 추적
- **5시간 및 1주일 추정 비용**: USD 기준 실시간 계산
- **쉼표 포맷팅**: $1,234.56 형식으로 명확한 표시
- **모델별 비용**: Opus, Sonnet, Haiku 모델 구분 계산

### 모델 사용량
- **모델별 토큰 집계**: Opus, Sonnet, Haiku 등 사용한 모델별 통계
- **비용 및 비율 표시**: 각 모델의 상대적 사용량 시각화

### 컨텍스트 창 모니터링
- **현재 사용량 추적**: 현재 세션의 입력 토큰 + 캐시 읽기 토큰
- **최대 컨텍스트 표시**: 모델별 최대 컨텍스트(200K 또는 1M 토큰)
- **사용률 진행 표시**: 시각적 진행률(%) 및 색상 코드(파란색→주황색→빨강색)

### 메뉴바 상태 텍스트
실시간으로 메뉴바에 다음 정보를 표시할 수 있습니다 (설정으로 커스터마이징):
- `5h 42%` - 5시간 사용률
- `1w 68%` - 1주 사용률
- `12.3K` - 5시간 토큰
- `1.2M` - 1주 토큰
- `$1.23` - 5시간 비용
- `$15.40` - 1주 비용
- `ctx 65%` - 컨텍스트 사용률

### 우클릭 컨텍스트 메뉴
- 새로고침: 즉시 데이터 갱신
- 설정: 팝오버 내 설정 화면 열기
- 정보: 앱 정보 표시
- 종료: 앱 종료

### 로그인 시 자동 실행
- **Launch at Login**: 시스템 설정(System Preferences)을 통한 공식 자동 시작 지원
- **ServiceManagement**: macOS 13+ 공식 API 사용

### 갱신 주기 설정
- **1초, 3초, 5초, 10초, 30초, 1분, 3분, 5분** 중 선택
- 세션 상태는 설정 주기로 폴링
- 토큰/사용률 데이터는 설정 주기의 6배(최소 30초)로 백그라운드 갱신

### 팝오버 자동 크기 조정
- **작게(Small)**: 340x500, 폰트 스케일 1.0x
- **보통(Medium)**: 400x580, 폰트 스케일 1.15x (기본값)
- **크게(Large)**: 460x660, 폰트 스케일 1.3x
- 콘텐츠 높이에 따라 자동 확장(최대값까지)

### 다크모드 지원
- **자동 동적 색상**: macOS 시스템 다크모드 변경에 따른 즉시 반영
- **아이콘 동적 색상**: 테마별 자동 색상 조정

### 다국어 지원
- **한국어**: 기본 언어 (시스템 언어 설정 기반)
- **영어**: 선택 가능
- 메뉴, 상태바, 팝오버, 설정 화면 모두 다국어 지원

## 설치 (Homebrew)

```bash
brew tap rofeels/duckbar https://github.com/rofeels/duckbar
brew install --cask duckbar
```

## 빌드 (개발자용)

```bash
git clone https://github.com/rofeels/duckbar.git
cd duckbar
./build.sh
cp -r .build/app/DuckBar.app /Applications/
```

## 기술 스택

| 기술 | 용도 |
|-----|------|
| **Swift 5.9** | 메인 프로그래밍 언어 |
| **SwiftUI** | UI 개발 |
| **AppKit** | 메뉴바 및 팝오버 관리 |
| **SPM** | 의존성 관리 |

## 의존성

- **[Sparkle](https://sparkle-project.org)**: 자동 업데이트
- **[HotKey](https://github.com/soffes/HotKey)**: 글로벌 핫키 (Carbon API)

## 구조

```
Sources/DuckBar/
├── AppDelegate.swift          # 메뉴바 아이콘, 애니메이션, 팝오버 관리
├── StatusMenuView.swift       # 팝오버 UI 및 데이터 표시
├── SettingsView.swift         # 설정 화면
├── AppSettings.swift          # 설정 모델 및 저장소
├── Models.swift               # 데이터 모델 (세션, 토큰, API 사용률 등)
├── SessionMonitor.swift       # 세션 모니터링 및 폴링
├── SessionDiscovery.swift     # Claude Code 세션 감지 및 통계 로드
└── Localization.swift         # 다국어 문자열 (기대되는 파일)

Resources/
├── Info.plist                 # 앱 메타데이터
└── AppIcon.icns               # 메뉴바 아이콘
```

## 사용 방법

### 기본 사용

1. 앱을 실행하면 메뉴바에 오리발 아이콘이 나타납니다
2. 아이콘을 클릭하면 팝오버가 열리고 세부 정보가 표시됩니다
3. 우클릭으로 새로고침, 설정, 종료 메뉴에 접근할 수 있습니다

### 설정

팝오버의 **설정** 버튼(톱니바퀴 아이콘)으로 진입:

- **언어**: 한국어 / English 선택
- **팝오버 크기**: 작게 / 보통 / 크게
- **로그인 시 자동 실행**: 토글로 활성화/비활성화
- **갱신 주기**: 1초 ~ 5분 선택
- **메뉴바 표시 항목**: 각 항목별로 활성화/비활성화 및 미리보기

### 새로고침

- 팝오버 헤더의 **새로고침** 버튼(화살표 아이콘) 클릭
- 우클릭 메뉴 > **새로고침**
- 자동 백그라운드 갱신은 설정한 주기로 동작

## 라이선스

MIT License — [LICENSE](LICENSE) 참조

## 지원

문제가 발생하면:

1. 앱을 재시작해보세요
2. **설정 > 갱신 주기**를 확인하세요
3. **설정 > 로그인 시 자동 실행** 토글을 확인하세요
4. Claude Code(`~/.claude` 디렉토리)가 올바르게 설치되어 있는지 확인하세요

## 개발

### 개발 환경 설정

```bash
# 소스 다운로드
git clone <repo-url>
cd duckbar

# 의존성 확인 (필요 없음 - SPM 자동 처리)

# 개발 빌드
swift build

# 디버그 실행
swift run DuckBar
```

### 코드 스타일

- Swift 표준 스타일 준수
- `@MainActor` / `@Observable` 메크로 활용
- 간결한 에러 핸들링

## 알려진 제한사항

- Claude Code 세션이 없으면 "세션 없음" 상태 표시
- 오래된 세션은 자동으로 정리됩니다
- 네트워크 지연으로 인해 API 사용률이 지연될 수 있습니다 (최대 5분 캐시)
