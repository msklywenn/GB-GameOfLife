SECTION "Utils", ROM0

MemCopy: MACRO
	ld hl, \1
	ld de, \2
	ld bc, \3
.memcpyloop\@
	ld a, [de]
	ld [hl+], a
	inc de
	dec bc
	ld a, b
	or c
	jr nz, .memcpyloop\@
	ENDM

StringCopy: MACRO
	ld hl, \1
	ld de, \2
.strcpyloop\@
	ld a, [de]
	ld [hl+], a
	inc de
	and a
	jr nz, .strcpyloop\@
	ENDM