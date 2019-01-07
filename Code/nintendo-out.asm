INCLUDE "hardware.inc"
INCLUDE "utils.inc"

SECTION "Random", ROM0, ALIGN[4]
Random:
	db -1, 1, 2, -1, 4, 3, -2, -1, -4, 3, -1, 5, 2
RandomEnd:

EXPORT ScrollNintendoOut
SECTION "Scroll Nintendo Out", ROM0
ScrollNintendoOut:

	; wait a moment
	ld b, 32
.wait
	HaltAndClearInterrupts
	dec b
	jr nz, .wait
	
	; sound ON
	ld a, $80
	ldh [rNR52], a
	ld a, $77
	ldh [rNR50], a ; max volume on both speakers
	ld a, $88
	ldh [rNR51], a ; noise channel on both speakers

	; make noise
	xor a
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
	HaltAndClearInterrupts
	HaltAndClearInterrupts
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
	xor a
	ldh [rNR41], a ; set sound duration
	ld a, $F4
	ldh [rNR42], a ; set volume with long sweep
	ld a, $62
	ldh [rNR43], a ; set frequency
	ld a, $80
	ldh [rNR44], a ; start

	; nintendo logo lift-off!
.scrollup
	HaltAndClearInterrupts

	; scroll up
	ldh a, [rSCY]
	inc a
	ldh [rSCY], a
	
	; loop until nintendo logo is out of screen
	ldh a, [rSCY]
	cp a, 88
	jp nz, .scrollup
	
	; sound off
	xor a
	ldh [rNR52], a
	
	ret