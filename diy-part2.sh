#!/bin/bash
# Description: OpenWrt DIY script part 2 (Hardcode Paths Edition)

DTS_NAME="sun8i-t113-tronlong-minievm"
TARGET_MK="target/linux/sunxi/image/cortexa7.mk"
KERNEL_DTS_DIR="target/linux/sunxi/files/arch/arm/boot/dts"
IMAGE_MAKEFILE="target/linux/sunxi/image/Makefile"

# 借用的 U-Boot 基础配置名 (ImmortalWrt 中存在的配置)
BASE_UBOOT="sun8i-r528-qa-board"

echo "-------------------------------------------------------"
echo "Starting DIY Part 2: Hardcode Paths Strategy"
echo "-------------------------------------------------------"

# ==============================================================================
# 1. 部署 DTS 文件
# ==============================================================================
mkdir -p "$KERNEL_DTS_DIR"
mkdir -p target/linux/sunxi/dts
if ls files/*.dts* 1> /dev/null 2>&1; then
    echo "  -> Found DTS files. Copying..."
    cp files/*.dts* "$KERNEL_DTS_DIR/"
    cp files/*.dts* target/linux/sunxi/dts/
else
    echo "  -> Error: No DTS files found!"
    exit 1
fi

# ==============================================================================
# 2. 手动生成 boot.scr (绕过 U-Boot 自动生成的不确定性)
# ==============================================================================
echo "  -> Generating custom boot.scr..."
cat <<EOF > boot.cmd
# OpenWrt Boot Script for Tronlong T113
part uuid mmc 0:2 uuid
setenv bootargs console=ttyS0,115200 root=PARTUUID=\${uuid} rootwait panic=10 earlycon=uart8250,mmio32,0x02500000
load mmc 0:1 \${kernel_addr_r} zImage
load mmc 0:1 \${fdt_addr_r} $DTS_NAME.dtb
bootz \${kernel_addr_r} - \${fdt_addr_r}
EOF

mkimage -C none -A arm -T script -d boot.cmd files/boot.scr

if [ ! -f "files/boot.scr" ]; then
    echo "  -> Error: Failed to generate boot.scr (mkimage not found?)"
    exit 1
fi
echo "  -> Success: files/boot.scr generated."

# ==============================================================================
# 3. [核弹级操作] 暴力修改 Image Makefile
# ==============================================================================
echo "  -> Hardcoding paths in Image Makefile..."

if [ -f "$IMAGE_MAKEFILE" ]; then
    # 1. 强制 boot.scr 指向我们刚才生成的本地文件
    # 使用 $(TOPDIR)/files/boot.scr 绝对定位
    sed -i 's|\$(STAGING_DIR_IMAGE)/\$(DEVICE_NAME)-boot.scr|\$(TOPDIR)/files/boot.scr|g' "$IMAGE_MAKEFILE"
    
    # 2. 强制 U-Boot 二进制文件指向借用的那个文件名
    # 无论当前编译什么机型，都去拿 sun8i-r528-qa-board-... 的文件
    # 这会破坏其他板子的编译，但因为我们只编这一个，所以没关系！
    sed -i "s|\$(STAGING_DIR_IMAGE)/\$(DEVICE_NAME)-u-boot-with-spl.bin|\$(STAGING_DIR_IMAGE)/${BASE_UBOOT}-u-boot-with-spl.bin|g" "$IMAGE_MAKEFILE"
    
    echo "  -> Success: Image Makefile hacked."
    # 打印修改行确认
    grep "files/boot.scr" "$IMAGE_MAKEFILE" || echo "Warning: sed checking failed"
else
    echo "  -> Error: Image Makefile not found!"
    exit 1
fi

# ==============================================================================
# 4. 注入机型定义
# ==============================================================================
cat <<EOF >> "$TARGET_MK"

# --- Added by DIY Script for Tronlong TLT113-MiniEVM ---
define Device/tronlong_tlt113-minievm
  \$(Device/sunxi-img)
  DEVICE_VENDOR := Tronlong
  DEVICE_MODEL := TLT113-MiniEVM (NAND/HDMI)
  DEVICE_DTS := $DTS_NAME
  
  # 必须借用这个 U-Boot，才能生成 Makefile 里硬编码的文件名
  DEVICE_UBOOT := $BASE_UBOOT
  
  # 依然需要覆盖内存参数，因为这是运行时被 SPL 读取的
  UBOOT_CONFIG_OVERRIDES := CONFIG_DRAM_CLK=792 CONFIG_DRAM_ZQ=8092667 CONFIG_DEFAULT_DEVICE_TREE="$DTS_NAME"
  
  SUPPORTED_DEVICES := tronlong,tlt113-minievm
endef
TARGET_DEVICES += tronlong_tlt113-minievm
EOF

echo "  -> Success: Device definition appended."
echo "DIY Part 2 Finished Successfully."
