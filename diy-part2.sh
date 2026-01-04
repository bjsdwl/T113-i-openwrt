#!/bin/bash
#
# diy-part2.sh: T113-i OpenWrt 深度适配脚本 (Session 5.3 - Dual Core & CCU Final Fix)
#

DTS_NAME="sun8i-t113-tronlong-minievm"
KERNEL_VER="6.12"
PATCH_DIR="target/linux/sunxi/patches-$KERNEL_VER"
IMAGE_MK="target/linux/sunxi/image/cortexa7.mk"
IMAGE_MAKEFILE="target/linux/sunxi/image/Makefile"

echo ">>> Starting T113-i Professional Adaptation (Session 5.3)..."

# ==============================================================================
# 1. 部署自定义设备树 (包含 PSCI 双核唤醒逻辑)
# ==============================================================================
mkdir -p target/linux/sunxi/files/arch/arm/boot/dts
if [ -f "files/$DTS_NAME.dts" ]; then
    cp "files/$DTS_NAME.dts" target/linux/sunxi/files/arch/arm/boot/dts/
    echo "✅ Dual-core enabled DTS deployed."
fi

# ==============================================================================
# 2. 引入 Armbian 高质量内核补丁 (解决 T113-i 在 6.12 下的底层兼容性)
# ==============================================================================
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

# ==============================================================================
# 3. 内核配置强刷 (核心：开启双核 SMP 与 正确的时钟驱动)
# ==============================================================================
for f in target/linux/sunxi/config-*; do
    [ -e "$f" ] || continue
    echo "Processing kernel config: $f"

    # --- [A] 开启双核 SMP 支持 ---
    sed -i 's/CONFIG_SMP=n/CONFIG_SMP=y/g' $f
    echo "CONFIG_SMP=y" >> $f
    echo "CONFIG_NR_CPUS=2" >> $f
    echo "CONFIG_HOTPLUG_CPU=y" >> $f
    echo "CONFIG_ARM_PSCI=y" >> $f

    # --- [B] 时钟驱动：主线内核 T113 依赖 D1 的 CCU 框架 ---
    # 必须确保 CONFIG_CLK_SUN20I_D1=y，否则所有外设都会卡在 deferred probe
    sed -i 's/# CONFIG_CLK_SUN20I_D1 is not set/CONFIG_CLK_SUN20I_D1=y/g' $f
    sed -i 's/CONFIG_CLK_SUN20I_D1=m/CONFIG_CLK_SUN20I_D1=y/g' $f
    echo "CONFIG_CLK_SUN20I_D1=y" >> $f
    echo "CONFIG_CLK_SUN8I_T113=y" >> $f

    # --- [C] 存储与文件系统强内置 (y) ---
    sed -i 's/CONFIG_MMC=m/CONFIG_MMC=y/g' $f
    sed -i 's/CONFIG_MMC_BLOCK=m/CONFIG_MMC_BLOCK=y/g' $f
    sed -i 's/CONFIG_MMC_SUNXI=m/CONFIG_MMC_SUNXI=y/g' $f
    sed -i 's/CONFIG_EXT4_FS=m/CONFIG_EXT4_FS=y/g' $f
    
    # --- [D] 架构核心组件 ---
    echo "CONFIG_ARM_ARCH_TIMER=y" >> $f
    echo "CONFIG_ARM_GIC=y" >> $f
    echo "CONFIG_GENERIC_IRQ_CHIP=y" >> $f
    echo "CONFIG_CLK_IGNORE_UNUSED=y" >> $f

    # --- [E] 调试增强 ---
    echo "CONFIG_DEBUG_KERNEL=y" >> $f
    echo "CONFIG_INITCALL_DEBUG=y" >> $f
    echo "CONFIG_PRINTK_TIME=y" >> $f
done

# ==============================================================================
# 4. 注册机型到 OpenWrt 编译菜单
# ==============================================================================
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

# ==============================================================================
# 5. 绕过打包校验
# ==============================================================================
if [ -f "$IMAGE_MAKEFILE" ]; then
    sed -i '/image_prepare:/a \	mkdir -p $(STAGING_DIR_IMAGE) && touch $(STAGING_DIR_IMAGE)/sunxi-boot.scr && touch $(STAGING_DIR_IMAGE)/$(DEVICE_UBOOT)-boot.scr' "$IMAGE_MAKEFILE"
fi

echo ">>> [Session 5.3] Adaptation Script Finished."
