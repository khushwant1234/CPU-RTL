@ what: euclid's gcd of 1071 and 462 using mod. the answer is 21.
@ expect r0 = 21
        mov  r1, 1071
        mov  r2, 462
loop:   cmp  r2, 0
        beq  done
        mod  r3, r1, r2
        mov  r1, r2
        mov  r2, r3
        b    loop
done:   mov  r0, r1
halt:   b    halt
