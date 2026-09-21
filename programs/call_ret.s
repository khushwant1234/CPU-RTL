@ call_ret.s - call/ret, stack in data memory, recursive factorial,
@ and a ret straight after "ld ra" (load-use on the implicit r15 read)
        mov  sp, 1024
        mov  r1, 6
        call square             @ r2 = 36
        mov  r3, r2
        mov  r1, 5
        call fact               @ r2 = 120
        mov  r4, r2
        mov  r6, 41
        call leaf
        b    end

square: mul  r2, r1, r1
        ret

@ r2 = fact(r1), saves ra and r1 on the stack
fact:   cmp  r1, 1
        bgt  fact_rec
        mov  r2, 1
        ret
fact_rec:
        sub  sp, sp, 8
        st   ra, 4[sp]
        st   r1, 0[sp]
        sub  r1, r1, 1
        call fact
        ld   r1, 0[sp]
        ld   ra, 4[sp]
        add  sp, sp, 8
        mul  r2, r2, r1
        ret

leaf:   sub  sp, sp, 4
        st   ra, 0[sp]
        add  r6, r6, 1          @ 42
        add  sp, sp, 4
        ld   ra, -4[sp]
        ret                     @ needs ra from the ld right before it

end:    mov  r5, 0x55
halt:   b    halt
