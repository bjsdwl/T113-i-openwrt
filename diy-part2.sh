#!/bin/bash
# Description: OpenWrt DIY script part 2 (Create New Target - The Correct Way)

DTS_NAME="sun8i-t113-tronlong-minievm"
TARGET_MK="target/linux/sunxi/image/cortexa7.mk"
KERNEL_DTS_DIR="target/linux/sunxi/files/arch/arm/boot/dts"
UBOOT_MAKEFILE="package/boot/uboot-sunxi/Makefile"
UBOOT_CONFIG_DIR="package/boot/uboot-sunxi/u-boot-sunxi/configs"
IMAGE_MAKEFILE="target/linux/sunxi/image/Makefile"

echo "-------------------------------------------------------"
echo "Starting DIY Part 2: Full Custom Target Creation"
echo "-------------------------------------------------------"

# ==============================================================================
# 1. 部署 DTS 文件 (我们已经验证这部分是没问题的)
# ==============================================================================
mkdir -p "$KERNEL_DTS_DIR"
mkdir -p target/linux/sunxi/dts

if ls files/*.dts* 1> /dev/null 2>&1; then
    echo "  -> Found DTS files. Copying..."
    cp files/*.dts* "$KERNEL_DTS_DIR/"
    cp files/*.dts* target/linux/sunxi/dts/
    echo "  -> Success: Device Tree files deployed."
else
    echo "  -> Error: No DTS files found!"
    exit 1
fi

# ==============================================================================
# 2. 创建 U-Boot Defconfig (让 U-Boot 知道怎么编我们的板子)
# ==============================================================================
echo "  -> Creating U-Boot defconfig..."
mkdir -p "$UBOOT_CONFIG_DIR"

# 这是一个标准的 T113 U-Boot 配置，填入了你的 DDR3 参数
# 这样 U-Boot 编译时就会使用这些参数，而不需要我们在 Makefile 里覆盖
cat <<EOF > "$UBOOT_CONFIG_DIR/tronlong_tlt113-minievm_defconfig"
CONFIG_ARM=y
CONFIG_ARCH_SUNXI=y
CONFIG_DEFAULT_DEVICE_TREE="$DTS_NAME"
CONFIG_SPL=y
CONFIG_MACH_SUN8I_R528=y
CONFIG_DRAM_CLK=792
CONFIG_DRAM_ZQ=8092667
CONFIG_DRAM_ODT_EN=y
CONFIG_MMC_SUNXI_SLOT_EXTRA=2
CONFIG_SPL_SPI_SUNXI=y
CONFIG_CMD_SPI=y
EOF

# ==============================================================================
# 3. 注册 U-Boot 编译目标 (核心步骤！)
# ==============================================================================
echo "  -> Registering new U-Boot target in Makefile..."

if [ -f "$UBOOT_MAKEFILE" ]; then
    # 我们直接在 Makefile 末尾追加定义，这是最安全的做法
    # 1. 定义编译规则
    # 2. 将目标加入到 UBOOT_TARGETS 列表
    
    cat <<EOF >> "$UBOOT_MAKEFILE"

# --- Added by DIY Script ---
define U-Boot/tronlong_tlt113-minievm
  BUILD_SUBTARGET:=cortexa7
  NAME:=Tronlong TLT113 MiniEVM
  BUILD_DEVICES:=tronlong_tlt113-minievm
  UENV:=default
endef

# 将我们的板子加入编译列表，这样 OpenWrt 就会真的去编译它
UBOOT_TARGETS += tronlong_tlt113-minievm
# ---------------------------
EOF
    echo "  -> Success: U-Boot target registered."
else
    echo "  -> Error: U-Boot Makefile not found!"
    exit 1
fi

# ==============================================================================
# 4. 手动生成 boot.scr (保持之前的成功经验，绕过自动生成的坑)
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

# 修改 Image Makefile 强制使用本地 boot.scr
# 注意：我们不需要修改 U-Boot bin 的路径了，因为第3步会让系统生成正确名字的文件！
if [ -f "$IMAGE_MAKEFILE" ]; then
    sed -i 's|\$(STAGING_DIR_IMAGE)/\$(DEVICE_NAME)-boot.scr|\$(TOPDIR)/files/boot.scr|g' "$IMAGE_MAKEFILE"
    echo "  -> Success: Image Makefile patched for boot.scr."
fi

# ==============================================================================
# 5. 注入机型定义
# ==============================================================================
if [ ! -f "$TARGET_MK" ]; then
    echo "  -> Error: Target Makefile $TARGET_MK not found!"
    exit 1
fi

cat <<EOF >> "$TARGET_MK"

# --- Added by DIY Script for Tronlong TLT113-MiniEVM ---
define Device/tronlong_tlt113-minievm
  \$(Device/sunxi-img)
  DEVICE_VENDOR := Tronlong
  DEVICE_MODEL := TLT113-MiniEVM (NAND/HDMI)
  DEVICE_DTS := $DTS_NAME
  
  # 这里引用我们在第3步注册的 U-Boot 目标
  # 它的名字是 tronlong_tlt113-minievm，所以生成的文件名也会是这个
  DEVICE_UBOOT := tronlong_tlt113-minievm
  
  # 我们的 defconfig 里已经写了参数，但这里覆盖一下也无妨
  UBOOT_CONFIG_OVERRIDES := CONFIG_DRAM_CLK=792 CONFIG_DRAM_ZQ=8092667 CONFIG_DEFAULT_DEVICE_TREE="$DTS_NAME"
  
  SUPPORTED_DEVICES := tronlong,tlt113-minievm
endef
TARGET_DEVICES += tronlong_tlt113-minievm
# -------------------------------------------------------
EOF

echo "  -> Success: Device definition appended."
echo "-------------------------------------------------------"
echo "DIY Part 2 Finished Successfully."
