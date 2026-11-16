@ what: find the biggest and smallest of 8 signed numbers in memory (17, -4, 33, 0, -128, 99, 5, -1).
@ max should be 99 and min should be -128. this needs the signed compare to be right.
@ expect r2 = 99
@ expect r3 = -128
        mov  r10, 0x300
        mov  r1, 17
        st   r1, 0[r10]
        mov  r1, -4
        st   r1, 4[r10]
        mov  r1, 33
        st   r1, 8[r10]
        mov  r1, 0
        st   r1, 12[r10]
        mov  r1, -128
        st   r1, 16[r10]
        mov  r1, 99
        st   r1, 20[r10]
        mov  r1, 5
        st   r1, 24[r10]
        mov  r1, -1
        st   r1, 28[r10]
        ld   r2, 0[r10]
        mov  r3, r2
        mov  r4, 4
        mov  r5, 7
loop:   add  r6, r10, r4
        ld   r7, 0[r6]
        cmp  r7, r2
        bgt  newmax
        b    checkmin
newmax: mov  r2, r7
checkmin:
        cmp  r3, r7
        bgt  newmin
        b    next
newmin: mov  r3, r7
next:   add  r4, r4, 4
        sub  r5, r5, 1
        cmp  r5, 0
        bgt  loop
halt:   b    halt
