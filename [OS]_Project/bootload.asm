; ==================================================================
; bootload.asm
; ==================================================================
; The Wagner Operating System Bootloader
; Written by David Wagner
; Copyright (C) 2017 
;
; Based on a free boot loader by E Dehling. 
; This program scans the FAT12 floppy file system for KERNEL.BIN. 
; If KERNEL.BIN is found, then it executes the binary program.
; The assembled binary program must grow no larger than 512 bytes (one sector)
; The final two bytes of the binary should be the boot signature (AA55h). 
; In FAT12 a cluster is the same size as a sector: 512 bytes.
; ==================================================================

	BITS 16

	jmp short bootloader_init	; Jump past disk description table
	nop				; Space before the table

;*********************************************************************
; This is the disk description table.
; If this data is in the boot sector, then the file system is a valid 
; FAT12 floppy disk.  Some of this data is used by the bootloader code.
; These values conform to the size of an IBM for 1.44 MB, 3.5" diskette
;*********************************************************************

OEMLabel		db "WAGNEROS"	; Disk label
BytesPerSector		dw 512		; Bytes per sector
SectorsPerCluster	db 1		; Sectors per cluster
ReservedForBoot		dw 1		; Reserved sectors for boot record
NumberOfFats		db 2		; Number of copies of the FAT
NumRootDirEntries	dw 224		; Number of entries in root dir
					; (224 * 32 = 7168 = 14 sectors to read)
LogicalSectors		dw 2880		; Number of logical sectors
MediumByte		db 0F0h		; Medium descriptor byte
SectorsPerFat		dw 9		; Sectors per FAT
SectorsPerTrack		dw 18		; Sectors per track (36/cylinder)
Sides			dw 2		; Number of sides/heads
HiddenSectors		dd 0		; Number of hidden sectors
LargeSectors		dd 0		; Number of LBA sectors
DriveNo			dw 0		; Drive No: 0
Signature		db 41		; Drive signature: 41 for floppy
VolumeID		dd 00000000h	; Volume ID: any number
VolumeLabel		db "WAGNEROS   "; Volume Label: any 11 chars
FileSystem		db "FAT12   "	; File system type: don't change!


;*********************************************************************
; Memory Constants
;*********************************************************************

%define DataSegmentStart 07C0h	; The Data Segment starts at 07C0h in memory
%define DataSegmentSize 544 	; The Data Segment Size is 512 byte bootloader + 32 byte heap = 544

%define StackSize 4096  	; Create 4 kilobytes of memory for the stack

%define KernelStart 2000h	; Loading the Kernel at segment address 2000h

;*********************************************************************
; Disk Constants
;*********************************************************************

%define RootDirStartSector 19	; The Root directory starts at logical sector 19
%define RootDirNumSectors 14	; The Root directory occupies 14 sectors

%define RootDirEntrySize 32	; An entry of the directory occupies 32 bytes

%define FilenameLength 11	; One Filename occupies 8+3 = 11 characters

%define SectorSize 512		; Sectors have 512 bytes

%define EndOfFileSignature 0FF8h ; FF8h = end of file marker in FAT12

%define FatStartSector	1	; The 1st FAT begins in Sector 1
%define FatNumSectors 9		; The 1st FAT occupies 9 sectors


;*********************************************************************
; Global Variables
;*********************************************************************

	bootDevice		db 0 	; Boot device number
	kernel_cluster_num	dw 0 	; Cluster of the file we want to load
	kernel_memory_pointer	dw 0 	; Pointer into memory, where the kernel will be loaded

;	logicalSector		dw 0	; The logical Sector number


;*********************************************************************
; Local Variable Space 
;*********************************************************************

; ------------------------------------------------------------------
; Byte sized local variable space

	LocalByteVar1		db 0	; Local Byte Variable
	LocalByteVar2		db 0	; Local Byte Variable
	LocalByteVar3		db 0	; Local Byte Variable
	LocalByteVar4		db 0	; Local Byte Variable
	LocalByteVar5		db 0	; Local Byte Variable
	LocalByteVar6		db 0	; Local Byte Variable
	LocalByteVar7		db 0	; Local Byte Variable
	LocalByteVar8		db 0	; Local Byte Variable
	LocalByteVar9		db 0	; Local Byte Variable
	LocalByteVar10		db 0	; Local Byte Variable


; ------------------------------------------------------------------
; Word sized local variable space
;
; Instead of creating a separate space for word sized variables, we 
; reuse the byte sized variable space.  Two byte sized variables may 
; be replaced with one word sized variable.

%define LocalWordVar1	LocalByteVar9	; Local Word Variable 1 occupies bytes 9 and 10
%define LocalWordVar2	LocalByteVar7	; Local Word Variable 2 occupies bytes 7 and 8
%define LocalWordVar3	LocalByteVar5	; Local Word Variable 3 occupies bytes 5 and 6
%define LocalWordVar4	LocalByteVar3	; Local Word Variable 4 occupies bytes 3 and 4
%define LocalWordVar5	LocalByteVar1	; Local Word Variable 5 occupies bytes 1 and 2

;  The above define statements replace the following declarations

;	LocalWordVar1		dw 0	; Local Variable
;	LocalWordVar2		dw 0	; Local Variable
;	LocalWordVar3		dw 0	; Local Variable
;	LocalWordVar4		dw 0	; Local Variable
;	LocalWordVar5		dw 0	; Local Variable

; ------------------------------------------------------------------
;	Local Variable Set 1
;	Used while loading from disk to memory
; ------------------------------------------------------------------
;	numSectors		db 0	; How many sectors
;	logicalDiskSector	dw 0	; Where on disk is the source sector
;	destinationSegment	dw 0	; What is the source segment base address in memory
;	destinationOffset	dw 0	; Where is the offset in memory of the destination 

;	trackNum		dw 0	; Disk Track Number
;	sectorInTrack		db 0	; Disk Sector Number within a track
;	headNum			db 0	; Disk Head Number
;	cylinderNum		db 0	; Disk Cylinder Number

%define	numSectors		LocalByteVar1
%define	logicalDiskSector	LocalWordVar1
%define	destinationSegment	LocalWordVar2
%define	destinationOffset	LocalWordVar3

%define	trackNum		LocalWordVar4
%define	sectorInTrack		LocalByteVar2
;%define	headNum			LocalByteVar3
;%define	cylinderNum		LocalByteVar4

; ------------------------------------------------------------------
;	Local Variable Set 2
;	Used while searching for kernel file in the root directory
; ------------------------------------------------------------------
;	String1Segment		dw 0	; Segment of the first string to be compared
;	String1Start		dw 0	; Location of the first string to be compared
;	String2Segment		dw 0	; Segment of the second string to be compared
;	String2Start		dw 0	; Location of the second string to be compared
;	StringLength		dw 0	; Length of the strings to be compared

%define	StringLength		LocalWordVar1
%define	String1Start		LocalWordVar2
%define	String2Start		LocalWordVar3
%define	String1Segment		LocalWordVar4
%define	String2Segment		LocalWordVar5
; ------------------------------------------------------------------


;*********************************************************************
;*********************************************************************
; Start of Bootloader Program
;*********************************************************************
;*********************************************************************

; When the bootloader starts, the program counter (PC) points to 07C0h and 
; DL is the disk number.  All other registers are undefined.  Memory looks like this:
;
; -------------- <------ 0000h
; |            |
; |            |
; |            |
; -------------- <------ 07C0h <------ PC
; |            |
; | Bootloader |
; |            |
; -------------- <------ 09C0h <------ heap_start
; |            |

;*********************************************************************
; Initialize the segment registers, stack pointer, and drive parameters
;*********************************************************************

bootloader_init:

	; ------------------------------------------------------------------
	; Initialize the Data Segment Register and Extra Segement Register
	; ------------------------------------------------------------------

	mov ax, DataSegmentStart
	mov ds, ax			; Data Segment will always start at 07C0h
	mov es, ax			; Extra Segment starts 07C0h but will change later

	; ------------------------------------------------------------------
	; Initialize the Stack Segment Register and Stack Pointer
	; ------------------------------------------------------------------

	add ax, DataSegmentSize		; Calculate 07C0h + 544 = 09E0h = End of Data Segment = Start of Stack

	cli				; Disable interrupts while changing stack
	mov ss, ax			; Stack Segment starts after end Data Segment
	mov sp, StackSize		; Stack Pointer points to end of 4K stack
	sti				; Restore interrupts

	; ------------------------------------------------------------------
	; Initialize the drive parameters
	; ------------------------------------------------------------------

	; DL should contain the Boot Device Number assigned by the BIOS/Firmware
	; NOTE: A few early BIOSes are reported to improperly set DL
	; See http://en.wikipedia.org/wiki/Master_boot_record#BIOS_to_MBR_interface

	; If Boot Device is Zero then Keep original Drive Parameters
;	cmp dl, 0
;	je bootloader_main

	; If Boot Device is not Zero Get New Drive Parameters

	call get_new_drive_parameters

;	jmp short bootloader_main	; Removed to save space

;*********************************************************************

; After Initialization, memory looks like this:
;
; -------------- <------ 0000h
; |            |
; |            |
; |            |
; -------------- <------ 07C0h <------ DS <------ ES <------ Data Segement Start
; |            |
; | Bootloader | <------ PC
; |            |
; -------------- <------ 09C0h <------ DS + 512 <------ heap_start
; |            |
; |    Heap    |
; |            |
; -------------- <------ 09E0h <------ SS <------ Stack Segement Start
; |            |
; |   Stack    |
; |            |
; -------------- <------ 19E0h <------ SS + SP <------ Stack Pointer
; |            |

;*********************************************************************
; Main bootloader code
;*********************************************************************

bootloader_main:

	; ------------------------------------------------------------------
	; Find the location of the kernel file
	; ------------------------------------------------------------------
	call load_root_directory_to_heap
	call find_kernel_file_in_root_directory

	; ------------------------------------------------------------------
	; Load the kernel file into memory
	; ------------------------------------------------------------------
	call load_fat_to_heap
	call load_kernel_file_to_kernel_memory

	; ------------------------------------------------------------------
	; Run the Kernel
	; ------------------------------------------------------------------

	mov dl, byte [bootDevice]	; Provide the kernel with the boot device number
	jmp KernelStart:0000h		; Jump to first instruction of loaded kernel!

;*********************************************************************
;*********************************************************************
; End of Main Bootloader Program
;*********************************************************************
;*********************************************************************

; After the bootloader finishes, memory looks like this:
;
; -------------- <------ 0000h
; |            |
; |            |
; |            |
; -------------- <------ 07C0h <------ DS <------ Data Segement Start
; |            |
; | Bootloader |
; |            |
; -------------- <------ 09C0h <------ heap_start
; |            |
; |    Heap    |
; |            |
; -------------- <------ 09E0h <------ SS <------ Stack Segement Start
; |            |
; |   Stack    |
; |            |
; -------------- <------ 19E0h <------ SS + SP <------ Stack Pointer
; |            |
; -------------- <------ 2000h <------ ES <------ Kernel Start <------ PC
; |            |
; |   Kernel   |
; |            |
; -------------- 

;*********************************************************************
;*********************************************************************
; SUBROUTINES
;*********************************************************************
;*********************************************************************


; ------------------------------------------------------------------
; ------------------------------------------------------------------
; LOAD FROM DISK TO HEAP MEMORY
; ------------------------------------------------------------------
; ------------------------------------------------------------------

; ------------------------------------------------------------------
;	Local Variable Set 1
;	Used while loading from disk to memory
; ------------------------------------------------------------------
;	numSectors		db 0	; How many sectors
;	logicalDiskSector	dw 0	; Where on disk is the source sector
;	destinationSegment	dw 0	; What is the source segment base address in memory
;	destinationOffset	dw 0	; Where is the offset in memory of the destination 

;	trackNum		dw 0	; Disk Track Number
;	sectorInTrack		db 0	; Disk Sector Number within a track
;	headNum			db 0	; Disk Head Number
;	cylinderNum		db 0	; Disk Cylinder Number
; ------------------------------------------------------------------


;*********************************************************************
; Load the Root Directory into Heap Memory
;*********************************************************************

load_root_directory_to_heap:
;	mov eax, 0			; Needed for some older BIOSes

; First, we need to load the root directory from the disk. Technical details:
; Start of root = ReservedForBoot + NumberOfFats * SectorsPerFat = logical 19
; Number of root = NumRootDirEntries * 32 bytes/entry / 512 bytes/sector = 14 sectors/entry
; Start of user data = (start of root) + (number of root) = logical 33

; Ready to read first block of data

	mov word [logicalDiskSector], RootDirStartSector	; Root dir starts at logical sector 19
	mov byte [numSectors], RootDirNumSectors		; And read 14 sectors of root dir
	jmp short load_disk_to_heap

;*********************************************************************
; Load the File Allocation Table (FAT) into Heap Memory
;*********************************************************************

load_fat_to_heap:
	mov word [logicalDiskSector], FatStartSector	; Sector 1 = first sector of first FAT
	mov byte [numSectors], FatNumSectors		; All 9 sectors of 1st FAT
;	jmp short load_disk_to_heap			; Removed to save space

;*********************************************************************
; Load sectors from disk to the heap
; ------------------------------------------------------------------
; IN: logicalDiskSector = Source Sector
;     numSectors = Number of sectors
;*********************************************************************

load_disk_to_heap:
	; ------------------------------------------------------------------
	; Set Destination to the heap
	; Set ES:BX to point to the heap (see end of code)
	; ------------------------------------------------------------------
	mov word [destinationSegment], ds
	mov word [destinationOffset], heap_start

;	jmp load_disk_sectors_to_memory
	call load_disk_sectors_to_memory
	ret

; ------------------------------------------------------------------
; ------------------------------------------------------------------
; FIND THE KERNEL FILE 
; ------------------------------------------------------------------
; ------------------------------------------------------------------

; ------------------------------------------------------------------
;	Local Variable Set 2
;	Used while searching for kernel file in the root directory
; ------------------------------------------------------------------
;	String1Segment		dw 0	; Segment of the first string to be compared
;	String1Start		dw 0	; Location of the first string to be compared
;	String2Segment		dw 0	; Segment of the second string to be compared
;	String2Start		dw 0	; Location of the second string to be compared
;	StringLength		dw 0	; Length of the strings to be compared
; ------------------------------------------------------------------

;*********************************************************************
; Find the Kernel file in the Root Directory
; ------------------------------------------------------------------
; OUT: kernel_cluster_num = The first cluster of the kernel file
;*********************************************************************

find_kernel_file_in_root_directory:

	; ------------------------------------------------------------------
	; Prepare to compare the first filename in the root directory
	; with the name of the kernel file
	; ------------------------------------------------------------------

;	mov word [String1Segment], ds			; The root directory is loaded in this segment
	mov word [String1Start], heap_start		; The first filename is loaded at the start of the heap
;	mov word [String2Segment], ds			; The kernel filename is a string in this segment
	mov word [String2Start], kernel_filename	; The Kernel filename is "KERNEL  BIN"
	mov word [StringLength], FilenameLength		; Filenames are 11 characters

	mov dx, word [NumRootDirEntries]		; Check all 224 files

	; ------------------------------------------------------------------
	; Check if the Filename is the same as the name of the Kernel File
	; ------------------------------------------------------------------

check_if_filename_is_kernel_filename:

	call compare_strings

	; ------------------------------------------------------------------
	; If Kernel File is found, store its first cluster number and return
	; ------------------------------------------------------------------

	je store_first_kernel_cluster_and_return

	; ------------------------------------------------------------------
	; If this is not the kernel file, advance to the next file and repeat
	; ------------------------------------------------------------------

	call advance_to_next_file_in_root_dir
	jmp short check_if_filename_is_kernel_filename

	; ------------------------------------------------------------------
	; Store the first cluster number of the kernel file to memory and return
	; ------------------------------------------------------------------

store_first_kernel_cluster_and_return:
	mov ax, word [es:di+0Fh]	; Offset 11 + 15 = 26, contains first cluster number
	mov word [kernel_cluster_num], ax
	ret

;*********************************************************************
; Advance to the next file in the root directory
; ------------------------------------------------------------------
; IN:  String1Start = Start of old filename 
;      DX = Old number of files remaining 
; OUT: String1Start = Start of new filename 
;      DX = New number of files remaining
;*********************************************************************

advance_to_next_file_in_root_dir:

	; ------------------------------------------------------------------
	; Advance to the next entry in the root directory (32 bytes per entry)
	; ------------------------------------------------------------------

	add word [String1Start], RootDirEntrySize 

	; ------------------------------------------------------------------
	; Decrement the number of remaining files.
	; If dx is 0 then we have checked every file so the kernel file is missing
	; ------------------------------------------------------------------

	dec dx					; One less file to check

	; ------------------------------------------------------------------
	; If all files have been checked, then throw a "File Not Found" error 
	; ------------------------------------------------------------------

	jna near throw_file_not_found_error

	; ------------------------------------------------------------------
	; If there are more files then return
	; ------------------------------------------------------------------

	ret


; ------------------------------------------------------------------
; ------------------------------------------------------------------
; LOAD THE KERNEL FILE
; ------------------------------------------------------------------
; ------------------------------------------------------------------

; ------------------------------------------------------------------
;	Local Variable Set 1
;	Used while loading from disk to memory
; ------------------------------------------------------------------
;	numSectors		db 0	; How many sectors
;	logicalDiskSector	dw 0	; Where on disk is the source sector
;	destinationSegment	dw 0	; What is the source segment base address in memory
;	destinationOffset	dw 0	; Where is the offset in memory of the destination 

;	trackNum		dw 0	; Disk Track Number
;	sectorInTrack		db 0	; Disk Sector Number within a track
;	headNum			db 0	; Disk Head Number
;	cylinderNum		db 0	; Disk Cylinder Number
; ------------------------------------------------------------------

;*********************************************************************
; Load the Kernel from disk into Kernel Memory
; ------------------------------------------------------------------
; IN:  kernel_cluster_num = The first cluster of the kernel file
;      kernel_memory_pointer = The start of kernel memory
;*********************************************************************

load_kernel_file_to_kernel_memory:

	; ------------------------------------------------------------------
	; Load one cluster of the kernel from disk to memory 
	; ------------------------------------------------------------------

	call load_one_disk_cluster_to_kernel_memory

	; ------------------------------------------------------------------
	; Advance to the next kernel cluster number on the disk
	; ------------------------------------------------------------------

	call advance_to_next_kernel_cluster_number

	; ------------------------------------------------------------------
	; Advance the kernel memory pointer by one cluster/sector length
	; ------------------------------------------------------------------

	add word [kernel_memory_pointer], SectorSize	; Increase kernel pointer 1 sector length

	; ------------------------------------------------------------------
	; If this was not the last cluster of the file then repeat
	; ------------------------------------------------------------------

	cmp ax, EndOfFileSignature		; FF8h = end of file marker in FAT12
	jb load_kernel_file_to_kernel_memory

	; ------------------------------------------------------------------
	; If this fat entry contains the end of file marker then return
	; ------------------------------------------------------------------

	ret

;*********************************************************************
; Advance the cluster number to the next kernel cluster
; ------------------------------------------------------------------
; IN : kernel_cluster_num = the old kernel cluster number
; OUT: kernel_cluster_num = the new kernel cluster number
;*********************************************************************

advance_to_next_kernel_cluster_number:


	; ------------------------------------------------------------------
	; In FAT 12, table entries occupy 12 bits. 
	; Convert the cluster number which counts by 12-bit FAT entries
	; to the byte offset, which counts by 8-bit bytes
	; AX = (3/2) * Cluster number = Byte offset of cluster in FAT
	; DX = Cluster number % 2
	; ------------------------------------------------------------------

	mov ax, [kernel_cluster_num] ; AX = Cluster number, counting by 12 bits
	mov bx, 3	; BX = 3
	mul bx		; AX = 3 * Cluster number ; DX = Cluster number % 2 
	mov bx, 2	; BX = 2
	div bx		; AX = (3/2) * Cluster number ; DX = Cluster number % 2 

	; ------------------------------------------------------------------
	; AX = The 12 bit FAT entry containing the next cluster number
	;      and 4 extraneous bits from a neighboring FAT entry
	; ------------------------------------------------------------------

	mov si, heap_start		; SI = FAT is stored in the heap
	add si, ax			; Add the Byte offset in FAT of the 12 bit entry
	mov ax, word [ds:si]		; Copy a 16 bit word from the FAT into AX

	; ------------------------------------------------------------------
	; Remove the extraneous bits in AX
	; ------------------------------------------------------------------

	call remove_extraneous_bits_from_AX

	; ------------------------------------------------------------------
	; Store the Cluster number of the next Kernel Cluster to memory
	; ------------------------------------------------------------------

store_next_kernel_cluster_number:
	mov word [kernel_cluster_num], ax	; Store next kernel cluster num in memory
	ret


;*********************************************************************
; Remove extraneous bits from AX
; ------------------------------------------------------------------
; IN : AX = Word with extraneous bits
;      DX = 0 or 1 (Cluster Number % 2)
; OUT: AX = Word without extraneous bits
;*********************************************************************

	; The FAT 12 entry might occuy a byte and 4 bits of the next byte 
	; or the last 4 bits of one byte and then the subsequent byte!

remove_extraneous_bits_from_AX:
	; ------------------------------------------------------------------
	; Determine if the cluster number is odd or even
	; ------------------------------------------------------------------

	or dx, dx	; If DX = 0 then kernel_cluster_num is even; if DX = 1 then it's odd
	jz even		

odd:
	; ------------------------------------------------------------------
	; Remove extraneous last 4 bits in AX from an odd FAT entry and return
	; ------------------------------------------------------------------

	shr ax, 4	; Cluster number is Odd, so shift out the last 4 bits
	ret		; of the 16 bit word (they belong to another entry)

even:
	; ------------------------------------------------------------------
	; Remove extraneous first 4 bits in AX from an even FAT entry and return
	; ------------------------------------------------------------------

	and ax, 0FFFh	; Cluster number is even, so drop the first 4 bits
	ret		; of the 16 bit word (they belong to another entry)


;*********************************************************************
; Load a cluster from disk to kernel memory 
; ------------------------------------------------------------------
; IN : kernel_cluster_num = source cluster number
;      kernel_memory_pointer = destination in memory
;*********************************************************************

load_one_disk_cluster_to_kernel_memory:

	; ------------------------------------------------------------------
	; Convert Cluster Number to Logical Disk Sector Number
	; ------------------------------------------------------------------
	; IN : kernel_cluster_num = source disk cluster number
	; OUT: logicalDiskSector = source disk sector number
	; ------------------------------------------------------------------

; ------------------------------------------------------------------
; Now we must load the FAT from the disk. Here's how we find out where it starts:
; FAT cluster 0 = media descriptor = 0F0h
; FAT cluster 1 = filler cluster = 0FFh
; Cluster start = ((cluster number) - 2) * SectorsPerCluster + (start of user)
;               = (cluster number) + 31

convert_cluster_num_to_sector_num:
	mov ax, word [kernel_cluster_num]
	add ax, 31
	mov word [logicalDiskSector], ax	
;	jmp short load_one_disk_sector_to_kernel_memory		; Removed to save space

;*********************************************************************
; Load a sector from disk to kernel memory
; ------------------------------------------------------------------
; IN : logicalDiskSector = source disk sector number
;      kernel_memory_pointer = destination in memory
;*********************************************************************

load_one_disk_sector_to_kernel_memory:

	mov byte [numSectors], 1			; Read only 1 sector

	; ------------------------------------------------------------------
	; 2000h = Start of Segment where kernel will be loaded
	; ------------------------------------------------------------------

	mov word [destinationSegment], KernelStart	; Kernel Segment starts at 2000h
	mov ax, word [kernel_memory_pointer]
	mov word [destinationOffset], ax
;	jmp short load_disk_sectors_to_memory		; Removed to save space

; ------------------------------------------------------------------
; ------------------------------------------------------------------
; LOAD FROM DISK TO MEMORY
; ------------------------------------------------------------------
; ------------------------------------------------------------------

; ------------------------------------------------------------------
;	Local Variable Set 1
;	Used while loading from disk to memory
; ------------------------------------------------------------------
;	numSectors		db 0	; How many sectors
;	logicalDiskSector	dw 0	; Where on disk is the source sector
;	destinationSegment	dw 0	; What is the source segment base address in memory
;	destinationOffset	dw 0	; Where is the offset in memory of the destination 

;	trackNum		dw 0	; Disk Track Number
;	sectorInTrack		db 0	; Disk Sector Number within a track
;	headNum			db 0	; Disk Head Number
;	cylinderNum		db 0	; Disk Cylinder Number
; ------------------------------------------------------------------

;*********************************************************************
; Load from disk sectors to memory
; ------------------------------------------------------------------
; IN: logicalDiskSector = Starting Source Sector
;     bootDevice
;     destinationSegment = Destination Segment in Memory
;     destinationOffset = Offset into the Destination Segment
;     numSectors = Number of sectors to load
;*********************************************************************

load_disk_sectors_to_memory:

	; ------------------------------------------------------------------
	; Attempt to copy from disk to memory
	; ------------------------------------------------------------------

	call prepare_registers_and_copy_from_disk_to_memory

	; ------------------------------------------------------------------
	; If the Carry Bit is 0 then the disk copy succeeded
	; ------------------------------------------------------------------

	jnc load_disk_succeeded	

	; ------------------------------------------------------------------
	; If the disk copy failed then the floppy disk might need some time to spin 
	; up to the speed where it can be read.  So reset the floppy controller 
	; and try reading the disk again See http://www.ctyme.com/intr/rb-0607.htm
	; ------------------------------------------------------------------

load_disk_failed:

	call reset_floppy
	jmp short load_disk_sectors_to_memory

	; ------------------------------------------------------------------
	; If the disk copy succeeded then return
	; ------------------------------------------------------------------

load_disk_succeeded:

	ret


;*********************************************************************
; Prepare the registers used to copy from disk to memory
; Convert the logical sector number into the head number, 
; track number, and physical sector number for int 13h 
; Calculate head, track and sector settings for int 13h
; ------------------------------------------------------------------
; IN: logicalDiskSector
;     bootDevice
;     destinationSegment 
;     destinationOffset
;     numSectors
; OUT: The Registers required to copy disk to memory (int 13h / ah = 2)
;      CL = Physical Sector Number (Sector Number in a Track)
;      DH = Head Number
;      CH = Cylinder Number (Track number on a Side)
;      DL = Drive Number
;      ES = Destination Segment in Memory
;      BX = Offset into Destination Segment
;      AL = Number of sectors to Copy
;*********************************************************************

prepare_registers_and_copy_from_disk_to_memory:

;;	If I had extra space I would call each piece as a separate function

;	call calculate_track_num_from_logical_sector_num
;	call prepare_sector_in_track_from_logical_sector_num
;	call prepare_head_and_cylinder_and_drive_number_from_track_number
;	call prepare_memory_destination_and_num_sectors
;	call copy_from_disk_to_memory:
;	ret


;*********************************************************************
; Calculate the Track Number 
; ------------------------------------------------------------------
; IN:  logicalDiskSector 
; OUT: trackNum
;      DX = logicalDiskSector % SectorsPerTrack
;*********************************************************************

calculate_track_num_from_logical_sector_num:

	; ------------------------------------------------------------------
	; Calculate the Track Number from the logical sector
	; ------------------------------------------------------------------

	; mov ax, word [logicalDiskSector]	; logicalDiskSector = first sector to load
	mov ax, word [logicalDiskSector]	; AX = logicalDiskSector
	mov dx, 0				; DX = 0

	div word [SectorsPerTrack] 		; AX = logicalDiskSector / SectorsPerTrack
						; DX = logicalDiskSector % SectorsPerTrack

	mov word [trackNum], ax			; Track Number = logicalDiskSector / SectorsPerTrack


;*********************************************************************
; Prepare the sector number within the track (the Physical Sector) in CL
; ------------------------------------------------------------------
; IN:  DL = logicalDiskSector % SectorsPerTrack
; OUT: CL = Physical Sector Number (Sector Number in a Track)
;*********************************************************************

prepare_sector_in_track_from_logical_sector_num:

	; ------------------------------------------------------------------
	; Calculate the Sector Number within a Track from the logical sector
	; ------------------------------------------------------------------

	inc dl      				; Add 1 to SectorNumInTrack (sector count starts at 1)
;	mov byte [sectorNumInTrack], dl  	; Sector Number in Track = logicalDiskSector % SectorsPerTrack + 1

	; ------------------------------------------------------------------
	; Save the Sector Number within a Track (Physical Sector Number) in CL
	; ------------------------------------------------------------------

;	mov cl, byte [sectorNumInTrack]
	mov cl, dl	; CL = Sector Number in Track = logicalDiskSector % SectorsPerTrack + 1


;*********************************************************************
; Prepare the Head Number, Cylinder Number, and Drive Number in DH, CH, and DL
; ------------------------------------------------------------------
; IN:  trackNum, bootDevice
; OUT: DH = Head Number
;      CH = Cylinder Number (Track number on a Side)
;      DL = Drive Number
;*********************************************************************

prepare_head_and_cylinder_and_drive_number_from_track_number:

	; ------------------------------------------------------------------
	; Calculate Head Number and Cylinder Number from the Track Number
	; ------------------------------------------------------------------

	mov ax, word [trackNum] 	; AX = TrackNum
	mov dx, 0 			; DX = 0

	div word [Sides] 		; AX = (TrackNum) / Sides
					; DX = (TrackNum) % Sides

;	mov byte [cylinderNum], al  	; Cylinder Number = (TrackNum) / Sides
;	mov byte [headNum], dl  	; Head Number = (TrackNum) % Sides

	; ------------------------------------------------------------------
	; Save the Head Number in DH
	; ------------------------------------------------------------------

;	mov dh, byte [headNum]
	mov dh, dl			; DH = Head Number = TrackNum % Sides

	; ------------------------------------------------------------------
	; Save the Cylinder Number in CH
	; ------------------------------------------------------------------

;	mov ch, byte [cylinderNum]
	mov ch, al			; CH = Cylinder Number = TrackNum / Sides

	; ------------------------------------------------------------------
	; Save the Drive Number in DL
	; ------------------------------------------------------------------

	mov dl, byte [bootDevice]	; DL = Drive Number


;*********************************************************************
; Prepare the Destination in Memory in ES:BX, and Number of Sectors in AL
; ------------------------------------------------------------------
; IN: destinationSegment, destinationOffset, numSectors
; OUT: ES = Destination Segment in Memory
;      BX = Offset into Destination Segment
;      AL = Number of sectors to Copy
;*********************************************************************

prepare_memory_destination_and_num_sectors:

	; ------------------------------------------------------------------
	; Save the destination memory location in ES:BX
	; ------------------------------------------------------------------

	mov es, word [destinationSegment]
	mov bx, word [destinationOffset]

	; ------------------------------------------------------------------
	; Save the number of sectors in AL
	; ------------------------------------------------------------------

	mov al, byte [numSectors]	; read numSectors of sectors


;*********************************************************************
; Copy sectors to memory from disk and return.  This interrupt uses
; source disk drive DL, source disk head DH, source disk sector CL, 
; source disk cyliner CH, destination memory segment ES, 
; destination segment offset BX, and number of sectors AL
; ------------------------------------------------------------------
; IN:  DL = Source Drive Number
;      DH = Source Head Number
;      CH = Source Cylinder Number (Track Number on Side) (10 bits): 
;      CL = Source Physical Sector Number (Sector Number In Track) (6 bits)
;      ES:BX = Destination in Memory
;      AL = Number of sectors to Copy
; OUT: carry = 1 indicates an error
;      carry = 0 indicates success
; See http://www.ctyme.com/intr/rb-0607.htm
;*********************************************************************

copy_from_disk_to_memory:

	stc		; Set the carry bit. A few BIOSes do not set properly on error
	mov ah, 2	; Read disk sectors to memory using the BIOS interrupt
	int 13h		

	ret

; ------------------------------------------------------------------
; ------------------------------------------------------------------
; UTILITY SUBROUTINES
; ------------------------------------------------------------------
; ------------------------------------------------------------------

;*********************************************************************
; Compare Two Strings
; ------------------------------------------------------------------
; IN : String1Start
;      String1Segment
;      String2Start
;      String2Segment
;      StringLength
; OUT: CX = 0
;      Status bit Z = 0 if the strings are the same
;      Status bit Z = 1 if the strings are different
;*********************************************************************

compare_strings:

;	mov es, word [String1Segment]		; Pointer DI will be at offset 11
	mov di, word [String1Start]		; Set DI to this info

;	mov ds, word [String2Segment]	
	mov si, word [String2Start] 		; Start searching for kernel filename
	mov cx, word [StringLength]

	; ------------------------------------------------------------------
	; Repeatedly compare memory locations es:di and ds:si.  Increment 
	; di and si after each comparison.  Continue until a difference or 0 
	; is found ; Z=0 if all positions were the same until the 0.
	; Z=1 if there was any difference.
	; ------------------------------------------------------------------

	rep cmpsb				

	ret


;*********************************************************************
; Reset the floppy drive
; ------------------------------------------------------------------
; IN: [bootDevice] = boot device
;*********************************************************************

reset_floppy:		

	; ------------------------------------------------------------------
	; Reset the floppy
	; See http://www.ctyme.com/intr/rb-0605.htm
	; ------------------------------------------------------------------

	mov ax, 0
	mov dl, byte [bootDevice]
	stc				; Set the carry bit. A few BIOSes do not set properly on error
	int 13h

	; ------------------------------------------------------------------
	; If the reset failed then throw a fatal error
	; ------------------------------------------------------------------

	jc throw_fatal_disk_error	; If reset floppy failed, fatal double error

	; ------------------------------------------------------------------
	; If the reset succeeded then return
	; ------------------------------------------------------------------

	ret


;*********************************************************************
; Get New Drive Parameters
; ------------------------------------------------------------------
; IN : DL = Drive Number
; OUT: SectorsPerTrack = MaxSectorNumber
;      Sides = Max Head Number + 1
;*********************************************************************

get_new_drive_parameters:

	; ------------------------------------------------------------------
	; Save the boot device number
	; ------------------------------------------------------------------

	mov [bootDevice], dl		; Save boot device number

	; ------------------------------------------------------------------
	; Get the Drive parameters.  This interrupt assigns the registers to:
	;      AH = Status 
	;      BL = DriveType
	;      CH:CL = Max Cylinder Number(10 bits): Max Sector Number(6 bits)
	;      DH = Max Head Number 
	;      DL = Number of Drives 
	;      ES:DI = Drive Parameter Table
	;      Carry bit = 0 indicates success; Carry bit = 1 indicates error
	; See http://www.ctyme.com/intr/rb-0621.htm
	; ------------------------------------------------------------------

	mov ah, 8			; Get drive parameters
	int 13h

	; ------------------------------------------------------------------
	; Throw an error if Carry bit = 1
	; ------------------------------------------------------------------

	jc throw_fatal_disk_error	; If get drive parameters failed then exit

	; ------------------------------------------------------------------
	; Save the number of sectors per track = the Maximum Sector number
	; ------------------------------------------------------------------

	and cx, 3Fh			; The last 6 bits of cx are the Max Sector Number
	mov [SectorsPerTrack], cx 	; Sectors start at 1, so Max Sector Num = Sectors Per Track

	; ------------------------------------------------------------------
	; Save the number of sides = the maximum head number + 1
	; ------------------------------------------------------------------
	movzx dx, dh		; DH contains the Maximum head number
	inc dx    		; Head numbers start at 0, so add 1 to 
	mov [Sides], dx 	; the Maximum Head Number to count the Sides
	ret


; ------------------------------------------------------------------
; ------------------------------------------------------------------
; ERROR SUBROUTINES
; ------------------------------------------------------------------
; ------------------------------------------------------------------

;*********************************************************************
; Throw a file not found error 
;*********************************************************************

throw_file_not_found_error:
	mov si, file_not_found_msg	; Prepare to print "kernel not found" message
	jmp short throw_error_and_reboot

;*********************************************************************
; Throw a disk error 
;*********************************************************************

throw_fatal_disk_error:
	mov si, disk_error_msg		; Prepare to print "disk error" message
;	jmp short throw_error_and_reboot

;*********************************************************************
; Throw an error: print an error message, wait for a key press, and reboot
; ------------------------------------------------------------------
; IN: SI = location of the error message to print
;*********************************************************************

throw_error_and_reboot:
	; ------------------------------------------------------------------
	; Print the error message pointed to by SI
	; ------------------------------------------------------------------

	call print_string_and_newline		; Print the error message referred to by SI

	; ------------------------------------------------------------------
	; Print a message to wait for a key
	; ------------------------------------------------------------------

	mov si, press_any_key_msg		; Use the "Press a key" message
	call print_string_and_newline		; Print the message

	; ------------------------------------------------------------------
	; Wait for a key
	; See http://www.ctyme.com/intr/rb-1754.htm
	; ------------------------------------------------------------------

	mov ax, 0
	int 16h				; Wait for keystroke

	; ------------------------------------------------------------------
	; Reboot
	; See http://www.ctyme.com/intr/rb-2270.htm
	; ------------------------------------------------------------------

	int 19h				; Reboot the system

; ------------------------------------------------------------------
; ------------------------------------------------------------------
; PRINT SUBROUTINES
; ------------------------------------------------------------------
; ------------------------------------------------------------------

;*********************************************************************
; Print the string pointed to by Register SI and go to the next line
; ------------------------------------------------------------------
; IN: SI = location of the message to print
;*********************************************************************

print_string_and_newline:
	call print_string				; Output string in SI to screen
	mov si, newline_msg
;	call print_string				; Output newline to screen
;	ret

;*********************************************************************
; Print the string pointed to by Register SI
; ------------------------------------------------------------------
; IN: SI = location of the message to print
;*********************************************************************

print_string:				; Output string in SI to screen

	; ------------------------------------------------------------------
	; Load one character from the memory location stored in SI to
	; register AL.  Increment SI so it points to the next character
	; ------------------------------------------------------------------

load_and_test_char:
	lodsb				; Copy one char from string to AL

	; ------------------------------------------------------------------
	; If this character is zero, then here is the end of the string
	; ------------------------------------------------------------------

	cmp al, 0
	je end_of_string

	; ------------------------------------------------------------------
	; Print the character and repeat
	; See http://www.ctyme.com/intr/rb-0106.htm
	; ------------------------------------------------------------------

print_char:
	mov ah, 0Eh			; int 10h teletype function
	int 10h				; Print the character in AL

	jmp short load_and_test_char	; Repeat with the next character

	; ------------------------------------------------------------------
	; If this is the end of the string then return
	; ------------------------------------------------------------------

end_of_string:

	ret				; If char is zero, return


; ------------------------------------------------------------------
; Strings 
; ------------------------------------------------------------------

	kernel_filename		db "KERNEL  BIN"	; Kernel filename

;	disk_error_msg		db "Disk Error!", 10, 13, 0
	disk_error_msg		db "Disk Error!", 0
;	file_not_found_msg	db "KERNEL.BIN not found!", 10, 13, 0
	file_not_found_msg	db "No KERNEL.BIN!", 0
;	press_any_key_msg	db "Press any key...", 10, 13, 0
	press_any_key_msg	db "Press a key.....", 0
	newline_msg		db 10, 13, 0


; ------------------------------------------------------------------
; END OF BOOT SECTOR AND BUFFER START

	times 510-($-$$) db 0	; Pad remainder of boot sector with zeros
	dw 0AA55h		; The last two bytes are the Boot signature (DO NOT CHANGE!)

heap_start:			; Heap begins here (8k after this, stack starts)


; ==================================================================
