@ arith.s - every ALU instruction, register and immediate forms
@ expected: see tb/shared/tb_cpu.sv (test_arith)
        mov  r1, 12
        mov  r2, 5
        add  r3, r1, r2         @ 17
        sub  r4, r1, r2         @ 7
        mul  r5, r1, r2         @ 60
        div  r6, r1, r2         @ 2
        mod  r7, r1, r2         @ 2
        and  r8, r1, r2         @ 4
        or   r9, r1, r2         @ 13
        not  r10, r2            @ 0xfffffffa
        lsl  r11, r2, 3         @ 40
        mov  r12, -64
        asr  r12, r12, 2        @ -16
        lsr  r13, r12, 28       @ 0xf
        movh r14, 0x1234
        addu r14, r14, 0xabcd   @ 0x1234abcd
        sub  r0, r2, r1         @ -7
        movu r15, 0xffff        @ 0x0000ffff
halt:   b    halt
