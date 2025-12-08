#!/bin/bash
# Description: OpenWrt DIY script part 2 (After Update feeds)

# ==============================================================================
# 1. 复制 DTS 文件 (关键修正：先创建目录)
# ------------------------------------------------------------------------------
echo "Creating DTS directory..."
# ⚠️ 修正点：先确保目标目录存在，否则 cp 会失败
mkdir -p target/linux/sunxi/dts

echo "Copying custom DTS file..."
# 确保源文件路径正确，并复制到刚才创建的目录
if [ -f "$GITHUB_WORKSPACE/files/sun8i-t113-tronlong-evm.dts" ]; then
    cp $GITHUB_WORKSPACE/files/sun8i-t113-tronlong-evm.dts target/linux/sunxi/dts/
    echo "DTS file copied successfully."
else
    echo "ERROR: Source DTS file not found in $GITHUB_WORKSPACE/files/!"
    exit 1
fi

# ==============================================================================
# 2. 注入机型定义 (Inject Device Definition)
# ------------------------------------------------------------------------------
echo "Appending device definition to cortexa7.mk..."
cat <<EOF >> target/linux/sunxi/image/cortexa7.mk

define Device/tronlong_tlt113-evm
  DEVICE_VENDOR := Tronlong
  DEVICE_MODEL := TLT113-EVM
  DEVICE_DTS := sun8i-t113-tronlong-evm
  DEVICE_UBOOT := sun8i-r528-qa-board
  UBOOT_CONFIG_OVERRIDES := CONFIG_DRAM_CLK=792 CONFIG_DRAM_ZQ=8092667 CONFIG_DEFAULT_DEVICE_TREE="sun8i-t113-tronlong-evm"
  SUPPORTED_DEVICES := tronlong,tlt113-evm
  \$(Device/sunxi-img)
endef
TARGET_DEVICES += tronlong_tlt113-evm
EOF

echo "DIY Script part 2 finished."
