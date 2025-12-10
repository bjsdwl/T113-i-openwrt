#!/bin/bash
# Description: OpenWrt DIY script part 2 (Fix U-Boot InstallDev Patch)

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
# 2. [核心修复] Patch U-Boot Makefile (针对 Build/InstallDev)
# ==============================================================================
echo "  -> Patching U-Boot Makefile to generate device-specific boot script..."

if [ -f "$UBOOT_MAKEFILE" ]; then
    # 逻辑：
    # 1. 搜索 'define Build/InstallDev' 区块
    # 2. 在该区块的 'endef' 之前，插入复制命令
    # 3. 复制命令：把生成的 $(BUILD_DEVICES)-boot.scr 复制一份为 tronlong_tlt113-minievm-boot.scr
    
    # 这里的 sed 命令会在 'define Build/InstallDev' 之后的第一个 'endef' 前插入代码
    sed -i '/define Build\/InstallDev/,/endef/ s@endef@	# Patch for Tronlong\n	cp $(STAGING_DIR_IMAGE)/$(BUILD_DEVICES)-boot.scr $(STAGING_DIR_IMAGE)/tronlong_tlt113-minievm-boot.scr || true\nendef@' "$UBOOT_MAKEFILE"
    
    # 验证 Patch 是否写入
    if grep -q "tronlong_tlt113-minievm-boot.scr" "$UBOOT_MAKEFILE"; then
        echo "  -> Success: U-Boot Makefile patched successfully."
    else
        echo "  -> Error: Failed to patch U-Boot Makefile!"
        # 打印 Makefile 内容以便调试 (只打最后30行)
        tail -n 30 "$UBOOT_MAKEFILE"
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
  # 内存参数
  UBOOT_CONFIG_OVERRIDES := CONFIG_DRAM_CLK=792 CONFIG_DRAM_ZQ=8092667 CONFIG_DEFAULT_DEVICE_TREE="$DTS_NAME"
  SUPPORTED_DEVICES := tronlong,tlt113-minievm
endef
TARGET_DEVICES += tronlong_tlt113-minievm
# -------------------------------------------------------
EOF

echo "  -> Success: Device definition appended."
echo "-------------------------------------------------------"
echo "DIY Part 2 Finished Successfully."
