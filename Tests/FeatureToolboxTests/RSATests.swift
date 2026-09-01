import Foundation
import Testing

@testable import FeatureToolbox

/// 生成一次就够 —— 2048 位的密钥对生成要花上百毫秒，
/// 每个测试各生成一把会把整个套件拖慢一个数量级。
private enum Fixture {
    static let pair: RSA.KeyPair = {
        do { return try RSA.generate(.bits2048) } catch { fatalError("生成密钥对失败：\(error)") }
    }()
}

@Suite("RSA")
struct RSATests {

    // MARK: - 密钥格式
    //
    // 这一组是这个工具的全部价值所在：Apple 只认 PKCS#1，
    // Java 那边给的是 X.509 / PKCS#8。两边对不上就什么都做不了。

    @Test("生成出来的就是 Java 直接能用的格式")
    func generatedKeysUseTheJavaFriendlyPEMLabels() {
        #expect(Fixture.pair.publicKey.hasPrefix("-----BEGIN PUBLIC KEY-----"))
        #expect(Fixture.pair.publicKey.hasSuffix("-----END PUBLIC KEY-----"))
        #expect(Fixture.pair.privateKey.hasPrefix("-----BEGIN PRIVATE KEY-----"))
        #expect(Fixture.pair.privateKey.hasSuffix("-----END PRIVATE KEY-----"))
    }

    @Test("PEM 一行 64 个字符 —— 不折行的话老工具读不进去")
    func pemBodyIsWrappedAtSixtyFour() {
        let body = Fixture.pair.publicKey
            .components(separatedBy: .newlines)
            .filter { !$0.hasPrefix("-----") }

        #expect(body.count > 1)
        #expect(body.dropLast().allSatisfy { $0.count == 64 })
        #expect(body.last?.count ?? 0 <= 64)
    }

    @Test("生成的公钥能被自己解析回来")
    func generatedPublicKeyParsesBack() throws {
        _ = try RSA.key(from: Fixture.pair.publicKey, isPrivate: false)
        _ = try RSA.key(from: Fixture.pair.privateKey, isPrivate: true)
    }

    @Test("包壳和拆壳互为逆运算")
    func derWrappingRoundTrips() throws {
        let pkcs1: [UInt8] = [0x30, 0x06, 0x02, 0x01, 0x2A, 0x02, 0x01, 0x2B]

        #expect(try DER.unwrapSubjectPublicKeyInfo(DER.wrapSubjectPublicKeyInfo(pkcs1)) == pkcs1)
        #expect(try DER.unwrapPKCS8(DER.wrapPKCS8(pkcs1)) == pkcs1)
    }

    @Test("DER 长度字段的长短两种写法都要能读")
    func derReadsBothLengthForms() throws {
        let short = DER.encode(0x04, Array(repeating: 0x41, count: 10))
        let long = DER.encode(0x04, Array(repeating: 0x41, count: 300))

        #expect(try DER.read(short, from: 0).value.count == 10)
        #expect(try DER.read(long, from: 0).value.count == 300)
        // 300 要用长写法：0x82 表示后面跟两个字节的长度
        #expect(long[1] == 0x82)
    }

    @Test("坏 PEM 说得出坏在哪一步")
    func badPEMIsExplained() {
        #expect(throws: RSA.Failure.noKey) {
            try RSA.key(from: "   ", isPrivate: false)
        }
        #expect(throws: RSA.Failure.badPEM("找不到 -----BEGIN 那一行。")) {
            try RSA.key(from: "just some text", isPrivate: false)
        }
        #expect(throws: RSA.Failure.badPEM("中间那段不是合法的 Base64。")) {
            try RSA.key(from: "-----BEGIN PUBLIC KEY-----\n@@@\n-----END PUBLIC KEY-----", isPrivate: false)
        }
    }

    // MARK: - 加解密

    @Test("公钥加密、私钥解密，三种填充都要通", arguments: RSA.Padding.allCases)
    func encryptDecryptRoundTrips(padding: RSA.Padding) throws {
        let plaintext = "letitgo"

        let ciphertext = try RSA.encrypt(plaintext, publicKeyPEM: Fixture.pair.publicKey, padding: padding)
        let recovered = try RSA.decrypt(ciphertext, privateKeyPEM: Fixture.pair.privateKey, padding: padding)

        #expect(recovered == plaintext)
    }

    @Test("中文按 UTF-8 走，往返不掉字节")
    func chineseSurvivesTheRoundTrip() throws {
        let plaintext = "把受保护文件交给本机 IDEA 读出明文"

        let ciphertext = try RSA.encrypt(plaintext, publicKeyPEM: Fixture.pair.publicKey, padding: .oaepSHA256)

        #expect(try RSA.decrypt(ciphertext, privateKeyPEM: Fixture.pair.privateKey, padding: .oaepSHA256) == plaintext)
    }

    @Test("同一段明文加两次密文不一样 —— 填充里有随机数")
    func paddingRandomisesTheCiphertext() throws {
        let first = try RSA.encrypt("a", publicKeyPEM: Fixture.pair.publicKey, padding: .pkcs1)
        let second = try RSA.encrypt("a", publicKeyPEM: Fixture.pair.publicKey, padding: .pkcs1)

        #expect(first != second)
    }

    /// RSA 能加密的长度上限是「模长 − 填充开销」。这是 Java 那边
    /// 「data must not be longer than 245 bytes」的来源，也是这个工具
    /// 最常被问到的一件事。
    @Test("超长明文报得出上限是多少", arguments: [
        (RSA.Padding.pkcs1, 245),        // 256 − 11
        (RSA.Padding.oaepSHA1, 214),     // 256 − 2×20 − 2
        (RSA.Padding.oaepSHA256, 190),   // 256 − 2×32 − 2
    ])
    func oversizedPlaintextReportsTheLimit(padding: RSA.Padding, limit: Int) {
        let tooLong = String(repeating: "a", count: limit + 1)

        #expect(throws: RSA.Failure.tooLong(limit: limit, actual: limit + 1)) {
            try RSA.encrypt(tooLong, publicKeyPEM: Fixture.pair.publicKey, padding: padding)
        }
        // 正好卡在上限上要能加密
        #expect(throws: Never.self) {
            try RSA.encrypt(String(repeating: "a", count: limit),
                            publicKeyPEM: Fixture.pair.publicKey, padding: padding)
        }
    }

    @Test("填充方式对不上就解不开 —— 不会悄悄给出一段垃圾")
    func mismatchedPaddingFails() throws {
        let ciphertext = try RSA.encrypt("a", publicKeyPEM: Fixture.pair.publicKey, padding: .pkcs1)

        #expect(throws: (any Error).self) {
            try RSA.decrypt(ciphertext, privateKeyPEM: Fixture.pair.privateKey, padding: .oaepSHA256)
        }
    }

    @Test("每种填充都写清楚了 Java 那边对应什么", arguments: RSA.Padding.allCases)
    func everyPaddingDocumentsItsJavaCounterpart(padding: RSA.Padding) {
        #expect(padding.note.contains("RSA/ECB/"))
    }
}

@Suite("RSA · 工具页")
@MainActor
struct RSAModelTests {

    @Test("生成一对之后，当前模式要用的那把已经填好了")
    func generateFillsTheKeyForTheCurrentMode() async {
        let model = RSAModel()
        model.options.mode = .encrypt

        await model.generateKeyPair()

        #expect(model.options.key.hasPrefix("-----BEGIN PUBLIC KEY-----"))
        #expect(model.counterpartKey?.value.hasPrefix("-----BEGIN PRIVATE KEY-----") == true)
    }

    @Test("解密模式下填进去的是私钥，配套给出的是公钥")
    func generateFillsThePrivateKeyWhenDecrypting() async {
        let model = RSAModel()
        model.options.mode = .decrypt

        await model.generateKeyPair()

        #expect(model.options.key.hasPrefix("-----BEGIN PRIVATE KEY-----"))
        #expect(model.counterpartKey?.value.hasPrefix("-----BEGIN PUBLIC KEY-----") == true)
    }

    /// 走一遍用户真实的路径：生成 → 加密 → 换成私钥 → 解密。
    @Test("生成的密钥对自己能加、自己能解")
    func generatedPairRoundTripsThroughTheModel() async throws {
        let model = RSAModel()
        await model.generateKeyPair()

        let privateKey = try #require(model.counterpartKey?.value)
        model.options.input = "letitgo"
        model.run()

        let ciphertext = try #require(try? model.output?.get())

        model.options.mode = .decrypt
        model.options.key = privateKey
        model.options.input = ciphertext
        model.run()

        #expect(try model.output?.get() == "letitgo")
    }

    @Test("密钥或内容还没填全时不算错 —— 不该半路弹红提示")
    func partialInputIsNotAnError() {
        let model = RSAModel()

        model.options.key = "-----BEGIN PUBLIC KEY-----"
        model.run()
        #expect(model.output == nil)

        model.options.key = ""
        model.options.input = "letitgo"
        model.run()
        #expect(model.output == nil)
    }
}
