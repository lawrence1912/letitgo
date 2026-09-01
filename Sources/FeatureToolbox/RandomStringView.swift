import DesignSystem
import SwiftUI

/// 随机串生成：密码、密钥、测试数据。
///
/// **一次给十个。** 挑密码这件事得有得挑 —— 好念、好打、不带 `l1I` `O0`
/// 这种一眼看不出差别的字符，这些没法写成选项，只能眼睛过一遍。
/// 一次只给一串的话，用户得连点十次，而每点一次上一串就没了。
public struct RandomStringView: View {
    @State private var model = RandomStringModel()

    public init() {}

    public var body: some View {
        @Bindable var model = model

        ToolPage {
            HStack(spacing: Theme.Spacing.lg) {
                length
                Spacer(minLength: Theme.Spacing.sm)
                // 这一页只有一个响亮的按钮，就是它。
                Button("重新生成") { model.regenerate() }
                    .buttonStyle(.primaryAction)
                    .disabled(model.hasNoClasses)
                    .keyboardShortcut("r", modifiers: .command)
                    .help("重新生成（⌘R）")
            }

            classes

            ToolNote("随机源是 SystemRandomNumberGenerator（CSPRNG）—— 对应 Java 的 SecureRandom，不是 Math.random() / new Random()，后两个可预测")

            result
        }
        // 选项一动就重来一批。改完还要再点一次「生成」是多余的一步 ——
        // 用户改长度本来就是为了要一批新长度的。
        .onChange(of: model.options) { model.regenerate() }
    }

    private var length: some View {
        @Bindable var model = model

        return HStack(spacing: Theme.Spacing.sm) {
            Text("长度")
                .font(Theme.Typo.label)
                .foregroundStyle(Theme.Ink.secondary)

            // 原生 Slider：拖动手感、键盘方向键、VoiceOver 的增减全在它本体里。
            Slider(
                value: Binding(
                    get: { Double(model.options.length) },
                    set: { model.options.length = Int($0.rounded()) }
                ),
                in: Double(RandomString.minimumLength)...Double(RandomString.maximumLength),
                step: 1
            )
            .frame(width: 220)
            .tint(Theme.Brand.accentFill)
            .accessibilityLabel("长度")
            .accessibilityValue("\(model.options.length) 个字符")

            Text("\(model.options.length)")
                .font(Theme.Typo.numeric)
                .foregroundStyle(Theme.Ink.primary)
                .frame(width: 26, alignment: .trailing)
                .accessibilityHidden(true)
        }
    }

    private var classes: some View {
        @Bindable var model = model

        // 间距用 md 不是 lg，末尾那个开关靠 Spacer 推到右边：
        // 详情区最窄是 460pt，四个复选框 + 一个开关排一行，宽度是刚好够的。
        return HStack(spacing: Theme.Spacing.md) {
            // 复选框继续用系统的：多选的语义、键盘、VoiceOver 角色全是白送的，
            // 自绘要连这些一起重做（见 DESIGN.md 里那张「换了什么 / 没换什么」的表）。
            ForEach(RandomString.CharacterClass.allCases) { characterClass in
                Toggle(
                    characterClass.title,
                    isOn: Binding(
                        get: { model.binding(for: characterClass) },
                        set: { model.set(characterClass, enabled: $0) }
                    )
                )
                .toggleStyle(.checkbox)
            }

            Spacer(minLength: Theme.Spacing.md)

            Toggle("每类至少一个", isOn: $model.options.guaranteeEachClass)
                .toggleStyle(.checkbox)
                .help("选中的每一类都保证出现至少一次，然后整串洗牌")
        }
        .font(Theme.Typo.body)
        .foregroundStyle(Theme.Ink.primary)
    }

    @ViewBuilder
    private var result: some View {
        if model.hasNoClasses {
            NoticeView(
                .warning,
                title: "至少选一类字符",
                message: "四类全不选就没有字符可挑了。勾上任意一类，结果会立刻出现。"
            )
        } else {
            results
        }
    }

    /// 十行一片。不用 `ToolOutput`（那是一整块文本 + 一个复制按钮）——
    /// 这里每一行都是一个**候选**，用户要的是挑一个拿走，
    /// 所以复制按钮得跟到行上；「全部复制」是顺带的，不是主路径。
    private var results: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                Text("结果")
                    .font(Theme.Typo.label)
                    .foregroundStyle(Theme.Ink.secondary)

                Text("\(RandomStringModel.batchSize) 个 · 字符集 \(model.poolSize) 个 · 每个约 \(model.entropyBits) bit")
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Ink.tertiary)

                Spacer(minLength: Theme.Spacing.sm)

                CopyButton(model.joined, title: "全部复制")
            }

            VStack(spacing: 0) {
                // 十串里可能有一模一样的两串（短长度 + 小字符集时），
                // 所以 id 用下标，不用值本身 —— 用值会让 ForEach 把两行认成一行。
                ForEach(Array(model.values.enumerated()), id: \.offset) { index, value in
                    if index > 0 {
                        Hairline()
                    }
                    ResultLine(number: index + 1, value: value)
                }
            }
            .panel(.well, radius: Theme.Radius.control)
        }
    }

    /// 结果里的一行：编号、串本身、复制。
    ///
    /// 编号不是装饰 —— 十行等宽字符长得都一样，说「第三个」比说
    /// 「那个 k 开头的」快。它对辅助技术不单独存在，念的是整行。
    private struct ResultLine: View {
        let number: Int
        let value: String

        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var isHovering = false

        var body: some View {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                Text("\(number)")
                    .font(Theme.Typo.numeric)
                    .foregroundStyle(Theme.Ink.tertiary)
                    .frame(width: 18, alignment: .trailing)
                    .accessibilityHidden(true)

                // 不截断：128 位的密码要能整串看到。行会换行，行高不齐没关系 ——
                // 看不到自己刚生成的东西才是问题。
                Text(value)
                    .font(Theme.Typo.mono)
                    .foregroundStyle(Theme.Ink.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                CopyButton(value)
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
            .background {
                if isHovering {
                    RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                        .fill(Theme.Glass.hover)
                }
            }
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .animation(Theme.Motion.fast(reduceMotion: reduceMotion), value: isHovering)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("第 \(number) 个：\(value)")
        }
    }
}
