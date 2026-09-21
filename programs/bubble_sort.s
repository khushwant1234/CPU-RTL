@ bubble_sort.s - sorts 8 signed words at 0x100 in place, then sums them
@ sorted: -20 -3 0 1 5 7 7 12      sum = 9
        mov  r1, 0x100
        mov  r2, 5
        st   r2, 0[r1]
        mov  r2, -3
        st   r2, 4[r1]
        mov  r2, 12
        st   r2, 8[r1]
        mov  r2, 0
        st   r2, 12[r1]
        mov  r2, 7
        st   r2, 16[r1]
        mov  r2, 7
        st   r2, 20[r1]
        mov  r2, -20
        st   r2, 24[r1]
        mov  r2, 1
        st   r2, 28[r1]

        mov  r3, 8              @ n
outer:  sub  r3, r3, 1
        cmp  r3, 0
        beq  sorted
        mov  r4, 0              @ i
        mov  r5, r1             @ &a[i]
inner:  cmp  r4, r3
        beq  outer
        ld   r6, 0[r5]
        ld   r7, 4[r5]
        cmp  r6, r7             @ load-use on r7
        bgt  swap
        b    next
swap:   st   r7, 0[r5]
        st   r6, 4[r5]
next:   add  r4, r4, 1
        add  r5, r5, 4
        b    inner

sorted: mov  r8, 0
        mov  r4, 0
        mov  r5, r1
sum:    ld   r6, 0[r5]
        add  r8, r8, r6         @ load-use on r6
        add  r5, r5, 4
        add  r4, r4, 1
        cmp  r4, 8
        beq  end
        b    sum
end:    b    end
