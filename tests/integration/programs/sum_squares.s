@ what: store the first 10 squares (1, 4, 9 ... 100) in memory with one loop, then add them up with
@ another loop. the sum should be 385. the second loop has a load-use pair every time around.
@ expect r3 = 385
@ expect mem[0x200] = 1
@ expect mem[0x224] = 100
        mov  r10, 0x200
        mov  r1, 1
        mov  r2, 0
fill:   mul  r4, r1, r1
        add  r5, r10, r2
        st   r4, 0[r5]
        add  r1, r1, 1
        add  r2, r2, 4
        cmp  r1, 11
        beq  sum
        b    fill
sum:    mov  r3, 0
        mov  r2, 0
        mov  r6, 10
loop:   add  r5, r10, r2
        ld   r4, 0[r5]
        add  r3, r3, r4
        add  r2, r2, 4
        sub  r6, r6, 1
        cmp  r6, 0
        bgt  loop
halt:   b    halt
