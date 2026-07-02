savedcmd_arch/arm64/boot/dts/overlays/rpi-sense.dtbo := gcc -E -Wp,-MMD,arch/arm64/boot/dts/overlays/.rpi-sense.dtbo.d.pre.tmp -nostdinc -I ./scripts/dtc/include-prefixes -undef -D__DTS__ -x assembler-with-cpp -o arch/arm64/boot/dts/overlays/.rpi-sense.dtbo.dts.tmp arch/arm64/boot/dts/overlays/rpi-sense-overlay.dts ; ./scripts/dtc/dtc -@ -H epapr -O dtb -o arch/arm64/boot/dts/overlays/rpi-sense.dtbo -b 0 -iarch/arm64/boot/dts/overlays/ -i./scripts/dtc/include-prefixes -Wno-unique_unit_address -Wno-unit_address_vs_reg -Wno-avoid_unnecessary_addr_size -Wno-alias_paths -Wno-graph_child_address -Wno-interrupt_map -Wno-simple_bus_reg    -Wno-avoid_default_addr_size -Wno-gpios_property -Wno-i2c_bus_reg -Wno-interrupt_provider -Wno-interrupts_property -Wno-label_is_string -Wno-pci_device_bus_num -Wno-reg_format -Wno-spi_bus_reg -d arch/arm64/boot/dts/overlays/.rpi-sense.dtbo.d.dtc.tmp arch/arm64/boot/dts/overlays/.rpi-sense.dtbo.dts.tmp ; cat arch/arm64/boot/dts/overlays/.rpi-sense.dtbo.d.pre.tmp arch/arm64/boot/dts/overlays/.rpi-sense.dtbo.d.dtc.tmp > arch/arm64/boot/dts/overlays/.rpi-sense.dtbo.d

source_arch/arm64/boot/dts/overlays/rpi-sense.dtbo := arch/arm64/boot/dts/overlays/rpi-sense-overlay.dts

deps_arch/arm64/boot/dts/overlays/rpi-sense.dtbo := \

arch/arm64/boot/dts/overlays/rpi-sense.dtbo: $(deps_arch/arm64/boot/dts/overlays/rpi-sense.dtbo)

$(deps_arch/arm64/boot/dts/overlays/rpi-sense.dtbo):
