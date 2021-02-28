org 0x7c00

BaseOfStack equ 0x7c00
BaseOfLoader equ 0x9000
OffsetOfLoader equ 0x0100
RootDirSectors equ 14
SectorNoOfRootDirectory equ 19
SectorNoOfFAT1 equ 1
DetlaSectorNo equ 17


jmp short START
nop

BS_OEMName: db "Singular"
BPB_BytsPerSec: dw 512        ; 每扇区字节数
BPB_SecPerClus: db 1        ; 每簇多少扇区
BPB_RsvdSecCnt: dw 1        ; Boot 记录占用多少扇区
BPB_NumFATs: db 2        ; 共有多少 FAT 表
BPB_RootEntCnt: dw 224        ; 根目录文件数最大值
BPB_TotSec16: dw 2880        ; 逻辑扇区总数
BPB_Media: db 0xF0        ; 媒体描述符
BPB_FATSz16: dw 9        ; 每FAT扇区数
BPB_SecPerTrk: dw 18        ; 每磁道扇区数
BPB_NumHeads: dw 2        ; 磁头数(面数)
BPB_HiddSec: dd 0        ; 隐藏扇区数
BPB_TotSec32: dd 0        ; 如果 wTotalSectorCount 是 0 由这个值记录扇区数
BS_DrvNum: db 0        ; 中断 13 的驱动器号
BS_Reserved1: db 0        ; 未使用
BS_BootSig: db 29h        ; 扩展引导标记 (29h)
BS_VolID: dd 0        ; 卷序列号
BS_VolLab: db 'Singular.00'; 卷标, 必须 11 个字节
BS_FileSysType: db 'FAT12   '    ; 文件系统类型, 必须 8个字节 

START:
	mov ax, cs
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, BaseOfStack

	mov ax, 0x0600
	mov bx, 0x0700
	mov cx, 0
	mov dx, 0x184f
	int 0x10

	xor ax, ax
	xor dl, dl
	int 0x13

	mov word [wSectorNo], SectorNoOfRootDirectory
SEARCH_ROOT_DIR:
	cmp word [wRootDirSizeForLoop], 0
	jz NO_LOADER
	dec word [wRootDirSizeForLoop]
	mov ax, BaseOfLoader
	mov es, ax
	mov bx, OffsetOfLoader
	mov ax, [wSectorNo]
	mov cl, 1
	call READ_SECTOR
	mov si, LoaderFileName
	mov di, OffsetOfLoader
	cld
	mov dx, 16
SEARCH_FILE:
	cmp dx, 0
	jz NEXT_SECTOR
	dec dx
	mov cx, 11
CMP_FILENAME:
	cmp cx, 0
	jz FILENAME_FOUND
	dec cx
	lodsb
	cmp al, byte [es:di]
	jz GO_ON_CMP
	jmp DIFFERENT
GO_ON_CMP:
	inc di
	jmp CMP_FILENAME
DIFFERENT:
	and di, 0xffe0
	add di, 0x20
	mov si, LoaderFileName
	jmp SEARCH_FILE
NEXT_SECTOR:
	add word [wSectorNo], 1
	jmp SEARCH_ROOT_DIR
NO_LOADER:
	mov ax, MassageNoLoader
	mov cx, 10
	call DISPLAY
	jmp $
FILENAME_FOUND:
	mov ax, MassageBooting
	mov cx, 7
	call DISPLAY

	mov ax, RootDirSectors
	and di, 0xffe0
	add di, 0x1a
	mov cx, word [es:di]
	push cx
	add cx, ax
	add cx, DetlaSectorNo
	mov ax, BaseOfLoader
	mov es, ax
	mov bx, OffsetOfLoader
	mov ax, cx
GO_ON_LOADING_FILE:
	push ax
	push bx
	mov ah, 0xe
	mov al, '.'
	mov bl, 0xf
	int 0x10
	pop bx
	pop ax
	mov cl, 1
	call READ_SECTOR
	pop ax	
	call GET_FAT_ENTRY
	cmp ax, 0xfff
	jz FILE_LOADED
	push ax
	mov dx, RootDirSectors
	add ax, dx
	add ax, DetlaSectorNo
	add bx, [BPB_BytsPerSec]
	jmp GO_ON_LOADING_FILE
FILE_LOADED:
	mov ax, MassageLoader
	mov cx, 14
	call DISPLAY
	jmp BaseOfLoader:OffsetOfLoader

READ_SECTOR:
	push bp
	mov bp, sp
	sub esp, 2
	mov byte [bp - 2], cl
	push bx
	mov bl, [BPB_SecPerTrk]
	div bl
	inc ah
	mov cl, ah
	mov dh, al
	shr al, 1
	mov ch, al
	and dh, 1
	pop bx
	mov dl, [BS_DrvNum]
READING:
	mov ah, 2
	mov al, byte [bp - 2]
	int 0x13
	jc READING
	add esp, 2
	pop bp
	ret

GET_FAT_ENTRY:
	push es
	push bx
	push ax
	mov ax, BaseOfLoader
	sub ax, 0x100
	mov es, ax
	pop ax
	mov byte [bodd], 0
	mov bx, 3
	mul bx
	mov bx, 2
	div bx
	cmp dx, 0
	jz EVEN
	mov byte [bodd], 1
EVEN:
	xor dx, dx
	mov bx, [BPB_BytsPerSec]
	div bx
	push dx
	mov bx, 0
	add ax, SectorNoOfFAT1
	mov cl, 2
	call READ_SECTOR
	pop dx
	add bx, dx
	mov ax, [es:bx]
	cmp byte [bodd], 1
	jnz EVEN_2
	shr ax, 4
EVEN_2:
	and ax, 0xfff
GET_FAT_ENTRY_OK:
	pop bx
	pop es
	ret

DISPLAY:
	push bp
	push ax
	push ds
	push es
	push bx
	push dx
	mov bp, ax
	mov ax, ds
	mov es, ax
	mov ax, 0x1301
	mov bx, 0x7
	mov dl, 0
	int 0x10
	pop dx
	pop bx
	pop es
	pop ds
	pop ax
	pop bp
	ret

wRootDirSizeForLoop: dw RootDirSectors
wSectorNo: dw 0
bodd: db 0

LoaderFileName: db "LOADER  BIN", 0

MassageBooting: db "Booting"
MassageLoader: db "Now in Loader!"
MassageNoLoader: db "No Loader!"

times 510 - ($ - $$) db 0
dw 0xaa55
