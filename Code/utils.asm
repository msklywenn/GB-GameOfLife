INCLUDE "hardware.inc"

EXPORT MemoryCopy
SECTION "Memory Copy", ROM0
; hl = destination
; de = source
; bc = count
MemoryCopy:
	ld a, [de]
	ld [hl+], a
	inc de
	dec bc
	ld a, b
	or c
	jr nz, MemoryCopy
	ret
	
EXPORT MemorySet
SECTION "Memory Set", ROM0
; hl = destination
; d = data
; bc = count
MemorySet:
	ld a, d
	ld [hl+], a
	dec bc
	ld a, b
	or c
	jr nz, MemorySet
	ret
