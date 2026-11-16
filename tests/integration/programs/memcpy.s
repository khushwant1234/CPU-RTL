@ what: fill 12 words at 0x200 with 1, 4, 7 ... 34, copy them to 0x400 one word at a time, then add up the copy.
@ the sum should be 210, and the copy should match the original.
@ expect mem[0x400] = 1
@ expect mem[0x42c] = 34
@ expect r7 = 210
        mov  r10, 0x200
        mov  r11, 0x400
        mov  r1, 1
        mov  r2, 0
fill:   add  r3, r10, r2
        st   r1, 0[r3]
        add  r1, r1, 3
        add  r2, r2, 4
        cmp  r2, 48
        beq  copy
        b    fill
copy:   mov  r2, 0
cloop:  add  r3, r10, r2
        ld   r4, 0[r3]
        add  r5, r11, r2
        st   r4, 0[r5]
        add  r2, r2, 4
        cmp  r2, 48
        beq  check
        b    cloop
check:  mov  r2, 0
        mov  r7, 0
sloop:  add  r5, r11, r2
        ld   r4, 0[r5]
        add  r7, r7, r4
        add  r2, r2, 4
        cmp  r2, 48
        beq  halt
        b    sloop
halt:   b    halt
