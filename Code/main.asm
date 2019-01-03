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
	
AddConstantToHL: MACRO
IF \1 == 1
	inc hl
ELIF \1 == -1
	dec hl
ELIF \1 > 0 && \1 <= 255
	ld a, l
	add a, \1
	ld l, a
	jr nc, .nocarry1\@
	inc h
.nocarry1\@
ELIF \1 > -255 && \1 < 0
	ld a, l
	sub a, -(\1)
	ld l, a
	jr nc, .nocarry2\@
	ld l, a
	dec h
.nocarry2\@
ELIF \1 > 255
	ld a, l
	add a, LOW(\1)
	ld l, a
	ld a, h
	adc a, HIGH(\1)
	ld h, a
ELIF \1 <= -255
	ld a, l
	sub a, LOW(-(\1))
	ld l, a
	ld a, h
	sbc a, HIGH(-(\1))
	ld h, a
ELSE
ENDC
ENDM
	
AddLiveNeighbors: MACRO
	; \1 offset 
	; \2 is mask for 2x2 cell
	; D must be high byte of a BitsSet table (for 0..15)
	; C register will be incremented with number of alive neighbors
	; moves HL with given offset
	; destroys A, E
	; does not touch B

	; load current 2x2 cell and mask out bits that are not neighbors
	AddConstantToHL \1
	ld a, [hl]
	and a, \2
	
	; count bits set
	ld e, a
	ld a, [de]

	; add to alive
	add a, c
	ld c, a
ENDM
	
Conway: MACRO
	; \1 = bit of target cell in 2x2 group
	; (\2, \3), (\4, \5), (\6, \7) = (offset to neighbor, neighbor mask)
	;
	; B will be updated with cell result
	; destroys all other registers

	; reset alive counter
	ld c, 0
	
	; Check all neighbors
	AddLiveNeighbors 0, (~(1 << \1)) & $F
	AddLiveNeighbors \2, \3
	AddLiveNeighbors \4 - \2, \5
	AddLiveNeighbors \6 - \4, \7
	AddConstantToHL -(\6)
	
	; if there are 3 neighbors, it's always alive
	ld a, c
	cp a, 3
	jr z, .alive\@
	
	; if there are only 2 neighbors, it's alive only if it was dead
	cp a, 2
	jr nz, .dead\@
	
	; load current old cell and test if alive
	ld a, [hl]
	bit \1, a
	jr z, .dead\@

.alive\@
	set \1, b
	
.dead\@
ENDM

SECTION "Load cell group and 8 neighbors to HRAM, then compute", ROM0	
	; \1..\8 offset to neighbors
	; destroys all registers
ConwayGroup: MACRO 

	ld d, HIGH(BitsSet)
	
	; load old pointer into hl
	ldh a, [Old]
	ld h, a
	ldh a, [Progress]
	ld l, a
	
	; reset result
	xor a
	ld b, a
	
	; compute all 4 cells in current 2x2 cell group
	Conway 0, \5, 10, \6,  8, \7, 12
	Conway 1, \1,  5, \7, 12, \8,  4
	Conway 2, \5, 10, \4,  2, \3,  3
	Conway 3, \1,  5, \3,  3, \2,  1
	
	; load new pointer
	ldh a, [New]
	ld h, a
	
	; save result to new buffer
	ld [hl], b
ENDM

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

	; set old and rendered pointers to buffer0
	ld a, HIGH(Buffer0)
	ldh [Old], a
	ldh [Rendered + 1], a

	; set new pointer to buffer1
	ld a, HIGH(Buffer1)
	ldh [New], a

	; set video pointer to first tilemap
	ld a, HIGH(_SCRN0)
	ldh [Video + 1], a
	
	; enable v-blank interrupt
	ld a, IEF_VBLANK
	ld [rIE], a

	xor a
	ldh [rIF], a
	
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
	
	; set scrolling to (0, 0)
	xor a
	ld [rSCX], a
	ld [rSCY], a
	
	; clear screen (both buffers)
	ld hl, _SCRN0
	ld d, 17 ; empty tile
	ld bc, 32 * 32 * 2
	call MemorySet
	
	; init buffer 0
	ld hl, Buffer0
	ld de, DefaultMap
	ld bc, 20 * 18
	call MemoryCopy
	
	; enable h-blank interrupt in lcd stat
	ld a, STATF_MODE00
	ld [rSTAT], a

	; enable screen but don't display anything yet
	ld a, LCDCF_ON
	ld [rLCDC], a
	
.mainloop
	; reset low bytes of pointers
	xor a
	ldh [Progress], a
	ldh [Rendered], a
	ldh [Video], a

	; start rendering
	ld a, 20
	ldh [TilesLeft], a
	ld a, 18
	ldh [LinesLeft], a
	
	; enable v-blank and lcd stat interrupt for h-blank
	; rendering routine is too slow for lcdc right now so disabled
	ld a, IEF_VBLANK; | IEF_LCDC
	ld [rIE], a
	xor a
	ei
	ldh [rIF], a

.topleft
	; handle top left corner
	ConwayGroup 1, 21, 20, 39, 19, 359, 340, 341
	
	; advance to next cell in top row
	ld hl, Progress
	inc [hl]

	; handle all cells in top row except corners
	ld a, 18
.top
	ld [XLoop], a

	; handle top row cell
	ConwayGroup 1, 21, 20, 19, -1, 339, 340, 341
	
	; advance to next cell in top row
	ld hl, Progress
	inc [hl]
	
	; loop horizontally
	ld a, [XLoop]
	dec a
	jp nz, .top

	; handle top right corner
.topright
	ConwayGroup -19, 1, 20, 19, -1, 339, 340, 321
	
	; advance pointers to next row
	ld hl, Progress
	inc [hl]
	
	ld a, 16
.leftcolumn
	ld [YLoop], a
	
	; handle first element in row
	ConwayGroup 1, 21, 20, 39, 19, -1, -20, -19
	
	; advance to next cell
	ld hl, Progress
	inc [hl]

	ld a, 18
.inner
	ld [XLoop], a

	; handle element inside row
	ConwayGroup 1, 21, 20, 19, -1, -21, -20, -19
	
	; advance to next cell
	ld hl, Progress
	inc [hl]
	jr nz, .noCarry
		ld hl, Old
		inc [hl]
		ld hl, New
		inc [hl]
.noCarry
	
	; loop horizontally
	ld a, [XLoop]
	dec a
	jp nz, .inner
	
	; handle last element in row
.rightcolumn
	ConwayGroup -19, 1, 20, 19, -1, -21, -20, -39

	; advance to next row
	ld hl, Progress
	inc [hl]
	
	; loop vertically
	ld a, [YLoop]
	dec a
	jp nz, .leftcolumn
	
	; handle bottom left element
.bottomleft
	ConwayGroup 1, -339, -340, -321, 19,  -1, -20, -19
	
	; advance to next cell in bottom row
	ld hl, Progress
	inc [hl]

	; handle all cells in bottom row except corners
	ld a, 18
.bottom
	ld [XLoop], a

	; handle top row cell
	ConwayGroup 1, -339, -340, -341, -1, -21, -20, -19
	
	; advance to next cell in top row
	ld hl, Progress
	inc [hl]
	
	; loop horizontally
	ld a, [XLoop]
	dec a
	jp nz, .bottom

	; handle last element
.bottomright
	ConwayGroup -19, -359, -340, -341, -1, -21, -20, -39
	
	; wait end of rendering (not necessary, update is way slower than rendering...)
.waitRender
	ldh a, [LinesLeft]
	ld b, a
	ldh a, [TilesLeft]
	or a, b
	jr z, .swap
	halt
	jr .waitRender

.swap
	; enable only v-blank interrupt
	di
	ld a, IEF_VBLANK
	ld [rIE], a
	xor a
	ldh [rIF], a
	
	; wait v-blank
	halt

	; check which buffer has just been rendered
	ldh a, [Old]
	cp a, HIGH(Buffer1)
	jr nc, .newToBuffer1

.newToBuffer0
	; set old and rendered pointers to buffer1
	ld a, HIGH(Buffer1)
	ldh [Old], a
	ldh [Rendered + 1], a

	; set new pointer to buffer0
	ld a, HIGH(Buffer0)
	ldh [New], a

	; set video pointer to first tilemap
	ld a, HIGH(_SCRN1)
	ldh [Video + 1], a

	; display bg 9800 that has just been filled
	ld a, LCDCF_ON | LCDCF_BGON | LCDCF_BG9800
	ld [rLCDC], a

	jr .resetLowBytes

.newToBuffer1
	; set old and rendered pointers to buffer0
	ld a, HIGH(Buffer0)
	ldh [Old], a
	ldh [Rendered + 1], a

	; set new pointer to buffer1
	ld a, HIGH(Buffer1)
	ldh [New], a

	; set video pointer to second tilemap
	ld a, HIGH(_SCRN0)
	ldh [Video + 1], a

	; display bg 9C00 that has just been filled
	ld a, LCDCF_ON | LCDCF_BGON | LCDCF_BG9C00
	ld [rLCDC], a

.resetLowBytes
	
	jp .mainloop

SECTION "V-Blank Interrupt Handler", ROM0[$40]
VBlankInterruptHandler:
	jr LCDStatInterruptHandler

SECTION "LCD Stat Interrupt Handler", ROM0[$48]
LCDStatInterruptHandler:
	; save registers
	push af
	push bc
    
	; check there are tiles to render
	ldh a, [LinesLeft]
	ld b, a
	ldh a, [TilesLeft]
	or b
	jr z, .exit

	push de
	push hl

.render	
	; load buffer pointer into DE
	ld hl, Rendered
	ld a, [hl+]
	ld d, [hl]
	ld e, a	

	; load video pointer into HL
	ld hl, Video
	ld a, [hl+]
	ld h, [hl]
	ld l, a
	
	; init tile counter in C
	ldh a, [TilesLeft]
	ld c, a
	
	; init line counter in B
	ldh a, [LinesLeft]
	ld b, a

.loop
	; check we can still render
	ldh a, [rSTAT]
	and a, STATF_BUSY
	jr nz, .finish

	; copy one byte
	ld a, [de]
	ld [hl+], a
	inc de

	; loop while there are tiles to render
	dec c
	jr nz, .loop

	; go to next line
	ld a, l
	add a, 32 - 20
	ld l, a
	jr nc, .nocarry
	inc h
.nocarry
	
	; loop while there are lines to render
	dec b
	jr z, .finish
	
	ld c, 20 ; reset tile counter

	jr .loop

.finish
	; save counters
	ld a, c
	ldh [TilesLeft], a
	ld a, b
	ldh [LinesLeft], a
	
	; save incremented video pointer and buffer pointer 
	ld a, l
	ldh [Video], a
	ld a, h
	ldh [Video + 1], a

	ld a, e
	ldh [Rendered], a
	ld a, d
	ldh [Rendered + 1], a

	; restore registers saved in interrupt handler
	pop hl
	pop de

.exit
	pop bc
	pop af

	; return from v-blank or lcd interrupt
	reti

; automata buffers with 4 cells per byte	
; 2x2 bytes per cell, bit ordering:
;  ___       ___
; |0 1|     |0 1|
; |2 3| eg. |1 0| is %0110 = 6
;  ‾‾‾       ‾‾‾
; bits 4, 5, 6 and 7 are not used
SECTION "Automata buffer 0", WRAM0, ALIGN[9]
Buffer0: ds 20 * 18
SECTION "Automata buffer 1", WRAM0, ALIGN[9]
Buffer1: ds 20 * 18

SECTION "Compute Memory", HRAM
New: ds 1 ; high byte of pointer to bufferX
Old: ds 1 ; high byte of pointer to bufferX
Progress: ds 1; low byte of pointer to bufferX, common to new and old
XLoop: ds 1
YLoop: ds 1

SECTION "Render Memory", HRAM
LinesLeft: ds 1     ; number of lines left to render
TilesLeft: ds 1     ; number of tiles left to render in current line
Video: ds 2         ; progressing pointer in tilemap (VRAM)
Rendered: ds 2      ; progressing pointer in old buffer

SECTION "Bits Set", ROM0, ALIGN[8]
BitsSet:
	db 0;  0 = 0000
	db 1;  1 = 0001
	db 1;  2 = 0010
	db 2;  3 = 0011
	db 1;  4 = 0100
	db 2;  5 = 0101
	db 2;  6 = 0110
	db 3;  7 = 0111
	db 1;  8 = 1000
	db 2;  9 = 1001
	db 2; 10 = 1010
	db 3; 11 = 1011
	db 2; 12 = 1100
	db 3; 13 = 1101
	db 3; 14 = 1110
	db 4; 15 = 1111

SECTION "Default Map", ROM0
DefaultMap:
	; 20x18 map with a glider on the top left corner
	db 2, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 3, 1, 0, 0, 0, 0, 0, 1, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 9,12, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 3, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 3, 1, 0, 3, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 5, 0,10,10, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 1,12, 6, 2,12, 4, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0,12, 4, 0,12, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 5, 0,10,10, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 1, 0, 2, 2, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 3, 1, 0, 3, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

SECTION "Graphics", ROM0
Tiles:
INCBIN "Tiles.bin"
TilesEnd: ds 0
