@ what: dot product of (3, -2, 7, 0, 5, 1) and (4, 6, -1, 9, 2, -8). that's 12 - 12 - 7 + 0 + 10 - 8 = -5.
@ expect r7 = -5
        mov  r10, 0x200
        mov  r11, 0x300
        mov  r1, 3
        st   r1, 0[r10]
        mov  r1, -2
        st   r1, 4[r10]
        mov  r1, 7
        st   r1, 8[r10]
        mov  r1, 0
        st   r1, 12[r10]
        mov  r1, 5
        st   r1, 16[r10]
        mov  r1, 1
        st   r1, 20[r10]
        mov  r1, 4
        st   r1, 0[r11]
        mov  r1, 6
        st   r1, 4[r11]
        mov  r1, -1
        st   r1, 8[r11]
        mov  r1, 9
        st   r1, 12[r11]
        mov  r1, 2
        st   r1, 16[r11]
        mov  r1, -8
        st   r1, 20[r11]
        mov  r7, 0
        mov  r2, 0
loop:   add  r3, r10, r2
        ld   r4, 0[r3]
        add  r3, r11, r2
        ld   r5, 0[r3]
        mul  r6, r4, r5
        add  r7, r7, r6
        add  r2, r2, 4
        cmp  r2, 24
        beq  halt
        b    loop
halt:   b    halt
