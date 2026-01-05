#!/bin/bash
#
# diy-part2.sh: T113-i OpenWrt 最终决胜脚本 (Session 5.5)
#

DTS_NAME="sun8i-t113-tronlong-minievm"
KERNEL_VER="6.12"
PATCH_DIR="target/linux/sunxi/patches-$KERNEL_VER"

echo ">>> [Stage 1] Deploying customized Device Tree..."
mkdir -p target/linux/sunxi/files/arch/arm/boot/dts
if [ -f "files/$DTS_NAME.dts" ]; then
    cp "files/$DTS_NAME.dts" target/linux/sunxi/files/arch/arm/boot/dts/
    echo "OK: $DTS_NAME.dts deployed."
fi

echo ">>> [Stage 2] Fetching Mainline patches..."
ARMBIAN_PATCH_RAW="https://raw.githubusercontent.com/armbian/build/master/patch/kernel/archive/sunxi-6.12"
mkdir -p $PATCH_DIR
for p in "general-sunxi-t113s-ccu-fixes.patch" "general-sunxi-t113-thermal-support.patch"; do
    wget -q "$ARMBIAN_PATCH_RAW/$p" -O "$PATCH_DIR/900-$p" && echo "Downloaded: $p"
done

echo ">>> [Stage 3] Unlocking D1 drivers for ARM T113-i..."
# 暴力解除 Kconfig 对 CCU 和 PIO 驱动的 RISCV 架构绑定
find . -name "Kconfig" -path "*/sunxi-ng/*" -exec sed -i 's/depends on RISCV/depends on RISCV || ARCH_SUNXI/g' {} +
find . -name "Kconfig" -path "*/pinctrl/sunxi/*" -exec sed -i 's/depends on RISCV/depends on RISCV || ARCH_SUNXI/g' {} +

echo ">>> [Stage 4] Forcing Kernel Configurations..."
for f in target/linux/sunxi/config-*; do
    [ -e "$f" ] || continue
    # 启用核心共用驱动
    echo "CONFIG_CLK_SUN20I_D1=y" >> $f
    echo "CONFIG_PINCTRL_SUN20I_D1=y" >> $f
    echo "CONFIG_PINCTRL_SUN8I_T113S=y" >> $f
    echo "CONFIG_CLK_SUN8I_T113=y" >> $f
    # 开启双核与预留调试
    echo "CONFIG_SMP=y" >> $f
    echo "CONFIG_NR_CPUS=2" >> $f
    echo "CONFIG_ARM_PSCI=y" >> $f
    echo "CONFIG_MMC_SUNXI=y" >> $f
    echo "CONFIG_EXT4_FS=y" >> $f
    echo "CONFIG_CLK_IGNORE_UNUSED=y" >> $f
    echo "CONFIG_RTC_DRV_SUN6I=y" >> $f
done

echo ">>> [Stage 5] Final Makefile Tweak..."
IMAGE_MAKEFILE="target/linux/sunxi/image/Makefile"
sed -i '/image_prepare:/a \	mkdir -p $(STAGING_DIR_IMAGE) && touch $(STAGING_DIR_IMAGE)/sunxi-boot.scr && touch $(STAGING_DIR_IMAGE)/$(DEVICE_UBOOT)-boot.scr' "$IMAGE_MAKEFILE"

echo ">>> [Final] Adaptation Completed."
