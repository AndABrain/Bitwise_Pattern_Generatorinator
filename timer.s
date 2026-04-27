.global main
.section .data
zebraBitMask: // Bitmask in which each byte is 01010101
    .8byte 0x5555555555555555
stairsBitMask: // Bitmask in which each byte is 01100110
    .8byte 0x6666666666660000
halfBitMask: // Bitmask with one 1 followed by 63 zeros
    .8byte 0x8000000000000000
frameBuffer:
    .space 288 // 48-bit x 48-bit frameBuffer
timespec: // will wait for 0.25 seconds
    .quad 0 // seconds
    .quad 250000000 // nanoseconds
character: // Reervse one byte for reading user inputs/hotkeys
    .space 1
frameBufferFile: //File name used when storing frame buffer to binary file
    .asciz "frameBuffer.bin"
termios: // Used to load the current terminal settings so we can alter the terminal settings
    .space 64
ogTermios: // We save what the terminal orginial settings were so we can set the terminal setting back
    .space 64


.section .text
// Start of our program
main:
    // <SAVE CURRENT TERMINAL SETTINGS> \\
    // get/save the current termios (terminal settings)
    MOVZ X0, #0 // file descriptor = 0 (STDIN)
    LDR X1, =0x5401 // signal a TCGETS command
    LDR X2, =ogTermios // pointer to ogTermios struct
    MOVZ X8, #29 // signal IOCTL syscall
    SVC #0 // make syscall
    
    // <SET GLOBAL VARIABLES> \\
    // All of these vairables should remain unchanged
    // Except for X19, which is a global variable showing 
    // our current mode
    ADRP X9, frameBuffer
    ADRP X10, timespec
    ADD X28, X9, :lo12:frameBuffer // X28 holds the frame buffer's address
    ADD X27, X10, :lo12:timespec // X27 holds the timeSpec's address

    ADRP X9, character
    ADRP X10, frameBufferFile
    ADD X26, X9, :lo12:character // X26 holds the address to the character byte
    ADD X25, X10, :lo12:frameBufferFile // X25 hold the address to the file name stored in memory

    MOVZ X24, #288
    ADD X23, X24, X28
    ADRP X9, zebraBitMask
    ADD X9, X9, :lo12:zebraBitMask
    LDR X22, [X9]
    ADRP X9, stairsBitMask
    ADD X9, X9, :lo12:stairsBitMask
    LDR X21, [X9]
    ADRP X9, halfBitMask
    ADD X9, X9, :lo12:halfBitMask
    LDR X20, [X9]
    REV X21, X21
    REV X22, X22
    REV X20, X20
    MOVZ X19, #0 // 0 when writing patterns, 1 when animating pattern

    // <DISABLE BLOCKING MODE> \\
    // Disable blocking so the program doesn't wait for an input if ones not given
    
    // Get file settings
    MOVZ X0, #0 // set file descriptor to STDIN
    MOVZ X1, #3 // signal a F_GETFL command
    MOVZ X8, #25 // signal the syscall as FCTNL
    SVC #0 // make syscall
    
    ORR X2, X0, #0x800 // Alter settings to disable blocking
    
    // Set files settings
    MOVZ X0, #0 // set file decriptor to STDIN
    MOVZ X1, #4 // signal a F_SETFL command
    MOVZ X8, #25 // signal the syscall as FCTNL
    SVC #0 // make syscall

    // <ENABLE RAW MODE> \\
    // Enable raw mode so once the user types it's read
    //Get current termios
    MOVZ X0, #0 // set file descriptor to STDIN
    LDR X1, =0x5401 // signal a TCGETS command
    LDR X2, =termios // pointer to termios struct
    MOVZ X8, #29 // signal the syscall as IOCTL syscall
    SVC #0 // make syscall

    // Modify terminal setting flags
    // load the c_lflags
    LDR W9, [X2, #12]
    // edit the icanon settings to put terminal into raw mode (termianl won't wait till \n to see new characters)
    BIC W9, W9, #0x0002
    // edit the echo settings (character types won't be printed back to the screen)
    BIC W9, W9, #0x0008
    STR W9, [X2, #12]

    // Set terminal settings
    MOVZ X0, #0 // set file descriptor to STDIN
    LDR X1, =0x5402 // signal a TCSETS command
    MOVZ X8, #29 // signal the syscall as IOCTL syscall
    SVC #0 // make syscall

    MOVZ X7, #0 // Set X7 param to anything but #'e' so program doesn't immediatly close
    B _clear // Jump to the clear subroutine


_timerLoop:
    // <READ USER INPUT CHARACTER> \\
    MOVZ X0, #0 // file descriptor = 0 (STDIN)
    MOV X1, X26 // point to character memory address
    MOVZ X2, #1 // read one byte
    MOVZ X8, #63 // signal syscall read command
    SVC #0 // make syscall
    
    // if there was something to read then the user gave an input which we need to handle
    CMP X0, #1
    BEQ handleChar
    // else the user has not given an input, in which we then should see if we need to animate something
    B checkIfAnimating

    handleChar:
        // load character into X7 (it'll be a parameter for so subroutines)
        LDRB W7, [X26]
        // If it's a valid hotkey then run the respective subroutine
        CMP W7, #'e'
        BEQ _clear
        CMP W7, #' '
        BEQ _clear
        CMP W7, #'v'
        BEQ _zebra
        CMP W7, #'h'
        BEQ _horizontalStripes
        CMP W7, #'c'
        BEQ _checkerBoard
        CMP W7, #'s'
        BEQ _stepsInit
        CMP W7, #'y'
        BEQ _half
        // If the character isn't a valid key then we will see if we need to animate the screen (so we move down to the next line)
    checkIfAnimating: 
    // if we're animating then call _stepsAnimate
    CMP X19, #1 
    BEQ _stepsAnimate
    // else we should jump back up to check if any new character has been typed since we have nothing to to write/display/do
    B _timerLoop 

_write:
    MOVZ X0, #0
    MOVN X0, #99 
    MOV X1, X25
    MOVZ X2, #0x241
    MOVZ X3, #0644
    MOVZ X8, #56
    SVC #0 // make syscall

    MOV X9, X0

    MOV X0, X9
    MOV X1, X28
    MOV X2, X24
    MOVZ X8, #64
    SVC #0 // make syscall

    MOV X0, X9
    MOVZ X8, #57
    SVC #0 // make syscall

    CMP W7, #'e'
    BEQ _exit
    CMP X19, #0
    BEQ _timerLoop

    MOV X0, X27
    MOVZ X1, #0
    MOVZ X8, #101        
    SVC #0 // make syscall

    B _timerLoop

_checkerBoard:
    // set X5 to be the checkerboard patterns intial bitmask (it's first row) and call _onOfffBasedPattern
    MOV X5, X22
    B _onOffBasedPattern

_horizontalStripes:
    // set X5 to be the horizontal stripes intial bitmask (it's first row) and call _onOfffBasedPattern
    MOVZ X5, #0
    B _onOffBasedPattern
    
_onOffBasedPattern:
    MOV X4, X28 // the register containg the address which will be incremented over
    MOV X6, X23 // the parameter for the upperbound of the iteration
    MOV X19, #0 // set the mode to be pattern drawing mode instead of animate mode
    
    onOffLoop: // Recursivley call until frame buffer has been fully updated/drawn
        // Write the last 6 bytes stored in X5
        UBFX X9, X5, #0, #32
        STR W9, [X4], #4
        UBFX X9, X5, #32, #16
        STRH W9, [X4], #2

        // Flip the bits of the bitmask being stored in X5
        MOVN X9, #0
        EOR X5, X5, X9

        // See if there's more of the frame buffer to write to
        CMP X4, X6
        BLT onOffLoop // if there is loop again
    B _write // if not write the current frame buffer

_clear:
    // set X5 to be the an intial bitmask of all zeros (it's first row) and call _rowBasedPattern
    MOVN X5, #0
    B _rowBasedPattern

_zebra: 
    // set X5 to be the zebra patterns intial bitmask (it's first row) and call _rowBasedPattern
    MOV X5, X22
    B _rowBasedPattern

_rowBasedPattern:
    MOV X4, X28 // the register containg the address which will be incremented over
    MOV X6, X23 // the parameter for the upperbound of the iteration
    MOV X19, #0 // set the mode to be pattern drawing mode instead of animate mode
    rowLoop:
        // load 8 bytes from the frame buffer
        LDR X9, [X4]

        // use bitwise operations to set the load registers to be the same as the pattern bitmask
        AND X9, X9, X5
        ORR X9, X9, X5

        // store the 8 changed bytes and increment by 8
        STR X9, [X4], #8
        // see if there's more of the frame buffer to write to
        CMP X4, X6
        BLT rowLoop // if there is loop again
    B _write // if not write the current frame buffer



_stepsInit:
    
    MOV X5, X21
    MOVZ X19, #1
    B _shiftBasedPattern

_stepsAnimate:
    LDR X5, [X28] 
    REV X5, X5
    AND W9, W5, #0x00010000
    LSL X9, X9, #47
    LSR X5, X5, #1
    ORR X5, X5, X9
    REV X5, X5
    MOVZ X19, #1
    B _shiftBasedPattern

_shiftBasedPattern:
    MOV X4, X28
    MOV X6, X23
    shiftLoop:
        UBFX X9, X5, #0, #32
        STR W9, [X4], #4
        UBFX X9, X5, #32, #16
        STRH W9, [X4], #2
    
        REV X5, X5
        AND W9, W5, #0x00010000
        LSL X9, X9, #47
        LSR X5, X5, #1
        ORR X5, X5, X9
        REV X5, X5

        CMP X4, X6
        BLT shiftLoop
    B _write

_half:
    MOV X4, X28
    MOV X5, X20
    MOV X6, X23
    halfLoop:
        UBFX X9, X5, #0, #32
        STR W9, [X4], #4
        UBFX X9, X5, #32, #16
        STRH W9, [X4], #2

        REV X5, X5
        LSR X9, X5, #1
        ORR X5, X9, X5
        REV X5, X5
        CMP X4, X6
        BLT halfLoop
    B _write
    
_exit:
    // Enable blocking
    MOVZ X0, #0 // set file descriptor to STDIN
    MOVZ X1, #3
    MOVZ X8, #25
    SVC #0 // make syscall

    MOV X2, X0
    ORR X2, X2, #0x800

    MOVZ X0, #0 // set file descriptor to STDIN
    MOVZ X1, #4
    MOVZ X8, #25
    SVC #0 // make syscall

    // Disbale raw mode
    // Set terminal settings back to ogTermios
    MOV X8, #29 // ioctl
    MOV X0, #0 // stdin 
    LDR X1, =0x5402 // tcsets
    LDR X2, =ogTermios
    SVC #0 // make syscall

    // Exit
    MOVZ x0, #0  // set exit code to 0
    MOVZ x8, #93 // signal that syscall is an exit
    SVC #0 // make syscall // syscall
