#!/bin/bash
# diy-part2.sh: Tronlong T113-i 机型适配 (完全解耦版)

DTS_FILENAME="sun8i-t113-tronlong-minievm.dts"
DTS_NAME="sun8i-t113-tronlong-minievm"
KERNEL_DTS_DIR="target/linux/sunxi/files/arch/arm/boot/dts"
TARGET_MK="target/linux/sunxi/image/cortexa7.mk"

echo "Applying T113-i Transplant Patches..."

# 1. 部署设备树到内核目录
mkdir -p "$KERNEL_DTS_DIR"
if [ -f "files/$DTS_FILENAME" ]; then
    cp "files/$DTS_FILENAME" "$KERNEL_DTS_DIR/"
    echo "DTS deployed."
fi

# 2. 注入 Dummy 引导脚本生成逻辑到 Makefile (关键修复)
# 这行代码会强制在生成镜像前创建一个空的 boot.scr，防止 mcopy 报错中断
IMAGE_MAKEFILE="target/linux/sunxi/image/Makefile"
sed -i '/image_prepare:/a \	mkdir -p $(STAGING_DIR_IMAGE) && touch $(STAGING_DIR_IMAGE)/$(DEVICE_UBOOT)-boot.scr && touch $(STAGING_DIR_IMAGE)/$(1)-boot.scr' "$IMAGE_MAKEFILE"

# 3. 注册机型
if ! grep -q "Device/tronlong_tlt113-minievm" "$TARGET_MK"; then
cat <<EOF >> "$TARGET_MK"

define Device/tronlong_tlt113-minievm
  DEVICE_VENDOR := Tronlong
  DEVICE_MODEL := TLT113-MiniEVM
  DEVICE_DTS := $DTS_NAME
  DEVICE_UBOOT := nanopi_neo
  KERNEL := kernel-bin
endef
TARGET_DEVICES += tronlong_tlt113-minievm
EOF
fi

echo "Patches applied successfully."
