#!/bin/bash
#
# diy-part2.sh: T113-i OpenWrt 最终全自动适配脚本 (Mainline 6.12 + Appended DTB)
#

DTS_NAME="sun8i-t113-tronlong-minievm"
KERNEL_VER="6.12"

echo ">>> [Stage 1] 解锁内核驱动限制 (RISC-V -> ARM)..."
# 暴力拆除 Kconfig 中对 D1 驱动的 RISCV 架构锁定，使 T113 能编译这些驱动
find . -name "Kconfig" -path "*/sunxi-ng/*" -exec sed -i 's/depends on RISCV/depends on RISCV || ARCH_SUNXI/g' {} +
find . -name "Kconfig" -path "*/pinctrl/sunxi/*" -exec sed -i 's/depends on RISCV/depends on RISCV || ARCH_SUNXI/g' {} +

echo ">>> [Stage 2] 注入内核强制配置 (Appended DTB & Force CMDLINE)..."
for f in target/linux/sunxi/config-*; do
    [ -e "$f" ] || continue
    
    # 核心：允许内核读取附加在末尾的 DTB (解决 U-Boot 传错 DTB 的致命问题)
    echo "CONFIG_ARM_APPENDED_DTB=y" >> $f
    echo "CONFIG_ARM_ATAG_DTB_COMPAT=y" >> $f
    
    # 核心：暴力覆盖 U-Boot 传来的垃圾参数，强制指定 rootfs 路径
    echo "CONFIG_CMDLINE_FORCE=y" >> $f
    echo "CONFIG_CMDLINE=\"console=ttyS0,115200 earlycon=uart8250,mmio32,0x02500000 root=/dev/mmcblk0p5 rootwait panic=10 clk_ignore_unused initcall_debug=1\"" >> $f
    
    # 驱动补全
    echo "CONFIG_PINCTRL_SUN8I_T113S=y" >> $f
    echo "CONFIG_CLK_SUN8I_T113=y" >> $f
    echo "CONFIG_MMC_SUNXI=y" >> $f
    echo "CONFIG_ARM_PSCI=y" >> $f
    echo "CONFIG_SMP=y" >> $f
    echo "CONFIG_NR_CPUS=2" >> $f
    echo "CONFIG_CLK_IGNORE_UNUSED=y" >> $f
done

echo ">>> [Stage 3] 部署自定义 32位设备树..."
# 确保文件被拷贝到内核源码目录
mkdir -p target/linux/sunxi/files/arch/arm/boot/dts
if [ -f "files/$DTS_NAME.dts" ]; then
    cp "files/$DTS_NAME.dts" target/linux/sunxi/files/arch/arm/boot/dts/
    echo "OK: DTS deployed."
fi

echo ">>> [Stage 4] 核心手术：修改 Makefile 实现 zImage 和 DTB 的自动缝合..."
# 我们需要在 Image Builder 打包前，强行将 DTB 拼接到 zImage 后面
# 修改 target/linux/sunxi/image/Makefile，在生成 zImage 后立即执行拼接
SUNXI_MAKEFILE="target/linux/sunxi/image/Makefile"
if [ -f "$SUNXI_MAKEFILE" ]; then
    # 注入一个 Hook 命令：当内核准备好后，把我们的 dtb cat 到 zImage 末尾
    # 这个操作会在打包 boot.img 之前发生
    sed -i "/image_prepare:/a \	cat \$(KDIR)/zImage \$(KDIR)/image-$DTS_NAME.dtb > \$(KDIR)/zImage-dtb && mv \$(KDIR)/zImage-dtb \$(KDIR)/zImage" "$SUNXI_MAKEFILE"
    
    # 绕过 U-Boot 脚本检查
    sed -i '/image_prepare:/a \	mkdir -p $(STAGING_DIR_IMAGE) && touch $(STAGING_DIR_IMAGE)/sunxi-boot.scr' "$SUNXI_MAKEFILE"
    echo "OK: Makefile Hook injected."
fi

echo ">>> [Stage 5] 修正 MMC 块设备命名..."
# 确保所有镜像生成脚本中，识别为第0个控制器（mmcblk0）
sed -i 's/mmcblk1/mmcblk0/g' target/linux/sunxi/image/*.mk 2>/dev/null

echo ">>> [Final] diy-part2.sh 全自动适配完成。"
