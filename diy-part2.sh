#!/bin/bash
# diy-part2.sh: Tronlong T113-i 机型适配

DTS_FILENAME="sun8i-t113-tronlong-minievm.dts"
DTS_NAME="sun8i-t113-tronlong-minievm"
KERNEL_DTS_DIR="target/linux/sunxi/files/arch/arm/boot/dts"
TARGET_MK="target/linux/sunxi/image/cortexa7.mk"

echo "Applying T113-i Transplant Patches..."

# 1. 部署设备树
mkdir -p "$KERNEL_DTS_DIR"
if [ -f "files/$DTS_FILENAME" ]; then
    cp "files/$DTS_FILENAME" "$KERNEL_DTS_DIR/"
    echo "DTS deployed."
fi

# 2. 注册机型
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

# 3. 准备 boot.scr (作为备份引导)
cat <<EOF > files/boot.cmd
part uuid mmc 0:2 uuid
setenv bootargs console=ttyS0,115200 root=PARTUUID=\${uuid} rootwait panic=10 earlycon=uart8250,mmio32,0x02500000
load mmc 0:1 \${kernel_addr_r} zImage
load mmc 0:1 \${fdt_addr_r} $DTS_NAME.dtb
bootz \${kernel_addr_r} - \${fdt_addr_r}
EOF
mkimage -C none -A arm -T script -d files/boot.cmd files/boot.scr

echo "Patches applied successfully."
