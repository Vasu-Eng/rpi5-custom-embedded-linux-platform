savedcmd_arch/arm64/boot/dts/overlays/vc4-kms-dpi-hyperpixel4sq.dtbo := gcc -E -Wp,-MMD,arch/arm64/boot/dts/overlays/.vc4-kms-dpi-hyperpixel4sq.dtbo.d.pre.tmp -nostdinc -I ./scripts/dtc/include-prefixes -undef -D__DTS__ -x assembler-with-cpp -o arch/arm64/boot/dts/overlays/.vc4-kms-dpi-hyperpixel4sq.dtbo.dts.tmp arch/arm64/boot/dts/overlays/vc4-kms-dpi-hyperpixel4sq-overlay.dts ; ./scripts/dtc/dtc -@ -H epapr -O dtb -o arch/arm64/boot/dts/overlays/vc4-kms-dpi-hyperpixel4sq.dtbo -b 0 -iarch/arm64/boot/dts/overlays/ -i./scripts/dtc/include-prefixes -Wno-unique_unit_address -Wno-unit_address_vs_reg -Wno-avoid_unnecessary_addr_size -Wno-alias_paths -Wno-graph_child_address -Wno-interrupt_map -Wno-simple_bus_reg    -Wno-avoid_default_addr_size -Wno-gpios_property -Wno-i2c_bus_reg -Wno-interrupt_provider -Wno-interrupts_property -Wno-label_is_string -Wno-pci_device_bus_num -Wno-reg_format -Wno-spi_bus_reg -d arch/arm64/boot/dts/overlays/.vc4-kms-dpi-hyperpixel4sq.dtbo.d.dtc.tmp arch/arm64/boot/dts/overlays/.vc4-kms-dpi-hyperpixel4sq.dtbo.dts.tmp ; cat arch/arm64/boot/dts/overlays/.vc4-kms-dpi-hyperpixel4sq.dtbo.d.pre.tmp arch/arm64/boot/dts/overlays/.vc4-kms-dpi-hyperpixel4sq.dtbo.d.dtc.tmp > arch/arm64/boot/dts/overlays/.vc4-kms-dpi-hyperpixel4sq.dtbo.d

source_arch/arm64/boot/dts/overlays/vc4-kms-dpi-hyperpixel4sq.dtbo := arch/arm64/boot/dts/overlays/vc4-kms-dpi-hyperpixel4sq-overlay.dts

deps_arch/arm64/boot/dts/overlays/vc4-kms-dpi-hyperpixel4sq.dtbo := \
  arch/arm64/boot/dts/overlays/vc4-kms-dpi-hyperpixel.dtsi \
  scripts/dtc/include-prefixes/dt-bindings/gpio/gpio.h \
  scripts/dtc/include-prefixes/dt-bindings/pinctrl/bcm2835.h \

arch/arm64/boot/dts/overlays/vc4-kms-dpi-hyperpixel4sq.dtbo: $(deps_arch/arm64/boot/dts/overlays/vc4-kms-dpi-hyperpixel4sq.dtbo)

$(deps_arch/arm64/boot/dts/overlays/vc4-kms-dpi-hyperpixel4sq.dtbo):
