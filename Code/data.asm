INCLUDE "hardware.inc"

EXPORT BitsSet
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

EXPORT DefaultMap
SECTION "Default Map", ROM0
DefaultMap:
	; 20x18 map with a glider on the top left corner
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 3, 1, 0, 3, 1, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 5, 0,10,10, 0, 0, 5, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 1,12, 6, 2,12, 4, 1, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0,12, 4, 0,12, 4, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 5, 0,10,10, 0, 0, 5, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 1, 0, 2, 2, 0, 0, 1, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 3, 1, 0, 3, 1, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

EXPORT BackgroundTiles, BackgroundTilesEnd
SECTION "Graphics", ROM0
BackgroundTiles:
INCBIN "BackgroundTiles.bin"
BackgroundTilesEnd: ds 0

EXPORT SpriteTiles, SpriteTilesEnd
SECTION "Graphics", ROM0
SpriteTiles:
INCBIN "SpriteTiles.bin"
SpriteTilesEnd: ds 0