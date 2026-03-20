import AppKit
import SwiftUI
import Sparkle
@preconcurrency import HotKey

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popoverManager: PopoverManager!
    private var monitor: SessionMonitor!
    private let settings = AppSettings.shared
    private var statusMenuView: StatusMenuView!
    private var updateTimer: Timer?
    private var updaterController: SPUStandardUpdaterController!
    private var lastRenderedState: SessionState?
    private var lastStatusText: String?
    private var lastRefreshInterval: Double = 5.0
    private var animationTimer: Timer?
    private var currentAnimationFrame: Int = 0
    private var animationDirection: Int = 1
    private var hotKey: HotKey?
    private struct ImageCacheKey: Hashable {
        let frame: Int
        let template: Bool
        let colorName: String?
    }
    private var imageCache: [ImageCacheKey: NSImage] = [:]
    private var recordingMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        monitor = SessionMonitor()

        // 메뉴바 아이템 설정
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = cachedDuckFeetImage(frame: 0, color: nil, template: true)
            button.imagePosition = .imageLeading
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // 팝오버 설정 (시스템 기본 NSPopover)
        popoverManager = PopoverManager()
        statusMenuView = StatusMenuView(monitor: monitor, settings: settings) {
            NSApplication.shared.terminate(nil)
        }
        popoverManager.setContentView(statusMenuView)

        // 세션 모니터 시작 (설정된 갱신 주기)
        monitor.start(interval: settings.refreshInterval.rawValue)

        // 메뉴바 아이콘 + 텍스트 업데이트 타이머 (1초)
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMenuBarIcon()
            }
        }

        // 다크모드 전환 감지
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(appearanceChanged),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )

        // 글로벌 핫키
        setupHotkey()

        // 핫키 변경 감지
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotkeyChanged),
            name: .hotkeyChanged,
            object: nil
        )

        // 핫키 녹음 시작 감지
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(startRecordingHotkey),
            name: .startRecordingHotkey,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(stopRecordingHotkey),
            name: .stopRecordingHotkey,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        updateTimer?.invalidate()
        animationTimer?.invalidate()
        hotKey = nil
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc private func hotkeyChanged() {
        setupHotkey()
    }

    @objc private func startRecordingHotkey() {
        // 녹음 중에는 기존 핫키 해제
        hotKey = nil

        recordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let significantMods = event.modifierFlags.intersection([.command, .option, .shift, .control])
            if event.keyCode == 53 && significantMods.isEmpty {
                self.finishRecording(keyCode: nil)
                return nil
            }
            self.finishRecording(keyCode: event.keyCode, modifiers: event.modifierFlags)
            return nil
        }
    }

    @objc private func stopRecordingHotkey() {
        if let monitor = recordingMonitor { NSEvent.removeMonitor(monitor) }
        recordingMonitor = nil
        setupHotkey()
    }

    private func finishRecording(keyCode: UInt16?, modifiers: NSEvent.ModifierFlags = []) {
        if let monitor = recordingMonitor { NSEvent.removeMonitor(monitor) }
        recordingMonitor = nil

        if let keyCode {
            settings.hotkeyCode = keyCode
            settings.hotkeyModifiers = modifiers.intersection(.deviceIndependentFlagsMask).rawValue
        }
        setupHotkey()
        NotificationCenter.default.post(name: .hotkeyRecorded, object: nil)
    }

    @objc private func appearanceChanged() {
        imageCache.removeAll()
        lastRenderedState = nil // 강제 아이콘 재렌더
        updateMenuBarIcon()
    }

    private func setupHotkey() {
        hotKey = nil

        let keyCode = settings.hotkeyCode
        guard keyCode != 0 || settings.hotkeyModifiers != 0 else { return }

        let modifiers = NSEvent.ModifierFlags(rawValue: settings.hotkeyModifiers)
            .intersection(.deviceIndependentFlagsMask)
            .subtracting(.function) // Fn 플래그 제거 (function 키 녹음 시 불필요하게 포함됨)

        let hk = HotKey(carbonKeyCode: UInt32(keyCode), carbonModifiers: modifiers.carbonFlags)
        hk.keyDownHandler = { [weak self] in
            Task { @MainActor in
                self?.togglePopover()
            }
        }
        hotKey = hk
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func showContextMenu() {
        guard let button = statusItem.button else { return }
        let menu = NSMenu()

        let refreshItem = NSMenuItem(title: L.refresh, action: #selector(refreshAction), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let checkUpdateItem = NSMenuItem(title: L.checkForUpdates, action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "u")
        checkUpdateItem.target = updaterController
        menu.addItem(checkUpdateItem)

        let settingsItem = NSMenuItem(title: L.settings, action: #selector(openSettingsAction), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let helpItem = NSMenuItem(title: L.help, action: #selector(openHelpAction), keyEquivalent: "?")
        helpItem.target = self
        menu.addItem(helpItem)

        menu.addItem(NSMenuItem.separator())

        let aboutItem = NSMenuItem(title: L.about, action: #selector(showAboutAction), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: L.quit, action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 5), in: button)
    }

    @objc private func refreshAction() {
        Task { await monitor.refreshAsync() }
    }

    @objc private func openSettingsAction() {
        NotificationCenter.default.post(name: .openSettings, object: nil)
        togglePopover()
    }

    @objc private func openHelpAction() {
        NotificationCenter.default.post(name: .openHelp, object: nil)
        togglePopover()
    }

    @objc private func showAboutAction() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func quitAction() {
        NSApplication.shared.terminate(nil)
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        let size = NSSize(
            width: settings.popoverSize.width,
            height: settings.popoverSize.height
        )
        popoverManager.toggle(relativeTo: button, withSize: size)

        if popoverManager.isShown {
            Task {
                await monitor.refreshAsync()
            }
        }
    }

    private func closePopover() {
        popoverManager.close()
    }

    private func updateMenuBarIcon() {
        // 갱신주기 변경 감지
        let newInterval = settings.refreshInterval.rawValue
        if newInterval != lastRefreshInterval {
            lastRefreshInterval = newInterval
            monitor.restartTimers(interval: newInterval)
        }

        let state = monitor.aggregateState
        let isEmpty = monitor.sessions.isEmpty
        let statusText = buildStatusText()

        guard state != lastRenderedState || isEmpty || statusText != lastStatusText else { return }
        lastRenderedState = state
        lastStatusText = statusText

        guard let button = statusItem.button else { return }

        let tintColor: NSColor?

        if isEmpty {
            tintColor = nil
        } else {
            switch state {
            case .active: tintColor = .systemGreen
            case .waiting: tintColor = .systemOrange
            case .compacting: tintColor = .systemBlue
            case .idle: tintColor = nil
            }
        }

        // 애니메이션 관리: active 상태에서만 오리발 걷기 모션
        if state == .active && !isEmpty {
            startAnimation()
        } else {
            stopAnimation()
        }

        if let color = tintColor {
            button.image = cachedDuckFeetImage(frame: currentAnimationFrame, color: color, template: false)
            button.contentTintColor = color
        } else {
            button.image = cachedDuckFeetImage(frame: 0, color: nil, template: true)
            button.contentTintColor = nil
        }

        // 상태바 텍스트 표시
        if let text = statusText {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
                .baselineOffset: -1,
                .foregroundColor: NSColor.labelColor
            ]
            button.attributedTitle = NSAttributedString(string: " \(text)", attributes: attrs)
        } else {
            button.title = ""
        }
    }

    /// 설정에 따라 상태바 텍스트 생성
    private func buildStatusText() -> String? {
        let items = settings.statusBarItems
        guard !items.isEmpty else { return nil }

        var parts: [String] = []
        let stats = monitor.usageStats

        // 순서 고정
        if items.contains(.rateLimit) {
            let text = stats.rateLimits.isLoaded ? "5h \(Int(stats.rateLimits.fiveHourPercent))%" : "5h —"
            parts.append(text)
        }
        if items.contains(.weeklyRateLimit) {
            let text = stats.rateLimits.isLoaded ? "1w \(Int(stats.rateLimits.weeklyPercent))%" : "1w —"
            parts.append(text)
        }
        if items.contains(.tokens) {
            parts.append(TokenUsage.formatTokens(stats.fiveHourTokens.totalTokens))
        }
        if items.contains(.weeklyTokens) {
            parts.append(TokenUsage.formatTokens(stats.oneWeekTokens.totalTokens))
        }
        if items.contains(.cost) {
            parts.append(TokenUsage.formatCost(stats.fiveHourTokens.estimatedCostUSD))
        }
        if items.contains(.weeklyCost) {
            parts.append(TokenUsage.formatCost(stats.oneWeekTokens.estimatedCostUSD))
        }
        if items.contains(.context) {
            let pct = Int(stats.contextInfo.usagePercent * 100)
            parts.append("ctx \(pct)%")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: - 오리발 픽셀아트

    /// 오리발 한 쌍의 픽셀아트 shape (7 wide, 6 tall)
    /// 좌표: (dx, dy), 원점은 좌상단
    private static let footShape: [(Int, Int)] = [
        // 다리
        (3, 0), (3, 1),
        // 발목
        (2, 2), (3, 2), (4, 2),
        // 발등
        (1, 3), (2, 3), (3, 3), (4, 3), (5, 3),
        // 물갈퀴
        (0, 4), (1, 4), (2, 4), (3, 4), (4, 4), (5, 4), (6, 4),
        // 발가락 (3개)
        (0, 5), (3, 5), (6, 5),
    ]

    private static func colorName(for color: NSColor?) -> String? {
        guard let color else { return nil }
        if color == .systemGreen { return "green" }
        if color == .systemOrange { return "orange" }
        if color == .systemBlue { return "blue" }
        return "other"
    }

    private func cachedDuckFeetImage(frame: Int, color: NSColor?, template: Bool) -> NSImage {
        let key = ImageCacheKey(frame: frame, template: template, colorName: Self.colorName(for: color))
        if let cached = imageCache[key] { return cached }
        let image = makeDuckFeetImage(frame: frame, color: color, template: template)
        imageCache[key] = image
        return image
    }

    /// 오리발 픽셀아트 메뉴바 이미지 생성
    private func makeDuckFeetImage(frame: Int, color: NSColor?, template: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let fillColor = template ? NSColor.black : (color ?? .black)

        // 프레임별 Y 오프셋 (뒤뚱뒤뚱 워킹 모션)
        let leftY: Int
        let rightY: Int
        switch frame {
        case 1:  leftY = 5; rightY = 7
        case 2:  leftY = 7; rightY = 5
        default: leftY = 6; rightY = 6
        }

        let image = NSImage(size: size, flipped: true) { _ in
            fillColor.setFill()
            for (dx, dy) in Self.footShape {
                // 왼발 (x 시작 = 0)
                NSRect(x: CGFloat(dx), y: CGFloat(leftY + dy), width: 1, height: 1).fill()
                // 오른발 (x 시작 = 11)
                NSRect(x: CGFloat(11 + dx), y: CGFloat(rightY + dy), width: 1, height: 1).fill()
            }
            return true
        }

        image.isTemplate = template
        return image
    }

    // MARK: - 걷기 애니메이션

    private func startAnimation() {
        guard animationTimer == nil else { return }
        currentAnimationFrame = 0
        animationDirection = 1
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let button = self.statusItem.button else { return }
                self.currentAnimationFrame += self.animationDirection
                if self.currentAnimationFrame >= 2 { self.animationDirection = -1 }
                if self.currentAnimationFrame <= 0 { self.animationDirection = 1 }
                button.image = self.cachedDuckFeetImage(
                    frame: self.currentAnimationFrame,
                    color: .systemGreen,
                    template: false
                )
            }
        }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        currentAnimationFrame = 0
        animationDirection = 1
    }
}
