#!/bin/bash
# 01-clean.sh

# ==========================================
# 1. 统一处理：卸载系统自带的冲突插件 (全局生效)
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
# 2. 统一处理：清理代理底层老旧核心 (全局生效)
# ==========================================
echo "====== 统一清理老旧底层代理核心 ======"
rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,v2ray-plugin,xray-plugin,geoview,shadow-tls} 2>/dev/null
rm -rf feeds/luci/applications/luci-app-passwall 2>/dev/null