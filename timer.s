.global main
.section .data
zebraBitMask: .8byte 0x5555555555555555

stairsBitMask: .8byte 0x6666666666660000
frameBuffer:
    .space 288 // 48x48 frameBuffer
timespec:
    .quad 0 // seconds
    .quad 250000000 // nanoseconds
character:
    .space 1
frameBufferFile: 
    .asciz "frameBuffer.bin"
termios: 
    .space 64
ogTermios:
    .space 64

.section .text
main:
    //Get and save current termios
    MOVZ X0, #0 // STDIN file
    LDR X1, =0x5401 // tcgets
    LDR X2, =ogTermios
    MOVZ X8, #29 // itoctl syscall
    SVC #0
    
    // Setting global variables
    ADRP X9, frameBuffer
    ADD X28, X9, :lo12:frameBuffer
    ADRP X9, timespec
    ADD X27, X9, :lo12:timespec
    ADRP X9, character
    ADD X26, X9, :lo12:character
    ADRP X9, frameBufferFile
    ADD X25, X9, :lo12:frameBufferFile
    MOVZ X24, #288
    ADD X23, X24, X28
    ADRP X9, zebraBitMask
    ADD X9, X9, :lo12:zebraBitMask
    LDR X21, [X9]
    MOVN X22, #0
    ADRP X9, stairsBitMask
    ADD X9, X9, :lo12:stairsBitMask
    LDR X20, [X9]
    MOVZ X19, #0 // 0 when image, 1 when animation

_enableNonBlocking:
    MOVZ X0, #0
    MOVZ X1, #3
    MOVZ X8, #25
    SVC #0

    ORR X2, X0, #0x800

    MOVZ X0, #0
    MOVZ X1, #4
    MOVZ X8, #25
    SVC #0
_enableRawMode:
    // Set the terminal to raw so once the user types it's read
    //Get current termios
    MOVZ X0, #0 // STDIN file
    LDR X1, =0x5401 // tcgets
    LDR X2, =termios
    MOVZ X8, #29 // itoctl syscall
    SVC #0

    // Modify terminal setting flags
    // c_lflag
    LDR W9, [X2, #12]
    // icanon
    BIC W9, W9, #0x0002
    // Echo
    BIC W9, W9, #0x0008
    STR W9, [X2, #12]

    // Set terminal settings
    MOVZ X0, #0 // stdin 
    LDR X1, =0x5402 // tcsets
    MOVZ X8, #29 // ioctl
    SVC #0

    B _clear

_timerLoop:
    // Read character
    MOVZ X0, #0
    MOV X1, X26
    MOVZ X2, #1
    MOVZ X8, #63
    SVC #0
    CMP X0, #1
    BEQ _handleChar
    B checkIfAnimating

    _handleChar:
        LDRB W9, [X26]
        CMP W9, #'e'
        BEQ _disableNonBlocking
        CMP W9, #' '
        BEQ _clear
        CMP W9, #'v'
        BEQ _zebra
        CMP W9, #'h'
        BEQ _horizontalStripes
        CMP W9, #'c'
        BEQ _checkerBoard
        CMP W9, #'s'
        BEQ _stepsInit
    checkIfAnimating:
    CMP X19, #1
    BEQ _stepsAnimate

_writeAndWait:
    MOVZ X0, #0
    MOVN X0, #99 
    MOV X1, X25
    MOVZ X2, #0x241
    MOVZ X3, #0644
    MOVZ X8, #56
    SVC #0

    MOV X9, X0

    MOV X0, X9
    MOV X1, X28
    MOV X2, X24
    MOVZ X8, #64
    SVC #0

    MOV X0, X9
    MOVZ X8, #57
    SVC #0

    MOV X0, X27
    MOVZ X1, #0
    MOVZ X8, #101        
    SVC #0
    B _timerLoop

_writeNoWait:
    MOVZ X0, #0
    MOVN X0, #99 
    MOV X1, X25
    MOVZ X2, #0x241
    MOVZ X3, #0644
    MOVZ X8, #56
    SVC #0

    MOV X9, X0

    MOV X0, X9
    MOV X1, X28
    MOV X2, X24
    MOVZ X8, #64
    SVC #0

    MOV X0, X9
    MOVZ X8, #57
    SVC #0

    B _timerLoop

_checkerBoard:
    MOV X4, X28
    MOV X5, X21
    MOV X19, #0
    B _onOffBasedPattern
_horizontalStripes:
    MOV X4, X28
    MOVZ X5, #0
    MOV X19, #0
_onOffBasedPattern:
    REV X5, X5
    UBFX X11, X5, #0, #32
    STR W11, [X4], #4
    UBFX X11, X5, #32, #16
    STRH W11, [X4], #2
    REV X5, X5
    EOR X5, X5, X22

    CMP X4, X23
    BLT _onOffBasedPattern
    B _writeNoWait

_zebra:    
    MOV X9, X28
    MOV X19, #0
_zebraLoop:
    LDR X10, [X9]
    AND X10, X10, X21
    ORR X10, X10, X21
    STR X10, [X9], #8

    CMP X9, X23
    BLT _zebraLoop
    B _writeNoWait

_stepsInit:
    MOV X9, X28
    MOV X10, X20
    MOVZ X19, #1
_stepsLoop:
    REV X10, X10
    UBFX X11, X10, #0, #32
    STR W11, [X9], #4
    UBFX X11, X10, #32, #16
    STRH W11, [X9], #2
    REV X10, X10

    AND W12, W10, #0x00010000
    LSL X12, X12, #47
    LSR X10, X10, #1
    ORR X10, X10, X12

    CMP X9, X23
    BLT _stepsLoop
    B _writeAndWait

_stepsAnimate:
    MOV X9, X28 
    LDR X13, [X9]
    SUB X12, X23, #6
_animateLoop:
    LDR X10, [X9, #6]

    UBFX X11, X10, #0, #32
    STR W11, [X9], #4
    UBFX X11, X10, #32, #16
    STRH W11, [X9], #2

    CMP X9, X12
    BLT _animateLoop

    UBFX X11, X13, #0, #32
    STR W11, [X9], #4
    UBFX X11, X13, #32, #16
    STRH W11, [X9], #2    

    B _writeAndWait

_clear:
    MOV X9, X28
    MOV X19, #0
_clearLoop:
    LDR X10, [X9]
    AND X10, X10, X22
    ORR X10, X10, X22
    STR X10, [X9], #8

    // Compare and branch depending on state
    CMP X9, X23
    BLT _clearLoop
    B _writeNoWait

_clearAndExit:

_disableNonBlocking:
    MOVZ X0, #0
    MOVZ X1, #3
    MOVZ X8, #25
    SVC #0

    MOV X2, X0
    ORR X2, X2, #0x800

    MOVZ X0, #0
    MOVZ X1, #4
    MOVZ X8, #25
    SVC #0
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
