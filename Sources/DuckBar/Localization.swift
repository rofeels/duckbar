import Foundation

// MARK: - Localized Strings

enum L {
    /// UserDefaults에서 직접 읽어 actor isolation 불필요
    static var lang: AppLanguage {
        if let raw = UserDefaults.standard.string(forKey: "language"),
           let lang = AppLanguage(rawValue: raw) {
            return lang
        }
        let preferred = Locale.preferredLanguages.first ?? ""
        return preferred.hasPrefix("ko") ? .korean : .english
    }

    // Header
    static var appTitle: String { "DuckBar" }
    static var refresh: String { lang == .korean ? "새로고침" : "Refresh" }

    // Empty state
    static var noActiveSessions: String { lang == .korean ? "활성 세션 없음" : "No active sessions" }

    // Session states
    static func stateLabel(_ state: SessionState) -> String {
        switch (state, lang) {
        case (.active, .korean): "활성"
        case (.active, .english): "Active"
        case (.waiting, .korean): "대기"
        case (.waiting, .english): "Waiting"
        case (.idle, .korean): "유휴"
        case (.idle, .english): "Idle"
        case (.compacting, .korean): "압축"
        case (.compacting, .english): "Compacting"
        }
    }

    // Time
    static var justNow: String { lang == .korean ? "방금" : "just now" }
    static func secondsAgo(_ s: Int) -> String { lang == .korean ? "\(s)초 전" : "\(s)s ago" }
    static func minutesAgo(_ m: Int) -> String { lang == .korean ? "\(m)분 전" : "\(m)m ago" }
    static func hoursAgo(_ h: Int) -> String { lang == .korean ? "\(h)시간 전" : "\(h)h ago" }

    // Sections
    static var rateLimits: String { lang == .korean ? "사용 한도" : "Rate Limits" }
    static var fiveHourWindow: String { lang == .korean ? "5시간" : "5h Window" }
    static var oneWeekWindow: String { lang == .korean ? "1주일" : "1w Window" }
    static var context: String { lang == .korean ? "컨텍스트" : "Context" }
    static var cacheHit: String { lang == .korean ? "캐시 적중" : "Cache Hit" }
    static var requests: String { lang == .korean ? "요청" : "reqs" }
    static var weekly: String { lang == .korean ? "주간" : "weekly" }
    static var monthly: String { lang == .korean ? "월간" : "monthly" }
    static var extraUsageDisabled: String { lang == .korean ? "추가 사용량 미사용" : "not enabled" }

    // Token labels
    static var tokenIn: String { "In" }
    static var tokenOut: String { "Out" }
    static var tokenCacheWrite: String { "C.Wr" }
    static var tokenCacheRead: String { "C.Rd" }

    // Model usage
    static var modelUsage: String { lang == .korean ? "모델별 사용량" : "Model Usage" }
    static var noData: String { "—" }
    static var tools: String { lang == .korean ? "도구" : "Tools" }
    static var popoverSize: String { lang == .korean ? "팝오버 크기" : "Popover Size" }

    // Menu
    static var settings: String { lang == .korean ? "설정" : "Settings" }
    static var quit: String { lang == .korean ? "종료" : "Quit" }

    // Context menu
    static var about: String { lang == .korean ? "앱 정보" : "About" }
    static var help: String { lang == .korean ? "도움말" : "Help" }

    // Settings view
    static var language: String { lang == .korean ? "언어" : "Language" }
    static var statusBarDisplay: String { lang == .korean ? "상태바 표시 항목" : "Status Bar Display" }
    static var done: String { lang == .korean ? "완료" : "Done" }
    static var launchAtLogin: String { lang == .korean ? "시스템 시작 시 실행" : "Launch at Login" }
    static var refreshInterval: String { lang == .korean ? "데이터 갱신 주기" : "Refresh Interval" }
    static var hotkey: String { lang == .korean ? "단축키" : "Hotkey" }
    static var hotkeyRecord: String { lang == .korean ? "키를 누르세요..." : "Press a key..." }

    // Chart
    static var tokenChart: String { lang == .korean ? "토큰 (24시간)" : "Tokens (24h)" }
    static var costChart: String { lang == .korean ? "비용 (24시간)" : "Cost (24h)" }
    static var chart: String { lang == .korean ? "차트" : "Chart" }
    static var chartTabLine: String { lang == .korean ? "라인" : "Line" }
    static var chartTabHeatmap: String { lang == .korean ? "히트맵" : "Heatmap" }
    static var defaultChartView: String { lang == .korean ? "기본 차트 뷰" : "Default Chart View" }
    static var chartExpandedByDefault: String { lang == .korean ? "차트 항상 펼치기" : "Always Expand Chart" }
    static var visibleSections: String { lang == .korean ? "표시할 섹션" : "Visible Sections" }
    static var chartHeatmap: String { lang == .korean ? "활동 히트맵 (7일)" : "Activity Heatmap (7d)" }
    static var heatmapLess: String { lang == .korean ? "적음" : "Less" }
    static var heatmapMore: String { lang == .korean ? "많음" : "More" }

    // Settings (inline 로컬라이제이션 통합)
    // Badges / 뱃지
    static var badges: String { lang == .korean ? "뱃지" : "Badges" }
    static var badgesShareCard: String { lang == .korean ? "뱃지 공유 카드" : "Badge Card" }
    static var badgeNotAchieved: String { lang == .korean ? "미달성" : "Locked" }
    static var badgeCategoryDailyPeak: String { lang == .korean ? "일간 최고 기록" : "Daily Peak" }
    static var badgeCategoryStreak: String { lang == .korean ? "연속 사용" : "Streak" }
    static var badgeCategoryTotalCost: String { lang == .korean ? "누적 비용" : "Total Cost" }
    static var badgeShareCardTitle: String { lang == .korean ? "DuckBar 뱃지" : "DuckBar Badges" }
    static var badgeStatTotalTokens: String { lang == .korean ? "누적 토큰" : "Total Tokens" }
    static var badgeStatTotalCost: String { lang == .korean ? "누적 비용" : "Total Cost" }
    static var badgeStatStreak: String { lang == .korean ? "연속 사용" : "Streak" }
    static func badgeStreakDays(_ n: Int) -> String { lang == .korean ? "\(n)일" : "\(n)d" }

    static var checkForUpdates: String { lang == .korean ? "업데이트 확인..." : "Check for Updates..." }
    static var copyShareCard: String { lang == .korean ? "공유 카드 복사" : "Copy Share Card" }
    static var shareCardPreview: String { lang == .korean ? "공유 카드 미리보기..." : "Share Card Preview..." }
    static var shareCardCopy: String { lang == .korean ? "클립보드에 복사" : "Copy to Clipboard" }
    static var shareCardCopied: String { lang == .korean ? "복사됨!" : "Copied!" }
    static var shareCardSave: String { lang == .korean ? "PNG로 저장" : "Save as PNG" }
    static var shareCardSaved: String { lang == .korean ? "저장됨!" : "Saved!" }
    static var provider: String { lang == .korean ? "데이터 소스" : "Data Source" }
    static var history: String { lang == .korean ? "알림" : "Alerts" }
    static var historyClear: String { lang == .korean ? "지우기" : "Clear" }
    static var historyEmpty: String { lang == .korean ? "알림 내역이 없습니다" : "No notifications yet" }
    static var usageAlerts: String { lang == .korean ? "사용량 알림" : "Usage Alerts" }
    static var usageAlertsHint: String { lang == .korean ? "0 입력 시 해당 알림 비활성화" : "Set to 0 to disable that alert" }
    static var automaticUpdateCheck: String { lang == .korean ? "자동 업데이트 확인" : "Check for Updates Automatically" }
    static var automaticUpdateInstall: String { lang == .korean ? "업데이트 자동 설치" : "Automatically Install Updates" }
    static var setHotkey: String { lang == .korean ? "설정" : "Set" }
    static var showDaysFormat: String { lang == .korean ? "24시간 이상 시 일(d)로 표시" : "Show days when over 24h" }
    static var sizeSmall: String { lang == .korean ? "작게" : "Small" }
    static var sizeMedium: String { lang == .korean ? "보통" : "Medium" }
    static var sizeLarge: String { lang == .korean ? "크게" : "Large" }
    static var interval1s: String { lang == .korean ? "1초" : "1s" }
    static var interval3s: String { lang == .korean ? "3초" : "3s" }
    static var interval5s: String { lang == .korean ? "5초" : "5s" }
    static var interval10s: String { lang == .korean ? "10초" : "10s" }
    static var interval30s: String { lang == .korean ? "30초" : "30s" }
    static var interval1m: String { lang == .korean ? "1분" : "1m" }
    static var interval3m: String { lang == .korean ? "3분" : "3m" }
    static var interval5m: String { lang == .korean ? "5분" : "5m" }
    static var menuBarIcon: String { lang == .korean ? "메뉴바 아이콘" : "Menu Bar Icon" }
    static var iconDuckFeet: String { lang == .korean ? "오리발" : "Duck Feet" }
    static var iconDuck: String { lang == .korean ? "오리" : "Duck" }
    static var iconClaude: String { lang == .korean ? "클로드" : "Claude" }
    static var iconRubberDuck: String { lang == .korean ? "고무오리" : "Rubber Duck" }
    static var iconTerminal: String { lang == .korean ? "터미널" : "Terminal" }
    static var iconSlime: String { lang == .korean ? "슬라임" : "Slime" }
}

// MARK: - Notification Names

extension Notification.Name {
    static let hotkeyChanged = Notification.Name("HotkeyChanged")
    static let hotkeyRecorded = Notification.Name("HotkeyRecorded")
    static let startRecordingHotkey = Notification.Name("StartRecordingHotkey")
    static let stopRecordingHotkey = Notification.Name("StopRecordingHotkey")
    static let openSettings = Notification.Name("OpenSettings")
    static let openHelp = Notification.Name("OpenHelp")
    static let openShareCard = Notification.Name("OpenShareCard")
    static let automaticUpdateCheckChanged = Notification.Name("AutomaticUpdateCheckChanged")
    static let automaticUpdateInstallChanged = Notification.Name("AutomaticUpdateInstallChanged")
    static let menuBarIconStyleChanged = Notification.Name("MenuBarIconStyleChanged")
}
