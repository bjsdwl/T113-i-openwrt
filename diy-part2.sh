#!/bin/bash
# Description: OpenWrt DIY script part 2 (Transplant Mode - Hardcode Paths)

DTS_FILENAME="sun8i-t113-tronlong-minievm.dts"
DTS_NAME="sun8i-t113-tronlong-minievm"
TARGET_MK="target/linux/sunxi/image/cortexa7.mk"
KERNEL_DTS_DIR="target/linux/sunxi/files/arch/arm/boot/dts"
IMAGE_MAKEFILE="target/linux/sunxi/image/Makefile"

echo "-------------------------------------------------------"
echo "Starting DIY Part 2: Preparation for Transplant"
echo "-------------------------------------------------------"

# ==============================================================================
# 1. 检查必要文件
# ==============================================================================
if [ ! -f "files/u-boot-sunxi-with-spl.bin" ]; then
    echo "❌ Error: files/u-boot-sunxi-with-spl.bin NOT FOUND!"
    exit 1
fi

# ==============================================================================
# 2. 部署 DTS 文件
# ==============================================================================
mkdir -p "$KERNEL_DTS_DIR"
mkdir -p target/linux/sunxi/dts

if [ -f "files/$DTS_FILENAME" ]; then
    echo "  -> Deploying DTS..."
    cp "files/$DTS_FILENAME" "$KERNEL_DTS_DIR/"
    cp "files/$DTS_FILENAME" target/linux/sunxi/dts/
else
    echo "❌ Error: files/$DTS_FILENAME not found!"
    exit 1
fi

# ==============================================================================
# 3. 生成 boot.scr
# ==============================================================================
echo "  -> Generating boot.scr..."
cat <<EOF > boot.cmd
# OpenWrt Boot Script for Tronlong T113
part uuid mmc 0:2 uuid
setenv bootargs console=ttyS0,115200 root=PARTUUID=\${uuid} rootwait panic=10 earlycon=uart8250,mmio32,0x02500000
load mmc 0:1 \${kernel_addr_r} zImage
load mmc 0:1 \${fdt_addr_r} $DTS_NAME.dtb
bootz \${kernel_addr_r} - \${fdt_addr_r}
EOF

mkimage -C none -A arm -T script -d boot.cmd files/boot.scr
if [ ! -f "files/boot.scr" ]; then
    echo "❌ Error: Failed to generate boot.scr!"
    exit 1
fi

# ==============================================================================
# 4. [关键] 暴力修改 Makefile 路径 (彻底解决 No such file)
# ==============================================================================
echo "  -> Patching Image Makefile to force local paths..."

if [ -f "$IMAGE_MAKEFILE" ]; then
    # 1. 替换 boot.scr 的路径
    # 原文可能是: $(STAGING_DIR_IMAGE)/$(DEVICE_NAME)-boot.scr
    # 替换为: $(TOPDIR)/files/boot.scr
    sed -i 's|\$(STAGING_DIR_IMAGE)/\$(DEVICE_NAME)-boot.scr|\$(TOPDIR)/files/boot.scr|g' "$IMAGE_MAKEFILE"
    
    # 2. 替换 u-boot-with-spl.bin 的路径
    # 原文可能是: $(STAGING_DIR_IMAGE)/$(DEVICE_NAME)-u-boot-with-spl.bin
    # 替换为: $(TOPDIR)/files/u-boot-sunxi-with-spl.bin
    sed -i 's|\$(STAGING_DIR_IMAGE)/\$(DEVICE_NAME)-u-boot-with-spl.bin|\$(TOPDIR)/files/u-boot-sunxi-with-spl.bin|g' "$IMAGE_MAKEFILE"
    
    echo "  -> Success: Makefile patched."
else
    echo "❌ Error: Image Makefile not found!"
    exit 1
fi

# ==============================================================================
# 5. 注册机型
# ==============================================================================
if [ -f "$TARGET_MK" ]; then
    cat <<EOF >> "$TARGET_MK"

define Device/tronlong_tlt113-minievm
  \$(Device/sunxi-img)
  DEVICE_VENDOR := Tronlong
  DEVICE_MODEL := TLT113-MiniEVM (Transplant)
  DEVICE_DTS := $DTS_NAME
  # 这里的 U-Boot 名字已经不重要了，因为上面我们强改了 Makefile 路径
  DEVICE_UBOOT := nanopi_neo
  UBOOT_CONFIG_OVERRIDES := CONFIG_DRAM_CLK=792 CONFIG_DRAM_ZQ=8092667
  SUPPORTED_DEVICES := tronlong,tlt113-minievm
endef
TARGET_DEVICES += tronlong_tlt113-minievm
EOF
    echo "  -> Success: Device registered."
fi

echo "DIY Part 2 Finished."
