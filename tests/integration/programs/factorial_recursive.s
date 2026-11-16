@ what: 7 factorial done recursively, so call and ret nest 7 deep and every level saves r15 and its
@ argument on the stack. 7! = 5040. r1 gets restored back to 7 and sp ends up where it started.
@ expect r0 = 5040
@ expect r2 = 5040
@ expect r1 = 7
@ expect sp = 0x800
        mov  sp, 0x800
        mov  r1, 7
        call fact
        mov  r2, r0
halt:   b    halt
fact:   cmp  r1, 1
        bgt  recurse
        mov  r0, 1
        ret
recurse:
        sub  sp, sp, 8
        st   ra, 4[sp]
        st   r1, 0[sp]
        sub  r1, r1, 1
        call fact
        ld   r1, 0[sp]
        ld   ra, 4[sp]
        add  sp, sp, 8
        mul  r0, r0, r1
        ret
