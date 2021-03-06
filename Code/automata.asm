INCLUDE "hardware.inc"

; automata buffers with 4 cells per byte	
; 2x2 bytes per cell, bit ordering:
;  ___       ___
; |0 1|     |0 1|
; |2 3| eg. |1 0| is %0110 = 6
;  ‾‾‾       ‾‾‾
; bits 4, 5, 6 and 7 are not used
EXPORT Buffer0
SECTION "Automata buffer 0", WRAM0, ALIGN[9]
Buffer0: ds 20 * 18

EXPORT Buffer1
SECTION "Automata buffer 1", WRAM0, ALIGN[9]
Buffer1: ds 20 * 18

EXPORT New, Old, Progress
SECTION "Automata data", HRAM
New: ds 1 ; high byte of pointer to bufferX
Old: ds 1 ; high byte of pointer to bufferX
Progress: ds 1; low byte of pointer to bufferX, common to new and old
XLoop: ds 1
YLoop: ds 1

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

EXPORT UpdateAutomata
SECTION "Update Automata", ROM0
UpdateAutomata:
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
	
	; move buffer address back to beginning
	ld hl, Old
	dec [hl]
	xor a
	ldh [Progress], a
	
	ret

EXPORT SwapBuffers, InitAutomata
SECTION "Swap Buffers", ROM0
SwapBuffers:
	; check which buffer has just been rendered
	ldh a, [Old]
	cp a, HIGH(Buffer1)
	jr nc, .newToBuffer1

.newToBuffer0
	; set old and rendered pointers to buffer1
	ld a, HIGH(Buffer1)
	ldh [Old], a

	; set new pointer to buffer0
	ld a, HIGH(Buffer0)
	ldh [New], a

	jr InitAutomata.resetLow

.newToBuffer1
InitAutomata:
	; set old and rendered pointers to buffer0
	ld a, HIGH(Buffer0)
	ldh [Old], a

	; set new pointer to buffer1
	ld a, HIGH(Buffer1)
	ldh [New], a

.resetLow
	; reset low bytes of pointers
	xor a
	ldh [Progress], a
	ldh [Rendered], a
	ldh [Video], a

	ret