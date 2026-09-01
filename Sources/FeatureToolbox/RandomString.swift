import Foundation

/// 随机串生成的纯函数。密码、密钥、测试数据都用它。
///
/// ## 三个容易写错的地方
///
/// 1. **随机源**。`Int.random(in:)` / `randomElement()` 走的是
///    `SystemRandomNumberGenerator`，在 Apple 平台上是 CSPRNG（`arc4random_buf`）。
///    Java 那边对应的是 `SecureRandom`，**不是** `Math.random()` / `new Random()` ——
///    后两个是可预测的线性同余，拿来生成密码等于没生成。
///
/// 2. **取模偏置**。`bytes[i] % alphabet.count` 这种写法会让排在前面的字符
///    出现得更频繁。这里用 `randomElement(using:)`，它内部按范围重采样，没有偏置。
///
/// 3. **洗牌**。「保证每类至少一个」的常见写法是先各取一个再补齐 ——
///    忘了洗牌的话，**前几位永远按类别顺序排**（第一位一定是小写、第二位一定是大写…），
///    等于把密码的前几位送人。
public enum RandomString {

    public enum CharacterClass: String, CaseIterable, Identifiable, Hashable, Sendable {
        case lowercase
        case uppercase
        case digits
        case symbols

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .lowercase: "小写"
            case .uppercase: "大写"
            case .digits: "数字"
            case .symbols: "符号"
            }
        }

        public var characters: [Character] {
            switch self {
            case .lowercase: Array("abcdefghijklmnopqrstuvwxyz")
            case .uppercase: Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
            case .digits: Array("0123456789")
            // 刻意不含 引号 / 反斜杠 / 反引号 / 竖线 / 分号 / 斜杠 ——
            // 那几个在 shell 和 JSON 里要转义，粘进配置文件最容易出事。
            case .symbols: Array("!@#$%^&*()-_=+[]{}<>?,.:")
            }
        }
    }

    /// 下限取 4 是有原因的：字符类最多四种，长度不小于 4 就保证
    /// 「每类至少一个」永远排得下 —— 那条约束不会有排不下的情况要处理。
    public static let minimumLength = 4
    public static let maximumLength = 128

    public static func generate(
        length: Int,
        classes: Set<CharacterClass>,
        guaranteeEachClass: Bool = true
    ) -> String {
        var generator = SystemRandomNumberGenerator()
        return generate(
            length: length,
            classes: classes,
            guaranteeEachClass: guaranteeEachClass,
            using: &generator
        )
    }

    /// 随机源是参数 —— 生产上传 `SystemRandomNumberGenerator`，
    /// 测试里传定种子的，于是「每类至少一个」「洗过牌」这些性质可以真的断言。
    public static func generate(
        length: Int,
        classes: Set<CharacterClass>,
        guaranteeEachClass: Bool,
        using generator: inout some RandomNumberGenerator
    ) -> String {
        // `Set` 没有顺序，先定序 —— 否则同一个种子跑两次结果不一样，
        // 测试会变成偶尔红一次的那种测试。
        let selected = CharacterClass.allCases.filter { classes.contains($0) }
        guard !selected.isEmpty, length > 0 else { return "" }

        let pool = selected.flatMap(\.characters)
        var characters: [Character] = []

        if guaranteeEachClass, length >= selected.count {
            for characterClass in selected {
                characters.append(characterClass.characters.randomElement(using: &generator)!)
            }
        }
        while characters.count < length {
            characters.append(pool.randomElement(using: &generator)!)
        }

        // 必须洗。见上面第 3 条。
        characters.shuffle(using: &generator)
        return String(characters)
    }

    /// 一次生成 `count` 个。
    ///
    /// 生成密码的人会在几个里挑一个顺眼的（好念、好打、不带容易看错的字符），
    /// 一次只给一个等于逼他连点十次 —— 而每点一次，上一串就没了。
    ///
    /// 每一个都是**独立**抽的，不去重：默认长度和字符集下两串撞上的概率在
    /// 10⁻⁴⁰ 量级，为它加一层重试只会换来一个「为什么这次生成得慢」的新问题。
    public static func generate(
        count: Int,
        length: Int,
        classes: Set<CharacterClass>,
        guaranteeEachClass: Bool = true
    ) -> [String] {
        var generator = SystemRandomNumberGenerator()
        return generate(
            count: count,
            length: length,
            classes: classes,
            guaranteeEachClass: guaranteeEachClass,
            using: &generator
        )
    }

    /// 同上，随机源是参数。**十个必须共用同一个 generator** ——
    /// 每个都新建一个定种子的源的话，十串会一模一样。
    public static func generate(
        count: Int,
        length: Int,
        classes: Set<CharacterClass>,
        guaranteeEachClass: Bool,
        using generator: inout some RandomNumberGenerator
    ) -> [String] {
        guard count > 0 else { return [] }

        var results: [String] = []
        results.reserveCapacity(count)
        for _ in 0..<count {
            results.append(
                generate(
                    length: length,
                    classes: classes,
                    guaranteeEachClass: guaranteeEachClass,
                    using: &generator
                )
            )
        }
        return results
    }

    public static func poolSize(_ classes: Set<CharacterClass>) -> Int {
        CharacterClass.allCases
            .filter { classes.contains($0) }
            .reduce(0) { $0 + $1.characters.count }
    }

    /// 香农熵，单位 bit。
    ///
    /// 算的是「每一位都从字符集里独立均匀取」的理想值。开了「每类至少一个」
    /// 之后真实熵会**略低**一点（有一部分组合被排除了），但在正常长度下
    /// 这个差值不到 1 bit，不值得为它把数字写得没法读。
    public static func entropyBits(length: Int, classes: Set<CharacterClass>) -> Double {
        let size = poolSize(classes)
        guard size > 1, length > 0 else { return 0 }
        return Double(length) * log2(Double(size))
    }
}
