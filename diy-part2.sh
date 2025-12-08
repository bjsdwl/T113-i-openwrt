#!/bin/bash
# Description: OpenWrt DIY script part 2 (After Update feeds)

# 定义文件名变量
DTS_FILENAME="sun8i-t113-tronlong-minievm.dts"
DTS_NAME="sun8i-t113-tronlong-minievm"
TARGET_MK="target/linux/sunxi/image/cortexa7.mk"

echo "-------------------------------------------------------"
echo "Starting DIY Part 2: Customizing for Tronlong TLT113-MiniEVM"
echo "-------------------------------------------------------"

# ==============================================================================
# 1. 部署 DTS 文件 (Deploy Custom DTS)
# ==============================================================================
echo "[1/2] Deploying Device Tree Source ($DTS_FILENAME)..."

# 确保目标目录存在
if [ ! -d "target/linux/sunxi/dts" ]; then
    echo "  -> Creating directory: target/linux/sunxi/dts"
    mkdir -p target/linux/sunxi/dts
fi

# 修正点：这里的路径改为相对路径 files/
# 因为工作流已经把 files 文件夹移动到了当前目录 (openwrt/) 下
if [ -f "files/$DTS_FILENAME" ]; then
    cp "files/$DTS_FILENAME" target/linux/sunxi/dts/
    echo "  -> Success: DTS file copied to target/linux/sunxi/dts/"
else
    echo "  -> Error: Source DTS file not found in files/$DTS_FILENAME !"
    echo "  -> Current directory: $(pwd)"
    echo "  -> List files dir: $(ls -F files/ 2>/dev/null)"
    exit 1
fi

# ==============================================================================
# 2. 注入机型定义 (Inject Device Definition into Makefile)
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
