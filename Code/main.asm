INCLUDE "hardware.inc"

_VRAM_BG_TILES EQU $9000

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

SECTION "Timer Interrupt Handler", ROM0[$50]
TimerInterruptHandler:
	reti

SECTION "Serial Interrupt Handler", ROM0[$58]
SerialInterruptHandler:
	reti

SECTION "Joypad Interrupt Handler", ROM0[$60]
JoypadInterruptHandler:
	reti

SECTION "Header", ROM0[$100]
EntryPoint:
    di
    jp Start
REPT $150 - $104
    db 0
ENDR

SECTION "Main", ROM0[$150]
Start:
	; shut sound off
	ld [rNR52], a

	; enable v-blank interrupt
	ld a, IEF_VBLANK
	ld [rIE], a
	
	; enable interrupts
	ei
	
	; wait for v-blank
	halt 
	
	; disable screen
	xor a
	ld [rLCDC], a
	
	; load bg palette [0=black, 1=dark gray, 2=light gray, 3=white]
	ld a, %11100100
	ld [rBGP], a
	
	; load 18 tiles
	; 0..15: 2x2 cell combinations
	; 16: sprite selection tile
	; 17: empty tile
	ld hl, _VRAM_BG_TILES
	ld de, Tiles
	ld bc, TilesEnd - Tiles
	call MemoryCopy
	
	; set scrolling to (32, 16)
	ld a, 32
	ld [rSCX], a
	ld a, 16
	ld [rSCY], a
	
	; clear screen (both buffers)
	ld hl, _SCRN0
	ld d, 17 ; empty tile
	ld bc, 32 * 32 * 2
	call MemorySet
	
	; init buffer 0
	ld hl, Buffer0
	ld de, DefaultMap
	ld bc, 32 * 32
	call MemoryCopy

	; display bg 9800
	ld a, LCDCF_ON | LCDCF_BGON | LCDCF_BG9800
	ld [rLCDC], a
	
	; enable h-blank interrupt in lcd stat
	ld a, STATF_MODE00
	ld [rSTAT], a

	; set old pointer to buffer0
	ld a, HIGH(Buffer0)
	ld [Old + 1], a

	; set new pointer to buffer1
	ld a, HIGH(Buffer1)
	ld [New + 1], a
	
	; shet video pointer to second tilemap
	ld a, HIGH(_SCRN1)
	ldh [Video + 1], a

	; set low byte of pointers to 0 (start of buffer is aligned)
	xor a
	ld [Old + 0], a
	ld [New + 0], a
	
.mainloop

	; enable v-blank and lcd stat interrupt for h-blank
	di
	ld a, IEF_VBLANK | IEF_LCDC
	ld [rIE], a
	ei

.topleft
	; handle top left corner
	ld bc, TopLeftCorner
	call Conway
	
	; advance to next cell in top row
	ld hl, New
	inc [hl]
	ld hl, Old
	inc [hl]

	; handle all cells in top row except corners
	ld a, 30
.top
	ld [XLoop], a

	; handle top row cell
	ld bc, TopRow
	call Conway
	
	; advance to next cell in top row
	ld hl, New
	inc [hl]
	ld hl, Old
	inc [hl]
	
	; decrement x loop
	ld a, [XLoop]
	dec a
	jr nz, .top

	; handle top right corner
.topright
	ld bc, TopRightCorner
	call Conway
	
	; advance pointers to next row
	ld hl, New
	inc [hl]
	ld hl, Old
	inc [hl]
	
	ld a, 30
.leftcolumn
	ld [YLoop], a
	
	; handle first element in row
	ld bc, LeftColumn
	call Conway
	
	; advance to next cell
	ld hl, New
	inc [hl]
	ld hl, Old
	inc [hl]

	ld a, 30
.inner
	ld [XLoop], a

	; handle element inside row
	ld bc, Inner
	call Conway
	
	; advance to next cell
	ld hl, New
	inc [hl]
	ld hl, Old
	inc [hl]
	
	; decrement x loop
	ld a, [XLoop]
	dec a
	jr nz, .inner
	
	; handle last element in row
.rightcolumn
	ld bc, RightColumn
	call Conway

	; advance to next row
	ld hl, New
	inc [hl]
	ld hl, Old
	inc [hl]
	jr nz, .nocarry
		ld hl, New + 1
		inc [hl]
		ld hl, Old + 1
		inc [hl]
.nocarry

	; decrement y loop
	ld a, [YLoop]
	dec a
	jr nz, .leftcolumn
	
	; handle bottom left element
.bottomleft
	ld bc, BottomLeftCorner
	call Conway
	
	; advance to next cell in bottom row
	ld hl, New
	inc [hl]
	ld hl, Old
	inc [hl]

	; handle all cells in bottom row except corners
	ld a, 30
.bottom
	ld [XLoop], a

	; handle top row cell
	ld bc, BottomRow
	call Conway
	
	; advance to next cell in top row
	ld hl, New
	inc [hl]
	ld hl, Old
	inc [hl]
	
	; decrement x loop
	ld a, [XLoop]
	dec a
	jr nz, .bottom

	; handle last element
.bottomright
	ld bc, BottomRightCorner
	call Conway

	; enable only v-blank interrupt
	di
	ld a, IEF_VBLANK
	ld [rIE], a
	ei

	; wait v-blank
	halt

	; swap pointers and display bg that has just been filled
	ld a, [New + 1]
	cp a, HIGH(Buffer1)
	jr c, .newToBuffer1
		ld a, HIGH(Buffer0)
		ld [New + 1], a
		ld a, HIGH(Buffer1)
		ld [Old + 1], a
		ld a, HIGH(_SCRN0)
		ldh [Video + 1], a

		; display bg 9C00
		ld a, LCDCF_ON | LCDCF_BGON | LCDCF_BG9C00
		ld [rLCDC], a

	jr .resetlow
.newToBuffer1
		ld a, HIGH(Buffer1)
		ld [New + 1], a
		ld a, HIGH(Buffer0)
		ld [Old + 1], a
		ld a, HIGH(_SCRN1)
		ldh [Video + 1], a
		
		; display bg 9800
		ld a, LCDCF_ON | LCDCF_BGON | LCDCF_BG9800
		ld [rLCDC], a
	
.resetlow
	; reset low bytes of pointers
	xor a
	ld [New], a
	ld [Old], a
	ldh [Video], a
		
	jp .mainloop

SECTION "Table based conway's game of life step for one cell", ROM0	
	; bc = pointer to neighbor offsets
	; destroys all registers
Conway:
	; reset alive counter
	xor a
	ld [Alive], a
	
.loop
	; load offset into de
	ld h, b
	ld l, c
	ld a, [hl+]
	ld e, a
	ld a, [hl+]
	ld d, a
	
	; check end of list
	or a, e ; (a still contains d)
	jp z, .decide
	
	; advance bc to next neighbor
	ld b, h
	ld c, l
	
	; load old pointer
	ld hl, Old
	ld a, [hl+]
	ld h, [hl]
	ld l, a
	
	; add offset
	add hl, de
	
	; load neighbor
	ld a, [hl]
	
	; check neighbor is alive
	or a, 0
	jr z, .loop
	
	; increment alive
	ld hl, Alive
	inc [hl]
	
	; continue to next neighbor
	jr .loop

.decide
	; load old pointer
	ld hl, Old
	ld a, [hl+]
	ld h, [hl]
	ld l, a
	
	; load status
	ld a, [hl]
	
	; check if alive
	or a, 0
	jr nz, .alive
	
.dead
	; load live neighbor count
	ld a, [Alive]
	
	; check if there is 3 neighbors
	cp a, 3
	jr nz, .writedead
	
.writealive
	; load new pointer
	ld hl, New
	ld a, [hl+]
	ld h, [hl]
	ld l, a
	
	; write alive 
	ld a, 1
	ld [hl], a
	
	ret
	
.alive
	; load live neighbor count
	ld a, [Alive]
	
	; check if there is 3 neighbors
	cp a, 3
	jr z, .writealive
	
	; check if there is 2 neighbors
	cp a, 2
	jr z, .writealive
	
.writedead
	; load new pointer
	ld hl, New
	ld a, [hl+]
	ld h, [hl]
	ld l, a
	
	; write alive 
	xor a ; a = 0
	ld [hl], a
	
	ret	

SECTION "V-Blank Interrupt Handler", ROM0[$40]
VBlankInterruptHandler:
	; save A and flags
	push af

	; set max number of cells to render
	ld a, 15
	ldh [RenderCount], a

	; render
	jp Render

SECTION "LCD Stat Interrupt Handler", ROM0[$48]
LCDStatInterruptHandler:
	; save A and flags
	push af

	; set max number of cells to render
	ld a, 5
	ldh [RenderCount], a

	; render
	jp Render
	
SECTION "Render", ROM0
Render:
	; save DE, BC, HL registers
	push de
	push bc
	push hl
	
.loop
	ld hl, RenderCount
	dec [hl]
	jr nz, .loop

	; restore DE, BC, HL registers
	pop hl
	pop bc
	pop de
	
	; restore A and flags, saved in interrupt handler
	pop af

	; return from v-blank or lcd interrupt
	reti
	
SECTION "Update Memory", WRAM0[$C000]
Buffer0: ds 32 * 32
Buffer1: ds 32 * 32
Old: ds 2
New: ds 2
Alive: ds 1
XLoop: ds 1
YLoop: ds 1
Tile: ds 1

SECTION "Render Memory", HRAM
Video: ds 2
RenderCount: ds 1

SECTION "Game of Life neighboring cells offset tables", ROM0
; for a looping grid of 32x32 cells
TopLeftCorner:     dw   1,    33,   32,   63, 31, 1023, 992, 993, 0
TopRightCorner:    dw -31,     1,   32,   31, -1,  991, 992, 961, 0
BottomLeftCorner:  dw   1,  -991, -992, -961, 31,   -1, -32, -31, 0
BottomRightCorner: dw -31, -1023, -992, -993, -1,  -33, -32, -63, 0
TopRow:            dw   1,    33,   32,   31, -1,  991, 992, 993, 0
BottomRow:         dw   1,  -991, -992, -993, -1,  -33, -32, -31, 0
LeftColumn:        dw   1,    33,   32,   63, 31,   -1, -32, -31, 0
RightColumn:       dw -31,     1,   32,   31, -1,  -33, -32, -63, 0
Inner:             dw   1,    33,   32,   31, -1,  -33, -32, -31, 0
	
SECTION "Graphics", ROM0
Tiles:
INCBIN "Tiles.bin"
TilesEnd: ds 0

DefaultMap:
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0