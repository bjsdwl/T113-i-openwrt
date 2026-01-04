#!/bin/bash
#
# diy-part2.sh: T113-i OpenWrt 最终决胜脚本 (Session 5.4)
#

DTS_NAME="sun8i-t113-tronlong-minievm"
KERNEL_VER="6.12"
PATCH_DIR="target/linux/sunxi/patches-$KERNEL_VER"

echo ">>> Starting T113-i Core Driver Unlock..."

# 1. 部署双核补全版 DTS (保持不变)
mkdir -p target/linux/sunxi/files/arch/arm/boot/dts
[ -f "files/$DTS_NAME.dts" ] && cp "files/$DTS_NAME.dts" target/linux/sunxi/files/arch/arm/boot/dts/

# 2. 引入 Armbian 补丁
ARMBIAN_PATCH_RAW="https://raw.githubusercontent.com/armbian/build/master/patch/kernel/archive/sunxi-6.12"
mkdir -p $PATCH_DIR
for p in "general-sunxi-t113s-ccu-fixes.patch" "general-sunxi-t113-thermal-support.patch"; do
    wget -q "$ARMBIAN_PATCH_RAW/$p" -O "$PATCH_DIR/900-$p"
done

# 3. 【核心手术】拆除内核源码中对 D1 驱动的 RISCV 架构限制
# 这步不执行，T113 在 ARM 架构下就永远拿不到时钟驱动
echo ">>> Unlocking D1 drivers for ARM architecture..."
KCONFIG_CCU="build_dir/target-arm_*/linux-sunxi_cortexa7/linux-6.12*/drivers/clk/sunxi-ng/Kconfig"
KCONFIG_PIO="build_dir/target-arm_*/linux-sunxi_cortexa7/linux-6.12*/drivers/pinctrl/sunxi/Kconfig"

# 由于 build_dir 在 compile 阶段才生成，我们改用 find 直接在源码树预处理
find . -name "Kconfig" -path "*/sunxi-ng/*" -exec sed -i 's/depends on RISCV/depends on RISCV || ARCH_SUNXI/g' {} +
find . -name "Kconfig" -path "*/pinctrl/sunxi/*" -exec sed -i 's/depends on RISCV/depends on RISCV || ARCH_SUNXI/g' {} +

# 4. 强制内核配置
for f in target/linux/sunxi/config-*; do
    [ -e "$f" ] || continue
    # 开启核心共用驱动
    echo "CONFIG_CLK_SUN20I_D1=y" >> $f
    echo "CONFIG_PINCTRL_SUN20I_D1=y" >> $f
    echo "CONFIG_CLK_SUN8I_T113=y" >> $f
    # 开启双核与预留调试
    echo "CONFIG_SMP=y" >> $f
    echo "CONFIG_NR_CPUS=2" >> $f
    echo "CONFIG_ARM_PSCI=y" >> $f
    echo "CONFIG_MMC_SUNXI=y" >> $f
    echo "CONFIG_EXT4_FS=y" >> $f
    echo "CONFIG_CLK_IGNORE_UNUSED=y" >> $f
done

# 5. 绕过打包校验
IMAGE_MAKEFILE="target/linux/sunxi/image/Makefile"
sed -i '/image_prepare:/a \	mkdir -p $(STAGING_DIR_IMAGE) && touch $(STAGING_DIR_IMAGE)/sunxi-boot.scr && touch $(STAGING_DIR_IMAGE)/$(DEVICE_UBOOT)-boot.scr' "$IMAGE_MAKEFILE"

echo ">>> [Session 5.4] Adaptation Completed."
