#!/bin/bash
# diy-part2.sh: 创龙 T113-i 适配补丁

DTS_FILENAME="sun8i-t113-tronlong-minievm.dts"
DTS_NAME="sun8i-t113-tronlong-minievm"
KERNEL_DTS_DIR="target/linux/sunxi/files/arch/arm/boot/dts"
TARGET_MK="target/linux/sunxi/image/cortexa7.mk"

echo "Applying T113-i Transplant Patches..."

# 1. 部署设备树到内核源码树
mkdir -p "$KERNEL_DTS_DIR"
if [ -f "files/$DTS_FILENAME" ]; then
    cp "files/$DTS_FILENAME" "$KERNEL_DTS_DIR/"
    echo "DTS deployed to $KERNEL_DTS_DIR"
fi

# 2. 修改 OpenWrt 构建机型定义
if ! grep -q "Device/tronlong_tlt113-minievm" "$TARGET_MK"; then
cat <<EOF >> "$TARGET_MK"

define Device/tronlong_tlt113-minievm
  \$(Device/sunxi-img)
  DEVICE_VENDOR := Tronlong
  DEVICE_MODEL := TLT113-MiniEVM
  DEVICE_DTS := $DTS_NAME
  DEVICE_UBOOT := nanopi_neo
  SUPPORTED_DEVICES := tronlong,tlt113-minievm
endef
TARGET_DEVICES += tronlong_tlt113-minievm
EOF
fi

echo "Patches applied successfully."
