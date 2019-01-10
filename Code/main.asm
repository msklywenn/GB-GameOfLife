INCLUDE "hardware.inc"
INCLUDE "utils.inc"

_VRAM_BG_TILES EQU $9000
EMPTY_BG_TILE EQU 17

ANIMATE EQU %01
STEP    EQU %10

SECTION "Main Memory", HRAM
Control: ds 1

SECTION "Header", ROM0[$100]
EntryPoint:
    di
    jp Start
REPT $150 - $104
    db 0
ENDR

SECTION "Jingle", ROM0
Jingle:

	; load initial frequency into HL
FREQUENCY = 330
	ld hl, PULSE_FREQUENCY

	; load step to be added to frequency in DE
	; based on if a != 0 or not
	or a
	jr z, .up
.down
	ld de, 100
	jr .do
.up
	ld de, -100	

.do
	; load note count
	ld b, 3
.loop

	; play pulse channel 1 with frequency set in HL
	xor a
	ldh [rNR10], a ; sweep 
	ld a, (%01 << 6) + 30
	ldh [rNR11], a ; pattern + sound length
	ld a, $F1
	ldh [rNR12], a ; init volume + envelope sweep
	ld a, l
	ldh [rNR13], a
	ld a, h
	or a, SOUND_START
	ldh [rNR14], a
	
	; add DE to HL frequency
	add hl, de
	
	; wait ~166ms
	ld c, 6
.delay
	HaltAndClearInterrupts
	dec c
	jr nz, .delay
	
	; repeat a few times
	dec b
	ret z
	jr .loop

SECTION "Main", ROM0[$150]
Start:	
	; enable sound
	ld a, $80
	ld [rNR52], a ; sound ON
	ld a, $77
	ldh [rNR50], a ; max volume on both speakers
	ld a, $99
	ldh [rNR51], a ; channels 1 (pulse) and 4 (noise) on both speakers
	
	; enable v-blank interrupt
	ld a, IEF_VBLANK
	ld [rIE], a

	HaltAndClearInterrupts
	
	; load 18 tiles
	; 0..15: 2x2 cell combinations
	; 16: sprite selection tile
	; 17: empty tile
	ld de, _VRAM_BG_TILES
	ld hl, BackgroundTiles
	ld bc, BackgroundTilesEnd - BackgroundTiles
	call VideoMemoryCopy

	HaltAndClearInterrupts
	call Intro
	
	; copy sprite tiles
	HaltAndClearInterrupts
	ld de, _VRAM
	ld hl, SpriteTiles
	ld bc, SpriteTilesEnd - SpriteTiles
	call VideoMemoryCopy
	
	; clear OAM over 4 frames
	HaltAndClearInterrupts
	ld hl, _OAMRAM
	ld d, 0
REPT 2
	ld bc, 40 * 2
	call MemorySet
	HaltAndClearInterrupts
ENDR

	; copy default map into 20x18 automata buffer
	ld hl, DefaultMap
	ld de, Buffer0
	ld c, 18
.loopY
	ld b, 20

.loopX
	ld a, [hl+]
	ld [de], a
	inc de
	dec b
	jr nz, .loopX

	dec c
	jr z, .next

	ld a, l
	add a, 32 - 20
	ld l, a
	jr nc, .loopY

	inc h
	jr .loopY
.next

	; set scrolling to (0, 0)
	xor a
	ldh [rSCX], a
	ldh [rSCY], a
	
	; animate by default
	ld a, ANIMATE
	ldh [Control], a

	call InitJoypad
	call InitAutomata
	call InitRender
	call InitEdit

	; load bg and obj palette [0=black, 1=dark gray, 2=light gray, 3=white]
	ld a, %11100100
	ldh [rBGP], a
	ldh [rOBP0], a
	
	; enable h-blank interrupt in lcd stat
	ld a, STATF_MODE00
	ld [rSTAT], a
	
	ClearAndEnableInterrupts

.mainloop
	; animate if a control bit is set
	ldh a, [Control]
	or a
	jr z, .interact

	call StartRender
	call UpdateAutomata
	call WaitRender
	call SwapBuffers

	; clear step bit
	ldh a, [Control]
	and a, ~STEP
	ldh [Control], a

	jr .checkpause

.interact
	HaltAndClearInterrupts

	call EditOldBuffer

	; step if B is pressed
	ldh a, [JoypadDown]
	and a, PADF_B
	jr z, .checkpause

	; enable step bit in control
	ld a, STEP
	ldh [Control], a
	
	; do sound
	ld a, $6E
	ldh [rNR10], a ; sweep 
	ld a, (%01 << 6) + 30
	ldh [rNR11], a ; pattern + sound length
	ld a, $33
	ldh [rNR12], a ; init volume + envelope sweep
FREQUENCY = 220
	ld a, LOW(PULSE_FREQUENCY)
	ldh [rNR13], a
	ld a, SOUND_START | HIGH(PULSE_FREQUENCY)
	ldh [rNR14], a
	
.checkpause
	call UpdateJoypad

	ldh a, [JoypadDown]
	and a, PADF_START
	jr z, .mainloop
	
	ldh a, [Control]
	xor a, ANIMATE
	ldh [Control], a
	and a, ANIMATE
	call Jingle
	
	; toggle sprites
	ldh a, [rLCDC]
	xor a, LCDCF_OBJON
	ldh [rLCDC], a

	jr .mainloop
