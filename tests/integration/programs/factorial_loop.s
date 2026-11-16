@ what: 12 factorial with a loop. 12! = 479001600, which is the biggest factorial that fits in 32 bits.
@ expect r1 = 479001600
        mov  r1, 1
        mov  r2, 12
loop:   mul  r1, r1, r2
        sub  r2, r2, 1
        cmp  r2, 1
        bgt  loop
halt:   b    halt
