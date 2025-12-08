#!/bin/bash
# Description: OpenWrt DIY script part 2 (After Update feeds)

# 1. 复制 DTS 文件到源码目录
# 注意：files/ 目录是你仓库里的目录，package/boot/... 是 OpenWrt 源码目录
cp $GITHUB_WORKSPACE/files/sun8i-t113-tronlong-evm.dts target/linux/sunxi/dts/

# 2. 注入机型定义和 U-Boot 内存参数
# 我们将这段定义追加到 cortexa7.mk 文件末尾
# 这里填入我们从 sys_config.fex 提取的参数：CLK=792, ZQ=8092667 (0x7b7bfb)

cat <<EOF >> target/linux/sunxi/image/cortexa7.mk

define Device/tronlong_tlt113-evm
  DEVICE_VENDOR := Tronlong
  DEVICE_MODEL := TLT113-EVM
  DEVICE_DTS := sun8i-t113-tronlong-evm
  # 借用通用配置，但覆盖关键参数
  DEVICE_UBOOT := sun8i-r528-qa-board
  UBOOT_CONFIG_OVERRIDES := CONFIG_DRAM_CLK=792 CONFIG_DRAM_ZQ=8092667 CONFIG_DEFAULT_DEVICE_TREE="sun8i-t113-tronlong-evm"
  SUPPORTED_DEVICES := tronlong,tlt113-evm
  \$(Device/sunxi-img)
endef
TARGET_DEVICES += tronlong_tlt113-evm
EOF
