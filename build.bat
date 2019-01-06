..\..\Assembler\rgbasm -i ..\..\Include\ -i Graphics\ -i Code\ -o Build\main.o         Code\main.asm
..\..\Assembler\rgbasm -i ..\..\Include\ -i Graphics\ -i Code\ -o Build\data.o         Code\data.asm
..\..\Assembler\rgbasm -i ..\..\Include\ -i Graphics\ -i Code\ -o Build\automata.o     Code\automata.asm
..\..\Assembler\rgbasm -i ..\..\Include\ -i Graphics\ -i Code\ -o Build\render.o       Code\render.asm
..\..\Assembler\rgbasm -i ..\..\Include\ -i Graphics\ -i Code\ -o Build\utils.o        Code\utils.asm
..\..\Assembler\rgbasm -i ..\..\Include\ -i Graphics\ -i Code\ -o Build\nintendo-out.o Code\nintendo-out.asm
..\..\Assembler\rgbasm -i ..\..\Include\ -i Graphics\ -i Code\ -o Build\edit.o Code\edit.asm
..\..\Assembler\rgblink -n rom.sym -w -t -o rom.gb -d Build/main.o Build/data.o Build/automata.o Build/render.o Build/utils.o Build/nintendo-out.o Build/edit.o
..\..\Assembler\rgbfix -t "Game of Life" -v -p 0 rom.gb