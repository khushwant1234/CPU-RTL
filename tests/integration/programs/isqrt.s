@ what: integer square root of 150000 by counting up until (r + 1)^2 goes past it. the answer is 387
@ (387^2 = 149769 and 388^2 = 150544). this one runs for a few thousand cycles.
@ expect r2 = 387
        movh r1, 0x0002
        oru  r1, r1, 0x49f0
        mov  r2, 0
loop:   add  r4, r2, 1
        mul  r5, r4, r4
        cmp  r5, r1
        bgt  halt
        mov  r2, r4
        b    loop
halt:   b    halt
