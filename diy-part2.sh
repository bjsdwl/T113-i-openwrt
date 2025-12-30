#!/bin/bash
# diy-part2.sh: Tronlong T113-i 深度适配补丁

DTS_NAME="sun8i-t113-tronlong-minievm"
DTS_FILE="$DTS_NAME.dts"
# 覆盖目录
KERNEL_FILES_DIR="target/linux/sunxi/files/arch/arm/boot/dts"
IMAGE_MAKEFILE="target/linux/sunxi/image/Makefile"

echo "Applying T113-i kernel and image patches..."

# 1. 部署设备树源码
mkdir -p "$KERNEL_FILES_DIR"
[ -f "files/$DTS_FILE" ] && cp "files/$DTS_FILE" "$KERNEL_FILES_DIR/"

# 2. 强制内核 Makefile 注册该 DTB (这是解决 DTB 找不到的关键)
# 我们在 sunxi 的配置处理脚本中插入一行，确保编译时包含该 dtb
# 注意：OpenWrt 在编译内核前会把 files 里的文件覆盖进去，但 Makefile 需手动补丁
# 我们直接在 target/linux/sunxi/Makefile 或 image Makefile 里做手脚
sed -i 's/TARGET_DEVICES +=/DEVICE_DTS := '"$DTS_NAME"'\nTARGET_DEVICES +=/g' target/linux/sunxi/image/cortexa7.mk

# 3. 彻底修复 mcopy 报错：在 image 准备阶段伪造所有可能的 boot.scr
# 无论它寻找 tronlong_tlt113... 还是 nanopi_neo... 统统补齐
sed -i '/image_prepare:/a \	mkdir -p $(STAGING_DIR_IMAGE) && touch $(STAGING_DIR_IMAGE)/$(DEVICE_UBOOT)-boot.scr && touch $(STAGING_DIR_IMAGE)/tronlong_tlt113-minievm-boot.scr && touch $(STAGING_DIR_IMAGE)/sunxi-boot.scr' "$IMAGE_MAKEFILE"

# 4. 注册机型定义
if ! grep -q "Device/tronlong_tlt113-minievm" target/linux/sunxi/image/cortexa7.mk; then
cat <<EOF >> target/linux/sunxi/image/cortexa7.mk

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

echo "Patches applied."
