#!/bin/bash
# Description: OpenWrt DIY script part 2 (Fix DTS Path Issue)

DTS_FILENAME="sun8i-t113-tronlong-minievm.dts"
DTS_NAME="sun8i-t113-tronlong-minievm"
TARGET_MK="target/linux/sunxi/image/cortexa7.mk"

echo "-------------------------------------------------------"
echo "Starting DIY Part 2: Customizing for Tronlong TLT113-MiniEVM"
echo "-------------------------------------------------------"

# ==============================================================================
# 1. 强制注入 DTS 文件 (Force Inject via Kernel Files Overlay)
# ==============================================================================
# 这里的路径 target/linux/sunxi/files/arch/arm/boot/dts/ 是 OpenWrt 的标准覆盖路径
# 放在这里的文件会被强制复制到内核源码的 arch/arm/boot/dts/ 目录下
KERNEL_DTS_DIR="target/linux/sunxi/files/arch/arm/boot/dts"

echo "[1/2] Creating Kernel Files Overlay directory..."
mkdir -p "$KERNEL_DTS_DIR"

echo "Deploying Device Tree Source ($DTS_FILENAME)..."
# 注意：files/ 已经在工作流中被移动到了当前目录下
if [ -f "files/$DTS_FILENAME" ]; then
    # 策略 A: 复制到 Overlay 目录 (强制覆盖内核源码)
    cp files/*.dts* target/linux/sunxi/dts/
    
    # 策略 B: 同时复制到传统的 dts 目录 (以此作为备份，防止某些旧脚本依赖)
    mkdir -p target/linux/sunxi/dts
    cp "files/$DTS_FILENAME" target/linux/sunxi/dts/
    
    echo "  -> Success: DTS file deployed to:"
    echo "     1. $KERNEL_DTS_DIR/"
    echo "     2. target/linux/sunxi/dts/"
else
    echo "  -> Error: Source DTS file not found in files/$DTS_FILENAME !"
    echo "  -> Directory listing:"
    ls -R files/
    exit 1
fi

# ==============================================================================
# 2. 注入机型定义 (Inject Device Definition)
# ==============================================================================
echo "[2/2] Injecting device definition into $TARGET_MK..."

if [ ! -f "$TARGET_MK" ]; then
    echo "  -> Error: Target Makefile $TARGET_MK not found!"
    exit 1
fi

cat <<EOF >> "$TARGET_MK"

# --- Added by DIY Script for Tronlong TLT113-MiniEVM ---
define Device/tronlong_tlt113-minievm
  DEVICE_VENDOR := Tronlong
  DEVICE_MODEL := TLT113-MiniEVM (NAND/HDMI)
  DEVICE_DTS := $DTS_NAME
  DEVICE_UBOOT := sun8i-r528-qa-board
  UBOOT_CONFIG_OVERRIDES := CONFIG_DRAM_CLK=792 CONFIG_DRAM_ZQ=8092667 CONFIG_DEFAULT_DEVICE_TREE="$DTS_NAME"
  SUPPORTED_DEVICES := tronlong,tlt113-minievm
  \$(Device/sunxi-img)
endef
TARGET_DEVICES += tronlong_tlt113-minievm
# -------------------------------------------------------
EOF

echo "  -> Success: Device definition appended."
echo "-------------------------------------------------------"
echo "DIY Part 2 Finished Successfully."
