#!/bin/bash
# Description: OpenWrt DIY script part 2 (File-level Fix)

DTS_NAME="sun8i-t113-tronlong-minievm"
TARGET_MK="target/linux/sunxi/image/cortexa7.mk"
KERNEL_DTS_DIR="target/linux/sunxi/files/arch/arm/boot/dts"
UBOOT_MAKEFILE="package/boot/uboot-sunxi/Makefile"

echo "-------------------------------------------------------"
echo "Starting DIY Part 2: Customizing for Tronlong TLT113-MiniEVM"
echo "-------------------------------------------------------"

# ==============================================================================
# 1. 部署 DTS 文件
# ==============================================================================
mkdir -p "$KERNEL_DTS_DIR"
mkdir -p target/linux/sunxi/dts

if ls files/*.dts* 1> /dev/null 2>&1; then
    echo "  -> Found DTS files. Copying..."
    cp files/*.dts* "$KERNEL_DTS_DIR/"
    cp files/*.dts* target/linux/sunxi/dts/
    echo "  -> Success: Device Tree files deployed."
else
    echo "  -> Error: No .dts or .dtsi files found!"
    exit 1
fi

# ==============================================================================
# 2. [核心修复] 修改 U-Boot Makefile 生成替身文件
# ==============================================================================
# 既然 OpenWrt 非要找 tronlong_tlt113-minievm-boot.scr，那我们就给它造一个！
# 我们在 u-boot-sunxi 的 install 环节强行插入一条 cp 命令
echo "  -> Patching U-Boot Makefile to generate device-specific boot script..."

if [ -f "$UBOOT_MAKEFILE" ]; then
    # 逻辑：找到安装 boot.scr 的那一行，在该行后面追加一行复制命令
    # 这里的 sed 语法：/匹配内容/a\追加内容
    # 我们匹配 install 这一段的结束标签 endef，在它之前插入
    
    sed -i '/define Package\/u-boot-sunxi\/install/,/endef/ s|endef|	# Patch: Clone boot.scr for Tronlong\n	cp $(1)/boot.scr $(1)/tronlong_tlt113-minievm-boot.scr || true\nendef|' "$UBOOT_MAKEFILE"
    
    # 检查是否修改成功
    if grep -q "tronlong_tlt113-minievm-boot.scr" "$UBOOT_MAKEFILE"; then
        echo "  -> Success: U-Boot Makefile patched successfully."
    else
        echo "  -> Error: Failed to patch U-Boot Makefile!"
        exit 1
    fi
else
    echo "  -> Error: U-Boot Makefile not found at $UBOOT_MAKEFILE"
    exit 1
fi

# ==============================================================================
# 3. 注入机型定义
# ==============================================================================
if [ ! -f "$TARGET_MK" ]; then
    echo "  -> Error: Target Makefile $TARGET_MK not found!"
    exit 1
fi

cat <<EOF >> "$TARGET_MK"

# --- Added by DIY Script for Tronlong TLT113-MiniEVM ---
define Device/tronlong_tlt113-minievm
  \$(Device/sunxi-img)
  DEVICE_VENDOR := Tronlong
  DEVICE_MODEL := TLT113-MiniEVM (NAND/HDMI)
  DEVICE_DTS := $DTS_NAME
  DEVICE_UBOOT := sun8i-r528-qa-board
  # 既然我们已经造了同名文件，这里不需要再覆盖 BOOT_SCRIPT 变量了，让它用默认的就好
  UBOOT_CONFIG_OVERRIDES := CONFIG_DRAM_CLK=792 CONFIG_DRAM_ZQ=8092667 CONFIG_DEFAULT_DEVICE_TREE="$DTS_NAME"
  SUPPORTED_DEVICES := tronlong,tlt113-minievm
endef
TARGET_DEVICES += tronlong_tlt113-minievm
# -------------------------------------------------------
EOF

echo "  -> Success: Device definition appended."
echo "-------------------------------------------------------"
echo "DIY Part 2 Finished Successfully."
