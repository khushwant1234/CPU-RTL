@ what: count the 1 bits in 0xdeadbeef by checking the lowest bit and shifting right 32 times.
@ 0xdeadbeef has 24 ones. r1 gets shifted all the way down to 0.
@ expect r2 = 24
@ expect r1 = 0
        movh r1, 0xdead
        oru  r1, r1, 0xbeef
        mov  r2, 0
        mov  r3, 32
loop:   and  r4, r1, 1
        add  r2, r2, r4
        lsr  r1, r1, 1
        sub  r3, r3, 1
        cmp  r3, 0
        bgt  loop
halt:   b    halt
