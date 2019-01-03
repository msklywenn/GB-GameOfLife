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

	; \1: sprite ID
	; \2: X position
	; \3: Y position
	; \4: tile number
	; \5: flags
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
