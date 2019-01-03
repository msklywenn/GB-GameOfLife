INCLUDE "hardware.inc"

SECTION "NintendoLogo", ROM0

EXPORT ScrollNintendoOut
SECTION "Scroll Nintendo Out", ROM0
ScrollNintendoOut:
	ld b, 30
.wait
	halt
	xor a
	ld [rIF], a
	dec b
	jr nz, .wait

.scrollup
	halt
	xor a
	ld [rIF], a
	ldh a, [rSCY]
	inc a
	ldh [rSCY], a
	cp a, 88
	jp nz, .scrollup
	
	ret