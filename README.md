# GB-GameOfLife
An implementation of Conway's Game of Life for the GameBoy

# Project's Backstory
I started this as my first real programming written entirely in assembly.
I thought the gameboy was a good fit for that, with its not too complex
instruction set. I chose Conway's Game of Life because it's quite a
classic of CS exercises and I thought it would be simple enough to do.

Boy, I was wrong.

I know the gameboy is far from fast enough to update all pixels on
screen in between each frame. Who would have thought it would also
not be fast enough to just update its 20x18 tiles? That's only 360
bytes! In the v-blank, the time between two frames are rendered by
the Picture Processing Unit or PPU, and where you have access to 
Video RAM, there's barely enough time to write to a quarter of the
tilemap. And that's without reading from it!

But there's hope: first, the gameboy has enough video ram to hold
two tilemaps, so we can double buffer. Second, the v-blank is not
the only time where you can write to Video RAM, you can also write
in between the PPU rendering lines! That requires synchronising code
with rendering but it should be doable.
