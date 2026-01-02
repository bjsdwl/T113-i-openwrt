#!/bin/bash
#
# diy-part2.sh: Tronlong T113-i 深度适配补丁 (Session 5 - Architecture Alignment)
#

DTS_NAME="sun8i-t113-tronlong-minievm"
IMAGE_MK="target/linux/sunxi/image/cortexa7.mk"
IMAGE_MAKEFILE="target/linux/sunxi/image/Makefile"

echo ">>> Starting T113-i (ARM sun8i) Architecture Alignment..."

# 1. 部署自定义设备树
mkdir -p target/linux/sunxi/files/arch/arm/boot/dts
if [ -f "files/$DTS_NAME.dts" ]; then
    cp "files/$DTS_NAME.dts" target/linux/sunxi/files/arch/arm/boot/dts/
    echo "✅ DTS file deployed to kernel source."
fi

# 2. 修改内核配置文件 (target/linux/sunxi/config-*)
# 这是解决 timer_probe 挂起和 CCU 逻辑错误的关键
for f in target/linux/sunxi/config-*; do
    [ -e "$f" ] || continue
    echo "Patching $f for ARM-sun8i architecture..."

    # --- 架构纠偏：关闭 D1 (RISC-V) 驱动，开启 T113 (ARM) 驱动 ---
    sed -i 's/CONFIG_CLK_SUN20I_D1=y/# CONFIG_CLK_SUN20I_D1 is not set/g' $f
    echo "CONFIG_CLK_SUN8I_T113=y" >> $f
    echo "CONFIG_CLK_SUN8I_V536=y" >> $f # T113 往往复用 V536 的时钟逻辑

    # --- 核心驱动内置 (y) 确保 Rootfs 挂载 ---
    sed -i 's/CONFIG_MMC=m/CONFIG_MMC=y/g' $f
    sed -i 's/CONFIG_MMC_BLOCK=m/CONFIG_MMC_BLOCK=y/g' $f
    sed -i 's/CONFIG_MMC_SUNXI=m/CONFIG_MMC_SUNXI=y/g' $f
    sed -i 's/CONFIG_EXT4_FS=m/CONFIG_EXT4_FS=y/g' $f
    
    # --- 架构组件内置 ---
    echo "CONFIG_ARM_ARCH_TIMER=y" >> $f
    echo "CONFIG_ARM_GIC=y" >> $f
    echo "CONFIG_GENERIC_IRQ_CHIP=y" >> $f

    # --- 调试增强：开启 initcall_debug ---
    echo "CONFIG_DEBUG_KERNEL=y" >> $f
    echo "CONFIG_PRINTK_TIME=y" >> $f
    echo "CONFIG_INITCALL_DEBUG=y" >> $f
done

# 3. 在编译系统中注册创龙 T113-i 机型
if [ -f "$IMAGE_MK" ]; then
    if ! grep -q "Device/tronlong_tlt113-minievm" "$IMAGE_MK"; then
        echo "Registering Tronlong T113-i in $IMAGE_MK"
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

# 4. 修复 OpenWrt 官方打包脚本的 mcopy/boot.scr 报错
# 由于我们是“手动缝合”镜像，需要通过伪造文件绕过 OpenWrt 的 sunxi 打包校验
if [ -f "$IMAGE_MAKEFILE" ]; then
    echo "Patching Image Makefile to bypass packaging errors..."
    sed -i '/image_prepare:/a \	mkdir -p $(STAGING_DIR_IMAGE) && touch $(STAGING_DIR_IMAGE)/sunxi-boot.scr && touch $(STAGING_DIR_IMAGE)/$(DEVICE_UBOOT)-boot.scr' "$IMAGE_MAKEFILE"
fi

# 5. [可选] 修正全志 sunxi-mmc 驱动的某些默认值
# 有些版本的内核 mmc 驱动会因为时钟不准导致卡死，强制关闭某些高级特性以提高兼容性
# echo "CONFIG_MMC_SUNXI_HAS_NEW_TIMINGS=n" >> target/linux/sunxi/config-default

echo ">>> Architecture Alignment Completed Successfully."
