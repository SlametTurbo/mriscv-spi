    .section .text.init
    .globl _start
_start:
    la   sp, _stack_top          # stack ke akhir RAM

    /* nol-kan .bss */
    la   a0, __bss_start
    la   a1, __bss_end
1:  bge  a0, a1, 2f
    sw   zero, 0(a0)
    addi a0, a0, 4
    j    1b
2:
    /* jalankan konstruktor global C++ (.init_array) */
    la   s0, __init_array_start
    la   s1, __init_array_end
3:  beq  s0, s1, 4f
    lw   t0, 0(s0)
    jalr t0                      # s0/s1 callee-saved -> aman melintasi call
    addi s0, s0, 4
    j    3b
4:
    call main                    # masuk ke C/C++ main()
hang:
    j    hang
