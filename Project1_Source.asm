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
TIMER1_RATE1   EQU 1000     ; 500Hz squarewave (peak amplitude of CEM-1203 speaker) ; Pin 1.1
TIMER1_RELOAD1 EQU ((65536-(CLK/TIMER1_RATE1))) ; LOW TONE


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

$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$LIST

;                     1234567890123456    <- This helps determine the location of the counter
Initial_Message:  db 'Period (ns):   ', 0
No_Signal_Str:    db 'No signal      ', 0
No_Signal_Str1:  db 'No signal T1', 0

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
    
Init_Seed:
	; Wait for a push of the BOOT button
	; to initialize random seed:
	setb TR2
	jb BOOT_BUTTON, $
	Set_Cursor(2,1)
	Display_char(#'!')
	mov Seed+0, TH2
	mov Seed+1, #0x01
    mov Seed+2, #0x87
    mov Seed+3, TL2
    clr TR2
    ret
    
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

Wait_Random:
	Wait_Milli_Seconds(Seed+0)
	Wait_Milli_Seconds(Seed+1)
	Wait_Milli_Seconds(Seed+2)
	Wait_Milli_Seconds(Seed+3)
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
    lcall Init_Seed
 	
	ret

;---------------------------------;
; Main program loop               ;
;---------------------------------;
main:
    ; Initialize the hardware:
    mov SP, #7FH
    lcall Initialize_All
    setb P0.0 ; Pin is used as input for 555 timer for timer/counter2
    setb P0.1 ; Pin for 555 timer for timer/counter1
    clr HLbit 
    clr TR0 ; clear timer 0 so no sound when game first starts
    clr abortFlag
    mov Score1, #0
    mov Score2, #0
    
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
	
	; When pin0_period returns, a player will have either won a point or lost a 
	; point (unless already at zero). Now we need to update scoreboard and 
	; if there is a winner, declare the winner
	
	; to be done soon
	
	
	; Wait a random time before playing the next sound
	; Once a sound plays, it plays indefinitely till a slap occurs
	; Once a slap occurs, calculate points, and wait to play the next sound
	; To wait for a slap to occur, potentially use some sort of loop
	
	clr TR0
	lcall Wait_Random ; wait a random amount of time before playing the next tone
	ljmp forever
	
tooSlow:
	clr TR1
	clr abortFlag
	Set_cursor(1,12)
	Display_char(#'$')
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
	jb TF2, no_signal_helper ; If the timer overflows, we assume there is no signal
    jb P0.0, synch1
synch2:    
	jb TF2, no_signal_helper
    jnb P0.0, synch2
    
    ; Measure the period of the signal applied to pin P0.0
    clr TR2
    mov TL2, #0
    mov TH2, #0
    clr TF2
    setb TR2 ; Start timer 2
measure1:
	jb TF2, no_signal
    jb P0.0, measure1
measure2:    
	jb TF2, no_signal
    jnb P0.0, measure2
    clr TR2 ; Stop timer 2, [TH2,TL2] * 45.21123ns is the period
    Load_y(45211)
    mov x+0, TL2
    mov x+1, TH2
    mov x+2, #0
    mov x+3, #0
    lcall mul32
    Load_y(1000)
    lcall div32
    
    Load_y(208000)
    lcall x_lt_y
    jb mf, no_signal
    
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
	Set_Cursor(1, 1)
	mov x, Score1
	lcall zero_3x_bytes_0
	lcall hex2bcd
	;lcall Display_10_digit_BCD
	Display_BCD(Score1)
    ret 

no_signal:	
	Set_Cursor(2, 15)
   	Display_char(#'!')
    ljmp pin1period

zero_3x_bytes_0:
	mov x+1, #0
	mov x+2, #0
	mov x+3, #0
	ret

; Determine period for 555 timer for player 2
pin1period:
    ; synchronize with rising edge of the signal applied to pin P0.0
    clr TR2 ; Stop timer 2
    mov TL2, #0
    mov TH2, #0
    clr TF2 ; clear timer1 overflow flag
    setb TR2
synch1_1:
	jb TF2, no_signal_1_helper ; If the timer overflows, we assume there is no signal
    jb P0.1, synch1_1
synch2_1:    
	jb TF2, no_signal_1_helper
    jnb P0.1, synch2_1
    
    ; Measure the period of the signal applied to pin P0.0
    clr TR2
    mov TL2, #0
    mov TH2, #0
    clr TF2
    setb TR2 ; Start timer 2
measure1_1:
	jb TF2, no_signal_1
    jb P0.1, measure1_1
measure2_1:    
	jb TF2, no_signal_1
    jnb P0.1, measure2_1
    clr TR2 ; Stop timer 2, [TH2,TL2] * 45.21123ns is the period
    Load_y(45211)
    mov x+0, TL2
    mov x+1, TH2
    mov x+2, #0
    mov x+3, #0
    lcall mul32
    Load_y(1000)
    lcall div32
    
    Load_y(208000)
    lcall x_lt_y
    jb mf, no_signal_1
    
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
	Set_Cursor(2, 1)
	mov x, Score2
	lcall zero_3x_bytes_1
	lcall hex2bcd
	;lcall Display_10_digit_BCD
	Display_BCD(Score2)
    ret 
    
no_signal_1:	
	Set_Cursor(2, 15)
   	Display_char(#'!')
    ljmp pin0period ; Repeat! 
    
zero_3x_bytes_1:
	mov x+1, #0
	mov x+2, #0
	mov x+3, #0
	ret
end
