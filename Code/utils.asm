INCLUDE "hardware.inc"

EXPORT MemoryCopy
SECTION "Memory Copy", ROM0
; de = destination
; hl = source
; bc = count
MemoryCopy:
	ld a, [hl+]
	ld [de], a
	inc de
	dec bc
	ld a, b
	or c
	jr nz, MemoryCopy
	ret

EXPORT VideoMemoryCopy
SECTION "Video Memory Copy", ROM0
; de = destination
; hl = source
; bc = count
VideoMemoryCopy:
	ldh a, [rSTAT]
	and a, STATF_BUSY
	jr nz, VideoMemoryCopy
	ld a, [hl+]
	ld [de], a
	inc de
	dec bc
	ld a, b
	or c
	jr nz, VideoMemoryCopy
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
	
EXPORT VideoMemorySet
SECTION "Video Memory Set", ROM0
; hl = destination
; d = data
; bc = count
VideoMemorySet:
	ldh a, [rSTAT]
	and a, STATF_BUSY
	jr nz, VideoMemorySet
	ld a, d
	ld [hl+], a
	dec bc
	ld a, b
	or c
	jr nz, VideoMemorySet
	ret
