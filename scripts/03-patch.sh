#!/bin/bash
# 03-patch.sh

# ==========================================
# 1. 差异化操作：各分支专有的修补逻辑
# ==========================================
echo "====== 开始各分支的差异化特征修改 ======"

if [ "$BUILD_TYPE" == "public" ]; then
    echo "👉 [DEBUG-SH] 差异化补丁检查，TARGET_DATE_ISO: [$TARGET_DATE_ISO]"
    if [[ "$TARGET_DATE_ISO" == *"2026-09-09"* ]] || [[ "$TARGET_DATE_ISO" == *"2026-09-16"* ]]; then
        echo "【${TARGET_DATE_ISO:0:10} 专属补丁】: 命中，开始执行 Dockerman 替换..."
        rm -rf feeds/luci/applications/luci-app-dockerman 2>/dev/null
        rm -rf feeds/luci/libs/luci-lib-docker 2>/dev/null
        
        # 兼容调用时光机逻辑
        repo_url_docker="https://github.com/wjtyyds/luci-app-dockerman"
        repo_url_lib="https://github.com/wjtyyds/luci-lib-docker"

        default_branch=$(curl -s -H "Authorization: Bearer $GH_TOKEN" "https://api.github.com/repos/wjtyyds/luci-app-dockerman" | jq -r '.default_branch // "master"')
        commit_hash=$(curl -s -H "Authorization: Bearer $GH_TOKEN" "https://api.github.com/repos/wjtyyds/luci-app-dockerman/commits?sha=$default_branch&until=$TARGET_DATE_ISO&per_page=1" | jq -r '.[0].sha // empty')
        if [ -n "$commit_hash" ]; then
            git clone "$repo_url_docker" "package/custom/luci-app-dockerman"
            cd "package/custom/luci-app-dockerman" && git reset --hard "$commit_hash" && cd - > /dev/null
        else
            git clone --depth 1 "$repo_url_docker" "package/custom/luci-app-dockerman"
        fi

        commit_hash_lib=$(curl -s -H "Authorization: Bearer $GH_TOKEN" "https://api.github.com/repos/wjtyyds/luci-lib-docker/commits?sha=$default_branch&until=$TARGET_DATE_ISO&per_page=1" | jq -r '.[0].sha // empty')
        if [ -n "$commit_hash_lib" ]; then
            git clone "$repo_url_lib" "package/custom/luci-lib-docker"
            cd "package/custom/luci-lib-docker" && git reset --hard "$commit_hash_lib" && cd - > /dev/null
        else
            git clone --depth 1 "$repo_url_lib" "package/custom/luci-lib-docker"
        fi
    else
        echo "✅ [DEBUG-SH] 未命中 09.09 或 09.16，跳过 Dockerman 替换。"
    fi
else
    echo "【Personal 模式】：跳过特定日期的 Dockerman 源码替换逻辑，保持纯净。"
fi

if [ "$FIRMWARE_TYPE" == "istoreos" ] && [ "$BUILD_TYPE" == "personal" ]; then
    echo "【iStoreOS Personal 专属】：干掉自带 Argon 主题与配置，拉取 Jerrykuku 版本..."
    ./scripts/feeds uninstall luci-theme-argon luci-app-argon-config 2>/dev/null || true
    rm -rf feeds/luci/themes/luci-theme-argon 2>/dev/null
    rm -rf feeds/luci/applications/luci-app-argon-config 2>/dev/null

    # 1. 精准抹除强依赖：连同 "+" 号一起删掉，彻底解决 dependency on '' 的空依赖警告
    find package/ -name "Makefile" -exec sed -i 's/+luci-theme-argon//g' {} +
    find package/ -name "Makefile" -exec sed -i 's/+luci-app-argon-config//g' {} +

    # 2. 规范文件夹命名：只克隆这一个自带 config 插件的主题仓库，名字必须是官方标准名
    git clone --depth 1 "https://github.com/jerrykuku/luci-theme-argon" "package/custom/luci-theme-argon"

    # 干掉 Argon 自带的霸道开机自启脚本，防止它抢夺默认主题优先级
    rm -f package/custom/luci-theme-argon/root/etc/uci-defaults/30_luci-theme-argon 2>/dev/null
fi

if [[ "$FIRMWARE_TYPE" == lede* ]]; then
    find package/custom/luci-theme-aurora -name "footer.ut" -exec sed -i 's/({{ version.distrevision }})/{% if (version.distrevision): %} ({{ version.distrevision }}){% endif %}/g' {} +

    if [ "$FIRMWARE_TYPE" == "lede-native" ] && [ -n "$TARGET_DATE_ISO" ]; then
        MAC_MK="package/kernel/mac80211/Makefile"
        MAC_PATCH="package/kernel/mac80211/patches/brcm/871-brcmfmac-disable-dump_survey-on-bcm2835.patch"

        if [[ "$TARGET_DATE_ISO" == *"2026-09-16"* ]] || [[ "$TARGET_DATE_ISO" == *"2026-10-11"* ]]; then
            echo "====== [6.18内核专属] 执行常规的 sed 热修复 (SDIO & GXL PHY) ======"
            if [ -f "$MAC_MK" ]; then sed -i 's/PKG_RELEASE:=3/PKG_RELEASE:=4/g' "$MAC_MK"; fi
            if [ -f "$MAC_PATCH" ]; then
                sed -i 's/on Raspberry Pi/if SDIO enabled/g' "$MAC_PATCH"
                sed -i 's/on Raspberry Pi and LuCI/on BRCM43455-SDIO and LuCI/g' "$MAC_PATCH"
                sed -i 's/CONFIG_ARCH_BCM2835/CPTCFG_BRCMFMAC_SDIO/g' "$MAC_PATCH"
                echo "✅ 6.18 内核 SDIO sed 注入完毕"
            fi
            for kconf in target/linux/amlogic/mesongx/config-*; do
                if [ -f "$kconf" ]; then
                    if ! grep -q "CONFIG_MDIO_BUS_MUX_MESON_GXL=y" "$kconf"; then
                        sed -i '/CONFIG_MDIO_BUS_MUX_MESON_G12A=y/a CONFIG_MDIO_BUS_MUX_MESON_GXL=y' "$kconf"
                        grep -q "CONFIG_MDIO_BUS_MUX_MESON_GXL=y" "$kconf" || echo "CONFIG_MDIO_BUS_MUX_MESON_GXL=y" >> "$kconf"
                        echo "✅ 已向 $kconf 注入 GXL MDIO 修复"
                    fi
                fi
            done
        fi
    fi

elif [ "$FIRMWARE_TYPE" == "immortalwrt" ]; then
    if [ "$SOURCE_BRANCH" == "v25.12.1" ]; then
        rm -rf feeds/packages/lang/rust
        git clone --depth 1 https://github.com/openwrt/packages.git /tmp/openwrt_packages
        cp -r /tmp/openwrt_packages/lang/rust feeds/packages/lang/
        rm -rf /tmp/openwrt_packages
    fi

elif [ "$FIRMWARE_TYPE" == "openwrt" ] || [ "$FIRMWARE_TYPE" == "istoreos" ]; then
    if [ "$BUILD_TYPE" != "personal" ]; then
        if [[ "$TARGET_DATE_ISO" != *"2026-09-09"* ]]; then
            if [[ "$SOURCE_BRANCH" =~ ^v([0-9]+\.[0-9]+) ]] || [[ "$SOURCE_BRANCH" == *"25.12"* ]]; then
                IMM_PKG_BRANCH="openwrt-${BASH_REMATCH[1]:-25.12}"
            else
                IMM_PKG_BRANCH="master"
            fi
            rm -rf feeds/packages/utils/{docker,dockerd,containerd,runc,docker-compose}
            git clone -b "$IMM_PKG_BRANCH" --depth 1 https://github.com/immortalwrt/packages.git /tmp/imm_packages
            cp -r /tmp/imm_packages/utils/{docker,dockerd,containerd,runc,docker-compose} feeds/packages/utils/ || true
            rm -rf /tmp/imm_packages
        fi
    fi

    if [ "$FIRMWARE_TYPE" == "openwrt" ] || { [ "$FIRMWARE_TYPE" == "istoreos" ] && [ "$BUILD_TYPE" == "personal" ]; }; then
        git clone --depth 1 https://github.com/lisaac/luci-app-diskman package/custom/luci-app-diskman
    fi

    if [ "$FIRMWARE_TYPE" == "openwrt" ]; then
        curl -sSL https://raw.githubusercontent.com/chenmozhijin/turboacc/luci/add_turboacc.sh | bash -s -- --no-sfe
    elif [ "$FIRMWARE_TYPE" == "istoreos" ]; then
        find package/ feeds/ -path "*/luci-static/quickstart/*.js" -exec sed -i 's|admin/services/appfilter|admin/services/oaf|g' {} + 2>/dev/null || true
        ISTORE_NET_BOARD="target/linux/amlogic/base-files/etc/board.d/02_network"
        if [ -f "$ISTORE_NET_BOARD" ]; then
            sed -i "s/ucidef_set_interface_lan 'eth0' 'dhcp'/ucidef_set_interface_lan 'eth0' 'static'/g" "$ISTORE_NET_BOARD"
        fi
        ISTORE_MAKEFILE="package/istoreos-files/Makefile"
        if [ -f "$ISTORE_MAKEFILE" ]; then
            sed -i 's/"192.168.100.1"/"192.168.1.1"/g' "$ISTORE_MAKEFILE"
            sed -i "s/'192.168.100.1'/'192.168.1.1'/g" "$ISTORE_MAKEFILE"
        fi
        BANNER_FILE=$(find package/ base-files/ -type f -name "banner" 2>/dev/null | head -n 1)
        if [ -n "$BANNER_FILE" ]; then
            sed -i 's/                                  Powered by OpenWRT/ Compiled by 粉墨悲欢@恩山        Powered by OpenWRT/g' "$BANNER_FILE"
        fi
    fi
fi

# ==========================================
# 2. OAF 翻译缺失动态修复
# ==========================================
echo "====== 检查并修复 OAF 翻译文件 ======"
OAF_PO_FILE=$(find package/custom/ -name "oaf.po" 2>/dev/null | head -n 1)
if [ -n "$OAF_PO_FILE" ] && [ -f "$OAF_PO_FILE" ]; then
    if ! grep -q "/etc/fwx\." "$OAF_PO_FILE"; then
        sed -i '/The user.s basic data/ s|/etc/oaf\.|/etc/fwx\.|g' "$OAF_PO_FILE"
        sed -i '/用户的基本数据/ s|/etc/oaf|/etc/fwx|g' "$OAF_PO_FILE"
    fi
fi

# ==========================================
# 3. 本地化环境与守护脚本注入 (静态引擎挂载)
# ==========================================
FILES_DIR="package/base-files/files"
mkdir -p ${FILES_DIR}/etc/uci-defaults

echo "====== 启动全局静态 Overlay 挂载引擎 ======"
[ -d "$GITHUB_WORKSPACE/custom-files/common" ] && cp -rf $GITHUB_WORKSPACE/custom-files/common/* ${FILES_DIR}/
[ -d "$GITHUB_WORKSPACE/custom-files/$FIRMWARE_TYPE" ] && cp -rf $GITHUB_WORKSPACE/custom-files/$FIRMWARE_TYPE/* ${FILES_DIR}/
[ -d "$GITHUB_WORKSPACE/custom-files/$BUILD_TYPE" ] && cp -rf $GITHUB_WORKSPACE/custom-files/$BUILD_TYPE/* ${FILES_DIR}/

find ${FILES_DIR}/etc/uci-defaults -type f -exec chmod +x {} \; 2>/dev/null || true
[ "$BUILD_TYPE" == "personal" ] && sed -i "s/__PPPOE_USER__/$PPPOE_USER/g; s/__PPPOE_PASS__/$PPPOE_PASS/g" ${FILES_DIR}/etc/uci-defaults/97_personal_setup 2>/dev/null || true

mkdir -p ${FILES_DIR}/etc
echo "Original Creator: 粉墨悲欢@恩山 Forum" > ${FILES_DIR}/etc/.fw_signature
echo 'BUILD_AUTHOR="粉墨悲欢@EnShan"' >> ${FILES_DIR}/etc/os-release
echo "# Firmware compiled and customized by 粉墨悲欢" >> ${FILES_DIR}/etc/profile

# ==========================================
# 4. lede-native 专属综合配置 (编译期注入)
# ==========================================
if [ "$FIRMWARE_TYPE" == "lede-native" ]; then
    echo "====== [lede-native] 强注 Amlogic 底层温度传感器驱动 ======"
    find target/linux/amlogic/ -type f -name "config-*" | while read conf_file; do
        echo "CONFIG_THERMAL=y" >> "$conf_file"
        echo "CONFIG_THERMAL_OF=y" >> "$conf_file"
        echo "CONFIG_AMLOGIC_THERMAL=y" >> "$conf_file"
        echo "CONFIG_MESON_THERMAL=y" >> "$conf_file"
        echo "CONFIG_SENSORS_ARM_SCPI=y" >> "$conf_file"
        echo "CONFIG_HWMON=y" >> "$conf_file"
    done
fi

# ==========================================
# 5. 针对特定版本强制使用预编译的 xray 核心
# ==========================================
if [ "$CUSTOM_TAG" == "R26.10.11" ]; then
    echo "====== 触发专属逻辑：替换 xray-core Makefile 为本地直装模式 ======"
    XRAY_MK_PATH="package/custom/passwall-packages/xray-core/Makefile"
    if [[ "$FIRMWARE_TYPE" == "openwrt" ]] || [[ "$FIRMWARE_TYPE" == "immortalwrt" ]]; then
        XRAY_ARCH="aarch64_generic"
    else
        XRAY_ARCH="aarch64_cortex-a53"
    fi
    XRAY_LOCAL_FILE="$GITHUB_WORKSPACE/auto_import/xray-${XRAY_ARCH}-26.10.10"

    if [ -f "$XRAY_MK_PATH" ]; then
        cat << EOF > "$XRAY_MK_PATH"
include \$(TOPDIR)/rules.mk
PKG_NAME:=xray-core
PKG_VERSION:=26.10.10
PKG_RELEASE:=1
include \$(INCLUDE_DIR)/package.mk
define Package/xray-core
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Xray (Pre-compiled local version)
  DEPENDS:=+ca-bundle
endef
define Build/Prepare
endef
define Build/Compile
endef
define Package/xray-core/install
	\$(INSTALL_DIR) \$(1)/usr/bin/
	\$(INSTALL_BIN) $XRAY_LOCAL_FILE \$(1)/usr/bin/xray
endef
\$(eval \$(call BuildPackage,xray-core))
EOF
    fi
fi