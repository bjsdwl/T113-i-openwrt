#!/bin/bash
#
# diy-part2.sh: T113-i OpenWrt 深度适配脚本 (Session 5.2 - The Final Success)
#

DTS_NAME="sun8i-t113-tronlong-minievm"
KERNEL_VER="6.12"
PATCH_DIR="target/linux/sunxi/patches-$KERNEL_VER"
IMAGE_MK="target/linux/sunxi/image/cortexa7.mk"
IMAGE_MAKEFILE="target/linux/sunxi/image/Makefile"

echo ">>> Starting T113-i Professional Adaptation (Session 5.2)..."

# 1. 部署自定义设备树
mkdir -p target/linux/sunxi/files/arch/arm/boot/dts
if [ -f "files/$DTS_NAME.dts" ]; then
    cp "files/$DTS_NAME.dts" target/linux/sunxi/files/arch/arm/boot/dts/
    echo "✅ Custom DTS deployed."
fi

# 2. 引入 Armbian 高质量内核补丁 (提供 T113 特定的时钟和热管理支持)
ARMBIAN_PATCH_RAW="https://raw.githubusercontent.com/armbian/build/master/patch/kernel/archive/sunxi-6.12"
echo ">>> Ingesting Armbian stability patches..."
mkdir -p $PATCH_DIR
patches=(
    "general-sunxi-t113s-ccu-fixes.patch"
    "general-sunxi-t113-thermal-support.patch"
)
for p in "${patches[@]}"; do
    wget -q "$ARMBIAN_PATCH_RAW/$p" -O "$PATCH_DIR/900-$p" && echo "✅ Patch added: $p"
done

# 3. 内核配置强刷 (核心：请回 D1 时钟驱动)
for f in target/linux/sunxi/config-*; do
    [ -e "$f" ] || continue
    echo "Processing kernel config: $f"

    # --- 纠正：必须开启 SUN20I_D1 驱动，它是 T113 在主线内核的时钟基础 ---
    sed -i 's/# CONFIG_CLK_SUN20I_D1 is not set/CONFIG_CLK_SUN20I_D1=y/g' $f
    echo "CONFIG_CLK_SUN20I_D1=y" >> $f
    echo "CONFIG_CLK_SUN8I_T113=y" >> $f

    # --- 驱动强内置 (y) ---
    sed -i 's/CONFIG_MMC=m/CONFIG_MMC=y/g' $f
    sed -i 's/CONFIG_MMC_BLOCK=m/CONFIG_MMC_BLOCK=y/g' $f
    sed -i 's/CONFIG_MMC_SUNXI=m/CONFIG_MMC_SUNXI=y/g' $f
    sed -i 's/CONFIG_EXT4_FS=m/CONFIG_EXT4_FS=y/g' $f
    
    # --- 核心组件内置 ---
    echo "CONFIG_ARM_ARCH_TIMER=y" >> $f
    echo "CONFIG_ARM_GIC=y" >> $f
    echo "CONFIG_GENERIC_IRQ_CHIP=y" >> $f
    echo "CONFIG_CLK_IGNORE_UNUSED=y" >> $f
done

# 4. 注册机型到 OpenWrt
if [ -f "$IMAGE_MK" ]; then
    if ! grep -q "Device/tronlong_tlt113-minievm" "$IMAGE_MK"; then
        echo "Registering device in cortexa7.mk"
        cat <<EOF >> "$IMAGE_MK"

define Device/tronlong_tlt113-minievm
  DEVICE_VENDOR := Tronlong
  DEVICE_MODEL := TLT113-MiniEVM
  DEVICE_DTS := $DTS_NAME
  SUPPORTED_DEVICES := tronlong,tlt113-minievm
  KERNEL := kernel-bin
endef
TARGET_DEVICES += tronlong_tlt113-minievm
EOF
    fi
fi

# 5. 绕过打包校验
if [ -f "$IMAGE_MAKEFILE" ]; then
    sed -i '/image_prepare:/a \	mkdir -p $(STAGING_DIR_IMAGE) && touch $(STAGING_DIR_IMAGE)/sunxi-boot.scr && touch $(STAGING_DIR_IMAGE)/$(DEVICE_UBOOT)-boot.scr' "$IMAGE_MAKEFILE"
fi

echo ">>> [Session 5.2] Adaptation Script Finished."
