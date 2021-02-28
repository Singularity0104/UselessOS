prepare: boot write

boot: boot.asm
	nasm -f bin boot.asm -o boot.bin

write: boot.bin
	dd if=boot.bin of=boot.img bs=512 count=1 conv=notrunc

mount:
	sudo mount -o loop boot.img ./file

umount:
	sudo umount ./file

run: prepare
	bochs -f bochsrc

recreate:
	rm boot.img
	dd if=/dev/zero of=./boot.img bs=512 count=2880

clean:
	rm boot.bin boot.img

