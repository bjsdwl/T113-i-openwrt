#!/bin/bash
# Description: OpenWrt DIY script part 2 (U-Boot Target Injection Edition)

# 变量定义
DTS_NAME="sun8i-t113-tronlong-minievm"
TARGET_MK="target/linux/sunxi/image/cortexa7.mk"
KERNEL_DTS_DIR="target/linux/sunxi/files/arch/arm/boot/dts"
UBOOT_MAKEFILE="package/boot/uboot-sunxi/Makefile"

echo "-------------------------------------------------------"
echo "Starting DIY Part 2: Customizing for Tronlong TLT113-MiniEVM"
echo "-------------------------------------------------------"

# ==============================================================================
# 1. 部署所有 DTS/DTSI 文件 (保持不变)
# ==============================================================================
echo "[1/3] Deploying Device Tree Files..."
mkdir -p "$KERNEL_DTS_DIR"
mkdir -p target/linux/sunxi/dts
if ls files/*.dts* 1> /dev/null 2>&1; then
    cp files/*.dts* "$KERNEL_DTS_DIR/"
    cp files/*.dts* target/linux/sunxi/dts/
    echo "  -> DTS files deployed."
else
    echo "  -> Error: No DTS files found in files/ !"
    exit 1
fi

# ==============================================================================
# 2. [核心修复] 在 U-Boot Makefile 中注册新机型
# ==============================================================================
echo "[2/3] Registering tronlong_tlt113-minievm in U-Boot Makefile..."

if [ -f "$UBOOT_MAKEFILE" ]; then
    # A. 插入 U-Boot 定义块 (借用 R528 配置)
    # 我们在 BuildPackage/U-Boot 调用前插入定义
    sed -i '/define Build\/InstallDev/i \
define U-Boot/tronlong_tlt113-minievm\
  BUILD_SUBTARGET:=cortexa7\
  NAME:=Tronlong TLT113 MiniEVM\
  BUILD_DEVICES:=tronlong_tlt113-minievm\
  UBOOT_CONFIG:=sun8i_r528\
  UENV:=default\
endef\
' "$UBOOT_MAKEFILE"

    # B. 将新机型加入 UBOOT_TARGETS 列表 (关键！)
    # 我们把名字追加到列表的最后
    sed -i '/UBOOT_TARGETS :=/a \	tronlong_tlt113-minievm \\' "$UBOOT_MAKEFILE"

    echo "  -> Success: U-Boot target registered."
else
    echo "  -> Error: U-Boot Makefile not found!"
    exit 1
fi

# ==============================================================================
# 3. 注入 OpenWrt 机型定义
# ==============================================================================
echo "[3/3] Injecting device definition into $TARGET_MK..."

if [ ! -f "$TARGET_MK" ]; then
    echo "  -> Error: Target Makefile not found!"
    exit 1
fi

# ⚠️ 注意：DEVICE_UBOOT 必须指向我们刚刚在上面注册的名字
cat <<EOF >> "$TARGET_MK"

define Device/tronlong_tlt113-minievm
  \$(Device/sunxi-img)
  DEVICE_VENDOR := Tronlong
  DEVICE_MODEL := TLT113-MiniEVM (NAND/HDMI)
  DEVICE_DTS := $DTS_NAME
  DEVICE_UBOOT := tronlong_tlt113-minievm
  UBOOT_CONFIG_OVERRIDES := CONFIG_DRAM_CLK=792 CONFIG_DRAM_ZQ=8092667 CONFIG_DEFAULT_DEVICE_TREE="$DTS_NAME"
  SUPPORTED_DEVICES := tronlong,tlt113-minievm
endef
TARGET_DEVICES += tronlong_tlt113-minievm
EOF

echo "  -> Success: Device definition appended."
echo "-------------------------------------------------------"
echo "DIY Part 2 Finished Successfully."
