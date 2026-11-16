@ what: work out fibonacci(25) with a loop. fib(25) = 75025 and fib(26) = 121393.
@ expect r1 = 75025
@ expect r2 = 121393
        mov  r1, 0
        mov  r2, 1
        mov  r3, 25
loop:   add  r4, r1, r2
        mov  r1, r2
        mov  r2, r4
        sub  r3, r3, 1
        cmp  r3, 0
        bgt  loop
halt:   b    halt
