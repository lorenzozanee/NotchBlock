#!/bin/bash
# NotchBlock — Quarantine Fix & Launch Helper
#
# Removes macOS quarantine attribute from NotchBlock.app and launches it.
# Required because NotchBlock is distributed outside the Mac App Store
# without Apple notarization ($99/year Apple Developer Program).
#
# First run: Right-click → Open (Gatekeeper bypass for unsigned scripts)
# Subsequent runs: double-click directly

set -euo pipefail

APP_PATH="/Applications/NotchBlock.app"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  NotchBlock — 隔离移除 & 启动助手"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ ! -d "$APP_PATH" ]; then
    echo "❌ 未找到 /Applications/NotchBlock.app"
    echo ""
    echo "   请先将 NotchBlock.app 拖入 Applications 文件夹，"
    echo "   然后重新运行此脚本。"
    echo ""
    read -p "按 Enter 键退出..."
    exit 1
fi

echo "✅ 已找到 NotchBlock.app"
echo ""

echo "🔧 正在移除隔离标记..."
if xattr -cr "$APP_PATH" 2>/dev/null; then
    echo "✅ 隔离标记已移除"
else
    echo "⚠️  移除隔离标记时出现问题，尝试继续..."
fi

echo ""
echo "🚀 正在启动 NotchBlock..."
open "$APP_PATH"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  NotchBlock 已启动！菜单栏会出现图标。"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

sleep 3
