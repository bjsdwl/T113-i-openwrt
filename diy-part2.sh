#!/bin/bash
# Description: OpenWrt DIY script part 2 (Evidence Gathering Mode)

DTS_NAME="sun8i-t113-tronlong-minievm"
TARGET_MK="target/linux/sunxi/image/cortexa7.mk"
KERNEL_DTS_DIR="target/linux/sunxi/files/arch/arm/boot/dts"
UBOOT_MAKEFILE="package/boot/uboot-sunxi/Makefile"

echo "-------------------------------------------------------"
echo "Starting DIY Part 2: EVIDENCE GATHERING MODE"
echo "-------------------------------------------------------"

# ==============================================================================
# 1. 部署 DTS (保持原样，确保内核能编过)
# ==============================================================================
mkdir -p "$KERNEL_DTS_DIR"
mkdir -p target/linux/sunxi/dts

if ls files/*.dts* 1> /dev/null 2>&1; then
    cp files/*.dts* "$KERNEL_DTS_DIR/"
    cp files/*.dts* target/linux/sunxi/dts/
    echo "  -> DTS files deployed."
fi

# ==============================================================================
# 2. 注入机型 (保持原样，确保能触发构建)
# ==============================================================================
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
echo "  -> Device definition injected."

# ==============================================================================
# 3. [核心任务] 收集证据 (Collect Evidence)
# ==============================================================================
# 我们将关键文件复制到 debug_files 目录（配合 Workflow 上传）
# 同时直接打印到控制台，方便你直接看日志
# ==============================================================================

echo "  -> Collecting Makefiles for analysis..."
mkdir -p debug_files

if [ -f "$UBOOT_MAKEFILE" ]; then
    # 1. 复制文件以便打包下载
    cp "$UBOOT_MAKEFILE" debug_files/uboot_makefile_dump.txt
    
    # 2. 【重点】直接打印文件内容到日志！
    # 这样你不需要下载 Artifacts，直接在 GitHub 网页日志里就能看到，复制给我即可。
    echo "======================================================="
    echo "START OF FILE: $UBOOT_MAKEFILE"
    echo "======================================================="
    cat "$UBOOT_MAKEFILE"
    echo "======================================================="
    echo "END OF FILE: $UBOOT_MAKEFILE"
    echo "======================================================="
else
    echo "!! ERROR: $UBOOT_MAKEFILE NOT FOUND !!"
fi

echo "-------------------------------------------------------"
echo "DIY Part 2 Finished. Please check build logs for Makefile content."
