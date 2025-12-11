#!/bin/bash
# Description: OpenWrt DIY script part 2 (Evidence Collection Mode)

DTS_NAME="sun8i-t113-tronlong-minievm"
TARGET_MK="target/linux/sunxi/image/cortexa7.mk"
KERNEL_DTS_DIR="target/linux/sunxi/files/arch/arm/boot/dts"
UBOOT_MAKEFILE="package/boot/uboot-sunxi/Makefile"
IMAGE_MAKEFILE="target/linux/sunxi/image/Makefile"

echo "--- STARTING EVIDENCE COLLECTION ---"

# 1. 正常部署 DTS (保持原样，以便触发后续流程)
mkdir -p "$KERNEL_DTS_DIR"
mkdir -p target/linux/sunxi/dts
if ls files/*.dts* 1> /dev/null 2>&1; then
    cp files/*.dts* "$KERNEL_DTS_DIR/"
    cp files/*.dts* target/linux/sunxi/dts/
fi

# 2. 正常注入机型 (保持原样)
cat <<EOF >> "$TARGET_MK"
define Device/tronlong_tlt113-minievm
  \$(Device/sunxi-img)
  DEVICE_VENDOR := Tronlong
  DEVICE_MODEL := TLT113-MiniEVM (NAND/HDMI)
  DEVICE_DTS := $DTS_NAME
  DEVICE_UBOOT := sun8i-r528-qa-board
  UBOOT_CONFIG_OVERRIDES := CONFIG_DRAM_CLK=792 CONFIG_DRAM_ZQ=8092667 CONFIG_DEFAULT_DEVICE_TREE="$DTS_NAME"
  SUPPORTED_DEVICES := tronlong,tlt113-minievm
endef
TARGET_DEVICES += tronlong_tlt113-minievm
EOF

# 3. [关键步骤] 收集证据文件到 debug_evidence 目录
mkdir -p debug_evidence

# 收集 U-Boot 的 Makefile (查看安装逻辑)
if [ -f "$UBOOT_MAKEFILE" ]; then
    cp "$UBOOT_MAKEFILE" debug_evidence/uboot_makefile.txt
    echo "Collected: uboot_makefile.txt"
else
    echo "MISSING: U-Boot Makefile not found!" > debug_evidence/error_uboot.txt
fi

# 收集 Image 的 Makefile (查看打包逻辑)
if [ -f "$IMAGE_MAKEFILE" ]; then
    cp "$IMAGE_MAKEFILE" debug_evidence/image_makefile.txt
    echo "Collected: image_makefile.txt"
fi

# 收集我们刚刚修改过的 cortexa7.mk (确认注入是否生效)
if [ -f "$TARGET_MK" ]; then
    cp "$TARGET_MK" debug_evidence/cortexa7_mk.txt
    echo "Collected: cortexa7_mk.txt"
fi

echo "--- EVIDENCE COLLECTION FINISHED ---"
