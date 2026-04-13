import SwiftUI
import Charts

struct TokenChartView: View {
    let hourlyData: [HourlyTokenData]
    let weeklyHourlyData: [HourlyTokenData]
    let fontScale: CGFloat
    let defaultTab: String

    private var s: CGFloat { fontScale }

    @State private var selectedTab: ChartTab = .line

    init(hourlyData: [HourlyTokenData], weeklyHourlyData: [HourlyTokenData], fontScale: CGFloat, defaultTab: String) {
        self.hourlyData = hourlyData
        self.weeklyHourlyData = weeklyHourlyData
        self.fontScale = fontScale
        self.defaultTab = defaultTab
        _selectedTab = State(initialValue: defaultTab == "heatmap" ? .heatmap : .line)
    }

    enum ChartTab: CaseIterable {
        case line, heatmap

        var label: String {
            switch self {
            case .line: L.chartTabLine
            case .heatmap: L.chartTabHeatmap
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                ForEach(ChartTab.allCases, id: \.label) { tab in
                    SegmentButton(
                        isSelected: selectedTab == tab,
                        title: tab.label,
                        fontSize: 10 * s,
                        padding: 4
                    ) { selectedTab = tab }
                }
            }

            switch selectedTab {
            case .line:
                lineChartSection
            case .heatmap:
                heatmapSection
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - 라인 차트

    private var lineChartSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            tokenChart
            costChart
        }
    }

    private var tokenChart: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L.tokenChart)
                .font(.system(size: 10 * s, weight: .medium))
                .foregroundStyle(.secondary)

            Chart(hourlyData) { point in
                LineMark(x: .value("시간", point.hour), y: .value("토큰", point.totalTokens))
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)
                AreaMark(x: .value("시간", point.hour), y: .value("토큰", point.totalTokens))
                    .foregroundStyle(.blue.opacity(0.1))
                    .interpolationMethod(.catmullRom)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 6)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2]))
                        .foregroundStyle(Color.gray.opacity(0.3))
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(formatHour(date)).font(.system(size: 8 * s))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2]))
                        .foregroundStyle(Color.gray.opacity(0.2))
                    AxisValueLabel {
                        if let v = value.as(Int.self) {
                            Text(TokenUsage.formatTokens(v)).font(.system(size: 8 * s))
                        }
                    }
                }
            }
            .frame(height: 80 * s)
        }
    }

    private var costChart: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L.costChart)
                .font(.system(size: 10 * s, weight: .medium))
                .foregroundStyle(.secondary)

            Chart(hourlyData) { point in
                LineMark(x: .value("시간", point.hour), y: .value("비용", point.estimatedCostUSD))
                    .foregroundStyle(.orange)
                    .interpolationMethod(.catmullRom)
                AreaMark(x: .value("시간", point.hour), y: .value("비용", point.estimatedCostUSD))
                    .foregroundStyle(.orange.opacity(0.1))
                    .interpolationMethod(.catmullRom)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 6)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2]))
                        .foregroundStyle(Color.gray.opacity(0.3))
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(formatHour(date)).font(.system(size: 8 * s))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2]))
                        .foregroundStyle(Color.gray.opacity(0.2))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(TokenUsage.formatCost(v)).font(.system(size: 8 * s))
                        }
                    }
                }
            }
            .frame(height: 80 * s)
        }
    }

    // MARK: - 히트맵

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L.chartHeatmap)
                .font(.system(size: 10 * s, weight: .medium))
                .foregroundStyle(.secondary)
            HeatmapView(weeklyData: weeklyHourlyData, fontScale: s)
        }
    }

    private func formatHour(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter.string(from: date)
    }
}

// MARK: - HeatmapView

struct HeatmapView: View {
    let weeklyData: [HourlyTokenData]
    let fontScale: CGFloat
    var showDayLabels: Bool = true

    private var maxTokens: Int { weeklyData.map(\.totalTokens).max() ?? 1 }
    private var tokenMap: [Date: Int] {
        Dictionary(uniqueKeysWithValues: weeklyData.map { ($0.hour, $0.totalTokens) })
    }
    private var days: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<7).reversed().map { cal.date(byAdding: .day, value: -$0, to: today)! }
    }
    private var gridHeight: CGFloat {
        // 7*14=98, 6*2=12, +14+20=34 → total 144
        let base: CGFloat = 144.0
        return base * fontScale
    }

    var body: some View {
        HeatmapSizedGrid(
            days: days,
            tokenMap: tokenMap,
            maxTokens: maxTokens,
            fontScale: fontScale,
            height: gridHeight,
            showDayLabels: showDayLabels
        )
    }
}

// MARK: - HeatmapSizedGrid (GeometryReader 래퍼)

struct HeatmapSizedGrid: View {
    let days: [Date]
    let tokenMap: [Date: Int]
    let maxTokens: Int
    let fontScale: CGFloat
    let height: CGFloat
    var showDayLabels: Bool = true

    var body: some View {
        GeometryReader { geo in
            HeatmapGrid(
                days: days,
                tokenMap: tokenMap,
                maxTokens: maxTokens,
                fontScale: fontScale,
                totalWidth: geo.size.width,
                showDayLabels: showDayLabels
            )
        }
        .frame(height: height)
    }
}

// MARK: - HeatmapGrid

struct HeatmapGrid: View {
    let days: [Date]
    let tokenMap: [Date: Int]
    let maxTokens: Int
    let fontScale: CGFloat
    let totalWidth: CGFloat
    var showDayLabels: Bool = true

    private var s: CGFloat { fontScale }
    private var labelWidth: CGFloat { showDayLabels ? 28 : 0 }
    private var cellSize: CGFloat { (totalWidth - labelWidth) / 24 }
    private var rowHeight: CGFloat { cellSize * 0.85 }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            hourLabels
            ForEach(days, id: \.self) { day in
                HeatmapRow(
                    day: day,
                    tokenMap: tokenMap,
                    maxTokens: maxTokens,
                    fontScale: fontScale,
                    cellSize: cellSize,
                    rowHeight: rowHeight,
                    showDayLabel: showDayLabels
                )
            }
            legendRow
        }
    }

    private var hourLabels: some View {
        HStack(spacing: 0) {
            if showDayLabels {
                Spacer().frame(width: 28)
            }
            ForEach(0..<4, id: \.self) { i in
                Text("\(i * 6)")
                    .font(.system(size: 7 * s))
                    .foregroundStyle(.tertiary)
                    .frame(width: cellSize * 6, alignment: .leading)
            }
        }
    }

    private var legendRow: some View {
        HStack(spacing: 4) {
            Spacer()
            Text(L.heatmapLess).font(.system(size: 7 * s)).foregroundStyle(.tertiary)
            ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { v in
                RoundedRectangle(cornerRadius: 2)
                    .fill(heatmapColor(intensity: v))
                    .frame(width: 10, height: 10)
            }
            Text(L.heatmapMore).font(.system(size: 7 * s)).foregroundStyle(.tertiary)
        }
        .padding(.top, 2)
    }
}

// MARK: - HeatmapRow

struct HeatmapRow: View {
    let day: Date
    let tokenMap: [Date: Int]
    let maxTokens: Int
    let fontScale: CGFloat
    let cellSize: CGFloat
    let rowHeight: CGFloat
    var showDayLabel: Bool = true

    private var s: CGFloat { fontScale }

    var body: some View {
        HStack(spacing: 2) {
            if showDayLabel {
                Text(dayLabel)
                    .font(.system(size: 7 * s, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, alignment: .trailing)
            }
            HStack(spacing: 1) {
                ForEach(0..<24, id: \.self) { hour in
                    HeatmapCell(
                        date: hourDate(hour),
                        tokens: tokenMap[hourDate(hour)] ?? 0,
                        maxTokens: maxTokens,
                        cellSize: cellSize,
                        rowHeight: rowHeight,
                        label: hourLabel(hour)
                    )
                }
            }
        }
    }

    private var dayLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EE"
        f.locale = Locale(identifier: L.lang == .korean ? "ko_KR" : "en_US")
        f.timeZone = TimeZone(identifier: "Asia/Seoul")
        return f.string(from: day)
    }

    private func hourDate(_ hour: Int) -> Date {
        Calendar.current.date(byAdding: .hour, value: hour, to: day)!
    }

    private func hourLabel(_ hour: Int) -> String {
        let f = DateFormatter()
        f.dateFormat = "M/d HH:00"
        f.timeZone = TimeZone(identifier: "Asia/Seoul")
        return f.string(from: hourDate(hour))
    }
}

// MARK: - HeatmapCell

struct HeatmapCell: View {
    let date: Date
    let tokens: Int
    let maxTokens: Int
    let cellSize: CGFloat
    let rowHeight: CGFloat
    let label: String

    private var intensity: Double {
        maxTokens > 0 ? Double(tokens) / Double(maxTokens) : 0
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(heatmapColor(intensity: intensity))
            .frame(width: cellSize - 1, height: rowHeight)
            .help(tokens > 0 ? "\(label): \(TokenUsage.formatTokens(tokens))" : "")
    }
}

// MARK: - 공통 색상 함수

func heatmapColor(intensity: Double) -> Color {
    guard intensity > 0 else { return Color.gray.opacity(0.12) }
    return Color(
        hue: 0.38,
        saturation: 0.6 + intensity * 0.4,
        brightness: 0.85 - intensity * 0.35
    ).opacity(0.3 + intensity * 0.7)
}
