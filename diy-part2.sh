#!/bin/bash
# Description: OpenWrt DIY script part 2 (Hijack MangoPi MQ-R Strategy)

# 你的源文件名
MY_DTS="sun8i-t113-tronlong-minievm.dts"
# 宿主的文件名 (我们要覆盖的目标)
HOST_DTS="sun8i-t113s-mangopi-mq-r.dts"

# OpenWrt 内核源码覆盖目录
KERNEL_DTS_DIR="target/linux/sunxi/files/arch/arm/boot/dts"
TARGET_MK="target/linux/sunxi/image/cortexa7.mk"

echo "-------------------------------------------------------"
echo "Starting DIY Part 2: Operation Hijack MangoPi"
echo "-------------------------------------------------------"

# ==============================================================================
# 1. 偷梁换柱：替换 DTS 文件
# ==============================================================================
echo "[1/2] Replacing MangoPi DTS with Tronlong DTS..."

mkdir -p "$KERNEL_DTS_DIR"

if [ -f "files/$MY_DTS" ]; then
    # 1. 也就是把你的 dts 复制进去，但改名叫 sun8i-t113s-mangopi-mq-r.dts
    # 这样编译系统毫无察觉，直接使用你的配置
    cp "files/$MY_DTS" "$KERNEL_DTS_DIR/$HOST_DTS"
    echo "  -> Hijacked: $HOST_DTS is now Tronlong content."
    
    # 2. 别忘了把那两个依赖的 .dtsi 文件也放进去
    # (t113s.dtsi 和 sun20i-d1s.dtsi)
    cp files/*.dtsi "$KERNEL_DTS_DIR/"
    echo "  -> Dependencies (.dtsi) injected."
else
    echo "  -> Error: Source file files/$MY_DTS not found!"
    exit 1
fi

# ==============================================================================
# 2. 注入参数：修改 U-Boot 内存配置
# ==============================================================================
echo "[2/2] Injecting DDR3 parameters into Makefile..."

if [ -f "$TARGET_MK" ]; then
    # 我们要找到 define Device/mangopi_mq-r 这一块
    # 然后在 endef 之前，插入 UBOOT_CONFIG_OVERRIDES
    
    # 你的 DDR3 参数
    PAYLOAD="  UBOOT_CONFIG_OVERRIDES := CONFIG_DRAM_CLK=792 CONFIG_DRAM_ZQ=8092667"
    
    # 使用 sed 在 'define Device/mangopi_mq-r' 区块内的 'endef' 前插入
    sed -i "/define Device\/mangopi_mq-r/,/endef/ s|endef|$PAYLOAD\nendef|" "$TARGET_MK"
    
    # 验证是否修改成功
    if grep -q "CONFIG_DRAM_CLK=792" "$TARGET_MK"; then
        echo "  -> Success: DDR3 parameters injected."
    else
        echo "  -> Error: Failed to patch Makefile for MangoPi!"
        exit 1
    fi
else
    echo "  -> Error: Target Makefile not found!"
    exit 1
fi

echo "-------------------------------------------------------"
echo "DIY Part 2 Finished Successfully."
