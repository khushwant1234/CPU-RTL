@ what: multiply 1234 by 5678 the long way (shift and add, like on paper) and also with mul, so they can be compared.
@ both should give 7006652.
@ expect r3 = 7006652
@ expect r7 = 7006652
        mov  r1, 1234
        mov  r2, 5678
        mov  r3, 0
loop:   cmp  r2, 0
        beq  done
        and  r4, r2, 1
        cmp  r4, 1
        beq  addit
        b    shift
addit:  add  r3, r3, r1
shift:  lsl  r1, r1, 1
        lsr  r2, r2, 1
        b    loop
done:   mov  r6, 1234
        mul  r7, r6, 5678
halt:   b    halt
