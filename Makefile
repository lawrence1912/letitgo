# LetItGo —— 常用命令入口
#
# 当前机器只装了 Command Line Tools（没有 Xcode），所以走 SwiftPM 构建 +
# 脚本打包这条路。装上 Xcode 后 `make xcode` 可以切到标准工程工作流。

APP_NAME := LetItGo
BUILD_DIR := build
APP := $(BUILD_DIR)/$(APP_NAME).app

# swift-testing 的 Testing.framework 在 CLT 里存在，但 SwiftPM 不会自动加
# 它的搜索路径和 rpath。装了完整 Xcode 时这些参数为空。
DEVELOPER_DIR := $(shell xcode-select -p)
ifneq (,$(findstring CommandLineTools,$(DEVELOPER_DIR)))
  TESTING_FW  := $(DEVELOPER_DIR)/Library/Developer/Frameworks
  TESTING_LIB := $(DEVELOPER_DIR)/Library/Developer/usr/lib
  TEST_FLAGS  := -Xswiftc -F -Xswiftc $(TESTING_FW) \
                 -Xlinker -F -Xlinker $(TESTING_FW) \
                 -Xlinker -rpath -Xlinker $(TESTING_FW) \
                 -Xlinker -rpath -Xlinker $(TESTING_LIB)
else
  TEST_FLAGS :=
endif

.DEFAULT_GOAL := help

.PHONY: help
help: ## 显示所有可用命令
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

.PHONY: build
build: ## 编译（debug）
	swift build

.PHONY: release
release: ## 编译（release）
	swift build -c release

.PHONY: app
app: ## 打包成 build/LetItGo.app（debug；SANDBOX=1 可带沙盒权限）
	@Scripts/bundle.sh debug

.PHONY: app-release
app-release: ## 打包 release 版 .app
	@Scripts/bundle.sh release

.PHONY: run
run: app ## 打包并启动
	@echo "==> open $(APP)"
	@open $(APP)

.PHONY: test
test: ## 跑单元测试（swift-testing）
	swift test $(TEST_FLAGS)

.PHONY: clean
clean: ## 清掉编译产物
	swift package clean
	rm -rf .build $(BUILD_DIR)

.PHONY: xcode
xcode: ## 用 XcodeGen 生成 .xcodeproj（需先装 Xcode 和 xcodegen）
	@command -v xcodegen >/dev/null 2>&1 || { \
		echo "缺少 xcodegen。安装: brew install xcodegen"; exit 1; }
	@case "$(DEVELOPER_DIR)" in \
		*CommandLineTools*) \
			echo "当前 developer dir 还是 CommandLineTools。"; \
			echo "装完 Xcode 后先跑: sudo xcode-select -s /Applications/Xcode.app"; \
			exit 1;; \
	esac
	xcodegen generate
	@echo "==> 生成完成，open $(APP_NAME).xcodeproj"
