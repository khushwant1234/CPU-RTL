@ what: count the primes below 100 by trial division (try every divisor d while d * d <= n).
@ there are 25 of them.
@ expect r2 = 25
        mov  r1, 2
        mov  r2, 0
        mov  r9, 100
outer:  cmp  r9, r1
        bgt  check
        b    halt
check:  mov  r3, 2
inner:  mul  r4, r3, r3
        cmp  r4, r1
        bgt  isprime
        mod  r5, r1, r3
        cmp  r5, 0
        beq  notprime
        add  r3, r3, 1
        b    inner
isprime:
        add  r2, r2, 1
notprime:
        add  r1, r1, 1
        b    outer
halt:   b    halt
