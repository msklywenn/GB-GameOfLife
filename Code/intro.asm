INCLUDE "hardware.inc"
INCLUDE "utils.inc"

EXPORT Random, RandomEnd
SECTION "Random", ROM0, ALIGN[4]
Random:
	db -1, 1, 2, -1, 2, 0, -2, -1, -2, 3, -1, -2, 2
RandomEnd:

EXPORT Intro
SECTION "Intro", ROM0

	; unpack routine from bootrom
	; adapted to run even with LCD on
GraphicA:
	ld c, a
GraphicB:
	ld b, 4
.loop:
	push bc
	rl c
	rla
	pop bc
	rl c
	rla
	dec b
	jr nz, .loop
	ld b, a
.waitVRAM
	ldh a, [rSTAT]
	and a, STATF_BUSY
	jr nz, .waitVRAM
	ld a, b
	ld [hl+], a
	inc hl
	ld [hl+], a
	inc hl
	ret

Intro:
	; fade bg palette
	ld b, 8
.fadeDelay0
	HaltAndClearInterrupts
	dec b
	jr nz, .fadeDelay0

	ld a, %11111100
	ldh [rBGP], a

	ld b, 8
.fadeDelay1
	HaltAndClearInterrupts
	dec b
	jr nz, .fadeDelay1

	ld a, %11111000
	ldh [rBGP], a

	ld b, 8
.fadeDelay2
	HaltAndClearInterrupts
	dec b
	jr nz, .fadeDelay2

	; load bg and obj palette [0=black, 1=dark gray, 2=light gray, 3=white]
	ld a, %11100100
	ldh [rBGP], a

	; copy nintendo logo tiles from rom to block 1
	; borrowed from boot rom
	ld de, NINTENDOLOGO_ROM
	ld hl, _VRAM + $810
.logoloop
	ld a, [de]
	call GraphicA
	call GraphicB
	inc de
	ld a, e
	cp $34
	jr nz, .logoloop

	; move all map indices to block 1
	ld hl, _SCRN0
	ld bc, 18 * 32
.copy
	ldh a, [rSTAT]
	and a, STATF_BUSY
	jr nz, .copy
	ld a, [hl]
	add a, $80
	ld [hl+], a	
	dec bc
	ld a, b
	or c
	jr nz, .copy
	
	; display nintendo logo from new map
	ld a, LCDCF_ON | LCDCF_BGON | LCDCF_BG9800
	ldh [rLCDC], a
	
	; sound
	ld a, $77
	ldh [rNR10], a ; sweep 
	ld a, (%00 << 6) + 0
	ldh [rNR11], a ; pattern + sound length
	ld a, $F6
	ldh [rNR42], a ; set volume with long sweep
FREQUENCY = 146
	ld a, LOW(PULSE_FREQUENCY)
	ldh [rNR13], a
	ld a, SOUND_START | HIGH(PULSE_FREQUENCY)
	ldh [rNR14], a

	; slowly copy default map to v-ram column by column
	ld hl, DefaultMap
	ld de, _SCRN0
	ld b, 20
.loopX
	ld c, 2
	HaltAndClearInterrupts
	HaltAndClearInterrupts
	HaltAndClearInterrupts
.loopY
	; copy 8 tiles (that's how many there is before L and E overflow)
REPT 8
	ld a, [hl]
	ld [de], a
	ld a, l
	add a, $20
	ld l, a
	ld a, e
	add a, $20
	ld e, a
ENDR
	; L and E overflowed, we can increment H and L
	inc h
	inc d
	dec c
	jr nz, .loopY
	; copy last 2 tiles
REPT 2
	ld a, [hl]
	ld [de], a
	ld a, l
	add a, $20
	ld l, a
	ld a, e
	add a, $20
	ld e, a
ENDR
	; back to beginning (high byte)
	ld a, h
	sub a, 2
	ld h, a
	ld a, d
	sub a, 2
	ld d, a
	
	; back to beginning + next column (low byte)
	ld a, l
	sub a, $3F
	ld l, a
	ld a, e
	sub a, $3F
	ld e, a
	
	dec b
	jp nz, .loopX

	ret