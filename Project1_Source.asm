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
	reti   
; Timer/Counter 2 overflow interrupt vector
org 0x002B
    reti

; These register definitions needed by 'math32.inc'
DSEG at 30H
x:   ds 4
y:   ds 4
bcd: ds 5

Seed: ds 4

BSEG
mf: dbit 1
HLbit: dbit 1

$NOLIST
$include(math32.inc)
$LIST

cseg
CLK           EQU 22118400 ; Microcontroller system crystal frequency in Hz

TIMER0_RATE1   EQU 4000     ; 2000Hz squarewave (peak amplitude of CEM-1203 speaker) ; Pin 1.1
TIMER0_RELOAD1 EQU ((65536-(CLK/TIMER0_RATE1)))
TIMER0_RATE2   EQU 4200     ; 2100Hz squarewave (peak amplitude of CEM-1203 speaker) ; Pin 1.1
TIMER0_RELOAD2 EQU ((65536-(CLK/TIMER0_RATE2)))

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
    setb TR0  ; DONT start timer 0 yet
	ret

;---------------------------------;
; ISR for timer 0.
;---------------------------------;
Timer0_ISR:
	;clr TF0  ; According to the data sheet this is done for us already.
	cpl SOUND_OUT ; Connect speaker to P1.1!
	reti

;Initializes timer/counter 2 as a 16-bit timer
InitTimer2:
	mov T2CON, #0 ; Stop timer/counter.  Set as timer (clock input is pin 22.1184MHz).
	; Set the reload value on overflow to zero (just in case is not zero)
	mov RCAP2H, #0
	mov RCAP2L, #0
	setb ET2
    ret
    
InitTimer1:
	mov a, TMOD
	anl a, #0x0f ; Clear the bits for timer 1
	orl a, #0x10 ; Configure timer 1 as 16-timer
	mov TMOD, a
	mov TH1, #0
	mov TL1, #0
	; Set autoreload value
	mov RH1, #0
	mov RL1, #0
	clr IE1 ; set timer1 interrupt to 0
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

	Set_Cursor(1, 1)
    ;Send_Constant_String(#Initial_Message) 
    

forever:

	; First part of the game: decide which freq to buzz at
	lcall Random
	mov a, Seed+1
	mov c, acc.3
	mov HLbit, c
	jc setup_tone2 ; if carry is one, we play tone2
	; if carry is zero, we play tone1
	mov RH0, #high(TIMER0_RELOAD1)
	mov RL0, #low(TIMER0_RELOAD1)
	ljmp play
	
	setup_tone2:
		mov RH0, #high(TIMER0_RELOAD2)
		mov RL0, #low(TIMER0_RELOAD2)
	
	play: ; activates tone
		setb TR0
	

	lcall pin0period
	
	; Wait a random time before playing the next sound
	; Once a sound plays, it plays indefinitely till a slap occurs
	; Once a slap occurs, calculate points, and wait to play the next sound
	; To wait for a slap to occur, potentially use some sort of loop
	
	lcall Wait_Random ; wait a random amount of time before playing the next tone
	ljmp forever
	
pin0period:
    ; synchronize with rising edge of the signal applied to pin P0.0
    clr TR2 ; Stop timer 2
    mov TL2, #0
    mov TH2, #0
    clr TF2 ; clear timer2 overflow flag
    setb TR2
synch1:
	jb TF2, no_signal ; If the timer overflows, we assume there is no signal
    jb P0.0, synch1
synch2:    
	jb TF2, no_signal
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
    

	; Convert the result to BCD and display on LCD
	Set_Cursor(1, 1)
	lcall hex2bcd
	lcall Display_10_digit_BCD
    ret 
    
no_signal:	
	Set_Cursor(1, 1)
    Send_Constant_String(#No_Signal_Str)
        
pin1period:
    ; synchronize with rising edge of the signal applied to pin P0.0
    clr TR1 ; Stop timer 2
    mov TL1, #0
    mov TH1, #0
    clr TF1 ; clear timer1 overflow flag
    setb TR1
synch1_1:
	jb TF1, no_signal_1 ; If the timer overflows, we assume there is no signal
    jb P0.1, synch1_1
synch2_1:    
	jb TF1, no_signal_1
    jnb P0.1, synch2_1
    
    ; Measure the period of the signal applied to pin P0.0
    clr TR1
    mov TL1, #0
    mov TH1, #0
    clr TF1
    setb TR1 ; Start timer 2
measure1_1:
	jb TF1, no_signal_1
    jb P0.1, measure1_1
measure2_1:    
	jb TF1, no_signal_1
    jnb P0.1, measure2_1
    clr TR1 ; Stop timer 2, [TH2,TL2] * 45.21123ns is the period
    Load_y(45211)
    mov x+0, TL1
    mov x+1, TH1
    mov x+2, #0
    mov x+3, #0
    lcall mul32
    Load_y(1000)
    lcall div32
    
    Load_y(210000)
    lcall x_lt_y
    jb mf, no_signal_1
    

	; Convert the result to BCD and display on LCD
	Set_Cursor(2, 1)
	lcall hex2bcd
	lcall Display_10_digit_BCD
    ret 
    
no_signal_1:	
	Set_Cursor(2, 1)
    Send_Constant_String(#No_Signal_Str1)
    ljmp pin0period ; Repeat! 
end
