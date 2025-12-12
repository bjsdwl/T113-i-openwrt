#!/bin/bash
# Description: OpenWrt DIY script part 2 (Smart Hijack Strategy)

# 你的源文件 (创龙配置)
MY_DTS="sun8i-t113-tronlong-minievm.dts"
# 宿主文件名 (MangoPi)
HOST_DTS_NAME="sun8i-t113s-mangopi-mq-r.dts"
# 宿主机型 ID (Makefile 中的 Device Name)
HOST_DEVICE_ID="mangopi_mq-r"

KERNEL_DTS_DIR="target/linux/sunxi/files/arch/arm/boot/dts"

echo "-------------------------------------------------------"
echo "Starting DIY Part 2: Smart Hijack Operation"
echo "-------------------------------------------------------"

# ==============================================================================
# 1. 偷梁换柱：DTS 替换
# ==============================================================================
echo "[1/3] Hijacking DTS..."
mkdir -p "$KERNEL_DTS_DIR"
mkdir -p target/linux/sunxi/dts

if [ -f "files/$MY_DTS" ]; then
    # 覆盖 Kernel Overlay
    cp "files/$MY_DTS" "$KERNEL_DTS_DIR/$HOST_DTS_NAME"
    # 覆盖标准目录
    cp "files/$MY_DTS" "target/linux/sunxi/dts/$HOST_DTS_NAME"
    
    # 注入依赖的 dtsi
    cp files/*.dtsi "$KERNEL_DTS_DIR/"
    cp files/*.dtsi "target/linux/sunxi/dts/"
    
    echo "  -> Success: DTS hijacked ($HOST_DTS_NAME is now Tronlong)."
else
    echo "  -> Error: Source files/$MY_DTS not found!"
    exit 1
fi

# ==============================================================================
# 2. 自动定位目标 Makefile (Smart Find)
# ==============================================================================
echo "[2/3] Searching for target definition..."

# 在 sunxi 目录下搜索定义了 mangopi_mq-r 的 .mk 文件
TARGET_MK=$(grep -l "define Device/$HOST_DEVICE_ID" target/linux/sunxi/image/*.mk | head -n 1)

if [ -z "$TARGET_MK" ]; then
    echo "  -> Error: Could not find any Makefile defining $HOST_DEVICE_ID"
    echo "  -> Listing available devices for debugging:"
    grep -r "define Device/" target/linux/sunxi/image/ | cut -d: -f2 | head -n 20
    exit 1
else
    echo "  -> Found target definition in: $TARGET_MK"
fi

# ==============================================================================
# 3. 注入 DDR3 参数
# ==============================================================================
echo "[3/3] Injecting DDR3 parameters..."

# 构造要插入的参数行
PAYLOAD="  UBOOT_CONFIG_OVERRIDES := CONFIG_DRAM_CLK=792 CONFIG_DRAM_ZQ=8092667"

# 使用 perl 精准替换
# 逻辑：找到 define Device/mangopi_mq-r ... endef 块
# 在 endef 之前插入 PAYLOAD
perl -i -0777 -pe "s|(define Device/$HOST_DEVICE_ID.*?)endef|\1$PAYLOAD\nendef|s" "$TARGET_MK"

# 验证
if grep -q "CONFIG_DRAM_CLK=792" "$TARGET_MK"; then
    echo "  -> Success: DDR3 parameters injected into $TARGET_MK"
else
    echo "  -> Error: Failed to patch Makefile!"
    echo "  -> Dumping file content for analysis:"
    cat "$TARGET_MK"
    exit 1
fi

echo "-------------------------------------------------------"
echo "DIY Part 2 Finished Successfully."
