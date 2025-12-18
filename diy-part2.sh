#!/bin/bash
# Description: OpenWrt DIY script part 2 (Transplant Preparation)

# 变量定义
DTS_FILENAME="sun8i-t113-tronlong-minievm.dts"
DTS_NAME="sun8i-t113-tronlong-minievm"
TARGET_MK="target/linux/sunxi/image/cortexa7.mk"
KERNEL_DTS_DIR="target/linux/sunxi/files/arch/arm/boot/dts"

echo "-------------------------------------------------------"
echo "Starting DIY Part 2: Preparing for Tina SDK Transplant"
echo "-------------------------------------------------------"

# ==============================================================================
# 1. 部署单体 DTS 文件
# ==============================================================================
# 确保 files/ 目录下有我们之前做好的那个“全手动定义宏”的 DTS
mkdir -p "$KERNEL_DTS_DIR"
mkdir -p target/linux/sunxi/dts

if [ -f "files/$DTS_FILENAME" ]; then
    echo "  -> Deploying DTS to Kernel Overlay..."
    cp "files/$DTS_FILENAME" "$KERNEL_DTS_DIR/"
    cp "files/$DTS_FILENAME" target/linux/sunxi/dts/
else
    echo "❌ Error: files/$DTS_FILENAME not found!"
    exit 1
fi

# ==============================================================================
# 2. 生成 boot.scr (可选，但在 Tina 环境中可能有用)
# ==============================================================================
echo "  -> Generating boot.scr for safety..."
cat <<EOF > boot.cmd
# OpenWrt Boot Script
part uuid mmc 0:2 uuid
setenv bootargs console=ttyS0,115200 root=PARTUUID=\${uuid} rootwait panic=10 earlycon=uart8250,mmio32,0x02500000
load mmc 0:1 \${kernel_addr_r} zImage
load mmc 0:1 \${fdt_addr_r} $DTS_NAME.dtb
bootz \${kernel_addr_r} - \${fdt_addr_r}
EOF
mkimage -C none -A arm -T script -d boot.cmd files/boot.scr

# ==============================================================================
# 3. 注册机型 (为了触发内核和DTB的编译)
# ==============================================================================
if [ ! -f "$TARGET_MK" ]; then
    echo "❌ Error: Target Makefile not found!"
    exit 1
fi

cat <<EOF >> "$TARGET_MK"

# --- Added by DIY Script for Tronlong TLT113-MiniEVM ---
define Device/tronlong_tlt113-minievm
  \$(Device/sunxi-img)
  DEVICE_VENDOR := Tronlong
  DEVICE_MODEL := TLT113-MiniEVM (Transplant)
  DEVICE_DTS := $DTS_NAME
  
  # 使用 nanopi_neo 作为 U-Boot 占位符，保证编译流程不中断
  # 我们不需要 OpenWrt 生成的 U-Boot，只取内核和文件系统
  DEVICE_UBOOT := nanopi_neo
  
  SUPPORTED_DEVICES := tronlong,tlt113-minievm
endef
TARGET_DEVICES += tronlong_tlt113-minievm
EOF

echo "DIY Part 2 Finished Successfully."
