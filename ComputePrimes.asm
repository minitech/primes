.cpu cortex-m0
.thumb
.syntax unified

.equ RAM_START, 0x20000000

.equ STK, 0xe000e010
.equ STK_CSR, STK
.equ STK_RVR, STK + 0x04
.equ STK_CVR, STK + 0x08

.equ SCB, 0xe000ed00
.equ SCB_SCR, SCB + 0x10

.equ UART, 0x40002000
.equ UART_ENABLE, UART + 0x500
.equ UART_ENABLE_ENABLED, 4
.equ UART_STARTTX, UART + 0x008
.equ UART_TXD, UART + 0x51C

.equ NUM_PRIMES, 20

vector_table:
    // initial stack pointer
    .word RAM_START + 0x1000

    // reset
    .word reset

    // NMI (non-maskable interrupt)
    .word hang

    // hard fault
    .word hang

.thumb_func
hang:
    b hang

.thumb_func
reset:
    ldr r0, =UART_ENABLE
    movs r1, UART_ENABLE_ENABLED
    str r1, [r0]
    ldr r0, =UART_STARTTX
    movs r1, 1
    str r1, [r0]

    ldr r0, =STK_RVR
    ldr r1, =1000000000
    str r1, [r0]

    ldr r0, =STK_CVR
    movs r1, 0
    str r1, [r0]

    ldr r0, =STK_CSR
    movs r1, 5  // processor clock | enable
    str r1, [r0]

    ldr r0, =STK_CVR
    ldr r3, [r0]
    bl debug_word

    ldr r0, =STK_CVR
    ldr r3, [r0]
    bl debug_word

    ldr r0, =STK_CVR
    ldr r3, [r0]
    ldr r4, [r0]
    bl debug_word
    mov r3, r4
    bl debug_word

    ldr r0, =STK_CVR
    ldr r3, [r0]
    ldr r4, [r0]
    bl debug_word
    mov r3, r4
    bl debug_word

    ldr r3, =Primearray

    ldr r0, =STK_CVR
    ldr r3, [r0]
    bl debug_word

    ldr r0, =UART_TXD
    movs r1, '\n'
    strb r1, [r0]

    bl ComputePrimes

    ldr r0, =UART_TXD
    movs r1, '\n'
    strb r1, [r0]

    ldr r0, =Primearray
    movs r4, 6
    next_prime:
        ldr r3, [r0]
        bl debug_word

        adds r0, 4
        adds r4, -1
        bne next_prime

    ldr r0, =UART_TXD
    movs r1, '\n'
    strb r1, [r0]

    pop {r3}
    bl debug_word

    // i don't know if this part even works on a real device. it doesn't seem to do anything visible with default QEMU flags
    ldr r0, =SCB_SCR
    movs r1, 4  // SLEEPDEEP
    str r1, [r0]
    wfi
    bl debug_word
    b hang

.thumb_func
ComputePrimes:
    SIEVE_LOW .req r0
    CURRENT_MASK .req r1
    CURRENT_VALUE .req r2
    MULTIPLES_MASK .req r3
    SUB_VALUE .req r4
    SUB_MASK .req r5
    TMP .req r6
    TMP_SHIFT .req r7
    SIEVE_HIGH .req r8

    push {SIEVE_LOW, CURRENT_MASK, CURRENT_VALUE, MULTIPLES_MASK, SUB_VALUE, SUB_MASK, TMP, TMP_SHIFT}
    mov TMP, SIEVE_HIGH
    push {TMP}

    // everything is initially prime. by using two 32-bit sieves, we rely on the foreknowledge that the 20th prime is less than 3+2*64.
    movs SIEVE_LOW, 0
    mvns SIEVE_LOW, SIEVE_LOW
    mov SIEVE_HIGH, SIEVE_LOW

    // start at the first odd number
    movs CURRENT_VALUE, 3

    // mask for current element
    movs CURRENT_MASK, 1

    next_sieve:
        // if not prime, continue
        tst SIEVE_LOW, CURRENT_MASK
        beq fail_sieve

        // periodic with period of n
        movs MULTIPLES_MASK, CURRENT_MASK
        movs TMP_SHIFT, CURRENT_VALUE

        // 3*2^4 > 32
        // TODO: can save some cycles here by going back and forth
        // TODO: 3 is the only prime that needs 4 repeats.
        .rept 4
            movs TMP, MULTIPLES_MASK
            lsls TMP, TMP_SHIFT
            orrs MULTIPLES_MASK, TMP
            lsls TMP_SHIFT, 1
        .endr

        bics SIEVE_LOW, MULTIPLES_MASK  // multiples of n up to 3+2*15 are not prime
        orrs SIEVE_LOW, CURRENT_MASK  // except for n itself

        // calculate 32 mod n. TODO: optimize
        movs TMP, 8
        cmp TMP, CURRENT_VALUE
        blo nosub_1
        subs TMP, CURRENT_VALUE
        cmp TMP, CURRENT_VALUE
        blo nosub_1
        subs TMP, CURRENT_VALUE
        nosub_1:
        add TMP, TMP
        cmp TMP, CURRENT_VALUE
        blo nosub_2
        subs TMP, CURRENT_VALUE
        nosub_2:
        add TMP, TMP
        cmp TMP, CURRENT_VALUE
        blo nosub_3
        subs TMP, CURRENT_VALUE
        nosub_3:
        // now -32 mod n
        // ... except it only works without this. i don't know why
        //subs TMP, CURRENT_VALUE, TMP

        lsrs MULTIPLES_MASK, TMP
        mov TMP, SIEVE_HIGH
        bics TMP, MULTIPLES_MASK
        mov SIEVE_HIGH, TMP

        fail_sieve:
        adds CURRENT_VALUE, 2
        lsls CURRENT_MASK, 1
        cmp CURRENT_VALUE, 16  // 16*16 is more than a byte
        blo next_sieve

    pOut .req r7
    pEnd .req r4

    ldr pOut, =Primearray
    movs pEnd, pOut
    adds pEnd, NUM_PRIMES

    movs CURRENT_MASK, 1
    movs CURRENT_VALUE, 3

    next_candidate_low:
        tst CURRENT_MASK, SIEVE_LOW
        beq fail_candidate_low

        strb CURRENT_VALUE, [pOut]
        adds pOut, 1

        fail_candidate_low:
        adds CURRENT_VALUE, 2
        lsls CURRENT_MASK, 1
        bne next_candidate_low  // depends on the fact that NUM_PRIMES > about 16

    movs CURRENT_MASK, 1

    SIEVE .req SIEVE_LOW
    //.unreq SIEVE_LOW
    mov SIEVE, SIEVE_HIGH
    //.unreq SIEVE_HIGH

    next_candidate_high:
        tst CURRENT_MASK, SIEVE
        beq fail_candidate_high

        strb CURRENT_VALUE, [pOut]
        adds pOut, 1

        fail_candidate_high:
        adds CURRENT_VALUE, 2
        lsls CURRENT_MASK, 1
        cmp pOut, pEnd
        bne next_candidate_high  // depends on the fact that NUM_PRIMES is low enough to not need 3 + 2 * (64 - (32 mod 13))

    pop {TMP}
    mov SIEVE_HIGH, TMP
    pop {SIEVE_LOW, CURRENT_MASK, CURRENT_VALUE, MULTIPLES_MASK, SUB_VALUE, SUB_MASK, TMP, TMP_SHIFT}
    bx lr

.thumb_func
debug_word:
    push {r0, r1, r2, r3, r4, r5}

    ldr r0, =UART_TXD
    movs r1, '0'
    strb r1, [r0]
    movs r1, 'x'
    strb r1, [r0]
    ldr r1, =hex

    movs r5, 4
    rev r3, r3
    movs r4, 0xf
    print_byte:
        mov r2, r3
        lsrs r2, 4
        ands r2, r4
        ldrb r2, [r1, r2]
        str r2, [r0]
        mov r2, r3
        ands r2, r4
        ldrb r2, [r1, r2]
        str r2, [r0]
        lsrs r3, 8
        adds r5, -1
        bne print_byte

    movs r1, '\n'
    strb r1, [r0]

    pop {r0, r1, r2, r3, r4, r5}
    bx lr

.section .rodata
.align 4
hex: .ascii "0123456789abcdef"

.section .data
stack:
    .fill 0x1000, 1, 0
Primearray:
    // space for 20 1-byte primes
    .fill NUM_PRIMES, 1, 0
