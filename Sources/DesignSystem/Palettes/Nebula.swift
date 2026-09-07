import AppCore

/// 星云：暖炭打底（色相 45，深色外观 L 0.195），琥珀点睛。
///
/// 这套是唯一一个**把渐变当主角**的主题：氛围底上有三团光晕（琥珀 → 珊瑚 → 品红，
/// 沿着暖色那半边扫过一段光谱）压在一层 40pt 的细网格上，玻璃的右下角
/// 还留了一道玫瑰色的尾光。别的主题是「一块有厚度的表面」，这套是「一扇朝外的舷窗」。
///
/// **2026-09-03 从冷调换成暖调。** 底从蓝紫 275 挪到暖炭 45，accent 从霓虹青 200
/// 换成琥珀 78，三团光晕从「青 → 紫 → 品红」换成「琥珀 → 珊瑚 → 品红」。
/// 猎户座那一类星云本来就是暖的 —— 换掉的是**色温**，不是这套主题的结构：
/// 三团光晕、那层网格、右下的尾光、下面那三条规矩，一条没动。
///
/// **科幻风最容易翻车的地方是可读性**，所以这套守着三条自己的规矩：
///
/// 1. **霓虹只发给会动的东西**：accent（主操作 / 选中 / 落点）和四个语义色。
///    正文、次级文字、边框仍然是中性色 —— 一屏全是发光的字等于一屏都在喊。
/// 2. **光晕再亮也只是底**：峰值 alpha 0.34（浅色）/ 0.14（深色），且三团的中心
///    互相错开。合成结果全部进了对比度测试（`Tests/DesignSystemTests` 的亮度带里
///    连「压着一条网格线」那一格都算了），4.5:1 一格没让。
///
///    换暖之后这三团的**亮度**被测试逼着调过一轮：暖色在同一个 OKLCH 明度下
///    WCAG 亮度比冷色高（黄绿通道权重 0.72，蓝只有 0.07），照搬冷调那版的 L
///    会把深色外观的表面顶亮一档 —— 珊瑚色的图标压在悬停态上只剩 4.30:1。
///    所以浅色那档整体抬亮 0.03（往底色靠，压得更浅），深色那档压暗 0.06。
///    **同一个 L 在两种色温下不是同一件事**，这是换色温时唯一要重算的东西。
/// 3. **增强对比度下整套让位**：光晕、网格、尾光、斜光的 alpha 全归零，
///    退回一块干净的暖底 —— 科幻是气氛，气氛不该挡路。
///
/// **暖色有一件冷色没有的麻烦：色域。** 琥珀在 sRGB 里能用的 chroma 比青窄得多
/// （L 0.87 的琥珀最多 0.118，同一亮度的青能到 0.15 以上），越亮越窄。
/// 这套里每个琥珀值都贴着色域边留了一档余量 —— 顶着上限写的话，
/// `OKLCH.srgb` 会把超出的通道夹掉，夹出来的颜色和你写的不是同一个，
/// 而且**不会报错**，只会看着有点脏。
///
/// | 角色 | 色相 | 是什么 |
/// |---|---|---|
/// | `accent` | 78 | 琥珀。主操作、当前选中、拖放落点 |
/// | `info` | 300 | 紫。信息态 —— 暖底上唯一的冷色，正好当「不是你干的事」那一档 |
/// | `success` | 145 | 绿。离 accent 67 度 —— 「选中」和「做完了」得一眼分得开 |
/// | `danger` | 25 | 红。五套主题同一组值。离 accent 53 度 |
/// | 三团光晕 | 60 / 20 / 330 | 琥珀（左上）→ 珊瑚（右下）→ 品红（左下） |
extension Palette {
    static let nebula = Palette(.nebula) { tint in
        // 图标色相：这套底几乎不带亮度，彩色图标是侧边栏上最亮的东西，
        // 所以相邻两族之间留的角度比别的主题都大。
        // 中性那一族跟着底走（暖炭），别的族是**辨识色**，换色温时不动 ——
        // 「紫色那个是编解码」这条肌肉记忆不该因为换了个底就作废。
        switch tint {
        case .neutral: 45     // 暖炭，等于不上色
        case .warm: 65        // 沙
        case .rose: 15        // 珊瑚
        case .violet: 300     // 紫
        case .blue: 265       // 蓝
        case .teal: 200       // 青
        case .green: 145      // 绿
        case .indigo: 285     // 靛
        case .plum: 330       // 莓
        case .lime: 120       // 苔
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
            light: OKLCH(0.720, 0.130, 78,  alpha: 0.34), dark: OKLCH(0.830, 0.140, 78,  alpha: 0.52)
        )

        // MARK: 读写面
        /// 正文躺着的那块地：代码框、结果区、长文本。
        ///
        /// **它是唯一一块不上玻璃的表面**，而且必须不上 —— 玻璃会折射背后的
        /// 星球，一段等宽代码压在一片会动的折射上是读不下去的。
        /// 玻璃管的是 chrome 和控件，这一块管的是「拿来读、拿来改」的东西。
        case .well: Ramp(
            light: OKLCH(0.945, 0.012, 275), dark: OKLCH(0.190, 0.018, 275),
            lightHC: OKLCH(0.950, 0.004, 275), darkHC: OKLCH(0.140, 0.008, 275)
        )

        // MARK: 氛围底、光晕与网格
        case .backdrop: Ramp(
            light: OKLCH(0.945, 0.014, 45), dark: OKLCH(0.195, 0.028, 45),
            lightHC: OKLCH(0.975, 0.004, 45), darkHC: OKLCH(0.135, 0.008, 45)
        )
        /// 左上：琥珀。三团里最亮的一团，正对着侧边栏的顶。
        case .auraLead: Ramp(
            light: OKLCH(0.900, 0.058, 60, alpha: 0.34),
            dark: OKLCH(0.560, 0.105, 60, alpha: 0.14),
            lightHC: OKLCH(0.900, 0.058, 60, alpha: 0),
            darkHC: OKLCH(0.560, 0.105, 60, alpha: 0)
        )
        /// 右下：珊瑚。和琥珀**不是补色**（补色是青）—— 三团合起来是沿暖色那半边
        /// 扫过的一段光谱，不是两种颜色在对撞。
        case .auraTrail: Ramp(
            light: OKLCH(0.875, 0.056, 20, alpha: 0.32),
            dark: OKLCH(0.440, 0.125, 20, alpha: 0.13),
            lightHC: OKLCH(0.875, 0.056, 20, alpha: 0),
            darkHC: OKLCH(0.440, 0.125, 20, alpha: 0)
        )
        /// 左下：品红。最淡的一团，只负责把左下角从「黑」变成「有东西」。
        case .auraDeep: Ramp(
            light: OKLCH(0.890, 0.058, 330, alpha: 0.26),
            dark: OKLCH(0.405, 0.120, 330, alpha: 0.10),
            lightHC: OKLCH(0.890, 0.058, 330, alpha: 0),
            darkHC: OKLCH(0.405, 0.120, 330, alpha: 0)
        )
        /// 网格。40pt 一格，1px，5% 不透明 —— 要的是「扫一眼说不出哪里有线，
        /// 但知道这块表面是有刻度的」。增强对比度下归零。
        case .gridLine: Ramp(
            light: OKLCH(0.500, 0.020, 45, alpha: 0.055),
            dark: OKLCH(0.960, 0.018, 60, alpha: 0.050),
            lightHC: OKLCH(0.500, 0.020, 45, alpha: 0),
            darkHC: OKLCH(0.960, 0.018, 60, alpha: 0)
        )

        // MARK: 薄膜
        //
        // 深色那档比别的主题**薄**一档，而且是被测试逼出来的：
        // 底下是三团光晕加网格，薄膜再往上堆白，面板就亮到
        // 压在上面的次级文字只剩 3.6:1。这套主题的面板靠**边缘**立住
        // （暖色描边 + 玫瑰色尾光），不靠把自己刷白。
        /// 悬停。合成后落在 content 和 panel 之间，可点的东西才用。
        case .hover: Ramp(
            light: OKLCH(0.650, 0.016, 45, alpha: 0.10),
            dark: OKLCH(0.995, 0.016, 60, alpha: 0.075),
            lightHC: OKLCH(0.920, 0.008, 45), darkHC: OKLCH(0.320, 0.010, 45)
        )

        // MARK: 边缘、尾光与投影
        case .border: Ramp(
            light: OKLCH(0.480, 0.016, 45, alpha: 0.20),
            dark: OKLCH(0.995, 0.016, 60, alpha: 0.24),
            lightHC: OKLCH(0.680, 0.014, 45), darkHC: OKLCH(0.500, 0.014, 45)
        )
        case .borderStrong: Ramp(
            light: OKLCH(0.390, 0.018, 45, alpha: 0.32),
            dark: OKLCH(0.995, 0.020, 60, alpha: 0.36),
            lightHC: OKLCH(0.540, 0.016, 45), darkHC: OKLCH(0.630, 0.016, 45)
        )

        case .ink: Ramp(
            light: OKLCH(0.235, 0.020, 45), dark: OKLCH(0.960, 0.008, 45),
            lightHC: OKLCH(0.155, 0.014, 45), darkHC: OKLCH(1.000, 0.000, 45)
        )
        case .inkSecondary: Ramp(
            light: OKLCH(0.395, 0.022, 45), dark: OKLCH(0.900, 0.012, 45),
            lightHC: OKLCH(0.330, 0.018, 45), darkHC: OKLCH(0.905, 0.010, 45)
        )
        case .inkTertiary: Ramp(
            light: OKLCH(0.495, 0.020, 45), dark: OKLCH(0.770, 0.014, 45),
            lightHC: OKLCH(0.425, 0.016, 45), darkHC: OKLCH(0.790, 0.012, 45)
        )

        // MARK: 琥珀（accent）
        /// 焦点环：比 `accent` 亮一档、浓一档。深色档和 accent 同值 ——
        /// 那一档它本来就够亮了，深的是浅色档。
        case .focusRing: Ramp(
            light: OKLCH(0.600, 0.125, 78), dark: OKLCH(0.870, 0.105, 78),
            lightHC: OKLCH(0.385, 0.072, 78), darkHC: OKLCH(0.885, 0.092, 78)
        )
        case .accent: Ramp(
            light: OKLCH(0.470, 0.090, 78), dark: OKLCH(0.870, 0.105, 78),
            lightHC: OKLCH(0.385, 0.072, 78), darkHC: OKLCH(0.885, 0.092, 78)
        )
        /// 实心填充。**全屏唯一允许比周围响一档的东西** ——
        /// 它现在是**递给系统的那个颜色**（`.tint()` 和玻璃的 tint），字色由系统自己配。
        case .accentFill: Ramp(
            light: OKLCH(0.800, 0.150, 78), dark: OKLCH(0.800, 0.150, 78),
            lightHC: OKLCH(0.830, 0.145, 78), darkHC: OKLCH(0.830, 0.145, 78)
        )
        case .accentSoft: Ramp(
            light: OKLCH(0.880, 0.052, 78, alpha: 0.55),
            dark: OKLCH(0.345, 0.060, 78, alpha: 0.55),
            lightHC: OKLCH(0.945, 0.032, 78), darkHC: OKLCH(0.260, 0.042, 78)
        )
        case .accentSoftBorder: Ramp(
            light: OKLCH(0.795, 0.070, 78, alpha: 0.80),
            dark: OKLCH(0.500, 0.080, 78, alpha: 0.80),
            lightHC: OKLCH(0.735, 0.085, 78), darkHC: OKLCH(0.565, 0.080, 78)
        )
        case .info: Ramp(
            light: OKLCH(0.478, 0.085, 300), dark: OKLCH(0.848, 0.080, 300),
            lightHC: OKLCH(0.382, 0.098, 300), darkHC: OKLCH(0.870, 0.082, 300)
        )
        /// 提示条是通栏的，同样的 chroma 铺满一条会读成「一块紫色横幅」——
        /// 所以 `infoSoft` 比别的 soft 再低一档。
        case .infoSoft: Ramp(
            light: OKLCH(0.885, 0.040, 300, alpha: 0.55),
            dark: OKLCH(0.345, 0.048, 300, alpha: 0.50),
            lightHC: OKLCH(0.948, 0.026, 300), darkHC: OKLCH(0.265, 0.036, 300)
        )
        case .infoSoftBorder: Ramp(
            light: OKLCH(0.800, 0.052, 300, alpha: 0.80),
            dark: OKLCH(0.495, 0.058, 300, alpha: 0.75),
            lightHC: OKLCH(0.740, 0.066, 300), darkHC: OKLCH(0.560, 0.062, 300)
        )

        case .success: Ramp(
            light: OKLCH(0.478, 0.072, 145), dark: OKLCH(0.845, 0.068, 145),
            lightHC: OKLCH(0.382, 0.084, 145), darkHC: OKLCH(0.870, 0.070, 145)
        )
        case .successSoft: Ramp(
            light: OKLCH(0.885, 0.044, 145, alpha: 0.55),
            dark: OKLCH(0.345, 0.048, 145, alpha: 0.50),
            lightHC: OKLCH(0.948, 0.030, 145), darkHC: OKLCH(0.265, 0.038, 145)
        )
        case .successSoftBorder: Ramp(
            light: OKLCH(0.800, 0.054, 145, alpha: 0.80),
            dark: OKLCH(0.495, 0.056, 145, alpha: 0.75),
            lightHC: OKLCH(0.740, 0.068, 145), darkHC: OKLCH(0.560, 0.060, 145)
        )

        /// 红。chroma 和另外四套是**同一个值**（0.105），只有深色那档的亮度
        /// 从 0.790 提到 0.850 —— 理由和上面的文字一样：这套的面板亮一档。
        /// 一个被调进星云里的警报不是警报。
        case .danger: Ramp(
            light: OKLCH(0.480, 0.105, 25), dark: OKLCH(0.850, 0.095, 25),
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
