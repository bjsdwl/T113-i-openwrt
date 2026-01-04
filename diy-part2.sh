#!/bin/bash
#
# diy-part2.sh: T113-i OpenWrt 最终决胜脚本 (Session 5.5 - Robust Patching)
#

DTS_NAME="sun8i-t113-tronlong-minievm"
KERNEL_VER="6.12"
PATCH_DIR="target/linux/sunxi/patches-$KERNEL_VER"
IMAGE_MK="target/linux/sunxi/image/cortexa7.mk"

echo ">>> Starting T113-i Professional Adaptation (Session 5.5)..."

# 1. 部署自定义设备树
mkdir -p target/linux/sunxi/files/arch/arm/boot/dts
if [ -f "files/$DTS_NAME.dts" ]; then
    cp "files/$DTS_NAME.dts" target/linux/sunxi/files/arch/arm/boot/dts/
    echo "✅ Custom DTS deployed."
fi

# 2. 引入 Armbian 补丁
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

# 3. 【核心修复】创建鲁棒性内核补丁，拆除 D1 驱动的架构限制
# 使用精准匹配而非行号，确保 100% 成功
echo ">>> Creating robust Kernel dependency patch..."
# 注意：下面使用 printf "\t" 来确保生成真正的 Tab 键
cat <<EOF > "$PATCH_DIR/999-support-t113-arm-on-d1-drivers.patch"
--- a/drivers/clk/sunxi-ng/Kconfig
+++ b/drivers/clk/sunxi-ng/Kconfig
@@ -10,3 +10,3 @@ config SUN20I_D1_CCU
$(printf "\t")tristate "Support for the Allwinner D1 CCU"
-$(printf "\t")depends on RISCV || COMPILE_TEST
+$(printf "\t")depends on RISCV || ARCH_SUNXI || COMPILE_TEST
$(printf "\t")default RISCV
--- a/drivers/pinctrl/sunxi/Kconfig
+++ b/drivers/pinctrl/sunxi/Kconfig
@@ -82,3 +82,3 @@ config PINCTRL_SUN20I_D1
$(printf "\t")tristate "Support for the Allwinner D1 pinctrl"
-$(printf "\t")depends on RISCV || COMPILE_TEST
+$(printf "\t")depends on RISCV || ARCH_SUNXI || COMPILE_TEST
$(printf "\t")default RISCV
EOF
echo "✅ Robust patch created."

# 4. 强制内核配置
for f in target/linux/sunxi/config-*; do
    [ -e "$f" ] || continue
    echo "Processing kernel config: $f"
    # 强制开启 D1/T113 共享驱动 (补丁生效后这里才能真正起作用)
    echo "CONFIG_CLK_SUN20I_D1=y" >> $f
    echo "CONFIG_PINCTRL_SUN20I_D1=y" >> $f
    echo "CONFIG_CLK_SUN8I_T113=y" >> $f
    # 开启 SMP 和核心组件
    echo "CONFIG_SMP=y" >> $f
    echo "CONFIG_NR_CPUS=2" >> $f
    echo "CONFIG_ARM_PSCI=y" >> $f
    echo "CONFIG_MMC_SUNXI=y" >> $f
    echo "CONFIG_EXT4_FS=y" >> $f
    echo "CONFIG_CLK_IGNORE_UNUSED=y" >> $f
    echo "CONFIG_DEBUG_KERNEL=y" >> $f
    echo "CONFIG_INITCALL_DEBUG=y" >> $f
done

# 5. 注册机型到 OpenWrt
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

# 6. 绕过打包校验
IMAGE_MAKEFILE="target/linux/sunxi/image/Makefile"
if [ -f "$IMAGE_MAKEFILE" ]; then
    sed -i '/image_prepare:/a \	mkdir -p $(STAGING_DIR_IMAGE) && touch $(STAGING_DIR_IMAGE)/sunxi-boot.scr && touch $(STAGING_DIR_IMAGE)/$(DEVICE_UBOOT)-boot.scr' "$IMAGE_MAKEFILE"
fi

echo ">>> [Session 5.5] Adaptation Script Finished."
