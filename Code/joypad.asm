INCLUDE "hardware.inc"

EXPORT JoypadDown, JoypadPressed
Section "Joypad memory", HRAM
; Bits 0..7 are A, B, Select, Start, Right, Left, Up, Down
JoypadPressed: ds 1
JoypadNewlyPressed: ds 1
JoypadDown: ds 1

EXPORT InitJoypad
SECTION "Init joypad", ROM0
InitJoypad:
	xor a
	ldh [JoypadDown], a
	ldh [JoypadPressed], a
	ldh [JoypadNewlyPressed], a
	ret

EXPORT ReadJoypad
SECTION "Read Joypad", ROM0
ReadJoypad:
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
	
	; add to currently pressed buttons
	ld b, a
	ldh a, [JoypadNewlyPressed]
	or a, b
	ldh [JoypadNewlyPressed], a

	; reset joypad
	ld a, $30
	ldh [rP1], a

	ret

EXPORT UpdateJoypad
SECTION "Update joypad", ROM0
UpdateJoypad:	
	; compute & store just pressed buttons
	ldh a, [JoypadNewlyPressed]
	ld b, a
	ldh a, [JoypadPressed]
	cpl 
	and a, b
	ldh [JoypadDown], a
	
	; update pressed
	ld a, b
	ldh [JoypadPressed], a
	
	; reset newly pressed
	xor a
	ldh [JoypadNewlyPressed], a
	
	ret
