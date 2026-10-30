#!/bin/bash
# 04-feeds.sh

echo "====== 开始处理 Feeds 源与配置文件 ======"

CONF_DIR="configs/${BUILD_LOWER}"

if [ "${FIRMWARE_LOWER}" == "istoreos" ] || [ "${FIRMWARE_LOWER}" == "lede-native" ]; then
  if [[ "${SOURCE_BRANCH}" =~ ^(istoreos-[0-9]+\.[0-9]+) ]]; then
    BASE_FEED_VER="${BASH_REMATCH[1]}"
    TARGET_FEEDS="${CONF_DIR}/feeds_${BASE_FEED_VER}.conf"
  else
    TARGET_FEEDS="${CONF_DIR}/feeds_${SOURCE_BRANCH}.conf"
  fi

  DEFAULT_FEEDS="${CONF_DIR}/feeds_istoreos.conf"

  if [ -f "$TARGET_FEEDS" ]; then
    echo "====== 匹配到分支专属 feeds 配置，开始注入: $TARGET_FEEDS ======"
    cp "$TARGET_FEEDS" openwrt/feeds.conf
  elif [ -f "$DEFAULT_FEEDS" ]; then
    echo "====== 未匹配到专属文件，使用兜底 feeds 配置: $DEFAULT_FEEDS ======"
    cp "$DEFAULT_FEEDS" openwrt/feeds.conf
  else
    echo "====== 未找到任何自定义 feeds 配置，保持源码默认状态 ======"
  fi
fi

cd openwrt

[ ! -f feeds.conf ] && cp feeds.conf.default feeds.conf

if grep -q '^src-include' feeds.conf 2>/dev/null; then
    if [ "${FIRMWARE_LOWER}" == "istoreos" ]; then
        echo "🔧 [iStoreOS 专属逻辑] 检测到 src-include 指令，按需【保留不展平】。"
    else
        echo "🔧 检测到 src-include 指令，开始展平被引用的 feeds 文件..."
        FLATTEN_TMP=$(mktemp)
        while IFS= read -r line; do
            if [[ "$line" =~ ^src-include[[:space:]]+[^[:space:]]+[[:space:]]+(.+)$ ]]; then
                INCLUDE_FILE=$(echo "${BASH_REMATCH[1]}" | sed -E 's/[[:space:]]+$//')
                if [ -f "$INCLUDE_FILE" ]; then
                    echo "   ↪ 展平 include 文件: $INCLUDE_FILE"
                    echo "# ===== Flattened from $INCLUDE_FILE =====" >> "$FLATTEN_TMP"
                    cat "$INCLUDE_FILE" >> "$FLATTEN_TMP"
                    echo "# ===== End of $INCLUDE_FILE =====" >> "$FLATTEN_TMP"
                else
                    echo "   ⚠️ 警告：include 文件 $INCLUDE_FILE 不存在，保留原行"
                    echo "$line" >> "$FLATTEN_TMP"
                fi
            else
                echo "$line" >> "$FLATTEN_TMP"
            fi
        done < feeds.conf
        mv "$FLATTEN_TMP" feeds.conf
        echo "✅ feeds.conf 展平完成 (共 $(wc -l < feeds.conf) 行)"
    fi
fi

if [[ "${FIRMWARE_LOWER}" == "istoreos" || "${FIRMWARE_LOWER}" == lede* ]] && { [ -n "$FEEDS_DATE_ISO" ] || [ -n "$TARGET_DATE_ISO" ]; }; then
    if [ "${FIRMWARE_LOWER}" == "istoreos" ] && [ -n "${SAFE_DATE_ISO}" ]; then
        ACTUAL_FEEDS_DATE="${SAFE_DATE_ISO}"
        echo "⏳ 触发 Feeds 联动时光机 (跟随底层安全基准: $ACTUAL_FEEDS_DATE)"
    else
        ACTUAL_FEEDS_DATE="${FEEDS_DATE_ISO:-$TARGET_DATE_ISO}"
        echo "⏳ 触发 Feeds 全局极致时光机 (目标日期: $ACTUAL_FEEDS_DATE)"
    fi

    while IFS= read -r line; do
        [[ -z "$line" || "$line" == \#* ]] && continue

        if echo "$line" | grep -q "^src-git"; then
            feed_name=$(echo "$line" | awk '{print $2}')
            feed_source=$(echo "$line" | awk '{print $3}')

            if [[ "$feed_source" == *";"* ]]; then
                repo_url=$(echo "$feed_source" | cut -d';' -f1)
                branch_name=$(echo "$feed_source" | cut -d';' -f2)
            elif [[ "$feed_source" == *"^"* ]]; then
                continue
            else
                repo_url="$feed_source"
                branch_name=""
            fi

            api_repo_url=$(echo "$repo_url" | sed -e 's|https://git.openwrt.org/feed/|https://github.com/openwrt/|' -e 's|https://git.openwrt.org/project/|https://github.com/openwrt/|')

            if [[ "$api_repo_url" == *"github.com"* ]]; then
                repo_path=$(echo "$api_repo_url" | sed -E 's|.*github.com/([^/]+/[^/.]+)(\.git)?|\1|')
                if [ -n "$branch_name" ]; then
                    api_url="https://api.github.com/repos/$repo_path/commits?sha=$branch_name&until=$ACTUAL_FEEDS_DATE&per_page=1"
                else
                    api_url="https://api.github.com/repos/$repo_path/commits?until=$ACTUAL_FEEDS_DATE&per_page=1"
                fi
                commit_hash=$(curl -sL -H "Authorization: Bearer $GH_TOKEN" "$api_url" | jq -r '.[0].sha' 2>/dev/null || true)
                if [ "$commit_hash" != "null" ] && [ -n "$commit_hash" ]; then
                    escaped_line=$(echo "$line" | sed 's/[./*?|]/\\&/g')
                    sed -i "s|^$escaped_line$|src-git $feed_name $repo_url^$commit_hash|g" feeds.conf
                fi
            fi
        fi
    done < feeds.conf
fi

./scripts/feeds update -a
./scripts/feeds install -a -f < /dev/null