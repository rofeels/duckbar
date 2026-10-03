import Foundation
import Observation
import ServiceManagement

// MARK: - Language

enum AppLanguage: String, CaseIterable, Codable {
    case korean = "ko"
    case english = "en"

    var displayName: String {
        switch self {
        case .korean: "한국어"
        case .english: "English"
        }
    }
}

// MARK: - Popover Size

enum PopoverSize: String, CaseIterable, Codable {
    case small
    case medium
    case large

    var displayName: String {
        switch self {
        case .small: L.sizeSmall
        case .medium: L.sizeMedium
        case .large: L.sizeLarge
        }
    }

    var width: CGFloat {
        switch self {
        case .small: 340
        case .medium: 400
        case .large: 460
        }
    }

    var height: CGFloat {
        switch self {
        case .small: 500
        case .medium: 580
        case .large: 660
        }
    }

    var fontScale: CGFloat {
        switch self {
        case .small: 1.0
        case .medium: 1.15
        case .large: 1.3
        }
    }
}

// MARK: - Refresh Interval

enum RefreshInterval: Double, CaseIterable, Codable {
    case one = 1.0
    case three = 3.0
    case five = 5.0
    case ten = 10.0
    case thirty = 30.0
    case sixty = 60.0
    case oneEighty = 180.0
    case threeHundred = 300.0

    var displayName: String {
        switch self {
        case .one: L.interval1s
        case .three: L.interval3s
        case .five: L.interval5s
        case .ten: L.interval10s
        case .thirty: L.interval30s
        case .sixty: L.interval1m
        case .oneEighty: L.interval3m
        case .threeHundred: L.interval5m
        }
    }
}

// MARK: - Status Bar Display Items

enum StatusBarItem: String, CaseIterable, Codable, Identifiable {
    case rateLimit        // 5h 사용률
    case weeklyRateLimit  // 1w 사용률
    case tokens           // 5h 토큰
    case weeklyTokens     // 1w 토큰
    case cost             // 5h 비용
    case weeklyCost       // 1w 비용
    case context          // 컨텍스트 사용률
    case extraUsage       // 추가 사용량

    var id: String { rawValue }

    func label(_ lang: AppLanguage) -> String {
        switch (self, lang) {
        case (.rateLimit, .korean): "5시간 사용률"
        case (.rateLimit, .english): "5h Rate"
        case (.weeklyRateLimit, .korean): "1주 사용률"
        case (.weeklyRateLimit, .english): "1w Rate"
        case (.tokens, .korean): "5시간 토큰"
        case (.tokens, .english): "5h Tokens"
        case (.weeklyTokens, .korean): "1주 토큰"
        case (.weeklyTokens, .english): "1w Tokens"
        case (.cost, .korean): "5시간 비용"
        case (.cost, .english): "5h Cost"
        case (.weeklyCost, .korean): "1주 비용"
        case (.weeklyCost, .english): "1w Cost"
        case (.context, .korean): "컨텍스트"
        case (.context, .english): "Context"
        case (.extraUsage, .korean): "추가 사용량"
        case (.extraUsage, .english): "Extra Usage"
        }
    }
}

// MARK: - Main Section Visibility

enum MainSection: String, CaseIterable, Codable, Identifiable {
    case rateLimits
    case fiveHourTokens
    case oneWeekTokens
    case chart
    case modelUsage
    case context

    var id: String { rawValue }

    func label(_ lang: AppLanguage) -> String {
        switch (self, lang) {
        case (.rateLimits, .korean): "사용 한도"
        case (.rateLimits, .english): "Rate Limits"
        case (.fiveHourTokens, .korean): "5시간 토큰"
        case (.fiveHourTokens, .english): "5h Tokens"
        case (.oneWeekTokens, .korean): "1주일 토큰"
        case (.oneWeekTokens, .english): "1w Tokens"
        case (.chart, .korean): "차트"
        case (.chart, .english): "Chart"
        case (.modelUsage, .korean): "모델별 사용량"
        case (.modelUsage, .english): "Model Usage"
        case (.context, .korean): "컨텍스트"
        case (.context, .english): "Context"
        }
    }
}

// MARK: - Settings

@Observable
@MainActor
final class AppSettings {
    static let shared = AppSettings()

    var language: AppLanguage {
        didSet { save() }
    }

    var statusBarItems: Set<StatusBarItem> {
        didSet { save() }
    }

    var popoverSize: PopoverSize {
        didSet { save() }
    }

    var refreshInterval: RefreshInterval {
        didSet { save() }
    }

    var hotkeyCode: UInt16 {
        didSet { save() }
    }

    var hotkeyModifiers: UInt {
        didSet { save() }
    }

    var launchAtLogin: Bool {
        didSet {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                launchAtLogin = oldValue
            }
        }
    }

    var defaultChartTab: String {
        didSet { save() }
    }

    var chartExpandedByDefault: Bool {
        didSet { save() }
    }

    var visibleSections: Set<MainSection> {
        didSet { save() }
    }

    var automaticUpdateCheck: Bool {
        didSet {
            save()
            NotificationCenter.default.post(name: .automaticUpdateCheckChanged, object: nil)
        }
    }

    var automaticUpdateInstall: Bool {
        didSet {
            save()
            NotificationCenter.default.post(name: .automaticUpdateInstallChanged, object: nil)
        }
    }

    var usageAlertsEnabled: Bool {
        didSet { save() }
    }

    var activeProvider: Provider {
        didSet { save() }
    }

    var alertThreshold1: Double {
        didSet { save() }
    }
    var alertThreshold2: Double {
        didSet { save() }
    }
    var alertThreshold3: Double {
        didSet { save() }
    }

    var showDaysFormat: Bool {
        didSet { save() }
    }

    var menuBarIconStyle: MenuBarIconStyle {
        didSet {
            save()
            NotificationCenter.default.post(name: .menuBarIconStyleChanged, object: nil)
        }
    }

    private let defaults = UserDefaults.standard

    private init() {
        if let raw = defaults.string(forKey: "language"),
           let lang = AppLanguage(rawValue: raw) {
            language = lang
        } else {
            let preferred = Locale.preferredLanguages.first ?? ""
            language = preferred.hasPrefix("ko") ? .korean : .english
        }

        if let data = defaults.data(forKey: "statusBarItems"),
           let items = try? JSONDecoder().decode([StatusBarItem].self, from: data) {
            statusBarItems = Set(items)
        } else {
            statusBarItems = []
        }

        if let raw = defaults.string(forKey: "popoverSize"),
           let size = PopoverSize(rawValue: raw) {
            popoverSize = size
        } else {
            popoverSize = .medium
        }

        if let raw = defaults.string(forKey: "refreshInterval"),
           let interval = RefreshInterval(rawValue: Double(raw) ?? 5.0) {
            refreshInterval = interval
        } else {
            refreshInterval = .five
        }

        if let raw = defaults.object(forKey: "hotkeyCode") as? Int {
            hotkeyCode = UInt16(raw)
        } else {
            hotkeyCode = 0  // 미설정
        }

        if let raw = defaults.object(forKey: "hotkeyModifiers") as? UInt {
            hotkeyModifiers = raw
        } else {
            hotkeyModifiers = 0
        }

        launchAtLogin = SMAppService.mainApp.status == .enabled

        defaultChartTab = defaults.string(forKey: "defaultChartTab") ?? "line"
        chartExpandedByDefault = defaults.object(forKey: "chartExpandedByDefault") as? Bool ?? false

        if let data = defaults.data(forKey: "visibleSections"),
           let sections = try? JSONDecoder().decode([MainSection].self, from: data) {
            visibleSections = Set(sections)
        } else {
            visibleSections = Set(MainSection.allCases)
        }
        automaticUpdateCheck = defaults.object(forKey: "automaticUpdateCheck") as? Bool ?? true
        automaticUpdateInstall = defaults.object(forKey: "automaticUpdateInstall") as? Bool ?? false
        usageAlertsEnabled = defaults.object(forKey: "usageAlertsEnabled") as? Bool ?? true
        if let raw = defaults.string(forKey: "activeProvider"), let p = Provider(rawValue: raw) {
            activeProvider = p
        } else {
            activeProvider = .claude
        }
        alertThreshold1 = defaults.object(forKey: "alertThreshold1") as? Double ?? 50
        alertThreshold2 = defaults.object(forKey: "alertThreshold2") as? Double ?? 80
        alertThreshold3 = defaults.object(forKey: "alertThreshold3") as? Double ?? 90
        showDaysFormat = defaults.object(forKey: "showDaysFormat") as? Bool ?? false
        menuBarIconStyle = defaults.string(forKey: "menuBarIconStyle").flatMap(MenuBarIconStyle.init(rawValue:)) ?? .duckFeet
    }

    private func save() {
        defaults.set(language.rawValue, forKey: "language")
        if let data = try? JSONEncoder().encode(Array(statusBarItems)) {
            defaults.set(data, forKey: "statusBarItems")
        }
        defaults.set(popoverSize.rawValue, forKey: "popoverSize")
        defaults.set(String(refreshInterval.rawValue), forKey: "refreshInterval")
        defaults.set(Int(hotkeyCode), forKey: "hotkeyCode")
        defaults.set(hotkeyModifiers, forKey: "hotkeyModifiers")
        defaults.set(defaultChartTab, forKey: "defaultChartTab")
        defaults.set(chartExpandedByDefault, forKey: "chartExpandedByDefault")
        if let data = try? JSONEncoder().encode(Array(visibleSections)) {
            defaults.set(data, forKey: "visibleSections")
        }
        defaults.set(automaticUpdateCheck, forKey: "automaticUpdateCheck")
        defaults.set(automaticUpdateInstall, forKey: "automaticUpdateInstall")
        defaults.set(usageAlertsEnabled, forKey: "usageAlertsEnabled")
        defaults.set(activeProvider.rawValue, forKey: "activeProvider")
        defaults.set(alertThreshold1, forKey: "alertThreshold1")
        defaults.set(alertThreshold2, forKey: "alertThreshold2")
        defaults.set(alertThreshold3, forKey: "alertThreshold3")
        defaults.set(showDaysFormat, forKey: "showDaysFormat")
        defaults.set(menuBarIconStyle.rawValue, forKey: "menuBarIconStyle")
    }
}
