#ComputePrimes.bin: ComputePrimes.elf
#	arm-none-eabi-objcopy -O binary $< $@

ComputePrimes.elf: ComputePrimes.o memmap.ld
	arm-none-eabi-ld ComputePrimes.o -T memmap.ld -o $@

ComputePrimes.o: ComputePrimes.asm
	arm-none-eabi-as $< -march=armv6 -o $@
