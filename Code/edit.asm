INCLUDE "hardware.inc"
INCLUDE "utils.inc"

SPRITE_ANIM_DELAY EQU 12
REPEAT_START_DELAY EQU 16
REPEAT_DELAY EQU 3
	
SECTION "Edit memory", HRAM
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
	
SECTION "Jingle", ROM0
Jingle:

	; load initial frequency into HL
FREQUENCY = 330
	ld hl, PULSE_FREQUENCY

	; load step to be added to frequency in DE
	; based on if a != 0 or not
	or a
	jr z, .up
.down
	ld de, 100
	jr .do
.up
	ld de, -100	

.do
	; load note count
	ld b, 3
.loop

	; play pulse channel 1 with frequency set in HL
	xor a
	ldh [rNR10], a ; sweep 
	ld a, (%01 << 6) + 30
	ldh [rNR11], a ; pattern + sound length
	ld a, $43
	ldh [rNR12], a ; init volume + envelope sweep
	ld a, l
	ldh [rNR13], a
	ld a, h
	or a, SOUND_START
	ldh [rNR14], a
	
	; add DE to HL frequency
	add hl, de
	
	; wait ~166ms
	ld c, 6
.delay
	HaltAndClearInterrupts
	dec c
	jr nz, .delay
	
	; repeat a few times
	dec b
	ret z
	jr .loop
	
EXPORT EditOldBuffer
SECTION "Edit old buffer", ROM0
EditOldBuffer:
	; check start has been pressed
	ldh a, [JoypadDown]
	and a, PADF_START
	ret z
	
	; sound ON
	ld a, $80
	ldh [rNR52], a
	ld a, $77
	ldh [rNR50], a ; max volume on both speakers
	ld a, $99
	ldh [rNR51], a ; channels 1 (pulse) and 4 (noise) on both speakers

	; play jingle with notes going down
	xor a
	call Jingle

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
	
	; set video address to displayed
	ldh a, [Video + 1]
	xor a, %100
	ldh [Video + 1], a

	; clear interrupts
	xor a
	ldh [rIF], a

.loop
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
	and a, PADF_A
	call nz, ToggleCell
	
	ldh a, [JoypadDown]
	and a, PADF_SELECT
	call nz, Clear

	; check start has been pressed
	ldh a, [JoypadDown]
	and a, PADF_START
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
	and a, PADF_LEFT
	jr z, .endLeft
	ldh a, [SelectX]
	and a
	jr z, .endLeft
	dec a
	ldh [SelectX], a
.endLeft
	
	; check up direction
	ldh a, [Down]
	and a, PADF_UP
	jr z, .endUp
	ldh a, [SelectY]
	and a
	jr z, .endUp
	dec a
	ldh [SelectY], a
.endUp
	
	; check right direction
	ldh a, [Down]
	and a, PADF_RIGHT
	jr z, .endRight
	ldh a, [SelectX]
	cp a, 39
	jr nc, .endRight
	inc a
	ldh [SelectX], a
.endRight
	
	; check down direction
	ldh a, [Down]
	and a, PADF_DOWN
	jr z, .endDown
	ldh a, [SelectY]
	cp a, 35
	jr nc, .endDown
	inc a
	ldh [SelectY], a
.endDown
	
	; wait v-blank
.skip
	HaltAndClearInterrupts
	
	jp .loop
	
.exit
	
	ld a, 1
	call Jingle

	; hide sprites
	ldh a, [rLCDC]
	and a, ~LCDCF_OBJON
	ldh [rLCDC], a
		
	; set video address to next displayed
	ldh a, [Video + 1]
	xor a, %100
	ldh [Video + 1], a
	
	; wait for sound to finish
	ld b, 10
.waitSound
	HaltAndClearInterrupts
	dec b
	jr nz, .waitSound
	
	; sound OFF
	xor a
	ldh [rNR52], a
	
	ret

SECTION "Value to flag", ROM0, ALIGN[8]
Flag: db 1, 2, 4, 8
	
	; \1: horizontal stride
MoveToCell: MACRO
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
ENDM

SECTION "Toggle cell", ROM0
ToggleCell:	
	; compute cell number in 2x2 cell group
	ldh a, [SelectX]
	and a, 1
	ld b, a
	ldh a, [SelectY]
	and a, 1
	sla a
	or a, b
	
	; transform cell number to bit mask in 2x2 cell
	ld d, HIGH(Flag)
	ld e, a
	ld a, [de]
	ld b, a

	; go to 2x2 cell in video buffer
	ldh a, [Video]
	ld l, a
	ldh a, [Video + 1]
	ld h, a
	MoveToCell 32
	
	; toggle bit 
	ld a, [hl]
	xor a, b
	ld [hl], a

	; go to 2x2 cell in automata buffer
	ldh a, [Progress]
	ld l, a
	ldh a, [Old]
	ld h, a
	MoveToCell 20
	
	; toggle bit 
	ld a, [hl]
	xor a, b
	ld [hl], a
	
	; do sound based on new value
	and a, b
	jr z, .blurp1

	; do noisy sound
.blurp0
	xor a
	ldh [rNR41], a ; sound length
	ld a, $F1
	ldh [rNR42], a ; init volume + envelope sweep
	ld a, $82
	ldh [rNR43], a ; frequency
	ld a, $80
	ldh [rNR44], a ; start
	jr .exit

	; do pulsy sound
.blurp1
	xor a
	ldh [rNR10], a ; sweep 
	ld a, (%01 << 6) + 30
	ldh [rNR11], a ; pattern + sound length
	ld a, $43
	ldh [rNR12], a ; init volume + envelope sweep
FREQUENCY = 100
	ld a, LOW(PULSE_FREQUENCY)
	ldh [rNR13], a
	ld a, SOUND_START | HIGH(PULSE_FREQUENCY)
	ldh [rNR14], a

.exit
	ret
	
SECTION "Clear buffers", ROM0
Clear:
	; load old buffer address and store into rendered
	ldh a, [Progress]
	ld l, a
	ld [Rendered], a
	ldh a, [Old]
	ld h, a
	ld [Rendered + 1], a
	
	; clear old buffer
	ld bc, 20 * 18
	ld d, 0
	call MemorySet
	
	; play long noise
	xor a
	ldh [rNR41], a ; set sound duration
	ld a, $F4
	ldh [rNR42], a ; set volume with long sweep
	ld a, $72
	ldh [rNR43], a ; set frequency
	ld a, $80
	ldh [rNR44], a ; start
	
	; render cleared buffer
	call StartRender
	call WaitRender	
	
	; reset video pointer
	ld hl, Video
	ld a, [hl+]
	ld h, [hl]
	ld l, a
	ld de, -(32 * 18)
	add hl, de
	ld a, l
	ldh [Video], a
	ld a, h
	ldh [Video + 1], a
	
	; reset rendered pointer
	ldh a, [Progress]
	ld l, a
	ld [Rendered], a
	ldh a, [Old]
	ld h, a
	ld [Rendered + 1], a
	
	ret