$NOLIST
$MODLP51
$LIST

org 0000H
   ljmp main
   
; Timer/Counter 0 overflow interrupt vector
org 0x000B
	ljmp Timer0_ISR
; Timer/Counter 1 overflow interrupt vector
org 0x001B
	ljmp Timer1_ISR   
; Timer/Counter 2 overflow interrupt vector
org 0x002B
    reti

; These register definitions needed by 'math32.inc'
DSEG at 30H
x:   ds 4
y:   ds 4
bcd: ds 5
Count1ms: ds 2

Seed: ds 4
Score1: ds 1
Score2: ds 1

BSEG
mf: dbit 1
HLbit: dbit 1
abortFlag: dbit 1

PlayerWin: dbit 1 ; flag to tell who won: 0 - playerOne, 1 - playerTwo

$NOLIST
$include(math32.inc)
$LIST

cseg
CLK           EQU 22118400 ; Microcontroller system crystal frequency in Hz

TIMER0_RATE1   EQU 4000     ; 2000Hz squarewave (peak amplitude of CEM-1203 speaker) ; Pin 1.1
TIMER0_RELOAD1 EQU ((65536-(CLK/TIMER0_RATE1))) ; LOW TONE
TIMER0_RATE2   EQU 4200     ; 2100Hz squarewave (peak amplitude of CEM-1203 speaker) ; Pin 1.1
TIMER0_RELOAD2 EQU ((65536-(CLK/TIMER0_RATE2))) ; HIGH TONE
TIMER1_RATE1   EQU 500     ; 250Hz squarewave (peak amplitude of CEM-1203 speaker) ; Pin 1.1
TIMER1_RELOAD1 EQU ((65536-(CLK/TIMER1_RATE1))) ; LOW TONE

; TONE FREQUENCY

A5_RATE			EQU ((65536-(CLK/(2*A5_FREQUENCY))))
A5_FREQUENCY	EQU 440
A5b_RATE		EQU ((65536-(CLK/(2*A5b_FREQUENCY))))
A5b_FREQUENCY	EQU 415
B5_RATE			EQU ((65536-(CLK/(2*B5_FREQUENCY))))
B5_FREQUENCY	EQU 494
B5b_RATE		EQU ((65536-(CLK/(2*B5b_FREQUENCY))))
B5b_FREQUENCY	EQU 466
C5_RATE			EQU ((65536-(CLK/(2*C5_FREQUENCY))))
C5_FREQUENCY	EQU 523
D5_RATE			EQU ((65536-(CLK/(2*D5_FREQUENCY))))
D5_FREQUENCY	EQU 622
E5_RATE			EQU ((65536-(CLK/(2*E5_FREQUENCY))))
E5_FREQUENCY	EQU 660



; These 'equ' must match the hardware wiring
LCD_RS equ P3.2
;LCD_RW equ PX.X ; Not used in this code, connect the pin to GND
LCD_E  equ P3.3
LCD_D4 equ P3.4
LCD_D5 equ P3.5
LCD_D6 equ P3.6
LCD_D7 equ P3.7

SOUND_OUT equ P1.1
BOOT_BUTTON equ P4.5
RESET_BUTTON equ P0.4

$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$LIST

;                     1234567890123456    <- This helps determine the location of the counter
Initial_Message:  db 'Period (ns):   ', 0
No_Signal_Str:    db 'No signal      ', 0
No_Signal_Str1:  db 'No signal T1', 0
Score1_Str:      db  'Score1: 00', 0
Score2_Str:      db  'Score2: 00', 0
Player_Wins:	db 'Player   Wins!  ', 0
Play_Again:     db 'Play again', 0
Menu_String1: 	db 'Hold BOOT to', 0
Menu_String2:	db 'Start game', 0

; Sends 10-digit BCD number in bcd to the LCD
Display_10_digit_BCD:
	Display_BCD(bcd+4)
	Display_BCD(bcd+3)
	Display_BCD(bcd+2)
	Display_BCD(bcd+1)
	Display_BCD(bcd+0)
	ret
	
;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 0                     ;
;---------------------------------;
Timer0_Init:
	mov a, TMOD
	anl a, #0xf0 ; Clear the bits for timer 0
	orl a, #0x01 ; Configure timer 0 as 16-timer
	mov TMOD, a
	mov TH0, #high(TIMER0_RELOAD1)
	mov TL0, #low(TIMER0_RELOAD1)
	; Set autoreload value
	mov RH0, #high(TIMER0_RELOAD1)
	mov RL0, #low(TIMER0_RELOAD1)
	; Enable the timer and interrupts
    setb ET0  ; Enable timer 0 interrupt
    clr TR0  ; DONT start timer 0 yet
	ret

;---------------------------------;
; ISR for timer 0.
;---------------------------------;
Timer0_ISR:
	;clr TF0  ; According to the data sheet this is done for us already.
	cpl SOUND_OUT ; Connect speaker to P1.1!
	reti

Timer1_ISR: 
	;clr TF1 ; According to data sheet this is done for us already.
	push acc
	push psw
	
	inc Count1ms+0
	mov a, Count1ms+0
	jnz Inc_Done
	inc Count1ms+1

Inc_Done:
    mov a, Count1ms+0
    cjne a, #low(1000), Timer1_ISR_done
    mov a, Count1ms+1
    cjne a, #high(1000), Timer1_ISR_done

	setb abortFlag
	clr a 
	
	mov Count1ms+0, a
	mov Count1ms+1, a
	
Timer1_ISR_done:
    ;Set_cursor(2,7)
    ;Display_char(#'g')
    pop psw
    pop acc
    
	reti

InitTimer1:
	mov a, TMOD
	anl a, #0x0f ; Clear the bits for timer 1
	orl a, #0x10 ; Configure timer 1 as 16-timer
	mov TMOD, a
	mov TH1, #high(TIMER1_RELOAD1)
	mov TL1, #low(TIMER1_RELOAD1)
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	; Set autoreload value
	mov RH1, #high(TIMER1_RELOAD1)
	mov RL1, #low(TIMER1_RELOAD1)
	setb ET1 ; set timer1 interrupt to 1
	clr TR1 ; don't start timer right away
	ret

;Initializes timer/counter 2 as a 16-bit timer
InitTimer2:
	mov T2CON, #0 ; Stop timer/counter.  Set as timer (clock input is pin 22.1184MHz).
	; Set the reload value on overflow to zero (just in case is not zero)
	mov RCAP2H, #0
	mov RCAP2L, #0
	setb ET2
    ret
    
Init_Seed3:
	; Wait for a push of the BOOT button
	; to initialize random seed:
	setb TR2
	;jb BOOT_BUTTON, $

	Set_Cursor(2,1)
	Display_char(#'!')
	mov Seed+0, TH2
	mov Seed+1, #0x01
    mov Seed+2, #0x87
    mov Seed+3, TL2
    clr TR2
    ljmp main2
    
Random:
	; Seed = 214013*Seed + 2531011
	mov x+0, Seed+0
	mov x+1, Seed+1
	mov x+2, Seed+2
	mov x+3, Seed+3
	Load_y(214013)
	lcall mul32
	Load_y(2531011)
	lcall add32
	mov Seed+0, x+0
	mov Seed+1, x+1
	mov Seed+2, x+2
	mov Seed+3, x+3
	ret
	
Play_A5_2:
	clr TR0
	mov TH0, #high(A5_RATE)
	mov TL0, #low(A5_RATE)
	; Set autoreload value
	mov RH0, #high(A5_RATE)
	mov RL0, #low(A5_RATE)
	setb TR0
	ret
	
Play_A5b:
	clr TR0
	mov TH0, #high(A5b_RATE)
	mov TL0, #low(A5b_RATE)
	; Set autoreload value
	mov RH0, #high(A5b_RATE)
	mov RL0, #low(A5b_RATE)
	setb TR0
	ret
	
Play_B5:
	clr TR0
	mov TH0, #high(B5_RATE)
	mov TL0, #low(B5_RATE)
	; Set autoreload value
	mov RH0, #high(B5_RATE)
	mov RL0, #low(B5_RATE)
	setb TR0
	ret
	
Play_B5b:
	clr TR0
	mov TH0, #high(B5b_RATE)
	mov TL0, #low(B5b_RATE)
	; Set autoreload value
	mov RH0, #high(B5b_RATE)
	mov RL0, #low(B5b_RATE)
	setb TR0
	ret
	
Play_C5:
	clr TR0
	mov TH0, #high(C5_RATE)
	mov TL0, #low(C5_RATE)
	; Set autoreload value
	mov RH0, #high(C5_RATE)
	mov RL0, #low(C5_RATE)
	setb TR0
	ret
		
Play_D5:
	clr TR0
	mov TH0, #high(D5_RATE)
	mov TL0, #low(D5_RATE)
	; Set autoreload value
	mov RH0, #high(D5_RATE)
	mov RL0, #low(D5_RATE)
	setb TR0
	ret
	
Play_E5:
	clr TR0
	mov TH0, #high(E5_RATE)
	mov TL0, #low(E5_RATE)
	; Set autoreload value
	mov RH0, #high(E5_RATE)
	mov RL0, #low(E5_RATE)
	setb TR0
	ret

Wait_Random:
	Wait_Milli_Seconds(Seed+0)
	Wait_Milli_Seconds(Seed+1)
	Wait_Milli_Seconds(Seed+2)
	Wait_Milli_Seconds(Seed+3)
	ret
	
Play_A5:
	ljmp Play_A5_2
	
Init_Seed2:
	ljmp Init_Seed3
	
Tetris:
	lcall Play_E5
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#83)
	jnb BOOT_BUTTON, Init_Seed2
	lcall Play_B5
	Wait_Milli_Seconds(#168)
	lcall Play_C5
	Wait_Milli_Seconds(#168)
	lcall Play_D5
	Wait_Milli_Seconds(#168)
	jnb BOOT_BUTTON, Init_Seed2
	lcall Play_E5
	Wait_Milli_Seconds(#84)
	lcall Play_D5
	Wait_Milli_Seconds(#84)
	lcall Play_C5
	Wait_Milli_Seconds(#164)
	lcall Play_B5
	Wait_Milli_Seconds(#164)
	jnb BOOT_BUTTON, Init_Seed2
	lcall Play_A5
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#83)
	lcall WaitNote
	lcall Play_A5
	Wait_Milli_Seconds(#168)
	lcall Play_C5
	Wait_Milli_Seconds(#168)
	lcall Play_E5
	Wait_Milli_Seconds(#250)
	jnb BOOT_BUTTON, Init_Seed4
	Wait_Milli_Seconds(#83)
	lcall Play_D5
	Wait_Milli_Seconds(#168)
	lcall WaitNote
	lcall Play_C5
	Wait_Milli_Seconds(#168)
	lcall WaitNote
	lcall Play_B5
	Wait_Milli_Seconds(#250)
	ljmp nextttt
	
Init_Seed4:
	ljmp Init_Seed
	
nextttt:
	Wait_Milli_Seconds(#83)
	jnb BOOT_BUTTON, Init_Seed
	lcall Play_B5
	Wait_Milli_Seconds(#84)
	lcall WaitNote
	lcall Play_B5
	Wait_Milli_Seconds(#84)
	lcall Play_C5
	Wait_Milli_Seconds(#168)
	lcall Play_D5
	Wait_Milli_Seconds(#250)
	jnb BOOT_BUTTON, Init_Seed
	Wait_Milli_Seconds(#83)
	lcall Play_E5
	ljmp nextt
	
Init_Seed:
	ljmp Init_Seed2
	
nextt:
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#83)
	jnb BOOT_BUTTON, Init_Seed
	lcall Play_C5
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#83)
	jnb BOOT_BUTTON, Init_Seed
	lcall Play_A5
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#83)
	lcall WaitNote
	jnb BOOT_BUTTON, Init_Seed
	lcall Play_A5
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	jnb BOOT_BUTTON, Init_Seed
	Wait_Milli_Seconds(#167)
	
	lcall Tetris
	
FF7:
	lcall Play_C5
	Wait_Milli_Seconds(#140)

	lcall WaitNote
	lcall Play_C5
	Wait_Milli_Seconds(#140)

	lcall WaitNote
	lcall Play_C5
	Wait_Milli_Seconds(#140)
	lcall WaitNote
	lcall Play_C5
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#150)
	lcall WaitNote
	lcall Play_A5b
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#150)
	lcall WaitNote
	lcall Play_B5b
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#150)
	lcall WaitNote
	lcall Play_C5
	Wait_Milli_Seconds(#250)
	lcall WaitNote
	lcall Play_B5b
	Wait_Milli_Seconds(#140)
	lcall WaitNote
	lcall Play_C5
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)

	ret

WaitNote:
	clr TR0
	Wait_Milli_Seconds(#8)
	setb TR0
ret
	
;---------------------------------;
; Hardware initialization         ;
;---------------------------------;
Initialize_All:
    lcall InitTimer2
    lcall Timer0_Init
    lcall InitTImer1
    lcall LCD_4BIT ; Initialize LCD
    setb EA
    ;lcall Tetris
    ;lcall Init_Seed
 	
	ret

;---------------------------------;
; Main program loop               ;
;---------------------------------;
main:
    ; Initialize the hardware:
    mov SP, #7FH
    lcall Initialize_All
    Set_cursor(1,1)
    Send_Constant_String(#Menu_String1)
    Set_cursor(2,1)
    Send_Constant_String(#Menu_String2)
    ;lcall FF7
    ljmp Tetris
main2:
    WriteCommand(#0x01)
	Wait_Milli_Seconds(#5)
    setb P0.0 ; Pin is used as input for 555 timer for timer/counter2
    setb P0.1 ; Pin for 555 timer for timer/counter1
    clr HLbit 
    clr TR0 ; clear timer 0 so no sound when game first starts
    clr abortFlag
    mov Score1, #0
    mov Score2, #0
    Set_cursor(1, 1)
    Send_Constant_String(#Score1_Str)
    Set_cursor(2, 1)
    Send_Constant_String(#Score2_Str)
    
    
    clr P2.0

	Set_Cursor(1, 1)
    ;Send_Constant_String(#Initial_Message) 
    
; LETS SAY HIGHER TONE IS BADDDDDD
forever:

	; First part of the game: decide which freq to buzz at
	
	lcall Random
	mov a, Seed+1
	mov c, acc.3
	mov HLbit, c
	jc setup_tone2 ; if carry is one, we play tone2
	; if carry is zero, we play tone1, the LOW tone
	mov RH0, #high(TIMER0_RELOAD1)
	mov RL0, #low(TIMER0_RELOAD1)
	ljmp play
	
	setup_tone2: ; get ready to play tone2, the HIGH tone
		mov RH0, #high(TIMER0_RELOAD2)
		mov RL0, #low(TIMER0_RELOAD2)
	
	
	play: ; activates tone
		setb TR1 ; start timer1 
		setb TR0
	
	lcall pin0period ; start check for capacitance (resulting in period) change
	mov x+0 , Score1
	mov x+1 , #0
	mov x+2 , #0
	mov x+3 , #0
	Load_y(5)
	lcall x_eq_y
	jb mf, Win_Routine1
    mov x+0 , Score2
	mov x+1 , #0
	mov x+2 , #0
	mov x+3 , #0
	lcall x_eq_y
	jb mf, Win_Routine2
ljmp No_Win
	
	
Win_Routine1:
	WriteCommand(#0x01)
	Wait_Milli_Seconds(#2)
	Set_cursor(1,1)
	Send_Constant_String(#Player_Wins)
	Set_cursor(1,7)
	Display_char(#'1')
	Set_cursor(2,1)
	Send_Constant_String(#Play_Again)
	lcall FF7
	clr TR0
	ljmp Reset
	
Win_Routine2:
	WriteCommand(#0x01)
	Wait_Milli_Seconds(#2)
	Set_cursor(1,1)
	Send_Constant_String(#Player_Wins)
	Set_cursor(1,7)
	Display_char(#'2')
	Set_cursor(2,1)
	Send_Constant_String(#Play_Again)
	lcall FF7
	clr TR0
	ljmp Reset	
	
	; When pin0_period returns, a player will have either won a point or lost a 
	; point (unless already at zero). Now we need to update scoreboard and 
	; if there is a winner, declare the winner
No_Win:
	; to be done soon
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	
	; Wait a random time before playing the next sound
	; Once a sound plays, it plays indefinitely till a slap occurs
	; Once a slap occurs, calculate points, and wait to play the next sound
	; To wait for a slap to occur, potentially use some sort of loop
	;Wait_Milli_Seconds(#250)
	;Wait_Milli_Seconds(#250)	
	clr TR0
	lcall Wait_Random ; wait a random amount of time before playing the next tone
	ljmp forever

Reset:
	jnb RESET_BUTTON, Reset
	ljmp main2
	
tooSlow:
	clr TR1
	clr abortFlag
	clr TR0 ; stop the buzzer
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	ljmp forever

; Determine period of 555 Timer for player 1
pin0period: 
	jb abortFlag, tooSlow
    ; synchronize with rising edge of the signal applied to pin P0.0
    clr TR2 ; Stop timer 2
    mov TL2, #0
    mov TH2, #0
    clr TF2 ; clear timer2 overflow flag
    setb TR2
synch1:
	jb TF2, no_signal0_helper_again ; If the timer overflows, we assume there is no signal
    jb P0.0, synch1
synch2:    
	jb TF2, no_signal0_helper_again
    jnb P0.0, synch2
    
    ; Measure the period of the signal applied to pin P0.0
    clr TR2
    mov TL2, #0
    mov TH2, #0
    clr TF2
    setb TR2 ; Start timer 2
measure1:
	jb TF2, no_signal_helper
    jb P0.0, measure1
measure2:    
	jb TF2, no_signal_helper
    jnb P0.0, measure2
    clr TR2 ; Stop timer 2, [TH2,TL2] * 45.21123ns is the period
    Load_y(45211)
    mov x+0, TL2
    mov x+1, TH2
    mov x+2, #0
    mov x+3, #0
    lcall mul32
   	ljmp next
no_signal0_helper_again:
	ljmp no_signal_helper
    next:
    Load_y(1000)
    lcall div32
     ; x has the period at this point
    lcall hex2bcd
    ;Set_cursor(2,1)
    ;lcall Display_10_digit_BCD
    Load_y(407000)
    lcall x_gt_y
    jb mf, pin1period
    Load_y(394000)
    lcall x_lt_y
    jb mf, no_signal
    clr TR0 ; when a hit is detected, stop the buzzer
    ; Handle winning a point
    jb HLbit, dec_score1
    ;mov a, Score1
    ;add a, #1
    ;da a
    ;mov Score1, a
    inc Score1
    ljmp pin0_return
    
no_signal_helper:
	ljmp no_signal
    
dec_score1:
	mov a, Score1
	jz pin0_return
	;add a, #99
	;da a
	;mov Score1, a
	dec Score1

pin0_return:
	; Convert the result to BCD and display on LCD
	Set_Cursor(1, 9)
	mov x, Score1
	lcall zero_3x_bytes_0
	lcall hex2bcd
	;lcall Display_10_digit_BCD
	Display_BCD(Score1)
    ret 

no_signal:	
    ljmp pin1period

zero_3x_bytes_0:
	mov x+1, #0
	mov x+2, #0
	mov x+3, #0
	ret

; Determine period for 555 timer for player 2
pin1period:
	Wait_Milli_Seconds(#100)
	
    ; synchronize with rising edge of the signal applied to pin P0.0
    clr TR2 ; Stop timer 2
    mov TL2, #0
    mov TH2, #0
    clr TF2 ; clear timer1 overflow flag
    setb TR2
synch1_1:
	jb TF2, no_signal_helper_again ; If the timer overflows, we assume there is no signal
    jb P0.1, synch1_1
synch2_1:    
	jb TF2, no_signal_helper_again
    jnb P0.1, synch2_1
    
    ; Measure the period of the signal applied to pin P0.0
    clr TR2
    mov TL2, #0
    mov TH2, #0
    clr TF2
    setb TR2 ; Start timer 2
	ljmp measure1_1
no_signal_helper_again:
	ljmp no_signal_1_helper
measure1_1:
	jb TF2, no_signal_1_helper
    jb P0.1, measure1_1
measure2_1:    

	jb TF2, no_signal_1_helper
    jnb P0.1, measure2_1
    clr TR2 ; Stop timer 2, [TH2,TL2] * 45.21123ns is the period
    Load_y(45211)
    mov x+0, TL2
    mov x+1, TH2
    ;Set_cursor(2,4)
    mov x+2, #0
    mov x+3, #0
    lcall mul32
    Load_y(1000)
    lcall div32
    ; x has the period at this point
    ;Set_cursor(1,1)
    ;lcall hex2bcd
    ;lcall Display_10_digit_BCD
    Load_y(440000)
    lcall x_gt_y
    jb mf, no_signal_1
    ;lcall hex2bcd
    ;lcall Display_10_digit_BCD
    Load_y(404000)
    lcall x_lt_y
    jb mf, no_signal_1
    
    clr TR0 ; when a hit is detected, stop the buzzer
; Handle a press depending on tone
    jb HLbit, dec_score2
    ;mov a, Score2
    ;add a, #1
    ;da a
    ;mov Score1, a
    inc Score2
    ljmp pin1_return
    
no_signal_1_helper:
	ljmp no_signal_1
    
dec_score2:
	mov a, Score2
	jz pin1_return ; if already zero, go to end
	;add a, #99
	;da a
	;mov Score2, a
	dec Score2

pin1_return:
	; Convert the result to BCD and display on LCD
	Set_Cursor(2, 9)
	mov x, Score2
	lcall zero_3x_bytes_1
	lcall hex2bcd
	;lcall Display_10_digit_BCD
	Display_BCD(Score2)
    ret 
    
no_signal_1:	
    ljmp pin0period ; Repeat! 
    
zero_3x_bytes_1:
	mov x+1, #0
	mov x+2, #0
	mov x+3, #0
	ret
end
