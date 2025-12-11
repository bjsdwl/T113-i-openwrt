#!/bin/bash
# Description: OpenWrt DIY script part 2 (Final Fix: U-Boot Binary Path)

DTS_NAME="sun8i-t113-tronlong-minievm"
TARGET_MK="target/linux/sunxi/image/cortexa7.mk"
KERNEL_DTS_DIR="target/linux/sunxi/files/arch/arm/boot/dts"
IMAGE_MAKEFILE="target/linux/sunxi/image/Makefile"

# 我们借用的 U-Boot 机型名称
UBOOT_DEVICE_NAME="sun8i-r528-qa-board"

echo "-------------------------------------------------------"
echo "Starting DIY Part 2: Customizing for Tronlong TLT113-MiniEVM"
echo "-------------------------------------------------------"

# ==============================================================================
# 1. 部署 DTS 文件
# ==============================================================================
mkdir -p "$KERNEL_DTS_DIR"
mkdir -p target/linux/sunxi/dts

if ls files/*.dts* 1> /dev/null 2>&1; then
    echo "  -> Found DTS files. Copying..."
    cp files/*.dts* "$KERNEL_DTS_DIR/"
    cp files/*.dts* target/linux/sunxi/dts/
    echo "  -> Success: Device Tree files deployed."
else
    echo "  -> Error: No DTS files found!"
    exit 1
fi

# ==============================================================================
# 2. 手动生成 boot.scr
# ==============================================================================
echo "  -> Generating custom boot.scr..."

cat <<EOF > boot.cmd
# OpenWrt Boot Script for Tronlong T113
part uuid mmc 0:2 uuid
setenv bootargs console=ttyS0,115200 root=PARTUUID=\${uuid} rootwait panic=10 earlycon=uart8250,mmio32,0x02500000
load mmc 0:1 \${kernel_addr_r} zImage
load mmc 0:1 \${fdt_addr_r} $DTS_NAME.dtb
bootz \${kernel_addr_r} - \${fdt_addr_r}
EOF

mkimage -C none -A arm -T script -d boot.cmd files/boot.scr

if [ -f "files/boot.scr" ]; then
    echo "  -> Success: files/boot.scr generated."
else
    echo "  -> Error: Failed to generate boot.scr!"
    exit 1
fi

# ==============================================================================
# 3. [核心绝招] 暴力修改 Image Makefile
# 修复 boot.scr 和 u-boot-with-spl.bin 的路径问题
# ==============================================================================
echo "  -> Patching Image Makefile..."

if [ -f "$IMAGE_MAKEFILE" ]; then
    # 修复 1: 强制使用我们手动生成的 boot.scr
    sed -i 's|\$(STAGING_DIR_IMAGE)/\$(DEVICE_NAME)-boot.scr|\$(TOPDIR)/files/boot.scr|g' "$IMAGE_MAKEFILE"
    
    # 修复 2: 强制指向真实存在的 U-Boot 二进制文件 (sun8i-r528-qa-board-u-boot-with-spl.bin)
    # 这一步将 $(DEVICE_NAME)-u-boot-with-spl.bin 替换为我们借用的那个机型的文件名
    sed -i "s|\$(STAGING_DIR_IMAGE)/\$(DEVICE_NAME)-u-boot-with-spl.bin|\$(STAGING_DIR_IMAGE)/${UBOOT_DEVICE_NAME}-u-boot-with-spl.bin|g" "$IMAGE_MAKEFILE"
    
    echo "  -> Success: Makefile patched to fix file paths."
else
    echo "  -> Error: Image Makefile not found!"
    exit 1
fi

# ==============================================================================
# 4. 注入机型定义
# ==============================================================================
if [ ! -f "$TARGET_MK" ]; then
    echo "  -> Error: Target Makefile $TARGET_MK not found!"
    exit 1
fi

cat <<EOF >> "$TARGET_MK"

# --- Added by DIY Script for Tronlong TLT113-MiniEVM ---
define Device/tronlong_tlt113-minievm
  \$(Device/sunxi-img)
  DEVICE_VENDOR := Tronlong
  DEVICE_MODEL := TLT113-MiniEVM (NAND/HDMI)
  DEVICE_DTS := $DTS_NAME
  DEVICE_UBOOT := $UBOOT_DEVICE_NAME
  UBOOT_CONFIG_OVERRIDES := CONFIG_DRAM_CLK=792 CONFIG_DRAM_ZQ=8092667 CONFIG_DEFAULT_DEVICE_TREE="$DTS_NAME"
  SUPPORTED_DEVICES := tronlong,tlt113-minievm
endef
TARGET_DEVICES += tronlong_tlt113-minievm
# -------------------------------------------------------
EOF

echo "  -> Success: Device definition appended."
echo "-------------------------------------------------------"
echo "DIY Part 2 Finished Successfully."
