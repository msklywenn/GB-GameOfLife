INCLUDE "hardware.inc"

JOYPAD_DIRECTIONS EQU (PADF_UP | PADF_DOWN | PADF_LEFT | PADF_RIGHT)

SOUND_START EQU $80
PULSE_FREQUENCY EQUS "(-131072 / (FREQUENCY) + 2048)"

	; destroys A
ClearAndEnableInterrupts: MACRO
	xor a
	ei ; will take effect AFTER next instruction
	ldh [rIF], a
ENDM

	; destroys A
HaltAndClearInterrupts: MACRO
	xor a
	ldh [rIF], a
	halt
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