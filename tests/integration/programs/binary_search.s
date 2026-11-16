@ what: put 16 sorted numbers in memory (3, 10, 17 ... 108) and binary search them with a function.
@ 66 is at index 9, and 50 isn't there so the search should give -1.
@ expect r11 = 9
@ expect r12 = -1
        mov  sp, 0x800
        mov  r10, 0x200
        mov  r1, 3
        mov  r2, 0
fill:   add  r3, r10, r2
        st   r1, 0[r3]
        add  r1, r1, 7
        add  r2, r2, 4
        cmp  r2, 64
        beq  search
        b    fill
search: mov  r1, 66
        call bsearch
        mov  r11, r0
        mov  r1, 50
        call bsearch
        mov  r12, r0
halt:   b    halt
bsearch:
        mov  r4, 0
        mov  r5, 15
bsloop: cmp  r4, r5
        bgt  notfound
        add  r6, r4, r5
        lsr  r6, r6, 1
        lsl  r7, r6, 2
        add  r7, r10, r7
        ld   r8, 0[r7]
        cmp  r8, r1
        beq  found
        bgt  goleft
        add  r4, r6, 1
        b    bsloop
goleft: sub  r5, r6, 1
        b    bsloop
found:  mov  r0, r6
        ret
notfound:
        mov  r0, -1
        ret
