INCLUDE "hardware.inc"

	; destroys A
ClearAndEnableInterrupts: MACRO
	xor a
	ei ; will take effect AFTER next instruction
	ldh a, [rIF]
ENDM

	; \1: sprite ID
	; \2: X position
	; \3: Y position
	; \4: tile number
	; \5: flags
	; destroys A and HL
SetSprite: MACRO
	ld hl, _OAMRAM + \1 * 4
	ld a, \3
	ld [hl+], a
	ld a, \2
	ld [hl+], a
	ld a, \4
	ld [hl+], a
	ld a, \5
	ld [hl+], a
ENDM