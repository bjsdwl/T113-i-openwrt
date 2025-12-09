#!/bin/bash
# Description: OpenWrt DIY script part 2 (Final Version for Tronlong T113)

# 变量定义
DTS_NAME="sun8i-t113-tronlong-minievm"
TARGET_MK="target/linux/sunxi/image/cortexa7.mk"
# OpenWrt 内核源码覆盖路径 (Kernel Overlay)
KERNEL_DTS_DIR="target/linux/sunxi/files/arch/arm/boot/dts"

echo "-------------------------------------------------------"
echo "Starting DIY Part 2: Customizing for Tronlong TLT113-MiniEVM"
echo "-------------------------------------------------------"

# ==============================================================================
# 1. 部署所有 DTS/DTSI 文件 (Deploy All Device Tree Files)
# ==============================================================================
echo "[1/2] Deploying Device Tree Files..."

# 创建必要的目录
mkdir -p "$KERNEL_DTS_DIR"
mkdir -p target/linux/sunxi/dts

# 检查 files 目录下是否有 dts 或 dtsi 文件
# 注意：files/ 目录已经在工作流中被移动到了当前目录下
if ls files/*.dts* 1> /dev/null 2>&1; then
    echo "  -> Found DTS files. Copying..."
    
    # 策略 A: 复制到 Kernel Overlay (强制覆盖内核源码，解决找不到依赖的问题)
    cp files/*.dts* "$KERNEL_DTS_DIR/"
    echo "     Copied to $KERNEL_DTS_DIR/"
    
    # 策略 B: 同时复制到 OpenWrt 标准 DTS 目录 (作为备份)
    cp files/*.dts* target/linux/sunxi/dts/
    echo "     Copied to target/linux/sunxi/dts/"
    
    echo "  -> Success: Device Tree files deployed."
else
    echo "  -> Error: No .dts or .dtsi files found in files/ directory!"
    echo "  -> Listing files/ content:"
    ls -R files/
    exit 1
fi

# ==============================================================================
# 2. 注入机型定义 (Inject Device Definition)
# ==============================================================================
echo "[2/2] Injecting device definition into $TARGET_MK..."

# 检查目标 Makefile 是否存在
if [ ! -f "$TARGET_MK" ]; then
    echo "  -> Error: Target Makefile $TARGET_MK not found!"
    exit 1
fi

# 追加机型配置到 Makefile 末尾
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
