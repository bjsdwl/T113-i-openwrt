#!/bin/bash
# Description: OpenWrt DIY script part 2 (Monolithic DTS + Pre-built U-Boot Injection)

# --- 配置变量 ---
DTS_FILENAME="sun8i-t113-tronlong-minievm.dts"
DTS_NAME="sun8i-t113-tronlong-minievm"
TARGET_MK="target/linux/sunxi/image/cortexa7.mk"
KERNEL_DTS_DIR="target/linux/sunxi/files/arch/arm/boot/dts"
IMAGE_MAKEFILE="target/linux/sunxi/image/Makefile"
# 占位符 U-Boot，用于骗过依赖检查
PLACEHOLDER_UBOOT="nanopi_neo"

echo "-------------------------------------------------------"
echo "Starting DIY Part 2: Tronlong TLT113-MiniEVM Injection"
echo "-------------------------------------------------------"

# ==============================================================================
# 1. 检查必要文件 (Safety Check)
# ==============================================================================
if [ ! -f "files/u-boot-sunxi-with-spl.bin" ]; then
    echo "❌ Error: files/u-boot-sunxi-with-spl.bin NOT FOUND!"
    echo "   Please upload the official U-Boot binary to the files/ directory."
    exit 1
fi

if [ ! -f "files/$DTS_FILENAME" ]; then
    echo "❌ Error: files/$DTS_FILENAME NOT FOUND!"
    exit 1
fi

# ==============================================================================
# 2. 部署单体 DTS 文件 (Deploy Monolithic DTS)
# ==============================================================================
echo "[1/4] Deploying Device Tree..."
mkdir -p "$KERNEL_DTS_DIR"
mkdir -p target/linux/sunxi/dts

# 复制到 Kernel Overlay (强制覆盖内核源码)
cp "files/$DTS_FILENAME" "$KERNEL_DTS_DIR/"
# 复制到标准目录 (备份)
cp "files/$DTS_FILENAME" target/linux/sunxi/dts/

echo "  -> Success: DTS file deployed."

# ==============================================================================
# 3. 手动生成 boot.scr (Generate Boot Script)
# ==============================================================================
echo "[2/4] Generating custom boot.scr..."
cat <<EOF > boot.cmd
# OpenWrt Boot Script for Tronlong T113
part uuid mmc 0:2 uuid
setenv bootargs console=ttyS0,115200 root=PARTUUID=\${uuid} rootwait panic=10 earlycon=uart8250,mmio32,0x02500000
load mmc 0:1 \${kernel_addr_r} zImage
load mmc 0:1 \${fdt_addr_r} $DTS_NAME.dtb
bootz \${kernel_addr_r} - \${fdt_addr_r}
EOF

# 使用 u-boot-tools 生成二进制脚本
mkimage -C none -A arm -T script -d boot.cmd files/boot.scr

if [ -f "files/boot.scr" ]; then
    echo "  -> Success: files/boot.scr generated."
else
    echo "❌ Error: Failed to generate boot.scr! (Is u-boot-tools installed?)"
    exit 1
fi

# ==============================================================================
# 4. 修改打包 Makefile (Patch ImageBuilder)
# ==============================================================================
echo "[3/4] Patching Image Makefile to use local files..."
if [ -f "$IMAGE_MAKEFILE" ]; then
    # 1. 强制 boot.scr 指向我们生成的本地文件
    # 原始: $(STAGING_DIR_IMAGE)/$(DEVICE_NAME)-boot.scr
    # 替换: $(TOPDIR)/files/boot.scr
    sed -i 's|\$(STAGING_DIR_IMAGE)/\$(DEVICE_NAME)-boot.scr|\$(TOPDIR)/files/boot.scr|g' "$IMAGE_MAKEFILE"
    
    # 2. 强制 U-Boot 二进制指向我们上传的文件
    # 原始: $(STAGING_DIR_IMAGE)/...-u-boot-with-spl.bin
    # 替换: $(TOPDIR)/files/u-boot-sunxi-with-spl.bin
    # 使用正则匹配任何包含 -u-boot-with-spl.bin 的路径
    sed -i 's|\$(STAGING_DIR_IMAGE)/.*-u-boot-with-spl.bin|\$(TOPDIR)/files/u-boot-sunxi-with-spl.bin|g' "$IMAGE_MAKEFILE"
    
    echo "  -> Success: Image Makefile patched."
else
    echo "❌ Error: Image Makefile not found!"
    exit 1
fi

# ==============================================================================
# 5. 注入机型定义 (Inject Device Definition)
# ==============================================================================
echo "[4/4] Injecting device definition..."

if [ ! -f "$TARGET_MK" ]; then
    echo "❌ Error: Target Makefile $TARGET_MK not found!"
    exit 1
fi

cat <<EOF >> "$TARGET_MK"

# --- Added by DIY Script for Tronlong TLT113-MiniEVM ---
define Device/tronlong_tlt113-minievm
  \$(Device/sunxi-img)
  DEVICE_VENDOR := Tronlong
  DEVICE_MODEL := TLT113-MiniEVM (Official U-Boot)
  DEVICE_DTS := $DTS_NAME
  
  # 使用 H3 的 U-Boot 占位，骗过依赖检查
  # 实际打包时会被上面的 sed 替换为 files/u-boot-sunxi-with-spl.bin
  DEVICE_UBOOT := $PLACEHOLDER_UBOOT
  
  # 参数仅作展示，实际参数由预编译的 U-Boot 决定
  UBOOT_CONFIG_OVERRIDES := CONFIG_DRAM_CLK=792 CONFIG_DRAM_ZQ=8092667
  
  SUPPORTED_DEVICES := tronlong,tlt113-minievm
endef
TARGET_DEVICES += tronlong_tlt113-minievm
# -------------------------------------------------------
EOF

echo "  -> Success: Device definition appended."
echo "-------------------------------------------------------"
echo "DIY Part 2 Finished Successfully."
