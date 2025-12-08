#!/bin/bash
# Description: OpenWrt DIY script part 2

# 1. 复制 DTS (注意文件名变了)
echo "Creating DTS directory..."
mkdir -p target/linux/sunxi/dts
echo "Copying custom DTS file..."
# 这里的 source 文件名要和你仓库里的一致
cp $GITHUB_WORKSPACE/files/sun8i-t113-tronlong-minievm.dts target/linux/sunxi/dts/

# 2. 注入机型定义
echo "Appending device definition..."
cat <<EOF >> target/linux/sunxi/image/cortexa7.mk

define Device/tronlong_tlt113-minievm
  DEVICE_VENDOR := Tronlong
  DEVICE_MODEL := TLT113-MiniEVM (NAND)
  # 引用新的 DTS 文件名
  DEVICE_DTS := sun8i-t113-tronlong-minievm
  DEVICE_UBOOT := sun8i-r528-qa-board
  # 内存参数保持不变 (792MHz / 0x7b7bfb)
  UBOOT_CONFIG_OVERRIDES := CONFIG_DRAM_CLK=792 CONFIG_DRAM_ZQ=8092667 CONFIG_DEFAULT_DEVICE_TREE="sun8i-t113-tronlong-minievm"
  SUPPORTED_DEVICES := tronlong,tlt113-minievm
  \$(Device/sunxi-img)
endef
TARGET_DEVICES += tronlong_tlt113-minievm
EOF
