#!/bin/bash
# Description: OpenWrt DIY script part 2 (Pipeline Injection Strategy)

DTS_NAME="sun8i-t113-tronlong-minievm"
TARGET_MK="target/linux/sunxi/image/cortexa7.mk"
KERNEL_DTS_DIR="target/linux/sunxi/files/arch/arm/boot/dts"
GEN_IMAGE_SCRIPT="target/linux/sunxi/image/gen_sunxi_sdcard_img.sh"

echo "-------------------------------------------------------"
echo "Starting DIY Part 2: Pipeline Injection Strategy"
echo "-------------------------------------------------------"

# ==============================================================================
# 1. 检查 20MB 文件 (必须存在)
# ==============================================================================
if [ ! -f "files/u-boot-sunxi-with-spl.bin" ]; then
    echo "❌ Error: files/u-boot-sunxi-with-spl.bin NOT FOUND!"
    exit 1
fi
echo "  -> Found U-Boot binary."

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
# 4. 修改分区偏移 (32MB Offset)
# ==============================================================================
if [ -f "$GEN_IMAGE_SCRIPT" ]; then
    sed -i 's/-l 1024/-l 65536/g' "$GEN_IMAGE_SCRIPT"
    echo "  -> Success: Partition start moved to 32MB."
else
    echo "❌ Error: gen_sunxi_sdcard_img.sh not found!"
    exit 1
fi

# ==============================================================================
# 5. [核心] 注入机型定义 (流水线强制复制)
# ==============================================================================
if [ ! -f "$TARGET_MK" ]; then
    echo "❌ Error: Target Makefile not found!"
    exit 1
fi

cat <<EOF >> "$TARGET_MK"

# 定义一个构建命令：install-tronlong-files
# 它的作用是：创建目录 -> 复制 U-Boot -> 复制 boot.scr
define Build/install-tronlong-files
	\$(INSTALL_DIR) \$(STAGING_DIR_IMAGE)
	\$(CP) \$(TOPDIR)/files/u-boot-sunxi-with-spl.bin \$(STAGING_DIR_IMAGE)/tronlong_tlt113-minievm-u-boot-with-spl.bin
	\$(CP) \$(TOPDIR)/files/boot.scr \$(STAGING_DIR_IMAGE)/tronlong_tlt113-minievm-boot.scr
endef

define Device/tronlong_tlt113-minievm
  \$(Device/sunxi-img)
  DEVICE_VENDOR := Tronlong
  DEVICE_MODEL := TLT113-MiniEVM (NAND/HDMI)
  DEVICE_DTS := $DTS_NAME
  
  # 这里随便写一个存在的 U-Boot 骗过检查，实际不用它
  DEVICE_UBOOT := nanopi_neo
  
  # 【关键点】
  # 修改镜像生成流水线 (Pipeline)
  # 在执行 sunxi-sdcard (打包) 之前，强制执行 install-tronlong-files (复制)
  # 这样文件就绝对会在那里等着打包程序了
  IMAGE/sdcard.img.gz := \\
      install-tronlong-files | \\
      sunxi-sdcard | append-metadata | gzip
      
  SUPPORTED_DEVICES := tronlong,tlt113-minievm
endef
TARGET_DEVICES += tronlong_tlt113-minievm
EOF

echo "  -> Success: Device definition with pipeline hook injected."
echo "DIY Part 2 Finished Successfully."
