@ what: back to back dependencies at distance 1, 2 and 3 (a fibonacci chain and friends).
@ there are no loads, so forwarding should handle all of it with zero stalls.
@ expect r1 = 1
@ expect r2 = 2
@ expect r3 = 3
@ expect r4 = 5
@ expect r5 = 8
@ expect r6 = 13
@ expect r7 = 21
@ expect r8 = 34
@ expect r9 = 55
@ expect r10 = 9
@ expect r11 = 18
@ expect r0 = 100
@ expect r14 = 0xffffff9b
@ expect mem[68] = 100
@ expect stalls = 0
        mov  r1, 1
        add  r2, r1, r1         @ 2    r1 from EX/MEM on both operands
        add  r3, r2, r1         @ 3    r2 EX/MEM, r1 MEM/WB
        add  r4, r3, r2         @ 5
        add  r5, r4, r3         @ 8
        add  r6, r5, r4         @ 13
        add  r7, r6, r5         @ 21
        nop
        add  r8, r7, r6         @ 34   r7 MEM/WB, r6 through the reg file bypass
        nop
        nop
        add  r9, r8, r7         @ 55   distance 3 and 4
        mov  r10, 7
        mov  r10, 9             @ two writes to r10 in flight
        add  r11, r10, r10      @ 18   newest value must win
        mov  r13, 64
        mov  r12, 100
        st   r12, 4[r13]        @ store data forwarded (dist 1), base (dist 2)
        ld   r0, 4[r13]         @ r0 = 100, reads what the st just wrote
        nop
        not  r14, r0            @ ~100, load at distance 2 -> forwarded, no stall
halt:   b    halt
