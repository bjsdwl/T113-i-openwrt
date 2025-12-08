#!/bin/bash
# Description: OpenWrt DIY script part 2 (After Update feeds)

# ==============================================================================
# 1. 复制 DTS 文件 (Copoy DTS file)
# ------------------------------------------------------------------------------
# 假设你在仓库根目录下创建了 'files' 文件夹，并把 sun8i-t113-tronlong-evm.dts 放在里面
# $GITHUB_WORKSPACE 是 GitHub Actions 的环境变量，代表当前仓库根目录
echo "Copying custom DTS file..."
cp $GITHUB_WORKSPACE/files/sun8i-t113-tronlong-evm.dts target/linux/sunxi/dts/

# ==============================================================================
# 2. 注入机型定义 (Inject Device Definition)
# ------------------------------------------------------------------------------
# 我们将把 Tronlong TLT113-EVM 的定义追加到 target/linux/sunxi/image/cortexa7.mk 末尾
# 
# 关键参数说明:
# DEVICE_DTS: 指定我们刚才复制进去的 DTS 文件名
# DEVICE_UBOOT: 借用现有的 sun8i-r528-qa-board 作为 U-Boot 编译基板
# UBOOT_CONFIG_OVERRIDES: 这是最重要的一行！它会覆盖 U-Boot 的默认配置：
#    - CONFIG_DRAM_CLK=792    : 这里的 792 也就是 sys_config.fex 里的 dram_clk
#    - CONFIG_DRAM_ZQ=8092667 : 这里的 8092667 是 0x7b7bfb 的十进制值
# ==============================================================================

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
