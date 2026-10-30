#!/bin/bash
# 02-fetch.sh

# ==========================================
# 0. 获取最新或指定日期的 Tag/Hash 克隆函数 (时光机核心)
# ==========================================
clone_time_machine() {
    local repo_url=$1
    local dest_dir=$2
    local target_date=$3
    local use_hash_only=$4

    local repo_path=$(echo "$repo_url" | sed -E 's|https://github.com/([^/]+/[^/.]+)(\.git)?|\1|')
    
    echo "=========================================="
    echo "🚀 启动 [时光机克隆]: 目标目录 -> $dest_dir"
    echo "📅 目标节点: ${target_date:-最新}"
    echo "=========================================="
    
    if [ -z "$target_date" ]; then
        local api_resp=$(curl -s -H "Authorization: Bearer $GH_TOKEN" "https://api.github.com/repos/$repo_path/releases/latest")
        local latest_tag=$(echo "$api_resp" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

        if [ -n "$latest_tag" ]; then
            echo "✅ [常规拉取] 找到最新 Tag: $latest_tag，正在浅克隆..."
            git clone --branch "$latest_tag" --depth 1 "$repo_url" "package/custom/$dest_dir"
        else
            echo "⚠️ [常规拉取] 未找到 Tag，直接拉取默认分支最新代码..."
            git clone --depth 1 "$repo_url" "package/custom/$dest_dir"
        fi
        return 0
    fi

    if [ "$use_hash_only" != "true" ]; then
        echo "🔍 [时光机] 正在检索 $target_date 之前的最新 Tag..."
        local releases_json=$(curl -s -H "Authorization: Bearer $GH_TOKEN" "https://api.github.com/repos/$repo_path/releases?per_page=30")
        local target_tag=""
        target_tag=$(echo "$releases_json" | jq -r --arg date "$target_date" 'map(select(.published_at < $date)) | .[0].tag_name // empty')

        if [ -n "$target_tag" ] && [ "$target_tag" != "null" ]; then
            echo "🎉 [时光机] 精准锁定！找到历史 Tag: $target_tag"
            git clone --branch "$target_tag" --depth 1 "$repo_url" "package/custom/$dest_dir"
            return 0
        else
            echo "⚠️ [时光机] 未能在历史中找到合适的 Tag，将降级寻找 Commit Hash..."
        fi
    fi

    echo "🔍 [时光机] 正在检索 $target_date 之前的最后一次提交..."
    local default_branch=$(curl -s -H "Authorization: Bearer $GH_TOKEN" "https://api.github.com/repos/$repo_path" | jq -r '.default_branch // "master"')
    local api_url="https://api.github.com/repos/$repo_path/commits?sha=$default_branch&until=$target_date&per_page=1"
    local commit_hash=$(curl -s -H "Authorization: Bearer $GH_TOKEN" "$api_url" | jq -r '.[0].sha // empty')

    if [ -n "$commit_hash" ] && [ "$commit_hash" != "null" ]; then
        echo "🎉 [时光机] 精准锁定！找到历史 Hash: ${commit_hash:0:7}"
        git clone "$repo_url" "package/custom/$dest_dir"
        cd "package/custom/$dest_dir"
        git reset --hard "$commit_hash"
        cd - > /dev/null
    else
        echo "❌ [时光机] 彻底失败！未找到任何历史记录。降级拉取最新代码！"
        git clone --depth 1 "$repo_url" "package/custom/$dest_dir"
    fi
}

mkdir -p package/custom

# ==========================================
# 3. 统一拉取：共用的第三方基础插件库 (全局生效，带时光机)
# ==========================================
echo "====== 统一拉取定制基础插件源码 ======"
clone_time_machine "https://github.com/wjtyyds/luci-app-adguardhome" "luci-app-adguardhome" ""
clone_time_machine "https://github.com/gdy666/luci-app-lucky" "lucky" "$TARGET_DATE_ISO"
clone_time_machine "https://github.com/destan19/OpenAppFilter" "luci-app-oaf" "$TARGET_DATE_ISO"
clone_time_machine "https://github.com/eamonxg/luci-theme-aurora" "luci-theme-aurora" "$TARGET_DATE_ISO"
clone_time_machine "https://github.com/eamonxg/luci-app-aurora-config" "luci-app-aurora-config" "$TARGET_DATE_ISO"

OPENCLASH_REPO="https://github.com/vernesong/OpenClash"
echo "[时光机] 离线读取全局配置，OpenClash 锁定于: ${OPENCLASH_TAG:-最新 master}"

mkdir -p /tmp/OpenClash && cd /tmp/OpenClash
git init; git remote add origin "$OPENCLASH_REPO"; git config core.sparseCheckout true
echo "luci-app-openclash/*" >> .git/info/sparse-checkout
git pull --depth 1 origin "${OPENCLASH_TAG:-master}"
mv luci-app-openclash $GITHUB_WORKSPACE/openwrt/package/custom/
cd $GITHUB_WORKSPACE/openwrt
rm -rf /tmp/OpenClash

# ==========================================
# 4. Public 公共版专属：追加拉取科学代理组件
# ==========================================
if [ "$BUILD_TYPE" == "public" ]; then
    echo "【公共版】：已配置拉取完整代理编译组件..."
    echo "👉 [DEBUG-SH] 代理组件拉取拦截检查，TARGET_DATE_ISO: [$TARGET_DATE_ISO]"

    if [[ "$TARGET_DATE_ISO" != *"2026-09-09"* ]]; then
        echo "✅ [DEBUG-SH] 未命中 09.09 拦截，拉取 Passwall。"
        clone_time_machine "https://github.com/Openwrt-Passwall/openwrt-passwall-packages" "passwall-packages" "$TARGET_DATE_ISO" "true"
        clone_time_machine "https://github.com/Openwrt-Passwall/openwrt-passwall" "passwall-luci" "$TARGET_DATE_ISO"
    else
        echo "⛔ [DEBUG-SH] 命中 09.09，拦截 Passwall 拉取！"
    fi

    if [[ "$TARGET_DATE_ISO" != *"2026-09-09"* ]] && [[ "$TARGET_DATE_ISO" != *"2026-09-16"* ]]; then
        echo "✅ [DEBUG-SH] 未命中 09.09/09.16 拦截，拉取 Daede。"
        clone_time_machine "https://github.com/kenzok8/openwrt-daede" "daede" "$TARGET_DATE_ISO"
    else
        echo "⛔ [DEBUG-SH] 命中拦截日期，拦截 Daede 拉取！"
    fi
else
    echo "【私有版】：已阻断外部代理套件克隆..."
fi