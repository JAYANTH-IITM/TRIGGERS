# Simple RISC-V Assembly Code for exepection Handling
#include "encoding.h"

#if XLEN == 64
# define LREG ld
# define SREG sd
# define REGBYTES 8
#else
# define LREG lw
# define SREG sw
# define REGBYTES 4
#endif

#define get_field(reg, mask) (((reg) & (mask)) / ((mask) & ~((mask) << 1)))

        .global         main

        .section        .text
main:
    la a0, 3f      
    
    csrrw a0,mtvec, a0      
    li a1, 0x8
    csrs tcontrol, a1

        la      a0, data
        li      t0, 0
just_before_read_loop:
        li      t2, 16
read_loop:
        lw      t1, 0(a0)
        addi    t1, t1, 1
        addi    t0, t0, 1
read_again:
        lw      t1, 0(a0)
        addi    a0, a0, 4
        blt     t0, t2, read_loop

        la      a0, data
just_before_write_loop:
        li      t0, 1
write_loop:
        sw      t0, 0(a0)
        addi    t0, t0, 1
        addi    a0, a0, 4
        blt     t0, t2, write_loop

        j       main_exit

write_store_trigger:
        /* 2<<60 is for RV64. 2<<28 is for RV32. That's safe because on RV64 bits 28 and 29 are 0. */
        li      a0, (6<<60) | (6<<28) | (1<<6) | (1<<1) | (1 << 7) | (0 << 12) | (1 << 21) | (1 << 22) | (0 << 25)
        li      a1, 0X30300060
        jal     write_triggers
        la      a0, data
        jal     read_triggers
     

write_load_trigger:
        li      a0, (6<<60) | (6<<28) | (1<<6) | (1<<1) | (1 << 7) | (0 << 12) | (1 << 21) | (1 << 22) | (0 << 25)
        li      a1, 0X30300060
        jal     write_triggers
        la      a0, data
        jal     read_triggers

li      t1, get_field(CSR_TDATA1,12)
beqz    t1, trigger_trap

// Clear triggers so the next test can use them.
clear_triggers:

        li      a0, 0
        jal     write_triggers


main_exit:

        li      a0, 10
        j       _exit

write_triggers:
        // a0: value to write to each tdata1
        // a1: value to write to each tdata2
        li      t0, 0
2:
        csrw    CSR_TSELECT, t0
        csrr    t1, CSR_TSELECT
        bne     t0, t1, 1f
        addi    t0, t0, 1
        csrw    CSR_TDATA2, a1
        csrw    CSR_TDATA1, a0
        j       2b
1:      ret

read_triggers:
        // a0: address where data should be written
        li      t0, 0
2:
        csrw    CSR_TSELECT, t0
        csrr    t1, CSR_TSELECT
        bne     t0, t1, 1f
        addi    t0, t0, 1
        csrr    t1, CSR_TDATA1
        SREG    t1, 0(a0)
        csrr    t1, CSR_TDATA2
        SREG    t1, REGBYTES(a0)
        addi    a0, a0, 2*REGBYTES
        j       2b
1:      SREG    zero, 0(a0)
        ret

3:
  csrw mtvec, a0

trigger_trap:
	
        ebreak
        nop

trap_entry:     
        addi sp, sp, -32*REGBYTES
        nop
        jal trap_handler


trap_handler:

        li s3, 0x0c010010
	csrr t0,mcause
	li t3, 0x80000000
	and t0,t0,t3
	beqz t0, exception_handler 
4:      ret

exception_handler:
        li      t1, get_field(CSR_TDATA1,7)
        li      t2,1
        beq     t1,t2,trigger_match1
	j 4b

trigger_match1:
        csrr    t1, CSR_TDATA1
        csrr    t2, CSR_TDATA2
        li      t6, 0xFFFFFFFE
        and     t1,t1,t6
        and     t2,t2,t6
        beq     t1,t2,trigger_exit
    	
trigger_exit:
        ret

        .section .data
        .align  3
data:   .word   0x50
        .word   0x51
        .word   0x52
        .word   0x53
        .word   0x54
        .word   0x55
        .word   0x56
        .word   0x57
        .word   0x58
        .word   0x59
        .word   0x5a
        .word   0x5b
        .word   0x5c
        .word   0x5d
        .word   0x5e
        .word   0x5f
