#!/bin/bash
# Description: OpenWrt DIY script part 2 (Transplant Components Generator)

# --- 变量定义 ---
DTS_FILENAME="sun8i-t113-tronlong-minievm.dts"
DTS_NAME="sun8i-t113-tronlong-minievm"
# OpenWrt sunxi target 的设备定义文件
TARGET_MK="target/linux/sunxi/image/cortexa7.mk"
# 内核源码覆盖目录 (确保编译时能找到 DTS)
KERNEL_DTS_DIR="target/linux/sunxi/files/arch/arm/boot/dts"

echo "-------------------------------------------------------"
echo "Starting DIY Part 2: Preparing Transplant Components"
echo "-------------------------------------------------------"

# ==============================================================================
# 1. 部署单体 DTS 文件
# ==============================================================================
# 确保 files/ 目录下有 sun8i-t113-tronlong-minievm.dts
if [ ! -f "files/$DTS_FILENAME" ]; then
    echo "❌ Error: files/$DTS_FILENAME not found!"
    exit 1
fi

echo "  -> Deploying DTS to Kernel Overlay..."
mkdir -p "$KERNEL_DTS_DIR"
mkdir -p target/linux/sunxi/dts

# 复制到内核源码覆盖目录 (最关键)
cp "files/$DTS_FILENAME" "$KERNEL_DTS_DIR/"
# 复制到标准目录作为备份
cp "files/$DTS_FILENAME" target/linux/sunxi/dts/

# ==============================================================================
# 2. 生成 boot.scr (引导脚本)
# ==============================================================================
echo "  -> Generating boot.scr..."
cat <<EOF > boot.cmd
# OpenWrt Boot Script for Tronlong T113
# 1. 识别分区 UUID
part uuid mmc 0:2 uuid
# 2. 设置启动参数 (console=ttyS0, root挂载点, 调试信息)
setenv bootargs console=ttyS0,115200 root=PARTUUID=\${uuid} rootwait panic=10 earlycon=uart8250,mmio32,0x02500000
# 3. 加载内核 (zImage)
load mmc 0:1 \${kernel_addr_r} zImage
# 4. 加载设备树 (dtb)
load mmc 0:1 \${fdt_addr_r} $DTS_NAME.dtb
# 5. 启动
bootz \${kernel_addr_r} - \${fdt_addr_r}
EOF

# 编译为二进制 boot.scr
mkimage -C none -A arm -T script -d boot.cmd files/boot.scr

if [ -f "files/boot.scr" ]; then
    echo "  -> Success: boot.scr generated."
else
    echo "❌ Error: Failed to generate boot.scr (Check u-boot-tools)."
    exit 1
fi

# ==============================================================================
# 3. 注册机型 (Trigger Kernel Build)
# ==============================================================================
if [ ! -f "$TARGET_MK" ]; then
    echo "❌ Error: Target Makefile not found!"
    exit 1
fi

# 我们使用 nanopi_neo (H3) 作为 U-Boot 占位符
# 这样 OpenWrt 会正常编译内核和 rootfs，而不会因为缺少 T113 U-Boot 源码而报错
# 我们最终只需要内核和文件系统，U-Boot 使用官方提取的即可
cat <<EOF >> "$TARGET_MK"

# --- Added by DIY Script for Tronlong TLT113-MiniEVM ---
define Device/tronlong_tlt113-minievm
  \$(Device/sunxi-img)
  DEVICE_VENDOR := Tronlong
  DEVICE_MODEL := TLT113-MiniEVM (Transplant)
  DEVICE_DTS := $DTS_NAME
  DEVICE_UBOOT := nanopi_neo
  SUPPORTED_DEVICES := tronlong,tlt113-minievm
endef
TARGET_DEVICES += tronlong_tlt113-minievm
EOF

echo "DIY Part 2 Finished Successfully."
