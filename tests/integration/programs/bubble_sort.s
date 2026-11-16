@ what: bubble sort 8 signed numbers in memory at 0x100, then add them up.
@ sorted they should be -20 -3 0 1 5 7 7 12, and the sum is 9.
@ expect mem[0x100] = -20
@ expect mem[0x104] = -3
@ expect mem[0x108] = 0
@ expect mem[0x10c] = 1
@ expect mem[0x110] = 5
@ expect mem[0x114] = 7
@ expect mem[0x118] = 7
@ expect mem[0x11c] = 12
@ expect r8 = 9
        mov  r1, 0x100
        mov  r2, 5
        st   r2, 0[r1]
        mov  r2, -3
        st   r2, 4[r1]
        mov  r2, 12
        st   r2, 8[r1]
        mov  r2, 0
        st   r2, 12[r1]
        mov  r2, 7
        st   r2, 16[r1]
        mov  r2, 7
        st   r2, 20[r1]
        mov  r2, -20
        st   r2, 24[r1]
        mov  r2, 1
        st   r2, 28[r1]

        mov  r3, 8              @ n
outer:  sub  r3, r3, 1
        cmp  r3, 0
        beq  sorted
        mov  r4, 0              @ i
        mov  r5, r1             @ &a[i]
inner:  cmp  r4, r3
        beq  outer
        ld   r6, 0[r5]
        ld   r7, 4[r5]
        cmp  r6, r7             @ load-use on r7
        bgt  swap
        b    next
swap:   st   r7, 0[r5]
        st   r6, 4[r5]
next:   add  r4, r4, 1
        add  r5, r5, 4
        b    inner

sorted: mov  r8, 0
        mov  r4, 0
        mov  r5, r1
sum:    ld   r6, 0[r5]
        add  r8, r8, r6         @ load-use on r6
        add  r5, r5, 4
        add  r4, r4, 1
        cmp  r4, 8
        beq  end
        b    sum
end:    b    end
