import AppCore

/// 雾青：蓝灰打底（色相 235），青色点睛。
///
/// 和莫兰迪同一档克制 —— chroma 一律压在 0.06 上下，靠**色相**区分角色，
/// 不靠饱和度。所以这两套换来换去，界面的「响度」是一样的，
/// 变的只是它偏暖还是偏冷；玻璃的质感、层次的关系、一屏只有一个响亮按钮那条规矩，
/// 全部原样成立。
///
/// 角色分配和莫兰迪一一对应，只是色相挪到了蓝青那一侧：
///
/// | 角色 | 色相 | 是什么 |
/// |---|---|---|
/// | `accent` | 196 | 青。主操作、当前选中 |
/// | `info` | 258 | 蓝。信息态、拖放高亮 |
/// | `success` | 138 | 草绿。刻意压到 138 而不是 150 —— 离青太近会和 accent 糊掉 |
/// | `danger` | 25 | 红。仍然是四个里唯一留了一半饱和度的那个 |
///
/// 两团光晕是蓝（252）和青（196）—— 还是邻近色，不是补色。
///
/// 对比度不是估的，是算的，而且有测试兜着（`Tests/DesignSystemTests`）。
extension Palette {
    static let mist = Palette(.mist) { tint in
        // 图标色相：冷的那半边挪得更开一点 —— 这套主题本身就住在蓝青区，
        // 图标再挤在一起就分不出来了。
        switch tint {
        case .neutral: 235    // 蓝灰，等于不上色
        case .warm: 70        // 沙
        case .rose: 22        // 珊瑚
        case .violet: 295     // 蓝紫
        case .blue: 252       // 蓝
        case .teal: 196       // 青
        case .green: 145      // 绿
        case .indigo: 275     // 靛
        case .plum: 338       // 莓
        case .lime: 118       // 苔
        }
    } lookup: { token in
        switch token {

        // MARK: 氛围底与光晕
        case .backdrop: Ramp(
            light: OKLCH(0.930, 0.014, 235), dark: OKLCH(0.195, 0.012, 235),
            lightHC: OKLCH(0.968, 0.006, 235), darkHC: OKLCH(0.150, 0.008, 235)
        )
        /// 蓝。光晕是**深度**，不是装饰：峰值 chroma 0.05，24% 不透明。
        case .auraLead: Ramp(
            light: OKLCH(0.830, 0.050, 252, alpha: 0.24),
            dark: OKLCH(0.470, 0.055, 252, alpha: 0.14),
            lightHC: OKLCH(0.830, 0.050, 252, alpha: 0),
            darkHC: OKLCH(0.470, 0.055, 252, alpha: 0)
        )
        /// 青。和蓝是**邻近色**，不是补色。
        case .auraTrail: Ramp(
            light: OKLCH(0.850, 0.042, 196, alpha: 0.24),
            dark: OKLCH(0.470, 0.045, 196, alpha: 0.16),
            lightHC: OKLCH(0.850, 0.042, 196, alpha: 0),
            darkHC: OKLCH(0.470, 0.045, 196, alpha: 0)
        )

        // MARK: 薄膜
        case .glassChrome: Ramp(
            light: OKLCH(0.995, 0.005, 235, alpha: 0.34),
            dark: OKLCH(0.995, 0.007, 235, alpha: 0.035),
            lightHC: OKLCH(0.968, 0.006, 235), darkHC: OKLCH(0.150, 0.008, 235)
        )
        case .glassContent: Ramp(
            light: OKLCH(0.995, 0.005, 235, alpha: 0.62),
            dark: OKLCH(0.995, 0.007, 235, alpha: 0.065),
            lightHC: OKLCH(1.000, 0.000, 235), darkHC: OKLCH(0.200, 0.008, 235)
        )
        case .glassPanel: Ramp(
            light: OKLCH(0.995, 0.007, 235, alpha: 0.55),
            dark: OKLCH(0.995, 0.009, 235, alpha: 0.075),
            lightHC: OKLCH(0.990, 0.006, 235), darkHC: OKLCH(0.260, 0.008, 235)
        )
        case .glassWell: Ramp(
            light: OKLCH(0.520, 0.016, 235, alpha: 0.08),
            dark: OKLCH(0.030, 0.010, 235, alpha: 0.18),
            lightHC: OKLCH(0.950, 0.006, 235), darkHC: OKLCH(0.170, 0.008, 235)
        )
        case .glassFloating: Ramp(
            light: OKLCH(0.995, 0.005, 235, alpha: 0.78),
            dark: OKLCH(0.995, 0.007, 235, alpha: 0.085),
            lightHC: OKLCH(0.990, 0.006, 235), darkHC: OKLCH(0.260, 0.008, 235)
        )
        /// 悬停。合成后落在 content 和 panel 之间，可点的东西才用。
        case .glassHover: Ramp(
            light: OKLCH(0.700, 0.018, 235, alpha: 0.10),
            dark: OKLCH(0.995, 0.012, 235, alpha: 0.10),
            lightHC: OKLCH(0.920, 0.010, 235), darkHC: OKLCH(0.345, 0.010, 235)
        )

        // MARK: 边缘与投影
        case .glassRim: Ramp(
            light: OKLCH(0.520, 0.018, 235, alpha: 0.20),
            dark: OKLCH(0.995, 0.012, 235, alpha: 0.21),
            lightHC: OKLCH(0.700, 0.016, 235), darkHC: OKLCH(0.520, 0.016, 235)
        )
        case .glassRimStrong: Ramp(
            light: OKLCH(0.420, 0.020, 235, alpha: 0.30),
            dark: OKLCH(0.995, 0.016, 235, alpha: 0.32),
            lightHC: OKLCH(0.560, 0.018, 235), darkHC: OKLCH(0.640, 0.018, 235)
        )
        /// 左上那道高光，冷白。增强对比度下归零 —— 它是装饰，不承担信息。
        case .glassHighlight: Ramp(
            light: OKLCH(1.000, 0.004, 235, alpha: 0.85),
            dark: OKLCH(1.000, 0.004, 235, alpha: 0.28),
            lightHC: OKLCH(1.000, 0.004, 235, alpha: 0),
            darkHC: OKLCH(1.000, 0.004, 235, alpha: 0)
        )
        case .glassShadow: Ramp(
            light: OKLCH(0.30, 0.020, 250, alpha: 0.09),
            dark: OKLCH(0.04, 0.008, 250, alpha: 0.45)
        )
        case .glassShadowFloating: Ramp(
            light: OKLCH(0.30, 0.020, 250, alpha: 0.16),
            dark: OKLCH(0.04, 0.008, 250, alpha: 0.60)
        )

        // MARK: 实心替身（减弱透明度时用）
        /// 以下八个是按玻璃合成结果**反解**出来的：把薄膜压在氛围底上算出最终亮度，
        /// 再找同色相下亮度相同的实心色。所以开不开透明度，四层的观感一样。
        case .canvas: Ramp(
            light: OKLCH(0.952, 0.012, 235), dark: OKLCH(0.230, 0.010, 235),
            lightHC: OKLCH(0.968, 0.006, 235), darkHC: OKLCH(0.150, 0.008, 235)
        )
        case .content: Ramp(
            light: OKLCH(0.970, 0.012, 235), dark: OKLCH(0.260, 0.010, 235),
            lightHC: OKLCH(1.000, 0.000, 235), darkHC: OKLCH(0.200, 0.008, 235)
        )
        case .raised: Ramp(
            light: OKLCH(0.984, 0.012, 235), dark: OKLCH(0.326, 0.010, 235),
            lightHC: OKLCH(0.990, 0.006, 235), darkHC: OKLCH(0.260, 0.008, 235)
        )
        case .sunken: Ramp(
            light: OKLCH(0.937, 0.012, 235), dark: OKLCH(0.233, 0.010, 235),
            lightHC: OKLCH(0.950, 0.006, 235), darkHC: OKLCH(0.170, 0.008, 235)
        )
        case .hover: Ramp(
            light: OKLCH(0.928, 0.014, 235), dark: OKLCH(0.322, 0.012, 235),
            lightHC: OKLCH(0.920, 0.010, 235), darkHC: OKLCH(0.345, 0.010, 235)
        )
        case .border: Ramp(
            light: OKLCH(0.885, 0.016, 235), dark: OKLCH(0.437, 0.014, 235),
            lightHC: OKLCH(0.700, 0.016, 235), darkHC: OKLCH(0.520, 0.016, 235)
        )
        case .borderStrong: Ramp(
            light: OKLCH(0.816, 0.016, 235), dark: OKLCH(0.522, 0.014, 235),
            lightHC: OKLCH(0.560, 0.018, 235), darkHC: OKLCH(0.640, 0.018, 235)
        )
        case .shadow: Ramp(
            light: OKLCH(0.30, 0.020, 250, alpha: 0.10),
            dark: OKLCH(0.04, 0.008, 250, alpha: 0.50)
        )

        // MARK: 文字
        case .ink: Ramp(
            light: OKLCH(0.255, 0.016, 250), dark: OKLCH(0.945, 0.008, 235),
            lightHC: OKLCH(0.160, 0.014, 250), darkHC: OKLCH(1.000, 0.000, 235)
        )
        case .inkSecondary: Ramp(
            light: OKLCH(0.455, 0.018, 250), dark: OKLCH(0.775, 0.012, 235),
            lightHC: OKLCH(0.380, 0.018, 250), darkHC: OKLCH(0.860, 0.010, 235)
        )
        case .inkTertiary: Ramp(
            light: OKLCH(0.575, 0.016, 250), dark: OKLCH(0.675, 0.014, 235),
            lightHC: OKLCH(0.470, 0.016, 250), darkHC: OKLCH(0.760, 0.012, 235)
        )

        // MARK: 青（accent）
        case .accent: Ramp(
            light: OKLCH(0.480, 0.062, 196), dark: OKLCH(0.780, 0.058, 196),
            lightHC: OKLCH(0.385, 0.074, 196), darkHC: OKLCH(0.865, 0.060, 196)
        )
        /// 实心填充。**全屏唯一允许比周围响一档的东西**，即便如此 chroma 也只有 0.070。
        /// 配 `onAccent` 近黑字 8.4:1。
        case .accentFill: Ramp(
            light: OKLCH(0.760, 0.070, 196), dark: OKLCH(0.755, 0.065, 196),
            lightHC: OKLCH(0.810, 0.075, 196), darkHC: OKLCH(0.810, 0.070, 196)
        )
        case .accentSoft: Ramp(
            light: OKLCH(0.880, 0.038, 196, alpha: 0.55),
            dark: OKLCH(0.340, 0.040, 196, alpha: 0.50),
            lightHC: OKLCH(0.945, 0.026, 196), darkHC: OKLCH(0.270, 0.032, 196)
        )
        case .accentSoftBorder: Ramp(
            light: OKLCH(0.800, 0.046, 196, alpha: 0.80),
            dark: OKLCH(0.490, 0.044, 196, alpha: 0.75),
            lightHC: OKLCH(0.740, 0.060, 196), darkHC: OKLCH(0.560, 0.052, 196)
        )
        /// 压在 `accentFill` 上的近黑。**不能写死白色** —— 青色填充在两种外观下都是亮色。
        case .onAccent: Ramp(
            light: OKLCH(0.215, 0.022, 196), dark: OKLCH(0.195, 0.018, 196),
            lightHC: OKLCH(0.160, 0.020, 196), darkHC: OKLCH(0.150, 0.016, 196)
        )

        // MARK: 蓝 / 草绿 / 红
        case .info: Ramp(
            light: OKLCH(0.480, 0.052, 258), dark: OKLCH(0.775, 0.048, 258),
            lightHC: OKLCH(0.385, 0.064, 258), darkHC: OKLCH(0.865, 0.050, 258)
        )
        /// 提示条是通栏的，同样的 chroma 铺满一条会读成「一块蓝色横幅」——
        /// 所以 `infoSoft` 比别的 soft 再低一档。
        case .infoSoft: Ramp(
            light: OKLCH(0.880, 0.028, 258, alpha: 0.55),
            dark: OKLCH(0.340, 0.030, 258, alpha: 0.50),
            lightHC: OKLCH(0.945, 0.020, 258), darkHC: OKLCH(0.270, 0.026, 258)
        )
        case .infoSoftBorder: Ramp(
            light: OKLCH(0.800, 0.036, 258, alpha: 0.80),
            dark: OKLCH(0.490, 0.036, 258, alpha: 0.75),
            lightHC: OKLCH(0.740, 0.048, 258), darkHC: OKLCH(0.560, 0.044, 258)
        )

        case .success: Ramp(
            light: OKLCH(0.480, 0.058, 138), dark: OKLCH(0.770, 0.055, 140),
            lightHC: OKLCH(0.385, 0.070, 138), darkHC: OKLCH(0.865, 0.058, 140)
        )
        case .successSoft: Ramp(
            light: OKLCH(0.880, 0.038, 138, alpha: 0.55),
            dark: OKLCH(0.340, 0.038, 140, alpha: 0.50),
            lightHC: OKLCH(0.945, 0.026, 138), darkHC: OKLCH(0.270, 0.032, 140)
        )
        case .successSoftBorder: Ramp(
            light: OKLCH(0.800, 0.045, 138, alpha: 0.80),
            dark: OKLCH(0.490, 0.042, 140, alpha: 0.75),
            lightHC: OKLCH(0.740, 0.058, 138), darkHC: OKLCH(0.560, 0.050, 140)
        )

        /// 红。这套主题里它离其余三个角色最远（蓝 258 / 青 196 / 绿 138），
        /// 是四个里唯一留了一半饱和度的：**一个被调进壁纸里的警报不是警报。**
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
