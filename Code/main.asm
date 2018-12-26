INCLUDE "hardware.inc"
INCLUDE "utils.inc"

_VRAM_BG_TILES EQU $9000
_SCREEN_BYTES EQU SCRN_X_B * SCRN_Y_B

SECTION "V-Blank Interrupt Handler", ROM0[$40]
VBlankInterruptHandler:
	reti

SECTION "LCD Stat Interrupt Handler", ROM0[$48]
LCDStatInterruptHandler:
	reti

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
	; enable v-blank interrupt
	ld a, IEF_VBLANK
	ld [rIE], a
	
	; enable interrupts
	ei
	
	; shut sound off
	ld [rNR52], a
	
	; wait for VBL
	halt 
	
	; disable screen
	xor a
	ld [rLCDC], a
	
	; load bg palette [0=black, 1=dark gray, 2=light gray, 3=white]
	ld a, %11100100
	ld [rBGP], a
	
	; load tiles
	MemCopy _VRAM_BG_TILES, Tile0, 16
	MemCopy _VRAM_BG_TILES + 16, Tile1, 16
	MemCopy _VRAM_BG_TILES + 32, Tile2, 16
	
	; set scrolling to (0, 0)
	xor a
	ld [rSCY], a
	ld [rSCX], a
	
	; init ram
	MemCopy _SCRN0, DefaultMap, 32 * 32
	
	; enable screen with background
	;ld a, LCDCF_ON | LCDCF_BGON
	;ld [rLCDC], a

	; disable v-blank interrupt, enable lcd stat interrupt
	;ld a, IEF_LCDC
	;ld [rIE], a

	; enable h-blank interrupt in lcd stat
	ld a, STATF_MODE00
	ld [rSTAT], a

	; set old pointer to first tilemap
	ld a, $98
	ld [OldPointer + 1], a

	; set new pointer to second tilemap
	ld a, $9C
	ld [NewPointer + 1], a
	
	; set low bytes of pointers to 0
	xor a
	ld [NewPointer], a
	ld [OldPointer], a

.mainloop

	; disable screen
	xor a
	ld [rLCDC], a

	; handle top left corner
	ld bc, TopLeftCorner
	call Conway
	
	; advance to next cell in top row
	ld hl, NewPointer
	inc [hl]
	ld hl, OldPointer
	inc [hl]

	; handle all cells in top row except corners
	ld a, 18
.top
	ld [XLoop], a

	; handle top row cell
	ld bc, TopRow
	call Conway
	
	; advance to next cell in top row
	ld hl, NewPointer
	inc [hl]
	ld hl, OldPointer
	inc [hl]
	
	; decrement x loop
	ld a, [XLoop]
	dec a
	jr nz, .top

	; handle top right corner
	ld bc, TopRightCorner
	call Conway
	
	; advance pointers to next row
	ld a, [OldPointer]
	add a, 32 - 20 + 1
	ld [OldPointer], a
	; ld a, [NewPointer] ; unnecessary, both pointers are in sync and aligned the same
	; add a, 32 - 20     ; unnecessary, both pointers are in sync and aligned the same
	ld [NewPointer], a
	
	ld a, 16
.columns
	ld [YLoop], a
	
	; handle first element in row
	ld bc, LeftColumn
	call Conway
	
	; advance to next cell
	ld hl, NewPointer
	inc [hl]
	ld hl, OldPointer
	inc [hl]

	ld a, 18
.inner
	ld [XLoop], a

	; handle element inside row
	ld bc, Inner
	call Conway
	
	; advance to next cell
	ld hl, NewPointer
	inc [hl]
	ld hl, OldPointer
	inc [hl]
	
	; decrement x loop
	ld a, [XLoop]
	dec a
	jr nz, .inner
	
	; handle last element in row
	ld bc, RightColumn
	call Conway

	; advance to next row
	ld a, [NewPointer]
	add a, 32 - 20 + 1
	ld [NewPointer], a
	ld [OldPointer], a
	jr nc, .nocarry
		ld hl, NewPointer + 1
		inc [hl]
		ld hl, OldPointer + 1
		inc [hl]
.nocarry

	; decrement y loop
	ld a, [YLoop]
	dec a
	jr nz, .columns
	
	; handle bottom left element
	ld bc, BottomLeftCorner
	call Conway
	
	; advance to next cell in bottom row
	ld hl, NewPointer
	inc [hl]
	ld hl, OldPointer
	inc [hl]

	; handle all cells in bottom row except corners
	ld a, 18
.bottom
	ld [XLoop], a

	; handle top row cell
	ld bc, BottomRow
	call Conway
	
	; advance to next cell in top row
	ld hl, NewPointer
	inc [hl]
	ld hl, OldPointer
	inc [hl]
	
	; decrement x loop
	ld a, [XLoop]
	dec a
	jr nz, .bottom

	; handle last element
	ld bc, BottomRightCorner
	call Conway
	
	; swap buffers and reset pointers
	ld a, [NewPointer + 1]
	cp a, $9C
	jr c, .newto9C00
		ld a, $98
		ld [NewPointer + 1], a
		ld a, $9C
		ld [OldPointer + 1], a
		
		; display bg 9C00
		ld a, LCDCF_ON | LCDCF_BGON | LCDCF_BG9C00
		ld [rLCDC], a

	jr .resetlow
.newto9C00
		ld a, $9C
		ld [NewPointer + 1], a
		ld a, $98
		ld [OldPointer + 1], a
		
		; display bg 9800
		ld a, LCDCF_ON | LCDCF_BGON | LCDCF_BG9800
		ld [rLCDC], a
	
.resetlow
	; reset low bytes of pointers
	xor a
	ld [NewPointer], a
	ld [OldPointer], a
	
.waitPressA
	halt
	halt
	halt
	;halt
	;halt
	;halt
	;halt
	;ld a, P1F_4
	;ld [rP1], a
	;ld a, [rP1]
	;ld a, [rP1]
	;ld a, [rP1]
	;ld a, [rP1]
	;cpl
	;and a, 1
	;jr z, .waitPressA

	jp .mainloop
	
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
	or e ; (a still contains d)
	jp z, .decide
	
	; advance bc to next neighbor
	ld b, h
	ld c, l
	
	; load old pointer
	ld hl, OldPointer
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
	ld hl, OldPointer
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
	ld hl, NewPointer
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
	ld hl, NewPointer
	ld a, [hl+]
	ld h, [hl]
	ld l, a
	
	; write alive 
	xor a ; a = 0
	ld [hl], a
	
	ret	
	
SECTION "Work", WRAM0
OldPointer: ds 2
NewPointer: ds 2
Alive: ds 1
XLoop: ds 1
YLoop: ds 1

SECTION "Game Of Life Offset Tables", ROM0
; for a looping grid of 20x18 cells, with stride 32
TopLeftCorner:     dw   1,   33,   32,   51, 19, 563, 544, 545, 0
TopRightCorner:    dw -19,   13,   32,   31, -1, 543, 544, 525, 0
BottomLeftCorner:  dw   1, -543, -544, -525, 19, -13, -32, -31, 0
BottomRightCorner: dw -19, -563, -544, -545, -1, -33, -32, -51, 0 
TopRow:            dw   1,   33,   32,   31, -1, 543, 544, 545, 0
BottomRow:         dw   1, -543, -544, -545, -1, -33, -32, -31, 0
LeftColumn:        dw   1,   33,   32,   51, 19, -13, -32, -31, 0
RightColumn:       dw -19,   13,   32,   31, -1, -33, -32, -51, 0
Inner:             dw   1,   33,   32,   31, -1, -33, -32, -31, 0
	
SECTION "Graphics", ROM0
Tile0: db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
Tile1: db $00, $FF, $00, $FF, $00, $FF, $00, $FF, $00, $FF, $00, $FF, $00, $FF, $00, $FF
Tile2: db $FF, $00, $FF, $00, $FF, $00, $FF, $00, $FF, $00, $FF, $00, $FF, $00, $FF, $00
DefaultMap:
; pulsar period 3
;	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;	db 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;	db 0, 0, 1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;	db 0, 0, 1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;	db 0, 0, 1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;	db 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;	db 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;	db 0, 0, 1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;	db 0, 0, 1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;	db 0, 0, 1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;	db 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
; glider
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
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
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0