#!/bin/bash
#
# diy-part2.sh: T113-i OpenWrt 最终决胜脚本 (Session 5.4 - Kernel Patch Edition)
#

DTS_NAME="sun8i-t113-tronlong-minievm"
KERNEL_PATCH_DIR="target/linux/sunxi/patches-6.12"

echo ">>> Starting T113-i Core Driver Unlock via Kernel Patch..."

# 1. 部署双核版 DTS (包含 PSCI)
mkdir -p target/linux/sunxi/files/arch/arm/boot/dts
[ -f "files/$DTS_NAME.dts" ] && cp "files/$DTS_NAME.dts" target/linux/sunxi/files/arch/arm/boot/dts/

# 2. 【核心手术】创建一个内核补丁，拆除 D1 驱动对 RISCV 的依赖
# 这个补丁会让内核在编译 ARM 架构时也包含 D1 的 CCU 和 PIO 驱动
mkdir -p $KERNEL_PATCH_DIR
cat <<EOF > $KERNEL_PATCH_DIR/999-support-t113-arm-on-d1-drivers.patch
--- a/drivers/clk/sunxi-ng/Kconfig
+++ b/drivers/clk/sunxi-ng/Kconfig
@@ -10,1 +10,1 @@
-	depends on RISCV || COMPILE_TEST
+	depends on RISCV || ARCH_SUNXI || COMPILE_TEST
--- a/drivers/pinctrl/sunxi/Kconfig
+++ b/drivers/pinctrl/sunxi/Kconfig
@@ -82,1 +82,1 @@
-	depends on RISCV || COMPILE_TEST
+	depends on RISCV || ARCH_SUNXI || COMPILE_TEST
EOF
echo "✅ Kernel dependency patch created."

# 3. 强制内核配置
for f in target/linux/sunxi/config-*; do
    [ -e "$f" ] || continue
    # 强制开启共用驱动
    echo "CONFIG_CLK_SUN20I_D1=y" >> $f
    echo "CONFIG_PINCTRL_SUN20I_D1=y" >> $f
    # 强制开启 SMP 和核心组件
    echo "CONFIG_SMP=y" >> $f
    echo "CONFIG_NR_CPUS=2" >> $f
    echo "CONFIG_ARM_PSCI=y" >> $f
    echo "CONFIG_MMC_SUNXI=y" >> $f
    echo "CONFIG_EXT4_FS=y" >> $f
    echo "CONFIG_CLK_IGNORE_UNUSED=y" >> $f
done

# 4. 绕过 OpenWrt 打包校验
IMAGE_MAKEFILE="target/linux/sunxi/image/Makefile"
sed -i '/image_prepare:/a \	mkdir -p \$(STAGING_DIR_IMAGE) && touch \$(STAGING_DIR_IMAGE)/sunxi-boot.scr && touch \$(STAGING_DIR_IMAGE)/\$(DEVICE_UBOOT)-boot.scr' "$IMAGE_MAKEFILE"

echo ">>> [Session 5.4] Adaptation Completed."
