#!/bin/bash
# Description: OpenWrt DIY script part 2 (Final Fix: Escaped Variables)

DTS_NAME="sun8i-t113-tronlong-minievm"
TARGET_MK="target/linux/sunxi/image/cortexa7.mk"
KERNEL_DTS_DIR="target/linux/sunxi/files/arch/arm/boot/dts"
UBOOT_MAKEFILE="package/boot/uboot-sunxi/Makefile"

echo "-------------------------------------------------------"
echo "Starting DIY Part 2: Customizing for Tronlong TLT113-MiniEVM"
echo "-------------------------------------------------------"

# 1. 部署 DTS
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

# 2. [核心修复] 修改 U-Boot Makefile
# 修复说明：使用单引号防止 shell 变量扩展，确保写入 Makefile 的是 $(CP) 而不是空值或乱码
echo "  -> Patching U-Boot Makefile to generate device-specific boot script..."

if [ -f "$UBOOT_MAKEFILE" ]; then
    # 策略：使用 sed 在 endef 前插入命令
    # 注意：我们使用单引号 '...' 包裹 sed 命令，这样里面的 $(...) 不会被 Shell 解析
    # Makefile 需要 Tab 缩进，这里用 \t 表示
    
    sed -i "/define Build\/InstallDev/,/endef/ s|endef|\t# Patch for Tronlong\n\t\$(CP) \$(STAGING_DIR_IMAGE)/\$(BUILD_DEVICES)-boot.scr \$(STAGING_DIR_IMAGE)/tronlong_tlt113-minievm-boot.scr\nendef|" "$UBOOT_MAKEFILE"
    
    # 验证 Patch 是否写入 (检查是否包含 CP 命令)
    if grep -q "tronlong_tlt113-minievm-boot.scr" "$UBOOT_MAKEFILE"; then
        echo "  -> Success: U-Boot Makefile patched successfully."
        # 输出最后几行确认内容正确
        tail -n 10 "$UBOOT_MAKEFILE"
    else
        echo "  -> Error: Failed to patch U-Boot Makefile!"
        exit 1
    fi
else
    echo "  -> Error: U-Boot Makefile not found at $UBOOT_MAKEFILE"
    exit 1
fi

# 3. 注入机型定义
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
  UBOOT_CONFIG_OVERRIDES := CONFIG_DRAM_CLK=792 CONFIG_DRAM_ZQ=8092667 CONFIG_DEFAULT_DEVICE_TREE="$DTS_NAME"
  SUPPORTED_DEVICES := tronlong,tlt113-minievm
endef
TARGET_DEVICES += tronlong_tlt113-minievm
# -------------------------------------------------------
EOF

echo "  -> Success: Device definition appended."
echo "-------------------------------------------------------"
echo "DIY Part 2 Finished Successfully."
