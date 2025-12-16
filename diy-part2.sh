#!/bin/bash
# Description: OpenWrt DIY script part 2 (Transplant Artifacts Mode)

# 变量定义
DTS_FILENAME="sun8i-t113-tronlong-minievm.dts"
DTS_NAME="sun8i-t113-tronlong-minievm"
KERNEL_DTS_DIR="target/linux/sunxi/files/arch/arm/boot/dts"

echo "-------------------------------------------------------"
echo "Starting DIY Part 2: Preparing Transplant Artifacts"
echo "-------------------------------------------------------"

# ==============================================================================
# 1. 部署单体 DTS 文件 (必须)
# ==============================================================================
mkdir -p "$KERNEL_DTS_DIR"
mkdir -p target/linux/sunxi/dts

if [ -f "files/$DTS_FILENAME" ]; then
    echo "  -> Deploying DTS..."
    cp "files/$DTS_FILENAME" "$KERNEL_DTS_DIR/"
    cp "files/$DTS_FILENAME" target/linux/sunxi/dts/
else
    echo "❌ Error: files/$DTS_FILENAME not found!"
    exit 1
fi

# ==============================================================================
# 2. 生成 boot.scr (这是给官方 U-Boot 看的指令书)
# ==============================================================================
echo "  -> Generating custom boot.scr..."
cat <<EOF > boot.cmd
# OpenWrt Boot Script for Tronlong T113 (Transplant Mode)
# 核心逻辑：覆盖官方默认启动参数
part uuid mmc 0:2 uuid
setenv bootargs console=ttyS0,115200 root=PARTUUID=\${uuid} rootwait panic=10 earlycon=uart8250,mmio32,0x02500000
# 加载 OpenWrt 内核 (注意：官方可能是 uImage，我们要用 zImage)
load mmc 0:1 \${kernel_addr_r} zImage
# 加载 OpenWrt 设备树
load mmc 0:1 \${fdt_addr_r} $DTS_NAME.dtb
# 启动
bootz \${kernel_addr_r} - \${fdt_addr_r}
EOF

# 编译为二进制脚本
mkimage -C none -A arm -T script -d boot.cmd files/boot.scr

if [ -f "files/boot.scr" ]; then
    echo "  -> Success: boot.scr generated."
else
    echo "❌ Error: Failed to generate boot.scr (Check u-boot-tools)."
    exit 1
fi

# ==============================================================================
# 3. 注册机型 (为了能编译出内核)
# ==============================================================================
# 我们依然需要告诉 OpenWrt 编译这个 DTS，但不再关心 U-Boot 和打包报错
cat <<EOF >> "target/linux/sunxi/image/cortexa7.mk"
define Device/tronlong_tlt113-minievm
  \$(Device/sunxi-img)
  DEVICE_VENDOR := Tronlong
  DEVICE_MODEL := TLT113-MiniEVM (Transplant)
  DEVICE_DTS := $DTS_NAME
  # 使用一个存在的配置混过去
  DEVICE_UBOOT := nanopi_neo
  SUPPORTED_DEVICES := tronlong,tlt113-minievm
endef
TARGET_DEVICES += tronlong_tlt113-minievm
EOF

echo "DIY Part 2 Finished."
