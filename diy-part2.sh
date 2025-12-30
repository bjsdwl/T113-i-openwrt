#!/bin/bash
# diy-part2.sh: 创龙 T113-i 机型适配 (精简版，防止构建报错)

DTS_FILENAME="sun8i-t113-tronlong-minievm.dts"
DTS_NAME="sun8i-t113-tronlong-minievm"
KERNEL_DTS_DIR="target/linux/sunxi/files/arch/arm/boot/dts"
TARGET_MK="target/linux/sunxi/image/cortexa7.mk"

echo "Applying T113-i Minimal Device Patches..."

# 1. 部署设备树
mkdir -p "$KERNEL_DTS_DIR"
if [ -f "files/$DTS_FILENAME" ]; then
    cp "files/$DTS_FILENAME" "$KERNEL_DTS_DIR/"
    echo "DTS deployed."
fi

# 2. 注册机型 (使用最简定义，只产出 zImage 和 rootfs)
if ! grep -q "Device/tronlong_tlt113-minievm" "$TARGET_MK"; then
cat <<EOF >> "$TARGET_MK"

define Device/tronlong_tlt113-minievm
  DEVICE_VENDOR := Tronlong
  DEVICE_MODEL := TLT113-MiniEVM
  DEVICE_DTS := $DTS_NAME
  KERNEL := kernel-bin
  FILESYSTEMS := ext4
endef
TARGET_DEVICES += tronlong_tlt113-minievm
EOF
fi

echo "Patches applied successfully."
