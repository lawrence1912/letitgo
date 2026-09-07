import AppCore

/// 素白：中性灰打底，石墨点睛。
///
/// 前两套是**降饱和**，这一套是**不上色**：表面、文字、玻璃、光晕的 chroma 一律是 0，
/// 所以下面所有中性色的色相位都写 `0` —— 它不参与任何计算，写别的数只会让人
/// 以为它有意义。掺一点黄就是莫兰迪，掺一点蓝就是雾青，白灰的价值恰恰在于它一点不掺。
///
/// 色相没了之后有两件事得重新安排。
///
/// ## 一、强调色改用明度的两端
///
/// 前两套的 `accent` 是个中间调的颜色（陶土 / 青），靠**色相**从灰底里跳出来。
/// 这套跳不出来 —— 一个中间调的灰按钮读出来是「这个按钮是灰的（禁用了）」。
/// 所以强调色走到色阶的尽头：浅色外观下是近黑（比正文还深一档），
/// 深色外观下是近白（比正文还亮一档）。
///
/// 于是有条一以贯之的规矩：**选中 / 主操作 = 往强调色那一端多走一步，
/// 悬停只是浮起来一点。** 两者在明度上分得开，不靠色相：
/// 浅色下选中块合成出来是 #d7d7d7、悬停 #e5e5e5；深色下选中块 #434343、悬停 #323232。
/// 前两套里这两个状态是**一个偏色一个不偏色**，这套只能是**一个更远一个更近**。
///
/// ## 二、只剩三个角色还带颜色
///
/// `accent` 变成石墨之后，蓝 / 绿 / 红是整个界面上仅有的颜色。周围没有别的颜色
/// 跟它们抢，chroma 反而可以再压一档（info 0.045 / success 0.052，比雾青还低）。
///
/// 只有 `danger` 照旧留着 0.105：**一个被调进壁纸里的警报不是警报。**
/// 在一片全灰的界面里它是唯一一处红，比在前两套里还更跳 —— 这正是想要的。
///
/// 两团光晕这里也没有色相可分，只剩明暗：左上那团提亮，右下那团压暗，
/// 合起来是一张纸上的一道斜光。它给玻璃提供起伏这件事原样成立。
///
/// 对比度不是估的，是算的，而且有测试兜着（`Tests/DesignSystemTests`）。
extension Palette {
    static let plain = Palette(.plain) { tint in
        // 图标色相：壳全灰了，这七族就是这套主题里仅有的彩色，彼此该分得越开越好，
        // 所以角度按色环摊平了排。族的归属仍然和另外两套一一对应 ——
        // 「紫色那个是编解码」这条肌肉记忆要能跨主题带过去。
        switch tint {
        case .neutral: 265    // 冷灰。chroma 被压到 0.013，等于不上色
        case .warm: 68        // 沙
        case .rose: 20        // 珊瑚
        case .violet: 300     // 紫
        case .blue: 250       // 蓝
        case .teal: 195       // 青
        case .green: 150      // 绿
        case .indigo: 275     // 靛
        case .plum: 340       // 莓
        case .lime: 115       // 苔
        }
    } lookup: { token in
        switch token {

        /// 左上的镜面高光。**它不进对比度合成链** —— 1px 的边不会压在正文底下，
        /// 所以它可以比任何一个面都亮。玻璃的厚度全靠它。
        case .rimSpecular: Ramp(
            light: OKLCH(1.000, 0.000, 0, alpha: 0.85), dark: OKLCH(1.000, 0.000, 0, alpha: 0.62)
        )
        /// 右下的色散边。有厚度的玻璃会分光：一条边偏冷白，另一条偏主题自己的色。
        case .rimDispersion: Ramp(
            light: OKLCH(0.600, 0.000, 0,   alpha: 0.24), dark: OKLCH(0.870, 0.000, 0,   alpha: 0.34)
        )

        // MARK: 读写面
        /// 正文躺着的那块地：代码框、结果区、长文本。
        ///
        /// **它是唯一一块不上玻璃的表面**，而且必须不上 —— 玻璃会折射背后的
        /// 星球，一段等宽代码压在一片会动的折射上是读不下去的。
        /// 玻璃管的是 chrome 和控件，这一块管的是「拿来读、拿来改」的东西。
        case .well: Ramp(
            light: OKLCH(0.933, 0.000, 0), dark: OKLCH(0.229, 0.000, 0),
            lightHC: OKLCH(0.950, 0.000, 0), darkHC: OKLCH(0.170, 0.000, 0)
        )

        // MARK: 氛围底与光晕
        case .backdrop: Ramp(
            light: OKLCH(0.920, 0.000, 0), dark: OKLCH(0.190, 0.000, 0),
            lightHC: OKLCH(0.968, 0.000, 0), darkHC: OKLCH(0.145, 0.000, 0)
        )
        /// 提亮的那团（左上）。这套里光晕**只剩明暗**，所以它是光，不是颜色。
        case .auraLead: Ramp(
            light: OKLCH(1.000, 0.000, 0, alpha: 0.28),
            dark: OKLCH(0.330, 0.000, 0, alpha: 0.30),
            lightHC: OKLCH(1.000, 0.000, 0, alpha: 0),
            darkHC: OKLCH(0.330, 0.000, 0, alpha: 0)
        )
        /// 压暗的那团（右下）。一亮一暗合起来是斜光扫过纸面 ——
        /// 前两套靠两个邻近色互相压，这套靠一道明暗。
        case .auraTrail: Ramp(
            light: OKLCH(0.825, 0.000, 0, alpha: 0.20),
            dark: OKLCH(0.110, 0.000, 0, alpha: 0.28),
            lightHC: OKLCH(0.825, 0.000, 0, alpha: 0),
            darkHC: OKLCH(0.110, 0.000, 0, alpha: 0)
        )

        // MARK: 这套主题不用的那几个槽位
        /// 第三团光晕、网格、尾部高光 —— 全透明就是「这套主题没有这些东西」。
        /// 星云那套才用得上（见 `Nebula.swift`）。
        case .auraDeep, .gridLine: Ramp(
            light: OKLCH(0, 0, 0, alpha: 0), dark: OKLCH(0, 0, 0, alpha: 0)
        )

        // MARK: 薄膜
        //
        // alpha 和另外两套**一个字不差** —— 玻璃的厚度是材质，不是色板。
        // 换主题只该换颜色，不该换手感。
        /// 悬停。合成后落在 content 和 panel 之间，可点的东西才用。
        case .hover: Ramp(
            light: OKLCH(0.700, 0.000, 0, alpha: 0.10),
            dark: OKLCH(0.995, 0.000, 0, alpha: 0.10),
            lightHC: OKLCH(0.920, 0.000, 0), darkHC: OKLCH(0.345, 0.000, 0)
        )

        // MARK: 边缘与投影
        case .border: Ramp(
            light: OKLCH(0.520, 0.000, 0, alpha: 0.20),
            dark: OKLCH(0.995, 0.000, 0, alpha: 0.21),
            lightHC: OKLCH(0.700, 0.000, 0), darkHC: OKLCH(0.520, 0.000, 0)
        )
        case .borderStrong: Ramp(
            light: OKLCH(0.420, 0.000, 0, alpha: 0.30),
            dark: OKLCH(0.995, 0.000, 0, alpha: 0.32),
            lightHC: OKLCH(0.560, 0.000, 0), darkHC: OKLCH(0.640, 0.000, 0)
        )

        case .ink: Ramp(
            light: OKLCH(0.255, 0.000, 0), dark: OKLCH(0.945, 0.000, 0),
            lightHC: OKLCH(0.160, 0.000, 0), darkHC: OKLCH(1.000, 0.000, 0)
        )
        case .inkSecondary: Ramp(
            light: OKLCH(0.400, 0.000, 0), dark: OKLCH(0.855, 0.000, 0),
            lightHC: OKLCH(0.330, 0.000, 0), darkHC: OKLCH(0.935, 0.000, 0)
        )
        case .inkTertiary: Ramp(
            light: OKLCH(0.500, 0.000, 0), dark: OKLCH(0.730, 0.000, 0),
            lightHC: OKLCH(0.425, 0.000, 0), darkHC: OKLCH(0.820, 0.000, 0)
        )

        // MARK: 石墨（accent）
        /// 强调色**文字 / 图标**：色阶的尽头，比正文还多走一档。
        /// 「选中」在这套主题里是**更黑 / 更白**，不是「变成另一个颜色」。
        /// 焦点环：比 `accent` 亮一档、浓一档。深色档和 accent 同值 ——
        /// 那一档它本来就够亮了，深的是浅色档。
        case .focusRing: Ramp(
            light: OKLCH(0.400, 0.000, 0), dark: OKLCH(0.995, 0.000, 0),
            lightHC: OKLCH(0.130, 0.000, 0), darkHC: OKLCH(1.000, 0.000, 0)
        )
        case .accent: Ramp(
            light: OKLCH(0.185, 0.000, 0), dark: OKLCH(0.995, 0.000, 0),
            lightHC: OKLCH(0.130, 0.000, 0), darkHC: OKLCH(1.000, 0.000, 0)
        )
        /// 实心填充。**全屏唯一允许比周围响一档的东西** —— 这套里「响」不是饱和度，
        /// 是明度落差：浅色下一块石墨压在近白纸上，深色下一块近白压在深灰上。
        /// 它现在是**递给系统的那个颜色**（`.tint()` 和玻璃的 tint），字色由系统自己配。
        case .accentFill: Ramp(
            light: OKLCH(0.285, 0.000, 0), dark: OKLCH(0.930, 0.000, 0),
            lightHC: OKLCH(0.250, 0.000, 0), darkHC: OKLCH(0.965, 0.000, 0)
        )
        /// 选中块。刻意压得比另外两套重（浅色 alpha 0.40，深色反着往亮里走）——
        /// 没有色相可认的时候，它和悬停之间只剩明度差这一条线索。
        case .accentSoft: Ramp(
            light: OKLCH(0.780, 0.000, 0, alpha: 0.40),
            dark: OKLCH(0.700, 0.000, 0, alpha: 0.30),
            lightHC: OKLCH(0.855, 0.000, 0), darkHC: OKLCH(0.430, 0.000, 0)
        )
        case .accentSoftBorder: Ramp(
            light: OKLCH(0.620, 0.000, 0, alpha: 0.55),
            dark: OKLCH(0.780, 0.000, 0, alpha: 0.45),
            lightHC: OKLCH(0.520, 0.000, 0), darkHC: OKLCH(0.680, 0.000, 0)
        )

        case .info: Ramp(
            light: OKLCH(0.480, 0.045, 250), dark: OKLCH(0.775, 0.042, 250),
            lightHC: OKLCH(0.385, 0.058, 250), darkHC: OKLCH(0.865, 0.045, 250)
        )
        /// 提示条是通栏的，同样的 chroma 铺满一条会读成「一块蓝色横幅」——
        /// 所以 `infoSoft` 比别的 soft 再低一档。
        case .infoSoft: Ramp(
            light: OKLCH(0.880, 0.024, 250, alpha: 0.55),
            dark: OKLCH(0.340, 0.026, 250, alpha: 0.50),
            lightHC: OKLCH(0.945, 0.018, 250), darkHC: OKLCH(0.270, 0.022, 250)
        )
        case .infoSoftBorder: Ramp(
            light: OKLCH(0.800, 0.032, 250, alpha: 0.80),
            dark: OKLCH(0.490, 0.032, 250, alpha: 0.75),
            lightHC: OKLCH(0.740, 0.044, 250), darkHC: OKLCH(0.560, 0.040, 250)
        )

        case .success: Ramp(
            light: OKLCH(0.480, 0.052, 148), dark: OKLCH(0.770, 0.050, 150),
            lightHC: OKLCH(0.385, 0.064, 148), darkHC: OKLCH(0.865, 0.052, 150)
        )
        case .successSoft: Ramp(
            light: OKLCH(0.880, 0.034, 148, alpha: 0.55),
            dark: OKLCH(0.340, 0.034, 150, alpha: 0.50),
            lightHC: OKLCH(0.945, 0.024, 148), darkHC: OKLCH(0.270, 0.028, 150)
        )
        case .successSoftBorder: Ramp(
            light: OKLCH(0.800, 0.040, 148, alpha: 0.80),
            dark: OKLCH(0.490, 0.038, 150, alpha: 0.75),
            lightHC: OKLCH(0.740, 0.052, 148), darkHC: OKLCH(0.560, 0.046, 150)
        )

        /// 红。三套主题里一模一样的一组值 —— 它是唯一一个**不该跟着主题走**的角色，
        /// 而在这套全灰的界面里，它是屏幕上唯一一处饱和色。
        case .danger: Ramp(
            light: OKLCH(0.480, 0.105, 25), dark: OKLCH(0.790, 0.095, 25),
            lightHC: OKLCH(0.385, 0.122, 25), darkHC: OKLCH(0.885, 0.095, 25)
        )
        case .dangerSoft: Ramp(
            light: OKLCH(0.880, 0.050, 25, alpha: 0.55),
            dark: OKLCH(0.340, 0.050, 25, alpha: 0.50),
            lightHC: OKLCH(0.945, 0.034, 25), darkHC: OKLCH(0.270, 0.042, 25)
        )
        case .dangerSoftBorder: Ramp(
            light: OKLCH(0.800, 0.060, 25, alpha: 0.80),
            dark: OKLCH(0.490, 0.056, 25, alpha: 0.75),
            lightHC: OKLCH(0.740, 0.078, 25), darkHC: OKLCH(0.560, 0.068, 25)
        )
        }
    }
}
