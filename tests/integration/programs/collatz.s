@ what: count the collatz steps for 27 (if even halve it, if odd do 3n + 1, stop at 1). 27 takes 111 steps,
@ and it goes as high as 9232 on the way.
@ expect r2 = 111
@ expect r1 = 1
        mov  r1, 27
        mov  r2, 0
loop:   cmp  r1, 1
        beq  halt
        and  r3, r1, 1
        cmp  r3, 0
        beq  even
        mul  r1, r1, 3
        add  r1, r1, 1
        b    next
even:   lsr  r1, r1, 1
next:   add  r2, r2, 1
        b    loop
halt:   b    halt
