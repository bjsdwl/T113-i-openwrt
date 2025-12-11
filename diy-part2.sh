#!/bin/bash
# Description: OpenWrt DIY script part 2 (Double Safety Fix)

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
# 2. [保险措施] 修改 U-Boot Makefile (强制生成副本)
# ==============================================================================
# 既然 ImageBuilder 想要 tronlong_tlt113-minievm-boot.scr，我们就让 U-Boot 顺便生成一个
echo "  -> Patching U-Boot Makefile to ensure boot script exists..."

if [ -f "$UBOOT_MAKEFILE" ]; then
    # 使用 perl 替代 sed 进行多行匹配替换，更稳定，避免分隔符问题
    # 逻辑：找到 'endef' (属于 Build/InstallDev 的结尾)，在它前面插入复制命令
    # 注意：Makefile 必须使用 Tab 缩进
    
    perl -i -pe 's|^endef|\t# Patch: Copy boot.scr for Tronlong\n\t$(CP) $(STAGING_DIR_IMAGE)/$(BUILD_DEVICES)-boot.scr $(STAGING_DIR_IMAGE)/tronlong_tlt113-minievm-boot.scr\nendef| if /define Build\/InstallDev/ .. /endef/' "$UBOOT_MAKEFILE"
    
    # 验证 Patch
    if grep -q "tronlong_tlt113-minievm-boot.scr" "$UBOOT_MAKEFILE"; then
        echo "  -> Success: U-Boot Makefile patched."
    else
        echo "  -> Warning: Patch verification failed, but we will try the variable method next."
    fi
else
    echo "  -> Error: U-Boot Makefile not found at $UBOOT_MAKEFILE"
    # 不退出，继续尝试下面的方法
fi

# ==============================================================================
# 3. 注入机型定义 (指定正确的 BOOT_SCRIPT)
# ==============================================================================
if [ ! -f "$TARGET_MK" ]; then
    echo "  -> Error: Target Makefile $TARGET_MK not found!"
    exit 1
fi

cat <<EOF >> "$TARGET_MK"

# --- Added by DIY Script for Tronlong TLT113-MiniEVM ---
define Device/tronlong_tlt113-minievm
  # 1. 继承基础配置
  \$(Device/sunxi-img)
  
  # 2. 基础信息
  DEVICE_VENDOR := Tronlong
  DEVICE_MODEL := TLT113-MiniEVM (NAND/HDMI)
  DEVICE_DTS := $DTS_NAME
  
  # 3. U-Boot 配置
  DEVICE_UBOOT := sun8i-r528-qa-board
  
  # 4. [核心] 指向真实存在的启动脚本文件
  # 因为 DEVICE_UBOOT 是 sun8i-r528-qa-board，所以生成的脚本必然叫这个名字
  BOOT_SCRIPT := sun8i-r528-qa-board-boot
  
  # 5. 内存参数
  UBOOT_CONFIG_OVERRIDES := CONFIG_DRAM_CLK=792 CONFIG_DRAM_ZQ=8092667 CONFIG_DEFAULT_DEVICE_TREE="$DTS_NAME"
  
  SUPPORTED_DEVICES := tronlong,tlt113-minievm
endef
TARGET_DEVICES += tronlong_tlt113-minievm
# -------------------------------------------------------
EOF

echo "  -> Success: Device definition appended."
echo "-------------------------------------------------------"
echo "DIY Part 2 Finished Successfully."
