#!/usr/bin/env bash
#
# 把 SwiftPM 产出的可执行文件包装成可双击运行的 .app。
#
# SwiftPM 本身不会生成 app bundle（只出裸二进制），而 SwiftUI 应用必须待在
# 带 Info.plist 的 bundle 里才能正常拿到菜单栏、窗口和激活状态 —— 这个脚本
# 补的就是 Xcode 平时替你做的那一步。装了 Xcode 之后可以改用 xcodebuild。
#
#   用法: Scripts/bundle.sh [debug|release]
#   环境变量:
#     SANDBOX=1        签名时带上 App Sandbox 权限
#     SIGN_IDENTITY    签名身份，默认 "-"（adhoc，仅本机可运行）

set -euo pipefail

CONFIG="${1:-debug}"
if [[ "$CONFIG" != "debug" && "$CONFIG" != "release" ]]; then
    echo "error: 配置只能是 debug 或 release，收到 '$CONFIG'" >&2
    exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="LetItGo"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/$APP_NAME.app"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

echo "==> swift build -c $CONFIG"
swift build --package-path "$ROOT" -c "$CONFIG"

BIN="$(swift build --package-path "$ROOT" -c "$CONFIG" --show-bin-path)/$APP_NAME"
if [[ ! -x "$BIN" ]]; then
    echo "error: 找不到可执行文件 $BIN" >&2
    exit 1
fi

echo "==> 组装 $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

# 有图标就带上（Resources/AppIcon.icns，可选）
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
    cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
    plutil -replace CFBundleIconFile -string "AppIcon" "$APP/Contents/Info.plist"
fi

plutil -lint "$APP/Contents/Info.plist" >/dev/null

echo "==> codesign (identity: $SIGN_IDENTITY)"
SIGN_ARGS=(--force --sign "$SIGN_IDENTITY" --timestamp=none)
if [[ "${SANDBOX:-0}" == "1" ]]; then
    SIGN_ARGS+=(--entitlements "$ROOT/Resources/$APP_NAME.entitlements")
    echo "    (带 App Sandbox 权限)"
fi
codesign "${SIGN_ARGS[@]}" "$APP"
codesign --verify --verbose=1 "$APP" 2>&1 | sed 's/^/    /'

echo "==> 完成: $APP"
