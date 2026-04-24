.global main
.section .data
zebra_BitMask: .8byte 0xAAAAAAAAAAAAAAAA

.align 4
frameBuffer:
    .space 288 // 48x48 frameBuffer
timespec:
    .quad 0 // seconds
    .quad 250000000 // nanoseconds
character:
    .space 1
termios: 
    .space 64
ogTermios:
    .space 64

// X0-X7 are parameters
// X0-15 are general
// X19-28 callee saved

.section .text
main:
    //Get and save current termios
    MOV X0, #0 // STDIN file
    LDR X1, =0x5401 // tcgets
    LDR X2, =ogTermios
    MOV X8, #29 // itoctl syscall
    SVC #0
    
_enableRawMode:
    // Set the terminal to raw so once the user types it's read
    //Get current termios
    MOV X0, #0 // STDIN file
    LDR X1, =0x5401 // tcgets
    LDR X2, =termios
    MOV X8, #29 // itoctl syscall
    SVC #0

    // Modify terminal setting flags
    // c_lflag
    LDR W3, [X2, #12]
    // icanon
    BIC W3, W3, #0x0002
    // Echo
    BIC W3, W3, 0x0008
    STR W3, [X2, #12]

    // Set terminal settings
    MOV X8, #29 // ioctl
    MOV X0, #0 // stdin 
    LDR X1, =0x5402 // tcsets
    SVC #0

_timerLoop:
    // Read character
    MOV X8, #63
    MOVZ X0, #0
    LDR X1, =character
    MOVZ X2, #1
    SVC #0

    // Compare character
    ADRP X1, character
    ADD X1, X1, :lo12:character
    LDRB W2, [X1]
    CMP W2, #'s'
    BEQ _disableRawMode
    CMP W2, #'z'
    BEQ _queueZebra
    CMP W2, #'c'
    BEQ _queueCheckerBoard

    _wait:
    mov X8, #101    
    ldr X0, =timespec
    mov X1, #0
    SVC #0

    MOVZ X8, #64 // syscall num for write
    MOVZ X0, #1
    ADRP X1, character
    ADD X1, X1, :lo12:character
    MOVZ X2, #1
    SVC #0

    B _timerLoop

_queueCheckerBoard:
    // Get address of first byte in frameBuffer
    ADRP X1, frameBuffer
    ADD X1, X1, :lo12:frameBuffer

    // Get zebra_BitMask (we'll reuse it)
    ADRP X3, zebra_BitMask
    ADD X3, X3, :lo12:zebra_BitMask
    LDR X3, [X3]

    MOVZ X2, #48 // Will be our iteration counter

    // Set up the parameters
    MOVN X4, #0 // Set X4 to all 1's
    EOR X3, X3, X4

// X0: return (unused)
// X1: frameBuffer addr (param)
// X2: iteration counter (param)
// X3: checkerBoardMask (param)
// X4: 0xFFFFFFFFFFFFFFFF (param)
// X8: local variable
_checkBoard:
    STR W3, [X1], #4
    UBFX X8, X3, #32, #16
    STRH W8, [X1], #2
    EOR X3, X3, X4
    
    SUBS X2, X2, #1 // Increment iteration counter
    CMP X2, #0
    BGT _checkBoard
    B _wait

_queueZebra:
    // Get address of first byte in frameBuffer
    ADRP X1, frameBuffer
    ADD X1, X1, :lo12:frameBuffer

    // Get zebra_BitMask (we'll reuse it)
    ADRP X3, zebra_BitMask
    ADD X3, X3, :lo12:zebra_BitMask
    LDR X3, [X3]
    
    MOVZ X2, #36 // Will be our iteration counter

// X0: return (unused)
// X1: frameBuffer addr (param)
// X2: iteration counter (param)
// X3: zebra_BitMask (param)
// X8: local variable
_zebra:
    LDR X8, [X1]
    AND X8, X8, X3
    ORR X8, X8, X3
    STR X8, [X1], #8 // Store 8 bytes in frameBuffer

    // Compare and branch depending on state
    SUBS X2, X2, #1 // Increment iteration counter
    CMP X2, #0
    BGT _zebra
    B _wait

// X1: frameBuffer addr (param)
// X2: Number of bytes printed (param)
_print:
    //Get address of first byte in frameBuffer
    ADRP X1, frameBuffer
    ADD X1, X1, :lo12:frameBuffer // Addr of firt byte of frameBuffer
    MOVZ X2, #288 // Num of bytes being printed
    MOVZ X8, #64 // syscall num for write
    MOVZ X0, #1
    SVC #0
    RET

_disableRawMode:
    // Set terminal settings back to ogTermios
    MOV X8, #29 // ioctl
    MOV X0, #0 // stdin 
    LDR X1, =0x5402 // tcsets
    LDR X2, =ogTermios
    SVC #0
_exit:
    MOVZ x0, #0      // exit code 0
    MOVZ x8, #93     // exit syscall
    SVC #0