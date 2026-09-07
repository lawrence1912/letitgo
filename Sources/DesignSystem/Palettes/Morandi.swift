import AppCore

/// 莫兰迪：暖灰打底（色相 85），四个品牌角色全部降饱和。
///
/// 参照的是乔治·莫兰迪那些静物的调子 —— 石灰、亚麻、旧纸、烧过的陶土，
/// 几个脏色挨在一起，谁也不压过谁。放进一个工具界面里，它是**降噪**：
/// 一屏同时亮着六七个语义色时，高饱和会让它们互相打架，眼睛找不到该看哪儿。
/// 全部拉灰之后，唯一还敢响的那个东西（主按钮）就自动成了视线落点。
///
/// 色相是从上一版网页工具那套挪过来的（琥珀 52 → 陶土 62、深蓝 246 →
/// 雾霾蓝 238、绿 151 → 鼠尾草 150、红 27 → 干玫瑰 25）：
/// 降饱和 + 往灰里挪本来就是莫兰迪的定义，保住原色相等于没换色系。
/// 保下来的是四个**角色**和它们的色相家族。
///
/// 对比度不是估的，是算的，而且有测试兜着（`Tests/DesignSystemTests`）。
extension Palette {
    static let morandi = Palette(.morandi) { tint in
        // 图标色相：全部落在莫兰迪那几个脏色上，和四个品牌角色共用色环。
        switch tint {
        case .neutral: 85     // 暖灰，等于不上色
        case .warm: 62        // 陶土
        case .rose: 25        // 干玫瑰
        case .violet: 305     // 灰紫
        case .blue: 238       // 雾霾蓝
        case .teal: 195       // 灰青
        case .green: 150      // 鼠尾草
        case .indigo: 272     // 灰靛
        case .plum: 342       // 梅
        case .lime: 112       // 橄榄
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
            light: OKLCH(0.700, 0.080, 62,  alpha: 0.28), dark: OKLCH(0.800, 0.080, 62,  alpha: 0.40)
        )

        // MARK: 读写面
        /// 正文躺着的那块地：代码框、结果区、长文本。
        ///
        /// **它是唯一一块不上玻璃的表面**，而且必须不上 —— 玻璃会折射背后的
        /// 星球，一段等宽代码压在一片会动的折射上是读不下去的。
        /// 玻璃管的是 chrome 和控件，这一块管的是「拿来读、拿来改」的东西。
        case .well: Ramp(
            light: OKLCH(0.937, 0.010, 85), dark: OKLCH(0.233, 0.008, 85),
            lightHC: OKLCH(0.950, 0.006, 85), darkHC: OKLCH(0.170, 0.006, 85)
        )

        // MARK: 氛围底与光晕
        case .backdrop: Ramp(
            light: OKLCH(0.930, 0.012, 80), dark: OKLCH(0.195, 0.010, 80),
            lightHC: OKLCH(0.968, 0.006, 85), darkHC: OKLCH(0.150, 0.006, 85)
        )
        /// 干玫瑰。光晕是**深度**，不是装饰：峰值 chroma 0.05，24% 不透明。
        case .auraLead: Ramp(
            light: OKLCH(0.820, 0.050, 38, alpha: 0.24),
            dark: OKLCH(0.470, 0.050, 38, alpha: 0.13),
            lightHC: OKLCH(0.820, 0.050, 38, alpha: 0),
            darkHC: OKLCH(0.470, 0.055, 38, alpha: 0)
        )
        /// 鼠尾草。和干玫瑰是**邻近色** —— 莫兰迪的张力来自挨得很近的几个脏色
        /// 互相压着，不来自补色对撞。
        case .auraTrail: Ramp(
            light: OKLCH(0.845, 0.035, 158, alpha: 0.24),
            dark: OKLCH(0.470, 0.040, 158, alpha: 0.16),
            lightHC: OKLCH(0.845, 0.035, 158, alpha: 0),
            darkHC: OKLCH(0.470, 0.040, 158, alpha: 0)
        )

        // MARK: 这套主题不用的那几个槽位
        /// 第三团光晕、网格、尾部高光 —— 全透明就是「这套主题没有这些东西」。
        /// 星云那套才用得上（见 `Nebula.swift`）。
        case .auraDeep, .gridLine: Ramp(
            light: OKLCH(0, 0, 0, alpha: 0), dark: OKLCH(0, 0, 0, alpha: 0)
        )

        // MARK: 薄膜
        /// 悬停。合成后落在 content 和 panel 之间，可点的东西才用。
        case .hover: Ramp(
            light: OKLCH(0.700, 0.016, 80, alpha: 0.10),
            dark: OKLCH(0.995, 0.010, 85, alpha: 0.10),
            lightHC: OKLCH(0.920, 0.010, 85), darkHC: OKLCH(0.345, 0.008, 85)
        )

        // MARK: 边缘与投影
        case .border: Ramp(
            light: OKLCH(0.520, 0.016, 80, alpha: 0.20),
            dark: OKLCH(0.995, 0.010, 85, alpha: 0.21),
            lightHC: OKLCH(0.700, 0.014, 85), darkHC: OKLCH(0.520, 0.014, 85)
        )
        case .borderStrong: Ramp(
            light: OKLCH(0.420, 0.018, 80, alpha: 0.30),
            dark: OKLCH(0.995, 0.014, 85, alpha: 0.32),
            lightHC: OKLCH(0.560, 0.016, 85), darkHC: OKLCH(0.640, 0.016, 85)
        )

        case .ink: Ramp(
            light: OKLCH(0.255, 0.014, 75), dark: OKLCH(0.945, 0.006, 85),
            lightHC: OKLCH(0.160, 0.012, 75), darkHC: OKLCH(1.000, 0.000, 85)
        )
        case .inkSecondary: Ramp(
            light: OKLCH(0.395, 0.016, 75), dark: OKLCH(0.880, 0.010, 85),
            lightHC: OKLCH(0.330, 0.016, 75), darkHC: OKLCH(0.935, 0.008, 85)
        )
        case .inkTertiary: Ramp(
            light: OKLCH(0.483, 0.014, 75), dark: OKLCH(0.755, 0.012, 85),
            lightHC: OKLCH(0.425, 0.014, 75), darkHC: OKLCH(0.820, 0.010, 85)
        )

        // MARK: 陶土（accent）
        /// 焦点环：比 `accent` 亮一档、浓一档。深色档和 accent 同值 ——
        /// 那一档它本来就够亮了，深的是浅色档。
        case .focusRing: Ramp(
            light: OKLCH(0.605, 0.105, 62), dark: OKLCH(0.780, 0.070, 68),
            lightHC: OKLCH(0.385, 0.090, 62), darkHC: OKLCH(0.865, 0.072, 68)
        )
        case .accent: Ramp(
            light: OKLCH(0.480, 0.078, 62), dark: OKLCH(0.780, 0.070, 68),
            lightHC: OKLCH(0.385, 0.090, 62), darkHC: OKLCH(0.865, 0.072, 68)
        )
        /// 实心填充。**全屏唯一允许比周围响一档的东西**，即便如此 chroma 也只有 0.080 ——
        /// 「晒褪色的赤陶」。
        /// 它现在是**递给系统的那个颜色**（`.tint()` 和玻璃的 tint），字色由系统自己配。
        case .accentFill: Ramp(
            light: OKLCH(0.750, 0.080, 62), dark: OKLCH(0.745, 0.075, 68),
            lightHC: OKLCH(0.800, 0.085, 62), darkHC: OKLCH(0.800, 0.080, 68)
        )
        case .accentSoft: Ramp(
            light: OKLCH(0.880, 0.045, 62, alpha: 0.55),
            dark: OKLCH(0.340, 0.045, 68, alpha: 0.50),
            lightHC: OKLCH(0.945, 0.030, 62), darkHC: OKLCH(0.270, 0.036, 68)
        )
        case .accentSoftBorder: Ramp(
            light: OKLCH(0.800, 0.055, 62, alpha: 0.80),
            dark: OKLCH(0.490, 0.050, 68, alpha: 0.75),
            lightHC: OKLCH(0.740, 0.070, 62), darkHC: OKLCH(0.560, 0.060, 68)
        )
        case .info: Ramp(
            light: OKLCH(0.480, 0.048, 238), dark: OKLCH(0.775, 0.044, 238),
            lightHC: OKLCH(0.385, 0.060, 238), darkHC: OKLCH(0.865, 0.048, 238)
        )
        case .infoSoft: Ramp(
            light: OKLCH(0.880, 0.026, 238, alpha: 0.55),
            dark: OKLCH(0.340, 0.028, 238, alpha: 0.50),
            lightHC: OKLCH(0.945, 0.020, 238), darkHC: OKLCH(0.270, 0.024, 238)
        )
        case .infoSoftBorder: Ramp(
            light: OKLCH(0.800, 0.034, 238, alpha: 0.80),
            dark: OKLCH(0.490, 0.034, 238, alpha: 0.75),
            lightHC: OKLCH(0.740, 0.046, 238), darkHC: OKLCH(0.560, 0.042, 238)
        )
        case .success: Ramp(
            light: OKLCH(0.480, 0.058, 150), dark: OKLCH(0.770, 0.055, 152),
            lightHC: OKLCH(0.385, 0.070, 150), darkHC: OKLCH(0.865, 0.058, 152)
        )
        case .successSoft: Ramp(
            light: OKLCH(0.880, 0.038, 150, alpha: 0.55),
            dark: OKLCH(0.340, 0.038, 152, alpha: 0.50),
            lightHC: OKLCH(0.945, 0.026, 150), darkHC: OKLCH(0.270, 0.032, 152)
        )
        case .successSoftBorder: Ramp(
            light: OKLCH(0.800, 0.045, 150, alpha: 0.80),
            dark: OKLCH(0.490, 0.042, 152, alpha: 0.75),
            lightHC: OKLCH(0.740, 0.058, 150), darkHC: OKLCH(0.560, 0.050, 152)
        )
        /// 干玫瑰。四个角色里唯一留了一半饱和度的：
        /// **一个被调进壁纸里的警报不是警报。**
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
