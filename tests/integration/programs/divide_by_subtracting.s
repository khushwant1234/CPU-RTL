@ what: divide 1000 by 37 by subtracting over and over, then do the same with div and mod to compare.
@ 1000 = 37 * 27 + 1, so the quotient is 27 and the remainder is 1 both ways.
@ expect r2 = 27
@ expect r3 = 1
@ expect r5 = 27
@ expect r6 = 1
        mov  r1, 1000
        mov  r2, 0
loop:   cmp  r1, 36
        bgt  more
        b    done
more:   sub  r1, r1, 37
        add  r2, r2, 1
        b    loop
done:   mov  r3, r1
        mov  r4, 1000
        div  r5, r4, 37
        mod  r6, r4, 37
halt:   b    halt
