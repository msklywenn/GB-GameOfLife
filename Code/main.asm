INCLUDE "hardware.inc"
INCLUDE "utils.inc"

EMPTY_BG_TILE EQU 17
_VRAM_BG_TILES EQU $9000

SECTION "Header", ROM0[$100]
EntryPoint:
    di
    jp Start
REPT $150 - $104
    db 0
ENDR

SECTION "Main", ROM0[$150]
Start:	
	; save gameboy type in B
	ld b, a

	; enable v-blank interrupt
	ld a, IEF_VBLANK
	ld [rIE], a

	xor a
	ldh [rIF], a

IF !DEF(DIRECT_TO_GAME)
	; skip if running on GBC or GBA
	ld a, b
	cp a, $11
	jr z, .skip

	call ScrollNintendoOut

.skip
ENDC
	
	; disable screen
	halt
	xor a
	ldh [rLCDC], a

	; load bg and obj palette [0=black, 1=dark gray, 2=light gray, 3=white]
	ld a, %11100100
	ldh [rBGP], a
	ldh [rOBP0], a
	
	; load 18 tiles
	; 0..15: 2x2 cell combinations
	; 16: sprite selection tile
	; 17: empty tile
	ld hl, _VRAM_BG_TILES
	ld de, BackgroundTiles
	ld bc, BackgroundTilesEnd - BackgroundTiles
	call MemoryCopy
	
	ld hl, _VRAM
	ld de, SpriteTiles
	ld bc, SpriteTilesEnd - SpriteTiles
	call MemoryCopy
	
	; clear OAM
	ld hl, _OAMRAM
	ld d, 0
	ld bc, 40 * 4
	call MemorySet
	
	; set scrolling to (0, 0)
	xor a
	ldh [rSCX], a
	ldh [rSCY], a
	
	; clear screen (both buffers)
	ld hl, _SCRN0
	ld d, EMPTY_BG_TILE
	ld bc, 32 * 32 * 2
	call MemorySet
	
	; init buffer 0
	ld hl, Buffer0
	ld de, DefaultMap
	ld bc, 20 * 18
	call MemoryCopy
	
	call InitJoypad
	call InitAutomata
	call InitEdit
	
	; enable h-blank interrupt in lcd stat
	ld a, STATF_MODE00
	ld [rSTAT], a

	; enable screen but don't display anything yet
	ld a, LCDCF_ON
	ldh [rLCDC], a
	
	ClearAndEnableInterrupts
.mainloop
	call StartRender
	call UpdateAutomata
	call WaitRender
	call SwapBuffers
	call UpdateJoypad
	call EditOldBuffer
	jp .mainloop
