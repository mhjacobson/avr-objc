;
; misc.s
; author: Matt Jacobson
; created: July 2021
;

.globl _objc_empty_cache
.equ _objc_empty_cache, 0

.globl _objc_empty_vtable
.equ _objc_empty_vtable, 0

; Force libgcc's __do_global_ctors to be linked in, so that our initializer runs.
; TODO: remove this once this LLVM fix goes in:
; <https://reviews.llvm.org/D107133>
.globl __do_global_ctors
