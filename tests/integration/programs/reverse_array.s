@ what: write 1 to 8 into memory at 0x200 and then reverse it in place by swapping from both ends.
@ afterwards 0x200 should hold 8 and 0x21c should hold 1.
@ expect mem[0x200] = 8
@ expect mem[0x204] = 7
@ expect mem[0x208] = 6
@ expect mem[0x20c] = 5
@ expect mem[0x210] = 4
@ expect mem[0x214] = 3
@ expect mem[0x218] = 2
@ expect mem[0x21c] = 1
        mov  r10, 0x200
        mov  r1, 1
        mov  r2, 0
fill:   add  r3, r10, r2
        st   r1, 0[r3]
        add  r1, r1, 1
        add  r2, r2, 4
        cmp  r1, 9
        beq  go
        b    fill
go:     mov  r4, 0x200
        mov  r5, 0x21c
swap:   cmp  r5, r4
        bgt  doswap
        b    halt
doswap: ld   r6, 0[r4]
        ld   r7, 0[r5]
        st   r7, 0[r4]
        st   r6, 0[r5]
        add  r4, r4, 4
        sub  r5, r5, 4
        b    swap
halt:   b    halt
