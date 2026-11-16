@ what: 3 to the power 13 by multiplying in a loop. 3^13 = 1594323.
@ expect r1 = 1594323
        mov  r1, 1
        mov  r2, 13
loop:   mul  r1, r1, 3
        sub  r2, r2, 1
        cmp  r2, 0
        bgt  loop
halt:   b    halt
