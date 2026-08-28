import Testing
import AppCore
import Persistence
@testable import FeatureHome

/// 永远失败的仓库，用来验证 Model 的错误分支。
/// 这就是「依赖从 init 注入」的回报 —— 不用碰任何全局状态。
private struct FailingItemRepository: ItemRepository {
    func fetchAll() async throws -> [Item] { throw AppError.storage("磁盘炸了") }
    func insert(_ item: Item) async throws {}
    func delete(id: Item.ID) async throws {}
}

@Suite("HomeModel")
@MainActor
struct HomeModelTests {

    @Test("空仓库载入后是空列表，且没有错误")
    func loadsEmpty() async {
        let model = HomeModel(repository: InMemoryItemRepository())
        await model.load()

        #expect(model.items.isEmpty)
        #expect(model.error == nil)
        #expect(model.isLoading == false)
    }

    @Test("载入仓库里已有的数据")
    func loadsSeededItems() async {
        let seed = [Item(title: "甲"), Item(title: "乙")]
        let model = HomeModel(repository: InMemoryItemRepository(seed: seed))
        await model.load()

        #expect(model.items.count == 2)
        #expect(model.error == nil)
    }

    @Test("仓库抛错时转成 AppError 并停掉 loading")
    func surfacesRepositoryFailure() async {
        let model = HomeModel(repository: FailingItemRepository())
        await model.load()

        #expect(model.error == .storage("磁盘炸了"))
        #expect(model.items.isEmpty)
        #expect(model.isLoading == false)
    }
}
