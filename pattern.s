.global _start
.text

_start:
    mov r8, #3
    add r8, #4

    // Exit program
    mov r0, #0
    mov r7, #1
    svc #0