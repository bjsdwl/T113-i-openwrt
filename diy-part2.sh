#!/bin/bash
# Description: OpenWrt DIY script part 2 (Dummy Package Strategy + 32MB Offset)

# 变量定义
DTS_FILENAME="sun8i-t113-tronlong-minievm.dts"
DTS_NAME="sun8i-t113-tronlong-minievm"
TARGET_MK="target/linux/sunxi/image/cortexa7.mk"
KERNEL_DTS_DIR="target/linux/sunxi/files/arch/arm/boot/dts"
GEN_IMAGE_SCRIPT="target/linux/sunxi/image/gen_sunxi_sdcard_img.sh"

echo "-------------------------------------------------------"
echo "Starting DIY Part 2: Tronlong TLT113-MiniEVM (Final)"
echo "-------------------------------------------------------"

# ==============================================================================
# 1. 检查必要文件 (20MB U-Boot)
# ==============================================================================
if [ ! -f "files/u-boot-sunxi-with-spl.bin" ]; then
    echo "❌ Error: files/u-boot-sunxi-with-spl.bin NOT FOUND!"
    echo "   Please upload the 20MB official U-Boot binary."
    exit 1
fi

# ==============================================================================
# 2. 部署 DTS 文件
# ==============================================================================
mkdir -p "$KERNEL_DTS_DIR"
mkdir -p target/linux/sunxi/dts

if ls files/*.dts* 1> /dev/null 2>&1; then
    echo "  -> Found DTS files. Copying..."
    # 复制到 Kernel Overlay (强制覆盖)
    cp files/*.dts* "$KERNEL_DTS_DIR/"
    # 复制到标准目录 (备份)
    cp files/*.dts* target/linux/sunxi/dts/
    echo "  -> Success: DTS deployed."
else
    echo "❌ Error: No DTS files found!"
    exit 1
fi

# ==============================================================================
# 3. 修改分区偏移 (32MB Offset) - 给 20MB U-Boot 让路
# ==============================================================================
echo "  -> Patching partition alignment..."
if [ -f "$GEN_IMAGE_SCRIPT" ]; then
    # 将默认的 1MB/512KB 对齐 (-l 1024) 修改为 32MB 对齐 (-l 65536)
    sed -i 's/-l 1024/-l 65536/g' "$GEN_IMAGE_SCRIPT"
    
    if grep -q "\-l 65536" "$GEN_IMAGE_SCRIPT"; then
        echo "  -> Success: Partition start moved to 32MB."
    else
        echo "❌ Error: Failed to patch partition alignment!"
        exit 1
    fi
else
    echo "❌ Error: gen_sunxi_sdcard_img.sh not found!"
    exit 1
fi

# ==============================================================================
# 4. 创建伪装 U-Boot 软件包 (解决文件缺失的核心)
# ==============================================================================
echo "  -> Creating custom U-Boot package..."

PKG_NAME="u-boot-tronlong_tlt113-minievm"
PKG_DIR="package/boot/$PKG_NAME"
mkdir -p "$PKG_DIR"

# A. 创建 boot.cmd
cat <<EOF > "$PKG_DIR/boot.cmd"
# OpenWrt Boot Script for Tronlong T113
part uuid mmc 0:2 uuid
setenv bootargs console=ttyS0,115200 root=PARTUUID=\${uuid} rootwait panic=10 earlycon=uart8250,mmio32,0x02500000
load mmc 0:1 \${kernel_addr_r} zImage
load mmc 0:1 \${fdt_addr_r} $DTS_NAME.dtb
bootz \${kernel_addr_r} - \${fdt_addr_r}
EOF

# B. 创建 Makefile
# 这个 Makefile 的作用是：
# 1. 编译 boot.scr
# 2. 将你的 20MB bin 和 boot.scr 复制到 staging_dir 并重命名
cat <<EOF > "$PKG_DIR/Makefile"
include \$(TOPDIR)/rules.mk

PKG_NAME:=$PKG_NAME
PKG_VERSION:=2025.01
PKG_RELEASE:=1

PKG_BUILD_DIR:=\$(BUILD_DIR)/\$(PKG_NAME)

include \$(INCLUDE_DIR)/package.mk

define Package/$PKG_NAME
  SECTION:=boot
  CATEGORY:=Boot Loaders
  TITLE:=Custom U-Boot for Tronlong
  DEPENDS:=@TARGET_sunxi
endef

define Build/Prepare
	mkdir -p \$(PKG_BUILD_DIR)
	# 复制 boot.cmd
	cp \$(TOPDIR)/$PKG_DIR/boot.cmd \$(PKG_BUILD_DIR)/
	# 复制你上传的 20MB U-Boot
	cp \$(TOPDIR)/files/u-boot-sunxi-with-spl.bin \$(PKG_BUILD_DIR)/
endef

define Build/Compile
	# 生成 boot.scr
	mkimage -C none -A arm -T script -d \$(PKG_BUILD_DIR)/boot.cmd \$(PKG_BUILD_DIR)/boot.scr
endef

define Build/InstallDev
	\$(INSTALL_DIR) \$(STAGING_DIR_IMAGE)
	# 关键：复制并重命名为 OpenWrt 想要的名称
	\$(CP) \$(PKG_BUILD_DIR)/u-boot-sunxi-with-spl.bin \$(STAGING_DIR_IMAGE)/tronlong_tlt113-minievm-u-boot-with-spl.bin
	\$(CP) \$(PKG_BUILD_DIR)/boot.scr \$(STAGING_DIR_IMAGE)/tronlong_tlt113-minievm-boot.scr
endef

\$(eval \$(call BuildPackage,$PKG_NAME))
EOF

echo "  -> Success: Custom package created."

# ==============================================================================
# 5. 注入机型定义
# ==============================================================================
echo "  -> Injecting device definition..."

if [ ! -f "$TARGET_MK" ]; then
    echo "❌ Error: Target Makefile not found!"
    exit 1
fi

cat <<EOF >> "$TARGET_MK"

# --- Added by DIY Script for Tronlong TLT113-MiniEVM ---
define Device/tronlong_tlt113-minievm
  \$(Device/sunxi-img)
  DEVICE_VENDOR := Tronlong
  DEVICE_MODEL := TLT113-MiniEVM (NAND/HDMI)
  DEVICE_DTS := $DTS_NAME
  
  # 关键：指定 U-Boot 为我们刚刚创建的这个包名
  # 这会触发上面的 Build/InstallDev 逻辑，把文件放到位
  DEVICE_UBOOT := tronlong_tlt113-minievm
  
  # 随便填，反正不用源码编
  UBOOT_CONFIG_OVERRIDES := CONFIG_DRAM_CLK=792 CONFIG_DRAM_ZQ=8092667
  
  SUPPORTED_DEVICES := tronlong,tlt113-minievm
endef
TARGET_DEVICES += tronlong_tlt113-minievm
# -------------------------------------------------------
EOF

echo "  -> Success: Device definition appended."
echo "DIY Part 2 Finished Successfully."
