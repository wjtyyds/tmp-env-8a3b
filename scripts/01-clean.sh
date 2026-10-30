#!/bin/bash
# 01-clean.sh

# ==========================================
# 1. 提取公共逻辑：Golang 升级 (必须在清理冲突前执行)
# ==========================================
if [[ "$FIRMWARE_TYPE" != lede* ]] && [ "$BUILD_TYPE" != "personal" ]; then
    if [[ "$TARGET_DATE_ISO" != *"2026-09-09"* ]]; then
        echo "【Public 编译专属】：为 OpenWrt，ImmortalWrt，iStoreOS 升级 Golang 1.27..."
        rm -rf feeds/packages/lang/golang
        git clone -b 27.x --depth 1 https://github.com/sbwml/packages_lang_golang.git feeds/packages/lang/golang
        ./scripts/feeds install -a -f
    else
        echo "⛔ [DEBUG-SH] 命中 09.09 拦截日期，保持自带版本，跳过 Golang 升级！"
    fi
fi

# ==========================================
# 2. 统一处理：卸载系统自带的冲突插件 (全局生效)
# ==========================================
echo "====== 统一卸载冲突插件 ======"
conflict_plugins=(
    "adguardhome" "luci-app-adguardhome" "luci-app-openclash" "openclash"
    "oaf" "kmod-oaf" "appfilter" "luci-app-oaf" "luci-app-appfilter" "openappfilter" "luci-app-openappfilter" "open-app-filter"
    "lucky" "luci-app-lucky" "passwall" "luci-app-passwall"
    "hysteria" "sing-box" "xray-core" "xray-plugin" "v2ray-geodata" "v2ray-plugin" "shadowsocks-rust" "shadowsocksr-libev"
    "dae" "daed" "luci-app-dae" "luci-app-daed"
)
for plugin in "${conflict_plugins[@]}"; do
    ./scripts/feeds uninstall "$plugin" || true
    rm -rf feeds/packages/*/*/"$plugin" 2>/dev/null
    rm -rf feeds/luci/*/*/"$plugin" 2>/dev/null
done

# ==========================================
# 3. 统一处理：清理代理底层老旧核心 (全局生效)
# ==========================================
echo "====== 统一清理老旧底层代理核心 ======"
rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,v2ray-plugin,xray-plugin,geoview,shadow-tls} 2>/dev/null
rm -rf feeds/luci/applications/luci-app-passwall 2>/dev/null