@ what: beq and bgt taken and not taken, a signed compare, a plain b, and a loop that adds 1 to 10.
@ the instructions right after each taken branch must get flushed, so r3, r4 and r7 never see the bad values.
@ expect r3 = 1
@ expect r4 = 2
@ expect r5 = 3
@ expect r7 = 4
@ expect r8 = 55
@ expect r9 = 11
@ expect r10 = 0x77
@ expect r11 = 0
@ expect flushes = 13
@ expect stalls = 0
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
