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

	; set old and rendered pointers to buffer0
	ld a, HIGH(Buffer0)
	ldh [Old + 1], a
	ldh [Rendered + 1], a

	; set new pointer to buffer1
	ld a, HIGH(Buffer1)
	ldh [New + 1], a

	; set video pointer to first tilemap
	ld a, HIGH(_SCRN0)
	ldh [Video + 1], a
	
	; reset low bytes of pointers (all buffers are aligned)
	xor a
	ldh [New], a
	ldh [Old], a
	ldh [Rendered], a
	ldh [Video], a
	
	; set total to render to 0 so that interrupts don't start rendering
	ldh [TotalToRender], a
	ldh [TotalToRender + 1], a

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
	
	; set scrolling to (0, 0)
	xor a
	ld [rSCX], a
	ld [rSCY], a
	
	; clear screen (both buffers)
	ld hl, _SCRN0
	ld d, 17 ; empty tile
	ld bc, 32 * 32 * 2
	call MemorySet
	
	; clear screen (both buffers)
	ld hl, _SCRN1
	ld d, 0 ; empty tile
	ld bc, 32 * 32
	call MemorySet
	
	; init buffer 0
	ld hl, Buffer0
	ld de, DefaultMap
	ld bc, 20 * 18
	call MemoryCopy
	
	; set total to render to start rendering
	ld a, LOW(20 * 18)
	ldh [TotalToRender], a
	ld a, HIGH(20 * 18)
	ldh [TotalToRender + 1], a

	; enable screen but don't display anything yet
	ld a, LCDCF_ON
	ld [rLCDC], a
	
	; enable h-blank interrupt in lcd stat
	ld a, STATF_MODE00
	ld [rSTAT], a
	
.mainloop

	; enable v-blank and lcd stat interrupt for h-blank
	di
	ld a, IEF_VBLANK; | IEF_LCDC
	ld [rIE], a
	ei

.topleft
	; handle top left corner
	ld hl, TopLeftCorner
	call ConwayGroup
	
	; advance to next cell in top row
	ld hl, New
	inc [hl]
	ld hl, Old
	inc [hl]

	; handle all cells in top row except corners
	ld a, 18
.top
	ld [XLoop], a

	; handle top row cell
	ld hl, TopRow
	call ConwayGroup
	
	; advance to next cell in top row
	ld hl, New
	inc [hl]
	ld hl, Old
	inc [hl]
	
	; loop horizontally
	ld a, [XLoop]
	dec a
	jr nz, .top

	; handle top right corner
.topright
	ld hl, TopRightCorner
	call ConwayGroup
	
	; advance pointers to next row
	ld hl, New
	inc [hl]
	ld hl, Old
	inc [hl]
	
	ld a, 16
.leftcolumn
	ld [YLoop], a
	
	; handle first element in row
	ld hl, LeftColumn
	call ConwayGroup
	
	; advance to next cell
	ld hl, New
	inc [hl]
	ld hl, Old
	inc [hl]

	ld a, 18
.inner
	ld [XLoop], a

	; handle element inside row
	ld hl, Inner
	call ConwayGroup
	
	; advance to next cell
	ld hl, New
	inc [hl]
	ld hl, Old
	inc [hl]
	jr nz, .noCarry
		inc hl ; old+1
		inc [hl]
		ld hl, New + 1
		inc [hl]
.noCarry
	
	; loop horizontally
	ld a, [XLoop]
	dec a
	jr nz, .inner
	
	; handle last element in row
.rightcolumn
	ld hl, RightColumn
	call ConwayGroup

	; advance to next row
	ld hl, New
	inc [hl]
	ld hl, Old
	inc [hl]
	
	; loop vertically
	ld a, [YLoop]
	dec a
	jr nz, .leftcolumn
	
	; handle bottom left element
.bottomleft
	ld hl, BottomLeftCorner
	call ConwayGroup
	
	; advance to next cell in bottom row
	ld hl, New
	inc [hl]
	ld hl, Old
	inc [hl]

	; handle all cells in bottom row except corners
	ld a, 18
.bottom
	ld [XLoop], a

	; handle top row cell
	ld hl, BottomRow
	call ConwayGroup
	
	; advance to next cell in top row
	ld hl, New
	inc [hl]
	ld hl, Old
	inc [hl]
	
	; loop horizontally
	ld a, [XLoop]
	dec a
	jr nz, .bottom

	; handle last element
.bottomright
	ld hl, BottomRightCorner
	call ConwayGroup
	
	; increment old pointer to first byte after buffer
	ld hl, Old
	inc [hl]

	; wait end of rendering
.waitRenderHigh
	; check high byte of TotalToRender
	ldh a, [TotalToRender + 1]
	or a
	jr z, .waitRenderLow
	halt
	jr .waitRenderHigh
	
.waitRenderLow
	; check low byte of TotalToRender
	ldh a, [TotalToRender]
	or a
	jr z, .swap
	halt
	jr .waitRenderLow

.swap
	; enable only v-blank interrupt
	di
	ld a, IEF_VBLANK
	ld [rIE], a
	ei
	
	; wait v-blank
	halt

	; check which buffer has just been rendered
	ldh a, [Old + 1]
	cp a, HIGH(Buffer1)
	jr nc, .newToBuffer1

.newToBuffer0
	; set old and rendered pointers to buffer1
	ld a, HIGH(Buffer1)
	ldh [Old + 1], a
	ldh [Rendered + 1], a

	; set new pointer to buffer0
	ld a, HIGH(Buffer0)
	ldh [New + 1], a

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
	ldh [Old + 1], a
	ldh [Rendered + 1], a

	; set new pointer to buffer1
	ld a, HIGH(Buffer1)
	ldh [New + 1], a

	; set video pointer to second tilemap
	ld a, HIGH(_SCRN0)
	ldh [Video + 1], a

	; display bg 9C00 that has just been filled
	ld a, LCDCF_ON | LCDCF_BGON | LCDCF_BG9C00
	ld [rLCDC], a

.resetLowBytes
	; reset low bytes of pointers
	xor a
	ldh [New], a
	ldh [Old], a
	ldh [Rendered], a
	ldh [Video], a
	
	; set total to render to start rendering
	ld a, LOW(20 * 18)
	ldh [TotalToRender], a
	ld a, HIGH(20 * 18)
	ldh [TotalToRender + 1], a
	
	jp .mainloop

SECTION "Load cell group and 8 neighbors to HRAM, then compute", ROM0	
	; hl = pointer to neighbor offsets
	; destroys all registers
ConwayGroup:
	; save pointer to neighbors
	push hl

	; pointer to HRAM
	ld c, LOW(Cells)
	
	; load old pointer into hl
	ld hl, Old
	ld a, [hl+]
	ld h, [hl]
	ld l, a

	; load cell group
	ld a, [hl]

	; write cell group into hram
	ld [$FF00+c], a

	; increment hram pointer
	inc c
	
	; counter to 8
	ld b, 8
	
.loop
	; restore pointer to neighbors
	pop hl

	; load offset into de
	ld a, [hl+]
	ld e, a
	ld a, [hl+]
	ld d, a

	; save incremented pointer to neighbors
	push hl
	
	; load old pointer into hl
	ld hl, Old
	ld a, [hl+]
	ld h, [hl]
	ld l, a
	
	; add offset
	add hl, de
	
	; load neighbor
	ld a, [hl]
	
	; store neighbor into hram
	ld [$FF00+c], a
	
	; increment pointer into hram
	inc c
	
	; decrement counter
	dec b
	
	; continue to next neighbor if any
	jr nz, .loop

.compute
	; remove pointer to offsets from stack
	pop hl
	
	; reset result
	xor a
	ldh [Result], a
	
	; compute all 4 cells
	ld hl, TopLeftMask
	call Conway
	
	ld hl, TopRightMask
	call Conway
	
	ld hl, BottomLeftMask
	call Conway
	
	ld hl, BottomRightMask
	call Conway
	
	; load new pointer
	ld hl, New
	ld a, [hl+]
	ld h, [hl]
	ld l, a
	
	; load result
	ldh a, [Result]
	
	; save result to new buffer
	ld [hl], a
	
	ret	
	
SECTION "Conway cell compute", ROM0
	; hl = pointer to cell group masks
Conway:

	; reset alive counter
	xor a
	ldh [Alive], a
	
	; load cells pointer
	ld c, LOW(Cells)
	
.loop
	; load next mask
	ld a, [hl+]
	
	; move mask to d
	ld d, a
	
	; load data
	ld a, [$FF00+c]
	
	; mask data
	and a, d
	
	; count bits set
	ld de, BitsSet
	add a, e
	ld e, a
	ld a, [de]
	ld b, a
	
	; add to alive
	ldh a, [Alive]
	add a, b
	ldh [Alive], a
	
	; increment cells pointer
	inc c
		
	; loop over all neighbors
	ld a, c
	cp a, LOW(Cells + 9)
	jr nz, .loop
	
.decide
	; load current group mask
	ld b, [hl]
	
	; load current cell group
	ldh a, [Cells]
	
	; mask data
	and a, b
	
	; load alive count
	ldh a, [Alive]

	jr z, .dead
.alive
	; check if there is two or three neighbors
	bit 1, a
	ret z
	
.writealive
	; add mask to result
	ldh a, [Result]
	or a, b
	ldh [Result], a
	ret
	
.dead
	; check if there is three neighbors
	cp a, 3
	jr z, .writealive

.writedead	
	ret	

SECTION "V-Blank Interrupt Handler", ROM0[$40]
VBlankInterruptHandler:
	; save a
	push af

	; set max number of cells to render
	ld a, 64
	ldh [MaxRender], a
    
	; render
	jp Render

SECTION "LCD Stat Interrupt Handler", ROM0[$48]
LCDStatInterruptHandler:
	; save a
	push af

	; set max number of cells to render
	ld a, 1
	ldh [MaxRender], a
    
	; render
	jp Render
	
SECTION "Render", ROM0
Render:
	; save registers
	push de
	push bc
	push hl
	
	; load counter into b
	ldh a, [MaxRender]
	ld b, a
	
	; check there is more than 255 bytes to render left
	ldh a, [TotalToRender + 1]
	and a
	jr nz, .render
	
	; check there is anything at all to render
	ldh a, [TotalToRender]
	and a
	jr z, .exit

	; check we're not trying to render more than what's left to render
	cp a, b
	jr nc, .render
	
	; render only what's left to
	ld b, a
	
.render
	; save render count so that we can decrement total later
	push bc
	
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
	
	; set c to number of tiles before next line
	ld a, l
	and a, $E0
	add a, 20
	sub a, l
	ld c, a
	
.loop
	; copy one byte
	ld a, [de]
	ld [hl+], a
	inc de
	
	; check if we need to go to next line
	dec c
	jr nz , .countdown
	
	; go to next line
	push de
	ld de, 32 - 20
	add hl, de
	pop de
	ld c, 20

	; loop over if not finished
.countdown
	dec b
	jr nz, .loop	

	; save incremented video and buffer pointers
	ld a, l
	ldh [Video], a
	ld a, h
	ldh [Video + 1], a
	
	ld a, e
	ldh [Rendered], a
	ld a, d
	ldh [Rendered + 1], a
	
	; restore max render
	pop bc
	
	; decrement total to render
	ldh a, [TotalToRender]
	sub a, b
	ldh [TotalToRender], a
	jr nc, .exit
	ld hl, TotalToRender + 1
	dec [hl]

.exit
	; restore registers
	pop hl
	pop bc
	pop de
	
	; restore A saved in interrupt handler
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
Old: ds 2 ; pointer to bufferX
New: ds 2 ; pointer to bufferX
Alive: ds 1
XLoop: ds 1
YLoop: ds 1
Cells: ds 9
Result: ds 1

SECTION "Render Memory", HRAM
MaxRender: ds 1     ; max number of tiles to render before leaving
TotalToRender: ds 2 ; total number of tiles to render left
Video: ds 2         ; pointer to tilemap
Rendered: ds 2      ; pointer to bufferX

SECTION "Game of Life neighboring cells offset tables", ROM0
; for a looping grid of 20x18 cells
; order matters         R,   BR,    B,   BL,  L,  TL,   T,  TR
TopLeftCorner:     dw   1,   21,   20,   39, 19, 359, 340, 341
TopRightCorner:    dw -19,    1,   20,   19, -1, 339, 340, 321
BottomLeftCorner:  dw   1, -339, -340, -321, 19,  -1, -20, -19
BottomRightCorner: dw -19, -359, -340, -341, -1, -21, -20, -39
TopRow:            dw   1,   21,   20,   19, -1, 339, 340, 341
BottomRow:         dw   1, -339, -340, -341, -1, -21, -20, -19
LeftColumn:        dw   1,   21,   20,   39, 19,  -1, -20, -19
RightColumn:       dw -19,    1,   20,   19, -1, -21, -20, -39
Inner:             dw   1,   21,   20,   19, -1, -21, -20, -19

SECTION "Game of Life neighboring masks", ROM0
; order matters      I,  R, BR,  B, BL,  L, TL,  T, TR, SELF 
TopLeftMask:     db 14,  0,  0,  0,  0, 10,  8, 12,  0,    1
TopRightMask:    db 13,  5,  0,  0,  0,  0,  0, 12,  4,    2
BottomLeftMask:  db 11,  0,  0,  3,  2, 10,  0,  0,  0,    4
BottomRightMask: db  7,  5,  1,  3,  0,  0,  0,  0,  0,    8

SECTION "Bits Set", ROM0, ALIGN[4]
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
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 3, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

SECTION "Graphics", ROM0
Tiles:
INCBIN "Tiles.bin"
TilesEnd: ds 0
