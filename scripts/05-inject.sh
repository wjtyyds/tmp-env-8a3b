#!/bin/bash
# 05-inject.sh

echo "====== 原生编译：前置注入最新内核与私密配置 ======"
BASE_FILES="openwrt/package/base-files/files"

mkdir -p $BASE_FILES/usr/lib/adg_core
mkdir -p $BASE_FILES/usr/bin
mkdir -p $BASE_FILES/etc/openclash/core
mkdir -p $BASE_FILES/etc/init.d
mkdir -p $BASE_FILES/etc/rc.d

echo "提取官方 AdGuardHome (使用探针提前查好的变量)..."
if [ -n "$AGH_URL" ] && [ "$AGH_URL" != "null" ]; then
    echo "✅ 读取到 AdGuardHome 链接: $AGH_URL"
    wget -qO /tmp/agh.tar.gz "$AGH_URL"
    tar -xzf /tmp/agh.tar.gz -C /tmp/
    mv /tmp/AdGuardHome/AdGuardHome $BASE_FILES/usr/lib/adg_core/
    chmod 755 $BASE_FILES/usr/lib/adg_core/AdGuardHome
fi

echo "提取 Lucky 并进行源码级劫持..."
mkdir -p openwrt/custom_bins
if [ "$BUILD_LOWER" == "public" ]; then
  LUCKY_FILE="lucky_2.27.2_Linux_arm64_wanji_docker.tar.gz"
else
  LUCKY_FILE="lucky_2.27.2_Linux_arm64_wanji.tar.gz"
fi

if [ -n "$PRIVATE_REPO" ]; then
  gh release download "Private-Configs" -R "$PRIVATE_REPO" -p "$LUCKY_FILE" --clobber >/dev/null 2>&1 || true
fi

if [ -f "$LUCKY_FILE" ]; then
  tar -xzf "$LUCKY_FILE" -C /tmp/
  mv $(find /tmp/ -type f -name "lucky" | head -n 1) openwrt/custom_bins/lucky
  chmod 755 openwrt/custom_bins/lucky
  sed -i 's|$(PKG_BUILD_DIR)[^ ]*lucky|$(TOPDIR)/custom_bins/lucky|g' openwrt/package/custom/lucky/lucky/Makefile
fi

echo "提取 OpenClash Meta (使用探针提前查好的变量)..."
META_URL="https://raw.githubusercontent.com/vernesong/OpenClash/${META_CORE_HASH}/master/meta/clash-linux-arm64.tar.gz"
echo "✅ 读取到 Meta Core 链接: $META_URL"
wget -qO /tmp/clash_meta.tar.gz "$META_URL" || true
if [ -f /tmp/clash_meta.tar.gz ]; then
    tar -xzf /tmp/clash_meta.tar.gz -C /tmp/ || true
    mv /tmp/clash $BASE_FILES/etc/openclash/core/clash_meta || true
    chmod 755 $BASE_FILES/etc/openclash/core/clash_meta || true
fi

if [ "$BUILD_LOWER" == "personal" ]; then
    echo "解压私有配置..."
    if [ -n "$PRIVATE_REPO" ]; then
        gh release download "Private-Configs" -R "$PRIVATE_REPO" -p "private_config.zip" --clobber >/dev/null 2>&1 || true
        if [ -f "private_config.zip" ]; then
            unzip -q "private_config.zip" -d /tmp/private_conf/ || true
            [ -f "/tmp/private_conf/AdGuardHome.yaml" ] && mv /tmp/private_conf/AdGuardHome.yaml $BASE_FILES/etc/AdGuardHome_private.yaml
            LUCKY_ZIP=$(ls /tmp/private_conf/lucky_*.zip 2>/dev/null | head -n 1)
            if [ -n "$LUCKY_ZIP" ]; then
                mkdir -p $BASE_FILES/etc/config/lucky.daji
                unzip -q -o "$LUCKY_ZIP" -d $BASE_FILES/etc/config/lucky.daji/
            fi
        fi
    fi
fi

echo "注入 AdGuardHome 引导脚本..."
cat << 'EOF' > $BASE_FILES/etc/init.d/ign
#!/bin/sh /etc/rc.common
START=99
start() {
    (
        sleep 5
        IS_EMMC=0
        if mount | grep -E 'on /boot |on /rom |on / ' | grep -q "mmcblk"; then
          IS_EMMC=1
        fi
        if [ -f /usr/lib/adg_core/AdGuardHome ]; then
            if [ "$IS_EMMC" = "1" ]; then
                if [ "%%FIRMWARE_TYPE%%" = "istoreos" ] || [ "%%FIRMWARE_TYPE%%" = "lede-native" ]; then
                    DATA_DIR="/opt/AdGuardHome"
                else
                    DATA_DIR="/mnt/mmcblk2p4/AdGuardHome"
                fi
                mkdir -p "$DATA_DIR/data"
                cp -n /usr/lib/adg_core/AdGuardHome "$DATA_DIR/AdGuardHome"
                chmod 755 "$DATA_DIR/AdGuardHome"
                [ -d /usr/bin/AdGuardHome_data ] && cp -rn /usr/bin/AdGuardHome_data/* "$DATA_DIR/" 2>/dev/null
                rm -rf /usr/bin/AdGuardHome
                ln -sf "$DATA_DIR" /usr/bin/AdGuardHome
                rm -rf /usr/lib/adg_core
                rm -rf /usr/bin/AdGuardHome_data
            else
                DATA_DIR="/usr/bin/AdGuardHome_data"
                mkdir -p "$DATA_DIR"
                cp -n /usr/lib/adg_core/AdGuardHome "$DATA_DIR/AdGuardHome"
                chmod 755 "$DATA_DIR/AdGuardHome"
                rm -rf /usr/bin/AdGuardHome
                ln -sf "$DATA_DIR" /usr/bin/AdGuardHome
            fi
            /etc/init.d/AdGuardHome restart 2>/dev/null
        fi
        if [ "$IS_EMMC" = "1" ]; then
            rm -f /etc/rc.d/S99ign
            rm -f /etc/init.d/ign
        fi
    ) &
}
EOF
chmod +x $BASE_FILES/etc/init.d/ign

sed -i "s/%%FIRMWARE_TYPE%%/${FIRMWARE_LOWER}/g" $BASE_FILES/etc/init.d/ign
ln -sf ../init.d/ign $BASE_FILES/etc/rc.d/S99ign

cat << 'EOF' > $BASE_FILES/etc/rc.local
# Put your custom commands here that should be executed once
# the system init finished. By default this file does nothing.
exit 0
EOF
chmod +x $BASE_FILES/etc/rc.local

if [ "$FIRMWARE_LOWER" == "istoreos" ]; then
    echo "为 iStoreOS 创建 /root/install-to-emmc.sh 软链接..."
    mkdir -p $BASE_FILES/root
    ln -sf /usr/sbin/install-to-emmc.sh $BASE_FILES/root/install-to-emmc.sh
fi