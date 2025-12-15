#!/bin/bash
# Description: OpenWrt DIY script part 2 (20MB U-Boot + Partition Fix)

DTS_NAME="sun8i-t113-tronlong-minievm"
TARGET_MK="target/linux/sunxi/image/cortexa7.mk"
KERNEL_DTS_DIR="target/linux/sunxi/files/arch/arm/boot/dts"
GEN_IMAGE_SCRIPT="target/linux/sunxi/image/gen_sunxi_sdcard_img.sh"

echo "-------------------------------------------------------"
echo "Starting DIY Part 2: Tronlong TLT113 (20MB Edition)"
echo "-------------------------------------------------------"

# ==============================================================================
# 1. 检查 20MB 文件 (必须存在)
# ==============================================================================
if [ ! -f "files/u-boot-sunxi-with-spl.bin" ]; then
    echo "❌ Error: files/u-boot-sunxi-with-spl.bin NOT FOUND!"
    exit 1
fi
# 简单检查大小，确保是那个大文件
FILE_SIZE=$(stat -c%s "files/u-boot-sunxi-with-spl.bin")
if [ "$FILE_SIZE" -lt 2000000 ]; then
    echo "⚠️ Warning: The uploaded U-Boot file seems small (<2MB)."
    echo "   Ensure you uploaded the 20MB version!"
fi

# ==============================================================================
# 2. 部署 DTS
# ==============================================================================
mkdir -p "$KERNEL_DTS_DIR"
mkdir -p target/linux/sunxi/dts
if ls files/*.dts* 1> /dev/null 2>&1; then
    cp files/*.dts* "$KERNEL_DTS_DIR/"
    cp files/*.dts* target/linux/sunxi/dts/
    echo "  -> Success: DTS deployed."
else
    echo "❌ Error: No DTS files found!"
    exit 1
fi

# ==============================================================================
# 3. 生成 boot.scr
# ==============================================================================
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
# 4. [关键] 修改分区起始位置 (给 20MB U-Boot 让路)
# ==============================================================================
if [ -f "$GEN_IMAGE_SCRIPT" ]; then
    # 将 -l 1024 (512KB) 改为 -l 65536 (32MB)
    sed -i 's/-l 1024/-l 65536/g' "$GEN_IMAGE_SCRIPT"
    echo "  -> Success: Partition start moved to 32MB."
else
    echo "❌ Error: gen_sunxi_sdcard_img.sh not found!"
    exit 1
fi

# ==============================================================================
# 5. [核心] 注入机型 & 文件复制钩子
# ==============================================================================
# 这里的逻辑是：
# 1. 定义一个 Build 命令 'install-tronlong-files'，负责把文件复制到位
# 2. 在 Device 定义中，把这个命令加入到 IMAGE/sdcard.img.gz 的生成链中

cat <<EOF >> "$TARGET_MK"

# 定义复制文件的构建步骤
define Build/install-tronlong-files
	\$(CP) \$(TOPDIR)/files/u-boot-sunxi-with-spl.bin \$(STAGING_DIR_IMAGE)/tronlong_tlt113-minievm-u-boot-with-spl.bin
	\$(CP) \$(TOPDIR)/files/boot.scr \$(STAGING_DIR_IMAGE)/tronlong_tlt113-minievm-boot.scr
endef

define Device/tronlong_tlt113-minievm
  \$(Device/sunxi-img)
  DEVICE_VENDOR := Tronlong
  DEVICE_MODEL := TLT113-MiniEVM (20MB U-Boot)
  DEVICE_DTS := $DTS_NAME
  
  # 借用 nanopi_neo 通过编译检查
  DEVICE_UBOOT := nanopi_neo
  
  # 自定义打包流程：先复制文件，再打包
  IMAGE/sdcard.img.gz := \\
      install-tronlong-files | \\
      sunxi-sdcard | append-metadata | gzip
      
  SUPPORTED_DEVICES := tronlong,tlt113-minievm
endef
TARGET_DEVICES += tronlong_tlt113-minievm
EOF

echo "  -> Success: Device definition appended."
echo "DIY Part 2 Finished Successfully."
