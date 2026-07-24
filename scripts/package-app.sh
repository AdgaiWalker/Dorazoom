#!/usr/bin/env bash
# 把 SPM 可执行文件打成 macOS .app，便于出现在「屏幕录制」权限列表
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "→ 编译 InkLayer…"
swift build -c debug

BIN="$ROOT/.build/debug/InkLayer"
if [[ ! -x "$BIN" ]]; then
  # 部分环境产物在三元组目录
  BIN="$(find "$ROOT/.build" -path '*/debug/InkLayer' -type f -perm -111 | head -1)"
fi
if [[ -z "${BIN:-}" || ! -x "$BIN" ]]; then
  echo "错误：找不到可执行文件 InkLayer" >&2
  exit 1
fi

APP="$ROOT/InkLayer.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RES="$CONTENTS/Resources"

echo "→ 组装 $APP …"
rm -rf "$APP"
mkdir -p "$MACOS" "$RES"
cp "$BIN" "$MACOS/InkLayer"
chmod +x "$MACOS/InkLayer"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"

# ad-hoc 签名：权限列表按 bundle id 识别更稳
if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP" 2>/dev/null || true
fi

echo "→ 完成：$APP"
echo "  启动：open \"$APP\""
echo "  或：  open -a \"$APP\""
