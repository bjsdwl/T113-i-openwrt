#!/bin/bash
# Description: OpenWrt DIY script part 2 (Custom Build Recipe Strategy)

DTS_NAME="sun8i-t113-tronlong-minievm"
TARGET_MK="target/linux/sunxi/image/cortexa7.mk"
KERNEL_DTS_DIR="target/linux/sunxi/files/arch/arm/boot/dts"
GEN_IMAGE_SCRIPT="target/linux/sunxi/image/gen_sunxi_sdcard_img.sh"

echo "-------------------------------------------------------"
echo "Starting DIY Part 2: Custom Build Recipe Strategy"
echo "-------------------------------------------------------"

# ==============================================================================
# 1. 检查 20MB 文件
# ==============================================================================
if [ ! -f "files/u-boot-sunxi-with-spl.bin" ]; then
    echo "❌ Error: files/u-boot-sunxi-with-spl.bin NOT FOUND!"
    exit 1
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
# 3. 生成 boot.scr (files/boot.scr)
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
# 4. 修改分区偏移 (32MB)
# ==============================================================================
if [ -f "$GEN_IMAGE_SCRIPT" ]; then
    sed -i 's/-l 1024/-l 65536/g' "$GEN_IMAGE_SCRIPT"
    echo "  -> Success: Partition start moved to 32MB."
else
    echo "❌ Error: gen_sunxi_sdcard_img.sh not found!"
    exit 1
fi

# ==============================================================================
# 5. [核心绝招] 定义全新的构建命令 + 注入机型
# ==============================================================================
# 我们不使用默认的 sunxi-sdcard，而是定义一个 tronlong-sdcard
# 直接在命令里写死 $(TOPDIR)/files/... 路径
# 这样就彻底绕过了 staging_dir 和文件名匹配的问题

cat <<EOF >> "$TARGET_MK"

# 定义 FAT32 块数 (参考原 Makefile)
FAT32_BLOCK_SIZE=1024
FAT32_BLOCKS=\$(shell echo \$\$((\$(CONFIG_SUNXI_SD_BOOT_PARTSIZE)*1024*1024/\$(FAT32_BLOCK_SIZE))))

# 自定义构建命令：直接使用 files/ 目录下的文件
define Build/tronlong-sdcard
	rm -f \$@.boot
	mkfs.fat \$@.boot -C \$(FAT32_BLOCKS)
	
	# 1. 复制 boot.scr (硬编码路径)
	mcopy -i \$@.boot \$(TOPDIR)/files/boot.scr ::boot.scr
	
	# 2. 复制内核 (标准变量)
	mcopy -i \$@.boot \$(IMAGE_KERNEL) ::uImage
	
	# 3. 调用打包脚本，传入 20MB U-Boot (硬编码路径)
	./gen_sunxi_sdcard_img.sh \$@ \\
		\$@.boot \\
		\$(IMAGE_ROOTFS) \\
		\$(CONFIG_SUNXI_SD_BOOT_PARTSIZE) \\
		\$(CONFIG_TARGET_ROOTFS_PARTSIZE) \\
		\$(TOPDIR)/files/u-boot-sunxi-with-spl.bin
	
	rm -f \$@.boot
endef

define Device/tronlong_tlt113-minievm
  \$(Device/sunxi-img)
  DEVICE_VENDOR := Tronlong
  DEVICE_MODEL := TLT113-MiniEVM (20MB U-Boot)
  DEVICE_DTS := $DTS_NAME
  
  # 随便填一个存在的 U-Boot 骗过依赖检查
  DEVICE_UBOOT := nanopi_neo
  
  # 使用我们自定义的构建命令 tronlong-sdcard
  IMAGE/sdcard.img.gz := \\
      tronlong-sdcard | append-metadata | gzip
      
  SUPPORTED_DEVICES := tronlong,tlt113-minievm
endef
TARGET_DEVICES += tronlong_tlt113-minievm
EOF

echo "  -> Success: Custom build recipe injected."
echo "DIY Part 2 Finished Successfully."
