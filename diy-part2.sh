#!/bin/bash
# Description: OpenWrt DIY script part 2 (Dummy U-Boot Package Strategy)

DTS_NAME="sun8i-t113-tronlong-minievm"
TARGET_MK="target/linux/sunxi/image/cortexa7.mk"
KERNEL_DTS_DIR="target/linux/sunxi/files/arch/arm/boot/dts"
GEN_IMAGE_SCRIPT="target/linux/sunxi/image/gen_sunxi_sdcard_img.sh"

echo "-------------------------------------------------------"
echo "Starting DIY Part 2: Creating Custom U-Boot Package"
echo "-------------------------------------------------------"

# ==============================================================================
# 1. 检查 20MB 文件 (必须存在)
# ==============================================================================
if [ ! -f "files/u-boot-sunxi-with-spl.bin" ]; then
    echo "❌ Error: files/u-boot-sunxi-with-spl.bin NOT FOUND!"
    exit 1
fi

# ==============================================================================
# 2. 部署 DTS
# ==============================================================================
mkdir -p "$KERNEL_DTS_DIR"
mkdir -p target/linux/sunxi/dts
if ls files/*.dts* 1> /dev/null 2>&1; then
    cp files/*.dts* "$KERNEL_DTS_DIR/"
    cp files/*.dts* target/linux/sunxi/dts/
    echo "  -> Success: DTS deployed."
else
    echo "❌ Error: No DTS files found!"
    exit 1
fi

# ==============================================================================
# 3. 创建 "伪装" U-Boot 软件包 (核心步骤)
# ==============================================================================
# 我们创建一个 OpenWrt 软件包，专门负责搬运文件
PKG_DIR="package/boot/u-boot-tronlong_tlt113-minievm"
mkdir -p "$PKG_DIR"

# A. 创建 boot.cmd (放在包目录里)
cat <<EOF > "$PKG_DIR/boot.cmd"
# OpenWrt Boot Script for Tronlong T113
part uuid mmc 0:2 uuid
setenv bootargs console=ttyS0,115200 root=PARTUUID=\${uuid} rootwait panic=10 earlycon=uart8250,mmio32,0x02500000
load mmc 0:1 \${kernel_addr_r} zImage
load mmc 0:1 \${fdt_addr_r} $DTS_NAME.dtb
bootz \${kernel_addr_r} - \${fdt_addr_r}
EOF

# B. 创建 Makefile (这是 OpenWrt 识别软件包的身份证)
cat <<EOF > "$PKG_DIR/Makefile"
include \$(TOPDIR)/rules.mk

PKG_NAME:=u-boot-tronlong_tlt113-minievm
PKG_VERSION:=2025.01
PKG_RELEASE:=1

PKG_BUILD_DIR:=\$(BUILD_DIR)/\$(PKG_NAME)

include \$(INCLUDE_DIR)/package.mk

define Package/u-boot-tronlong_tlt113-minievm
  SECTION:=boot
  CATEGORY:=Boot Loaders
  TITLE:=Custom U-Boot for Tronlong T113
  DEPENDS:=@TARGET_sunxi
endef

define Build/Prepare
	# 准备阶段：把 boot.cmd 和 GitHub 仓库里的 bin 文件复制到编译目录
	mkdir -p \$(PKG_BUILD_DIR)
	cp \$(TOPDIR)/files/u-boot-sunxi-with-spl.bin \$(PKG_BUILD_DIR)/
	cp \$(TOPDIR)/$PKG_DIR/boot.cmd \$(PKG_BUILD_DIR)/
endef

define Build/Compile
	# 编译阶段：生成 boot.scr
	mkimage -C none -A arm -T script -d \$(PKG_BUILD_DIR)/boot.cmd \$(PKG_BUILD_DIR)/boot.scr
endef

define Build/InstallDev
	# 安装阶段：把文件复制到 staging_dir (ImageBuilder 会来这里找)
	\$(INSTALL_DIR) \$(STAGING_DIR_IMAGE)
	\$(CP) \$(PKG_BUILD_DIR)/u-boot-sunxi-with-spl.bin \$(STAGING_DIR_IMAGE)/tronlong_tlt113-minievm-u-boot-with-spl.bin
	\$(CP) \$(PKG_BUILD_DIR)/boot.scr \$(STAGING_DIR_IMAGE)/tronlong_tlt113-minievm-boot.scr
endef

\$(eval \$(call BuildPackage,u-boot-tronlong_tlt113-minievm))
EOF

echo "  -> Success: Custom U-Boot package created at $PKG_DIR"

# ==============================================================================
# 4. 修改分区偏移 (适配 20MB U-Boot)
# ==============================================================================
if [ -f "$GEN_IMAGE_SCRIPT" ]; then
    sed -i 's/-l 1024/-l 65536/g' "$GEN_IMAGE_SCRIPT"
    echo "  -> Success: Partition start moved to 32MB."
else
    echo "❌ Error: gen_sunxi_sdcard_img.sh not found!"
    exit 1
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
  
  # 关键：指定 U-Boot 为我们刚刚创建的这个包名
  # OpenWrt 会自动去编译 package/boot/u-boot-tronlong_tlt113-minievm
  # 并自动运行它的 InstallDev 逻辑
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
