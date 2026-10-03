import AppKit

// MARK: - 메뉴바 아이콘 스타일 (18x18 픽셀아트, 3프레임 애니메이션)

enum MenuBarIconStyle: String, CaseIterable, Codable {
    case duckFeet
    case duck
    case claude

    var displayName: String {
        switch self {
        case .duckFeet: L.iconDuckFeet
        case .duck: L.iconDuck
        case .claude: L.iconClaude
        }
    }

    /// 프레임별 픽셀 좌표 (원점 좌상단). frame 0 = 정지 상태
    func pixels(frame: Int) -> [(Int, Int)] {
        switch self {
        case .duckFeet:
            // 뒤뚱뒤뚱 워킹: 양발 Y 오프셋 교차
            let (leftY, rightY) = frame == 1 ? (5, 7) : frame == 2 ? (7, 5) : (6, 6)
            return Self.points(Self.footArt, x: 0, y: leftY) + Self.points(Self.footArt, x: 11, y: rightY)
        case .duck:
            // 둥실둥실: 몸통만 위아래, 물결은 고정
            let bob = frame == 1 ? -1 : frame == 2 ? 1 : 0
            return Self.points(Self.duckBodyArt, x: 1, y: 3 + bob) + Self.points(Self.waterArt, x: 0, y: 16)
        case .claude:
            // 종종걸음: 다리 두 쌍이 번갈아 들림
            let lifted: Set<Int> = frame == 1 ? [0, 2] : frame == 2 ? [1, 3] : []
            let legs = [3, 5, 10, 12].enumerated().flatMap { i, x in
                lifted.contains(i) ? [(x, 11)] : [(x, 11), (x, 12)]
            }
            return Self.points(Self.claudeArt, x: 1, y: 4) + legs
        }
    }

    func makeImage(frame: Int, color: NSColor?, template: Bool) -> NSImage {
        let fillColor = template ? NSColor.black : (color ?? .black)
        let pixels = pixels(frame: frame)
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            fillColor.setFill()
            for (x, y) in pixels {
                NSRect(x: CGFloat(x), y: CGFloat(y), width: 1, height: 1).fill()
            }
            return true
        }
        image.isTemplate = template
        return image
    }

    /// ASCII 아트("#" = 픽셀)를 좌표로 변환
    private static func points(_ art: [String], x: Int, y: Int) -> [(Int, Int)] {
        art.enumerated().flatMap { dy, row in
            row.enumerated().compactMap { dx, ch in ch == "#" ? (x + dx, y + dy) : nil }
        }
    }

    private static let footArt = [
        "   #   ",
        "   #   ",
        "  ###  ",
        " ##### ",
        "#######",
        "#  #  #",
    ]

    private static let duckBodyArt = [
        "   ###          ",
        "  #####         ",
        "  # ###         ",
        "#######         ",
        "  #####      ## ",
        "   ####     ### ",
        "  ############# ",
        "  ############# ",
        "   ###########  ",
        "    #########   ",
    ]

    private static let waterArt = [
        "##  ####  ####  ##",
    ]

    private static let claudeArt = [
        "  ############  ",
        "  ##  ####  ##  ",
        "  ##  ####  ##  ",
        "################",
        "################",
        "  ############  ",
        "  ############  ",
    ]
}
