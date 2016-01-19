.ORIG x3000

; STEP 1 -----------------------------------------------------------------------
; 1. Determine the values of A and S, and the initial value of P.
; All of these numbers should have a length equal to (x + y + 1).
; A: Fill the most significant (leftmost) bits with the value of m.
;    Fill the remaining (y + 1) bits with zeros.
; S: Fill the most significant bits with the value of (−m) in two's complement notation.
;    Fill the remaining (y + 1) bits with zeros.
; P: Fill the most significant x bits with zeros.
;    To the right of this, append the value of r.
;    Fill the least significant (rightmost) bit with a zero.

; For this implementation A, S, and P all have 1 less zero to the right
; A: Only the remaining y bits are filled with zeroes.
; S: Only the remaining y bits are filled with zeroes.
; P: The least significant bit isn't filled a zero.
; This is taken care of by the next part

; R2 - A
; R3 - S
; R4 - P
; R5 - P mask
; R6 - counter

LDI R2, TERM1_ADDR ; load first term
NOT R3, R2 ; negate 2's complement, not
ADD R3, R3, #1 ; negate 2's complement, add 1
AND R6, R6, #0 ; clear counter
ADD R6, R6, #8 ; start counter at 8 (count down) because both are 8 bit numbers
FILL_ZEROES_LOOP ; completes the setup for A and S
  BRz FILL_ZEROES_LOOP_END ; branch to the end if counter is zero
  ADD R2, R2, R2 ; shift A left
  ADD R3, R3, R3 ; shift S left
  ADD R6, R6, #-1 ; decrement counter
  BR FILL_ZEROES_LOOP ; branch to the start of the loop
FILL_ZEROES_LOOP_END
LDI R4, TERM2_ADDR ; load second term
LD R5, P_MASK ; load P mask
AND R4, R4, R5 ; set everything except last 8 bits to 0

; FIRST LOOP OF STEP 2 AND 3 ---------------------------------------------------
; Because for the first loop the least significant bit is always 0,
; this only tests for the second least significant bit.
; Out of these four cases only 1 is relevant.
; If they are 01, find the value of P + A. Ignore any overflow.
; If they are 10, find the value of P + S. Ignore any overflow.
; If they are 00, do nothing. Use P directly in the next step.
; If they are 11, do nothing. Use P directly in the next step.
; We don't need to check the last two because we don't need to do anything to P
; and we only need to check the case of 10 because 01 is impossible since the
; second bit has to equal 0.
; Step 3 can be ignored because the extra 0 wasn't appended in the last part.

; R0 - branch test value
; R2 - A
; R3 - S
; R4 - P

AND R0, R4, #1 ; get LSB
BRz SKIP
  ADD R4, R3, R4 ; P = P + S
SKIP

; Shift A and S to the left by 1 bit because this format is required for the next part.
ADD R2, R2, R2
ADD R3, R3, R3

; STEPS 2 TO 4 -----------------------------------------------------------------
; 2. Determine the two least significant (rightmost) bits of P.
;    If they are 01, find the value of P + A. Ignore any overflow.
;    If they are 10, find the value of P + S. Ignore any overflow.
;    If they are 00, do nothing. Use P directly in the next step.
;    If they are 11, do nothing. Use P directly in the next step.
; 3. Arithmetically shift the value obtained in the 2nd step by a single place to the right.
;    Let P now equal this new value.
; 4. Repeat steps 2 and 3 until they have been done y times.

; R6 - counter

AND R6, R6, #0 ; clear counter
ADD R6, R6, #7 ; set counter to 7
MAIN_LOOP
  BRz MAIN_LOOP_END ; branch to the end if counter is zero

  ; R0 - LSBITS_MASK
  ; R1 - two least significant bits
  ; R2 - A
  ; R3 - S
  ; R4 - P
  ; R5 - branch test value
  LD R0, LSBITS_MASK ; load the lsbits mask
  AND R1, R4, R0 ; get two lsbits

  ADD R5, R1, #-1 ; if the lsbits are equal to 01
  BRnp LSB_SKIP1
    ADD R4, R4, R2 ; P = P + A
  LSB_SKIP1

  ADD R5, R1, #-2 ; if the lsbits are equal to 10
  BRnp LSB_SKIP2
    ADD R4, R4, R3 ; P = P + S
  LSB_SKIP2

  JSR ST_VALUES
  JSR ARITHMETIC_SHIFT_RIGHT
  JSR LD_VALUES

  ADD R6, R6, #-1 ; decrement counter
  BR MAIN_LOOP
MAIN_LOOP_END

; STEP 5
; Drop the least significant (rightmost) bit from P. This is the product of m and r.

JSR ST_VALUES
JSR ARITHMETIC_SHIFT_RIGHT
JSR LD_VALUES
STI R4, RESULT

HALT

TERM1_ADDR .FILL x3F00
TERM2_ADDR .FILL x3F01
RESULT .FILL x3FFF

MSB_MASK .FILL x8000
LSBITS_MASK .FILL x0003
P_MASK .FILL x00FF

STORAGE .BLKW #2

ST_VALUES
  LEA R0, STORAGE
  STR R2, R0, #0
  STR R3, R0, #1
  RET

LD_VALUES
  LEA R0, STORAGE
  LDR R2, R0, #0
  LDR R3, R0, #1
  RET

; R0 - P
; R1 - branch test value
; R2 - previous bit value, a number with only the previous bit set as 1
;      and every other bit set as 0
; R3 - mask
; R4 - new P

ARITHMETIC_SHIFT_RIGHT
  ADD R0, R4, #0 ; copy R4 to R0
  AND R4, R4, #0 ; clear R4

  AND R2, R2, #0 ; clear R2
  ADD R2, R2, #1 ; start R2 at 1
  ADD R3, R2, #0 ; set R3 equal to R2
  SHIFT_LOOP
    ADD R3, R3, R3 ; shift mask to the left
    AND R1, R0, R3 ; get current bit
    BRz SHIFT_SKIP ; skip if the current bit is zero
      ADD R4, R4, R2 ; set the bit to the right as the current bit value
    SHIFT_SKIP
    ADD R3, R3, #0 ; setCC for R3
    BRn SHIFT_LOOP_END ; branch to end if mask is 0 because it would mean that
                       ; there was overflow and the mask was previously at x8000
    ADD R2, R2, R2 ; shift previous bit value to the left
    BR SHIFT_LOOP
  SHIFT_LOOP_END

  AND R1, R4, R2 ; get the second most significant bit of the new value of P
  BRz MSB_SKIP ; if it's 0 then skip because that bit is already set to 0
    ADD R4, R4, R3 ; if it's 1 then we also have to set the most signifcant bit
                   ; to 1 because of the arithmetic shift
  MSB_SKIP
  RET

.END
