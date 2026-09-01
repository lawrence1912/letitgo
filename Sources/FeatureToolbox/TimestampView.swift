import DesignSystem
import SwiftUI

/// epoch 时间戳 ↔ 日期。
public struct TimestampView: View {
    @State private var model = TimestampModel()

    public init() {}

    public var body: some View {
        ToolPage {
            options
            ToolNote("System.currentTimeMillis() 给毫秒，Instant.getEpochSecond() 给秒 —— 默认按量级自动判断，判断结果写在下面")
            input
            results
        }
    }

    private var options: some View {
        HStack(spacing: Theme.Spacing.md) {
            SegmentedPicker(
                "单位",
                options: TimeConversion.Unit.allCases,
                selection: $model.unit,
                title: \.title
            )
            SegmentedPicker(
                "时区",
                options: TimestampModel.ZoneChoice.allCases,
                selection: $model.zoneChoice,
                title: \.title
            )
            Spacer(minLength: Theme.Spacing.sm)
            Button("现在") { model.fillWithNow() }
                .buttonStyle(.secondaryAction(size: .compact))
                .help("填入当前时间的毫秒时间戳")
        }
    }

    private var input: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text("时间戳 或 日期")
                    .font(Theme.Typo.label)
                    .foregroundStyle(Theme.Ink.secondary)
                Spacer()
                // 「按什么读的」必须说出来。猜错三个数量级，日期会落到 1970 年
                // 或者五万年后 —— 而它看起来仍然「像个日期」。
                if case .success(let parsed) = model.parsed {
                    Badge(parsed.source.label, tone: .neutral, size: .compact)
                }
            }

            TextField("1700000000000", text: $model.input)
                .textFieldStyle(.plain)
                .font(Theme.Typo.mono)
                .foregroundStyle(Theme.Ink.primary)
                .padding(.horizontal, Theme.Spacing.sm)
                .frame(height: 32)
                .panel(.well, radius: Theme.Radius.control)
                .accessibilityLabel("时间戳或日期")
        }
    }

    @ViewBuilder
    private var results: some View {
        switch model.parsed {
        case .success:
            VStack(spacing: 0) {
                ForEach(Array(model.rows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 { Hairline() }
                    ResultRow(label: row.label, value: row.value, detail: row.detail)
                }
            }
            .panel()

        case .failure(let failure):
            NoticeView(.danger, title: "读不出来", message: failure.message)
        }
    }
}
