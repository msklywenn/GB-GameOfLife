INCLUDE "hardware.inc"

Section "Joypad memory", HRAM
; Bits 0..7 are A, B, Select, Start, Right, Left, Up, Down
JoypadDown: ds 1
JoypadPressed: ds 1

SECTION "Update joypad", ROM0
UpdateJoypad:
	; read directions
	ld a, P1F_5
	ldh [rP1], a 
	ldh a, [rP1]
	ldh a, [rP1]
	ldh a, [rP1]
	ldh a, [rP1]
	and a, $0F
	swap a ; move into high nibble
	ld b, a
	
	; read buttons
	ld a, P1F_4
	ldh [rP1], a 
	ldh a, [rP1]
	ldh a, [rP1]
	ldh a, [rP1]
	ldh a, [rP1]
	and a, $0F
	
	; merge directions and buttons
	; complement so that active buttons read as 1
	or a, b
	cpl

	; backup all buttons in B
	ld b, a
	
	; store just pressed buttons
	ldh a, [JoypadPressed]
	cpl 
	and a, b
	ldh [JoypadDown], a
	
	; store currently pressed buttons
	ld a, b
	ldh [JoypadPressed], a
	
	; reset joypad
	ld a, $30
	ldh [rP1], a
	ret

Section "Edit memory", HRAM
SelectX: ds 1
SelectY: ds 1

EXPORT InitEdit
SECTION "Init edit", ROM0
InitEdit:
	ld a, 20
	ldh [SelectX], a
	ld a, 18
	ldh [SelectY], a
	xor a
	ldh [JoypadDown], a
	ldh [JoypadPressed], a
	ret
	

EXPORT EditOldBuffer
SECTION "Edit old buffer", ROM0
EditOldBuffer:
	call UpdateJoypad
	
	ldh a, [JoypadDown]
	and a, %1000
	ret z
	
.loop
	halt
	xor a
	ldh a, [rIF]

	call UpdateJoypad
	ldh a, [JoypadDown]
	and a, %1000
	ret nz

	jr .loop
	
	
	
	