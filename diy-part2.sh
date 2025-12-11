#!/bin/bash
# Description: OpenWrt DIY script part 2 (Manual Boot Script Injection)

DTS_NAME="sun8i-t113-tronlong-minievm"
TARGET_MK="target/linux/sunxi/image/cortexa7.mk"
KERNEL_DTS_DIR="target/linux/sunxi/files/arch/arm/boot/dts"
IMAGE_MAKEFILE="target/linux/sunxi/image/Makefile"

echo "-------------------------------------------------------"
echo "Starting DIY Part 2: Manual Boot Script Strategy"
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
else
    echo "  -> Error: No DTS files found!"
    exit 1
fi

# ==============================================================================
# 2. [核心绝招] 手动生成 boot.scr (Bypass U-Boot build artifacts)
# ==============================================================================
echo "  -> Generating custom boot.scr..."

# 创建 boot.cmd (T113 通用启动脚本)
# 注意：这里指定加载 sun8i-t113-tronlong-minievm.dtb
cat <<EOF > boot.cmd
# OpenWrt Boot Script for Tronlong T113
part uuid mmc 0:2 uuid
setenv bootargs console=ttyS0,115200 root=PARTUUID=\${uuid} rootwait panic=10
load mmc 0:1 \${kernel_addr_r} zImage
load mmc 0:1 \${fdt_addr_r} $DTS_NAME.dtb
bootz \${kernel_addr_r} - \${fdt_addr_r}
EOF

# 编译生成 boot.scr
# 这里的路径 files/boot.scr 是相对于 OpenWrt 源码根目录的
mkimage -C none -A arm -T script -d boot.cmd files/boot.scr

if [ -f "files/boot.scr" ]; then
    echo "  -> Success: files/boot.scr generated."
else
    echo "  -> Error: Failed to generate boot.scr! Check if u-boot-tools is installed."
    exit 1
fi

# ==============================================================================
# 3. 修改 Image Makefile (强制使用我们的 boot.scr)
# ==============================================================================
echo "  -> Patching Image Makefile to use local boot.scr..."

if [ -f "$IMAGE_MAKEFILE" ]; then
    # 原始命令类似：mcopy -i $@.boot $(STAGING_DIR_IMAGE)/$(DEVICE_NAME)-boot.scr ::boot.scr
    # 我们要把它替换为：mcopy -i $@.boot $(TOPDIR)/files/boot.scr ::boot.scr
    
    # 这里的 TOPDIR 是 OpenWrt 构建系统的一个变量，指向源码根目录
    sed -i 's|\$(STAGING_DIR_IMAGE)/\$(DEVICE_NAME)-boot.scr|\$(TOPDIR)/files/boot.scr|g' "$IMAGE_MAKEFILE"
    
    echo "  -> Success: Makefile patched to use local file."
else
    echo "  -> Error: Image Makefile not found!"
    exit 1
fi

# ==============================================================================
# 4. 注入机型定义
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
  # 借用一个存在的 U-Boot 配置以通过编译依赖检查
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
