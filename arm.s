.global main
.section .data
zebraBitMask: // Bitmask in which each byte is 01010101
    .8byte 0x5555555555555555
stairsBitMask: // Bitmask in which the first 6 bytes are 01100110
    .8byte 0x6666666666660000
halfBitMask: // Bitmask with one 1 followed by 63 zeros
    .8byte 0x8000000000000000
frameBuffer:
    .space 288 // 48-bit x 48-bit frameBuffer
// will allow us to wait for 0.25 seconds
timespec:
    .quad 0 // seconds
    .quad 250000000 // nanoseconds
// Reservse one byte for reading user inputs/hotkeys
character: 
    .space 1
//File name used when storing frame buffer to binary file
frameBufferFile: 
    .asciz "frameBuffer.bin"
// Used to load the current terminal settings so we can alter the terminal settings
termios: 
    .space 64
// We save what the terminal orginial settings were so we can set the terminal setting back
ogTermios: 
    .space 64


.section .text
// Start of our program
main:
    // <SAVE CURRENT TERMINAL SETTINGS> \\
    // get/save the current termios (terminal settings)
    MOVZ X0, #0             // file descriptor = 0 (STDIN)
    LDR X1, =0x5401         // signal a TCGETS command
    LDR X2, =ogTermios      // pointer to ogTermios struct
    MOVZ X8, #29            // signal IOCTL syscall
    SVC #0                  // make syscall
    
    // <SET GLOBAL VARIABLES> \\
    // All of these vairables should remain unchanged
    // Except for X19, which is a global variable showing 
    // our current mode
    ADRP X9, frameBuffer
    ADRP X10, timespec
    ADD X28, X9, :lo12:frameBuffer      // X28 holds the frame buffers address
    ADD X27, X10, :lo12:timespec            // X27 holds the timeSpecs address

    ADRP X9, character
    ADRP X10, frameBufferFile
    ADD X26, X9, :lo12:character            // X26 holds the address to the character byte
    ADD X25, X10, :lo12:frameBufferFile         // X25 hold the address to the file name stored in memory
    
    // X24 holds the size of the frame buffer (48*48 bits = 288 bytes)
    MOVZ X24, #288 
    ADD X23, X24, X28       // X23 holds the address of the end of the frame buffer (used for bounds checking when writing to the frame buffer)
    
    ADRP X9, zebraBitMask 
    ADRP X10, stairsBitMask
    ADRP X11, halfBitMask
    ADD X9, X9, :lo12:zebraBitMask
    ADD X10, X10, :lo12:stairsBitMask
    ADD X11, X11, :lo12:halfBitMask
    LDR X22, [X9]           // X22 holds the zebra pattern bitmask
    LDR X21, [X10]          // X21 holds the stairs pattern bitmask
    LDR X20, [X11]          // X20 holds the half pattern bitmask
    
    // we reverse tge bitmasks so they are easier to read from and write out of (we will have to reverse them back when shifting bits)
    REV X22, X22
    REV X21, X21
    REV X20, X20
    // Sets X19 to show the current mode (0 == writing patterns not animating)
    MOVZ X19, #0 

    // <DISABLE BLOCKING MODE> \\
    // Disable blocking so the program doesnt wait for an input if ones not given
    // Get file settings
    MOVZ X0, #0             // set file descriptor to STDIN
    MOVZ X1, #3             // signal a F_GETFL command
    MOVZ X8, #25            // signal the syscall as FCTNL
    SVC #0                  // make syscall
    
    ORR X2, X0, #0x800      // Alter settings to disable blocking
    
    // Set files settings
    MOVZ X0, #0             // set file decriptor to STDIN
    MOVZ X1, #4             // signal a F_SETFL command
    MOVZ X8, #25            // signal the syscall as FCTNL
    SVC #0                  // make syscall

    // <ENABLE RAW MODE> \\
    // Enable raw mode so once the user types its read
    //Get current termios
    MOVZ X0, #0             // set file descriptor to STDIN
    LDR X1, =0x5401         // signal a TCGETS command
    LDR X2, =termios        // pointer to termios struct
    MOVZ X8, #29            // signal the syscall as IOCTL syscall
    SVC #0                  // make syscall

    // Modify terminal setting flags
    // load the c_lflags
    LDR W9, [X2, #12]
    // edit the icanon settings to put terminal into raw mode (termianl wont wait till \n to see new characters)
    BIC W9, W9, #0x0002
    // edit the echo settings (character types wont be printed back to the screen)
    BIC W9, W9, #0x0008
    STR W9, [X2, #12]

    // Set terminal settings
    MOVZ X0, #0             // set file descriptor to STDIN
    LDR X1, =0x5402         // signal a TCSETS command
    MOVZ X8, #29            // signal the syscall as IOCTL syscall
    SVC #0                  // make syscall

    MOVZ X7, #0             // Set X7 param to anything but #e so program doesnt immediatly close
    B func_clear                // Jump to the clear subroutine

// Function which repeats itself and is in control of reading user input and activating the correct subroutines
func_readerLoop:
    // <READ USER INPUT CHARACTER> \\
    MOVZ X0, #0             // file descriptor = 0 (STDIN)
    MOV X1, X26             // point to character memory address
    MOVZ X2, #1             // read one byte
    MOVZ X8, #63            // signal syscall read command
    SVC #0                  // make syscall
    
    // <HANDLE INPUT> \\
    // if there was something to read then the user gave an input which we need to handle
    CMP X0, #1
    BEQ .handleChar
    // else the user has not given an input, in which we then should see if we need to animate something
    B .checkIfAnimating

    .handleChar:
        // load character into X7 (itll be a parameter for so subroutines)
        LDRB W7, [X26]
        // If its a valid hotkey then run the respective subroutine
        CMP W7, #'e'
        BEQ func_clear
        CMP W7, #' '
        BEQ func_clear
        CMP W7, #'z'
        BEQ func__zebra
        CMP W7, #'h'
        BEQ func_horizontalStripes
        CMP W7, #'c'
        BEQ func_checkerBoard
        CMP W7, #'s'
        BEQ func_stepsInit
        CMP W7, #'d'
        BEQ func_half
        // If the character isnt a valid key then we will see if we need to animate the screen (so we move down to the next line)
    .checkIfAnimating: 
    // if were animating then call func_stepsAnimate
    CMP X19, #1 
    BEQ func_stepsAnimate
    // else we should jump back up to check if any new character has been typed since we have nothing to to write/display/do
    B func_readerLoop 

// Function which writes the frame buffer to a binary file and then checks if we need to wait for 0.25s (if we are in animate mode) before going back to the reader loop
func_write:
    // <WRITE FRAME BUFFER TO A BINARY FILE CALLED frameBuffer.bin> \\
    // opens binary file
    MOVZ X0, #0
    MOVN X0, #99            // signal the working directory to be the current directory
    MOV X1, X25             // point to the file name in memory
    MOVZ X2, #0x241         // signal open for writing, create file if it doesnt exist, and truncate file if it does exist
    MOVZ X3, #0644          // set file permissions to rw-r--r--
    MOVZ X8, #56            // signal syscall openat command
    SVC #0                  // make syscall

    MOV X9, X0 // save the file descriptor for the frame buffer binary file

    // write the frame buffer to the file
    MOV X0, X9              // set the file descriptor for writing the frame buffer to a binary file
    MOV X1, X28             // point to the start of the frame buffer
    MOV X2, X24             // set the number of bytes to write (the size of the frame buffer)
    MOVZ X8, #64            // signal syscall write command
    SVC #0                  // make syscall

    // close binary file
    MOV X0, X9              // set the file descriptor for closing the frame buffer binary file
    MOVZ X8, #57            // signal syscall close command
    SVC #0                  // make syscall

    // <CHECK MODES AND PARAMETERS> \\
    // If the W7 parameter is e then we should exit
    CMP W7, #'e' 
    BEQ func_exit
    // we then check the current mode a value of 1 indicates we need to wait 0.25s to introduce a 
    // frame rate, whilst mode 0 indicates we do not need to wait since we there is no need for a 
    // frame rate to drawing one pattern after another
    CMP X19, #0
    BEQ func_readerLoop

    // wait 0.25 seconds
    MOV X0, X27             // point to the timespec struct in memory
    MOVZ X1, #0             // signal to ignore remaining time
    MOVZ X8, #101           // signal syscall nanosleep command
    SVC #0                  // make syscall

    B func_readerLoop

// create a checkerboard pattern in the frame buffer through calling func_onOffBasedPattern with the checkerboard pattern bitmask as a parameter
func_checkerBoard:
    // set X5 to be the checkerboard patterns intial bitmask (its first row) and call _onOfffBasedPattern
    MOV X5, X22
    B func_onOffBasedPattern

// create a horizontal stripes pattern in the frame buffer through calling func_onOffBasedPattern
func_horizontalStripes:
    // set X5 to be the horizontal stripes intial bitmask (its first row) and call _onOfffBasedPattern
    MOVZ X5, #0
    B func_onOffBasedPattern
    
// create a pattern in the frame buffer through flipping the bits of the pattern bitmask
func_onOffBasedPattern:
    MOV X4, X28             // the register containg the address which will be incremented over
    MOV X6, X23             // the parameter for the upperbound of the iteration
    MOV X19, #0             // set the mode to be pattern drawing mode instead of animate mode
    
    .onOffLoop:              // Recursivley call until frame buffer has been fully updated/drawn
        // Write the last 6 bytes stored in X5
        UBFX X9, X5, #0, #32
        STR W9, [X4], #4
        UBFX X9, X5, #32, #16
        STRH W9, [X4], #2

        // Flip the bits of the bitmask being stored in X5
        MOVN X9, #0
        EOR X5, X5, X9

        // See if theres more of the frame buffer to write to
        CMP X4, X6
        BLT .onOffLoop       // if there is loop again
    B func_write                // if not write the current frame buffer

// clear the frame buffer through calling func_rowBasedPattern
func_clear:
    // set X5 to be the an intial bitmask of all zeros (its first row) and call func_rowBasedPattern
    MOVZ X5, #0
    B func_rowBasedPattern

// create a zebra pattern in the frame buffer through calling func_rowBasedPattern with the zebra pattern bitmask as a parameter
func__zebra: 
    // set X5 to be the zebra patterns intial bitmask (its first row) and call func_rowBasedPattern
    MOV X5, X22
    B func_rowBasedPattern

// create a pattern in the frame buffer through setting the row registers to be the same as the pattern bitmask
func_rowBasedPattern:
    MOV X4, X28             // the register containg the address which will be incremented over
    MOV X6, X23             // the parameter for the upperbound of the iteration
    MOV X19, #0             // set the mode to be pattern drawing mode instead of animate mode
    .rowLoop:
        // load 8 bytes from the frame buffer
        LDR X9, [X4]

        // use bitwise operations to set the load registers to be the same as the pattern bitmask
        AND X9, X9, X5
        ORR X9, X9, X5

        // store the 8 changed bytes and increment by 8
        STR X9, [X4], #8
        // see if theres more of the frame buffer to write to
        CMP X4, X6
        BLT .rowLoop         // if there is loop again
    B func_write                // if not write the current frame buffer

// create the initial step pattern in the frame buffer through calling func_shiftBasedPattern
func_stepsInit:
    MOV X5, X21             // set X5 to be the stairs patterns intial bitmask (its first row) and call func_shiftBasedPattern
    MOVZ X19, #1            // set the mode to be animate mode since the steps pattern is the only pattern that has an animation
    B func_shiftBasedPattern

// create the next frame of animation in the frame buffer through calling func_shiftBasedPattern
func_stepsAnimate:
    LDR X5, [X28]           // load the first 8 bytes of the frame buffer (the first row of the pattern) into X5
    // shift the 48 bits of the bitmask to the right by one
    REV X5, X5              // undo previous reversal of bitmask to make bitwise operations easier
    AND W9, W5, #0x00010000 // get the state if the right most bit shown on the firt row
    LSL X9, X9, #47         // shift the bit so its now the left most bit (the bit that will be shown on the beginning of the row)
    LSR X5, X5, #1          // shift the bitmask to the right by one bit
    ORR X5, X5, X9          // combine the shifted bitmask with the bit we got from the right most bit to get the new bitmask we want to write out
    REV X5, X5              // reverse the bitmask again to make writing to the frame buffer easier
    MOVZ X19, #1            // keep the mode set to animate mode
    B func_shiftBasedPattern    // branch to func_shiftBasedPattern

// create a pattern in the frame buffer through shifting a bitmask
func_shiftBasedPattern:
    MOV X4, X28             // the register containg the address which will be incremented over
    MOV X6, X23             // the parameter for the upperbound of the iteration
    .shiftLoop:
        // Write the last 6 bytes stored in X5
        UBFX X9, X5, #0, #32
        STR W9, [X4], #4
        UBFX X9, X5, #32, #16
        STRH W9, [X4], #2
    
        // shift the 48 bits of the bitmask to the right by one (the rightmost bit gets wrapped to the leftmost bit)
        REV X5, X5
        AND W9, W5, #0x00010000
        LSL X9, X9, #47
        LSR X5, X5, #1
        ORR X5, X5, X9
        REV X5, X5

        // See if theres more of the frame buffer to write to
        CMP X4, X6
        BLT .shiftLoop       // if there is more frameBuffer to write to we loop again
    B func_write                // if not write the current frame buffer

// create the half black and half white pattern in the frame buffer
func_half:
    MOV X4, X28 // the register containg the address which will be incremented over
    MOV X5, X20 // the bitmask for the half pattern
    MOV X6, X23 // the parameter for the upperbound of the iteration
    .halfLoop:
        // Write the last 6 bytes stored in X5
        UBFX X9, X5, #0, #32
        STR W9, [X4], #4
        UBFX X9, X5, #32, #16
        STRH W9, [X4], #2

        // shift the bitmask to the right whilst making sure the left most bits stays the same (there by adding a new 1 to the right of the line of ones making up the bitmask)
        REV X5, X5
        LSR X9, X5, #1
        ORR X5, X9, X5
        REV X5, X5

        // See if theres more of the frame buffer to write to
        CMP X4, X6
        BLT .halfLoop        // if there is more frameBuffer to write to we loop again
    B func_write                // if not write the current frame buffer
    
// reset the file and terminal settings and then exit
func_exit:
    // Enable blocking
    // We will enable blocking since we disabled it at the start of the program and we want to set it back to how it was before we changed it (which is blocking)
    // Get file settings
    MOVZ X0, #0 // set file descriptor to STDIN
    MOVZ X1, #3 // signal a F_GETFL command
    MOVZ X8, #25 // signal the syscall as FCTNL
    SVC #0 // make syscall

    // Alter settings to enable blocking (set it back to how it was before we changed it)
    MOV X2, X0
    BIC X2, X2, #0x800

    // Set files settings
    MOVZ X0, #0 // set file descriptor to STDIN
    MOVZ X1, #4 // signal a F_SETFL command
    MOVZ X8, #25 // signal the syscall as FCTNL
    SVC #0 // make syscall

    // Disbale raw mode
    // Set terminal settings back to ogTermios
    MOV X0, #0  // file descriptor = 0 (STDIN)
    LDR X1, =0x5402 // signal a TCSETS command
    LDR X2, =ogTermios // pointer to ogTermios struct
    MOV X8, #29  // signal IOCTL syscall
    SVC #0 // make syscall

    // Exit
    MOVZ x0, #0  // set exit code to 0
    MOVZ x8, #93 // signal that syscall is an exit
    SVC #0 // make syscall // syscall
