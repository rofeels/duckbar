import SwiftUI
import Carbon.HIToolbox
import CoreServices

// MARK: - Reusable Segment Picker

struct SegmentButton: View {
    let isSelected: Bool
    let title: String
    let fontSize: CGFloat
    let padding: CGFloat
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Text(title)
                .font(.system(size: fontSize, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, padding)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
    }
}

struct IconStyleButton: View {
    let style: MenuBarIconStyle
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                Image(nsImage: style.makeImage(frame: 0, color: nil, template: true))
                    .renderingMode(.template)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 36, height: 36)
                Text(style.displayName)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
    }
}

struct AlertThresholdField: View {
    @Binding var value: Double
    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 2) {
            TextField("", text: $text)
                .font(.system(size: 12, design: .monospaced))
                .multilineTextAlignment(.center)
                .frame(width: 36)
                .textFieldStyle(.plain)
                .focused($focused)
                .onAppear { text = value == 0 ? "" : String(Int(value)) }
                .onChange(of: focused) {
                    if !focused { commit() }
                }
                .onSubmit { commit() }
            Text("%")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(0.06))
        )
    }

    private func commit() {
        if let v = Double(text), v >= 0, v <= 100 {
            value = v
        } else if text.isEmpty {
            value = 0
        } else {
            text = value == 0 ? "" : String(Int(value))
        }
    }
}

struct SettingsView: View {
    let settings: AppSettings
    var onHelp: (() -> Void)? = nil
    let onDone: () -> Void
    @State private var isRecordingHotkey = false

    /// 헤더(~52pt) + 팝오버 여백을 제외한 스크롤 영역 최대 높이
    private var maxScrollHeight: CGFloat {
        let screenHeight = NSScreen.main?.visibleFrame.height ?? 800
        return screenHeight - 133
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Button(action: onDone) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text(L.settings)
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Button(action: { onHelp?() }) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                // Provider
                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        Text(L.provider)
                            .font(.system(size: 11, weight: .semibold))
                    } icon: {
                        Image(systemName: "cpu")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        ForEach(Provider.allCases, id: \.rawValue) { p in
                            SegmentButton(isSelected: settings.activeProvider == p,
                                          title: p.displayName, fontSize: 12, padding: 6) {
                                settings.activeProvider = p
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                Divider()

                // Language (.id로 언어 변경 시 전체 재렌더링 강제 — L.lang은 SwiftUI observation 밖)
                    VStack(alignment: .leading, spacing: 8) {
                        Label {
                            Text(L.language)
                                .font(.system(size: 11, weight: .semibold))
                        } icon: {
                            Image(systemName: "globe")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(.secondary)

                        HStack(spacing: 6) {
                            ForEach(AppLanguage.allCases, id: \.rawValue) { lang in
                                SegmentButton(isSelected: settings.language == lang,
                                              title: lang.displayName, fontSize: 12, padding: 6) {
                                    settings.language = lang
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    Divider()

                    // Popover Size
                    VStack(alignment: .leading, spacing: 8) {
                        Label {
                            Text(L.popoverSize)
                                .font(.system(size: 11, weight: .semibold))
                        } icon: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(.secondary)

                        HStack(spacing: 6) {
                            ForEach(PopoverSize.allCases, id: \.rawValue) { size in
                                SegmentButton(isSelected: settings.popoverSize == size,
                                              title: size.displayName, fontSize: 12, padding: 6) {
                                    settings.popoverSize = size
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    Divider()

                    // 메뉴바 아이콘
                    VStack(alignment: .leading, spacing: 8) {
                        Label {
                            Text(L.menuBarIcon)
                                .font(.system(size: 11, weight: .semibold))
                        } icon: {
                            Image(systemName: "menubar.rectangle")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(.secondary)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                            ForEach(MenuBarIconStyle.allCases, id: \.rawValue) { style in
                                IconStyleButton(style: style, isSelected: settings.menuBarIconStyle == style) {
                                    settings.menuBarIconStyle = style
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    Divider()

                    // Launch at Login
                    HStack {
                        Label {
                            Text(L.launchAtLogin)
                                .font(.system(size: 12))
                        } icon: {
                            Image(systemName: "power")
                                .font(.system(size: 10))
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { settings.launchAtLogin },
                            set: { settings.launchAtLogin = $0 }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    Divider()

                    // 기본 차트 뷰
                    VStack(alignment: .leading, spacing: 8) {
                        Label {
                            Text(L.defaultChartView)
                                .font(.system(size: 11, weight: .semibold))
                        } icon: {
                            Image(systemName: "chart.xyaxis.line")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(.secondary)

                        HStack(spacing: 6) {
                            SegmentButton(isSelected: settings.defaultChartTab == "line",
                                          title: L.chartTabLine, fontSize: 12, padding: 6) {
                                settings.defaultChartTab = "line"
                            }
                            SegmentButton(isSelected: settings.defaultChartTab == "heatmap",
                                          title: L.chartTabHeatmap, fontSize: 12, padding: 6) {
                                settings.defaultChartTab = "heatmap"
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                    // 차트 항상 펼치기
                    HStack {
                        Label {
                            Text(L.chartExpandedByDefault)
                                .font(.system(size: 12))
                        } icon: {
                            Image(systemName: "chevron.down.circle")
                                .font(.system(size: 10))
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { settings.chartExpandedByDefault },
                            set: { settings.chartExpandedByDefault = $0 }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)

                    Divider()

                    // 남은 시간 일 단위 표시
                    HStack {
                        Label {
                            Text(L.showDaysFormat)
                                .font(.system(size: 12))
                        } icon: {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { settings.showDaysFormat },
                            set: { settings.showDaysFormat = $0 }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    Divider()

                    // 사용량 알림
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label {
                                Text(L.usageAlerts)
                                    .font(.system(size: 12))
                            } icon: {
                                Image(systemName: "bell")
                                    .font(.system(size: 10))
                            }

                            Spacer()

                            Toggle("", isOn: Binding(
                                get: { settings.usageAlertsEnabled },
                                set: { newValue in
                                    settings.usageAlertsEnabled = newValue
                                    if newValue {
                                        UsageAlertManager.shared.requestPermissionIfNeeded()
                                    }
                                }
                            ))
                            .toggleStyle(.switch)
                            .controlSize(.small)
                        }

                        if settings.usageAlertsEnabled {
                            HStack(spacing: 6) {
                                AlertThresholdField(value: Binding(get: { settings.alertThreshold1 }, set: { settings.alertThreshold1 = $0 }))
                                AlertThresholdField(value: Binding(get: { settings.alertThreshold2 }, set: { settings.alertThreshold2 = $0 }))
                                AlertThresholdField(value: Binding(get: { settings.alertThreshold3 }, set: { settings.alertThreshold3 = $0 }))
                            }
                            Text(L.usageAlertsHint)
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    Divider()

                    // 자동 업데이트 확인
                    HStack {
                        Label {
                            Text(L.automaticUpdateCheck)
                                .font(.system(size: 12))
                        } icon: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 10))
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { settings.automaticUpdateCheck },
                            set: { settings.automaticUpdateCheck = $0 }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, settings.automaticUpdateCheck ? 6 : 10)

                    // 업데이트 자동 설치 (자동 확인이 켜진 경우에만 표시)
                    if settings.automaticUpdateCheck {
                        HStack {
                            Label {
                                Text(L.automaticUpdateInstall)
                                    .font(.system(size: 12))
                            } icon: {
                                Image(systemName: "arrow.down.circle")
                                    .font(.system(size: 10))
                            }

                            Spacer()

                            Toggle("", isOn: Binding(
                                get: { settings.automaticUpdateInstall },
                                set: { settings.automaticUpdateInstall = $0 }
                            ))
                            .toggleStyle(.switch)
                            .controlSize(.small)
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 10)
                    }

                    Divider()

                    // Hotkey
                    HStack {
                        Label {
                            Text(L.hotkey)
                                .font(.system(size: 12))
                        } icon: {
                            Image(systemName: "keyboard")
                                .font(.system(size: 10))
                        }

                        Spacer()

                        if isRecordingHotkey {
                            Button(action: {
                                isRecordingHotkey = false
                                NotificationCenter.default.post(name: .stopRecordingHotkey, object: nil)
                            }) {
                                Text(L.hotkeyRecord)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.orange)
                                    .padding(.vertical, 5)
                                    .padding(.horizontal, 12)
                                    .background(
                                        Capsule()
                                            .strokeBorder(Color.orange, lineWidth: 1.5)
                                    )
                            }
                            .buttonStyle(.plain)
                        } else if settings.hotkeyCode == 0 && settings.hotkeyModifiers == 0 {
                            // 미설정 상태
                            Button(action: {
                                isRecordingHotkey = true
                                NotificationCenter.default.post(name: .startRecordingHotkey, object: nil)
                            }) {
                                Text(L.setHotkey)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 5)
                                    .padding(.horizontal, 14)
                                    .background(
                                        Capsule()
                                            .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        } else {
                            // 설정된 상태
                            HStack(spacing: 4) {
                                Button(action: {
                                    isRecordingHotkey = true
                                    NotificationCenter.default.post(name: .startRecordingHotkey, object: nil)
                                }) {
                                    Text(hotkeyDisplayString())
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.primary)
                                }
                                .buttonStyle(.plain)

                                Button(action: {
                                    settings.hotkeyCode = 0
                                    settings.hotkeyModifiers = 0
                                    NotificationCenter.default.post(name: .hotkeyChanged, object: nil)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 5)
                            .padding(.leading, 12)
                            .padding(.trailing, 8)
                            .background(
                                Capsule()
                                    .strokeBorder(Color.primary.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .hotkeyRecorded)) { _ in
                        isRecordingHotkey = false
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    Divider()

                    // Refresh Interval
                    VStack(alignment: .leading, spacing: 8) {
                        Label {
                            Text(L.refreshInterval)
                                .font(.system(size: 11, weight: .semibold))
                        } icon: {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(.secondary)

                        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)
                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(RefreshInterval.allCases, id: \.rawValue) { interval in
                                SegmentButton(isSelected: settings.refreshInterval == interval,
                                              title: interval.displayName, fontSize: 11, padding: 5) {
                                    settings.refreshInterval = interval
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    Divider()

                    // 섹션 표시 옵션
                    VStack(alignment: .leading, spacing: 10) {
                        Label {
                            Text(L.visibleSections)
                                .font(.system(size: 11, weight: .semibold))
                        } icon: {
                            Image(systemName: "square.3.layers.3d")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(.secondary)

                        VStack(spacing: 2) {
                            ForEach(MainSection.allCases) { section in
                                let isOn = settings.visibleSections.contains(section)
                                Button(action: {
                                    if isOn {
                                        settings.visibleSections.remove(section)
                                    } else {
                                        settings.visibleSections.insert(section)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 14))
                                            .foregroundStyle(isOn ? .blue : .secondary)
                                        Text(section.label(settings.language))
                                            .font(.system(size: 12))
                                        Spacer()
                                    }
                                    .padding(.vertical, 5)
                                    .padding(.horizontal, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(isOn ? Color.blue.opacity(0.08) : Color.clear)
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    Divider()

                    // Status bar items
                    VStack(alignment: .leading, spacing: 10) {
                        Label {
                            Text(L.statusBarDisplay)
                                .font(.system(size: 11, weight: .semibold))
                        } icon: {
                            Image(systemName: "menubar.rectangle")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(.secondary)

                        VStack(spacing: 2) {
                            ForEach(StatusBarItem.allCases) { item in
                                let isOn = settings.statusBarItems.contains(item)
                                Button(action: {
                                    if isOn {
                                        settings.statusBarItems.remove(item)
                                    } else {
                                        settings.statusBarItems.insert(item)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 14))
                                            .foregroundStyle(isOn ? .green : .secondary)

                                        Text(item.label(settings.language))
                                            .font(.system(size: 12))

                                        Spacer()

                                        // 미리보기
                                        Text(previewText(for: item))
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.vertical, 5)
                                    .padding(.horizontal, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(isOn ? Color.green.opacity(0.08) : Color.clear)
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }
            .id(settings.language)
            } // ScrollView
            .frame(maxHeight: maxScrollHeight)
        }
        .frame(width: settings.popoverSize.width)
    }

    private func hotkeyDisplayString() -> String {
        let code = settings.hotkeyCode
        let mods = NSEvent.ModifierFlags(rawValue: settings.hotkeyModifiers)
        if code == 0 && settings.hotkeyModifiers == 0 { return "—" }

        var parts: [String] = []
        if mods.contains(.control) { parts.append("⌃") }
        if mods.contains(.option) { parts.append("⌥") }
        if mods.contains(.shift) { parts.append("⇧") }
        if mods.contains(.command) { parts.append("⌘") }
        parts.append(keyName(for: code))
        return parts.joined()
    }

    private func keyName(for code: UInt16) -> String {
        // 비인쇄 키만 하드코딩
        let special: [UInt16: String] = [
            // Function keys (UCKeyTranslate가 PUA 문자를 반환하므로 직접 매핑)
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
            105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17", 79: "F18", 80: "F19",
            // 특수 키
            36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "Esc", 117: "⌦",
            // 방향 키
            123: "←", 124: "→", 125: "↓", 126: "↑",
            // 내비게이션
            115: "Home", 119: "End", 116: "PgUp", 121: "PgDn",
        ]
        if let name = special[code] { return name }

        // 나머지: UCKeyTranslate로 현재 키보드 레이아웃에서 자동 변환
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let rawPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return "Key \(code)"
        }
        let layoutData = unsafeBitCast(rawPtr, to: CFData.self) as Data
        var deadKeyState: UInt32 = 0
        let maxChars = 4
        var chars = [UniChar](repeating: 0, count: maxChars)
        var length = 0

        let error = layoutData.withUnsafeBytes { pointer -> OSStatus in
            guard let baseAddress = pointer.bindMemory(to: UCKeyboardLayout.self).baseAddress else {
                return errSecAllocate
            }
            return CoreServices.UCKeyTranslate(
                baseAddress,
                code,
                UInt16(CoreServices.kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(CoreServices.kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                maxChars,
                &length,
                &chars
            )
        }

        guard error == noErr, length > 0 else { return "Key \(code)" }
        return (NSString(characters: &chars, length: length) as String).uppercased()
    }

    private func previewText(for item: StatusBarItem) -> String {
        switch item {
        case .rateLimit: "5h 42%"
        case .weeklyRateLimit: "1w 68%"
        case .tokens: "12.3K"
        case .weeklyTokens: "1.2M"
        case .cost: "$1.23"
        case .weeklyCost: "$15.40"
        case .context: "ctx 65%"
        case .extraUsage: "ex $13/$20"
        }
    }
}
