#!/bin/bash
# 06-config.sh

CONF_NAME="${FIRMWARE_LOWER}"
CONF_DIR="configs/${BUILD_LOWER}"

if [ ! -f "${CONF_DIR}/${CONF_NAME}.config" ] && [[ "${CONF_NAME}" == "lede-native" ]]; then
  echo "未找到 ${CONF_DIR}/lede-native.config，降级使用共用的 lede.config..."
  cp ${CONF_DIR}/lede.config openwrt/.config
else
  echo "加载配置文件: ${CONF_DIR}/${CONF_NAME}.config"
  cp ${CONF_DIR}/${CONF_NAME}.config openwrt/.config
fi

sed -i 's/CONFIG_KERNEL_DEBUG_INFO=y/# CONFIG_KERNEL_DEBUG_INFO is not set/g' openwrt/.config
sed -i 's/CONFIG_KERNEL_DEBUG_KERNEL=y/# CONFIG_KERNEL_DEBUG_KERNEL is not set/g' openwrt/.config
sed -i 's/CONFIG_GDB=y/# CONFIG_GDB is not set/g' openwrt/.config
sed -i 's/CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadowsocks_Rust_Client=y/# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadowsocks_Rust_Client is not set/g' openwrt/.config
sed -i 's/CONFIG_PACKAGE_shadowsocks-rust-sslocal=y/# CONFIG_PACKAGE_shadowsocks-rust-sslocal is not set/g' openwrt/.config
echo "CONFIG_DEVEL=y" >> openwrt/.config
echo "CONFIG_BPF_TOOLCHAIN_HOST=y" >> openwrt/.config

# 开启全局 ImmortalWrt 兜底
sed -i '/CONFIG_LOCALMIRROR/d' openwrt/.config
echo 'CONFIG_LOCALMIRROR="https://sources.immortalwrt.org"' >> openwrt/.config

echo "====== 注入全局基础定制插件 ======"
cat >> openwrt/.config <<EOF
CONFIG_PACKAGE_luci-theme-aurora=y
CONFIG_PACKAGE_luci-app-aurora-config=y
CONFIG_PACKAGE_luci-app-adguardhome=y
CONFIG_PACKAGE_luci-app-lucky=y
CONFIG_PACKAGE_luci-app-openclash=y
CONFIG_PACKAGE_luci-app-oaf=y
CONFIG_PACKAGE_luci-app-diskman=y
CONFIG_PACKAGE_luci-app-diskman_INCLUDE_lsblk=y
EOF

if [[ "${CONF_NAME}" == lede* ]]; then
  if [ "${CONF_NAME}" == "lede-native" ]; then
    sed -i 's/CONFIG_PACKAGE_brcmfmac-firmware-usb=y/# CONFIG_PACKAGE_brcmfmac-firmware-usb is not set/g' openwrt/.config
    sed -i 's/CONFIG_BRCMFMAC_USB=y/# CONFIG_BRCMFMAC_USB is not set/g' openwrt/.config
  elif [ "${CONF_NAME}" == "lede" ]; then
    sed -i 's/# CONFIG_TARGET_ROOTFS_TARGZ is not set/CONFIG_TARGET_ROOTFS_TARGZ=y/g' openwrt/.config
    echo "CONFIG_TARGET_ROOTFS_TARGZ=y" >> openwrt/.config
    sed -i 's/CONFIG_TARGET_ROOTFS_EXT4FS=y/# CONFIG_TARGET_ROOTFS_EXT4FS is not set/g' openwrt/.config
    sed -i 's/CONFIG_TARGET_ROOTFS_SQUASHFS=y/# CONFIG_TARGET_ROOTFS_SQUASHFS is not set/g' openwrt/.config
    sed -i '/CONFIG_TARGET_EXT4_/d' openwrt/.config
    sed -i '/CONFIG_TARGET_IMAGES_GZIP/d' openwrt/.config
    sed -i '/CONFIG_TARGET_ROOTFS_PARTSIZE/d' openwrt/.config
  fi

  sed -i 's/CONFIG_PACKAGE_libustream-openssl=y/# CONFIG_PACKAGE_libustream-openssl is not set/g' openwrt/.config
  sed -i 's/CONFIG_DEFAULT_libustream-openssl=y/# CONFIG_DEFAULT_libustream-openssl is not set/g' openwrt/.config
  cat >> openwrt/.config <<EOF
CONFIG_PACKAGE_libustream-mbedtls=y
CONFIG_DEFAULT_libustream-mbedtls=y
CONFIG_PACKAGE_ca-bundle=y
CONFIG_PACKAGE_ca-certificates=y
EOF

elif [ "${CONF_NAME}" == "openwrt" ]; then
  cat >> openwrt/.config <<EOF
CONFIG_PACKAGE_luci-app-turboacc=y
CONFIG_PACKAGE_luci-app-turboacc_INCLUDE_OFFLOADING=y
CONFIG_PACKAGE_luci-app-turboacc_INCLUDE_BBR_CCA=y
CONFIG_PACKAGE_luci-app-turboacc_INCLUDE_NFT_FULLCONE=y
EOF
fi

if [ "${BUILD_LOWER}" == "public" ]; then

  echo "👉 [DEBUG] 注入公共基础网络与内核依赖..."
  cat >> openwrt/.config <<EOF
# --- 1. Nikki (科学代理) 底层核心与网络依赖 ---
CONFIG_PACKAGE_ca-bundle=y
CONFIG_PACKAGE_curl=y
CONFIG_PACKAGE_yq=y
CONFIG_PACKAGE_firewall4=y
CONFIG_PACKAGE_ip-full=y
CONFIG_PACKAGE_kmod-inet-diag=y
CONFIG_PACKAGE_kmod-nft-socket=y
CONFIG_PACKAGE_kmod-nft-tproxy=y
CONFIG_PACKAGE_kmod-tun=y

# --- 2. USB 手机网络共享与虚拟网卡驱动 (RNDIS/CDC) ---
CONFIG_PACKAGE_usbutils=y
CONFIG_PACKAGE_kmod-dummy=y
CONFIG_PACKAGE_kmod-usb-net=y
CONFIG_PACKAGE_kmod-usb-net-rndis=y
CONFIG_PACKAGE_kmod-usb-net-cdc-ether=y

# --- 3. RTL8152/8153 USB 转千兆网卡驱动与微代码固件 ---
CONFIG_PACKAGE_kmod-usb-net-rtl8152=y
CONFIG_PACKAGE_r8152-firmware=y

# --- 4. Open-Box (代理面板) 底层依赖 ---
CONFIG_PACKAGE_kmod-nft-queue=y
CONFIG_PACKAGE_kmod-nft-nat=y
CONFIG_PACKAGE_kmod-veth=y
EOF

  echo "👉 [DEBUG] 当前注入拦截变量判断："
  echo "  - TARGET_DATE_ISO (包含检查): [${TARGET_DATE_ISO}]"

  if [[ "${TARGET_DATE_ISO}" != *"2026-09-09"* ]]; then
    echo "✅ [DEBUG] 未命中 09.09 拦截，正常注入 Passwall 等套件。"
    cat >> openwrt/.config <<EOF
CONFIG_PACKAGE_luci-app-passwall=y
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Geoview=y
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Haproxy=y
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Hysteria=y
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadowsocks_Rust_Client=y
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_ShadowsocksR_Libev_Client=y
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_SingBox=y
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_V2ray_Geodata=y
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_V2ray_Plugin=y
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Xray=y
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Xray_Plugin=y
EOF
    echo "CONFIG_PACKAGE_luci-app-passwall_Nftables_Transparent_Proxy=y" >> openwrt/.config
  else
    echo "⛔ [DEBUG] 已命中 09.09，成功拦截 Passwall 注入！"
  fi

  if [[ "${TARGET_DATE_ISO}" != *"2026-09-09"* ]] && [[ "${TARGET_DATE_ISO}" != *"2026-09-16"* ]]; then
    echo "✅ [DEBUG] 未命中 09.09/09.16 拦截，正常注入 Daede 套件。"
    cat >> openwrt/.config <<EOF
CONFIG_PACKAGE_luci-app-daede=y
CONFIG_PACKAGE_dae=y
EOF
  else
    echo "⛔ [DEBUG] 已命中拦截日期，成功拦截 Daede 注入！"
  fi
fi
cd openwrt
make defconfig