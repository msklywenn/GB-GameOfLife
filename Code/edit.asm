INCLUDE "hardware.inc"
	
Section "Edit memory", HRAM
SelectX: ds 1
SelectY: ds 1

EXPORT InitEdit
SECTION "Init edit", ROM0
InitEdit:
	ld a, 20
	ldh [SelectX], a
	ld a, 18
	ldh [SelectY], a
	ret
	
EXPORT EditOldBuffer
SECTION "Edit old buffer", ROM0
EditOldBuffer:	
	ldh a, [JoypadDown]
	and a, %1000
	ret z
	
.loop
	halt
	xor a
	ldh a, [rIF]

	call UpdateJoypad
	ldh a, [JoypadDown]
	and a, %1000
	ret nz

	jr .loop
	
	
	
	