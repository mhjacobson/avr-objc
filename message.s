;
; message.s
; author: Matt Jacobson
; created: June 2021
;

; Caller-saved: (r18-r25, X, Z)
; Callee-saved: (r2-r17, Y)

.macro PUSHARGS
    ; save all registers that could contain arguments AND which are caller-saved (i.e., might be clobbered by class_lookupMethod) or which we wish to use as scratch
    push r25
    push r24
    push r23
    push r22
    push r21
    push r20
    push r19
    push r18
.endm

.macro POPARGS
    ; restore all registers that could contain arguments AND which are caller-saved (i.e., might be clobbered by class_lookupMethod) or which we wish to use as scratch
    pop r18
    pop r19
    pop r20
    pop r21
    pop r22
    pop r23
    pop r24
    pop r25
.endm

.globl objc_msgSend
objc_msgSend:
    ; self <- r25:r24
    ; _cmd <- r23:r22

    tst r24
    brne __msgSend_nonzero
    tst r25
    brne __msgSend_nonzero

    ; self == 0x0, so return zero
    ; zeroing out r18 through r25 covers all the C integer types, plus float, double, and long double.
    ; it does not cover _Complex types, which GCC currently (incorrectly) dispatches with objc_msgSend.
    ; structs are covered by the stret variant.
    ldi r18, 0
    ldi r19, 0
    ldi r20, 0
    ldi r21, 0
    ldi r22, 0
    ldi r23, 0
    ldi r24, 0
    ldi r25, 0
    ret

__msgSend_nonzero:
    PUSHARGS

    ; X <- self (r25:r24)
    movw X, r24

    ; cls (r25:r24) <- *X
    ld r24, X+
    ld r25, X+

    ; _cmd remains in r23:r22
    call class_lookupMethod
    ; imp <- r25:r24

    ; Z <- imp (r25:r24)
    movw Z, r24

    POPARGS

    ijmp

; struct objc_super {
;     id receiver;
;     Class super_class; /* super_class is the first class to search */
; };

.globl objc_msgSendSuper2
objc_msgSendSuper2:
    ; objc_super <- r25:r24
    ; _cmd <- r23:r22

    ; X <- objc_super
    movw X, r24

    ; r25:r24 <- *X; this places `self` back into the arg0 position
    ld r24, X+
    ld r25, X+

    ; Z <- *X; this loads the caller class
    ld r30, X+
    ld r31, X+

    PUSHARGS

    ; Z still contains our caller class.  move it into arg0 and call class_getSuperclass
    movw r24, Z
    call class_getSuperclass

    ; the next search class is now in r25:r24
    ; _cmd remains in r23:r22
    call class_lookupMethod
    ; imp <- r25:r24

    ; Z <- imp (r25:r24)
    movw Z, r24

    POPARGS

    ijmp

;;;
;;; STRET VARIANTS
;;;

.globl objc_msgSend_stret
objc_msgSend_stret:
    ; return <- r25:r24
    ; self <- r23:r22
    ; _cmd <- r21:r20

    tst r22
    brne __msgSend_stret_nonzero
    tst r23
    brne __msgSend_stret_nonzero

    ; self == 0x0, so return.  We're unable to "return zero" here, and we rely on the compiler's preemptively zeroing out the return struct.
    ret

__msgSend_stret_nonzero:
    PUSHARGS

    ; X <- self (r23:r22)
    movw X, r22

    ; cls (r25:r24) <- *X
    ld r24, X+
    ld r25, X+

    ; move _cmd to r23:r22
    movw r22, r20

    call class_lookupMethod
    ; imp <- r25:r24

    ; Z <- imp (r25:r24)
    movw Z, r24

    POPARGS

    ijmp

.globl objc_msgSendSuper2_stret
objc_msgSendSuper2_stret:
    ; return <- r25:r24
    ; objc_super <- r23:r22
    ; _cmd <- r21:r20

    ; X <- objc_super
    movw X, r22

    ; r25:r24 <- *X; this places `self` back into the arg1 position
    ld r22, X+
    ld r23, X+

    ; Z <- *X; this loads the caller class
    ld r30, X+
    ld r31, X+

    PUSHARGS

    ; Z still contains our caller class.  move it into arg0 and call class_getSuperclass
    movw r24, Z
    call class_getSuperclass

    ; the next search class is now in r25:r24
    ; move _cmd to arg2
    movw r22, r20

    call class_lookupMethod
    ; imp <- r25:r24

    ; Z <- imp (r25:r24)
    movw Z, r24

    POPARGS

    ijmp

;;;
;;; FIXUP VARIANTS
;;;

; struct message_ref {
;     id (*messenger)(id self, SEL _cmd, ...);
;     SEL _cmd;
; };

.macro FIXUPVARIANT messenger stret
.globl \messenger\()_fixup
\messenger\()_fixup:
    ; X <- message_struct
    .ifb \stret
        movw X, r22
    .else
        movw X, r20
    .endif

    ; The messenger function in the struct is ignored, since we don't do the fixup optimization
    ; (nor does Apple's objc4 anymore!)
    ; X <- &message_struct._cmd
    adiw X, 2

    ; _cmd <- *X
    .ifb \stret
        ld r22, X+
        ld r23, X+
    .else
        ld r20, X+
        ld r21, X+
    .endif

    jmp \messenger
.endm

FIXUPVARIANT objc_msgSend
FIXUPVARIANT objc_msgSendSuper2
FIXUPVARIANT objc_msgSend_stret STRET
FIXUPVARIANT objc_msgSendSuper2_stret STRET
