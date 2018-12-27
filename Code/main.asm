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

	; set old pointer to buffer0
	ld a, HIGH(Buffer0)
	ldh [Old + 1], a

	; set new pointer to buffer1
	ld a, HIGH(Buffer1)
	ldh [New + 1], a

	; set rendered to buffer1 also
	ldh [Rendered + 1], a
	
	; set video pointer to second tilemap
	ld a, HIGH(_SCRN1)
	ldh [Video + 1], a

	; set low byte of pointers to 0 (all buffers are aligned)
	xor a
	ldh [Old + 0], a
	ldh [New + 0], a
	ldh [Rendered + 0], a
	ldh [Video + 0], a

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
	
	; set scrolling to (-16, -8)
	ld a, -16
	ld [rSCX], a
	ld a, -8
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
	
.mainloop

	; enable v-blank and lcd stat interrupt for h-blank
	di
	ld a, IEF_VBLANK ;| IEF_LCDC
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
		inc hl ; old + 1
		inc [hl]
		ld hl, New + 1
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
	
	; increment new pointer to first byte after buffer
	ld hl, New
	inc [hl]
	inc hl
	inc [hl]

	; enable only v-blank interrupt
	di
	ld a, IEF_VBLANK
	ld [rIE], a
	ei

	; wait end of rendering
.waitRender
	halt
	; compare high byte of rendered and new pointers
	ldh a, [Rendered + 1]
	ld b, a
	ldh a, [New + 1]
	cp a, b
	jr nz, .waitRender
	; compare low byte of rendered and new pointers
	ldh a, [Rendered]
	ld b, a
	ldh a, [New]
	cp a, b
	jr nz, .waitRender

	; swap pointers and display bg that has just been filled
	ldh a, [New + 1]
	cp a, HIGH(Buffer1)
	jr z, .newToBuffer1
		ld a, HIGH(Buffer0)
		ldh [New + 1], a
		ldh [Rendered + 1], a
		ld a, HIGH(Buffer1)
		ldh [Old + 1], a
		ld a, HIGH(_SCRN0)
		ldh [Video + 1], a

		; display bg 9C00
		ld a, LCDCF_ON | LCDCF_BGON | LCDCF_BG9C00
		ld [rLCDC], a

	jr .resetlow
.newToBuffer1
		ld a, HIGH(Buffer1)
		ldh [New + 1], a
		ldh [Rendered + 1], a
		ld a, HIGH(Buffer0)
		ldh [Old + 1], a
		ld a, HIGH(_SCRN1)
		ldh [Video + 1], a
		
		; display bg 9800
		ld a, LCDCF_ON | LCDCF_BGON | LCDCF_BG9800
		ld [rLCDC], a
	
.resetlow
	; reset low bytes of pointers
	xor a
	ldh [New], a
	ldh [Old], a
	ldh [Video], a
	ldh [Rendered], a
		
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
	jr z, .decide
	
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
	ld a, 10
	ldh [RenderCount], a

	; render
	jp Render

SECTION "LCD Stat Interrupt Handler", ROM0[$48]
LCDStatInterruptHandler:
	; save A and flags
	push af

	; set max number of cells to render
	ld a, 1
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
	; compare rendered and new pointers
	; compare high byte first
	ldh a, [New + 1]
	ld b, a
	ldh a, [Rendered + 1]
	cp a, b
	jr c, .render
	
	; compare low byte
	ldh a, [Rendered  + 0]
	ld b, a
	ldh a, [New + 0]
	sub a, b
	jr z, .exit
	
	; check there are at least two bytes to render
	dec a
	jr z, .exit

	; load rendered pointer
.render
	ld hl, Rendered
	ld a, [hl+]
	ld h, [hl]
	ld l, a
	ld d, l
	
	; read two bytes in bits 0 and 1 of C
	ld a, [hl+]
	ld b, a
	ld a, [hl+]
	sla a
	or a, b
	
	; store read data into C
	ld c, a
	
	; test bit 6 of address to determine if we're on odd or even row 
	bit 5, d

	; store incremented rendered pointer
	ld a, h
	ld [Rendered + 1], a
	ld a, l
	ld [Rendered + 0], a
	
	jr z, .even
.odd:
	; move read data into bits 2 and 3
	sla c
	sla c
	
	; load video pointer
	ld hl, Video
	ld a, [hl+]
	ld h, [hl]
	ld l, a
	
	; load current data
	ld a, [hl]
	
	; add read data
	or a, c
	
	; write updated data into video ram
	ld [hl], a
	
	; increment video pointer by 1
	ld hl, Video
	inc [hl]

	; check end of line
	ld a, [Rendered]
	and %11111
	jr nz, .next

	; increment video pointer by 16 to go to next line
	ldh a, [Video]
	add a, 16
	ldh [Video], a
	jr nc, .next
		ld hl, Video + 1
		inc [hl]

	jr .next
.even:
	; load video pointer
	ld hl, Video
	ld a, [hl+]
	ld h, [hl]
	ld l, a
	
	; write data into video ram
	ld [hl], c

	; increment video pointer by 1
	ld hl, Video
	inc [hl]

	; check end of line
	ld a, [Rendered]
	and %11111
	jr nz, .next
		
	; move back to beginning of video line
	ldh a, [Video]
	add a, -16
	ldh [Video], a
	
	; decrement render count
.next
	ld hl, RenderCount
	dec [hl]
	jr nz, .loop

.exit
	; restore DE, BC, HL registers
	pop hl
	pop bc
	pop de
	
	; restore A and flags, saved in interrupt handler
	pop af

	; return from v-blank or lcd interrupt
	reti
	
SECTION "Automata buffers", WRAM0[$C000]
Buffer0: ds 32 * 32
Buffer1: ds 32 * 32

SECTION "Update Memory", HRAM
; update
Old: ds 2
New: ds 2
Alive: ds 1
XLoop: ds 1
YLoop: ds 1
; render
RenderCount: ds 1
Video: ds 2
Rendered: ds 2

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

SECTION "Default Map", ROM0
DefaultMap:
	db 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
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

SECTION "Graphics", ROM0
Tiles:
INCBIN "Tiles.bin"
TilesEnd: ds 0
