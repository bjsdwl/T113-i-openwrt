#!/bin/bash
# Description: OpenWrt DIY script part 2 (Evidence-based Fix)

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
    echo "  -> Error: No .dts or .dtsi files found in files/ directory!"
    exit 1
fi

# ==============================================================================
# 2. [核心修复] 精准修改 U-Boot Makefile
# ==============================================================================
echo "  -> Patching U-Boot Makefile to generate device-specific boot script..."

if [ -f "$UBOOT_MAKEFILE" ]; then
    # 既然我们已经拿到文件内容，知道 'define Build/InstallDev' 是存在的。
    # 我们使用 sed 在 'endef' 之前插入一行 cp 命令。
    # 命令逻辑：cp $(STAGING_DIR_IMAGE)/$(BUILD_DEVICES)-boot.scr $(STAGING_DIR_IMAGE)/tronlong_tlt113-minievm-boot.scr
    
    # 匹配 Build/InstallDev 区块内的 endef，替换为：复制命令 + 换行 + endef
    # 使用 '#' 作为分隔符，防止路径斜杠冲突
    sed -i '/define Build\/InstallDev/,/endef/ s#endef#	$(CP) $(STAGING_DIR_IMAGE)/$(BUILD_DEVICES)-boot.scr $(STAGING_DIR_IMAGE)/tronlong_tlt113-minievm-boot.scr\nendef#' "$UBOOT_MAKEFILE"
    
    # 验证 Patch 是否写入
    if grep -q "tronlong_tlt113-minievm-boot.scr" "$UBOOT_MAKEFILE"; then
        echo "  -> Success: U-Boot Makefile patched successfully."
        # 输出一下 Patch 后的最后几行确认
        echo "--- Patched Content (Partial) ---"
        grep -A 10 "define Build/InstallDev" "$UBOOT_MAKEFILE"
        echo "---------------------------------"
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
  # 既然我们已经物理复制了文件，就不需要再覆盖 BOOT_SCRIPT 变量了，让它找同名文件即可
  UBOOT_CONFIG_OVERRIDES := CONFIG_DRAM_CLK=792 CONFIG_DRAM_ZQ=8092667 CONFIG_DEFAULT_DEVICE_TREE="$DTS_NAME"
  SUPPORTED_DEVICES := tronlong,tlt113-minievm
endef
TARGET_DEVICES += tronlong_tlt113-minievm
# -------------------------------------------------------
EOF

echo "  -> Success: Device definition appended."
echo "-------------------------------------------------------"
echo "DIY Part 2 Finished Successfully."
