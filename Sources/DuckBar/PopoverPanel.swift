import AppKit
import SwiftUI

/// 시스템 기본 NSPopover를 래핑
final class PopoverManager: NSObject, NSPopoverDelegate {

    let popover = NSPopover()

    override init() {
        super.init()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
    }

    func popoverDidShow(_ notification: Notification) {
        popover.contentViewController?.view.window?.makeKey()
    }

    /// SwiftUI 뷰를 콘텐츠로 설정
    func setContentView<V: View>(_ view: V) {
        let hc = NSHostingController(rootView: view)
        hc.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hc
    }

    /// 메뉴바 버튼 기준으로 팝오버 표시/숨기기 토글
    func toggle(relativeTo button: NSView, withSize size: NSSize) {
        if popover.isShown {
            close()
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    var isShown: Bool {
        popover.isShown
    }

    func close() {
        popover.performClose(nil)
    }
}
