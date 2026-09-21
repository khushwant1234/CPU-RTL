@ load_use.s - load-use hazards, each one needs exactly 1 stall cycle
@ expected stalls: 4
        mov  r1, 256
        mov  r2, 11
        st   r2, 0[r1]
        mov  r2, 22
        st   r2, 4[r1]
        ld   r3, 0[r1]
        add  r4, r3, r3         @ stall 1 -> 22
        ld   r5, 4[r1]
        nop
        add  r6, r5, r5         @ distance 2, no stall -> 44
        ld   r7, 0[r1]
        st   r7, 8[r1]          @ stall 2: stored value comes from the load
        ld   r8, 8[r1]          @ 11, reads back the st right before it
        st   r1, 12[r1]         @ mem[256+12] = 256 (a pointer)
        ld   r9, 12[r1]         @ r9 = 256
        ld   r10, 4[r9]         @ stall 3: base register from a load -> 22
        ld   r11, 0[r1]
        cmp  r11, 11            @ stall 4
        beq  ok
        mov  r12, 0xbad
ok:     mov  r13, 1
halt:   b    halt
