@ branches.s - beq/bgt taken and not taken, b, signed compare, loop
@ instructions after a taken branch must be flushed (never write r3/r4/r7)
        mov  r1, 5
        mov  r2, 5
        mov  r3, 0
        cmp  r1, r2
        beq  eq_ok              @ taken
        mov  r3, 99             @ flushed
        mov  r3, 98             @ flushed
eq_ok:  add  r3, r3, 1          @ r3 = 1
        cmp  r1, 3
        bgt  gt_ok              @ taken, 5 > 3
        mov  r4, 99             @ flushed
gt_ok:  mov  r4, 2
        cmp  r1, 9
        bgt  bad                @ not taken
        beq  bad                @ not taken
        mov  r5, 3
        mov  r6, -1
        cmp  r6, r1             @ -1 > 5 ? no (signed)
        bgt  bad
        b    skip
        mov  r7, 99             @ flushed
skip:   mov  r7, 4

        @ sum of 1..10 with a counted loop
        mov  r8, 0
        mov  r9, 1
loop:   add  r8, r8, r9
        add  r9, r9, 1
        cmp  r9, 11
        beq  done
        b    loop
done:   mov  r10, 0x77
halt:   b    halt

bad:    mov  r11, 0xbad
        b    bad
