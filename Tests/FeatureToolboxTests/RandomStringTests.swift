import Foundation
import Testing

@testable import FeatureToolbox

/// 定种子的随机源。随机的东西要能断言，就得先让它不随机。
/// SplitMix64 —— 十行，分布够好，重跑结果一样。
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

@Suite("随机串")
struct RandomStringTests {
    private let everything: Set<RandomString.CharacterClass> = Set(RandomString.CharacterClass.allCases)

    private func generate(
        length: Int = 24,
        classes: Set<RandomString.CharacterClass>? = nil,
        guarantee: Bool = true,
        seed: UInt64
    ) -> String {
        var generator = SeededGenerator(seed: seed)
        return RandomString.generate(
            length: length,
            classes: classes ?? everything,
            guaranteeEachClass: guarantee,
            using: &generator
        )
    }

    private func batch(
        count: Int = 10,
        length: Int = 24,
        classes: Set<RandomString.CharacterClass>? = nil,
        guarantee: Bool = true,
        seed: UInt64
    ) -> [String] {
        var generator = SeededGenerator(seed: seed)
        return RandomString.generate(
            count: count,
            length: length,
            classes: classes ?? everything,
            guaranteeEachClass: guarantee,
            using: &generator
        )
    }

    // MARK: - 一次一批

    @Test("要几个就是几个", arguments: [1, 5, 10, 25])
    func batchCountIsExact(count: Int) {
        #expect(batch(count: count, seed: 7).count == count)
    }

    @Test("批里每一个都符合长度和字符集的要求")
    func batchItemsObeyOptions() {
        let digits: Set<RandomString.CharacterClass> = [.digits]
        for value in batch(length: 8, classes: digits, seed: 11) {
            #expect(value.count == 8)
            #expect(value.allSatisfy { $0.isNumber })
        }
    }

    @Test("十个互不相同 —— 不是生成一个复制十遍")
    func batchItemsDiffer() {
        // 24 位、62 个字符的池子，撞车概率在 10⁻⁴⁰ 量级：
        // 这条要是红了，一定是代码把同一串发了十遍，不是运气不好。
        for seed in UInt64(0)..<20 {
            let values = batch(seed: seed)
            #expect(Set(values).count == values.count)
        }
    }

    @Test("count 是 0 或负数时给空数组，不是崩溃")
    func batchRejectsNonPositiveCount() {
        #expect(batch(count: 0, seed: 3).isEmpty)
        #expect(batch(count: -5, seed: 3).isEmpty)
    }

    @Test("同一个种子给出同一批 —— 否则这套测试自己不可靠")
    func batchIsDeterministic() {
        #expect(batch(seed: 99) == batch(seed: 99))
    }

    // MARK: - 长度

    @Test("要多长就是多长", arguments: [4, 5, 16, 24, 63, 128])
    func lengthIsExact(length: Int) {
        for seed in UInt64(0)..<20 {
            #expect(generate(length: length, seed: seed).count == length)
        }
    }

    // MARK: - 字符集

    @Test("只出现选中类里的字符", arguments: RandomString.CharacterClass.allCases)
    func onlySelectedClassesAppear(only: RandomString.CharacterClass) {
        let allowed = Set(only.characters)
        for seed in UInt64(0)..<50 {
            let value = generate(length: 32, classes: [only], seed: seed)
            #expect(value.allSatisfy { allowed.contains($0) }, "\(value) 里有集合外的字符")
        }
    }

    @Test("符号集里没有引号 / 反斜杠 / 反引号 / 竖线 / 分号 —— 那些粘进配置文件要转义")
    func symbolsAvoidTheCharactersThatNeedEscaping() {
        let symbols = Set(RandomString.CharacterClass.symbols.characters)

        for dangerous in Array("\"'\\`|;/") {
            #expect(!symbols.contains(dangerous), "符号集里不该有 \(dangerous)")
        }
    }

    // MARK: - 每类至少一个

    @Test("开了保证：选中的每一类都出现过")
    func guaranteePutsAtLeastOneOfEachClass() {
        for seed in UInt64(0)..<200 {
            let value = generate(length: 4, seed: seed)   // 4 = 类数，最紧的情况
            for characterClass in RandomString.CharacterClass.allCases {
                let members = Set(characterClass.characters)
                #expect(
                    value.contains(where: { members.contains($0) }),
                    "seed \(seed) 生成的 \(value) 里没有\(characterClass.title)"
                )
            }
        }
    }

    /// 「先各取一个再补齐」如果忘了洗牌，前四位就永远是
    /// 小写、大写、数字、符号 —— 等于把密码的前四位送人。
    @Test("保证之后要洗牌：首位不会永远是同一类")
    func guaranteedCharactersAreShuffled() {
        var firstCharacterClasses: Set<String> = []
        for seed in UInt64(0)..<100 {
            let value = generate(length: 16, seed: seed)
            let first = value.first!
            for characterClass in RandomString.CharacterClass.allCases
            where characterClass.characters.contains(first) {
                firstCharacterClasses.insert(characterClass.rawValue)
            }
        }
        #expect(firstCharacterClasses.count == RandomString.CharacterClass.allCases.count)
    }

    @Test("关了保证也照样生成，字符仍然在池子里")
    func withoutGuaranteeItStillGenerates() {
        let allowed = Set(everything.flatMap(\.characters))
        for seed in UInt64(0)..<50 {
            let value = generate(length: 20, guarantee: false, seed: seed)
            #expect(value.count == 20)
            #expect(value.allSatisfy { allowed.contains($0) })
        }
    }

    // MARK: - 边界

    @Test("一类都没选就是空串，不是崩溃")
    func noClassesYieldsEmptyString() {
        #expect(generate(classes: [], seed: 1).isEmpty)
    }

    @Test("长度下限保证「每类至少一个」永远排得下")
    func minimumLengthFitsEveryClass() {
        #expect(RandomString.minimumLength >= RandomString.CharacterClass.allCases.count)
    }

    // MARK: - 真的随机

    @Test("不同种子生成的串互不相同 —— 别是个常量")
    func differentSeedsProduceDifferentValues() {
        let values = Set((UInt64(0)..<100).map { generate(seed: $0) })

        #expect(values.count == 100)
    }

    @Test("同一个种子生成的串一模一样 —— 否则这套测试自己不可靠")
    func sameSeedIsReproducible() {
        #expect(generate(seed: 42) == generate(seed: 42))
    }

    // MARK: - 熵

    @Test("熵按 log2(字符集大小) × 长度 算")
    func entropyMatchesTheFormula() {
        // 26 + 26 + 10 = 62 个字符，24 位 ≈ 142.9 bit
        let bits = RandomString.entropyBits(length: 24, classes: [.lowercase, .uppercase, .digits])

        #expect(RandomString.poolSize([.lowercase, .uppercase, .digits]) == 62)
        #expect(abs(bits - 24 * log2(62.0)) < 0.001)
    }

    @Test("没选字符类时熵是 0，不是 NaN 或负数")
    func entropyIsZeroWithoutAnyClass() {
        #expect(RandomString.entropyBits(length: 24, classes: []) == 0)
    }
}
