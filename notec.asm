; Operations chars.
CHAR_STOP_READING   equ '='
CHAR_ADD            equ '+'
CHAR_MULTIPLY       equ '*'
CHAR_NEGATION       equ '-'
CHAR_AND            equ '&'
CHAR_OR             equ '|'
CHAR_XOR            equ '^'
CHAR_BIT_NEGATION   equ '~'
CHAR_POP            equ 'Z'
CHAR_DUPLICATE      equ 'Y'
CHAR_SWAP           equ 'X'
CHAR_PUSH_N         equ 'N'
CHAR_PUSH_INDEX     equ 'n'
CHAR_DEBUG          equ 'g'
CHAR_WAIT_AND_SWAP  equ 'W'

default rel

section .bss
    values      resq N          ; Buffor for exchanging stack values between notec's.


section .data
    align 4                     ; Align to enable atomic operations.
    waitFor:    times N dd -1   ; i-th element of array indicates on which notec i-th notec is waiting. Values is negative if notec isn't waiting for any notec.


section .text
    global  notec
    extern  debug


; Single operation performs calculations and jumps back to main code.

; Macro for pasting all cases.
%macro catch_operation 0

; No registers is changed.
; No value is pushed on stack.
.read:
    mov     qword [rbp - 16], STATE_READING
    shl     qword [rbp - 8], 4
    add     qword [rbp - 8], r12
    jmp     .no_result

; rax is changed.
; One value is pushed on stack.
.add_numbers:
    add     rax, rdx
    jmp     .one_result

; rax is changed.
; One value is pushed on stack.
.multiply_numbers:
    mul     rdx
    jmp     .one_result

; rax is changed.
; One value is pushed on stack.
.negate_number:
    neg     rax
    jmp     .one_result

; rax is changed.
; One value is pushed on stack.
.and_numbers:
    and     rax, rdx
    jmp     .one_result

; rax is changed.
; One value is pushed on stack.
.or_numbers:
    or      rax, rdx
    jmp     .one_result

; rax is changed.
; One value is pushed on stack.
.xor_numbers:
    xor     rax, rdx
    jmp     .one_result

; rax is changed.
; One value is pushed on stack.
.bit_negate_number:
    not     rax
    jmp     .one_result

; rdx is changed.
; Two values are pushed on stack.
.duplicate:
    mov     rdx, rax
    jmp     .two_results

; rax and rdx are changed.
; Two values are pushed on stack.
.swap:
    xchg    rax, rdx
    jmp     .two_results

; rax is changed.
; One value is pushed on stack.
.push_n:
    mov     rax, N
    jmp     .one_result

; rax is changed.
; One value is pushed on stack.
.push_id:
    mov     rax, [rbp - 24]
    jmp     .one_result

; rax, rdi, rsi, r12, rsp are changed.
; Others registers can be changed by calling debug according to ABI.
; No value is pushed on stack.
.debug_operation:
    mov     rdi, [rbp - 24] ; Pass notec id to function.
    mov     rsi, rsp        ; Pass stack pointer to function.
    mov     r12, rsp        ; Save rsp.

    and     rsp, -16        ; Align stack to 8 mod 16.
    call    debug

    mov     rsp, r12        ; Restore rsp.
    xor     r12, r12        ; Reset r12 for further operations.
    shl     rax, 3          ; Get how many about bites stack has to be moved.
    add     rsp, rax        ; Move stack pointer according to debug result.
    jmp     .no_result

; rax, rdi, rsi, r8, r9, r11 are changed.
; One value is pushed on stack.
.wait_and_swap:
    mov     r8, rax                     ; Store m.
    mov     r9, [rbp - 24]              ; Store n.
    lea     r11, [waitFor]              ; Pointer to waitFor array.
    lea     rsi, [values]               ; Pointer to values array.

    mov     qword [rsi + 8 * r9], rdx   ; Move value from top of stack to common array.
    mov     dword [r11 + 4 * r9], r8d   ; Send information that notec is waiting for m-th notec.
%%.wait_for_start:
    cmp     dword [r11 + 4 * r8], r9d
    jne     %%.wait_for_start           ; Wait for m-th notec.

    ; There are two roles for notecs in pair.
    ; First - notec with smaller id.
    ; Second - notec with greater id.
    cmp     r8, r9                      ; Check role.
    ja      %%.second_start
%%.first_start:
    mov     rax, -1                     ; Set value for comparison.
%%.first_wait_for_start:
    cmp     dword [r11 + 4 * r9], eax
    jne     %%.first_wait_for_start     ; Wait for signal from second notec.
    jmp     %%.swap_start

%%.second_start:
    mov     dword [r11 + 4 * r8], -1    ; Allow first notec to move on.
%%.swap_start:
    mov     rdi, qword [rsi + 8 * r8]   ; Take value from other notec.

    cmp     r8, r9                      ; Check role.
    jb      %%.first_end
%%.second_end:
    mov     rax, -1                     ; Set value for comparison.
%%.second_wait_for_end:
    cmp     dword [r11 + 4 * r9], eax
    jne     %%.second_wait_for_end      ; Wait for signal from first notec.
    jmp     %%.wait_and_swap_end

%%.first_end:
    mov     dword [r11 + 4 * r8], -1    ; Allow second notec to move on.
%%.wait_and_swap_end:
    mov     rax, rdi                    ; Return value from other notec.
    jmp     .one_result
%endmacro

%macro case 2
    cmp     r12b, %1                    ; Check case condition.
    je      %2                          ; Jump to operation if it matches case.
%endmacro


; Possible states of notec.
STATE_NONE      equ 0   ; Default mode.
STATE_READING   equ 1   ; Entering mode.

; Function calculates RPN.
; rdi - number of notecs,
; rsi - operations string.
notec:
    ; Save registers to enable changing it.
    push    rbp
    push    r12
    push    r13
    mov     rbp, rsp        ; Set current bottom of stack used by notec.
    ; [rbp - 8] - value that is currently entered.
    ; [rbp - 16] - current state (entering mode or none).
    ; [rbp - 24] - notec id.
    push    qword 0         ; Reset currently entered value.
    push    STATE_NONE      ; Set default state.
    push    rdi             ; Set notec id.

    ; r12b - operation char.
    ; r13 - current position in operations string.
    mov     r13, rsi
    xor     r12, r12        ; Reset register for using only its first byte.
    mov     r12b, byte [r13]
    cmp     r12b, 0
    jz      .end            ; String has no operations.
.loop:
    ; Check if it's entering mode.
    cmp     r12b, '0'
    jb      .not_number
    cmp     r12b, 'A'
    jb      .check_digit
    cmp     r12b, 'a'
    jb      .check_letter_uppercase
.check_letter_lowercase:
    cmp     r12b, 'f'
    ja      .not_number

    sub     r12b, 'a' - 10      ; Change char to its value.
    jmp     .read

.check_digit:
    cmp     r12b, '9'
    ja      .not_number

    sub     r12b, '0'           ; Change char to its value.
    jmp     .read

.check_letter_uppercase:
    cmp     r12b, 'F'
    ja      .not_number

    sub     r12b, 'A' - 10      ; Change char to its value.
    jmp     .read

.not_number:
    ; Check if it was entering mode.
    cmp     qword [rbp - 16], STATE_READING
    jne     .not_number_effect
    ; Previously it was entering mode.
    mov     qword [rbp - 16], STATE_NONE
    push    qword [rbp - 8]
    mov     qword [rbp - 8], 0              ; Reset currently entered value.
.not_number_effect:
    ; Check every possible option without stack arguments.
    case    CHAR_STOP_READING,  .no_result
    case    CHAR_PUSH_N,        .push_n
    case    CHAR_PUSH_INDEX,    .push_id
    case    CHAR_DEBUG,         .debug_operation

    pop     rax                 ; Pop value from top of stack.

    ; Check every possible option with one stack arguments.
    case    CHAR_NEGATION,      .negate_number
    case    CHAR_BIT_NEGATION,  .bit_negate_number
    case    CHAR_POP,           .no_result
    case    CHAR_DUPLICATE,     .duplicate

    pop     rdx                 ; Pop value from top of stack.

    ; Check every possible option with two stack arguments.
    case    CHAR_ADD,           .add_numbers
    case    CHAR_MULTIPLY,      .multiply_numbers
    case    CHAR_AND,           .and_numbers
    case    CHAR_OR,            .or_numbers
    case    CHAR_XOR,           .xor_numbers
    case    CHAR_SWAP,          .swap
    case    CHAR_WAIT_AND_SWAP, .wait_and_swap

    ; Catch every possible operation jump.
    catch_operation
.two_results:   ; Two values are pushed to stack.
    push    rdx
.one_result:    ; One value is pushed to stack.
    push    rax
.no_result:     ; No value is pushed to stack.
    inc     r13                 ; Move to next register.
    mov     r12b, byte [r13]
    cmp     r12b, 0             ; Check if it is end of string.
    jnz     .loop
.end:
    mov     rax, [rbp - 8]      ; Move entered number to top value from stack register.
    mov     rdx, [rbp - 16]
    cmp     rdx, STATE_READING
    je      .end_restore        ; It was entering mode, so top value from stack was entered.
    pop     rax                 ; It wasn't entering mode, so top value is placed on program stack.
.end_restore:
    ; Restore previous registers values.
    mov     rsp, rbp
    pop     r13
    pop     r12
    pop     rbp
    ret
