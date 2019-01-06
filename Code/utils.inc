INCLUDE "hardware.inc"

JOYPAD_A          EQU $01
JOYPAD_B          EQU $02
JOYPAD_SELECT     EQU $04
JOYPAD_START      EQU $08
JOYPAD_RIGHT      EQU $10
JOYPAD_LEFT       EQU $20
JOYPAD_UP         EQU $40
JOYPAD_DOWN       EQU $80
JOYPAD_DIRECTIONS EQU $F0

	; destroys A
ClearAndEnableInterrupts: MACRO
	xor a
	ei ; will take effect AFTER next instruction
	ldh [rIF], a
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