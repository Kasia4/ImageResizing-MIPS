# Nazwa pliku: skalowanieObrazu.asm
# Autor: Katarzyna Rybacka (4I3)
# Skalowanie obrazu .bmp do zadanej rozdzielczo�ci


	.data
	
in:	.space 64
out:	.space 64
header: .space 54
info:	.space 12
buffer: .byte 0,0,0,0

strIn: 	.asciiz "Podaj nazwe pliku wejsciowego\n"
strOut: .asciiz "Podaj nazwe pliku wyjsciowego\n"
height: .asciiz "Podaj wysokosc\n"
width: 	.asciiz "Podaj szerokosc\n"
nErr: 	.asciiz "Nieprawidlowa nazwa pliku!\n"
lErr: 	.asciiz "Nie mozna zaladowac pliku!\n"



	.text
	.globl main
	
# s0- file descriptor(input)
# s1- size of image(input)
# s2- address of allocated memory(input)
# s3- destination width
# s4- destination height
# s5- size of image(output)
# s6- address of allocated memory(output)
# s7- file descriptor(output)

main:
	li $v0, 4			# ask for input filename
	la $a0, strIn
	syscall
	
	li $v0, 8			# read input filename
	la $a0, in
	li $a1, 64
	syscall
	
	li $v0, 4			# ask for output filename
	la $a0, strOut
	syscall
	
	li $v0, 8			# read output filename
	la $a0, out
	li $a1, 64
	syscall
	
	
	li $t0, '\n'		
	li $t1, 64
	li $t2, 64
	
	
propName:
	# erase '\n' from input filename
	beqz $t1, propName2
	subiu $t1, $t1, 1
	lb $t3, in($t1)
	bne $t3, $t0, propName
	sb $zero, in($t1)
	
	
propName2:
	# erase '\n' from output filename and start reading file
	beqz $t2, readFile
	subiu $t2, $t2, 1
	lb $t3, out($t2)
	bne $t3, $t0, propName2
	sb $zero, out($t2)
	
	
readFile:

	li $v0, 13			# open input file
	la $a0, in			# input filename
	move $a1, $zero
	move $a2, $zero
	syscall
	
	move $s0, $v0			# store file descriptor
	
	bltz $s0, inError
	
	# read header of file
	li $v0, 14
	move $a0, $s0			# file descriptor
	la $a1, header			# store the header
	li $a2, 54
	syscall
	
	bltz $v0, loadError
	
	la $t0, header+34		# address of image size
	ulw $s1, ($t0)			# store number of bytes of image size
	
	li $v0, 9
	move $a0, $s1			# allocate memory for array of pixels (input)
	syscall
	
	move $s2, $v0			# store address of allocated memory
	
	
	li $v0, 4			# ask for destination width
	la $a0, width
	syscall
	
	li $v0, 5			# read destination width
	syscall
	
	move $s3, $v0			# store width in s3
	
	li $v0, 4			# ask for destination height 
	la $a0, height
	syscall
	
	li $v0, 5			# read destination width
	syscall
	
	move $s4, $v0			# store height in s4
	
	mul $s5, $s3, $s4		# number of pixels of new image
	mul $s5, $s5, 3			# size of new array of pixels in bytes (without padding)
	
	li $v0, 9
	move $a0, $s5			# allocate memory for array of pixels (output)
	syscall
	
	move $s6, $v0			# store address of new allocated memory (output)
	
	li $v0, 14			# load array of pixels
	move $a0, $s0			# input file descriptor
	move $a1, $s2			# address of array for pixels of input image
	move $a2, $s1			# size of input image
	syscall
	
	# close file
	li $v0, 16
	move $a0, $s0
	syscall

	# store in info input buffer, height and width of input image 
	la $t1, info
	usw $s2, ($t1)			# input buffer (whole table of bytes)
	la $t2, header
	ulw $t3, 18($t2)		# input width
	usw $t3, 4($t1)
	ulw $t3, 22($t2) 		# input height
	usw $t3, 8($t1)
	
	la $a0, info			# address of array which keeps information about input image
	jal resize
	
	# write to the file after resizing
	li $v0, 13			# open output file
	la $a0, out			# output filename
	li $a1, 1
	syscall
	
	move $s7, $v0			# output file descriptor
	
	bltz $s7, inError
	
	# prepare header and store in output file
	# count padding in every row
	mul $t0, $s3, 3			# width in bytes
	div $t1, $t0, 4
	addiu $t1, $t1, 1
	mul $t1, $t1, 4
	sub $t1, $t1, $t0
	
	bne $t1, 4, modify
	move $t1, $zero
	
	# t1 contains size of padding
modify:
	# count padding in whole file ( padding in a row * height)
	mul $t2, $t1, $s4		# number of zero bytes in output file
	add $t3, $t2, $s5		# total size of array of pixels
	
	la $t4, header 
	usw $s3, 18($t4)		# store width
	usw $s4, 22($t4)		# store height
	usw $t3, 34($t4)		# store total size
	addiu $t3, $t3, 54		# size of whole file
	usw $t3, 2($t4)			# store size of whole file
	li $t3, 54
	usw $t3, 8($t4)			# store size of header
	li $t3, 40
	usw $t3, 14($t4)		# store size of DIB header
	
	# write header
	li $v0, 15
	move $a0, $s7 			# output file descriptor
	la $a1, header
	li $a2, 54
	syscall
	
	li $t4, 0
	
	# loop which writes all output rows of pixels
	beq $t4, $s4, end
write:
	
	# write row of pixel array
	li $v0, 15
	move $a0, $s7			# output file descriptor
	move $a1, $s6			# output array of pixels
	move $a2, $t0			# size of row without padding
	syscall
	
	# write padding
	li $v0, 15 
	move $a0, $s7
	la $a1, buffer			# array of zeros
	move $a2, $t1			# size of padding per row
	syscall
	
	addiu $t4, $t4, 1		# increment counter of loop
	addu  $s6, $s6, $t0		# move descriptor in array of output pixels
	bne $t4, $s4, write
	
	
end:
	# close file
	li $v0, 16
	move $a0, $s7
	syscall
	
	j exit
	
	
resize:
	ulw $t0, 4($a0)			# width of input image
	ulw $t1, 8($a0)			# height of input image
	mul $t2, $t0, $t1		# number of pixels of input image
	mul $t2, $t2, 3			# number of bytes of input image
	subu $t3, $s1, $t2		# size of padding in whole table
	div $t3, $t3, $t1		# size of padding per row
	
	li $t4, 0			# outer loop counter ( current y-position in output image)
	
	
storeRow:
	li $t5, 0			# inner loop counter ( current x-position in output image)
	
	mul $t6, $t4, $t1		# count row index of neighbour
	div $t6, $t6, $s4
	
	
storePixel:
	# find neighbour in input array of pixels
	mul $t7, $t0, 3
	addu $t7, $t7, $t3		# size of input row with padding
	
	mul $t7, $t7, $t6		# offset in input pixels array made by already stored rows
	
	mul $t8, $t5, $t0
	div $t8, $t8, $s3 		# count column index of neighbour
	
	mul $t8, $t8, 3
	
	addu $t7, $t7, $t8		# whole offset in input pixels array (neighbour)
	
	# count index of output pixel
	mul $t8, $s3, 3			# row size in bytes in output array
	mul $t8, $t8, $t4		# how many rows are already written
	mul $t9, $t5, 3			# how many pixels in current row are written
	addu $t8, $t8, $t9		# how many bytes should be ignored
	
	move $a1, $s2 			# input array
	move $a2, $s6			# output array
	
	addu $a1, $a1, $t7		# move index in input array
	addu $a2, $a2, $t8		# move index in output array

	# store 3 bytes of pixel
	lbu $t7, ($a1)
	sb $t7, ($a2)
	
	addiu $a1, $a1, 1
	addiu $a2, $a2, 1
	
	lbu $t7, ($a1)
	sb $t7, ($a2)
	
	addiu $a1, $a1, 1
	addiu $a2, $a2, 1
	
	lbu $t7, ($a1)
	sb $t7, ($a2)
	
	addiu $t5, $t5, 1
	blt $t5, $s3, storePixel			# store next pixel of current row of output image

nextRow:
	addiu $t4, $t4, 1
	blt $t4, $s4, storeRow			# store next row of output image
	
			
endR:
	jr $ra				# come back from resize function
	

inError:
	li $v0, 4			# show error message
	la $a0, nErr
	syscall
	j exit
	
	
loadError:
	li $v0, 4			# show error message
	la $a0, lErr
	syscall


exit:
	li $v0,10			
	syscall

	
	
	

