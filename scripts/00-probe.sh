#!/bin/bash
# 00-probe.sh (环境嗅探探针)
# 职责：提前完成所有零散的 GitHub API 请求，统一存为环境变量给全流程使用

echo "====== 启动全局 API 数据嗅探 ======"

# 1. 嗅探 AdGuardHome 下载链接
echo "🔍 正在嗅探 AdGuardHome 稳定版链接..."
if [ -n "$TARGET_DATE_ISO" ]; then
    AGH_API="https://api.github.com/repos/AdguardTeam/AdGuardHome/releases?per_page=50"
    AGH_URL=$(curl -s -H "Authorization: Bearer $GH_TOKEN" "$AGH_API" | jq -r --arg date "$TARGET_DATE_ISO" 'map(select(.published_at < $date and .prerelease == false)) | .[0].assets[] | select(.name | contains("linux_arm64.tar.gz")) | .browser_download_url' | head -n 1)
else
    AGH_API="https://api.github.com/repos/AdguardTeam/AdGuardHome/releases/latest"
    AGH_URL=$(curl -s -H "Authorization: Bearer $GH_TOKEN" "$AGH_API" | grep "browser_download_url" | grep "linux_arm64.tar.gz" | head -n 1 | cut -d '"' -f 4)
fi
echo "AGH_URL=$AGH_URL" >> $GITHUB_ENV
echo "✅ AdGuardHome 链接就绪: $AGH_URL"

# 2. 嗅探 OpenClash Meta Core 哈希
echo "🔍 正在嗅探 OpenClash Meta Core 哈希..."
if [ -n "$TARGET_DATE_ISO" ]; then
    CORE_HASH=$(curl -s -H "Authorization: Bearer $GH_TOKEN" "https://api.github.com/repos/vernesong/OpenClash/commits?sha=core&until=$TARGET_DATE_ISO&per_page=1" | jq -r '.[0].sha' 2>/dev/null || true)
    if [ "$CORE_HASH" == "null" ] || [ -z "$CORE_HASH" ]; then CORE_HASH="core"; fi
else
    CORE_HASH="core"
fi
echo "META_CORE_HASH=$CORE_HASH" >> $GITHUB_ENV
echo "✅ Meta Core 哈希就绪: $CORE_HASH"

# 3. 嗅探 OpenClash 插件源码 Tag
echo "🔍 正在嗅探 OpenClash 插件源码 Tag..."
if [ -n "$TARGET_DATE_ISO" ]; then
    OPENCLASH_RELEASES=$(curl -s -H "Authorization: Bearer $GH_TOKEN" "https://api.github.com/repos/vernesong/OpenClash/releases?per_page=30")
    OPENCLASH_TAG=$(echo "$OPENCLASH_RELEASES" | jq -r --arg date "$TARGET_DATE_ISO" 'map(select(.published_at < $date)) | .[0].tag_name // empty')
else
    OPENCLASH_TAG=$(curl -s -H "Authorization: Bearer $GH_TOKEN" "https://api.github.com/repos/vernesong/OpenClash/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
fi
echo "OPENCLASH_TAG=$OPENCLASH_TAG" >> $GITHUB_ENV
echo "✅ OpenClash Tag 就绪: ${OPENCLASH_TAG:-最新 master}"