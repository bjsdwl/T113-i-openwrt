#!/bin/bash
# Description: OpenWrt DIY script part 2 (After Update feeds)

# 定义文件名变量，方便后续维护
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

# 确保目标目录存在 (防止 cp 报错)
if [ ! -d "target/linux/sunxi/dts" ]; then
    echo "  -> Creating directory: target/linux/sunxi/dts"
    mkdir -p target/linux/sunxi/dts
fi

# 复制文件
if [ -f "$GITHUB_WORKSPACE/files/$DTS_FILENAME" ]; then
    cp "$GITHUB_WORKSPACE/files/$DTS_FILENAME" target/linux/sunxi/dts/
    echo "  -> Success: DTS file copied to target/linux/sunxi/dts/"
else
    echo "  -> Error: Source DTS file not found in $GITHUB_WORKSPACE/files/!"
    echo "  -> Please verify your repository structure."
    exit 1
fi

# ==============================================================================
# 2. 注入机型定义 (Inject Device Definition into Makefile)
# ==============================================================================
echo "[2/2] Injecting device definition into $TARGET_MK..."

# 检查目标 Makefile 是否存在
if [ ! -f "$TARGET_MK" ]; then
    echo "  -> Error: Target Makefile $TARGET_MK not found!"
    exit 1
fi

# 追加机型配置
# 关键点说明：
# - DEVICE_UBOOT: 借用 sun8i-r528-qa-board 作为编译基础
# - UBOOT_CONFIG_OVERRIDES: 覆盖 DRAM 参数 (CLK=792, ZQ=8092667)
# - 注意：这里没有设置 cma=0，因为启用了 HDMI 需要预留显存 (256MB 内存足够)

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
