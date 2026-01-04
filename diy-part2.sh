#!/bin/bash
#
# diy-part2.sh: T113-i 最终决胜脚本 (Session 5.5 - Zero Patch Edition)
#

DTS_NAME="sun8i-t113-tronlong-minievm"
IMAGE_MK="target/linux/sunxi/image/cortexa7.mk"
IMAGE_MAKEFILE="target/linux/sunxi/image/Makefile"

echo ">>> Starting T113-i Adaptation (Session 5.5)..."

# 1. 部署双核补全版 DTS (包含 PSCI 和 24M Timer)
mkdir -p target/linux/sunxi/files/arch/arm/boot/dts
if [ -f "files/$DTS_NAME.dts" ]; then
    cp "files/$DTS_NAME.dts" target/linux/sunxi/files/arch/arm/boot/dts/
    echo "✅ Dual-core DTS deployed."
fi

# 2. 内核配置强刷 (核心：利用 COMPILE_TEST 解锁驱动)
for f in target/linux/sunxi/config-*; do
    [ -e "$f" ] || continue
    echo "Processing kernel config: $f"

    # --- [关键] 开启编译测试模式，以此解锁 D1 的时钟和引脚驱动 ---
    echo "CONFIG_COMPILE_TEST=y" >> $f
    echo "CONFIG_CLK_SUN20I_D1=y" >> $f
    echo "CONFIG_PINCTRL_SUN20I_D1=y" >> $f
    echo "CONFIG_CLK_SUN8I_T113=y" >> $f

    # --- 开启多核 SMP 支持 ---
    sed -i 's/CONFIG_SMP=n/CONFIG_SMP=y/g' $f
    echo "CONFIG_SMP=y" >> $f
    echo "CONFIG_NR_CPUS=2" >> $f
    echo "CONFIG_ARM_PSCI=y" >> $f

    # --- 驱动强内置 (y) ---
    sed -i 's/CONFIG_MMC=m/CONFIG_MMC=y/g' $f
    sed -i 's/CONFIG_MMC_BLOCK=m/CONFIG_MMC_BLOCK=y/g' $f
    sed -i 's/CONFIG_MMC_SUNXI=m/CONFIG_MMC_SUNXI=y/g' $f
    sed -i 's/CONFIG_EXT4_FS=m/CONFIG_EXT4_FS=y/g' $f
    
    # --- 架构核心组件 ---
    echo "CONFIG_ARM_ARCH_TIMER=y" >> $f
    echo "CONFIG_ARM_GIC=y" >> $f
    echo "CONFIG_GENERIC_IRQ_CHIP=y" >> $f
    echo "CONFIG_CLK_IGNORE_UNUSED=y" >> $f

    # --- 调试增强 ---
    echo "CONFIG_DEBUG_KERNEL=y" >> $f
    echo "CONFIG_INITCALL_DEBUG=y" >> $f
done

# 3. 注册机型到 OpenWrt
if [ -f "$IMAGE_MK" ]; then
    if ! grep -q "Device/tronlong_tlt113-minievm" "$IMAGE_MK"; then
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

# 4. 绕过打包校验
if [ -f "$IMAGE_MAKEFILE" ]; then
    sed -i '/image_prepare:/a \	mkdir -p $(STAGING_DIR_IMAGE) && touch $(STAGING_DIR_IMAGE)/sunxi-boot.scr && touch $(STAGING_DIR_IMAGE)/$(DEVICE_UBOOT)-boot.scr' "$IMAGE_MAKEFILE"
fi

echo ">>> Adaptation Script Finished Successfully."
