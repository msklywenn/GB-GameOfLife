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

AddLiveNeighbors: MACRO
	; H register will be incremented with number of alive neighbors
	; destroys A, B, C, E, does not touch L nor D
	; D must be high byte of a BitsSet table (for 0..15)

	; load current 2x2 cell and mask out bits that are not neighbors
	ld c, LOW(Cells + \1)
	ld a, [$FF00+c]
	ld b, \2
	and a, b
	
	; count bits set
	ld e, a
	ld a, [de]

	; add to alive
	add a, h
	ld h, a
ENDM
	
Conway: MACRO
	; \1 = mask for neighbors in inner cell
	; \2 = first useful neighbor 2x2 cell
	; \3 = mask for first useful neighbor 2x2 cell
	; \4 = mask for second useful neighbor 2x2 cell
	; \5 = mask for third useful neighbor 2x2 cell
	;
	; L will be updated with cell result
	; destroys all other registers

	; reset alive counter
	ld h, 0
	
	; set high byte of DE to BitsSet high address
	ld d, HIGH(BitsSet)
	
	; Check all neighbors
	AddLiveNeighbors 0, \1
	AddLiveNeighbors (1 + (\2 + 0) % 8), \3
	AddLiveNeighbors (1 + (\2 + 1) % 8), \4
	AddLiveNeighbors (1 + (\2 + 2) % 8), \5
	
	; load current group mask
	ld b, (~\1) & $F
	
	; load current cell group
	ldh a, [Cells]
	
	; mask data
	and a, b
	
	; put alive neighbors in A
	ld a, h

	jr z, .dead\@
;.alive
	; check if there is two or three neighbors
	cp a, 2
	jr c, .writedead\@
	cp a, 4
	jr nc, .writedead\@
	
.writealive\@
	; add mask to result
	ld a, l
	add a, b
	ld l, a
	jr .writedead\@
	
.dead\@
	; check if there is three neighbors
	cp a, 3
	jr z, .writealive\@

.writedead\@
ENDM

LoadCellToHRAM: MACRO
	; \1 = offset to Old pointer
	; destroys A, D, E, H, L
	; increments C
	
	; load old pointer into hl
	ld hl, Old
	ld a, [hl+]
	ld h, [hl]
	ld l, a
	
	; add offset
IF \1 != 0
	ld de, \1
	add hl, de
ENDC
	
	; load neighbor
	ld a, [hl]
	
	; store in HRAM
	ld [$FF00+c], a
	
	; increment hram pointer
	inc c
ENDM

SECTION "Load cell group and 8 neighbors to HRAM, then compute", ROM0	
	; \1..\8 offset to neighbors
	; destroys all registers
ConwayGroup: MACRO 

	; pointer to HRAM
	ld c, LOW(Cells)
	
	; load current 2x2 cell then neighbor 2x2 cells to HRAM from old buffer
	LoadCellToHRAM 0
	LoadCellToHRAM \1
	LoadCellToHRAM \2
	LoadCellToHRAM \3
	LoadCellToHRAM \4
	LoadCellToHRAM \5
	LoadCellToHRAM \6
	LoadCellToHRAM \7
	LoadCellToHRAM \8

	; reset result
	xor a
	ld l, a
	
	; compute all 4 cells in current 2x2 cell
	Conway 14, 4, 10, 8, 12
	Conway 13, 6, 12, 4, 5
	Conway 11, 2, 3, 2, 10
	Conway 7, 0, 5, 1, 3
	
	; move result to B
	ld b, l
	
	; load new pointer
	ld hl, New
	ld a, [hl+]
	ld h, [hl]
	ld l, a
	
	; save result to new buffer
	ld [hl], b
ENDM

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
	
	; set lines and tiles left to 0 to avoid rendering in interrupts 
	ldh [LinesLeft], a
	ldh [TilesLeft], a

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
	ld a, 18
	ldh [LinesLeft], a
	ld a, 20
	ldh [TilesLeft], a
	
	; enable h-blank interrupt in lcd stat
	ld a, STATF_MODE00
	ld [rSTAT], a

	; enable screen but don't display anything yet
	ld a, LCDCF_ON
	ld [rLCDC], a
	
.mainloop

	; enable v-blank and lcd stat interrupt for h-blank
	ld a, IEF_VBLANK; | IEF_LCDC
	ld [rIE], a
	xor a
	ei
	ldh [rIF], a

.topleft
	; handle top left corner
	ConwayGroup 1, 21, 20, 39, 19, 359, 340, 341
	
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
	ConwayGroup 1, 21, 20, 19, -1, 339, 340, 341
	
	; advance to next cell in top row
	ld hl, New
	inc [hl]
	ld hl, Old
	inc [hl]
	
	; loop horizontally
	ld a, [XLoop]
	dec a
	jp nz, .top

	; handle top right corner
.topright
	ConwayGroup -19, 1, 20, 19, -1, 339, 340, 321
	
	; advance pointers to next row
	ld hl, New
	inc [hl]
	ld hl, Old
	inc [hl]
	
	ld a, 16
.leftcolumn
	ld [YLoop], a
	
	; handle first element in row
	ConwayGroup 1, 21, 20, 39, 19, -1, -20, -19
	
	; advance to next cell
	ld hl, New
	inc [hl]
	ld hl, Old
	inc [hl]

	ld a, 18
.inner
	ld [XLoop], a

	; handle element inside row
	ConwayGroup 1, 21, 20, 19, -1, -21, -20, -19
	
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
	jp nz, .inner
	
	; handle last element in row
.rightcolumn
	ConwayGroup -19, 1, 20, 19, -1, -21, -20, -39

	; advance to next row
	ld hl, New
	inc [hl]
	ld hl, Old
	inc [hl]
	
	; loop vertically
	ld a, [YLoop]
	dec a
	jp nz, .leftcolumn
	
	; handle bottom left element
.bottomleft
	ConwayGroup 1, -339, -340, -321, 19,  -1, -20, -19
	
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
	ConwayGroup 1, -339, -340, -341, -1, -21, -20, -19
	
	; advance to next cell in top row
	ld hl, New
	inc [hl]
	ld hl, Old
	inc [hl]
	
	; loop horizontally
	ld a, [XLoop]
	dec a
	jp nz, .bottom

	; handle last element
.bottomright
	ConwayGroup -19, -359, -340, -341, -1, -21, -20, -39
	
	; increment old pointer to first byte after buffer
	ld hl, Old
	inc [hl]

	; wait end of rendering
.waitLines
	; check high byte of TotalToRender
	ldh a, [LinesLeft]
	or a
	jr z, .waitTiles
	halt
	jr .waitLines
	
.waitTiles
	; check low byte of TotalToRender
	ldh a, [TilesLeft]
	or a
	jr z, .swap
	halt
	jr .waitTiles

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
	
	; set total to render to restart rendering
	ld a, 20
	ldh [TilesLeft], a
	ld a, 18
	ldh [LinesLeft], a
	
	jp .mainloop

SECTION "V-Blank Interrupt Handler", ROM0[$40]
VBlankInterruptHandler:
	; save registers
	push af
	push bc
	push de
	push hl
    
	; render
	jp Render

SECTION "LCD Stat Interrupt Handler", ROM0[$48]
LCDStatInterruptHandler:
	; save registers
	push af
	push bc
	push de
	push hl
    
	; render
	jp Render
	
SECTION "Render", ROM0
Render:	
	; check there are tiles to render
	ldh a, [LinesLeft]
	ld b, a
	ldh a, [TilesLeft]
	or b
	jr z, .exit

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

	; set c to point to tiles left to render
.nextline
	ld c, LOW(TilesLeft)

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
	ld a, [$FF00+c]
	dec a
	ld [$FF00+c], a
	jr nz, .loop

	; go to next line
	ld a, l
	add a, 32 - 20
	ld l, a
	jr nc, .nocarry
	inc h
.nocarry
	
	; loop while there are lines to render
	ld c, LOW(LinesLeft)
	ld a, [$FF00+c]
	dec a
	ld [$FF00+c], a
	jr z, .finish

	ld a, 20
	ldh [TilesLeft], a
	ld c, a

	jr .nextline

	; save incremented video and buffer pointers
.finish
	ld a, l
	ldh [Video], a
	ld a, h
	ldh [Video + 1], a

	ld a, e
	ldh [Rendered], a
	ld a, d
	ldh [Rendered + 1], a

.exit
	; restore registers saved in interrupt handler
	pop hl
	pop de
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
Old: ds 2 ; pointer to bufferX
New: ds 2 ; pointer to bufferX
XLoop: ds 1
YLoop: ds 1
Cells: ds 9 ; cells loaded from old buffer, order is: self then right, clockwise

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
