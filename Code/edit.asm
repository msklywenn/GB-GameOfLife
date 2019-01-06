INCLUDE "hardware.inc"
INCLUDE "utils.inc"

SPRITE_ANIM_DELAY EQU 12
REPEAT_START_DELAY EQU 24
REPEAT_DELAY EQU 3
	
Section "Edit memory", HRAM
SelectX: ds 1
SelectY: ds 1
Down: ds 1
RepeatDelay: ds 1
SpriteAnimation: ds 1
SpriteDelay: ds 1

EXPORT InitEdit
SECTION "Init edit", ROM0
InitEdit:
	ld a, 20
	ldh [SelectX], a
	ld a, 18
	ldh [SelectY], a
	xor a
	ldh [Down], a
	ld a, REPEAT_START_DELAY
	ldh [RepeatDelay], a
	ret
	
EXPORT EditOldBuffer
SECTION "Edit old buffer", ROM0
EditOldBuffer:
	; check start has been pressed
	ldh a, [JoypadDown]
	and a, JOYPAD_START
	ret z
	
	; wait v-blank
	halt
	
	; show sprites
	ldh a, [rLCDC]
	or a, LCDCF_OBJON
	ldh [rLCDC], a
	
	; init sprite animation
	xor a
	ldh [SpriteAnimation], a
	ld a, SPRITE_ANIM_DELAY
	ldh [SpriteDelay], a
	
.loop
	; clear interrupts
	xor a
	ldh [rIF], a

	; compute cursor X position
	ldh a, [SelectX]
	sla a
	sla a
	add a, 8
	ld b, a
	
	; compute cursor Y position
	ldh a, [SelectY]
	sla a
	sla a
	add a, 16
	ld c, a
	
	; update and load sprite animation
	ldh a, [SpriteDelay]
	dec a
	ldh [SpriteDelay], a
	jr nz, .same
	ldh a, [SpriteAnimation]
	inc a
	and a, 3
	ldh [SpriteAnimation], a
	ld a, SPRITE_ANIM_DELAY
	ldh [SpriteDelay], a
.same
	ldh a, [SpriteAnimation]
	ld d, a
	
	; update sprite in OAM
	SetSprite 0, b, c, d, 0

	call UpdateJoypad
	
	; check A button has been pressed
	ldh a, [JoypadDown]
	and a, JOYPAD_A
	call nz, ToggleCell

	; check start has been pressed
	ldh a, [JoypadDown]
	and a, JOYPAD_START
	jr nz, .exit
	
	; reset input
	xor a
	ldh [Down], a

	; if a direction is pressed, handle repeat
	ldh a, [JoypadPressed]
	and JOYPAD_DIRECTIONS
	ld b, a
	jr z, .addDown

	; check if time to repeat
	ldh a, [RepeatDelay]
	dec a
	ldh [RepeatDelay], a
	jr nz, .addDown

	; reset repeat delay and add pressed to inputs
	ld a, REPEAT_DELAY
	ldh [RepeatDelay], a
	ld a, b
	ldh [Down], a

	; add just down keys
.addDown
	ldh a, [JoypadDown]
	and JOYPAD_DIRECTIONS
	ld b, a
	ldh a, [Down]
	or a, b
	ldh [Down], a
	
	ldh a, [JoypadPressed]
	or a
	jr nz, .do
	
	ld a, REPEAT_START_DELAY
	ldh [RepeatDelay], a
	
.do
	; check left direction
	ldh a, [Down]
	and a, JOYPAD_LEFT
	jr z, .endLeft
	ldh a, [SelectX]
	and a
	jr z, .endLeft
	dec a
	ldh [SelectX], a
.endLeft
	
	; check up direction
	ldh a, [Down]
	and a, JOYPAD_UP
	jr z, .endUp
	ldh a, [SelectY]
	and a
	jr z, .endUp
	dec a
	ldh [SelectY], a
.endUp
	
	; check right direction
	ldh a, [Down]
	and a, JOYPAD_RIGHT
	jr z, .endRight
	ldh a, [SelectX]
	cp a, 39
	jr nc, .endRight
	inc a
	ldh [SelectX], a
.endRight
	
	; check down direction
	ldh a, [Down]
	and a, JOYPAD_DOWN
	jr z, .endDown
	ldh a, [SelectY]
	cp a, 35
	jr nc, .endDown
	inc a
	ldh [SelectY], a
.endDown
	
	; wait v-blank
.skip
	halt	
	
	jp .loop
	
.exit
	
	; hide sprites
	ldh a, [rLCDC]
	and a, ~LCDCF_OBJON
	ldh [rLCDC], a
	
	ret

Section "Value to flag", ROM0, ALIGN[8]
Flag: db 1, 2, 4, 8
	
	; \1: horizontal stride
ToggleInTargetBuffer: MACRO
	; move pointer to 2x2 cell group
	ldh a, [SelectY]
	sra a
	jr z, .addX\@
	ld c, a
	ld de, \1
.mul\@
	add hl, de
	dec c
	jr nz, .mul\@
.addX\@
	xor a
	ld d, a
	ldh a, [SelectX]
	sra a
	ld e, a
	add hl, de	
	
	; compute cell number in 2x2 cell group
	ldh a, [SelectX]
	and a, 1
	ld b, a
	ldh a, [SelectY]
	and a, 1
	sla a
	or a, b
	
	; transform cell number to bit offset in 2x2 cell
	ld d, HIGH(Flag)
	ld e, a
	ld a, [de]
	ld b, a

	ld a, [hl]
	xor a, b
	ld [hl], a
ENDM

ToggleCell:
	ldh a, [Video]
	ld l, a
	ldh a, [Video + 1]
	xor a, %100 ; change to displayed video buffer
	ld h, a
	ToggleInTargetBuffer 32
	ldh a, [Progress]
	ld l, a
	ldh a, [Old]
	ld h, a
	ToggleInTargetBuffer 20
	ret