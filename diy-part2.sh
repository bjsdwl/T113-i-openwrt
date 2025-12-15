#!/bin/bash
# Description: OpenWrt DIY script part 2 (Prepare Files for Transplant)

DTS_NAME="sun8i-t113-tronlong-minievm"
TARGET_MK="target/linux/sunxi/image/cortexa7.mk"
KERNEL_DTS_DIR="target/linux/sunxi/files/arch/arm/boot/dts"

echo "-------------------------------------------------------"
echo "Starting DIY Part 2: Preparation for Transplant"
echo "-------------------------------------------------------"

# 1. 部署 DTS 文件
mkdir -p "$KERNEL_DTS_DIR"
mkdir -p target/linux/sunxi/dts
if ls files/*.dts* 1> /dev/null 2>&1; then
    cp files/*.dts* "$KERNEL_DTS_DIR/"
    cp files/*.dts* target/linux/sunxi/dts/
    echo "  -> Success: DTS files deployed."
else
    echo "❌ Error: No DTS files found!"
    exit 1
fi

# 2. 生成 boot.scr (这是你要的三个文件之一)
echo "  -> Generating boot.scr..."
cat <<EOF > boot.cmd
# OpenWrt Boot Script for Tronlong T113
part uuid mmc 0:2 uuid
setenv bootargs console=ttyS0,115200 root=PARTUUID=\${uuid} rootwait panic=10 earlycon=uart8250,mmio32,0x02500000
load mmc 0:1 \${kernel_addr_r} zImage
load mmc 0:1 \${fdt_addr_r} $DTS_NAME.dtb
bootz \${kernel_addr_r} - \${fdt_addr_r}
EOF

mkimage -C none -A arm -T script -d boot.cmd files/boot.scr

if [ -f "files/boot.scr" ]; then
    echo "  -> Success: boot.scr generated in files/ directory."
else
    echo "❌ Error: Failed to generate boot.scr!"
    exit 1
fi

# 3. 注册机型 (保证内核能被编译出来)
# 我们不需要关心 U-Boot 报不报错了，只要内核能编出来就行
if [ -f "$TARGET_MK" ]; then
    cat <<EOF >> "$TARGET_MK"
define Device/tronlong_tlt113-minievm
  \$(Device/sunxi-img)
  DEVICE_VENDOR := Tronlong
  DEVICE_MODEL := TLT113-MiniEVM (Transplant Mode)
  DEVICE_DTS := $DTS_NAME
  # 使用一个存在的 H3 配置混过去，确保流程能走
  DEVICE_UBOOT := nanopi_neo
  UBOOT_CONFIG_OVERRIDES := CONFIG_DRAM_CLK=792 CONFIG_DRAM_ZQ=8092667
  SUPPORTED_DEVICES := tronlong,tlt113-minievm
endef
TARGET_DEVICES += tronlong_tlt113-minievm
EOF
    echo "  -> Success: Device registered."
fi
