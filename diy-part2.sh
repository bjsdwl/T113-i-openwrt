#!/bin/bash
# Description: OpenWrt DIY script part 2 (Bulletproof Version)

DTS_NAME="sun8i-t113-tronlong-minievm"
TARGET_MK="target/linux/sunxi/image/cortexa7.mk"
KERNEL_DTS_DIR="target/linux/sunxi/files/arch/arm/boot/dts"

echo "-------------------------------------------------------"
echo "Starting DIY Part 2: Customizing for Tronlong TLT113-MiniEVM"
echo "-------------------------------------------------------"

# 1. 部署 DTS 文件 (Deploy DTS)
mkdir -p "$KERNEL_DTS_DIR"
mkdir -p target/linux/sunxi/dts

if ls files/*.dts* 1> /dev/null 2>&1; then
    echo "  -> Found DTS files. Copying..."
    cp files/*.dts* "$KERNEL_DTS_DIR/"
    cp files/*.dts* target/linux/sunxi/dts/
    echo "  -> Success: Device Tree files deployed."
else
    echo "  -> Error: No .dts or .dtsi files found in files/ directory!"
    exit 1
fi

# 2. 注入机型定义 (Inject Device Definition)
if [ ! -f "$TARGET_MK" ]; then
    echo "  -> Error: Target Makefile $TARGET_MK not found!"
    exit 1
fi

# 使用极简且严格的 Makefile 语法注入
# 注意：这里不再包含任何注释，防止 parser 解析错误
cat <<EOF >> "$TARGET_MK"

define Device/tronlong_tlt113-minievm
  \$(Device/sunxi-img)
  DEVICE_VENDOR := Tronlong
  DEVICE_MODEL := TLT113-MiniEVM (NAND/HDMI)
  DEVICE_DTS := $DTS_NAME
  DEVICE_UBOOT := sun8i-r528-qa-board
  BOOT_SCRIPT := sunxi-boot
  UBOOT_CONFIG_OVERRIDES := CONFIG_DRAM_CLK=792 CONFIG_DRAM_ZQ=8092667 CONFIG_DEFAULT_DEVICE_TREE="$DTS_NAME"
  SUPPORTED_DEVICES := tronlong,tlt113-minievm
endef
TARGET_DEVICES += tronlong_tlt113-minievm

EOF

echo "  -> Success: Device definition appended."

# 3. [绝招] 创建文件别名 (Create File Alias)
# 如果 Makefile 里的 BOOT_SCRIPT 变量覆盖失败，
# 这一步会预先在 staging_dir 里创建一个软链接，骗过打包工具。
# 注意：这需要在编译前执行，但 staging_dir 此时可能还没准备好。
# 所以我们把这个动作注入到 OpenWrt 的核心 Makefile 里去（利用 Build/InstallDev 钩子太复杂）。
# 我们采用一个更简单的策略：修改 u-boot-sunxi 的安装脚本。

echo "  -> Patching u-boot-sunxi Makefile to support alias..."
# 找到 u-boot-sunxi 的 Makefile
UBOOT_MAKEFILE="package/boot/uboot-sunxi/Makefile"

if [ -f "$UBOOT_MAKEFILE" ]; then
    # 在安装 sunxi-boot.scr 的地方，顺手复制一份名为 tronlong_tlt113-minievm-boot.scr 的副本
    # 这样无论 BOOT_SCRIPT 变量是什么，都能找到文件。
    sed -i '/cp $(PKG_BUILD_DIR)\/boot.scr $(1)\/boot.scr/a \\tcb $(1)/sunxi-boot.scr $(1)/tronlong_tlt113-minievm-boot.scr || true' "$UBOOT_MAKEFILE"
    # 注意：上面的 sed 可能因为不同版本路径不同而失效，我们用追加的方式更稳妥
    
    # 直接在 Package/u-boot-sunxi/install 部分的末尾追加一行复制命令
    # 匹配 "endef" 前的最后一行，插入复制命令
    sed -i '/define Package\/u-boot-sunxi\/install/,/endef/ s|endef|	[ -f $(1)/sunxi-boot.scr ] && cp $(1)/sunxi-boot.scr $(1)/tronlong_tlt113-minievm-boot.scr || true\nendef|' "$UBOOT_MAKEFILE"
    
    echo "  -> Success: U-Boot Makefile patched."
else
    echo "  -> Warning: U-Boot Makefile not found, skipping patch."
fi

echo "-------------------------------------------------------"
echo "DIY Part 2 Finished Successfully."
