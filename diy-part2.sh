#!/bin/bash
#
# diy-part2.sh: T113-i OpenWrt 深度适配脚本 (Session 5 - Armbian Patch Edition)
#

DTS_NAME="sun8i-t113-tronlong-minievm"
# 根据你的日志，确认为 sunxi 平台和 6.12 内核
KERNEL_VER="6.12"
PATCH_DIR="target/linux/sunxi/patches-$KERNEL_VER"
IMAGE_MK="target/linux/sunxi/image/cortexa7.mk"
IMAGE_MAKEFILE="target/linux/sunxi/image/Makefile"

echo ">>> Starting T113-i (sun8i) Professional Adaptation..."

# ==============================================================================
# 1. 部署自定义设备树 (DTS)
# ==============================================================================
mkdir -p target/linux/sunxi/files/arch/arm/boot/dts
if [ -f "files/$DTS_NAME.dts" ]; then
    cp "files/$DTS_NAME.dts" target/linux/sunxi/files/arch/arm/boot/dts/
    echo "✅ Custom DTS deployed."
fi

# ==============================================================================
# 2. 引入 Armbian 高质量内核补丁 (站在巨人的肩膀上)
# ==============================================================================
# Armbian 的 sunxi-6.12 补丁库地址
ARMBIAN_PATCH_RAW="https://raw.githubusercontent.com/armbian/build/master/patch/kernel/archive/sunxi-6.12"

echo ">>> Ingesting Armbian stability patches for T113-i..."
mkdir -p $PATCH_DIR

# 选择性拉取 Armbian 修复 T113/D1 核心问题的补丁
# 900-905 序列号是为了确保在 OpenWrt 官方补丁之后运行
patches=(
    "general-sunxi-t113s-ccu-fixes.patch"      # 修复 T113 时钟树错误
    "general-sunxi-wdt-t113s-support.patch"   # 开启看门狗支持
    "general-sunxi-t113-thermal-support.patch" # 开启温度传感器支持，防止过热降频
)

for p in "${patches[@]}"; do
    wget -q "$ARMBIAN_PATCH_RAW/$p" -O "$PATCH_DIR/900-$p"
    if [ $? -eq 0 ]; then
        echo "✅ Armbian patch added: $p"
    else
        echo "⚠️ Note: Patch $p not found in Armbian repo, skipping."
        rm -f "$PATCH_DIR/900-$p"
    fi
done

# ==============================================================================
# 3. 架构纠偏与内核配置强刷 (解决 timer_probe 挂起)
# ==============================================================================
for f in target/linux/sunxi/config-*; do
    [ -e "$f" ] || continue
    echo "Processing kernel config: $f"

    # --- 架构拨乱反正 ---
    # 彻底禁用误导的 D1 (RISC-V) 时钟定义，强制开启 T113s (ARM)
    sed -i 's/CONFIG_CLK_SUN20I_D1=y/# CONFIG_CLK_SUN20I_D1 is not set/g' $f
    echo "CONFIG_CLK_SUN8I_T113=y" >> $f
    echo "CONFIG_CLK_SUN8I_T113_CCU=y" >> $f

    # --- 驱动强内置 (y) ---
    # 必须内置才能在没有 initramfs 的情况下直接挂载 SD 卡
    sed -i 's/CONFIG_MMC=m/CONFIG_MMC=y/g' $f
    sed -i 's/CONFIG_MMC_BLOCK=m/CONFIG_MMC_BLOCK=y/g' $f
    sed -i 's/CONFIG_MMC_SUNXI=m/CONFIG_MMC_SUNXI=y/g' $f
    sed -i 's/CONFIG_EXT4_FS=m/CONFIG_EXT4_FS=y/g' $f
    
    # --- 开启核心组件 ---
    echo "CONFIG_ARM_ARCH_TIMER=y" >> $f
    echo "CONFIG_ARM_GIC=y" >> $f
    echo "CONFIG_GENERIC_IRQ_CHIP=y" >> $f

    # --- 开启调试日志 (Session 5 必须) ---
    echo "CONFIG_DEBUG_KERNEL=y" >> $f
    echo "CONFIG_INITCALL_DEBUG=y" >> $f
    echo "CONFIG_PRINTK_TIME=y" >> $f
    echo "CONFIG_EARLY_PRINTK=y" >> $f
    # 防止由于 unused clocks 导致串口在启动中途断开
    echo "CONFIG_CLK_IGNORE_UNUSED=y" >> $f
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
# 5. 绕过打包校验 (手术准备)
# ==============================================================================
# 既然我们通过 GitHub Actions 进行“手动物理缝合”，我们不需要 OpenWrt 默认的打包流程
# 伪造 boot.scr 避免 make 流程中断
if [ -f "$IMAGE_MAKEFILE" ]; then
    echo "Bypassing sunxi image prepare errors..."
    sed -i '/image_prepare:/a \	mkdir -p $(STAGING_DIR_IMAGE) && touch $(STAGING_DIR_IMAGE)/sunxi-boot.scr && touch $(STAGING_DIR_IMAGE)/$(DEVICE_UBOOT)-boot.scr' "$IMAGE_MAKEFILE"
fi

echo ">>> [Session 5] T113-i Adaptation Script Finished."
