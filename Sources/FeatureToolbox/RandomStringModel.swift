import Foundation
import Observation

/// 随机串工具的状态。
///
/// 结果是**存下来的**，不是算出来的：如果 `values` 是个计算属性，
/// 每次重绘都会得到一批新的 —— 界面会在你看着它的时候自己变，
/// 而且复制到的和看到的可能不是同一串。
@MainActor
@Observable
public final class RandomStringModel {

    /// 所有选项打包成一个值，界面只要盯着它一个变化就够了。
    public struct Options: Equatable, Sendable {
        public var length: Int
        public var classes: Set<RandomString.CharacterClass>
        public var guaranteeEachClass: Bool

        public init(
            length: Int = 24,
            classes: Set<RandomString.CharacterClass> = [.lowercase, .uppercase, .digits],
            guaranteeEachClass: Bool = true
        ) {
            self.length = length
            self.classes = classes
            self.guaranteeEachClass = guaranteeEachClass
        }
    }

    /// 一次给几个。挑密码这件事得有得挑，而十个是「够挑」和
    /// 「一屏还看得完」之间的位置 —— 再多就得滚动着挑了。
    public static let batchSize = 10

    public var options: Options
    public private(set) var values: [String]

    public init(options: Options = Options()) {
        self.options = options
        self.values = RandomString.generate(
            count: Self.batchSize,
            length: options.length,
            classes: options.classes,
            guaranteeEachClass: options.guaranteeEachClass
        )
    }

    public func regenerate() {
        values = RandomString.generate(
            count: Self.batchSize,
            length: options.length,
            classes: options.classes,
            guaranteeEachClass: options.guaranteeEachClass
        )
    }

    /// 「全部复制」拿走的东西：一行一个。
    /// 换行分隔是因为这批东西最常见的下一站是配置文件或者一列测试数据。
    public var joined: String {
        values.joined(separator: "\n")
    }

    /// 四个都取消时不拦着 —— 拦着的话按钮点下去没反应，用户不知道为什么。
    /// 让它变成空结果 + 一条说明，看得见才改得掉。
    public var hasNoClasses: Bool { options.classes.isEmpty }

    public var poolSize: Int { RandomString.poolSize(options.classes) }

    public var entropyBits: Int {
        Int(RandomString.entropyBits(length: options.length, classes: options.classes).rounded())
    }

    public func binding(for characterClass: RandomString.CharacterClass) -> Bool {
        options.classes.contains(characterClass)
    }

    public func set(_ characterClass: RandomString.CharacterClass, enabled: Bool) {
        if enabled {
            options.classes.insert(characterClass)
        } else {
            options.classes.remove(characterClass)
        }
    }
}
