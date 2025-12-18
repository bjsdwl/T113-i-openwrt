#!/bin/bash
# Description: OpenWrt DIY script part 2 (Fix DTS Phandle Error)

# 变量定义
DTS_FILENAME="sun8i-t113-tronlong-minievm.dts"
DTS_NAME="sun8i-t113-tronlong-minievm"
TARGET_MK="target/linux/sunxi/image/cortexa7.mk"
KERNEL_DTS_DIR="target/linux/sunxi/files/arch/arm/boot/dts"
IMAGE_MAKEFILE="target/linux/sunxi/image/Makefile"

echo "-------------------------------------------------------"
echo "Starting DIY Part 2: Fix DTS Structure"
echo "-------------------------------------------------------"

# ==============================================================================
# 1. 检查必要文件
# ==============================================================================
if [ ! -f "files/u-boot-sunxi-with-spl.bin" ]; then
    echo "❌ Error: files/u-boot-sunxi-with-spl.bin NOT FOUND!"
    exit 1
fi

# ==============================================================================
# 2. 部署单体 DTS 文件 (结构重构：分离定义与连接)
# ==============================================================================
echo "[1/4] Generating & Deploying DTS..."
mkdir -p "$KERNEL_DTS_DIR"
mkdir -p target/linux/sunxi/dts

cat <<EOF > "files/$DTS_FILENAME"
// SPDX-License-Identifier: (GPL-2.0+ OR MIT)
/dts-v1/;

/* === 宏定义 === */
#define GIC_SPI 0
#define GIC_PPI 1
#define IRQ_TYPE_LEVEL_HIGH 4
#define IRQ_TYPE_LEVEL_LOW 8
#define GPIO_ACTIVE_HIGH 0
#define GPIO_ACTIVE_LOW 1
#define LED_COLOR_ID_GREEN 2
#define LED_FUNCTION_STATUS "status"

#define CLK_CPUX 0
#define CLK_APB1 13
#define CLK_LOSC 0
#define CLK_BUS_UART0 62
#define CLK_BUS_I2C0 68
#define CLK_BUS_I2C2 70
#define CLK_BUS_SPI0 74
#define CLK_BUS_EMAC 77
#define CLK_BUS_MMC0 59
#define CLK_BUS_OHCI0 99
#define CLK_BUS_OHCI1 100
#define CLK_BUS_EHCI0 101
#define CLK_BUS_EHCI1 102
#define CLK_BUS_TCON_LCD0 113
#define CLK_BUS_DE 28
#define CLK_BUS_MIPI_DSI 111
#define CLK_SPI0 72
#define CLK_MMC0 56
#define CLK_USB_OHCI0 97
#define CLK_USB_OHCI1 98
#define CLK_USB_PHY0 40
#define CLK_USB_PHY1 41
#define CLK_DE 27
#define CLK_TCON_LCD0 112
#define CLK_MIPI_DSI 110

#define RST_BUS_UART0 18
#define RST_BUS_I2C0 24
#define RST_BUS_I2C2 26
#define RST_BUS_SPI0 28
#define RST_BUS_EMAC 30
#define RST_BUS_MMC0 15
#define RST_BUS_OHCI0 42
#define RST_BUS_OHCI1 43
#define RST_BUS_EHCI0 44
#define RST_BUS_EHCI1 45
#define RST_BUS_TCON_LCD0 52
#define RST_BUS_DE 1
#define RST_BUS_MIPI_DSI 51
#define RST_USB_PHY0 40
#define RST_USB_PHY1 41

/ {
	model = "Tronlong TLT113-MiniEVM (NAND/HDMI)";
	compatible = "tronlong,tlt113-minievm", "allwinner,sun8i-t113s", "allwinner,sun8i";
	#address-cells = <1>;
	#size-cells = <1>;
	interrupt-parent = <&gic>;

	aliases {
		serial0 = &uart0;
		ethernet0 = &emac;
		spi0 = &spi0;
	};

	chosen { stdout-path = "serial0:115200n8"; };

	cpus {
		#address-cells = <1>;
		#size-cells = <0>;
		cpu0: cpu@0 { compatible = "arm,cortex-a7"; device_type = "cpu"; reg = <0>; clocks = <&ccu CLK_CPUX>; clock-names = "cpu"; };
		cpu1: cpu@1 { compatible = "arm,cortex-a7"; device_type = "cpu"; reg = <1>; clocks = <&ccu CLK_CPUX>; clock-names = "cpu"; };
	};

	osc24M: osc24M_clk { #clock-cells = <0>; compatible = "fixed-clock"; clock-frequency = <24000000>; clock-output-names = "osc24M"; };
	osc32k: osc32k_clk { #clock-cells = <0>; compatible = "fixed-clock"; clock-frequency = <32768>; clock-output-names = "osc32k"; };

	reg_vcc3v3: vcc3v3 { compatible = "regulator-fixed"; regulator-name = "vcc3v3"; regulator-min-microvolt = <3300000>; regulator-max-microvolt = <3300000>; regulator-always-on; };
	reg_usb1_vbus: usb1-vbus { compatible = "regulator-fixed"; regulator-name = "usb1-vbus"; regulator-min-microvolt = <5000000>; regulator-max-microvolt = <5000000>; regulator-enable-ramp-delay = <1000>; gpio = <&pio 1 12 GPIO_ACTIVE_HIGH>; enable-active-high; regulator-always-on; };

	hdmi_connector: connector {
		compatible = "hdmi-connector";
		type = "a";
		ddc-i2c-bus = <&i2c0>;
		port { 
			hdmi_con_in: endpoint { remote-endpoint = <&lt8912_out>; }; 
		};
	};

	soc {
		compatible = "simple-bus";
		#address-cells = <1>;
		#size-cells = <1>;
		ranges;

		gic: interrupt-controller@3021000 { compatible = "arm,gic-400"; reg = <0x03021000 0x1000>, <0x03022000 0x2000>, <0x03024000 0x2000>, <0x03026000 0x2000>; interrupts = <GIC_PPI 9 (GIC_PPI | IRQ_TYPE_LEVEL_HIGH)>; interrupt-controller; #interrupt-cells = <3>; };
		timer_arch: timer@3020000 { compatible = "arm,armv7-timer"; interrupts = <GIC_PPI 13 (GIC_PPI | IRQ_TYPE_LEVEL_LOW)>, <GIC_PPI 14 (GIC_PPI | IRQ_TYPE_LEVEL_LOW)>, <GIC_PPI 11 (GIC_PPI | IRQ_TYPE_LEVEL_LOW)>, <GIC_PPI 10 (GIC_PPI | IRQ_TYPE_LEVEL_LOW)>; };
		pmu { compatible = "arm,cortex-a7-pmu"; interrupts = <GIC_SPI 172 IRQ_TYPE_LEVEL_HIGH>, <GIC_SPI 173 IRQ_TYPE_LEVEL_HIGH>; interrupt-affinity = <&cpu0>, <&cpu1>; };

		pio: pinctrl@2000000 {
			compatible = "allwinner,sun20i-d1-pinctrl";
			reg = <0x02000000 0x800>;
			interrupts = <GIC_SPI 13 IRQ_TYPE_LEVEL_HIGH>, <GIC_SPI 14 IRQ_TYPE_LEVEL_HIGH>, <GIC_SPI 15 IRQ_TYPE_LEVEL_HIGH>, <GIC_SPI 16 IRQ_TYPE_LEVEL_HIGH>, <GIC_SPI 17 IRQ_TYPE_LEVEL_HIGH>, <GIC_SPI 18 IRQ_TYPE_LEVEL_HIGH>;
			clocks = <&ccu CLK_APB1>, <&osc24M>, <&osc32k>;
			clock-names = "apb", "hosc", "losc";
			gpio-controller; #gpio-cells = <3>; interrupt-controller; #interrupt-cells = <3>;

			uart0_pg_pins: uart0-pg-pins { pins = "PG17", "PG18"; function = "uart0"; };
			emac_rgmii_pins: emac-rgmii-pins { pins = "PG0", "PG1", "PG2", "PG3", "PG4", "PG5", "PG6", "PG7", "PG8", "PG9", "PG10", "PG12", "PG14", "PG15"; function = "emac"; drive-strength = <40>; };
			i2c0_pins: i2c0-pins { pins = "PB10", "PB11"; function = "twi0"; };
			i2c2_pins: i2c2-pins { pins = "PE12", "PE13"; function = "twi2"; };
			spi0_pins: spi0-pins { pins = "PC2", "PC4", "PC5", "PC6", "PC7"; function = "spi0"; };
			spi0_cs0_pin: spi0-cs0-pin { pins = "PC3"; function = "spi0"; };
			mmc0_pins: mmc0-pins { pins = "PF0", "PF1", "PF2", "PF3", "PF4", "PF5"; function = "mmc0"; drive-strength = <30>; bias-pull-up; };
			mmc0_cd_pin: mmc0-cd-pin { pins = "PF6"; function = "gpio_in"; bias-pull-up; };
		};

		ccu: clock-controller@2001000 { compatible = "allwinner,sun20i-d1-ccu"; reg = <0x02001000 0x1000>; clocks = <&osc24M>, <&osc32k>; clock-names = "hosc", "losc"; #clock-cells = <1>; #reset-cells = <1>; };

		uart0: serial@2500000 { compatible = "snps,dw-apb-uart"; reg = <0x02500000 0x400>; interrupts = <GIC_SPI 2 IRQ_TYPE_LEVEL_HIGH>; reg-shift = <2>; reg-io-width = <4>; clocks = <&ccu CLK_BUS_UART0>; resets = <&ccu RST_BUS_UART0>; status = "okay"; pinctrl-names = "default"; pinctrl-0 = <&uart0_pg_pins>; };
		
		i2c0: i2c@2502000 { compatible = "allwinner,sun20i-d1-i2c", "allwinner,sun8i-v536-i2c"; reg = <0x02502000 0x400>; interrupts = <GIC_SPI 11 IRQ_TYPE_LEVEL_HIGH>; clocks = <&ccu CLK_BUS_I2C0>; resets = <&ccu RST_BUS_I2C0>; #address-cells = <1>; #size-cells = <0>; status = "okay"; pinctrl-names = "default"; pinctrl-0 = <&i2c0_pins>; };
		
		/* 注意：这里只定义节点，不定义端口连接，避免循环引用 */
		i2c2: i2c@2502800 { 
			compatible = "allwinner,sun20i-d1-i2c", "allwinner,sun8i-v536-i2c"; reg = <0x02502800 0x400>; interrupts = <GIC_SPI 13 IRQ_TYPE_LEVEL_HIGH>; clocks = <&ccu CLK_BUS_I2C2>; resets = <&ccu RST_BUS_I2C2>; #address-cells = <1>; #size-cells = <0>; status = "okay"; pinctrl-names = "default"; pinctrl-0 = <&i2c2_pins>; 
			lt8912@48 {
				compatible = "lontium,lt8912b"; reg = <0x48>; reset-gpios = <&pio 4 11 GPIO_ACTIVE_LOW>; 
				ports {
					#address-cells = <1>; #size-cells = <0>;
					port@0 { reg = <0>; lt8912_in: endpoint { }; }; /* 连接在底部定义 */
					port@1 { reg = <1>; lt8912_out: endpoint { remote-endpoint = <&hdmi_con_in>; }; };
				};
			};
		};

		spi0: spi@4025000 { 
			compatible = "allwinner,sun20i-d1-spi", "allwinner,sun8i-h3-spi"; reg = <0x04025000 0x1000>; interrupts = <GIC_SPI 15 IRQ_TYPE_LEVEL_HIGH>; clocks = <&ccu CLK_BUS_SPI0>, <&ccu CLK_SPI0>; clock-names = "ahb", "mod"; resets = <&ccu RST_BUS_SPI0>; #address-cells = <1>; #size-cells = <0>; status = "okay"; pinctrl-names = "default"; pinctrl-0 = <&spi0_pins>, <&spi0_cs0_pin>;
			flash@0 {
				compatible = "spi-nand"; reg = <0>; spi-max-frequency = <40000000>;
				partitions {
					compatible = "fixed-partitions"; #address-cells = <1>; #size-cells = <1>;
					partition@0 { label = "u-boot"; reg = <0x000000 0x200000>; read-only; };
					partition@200000 { label = "ubi"; reg = <0x200000 0xfe00000>; };
				};
			};
		};

		emac: ethernet@4500000 {
			compatible = "allwinner,sun20i-d1-emac", "allwinner,sun8i-a83t-emac"; reg = <0x04500000 0x10000>; interrupts = <GIC_SPI 46 IRQ_TYPE_LEVEL_HIGH>; interrupt-names = "macirq"; clocks = <&ccu CLK_BUS_EMAC>; clock-names = "stmmaceth"; resets = <&ccu RST_BUS_EMAC>; reset-names = "stmmaceth"; syscon = <&ccu>; status = "okay";
			pinctrl-names = "default"; pinctrl-0 = <&emac_rgmii_pins>; phy-mode = "rgmii-id"; phy-handle = <&ext_rgmii_phy>;
			mdio {
				compatible = "snps,dwmac-mdio"; #address-cells = <1>; #size-cells = <0>;
				ext_rgmii_phy: ethernet-phy@0 { compatible = "ethernet-phy-ieee802.3-c22"; reg = <0>; reset-gpios = <&pio 6 13 GPIO_ACTIVE_LOW>; reset-assert-us = <10000>; reset-deassert-us = <150000>; motorcomm,clk-out-frequency-hz = <125000000>; motorcomm,keep-pll-enabled; motorcomm,auto-sleep-disabled; };
			};
		};

		mmc0: mmc@4020000 { compatible = "allwinner,sun20i-d1-mmc", "allwinner,sun7i-a20-mmc"; reg = <0x04020000 0x1000>; interrupts = <GIC_SPI 39 IRQ_TYPE_LEVEL_HIGH>; clocks = <&ccu CLK_BUS_MMC0>, <&ccu CLK_MMC0>; clock-names = "ahb", "mmc"; resets = <&ccu RST_BUS_MMC0>; reset-names = "ahb"; max-frequency = <150000000>; status = "okay"; pinctrl-names = "default"; pinctrl-0 = <&mmc0_pins>; vmmc-supply = <&reg_vcc3v3>; bus-width = <4>; cd-gpios = <&pio 5 6 GPIO_ACTIVE_LOW>; };

		usb_otg: usb@4101000 { compatible = "allwinner,sun8i-a33-musb"; reg = <0x04101000 0x0400>; clocks = <&ccu CLK_BUS_OHCI0>, <&ccu CLK_BUS_EHCI0>, <&ccu CLK_USB_OHCI0>; resets = <&ccu RST_BUS_OHCI0>, <&ccu RST_BUS_EHCI0>; interrupts = <GIC_SPI 32 IRQ_TYPE_LEVEL_HIGH>; interrupt-names = "mc"; phys = <&usbphy 0>; phy-names = "usb"; status = "okay"; dr_mode = "host"; };
		usbphy: phy@4101400 { compatible = "allwinner,sun20i-d1-usb-phy"; reg = <0x04101400 0x14>, <0x04101800 0x4>, <0x04200800 0x4>; reg-names = "phy_ctrl", "pmu0", "pmu1"; clocks = <&ccu CLK_USB_PHY0>, <&ccu CLK_USB_PHY1>; clock-names = "usb0_phy", "usb1_phy"; resets = <&ccu RST_USB_PHY0>, <&ccu RST_USB_PHY1>; reset-names = "usb0_reset", "usb1_reset"; status = "okay"; usb1_vbus-supply = <&reg_usb1_vbus>; };
		ehci0: usb@4101800 { compatible = "allwinner,sun20i-d1-ehci", "generic-ehci"; reg = <0x04101800 0x100>; interrupts = <GIC_SPI 33 IRQ_TYPE_LEVEL_HIGH>; clocks = <&ccu CLK_BUS_EHCI0>, <&ccu CLK_BUS_OHCI0>; resets = <&ccu RST_BUS_EHCI0>, <&ccu RST_BUS_OHCI0>; phys = <&usbphy 0>; phy-names = "usb"; status = "okay"; };
		ohci0: usb@4101c00 { compatible = "allwinner,sun20i-d1-ohci", "generic-ohci"; reg = <0x04101c00 0x100>; interrupts = <GIC_SPI 34 IRQ_TYPE_LEVEL_HIGH>; clocks = <&ccu CLK_BUS_OHCI0>, <&ccu CLK_USB_OHCI0>; resets = <&ccu RST_BUS_OHCI0>; phys = <&usbphy 0>; phy-names = "usb"; status = "okay"; };
		ehci1: usb@4200800 { compatible = "allwinner,sun20i-d1-ehci", "generic-ehci"; reg = <0x04200800 0x100>; interrupts = <GIC_SPI 35 IRQ_TYPE_LEVEL_HIGH>; clocks = <&ccu CLK_BUS_EHCI1>, <&ccu CLK_BUS_OHCI1>; resets = <&ccu RST_BUS_EHCI1>, <&ccu RST_BUS_OHCI1>; phys = <&usbphy 1>; phy-names = "usb"; status = "okay"; };
		ohci1: usb@4200c00 { compatible = "allwinner,sun20i-d1-ohci", "generic-ohci"; reg = <0x04200c00 0x100>; interrupts = <GIC_SPI 36 IRQ_TYPE_LEVEL_HIGH>; clocks = <&ccu CLK_BUS_OHCI1>, <&ccu CLK_USB_OHCI1>; resets = <&ccu RST_BUS_OHCI1>; phys = <&usbphy 1>; phy-names = "usb"; status = "okay"; };

		display_engine: display-engine { compatible = "allwinner,sun20i-d1-de2e"; reg = <0x05000000 0x10000>, <0x05100000 0x10000>, <0x05200000 0x10000>, <0x05300000 0x10000>; reg-names = "blender", "ui", "top", "scaler"; clocks = <&ccu CLK_BUS_DE>, <&ccu CLK_DE>; clock-names = "bus", "mod"; resets = <&ccu RST_BUS_DE>; interrupts = <GIC_SPI 94 IRQ_TYPE_LEVEL_HIGH>; status = "okay"; 
			display_engine_output: output { reg = <0>; port { #address-cells = <1>; #size-cells = <0>; display_engine_out_tcon0: endpoint@0 { reg = <0>; remote-endpoint = <&tcon_lcd0_in_display_engine>; }; }; }; };
		
		tcon_lcd0: lcd-controller@5461000 { compatible = "allwinner,sun20i-d1-tcon-lcd"; reg = <0x05461000 0x1000>; interrupts = <GIC_SPI 95 IRQ_TYPE_LEVEL_HIGH>; clocks = <&ccu CLK_BUS_TCON_LCD0>, <&ccu CLK_TCON_LCD0>; clock-names = "ahb", "tcon"; resets = <&ccu RST_BUS_TCON_LCD0>, <&ccu RST_BUS_LVDS0>; reset-names = "lcd", "lvds"; status = "okay";
			ports { #address-cells = <1>; #size-cells = <0>;
				tcon_lcd0_in: port@0 { reg = <0>; tcon_lcd0_in_display_engine: endpoint { remote-endpoint = <&display_engine_out_tcon0>; }; };
				tcon_lcd0_out: port@1 { reg = <1>; tcon_lcd0_out_dsi: endpoint { }; }; /* 连接在底部定义 */
			};
		};

		dsi: dsi@5450000 {
			compatible = "allwinner,sun20i-d1-mipi-dsi";
			reg = <0x05450000 0x1000>;
			interrupts = <GIC_SPI 98 IRQ_TYPE_LEVEL_HIGH>;
			clocks = <&ccu CLK_BUS_MIPI_DSI>, <&ccu CLK_MIPI_DSI>;
			clock-names = "bus", "mod";
			resets = <&ccu RST_BUS_MIPI_DSI>;
			phys = <&dphy>;
			phy-names = "dphy";
			status = "okay";
			ports {
				#address-cells = <1>;
				#size-cells = <0>;
				dsi_in: port@0 {
					reg = <0>;
					dsi_in_tcon_lcd0: endpoint { }; /* 连接在底部定义 */
				};
				dsi_out: port@1 {
					reg = <1>;
					dsi_out_bridge: endpoint { }; /* 连接在底部定义 */
				};
			};
		};

		dphy: d-phy@5460000 { compatible = "allwinner,sun20i-d1-mipi-dphy"; reg = <0x05460000 0x1000>; clocks = <&ccu CLK_BUS_MIPI_DSI>, <&ccu CLK_MIPI_DSI>; clock-names = "bus", "mod"; resets = <&ccu RST_BUS_MIPI_DSI>; status = "okay"; #phy-cells = <0>; };
	};
};

/* ============================================================================
 * 第三部分：外部连接 (Links)
 * 在所有节点定义完成后，最后进行连接，消除“节点不存在”错误
 * ============================================================================
 */

/* TCON 输出 -> DSI 输入 */
&tcon_lcd0_out_dsi { remote-endpoint = <&dsi_in_tcon_lcd0>; };
&dsi_in_tcon_lcd0 { remote-endpoint = <&tcon_lcd0_out_dsi>; };

/* DSI 输出 -> LT8912B 输入 */
&dsi_out_bridge { remote-endpoint = <&lt8912_in>; };
&lt8912_in { remote-endpoint = <&dsi_out_bridge>; };

EOF

# 复制到 Kernel Overlay 和标准目录
cp "files/$DTS_FILENAME" "$KERNEL_DTS_DIR/"
cp "files/$DTS_FILENAME" target/linux/sunxi/dts/
echo "  -> Success: DTS deployed."


# ==============================================================================
# 3. 手动生成 boot.scr
# ==============================================================================
echo "  -> Generating boot.scr..."
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
    echo "❌ Error: Failed to generate boot.scr!"
    exit 1
fi

# ==============================================================================
# 4. 修改分区偏移 (32MB Offset)
# ==============================================================================
echo "  -> Patching partition alignment..."
if [ -f "$GEN_IMAGE_SCRIPT" ]; then
    sed -i 's/-l 1024/-l 65536/g' "$GEN_IMAGE_SCRIPT"
    echo "  -> Success: Partition start moved to 32MB."
else
    echo "❌ Error: gen_sunxi_sdcard_img.sh not found!"
    exit 1
fi

# ==============================================================================
# 5. [核心] 注入机型定义 (流水线强制复制)
# ==============================================================================
if [ ! -f "$TARGET_MK" ]; then
    echo "❌ Error: Target Makefile not found!"
    exit 1
fi

cat <<EOF >> "$TARGET_MK"

# 定义一个构建命令：install-tronlong-files
# 它的作用是：创建目录 -> 复制 U-Boot -> 复制 boot.scr
define Build/install-tronlong-files
	\$(INSTALL_DIR) \$(STAGING_DIR_IMAGE)
	\$(CP) \$(TOPDIR)/files/u-boot-sunxi-with-spl.bin \$(STAGING_DIR_IMAGE)/tronlong_tlt113-minievm-u-boot-with-spl.bin
	\$(CP) \$(TOPDIR)/files/boot.scr \$(STAGING_DIR_IMAGE)/tronlong_tlt113-minievm-boot.scr
endef

define Device/tronlong_tlt113-minievm
  \$(Device/sunxi-img)
  DEVICE_VENDOR := Tronlong
  DEVICE_MODEL := TLT113-MiniEVM (NAND/HDMI)
  DEVICE_DTS := $DTS_NAME
  DEVICE_UBOOT := nanopi_neo
  
  # 修改镜像生成流水线
  IMAGE/sdcard.img.gz := \\
      install-tronlong-files | \\
      sunxi-sdcard | append-metadata | gzip
      
  SUPPORTED_DEVICES := tronlong,tlt113-minievm
endef
TARGET_DEVICES += tronlong_tlt113-minievm
EOF

echo "  -> Success: Device definition with pipeline hook injected."
echo "DIY Part 2 Finished Successfully."
