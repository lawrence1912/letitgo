import Foundation
import Observation

/// RSA 工具的状态。
///
/// 结果**存下来**，不是算出来的：PKCS#1 和 OAEP 的填充里都有随机数，
/// 同一段明文每次加密的密文都不一样。写成计算属性的话，界面每重绘一次
/// 密文就变一次 —— 看着的和复制到的还可能不是同一份。
@MainActor
@Observable
public final class RSAModel {

    public enum Mode: String, CaseIterable, Identifiable, Hashable, Sendable {
        case encrypt
        case decrypt

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .encrypt: "加密"
            case .decrypt: "解密"
            }
        }

        var keyTitle: String {
            switch self {
            case .encrypt: "公钥（BEGIN PUBLIC KEY）"
            case .decrypt: "私钥（BEGIN PRIVATE KEY）"
            }
        }

        var inputTitle: String {
            switch self {
            case .encrypt: "明文"
            case .decrypt: "密文（Base64）"
            }
        }
    }

    /// 选项打包成一个值，界面盯着它一个变化就够了。
    public struct Options: Equatable, Sendable {
        public var mode: Mode = .encrypt
        public var padding: RSA.Padding = .pkcs1
        public var key = ""
        public var input = ""

        public init() {}
    }

    public var options = Options()
    public var keySize: RSA.KeySize = .bits2048

    public private(set) var output: Result<String, RSA.Failure>?
    public private(set) var generated: RSA.KeyPair?
    public private(set) var isGenerating = false

    public init() {}

    public func run() {
        let options = options
        guard !options.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !options.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            // 还没填全不算错 —— 半路弹一条红提示只会打断人。
            output = nil
            return
        }

        do {
            let text = switch options.mode {
            case .encrypt:
                try RSA.encrypt(options.input, publicKeyPEM: options.key, padding: options.padding)
            case .decrypt:
                try RSA.decrypt(options.input, privateKeyPEM: options.key, padding: options.padding)
            }
            output = .success(text)
        } catch let failure as RSA.Failure {
            output = .failure(failure)
        } catch {
            output = .failure(.security("\(error)"))
        }
    }

    /// 生成放到后台：4096 位在这台机器上要小一秒，卡在主线程会明显掉帧。
    ///
    /// 写成 `async` 而不是内部起个 `Task` —— 后者在测试里没法等，
    /// 而「生成完有没有把密钥填进去」恰恰是要测的那件事。
    public func generateKeyPair() async {
        guard !isGenerating else { return }
        isGenerating = true
        defer { isGenerating = false }

        let size = keySize
        guard let pair = await Task.detached(operation: { try? RSA.generate(size) }).value else {
            output = .failure(.security("生成密钥对失败。"))
            return
        }

        generated = pair
        // 顺手把当前模式要用的那把填进去 —— 生成完还要手动复制粘贴是多余的一步。
        options.key = options.mode == .encrypt ? pair.publicKey : pair.privateKey
        run()
    }

    /// 生成的那对里，当前模式**没用上**的另一半。加密时要给对方私钥去解，
    /// 解密时要给对方公钥去加 —— 两边都得能复制走。
    public var counterpartKey: (title: String, value: String)? {
        guard let generated else { return nil }
        return options.mode == .encrypt
            ? ("配套私钥（BEGIN PRIVATE KEY）", generated.privateKey)
            : ("配套公钥（BEGIN PUBLIC KEY）", generated.publicKey)
    }
}
