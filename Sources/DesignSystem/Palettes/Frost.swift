import AppCore

/// 霜白：近白打底（色相 228 的冷蓝灰），湖蓝点睛。
///
/// 这套是三套里**最亮、最干净**的一档 —— 「清爽简洁」不是靠加东西做出来的，
/// 是靠把底色抬到近白、把中性色的 chroma 压到 0.01 以下做出来的：
/// 一屏几乎只剩下白、字、和一处湖蓝。
///
/// | 和另外两套的区别 | 莫兰迪 | 雾青 | 霜白 |
/// |---|---|---|---|
/// | 底（浅色外观） | L 0.945 暖灰 | L 0.952 蓝灰 | **L 0.968 近白** |
/// | 中性 chroma | 0.014 | 0.012 | **0.007** |
/// | accent | 陶土 45 | 青 196 | **湖蓝 212，chroma 高一档** |
///
/// **玻璃在这套里最明显。** 底色越亮、薄膜越透，「一块玻璃压在另一块上」
/// 就越靠那圈边缘高光和投影来交代 —— 所以这套把高光提到 0.92、
/// 薄膜的 alpha 各降一档：看到的是层与层之间的**边界**，不是一层层堆起来的灰。
///
/// 角色分配：
///
/// | 角色 | 色相 | 是什么 |
/// |---|---|---|
/// | `accent` | 212 | 湖蓝。主操作、当前选中、拖放落点 |
/// | `info` | 255 | 蓝。信息态 |
/// | `success` | 148 | 绿。离 accent 64 度 —— 「选中」和「做完了」同屏出现，不能是同一种青 |
/// | `danger` | 25 | 红。四个里唯一留了一半饱和度的 —— 警报不该被调进壁纸 |
///
/// 对比度不是估的，是算的，而且有测试兜着（`Tests/DesignSystemTests`）。
extension Palette {
    static let frost = Palette(.frost) { tint in
        // 图标色相。底色本身几乎没有颜色，所以这套的图标是全场唯一的彩色，
        // 相邻两族之间留的角度比别的主题更大一点。
        switch tint {
        case .neutral: 228    // 冷灰，等于不上色
        case .warm: 68        // 沙
        case .rose: 20        // 珊瑚
        case .violet: 298     // 蓝紫
        case .blue: 250       // 蓝
        case .teal: 190       // 湖蓝
        case .green: 148      // 绿
        case .indigo: 272     // 靛
        case .plum: 335       // 莓
        case .lime: 116       // 苔
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
            light: OKLCH(0.700, 0.090, 212, alpha: 0.30), dark: OKLCH(0.810, 0.095, 212, alpha: 0.44)
        )

        // MARK: 读写面
        /// 正文躺着的那块地：代码框、结果区、长文本。
        ///
        /// **它是唯一一块不上玻璃的表面**，而且必须不上 —— 玻璃会折射背后的
        /// 星球，一段等宽代码压在一片会动的折射上是读不下去的。
        /// 玻璃管的是 chrome 和控件，这一块管的是「拿来读、拿来改」的东西。
        case .well: Ramp(
            light: OKLCH(0.952, 0.007, 228), dark: OKLCH(0.229, 0.009, 228),
            lightHC: OKLCH(0.955, 0.004, 228), darkHC: OKLCH(0.165, 0.006, 228)
        )

        // MARK: 氛围底与光晕
        case .backdrop: Ramp(
            light: OKLCH(0.955, 0.008, 228), dark: OKLCH(0.190, 0.010, 228),
            lightHC: OKLCH(0.975, 0.004, 228), darkHC: OKLCH(0.145, 0.006, 228)
        )
        /// 湖蓝。光晕是**深度**，不是装饰 —— 这套的两团比另外两套还淡一档，
        /// 近白的底上一团有颜色的雾会立刻变成「渐变背景」。
        case .auraLead: Ramp(
            light: OKLCH(0.880, 0.036, 200, alpha: 0.22),
            dark: OKLCH(0.470, 0.050, 200, alpha: 0.14),
            lightHC: OKLCH(0.880, 0.036, 200, alpha: 0),
            darkHC: OKLCH(0.470, 0.050, 200, alpha: 0)
        )
        /// 蓝。和湖蓝是**邻近色**，不是补色。
        case .auraTrail: Ramp(
            light: OKLCH(0.870, 0.032, 250, alpha: 0.20),
            dark: OKLCH(0.470, 0.045, 250, alpha: 0.15),
            lightHC: OKLCH(0.870, 0.032, 250, alpha: 0),
            darkHC: OKLCH(0.470, 0.045, 250, alpha: 0)
        )

        // MARK: 这套主题不用的那几个槽位
        /// 第三团光晕、网格、尾部高光 —— 全透明就是「这套主题没有这些东西」。
        /// 星云那套才用得上（见 `Nebula.swift`）。
        case .auraDeep, .gridLine: Ramp(
            light: OKLCH(0, 0, 0, alpha: 0), dark: OKLCH(0, 0, 0, alpha: 0)
        )

        // MARK: 薄膜
        //
        // alpha 全线比雾青低一档：底已经够亮了，薄膜再厚一点，
        // 玻璃就从「透明的一层」变成「白色的一块」。
        /// 悬停。合成后落在 content 和 panel 之间，可点的东西才用。
        case .hover: Ramp(
            light: OKLCH(0.680, 0.014, 228, alpha: 0.10),
            dark: OKLCH(0.995, 0.012, 228, alpha: 0.10),
            lightHC: OKLCH(0.925, 0.008, 228), darkHC: OKLCH(0.340, 0.008, 228)
        )

        // MARK: 边缘与投影
        //
        // 这套的边缘比另外两套**重要**：底色近白，薄膜又薄，
        // 没有这圈发丝线的话两块玻璃之间就真的看不出界。
        case .border: Ramp(
            light: OKLCH(0.500, 0.014, 228, alpha: 0.22),
            dark: OKLCH(0.995, 0.010, 228, alpha: 0.21),
            lightHC: OKLCH(0.690, 0.012, 228), darkHC: OKLCH(0.515, 0.012, 228)
        )
        case .borderStrong: Ramp(
            light: OKLCH(0.400, 0.016, 228, alpha: 0.32),
            dark: OKLCH(0.995, 0.014, 228, alpha: 0.32),
            lightHC: OKLCH(0.550, 0.014, 228), darkHC: OKLCH(0.635, 0.014, 228)
        )

        case .ink: Ramp(
            light: OKLCH(0.245, 0.014, 240), dark: OKLCH(0.945, 0.006, 228),
            lightHC: OKLCH(0.155, 0.012, 240), darkHC: OKLCH(1.000, 0.000, 228)
        )
        case .inkSecondary: Ramp(
            light: OKLCH(0.410, 0.016, 240), dark: OKLCH(0.880, 0.010, 228),
            lightHC: OKLCH(0.335, 0.016, 240), darkHC: OKLCH(0.930, 0.008, 228)
        )
        case .inkTertiary: Ramp(
            light: OKLCH(0.505, 0.014, 240), dark: OKLCH(0.760, 0.012, 228),
            lightHC: OKLCH(0.425, 0.014, 240), darkHC: OKLCH(0.815, 0.010, 228)
        )

        // MARK: 湖蓝（accent）
        /// 焦点环：比 `accent` 亮一档、浓一档。深色档和 accent 同值 ——
        /// 那一档它本来就够亮了，深的是浅色档。
        case .focusRing: Ramp(
            light: OKLCH(0.600, 0.110, 212), dark: OKLCH(0.782, 0.070, 212),
            lightHC: OKLCH(0.382, 0.090, 212), darkHC: OKLCH(0.868, 0.072, 212)
        )
        case .accent: Ramp(
            light: OKLCH(0.478, 0.078, 212), dark: OKLCH(0.782, 0.070, 212),
            lightHC: OKLCH(0.382, 0.090, 212), darkHC: OKLCH(0.868, 0.072, 212)
        )
        /// 实心填充。**全屏唯一允许比周围响一档的东西**。
        /// 它现在是**递给系统的那个颜色**（`.tint()` 和玻璃的 tint），字色由系统自己配。
        case .accentFill: Ramp(
            light: OKLCH(0.755, 0.085, 212), dark: OKLCH(0.752, 0.080, 212),
            lightHC: OKLCH(0.805, 0.090, 212), darkHC: OKLCH(0.805, 0.085, 212)
        )
        case .accentSoft: Ramp(
            light: OKLCH(0.885, 0.042, 212, alpha: 0.55),
            dark: OKLCH(0.340, 0.045, 212, alpha: 0.50),
            lightHC: OKLCH(0.948, 0.028, 212), darkHC: OKLCH(0.268, 0.036, 212)
        )
        case .accentSoftBorder: Ramp(
            light: OKLCH(0.800, 0.052, 212, alpha: 0.80),
            dark: OKLCH(0.490, 0.050, 212, alpha: 0.75),
            lightHC: OKLCH(0.738, 0.066, 212), darkHC: OKLCH(0.558, 0.058, 212)
        )
        case .info: Ramp(
            light: OKLCH(0.478, 0.058, 255), dark: OKLCH(0.775, 0.052, 255),
            lightHC: OKLCH(0.382, 0.070, 255), darkHC: OKLCH(0.865, 0.054, 255)
        )
        /// 提示条是通栏的，同样的 chroma 铺满一条会读成「一块蓝色横幅」——
        /// 所以 `infoSoft` 比别的 soft 再低一档。
        case .infoSoft: Ramp(
            light: OKLCH(0.885, 0.030, 255, alpha: 0.55),
            dark: OKLCH(0.340, 0.032, 255, alpha: 0.50),
            lightHC: OKLCH(0.948, 0.022, 255), darkHC: OKLCH(0.268, 0.028, 255)
        )
        case .infoSoftBorder: Ramp(
            light: OKLCH(0.800, 0.040, 255, alpha: 0.80),
            dark: OKLCH(0.490, 0.040, 255, alpha: 0.75),
            lightHC: OKLCH(0.738, 0.052, 255), darkHC: OKLCH(0.558, 0.048, 255)
        )

        /// 绿。「已完成」那一列的计数、勾选框的完成态都走它。
        ///
        /// 148 离 accent 的 212 有 64 度。**这个距离是量出来的，不是拍的**：
        /// 第一版 accent 放在 188，出图一看，选中的卡和勾掉的卡是同一种青 ——
        /// 「这张被选中」和「这件做完了」在一块板上必须一眼分得开。
        case .success: Ramp(
            light: OKLCH(0.478, 0.062, 148), dark: OKLCH(0.770, 0.058, 150),
            lightHC: OKLCH(0.382, 0.074, 148), darkHC: OKLCH(0.865, 0.060, 150)
        )
        case .successSoft: Ramp(
            light: OKLCH(0.885, 0.040, 148, alpha: 0.55),
            dark: OKLCH(0.340, 0.040, 150, alpha: 0.50),
            lightHC: OKLCH(0.948, 0.028, 148), darkHC: OKLCH(0.268, 0.034, 150)
        )
        case .successSoftBorder: Ramp(
            light: OKLCH(0.800, 0.048, 148, alpha: 0.80),
            dark: OKLCH(0.490, 0.044, 150, alpha: 0.75),
            lightHC: OKLCH(0.738, 0.060, 148), darkHC: OKLCH(0.558, 0.052, 150)
        )

        /// 红。四套主题用的是**同一组值** —— 一个被调进壁纸里的警报不是警报。
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
