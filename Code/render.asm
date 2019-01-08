INCLUDE "hardware.inc"
INCLUDE "utils.inc"

RENDER_IN_HBL EQU 0

EXPORT Video, Rendered
SECTION "Render Memory", HRAM
LinesLeft: ds 1     ; number of lines left to render
TilesLeft: ds 1     ; number of tiles left to render in current line
Video: ds 2         ; progressing pointer in tilemap (VRAM)
Rendered: ds 2      ; progressing pointer in old buffer

SECTION "V-Blank Interrupt Handler", ROM0[$40]
VBlankInterruptHandler:
	; save registers
	push af
	push bc
	call ReadJoypad
	jr LCDStatInterruptHandler.start

SECTION "LCD Stat Interrupt Handler", ROM0[$48]
LCDStatInterruptHandler:
	; save registers
	push af
	push bc

.start    
	; check there are tiles to render
	ldh a, [LinesLeft]
	or a
	jr z, .exit
	
	; move lines left to B
	ld b, a

	push de
	push hl

.render	
	; load buffer pointer into DE
	ld hl, Video
	ld a, [hl+]
	ld d, [hl]
	ld e, a	

	; load video pointer into HL
	ld hl, Rendered
	ld a, [hl+]
	ld h, [hl]
	ld l, a
	
	; load counters
	ldh a, [TilesLeft]
	ld c, a

.loop
	; check we can still render
	ldh a, [rSTAT]
	and a, STATF_BUSY
	jr nz, .finish

	; copy one byte
	ld a, [hl+]
	ld [de], a
	inc e ; it will never overflow since it only increments
	      ; up to 20 bytes starting on 32 byte boundaries

	; loop while there are tiles to render
	dec c
	jr nz, .loop

	; go to next line
	ld a, e
	add a, 32 - 20
	ld e, a
	jr nc, .nocarry
	inc d
.nocarry
	
	; loop while there are lines to render
	dec b
	jr z, .finish
	
	; reset tile counter
	ld c, 20 

	jr .loop

.finish
	; save counters
	ld a, c
	ldh [TilesLeft], a
	ld a, b
	ldh [LinesLeft], a
	
	; save incremented video pointer and buffer pointer 
	ld a, e
	ldh [Video], a
	ld a, d
	ldh [Video + 1], a

	ld a, l
	ldh [Rendered], a
	ld a, h
	ldh [Rendered + 1], a

	; restore registers saved in interrupt handler
	pop hl
	pop de

.exit
	pop bc
	pop af

	; return from v-blank or lcd interrupt
	reti

EXPORT InitRender
SECTION "Init render", ROM0
InitRender:
	ld a, $9C
	ldh [Video + 1], a
	xor a
	ldh [Video], a
	ret

EXPORT StartRender	
SECTION "StartRender", ROM0
StartRender:	
	; set rendered pointer to old buffer
	ldh a, [Progress]
	ld l, a
	ld [Rendered], a
	ldh a, [Old]
	ld h, a
	ld [Rendered + 1], a

	; start rendering
	ld a, 20
	ldh [TilesLeft], a
	ld a, 18
	ldh [LinesLeft], a
	
	; enable v-blank and lcd stat interrupt for h-blank
	; rendering routine is too slow for lcdc right now so disabled
IF RENDER_IN_HBL != 0
	ld a, IEF_VBLANK | IEF_LCDC
ELSE
	ld a, IEF_VBLANK
ENDC
	ld [rIE], a
	
	ret

EXPORT WaitRender	
SECTION "WaitRender", ROM0
WaitRender:
	ldh a, [LinesLeft]
	or a
	jr z, .exit
	halt
	jr WaitRender

.exit
IF RENDER_IN_HBL != 0
	; enable only v-blank interrupt and wait for vbl
	ld a, IEF_VBLANK
	ld [rIE], a
	HaltAndClearInterrupts
ENDC

	; swap video pointer
	ldh a, [Video + 1]
	dec a
	dec a
	xor a, %100
	ldh [Video + 1], a
	xor a
	ldh [Video], a

	; swap displayed BG
	ldh a, [rLCDC]
	xor a, LCDCF_BG9C00
	or a, LCDCF_ON | LCDCF_BGON
	ldh [rLCDC], a

	ret