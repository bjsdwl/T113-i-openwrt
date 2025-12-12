#!/bin/bash
# Description: OpenWrt DIY script part 2 (Pre-built U-Boot Injection)

DTS_NAME="sun8i-t113-tronlong-minievm"
TARGET_MK="target/linux/sunxi/image/cortexa7.mk"
KERNEL_DTS_DIR="target/linux/sunxi/files/arch/arm/boot/dts"
IMAGE_MAKEFILE="target/linux/sunxi/image/Makefile"

# 这是一个占位符，用来骗过 OpenWrt 的依赖检查，实际打包用的是你上传的文件
PLACEHOLDER_UBOOT="nanopi_neo"

echo "-------------------------------------------------------"
echo "Starting DIY Part 2: Injecting Pre-built U-Boot"
echo "-------------------------------------------------------"

# ==============================================================================
# 1. 检查必要文件是否存在
# ==============================================================================
if [ ! -f "files/u-boot-sunxi-with-spl.bin" ]; then
    echo "❌ Error: files/u-boot-sunxi-with-spl.bin NOT FOUND!"
    echo "   Please upload the official U-Boot binary to the files/ directory."
    exit 1
fi
echo "  -> Found pre-built U-Boot binary."

# ==============================================================================
# 2. 部署 DTS 文件
# ==============================================================================
mkdir -p "$KERNEL_DTS_DIR"
mkdir -p target/linux/sunxi/dts
if ls files/*.dts* 1> /dev/null 2>&1; then
    echo "  -> Found DTS files. Copying..."
    cp files/*.dts* "$KERNEL_DTS_DIR/"
    cp files/*.dts* target/linux/sunxi/dts/
else
    echo "❌ Error: No DTS files found!"
    exit 1
fi

# ==============================================================================
# 3. 手动生成 boot.scr
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

if [ ! -f "files/boot.scr" ]; then
    echo "❌ Error: Failed to generate boot.scr!"
    exit 1
fi

# ==============================================================================
# 4. [魔改] 修改打包逻辑 (核心步骤)
# ==============================================================================
echo "  -> Patching Image Makefile to use local files..."
if [ -f "$IMAGE_MAKEFILE" ]; then
    # 1. 强制 boot.scr 指向我们生成的本地文件
    sed -i 's|\$(STAGING_DIR_IMAGE)/\$(DEVICE_NAME)-boot.scr|\$(TOPDIR)/files/boot.scr|g' "$IMAGE_MAKEFILE"
    
    # 2. 强制 U-Boot 指向我们要上传的那个文件
    # 这里的正则会将任何形如 "...-u-boot-with-spl.bin" 的路径
    # 替换为你上传在 files/ 目录下的那个文件的绝对路径
    sed -i 's|\$(STAGING_DIR_IMAGE)/.*-u-boot-with-spl.bin|\$(TOPDIR)/files/u-boot-sunxi-with-spl.bin|g' "$IMAGE_MAKEFILE"
    
    echo "  -> Success: Image Makefile patched."
    # 打印修改行验证
    grep "files/u-boot-sunxi-with-spl.bin" "$IMAGE_MAKEFILE"
else
    echo "❌ Error: Image Makefile not found!"
    exit 1
fi

# ==============================================================================
# 5. 注入机型定义
# ==============================================================================
if [ ! -f "$TARGET_MK" ]; then
    echo "❌ Error: Target Makefile $TARGET_MK not found!"
    exit 1
fi

cat <<EOF >> "$TARGET_MK"

define Device/tronlong_tlt113-minievm
  \$(Device/sunxi-img)
  DEVICE_VENDOR := Tronlong
  DEVICE_MODEL := TLT113-MiniEVM (NAND/HDMI)
  DEVICE_DTS := $DTS_NAME
  
  # 使用 H3 的 U-Boot 占位，仅仅是为了骗过编译系统的依赖检查
  # 实际上打包时会用上面 sed 替换掉的那个 files/u-boot...bin
  DEVICE_UBOOT := $PLACEHOLDER_UBOOT
  
  # 参数其实没用了，因为用的是预编译的 bin，但为了格式完整保留
  UBOOT_CONFIG_OVERRIDES := CONFIG_DRAM_CLK=792 CONFIG_DRAM_ZQ=8092667
  
  SUPPORTED_DEVICES := tronlong,tlt113-minievm
endef
TARGET_DEVICES += tronlong_tlt113-minievm
EOF

echo "  -> Success: Device definition appended."
echo "-------------------------------------------------------"
echo "DIY Part 2 Finished Successfully."
