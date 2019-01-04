INCLUDE "hardware.inc"

SECTION "Random", ROM0, ALIGN[4]
Random:
	db -1, 1, 2, -1, 4, 3, -2, -1, -4, 3, -1, 5, 2
RandomEnd:

HaltAndClearIF: MACRO
	halt
	xor a
	ld [rIF], a
ENDM

EXPORT ScrollNintendoOut
SECTION "Scroll Nintendo Out", ROM0
ScrollNintendoOut:

	; wait a moment
	ld b, 32
.wait
	HaltAndClearIF
	dec b
	jr nz, .wait
	
	; sound ON
	ld a, $80
	ldh [rNR52], a ; sound ON with noise channel
	ld a, $77
	ldh [rNR50], a ; max volume on both speakers
	ld a, $88
	ldh [rNR51], a ; noise channel on both speakers

	; make noise
	ld a, 0
	ldh [rNR41], a ; set sound duration
	ld a, $F0
	ldh [rNR42], a ; set volume
	ld a, $72
	ldh [rNR43], a ; set frequency
	ld a, $80
	ldh [rNR44], a ; turn on

	; nudge nintendo logo
	ld d, HIGH(Random)
	ld e, 0
	ld b, 42
.noise
	HaltAndClearIF
	HaltAndClearIF
	ld a, [de]
	ldh [rSCY], a
	
	inc e
	ld a, e
	cp a, RandomEnd - Random
	jr nz, .next
	ld e, 0
.next

	ld a, [de]
	ldh [rSCX], a

	inc e
	ld a, e
	cp a, RandomEnd - Random
	jr nz, .next2
	ld e, 0
.next2
	
	dec b
	jr nz, .noise

	xor a
	ldh [rSCY], a
	
	; change noise
	ld a, $62
	ldh [rNR43], a ; set frequency
	
	ld b, 4 ; number of frames before reducing volume
	ld c, 16 ; number of steps before volume is 0

	; nintendo logo lift-off!
.scrollup
	HaltAndClearIF
	; scroll up
	ldh a, [rSCY]
	inc a
	ldh [rSCY], a
	
	; fade out
	ld a, c
	or a
	jr z, .novolumechange
	dec b
	jr nz, .novolumechange
	; decrement volume by 1
	; see http://gbdev.gg8.se/wiki/articles/Gameboy_sound_hardware obscure behavior...
	ld a, $08
REPT 15 
	ldh [rNR42], a
ENDR
	ld b, 4
	dec c
	
.novolumechange
	; loop until nintendo logo is out of screen
	ldh a, [rSCY]
	cp a, 88
	jp nz, .scrollup
	
	; sound off
	xor a
	ldh [rNR52], a
	
	ret