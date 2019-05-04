
_WDTE_OFF       EQU  0x3FFB ; WDT disabled
_FOSC_INTOSCIO  EQU  0x3FFC ; INTOSC oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on 
_PWRTE_ON       EQU  0x3FF7 ; PWRT enabled
_MCLRE_OFF      EQU  0x3FDF ; RA5/MCLR/VPP pin function is digital input, MCLR internally tied to VDD
_MCLRE_ON       EQU  0x3FFF ; RA5/MCLR/VPP pin function is MCLR	
_BOREN_ON       EQU  0x3FFF ; BOD enabled
_BOREN_OFF      EQU  0x3FBF ; BOD disabled
_LVP_OFF        EQU  0x3F7F ; RB4/PGM pin has digital I/O function, HV on MCLR must be used for programming
_CPD_ON         EQU  0x3EFF ; Data memory code-protected
_CPD_OFF        EQU  0x3FFF ; Data memory code protection off	
_CP_ON          EQU  0x1FFF ; 0000h to 07FFh code-protected
_CP_OFF         EQU  0x3FFF ; Code protection off	
TRISA           EQU  0x0085
TRISB           EQU  0x0086 
PORTA           EQU  0x0005
PORTB           EQU  0x0006
STATUS          EQU  0x03
RP0             EQU  0x05
RP1             EQU  0x06
CMCON           EQU  0x1F
Z               EQU  0x02
OPTION_REG      EQU  0x0081
GIE             EQU  0x0007
INTCON          EQU  0x000B
T1CON           EQU  0x0010
TMR1L           EQU  0x000E
TMR1H           EQU  0x000F
PIR1            EQU  0x000c
PIE1            EQU  0x008c
PEIE            EQU  0x06
TMR1IE          EQU  0x00
TMR1IF          EQU  0x00	  
INTE            EQU  0x0004
f               EQU  0x01
w               EQU  0x00
CCP1IF          EQU  0x02
TMR1ON          EQU  0x00     
TMR1            EQU  0x000E	

;------------------------
;State machine variables
;------------------------

M_STATE         EQU  0x0c    
TimeOutBit      EQU  0x00 
TurnOFFBit      EQU  0x01 
TurnOnBit       EQU  0x02  
LED_STATE       EQU  0x71
INT_OCURRED     EQU  0x72
INTFLAG         EQU  0x00
	 
Variables udata
counter   res 1

;  PIC16F628A Configuration Bit Settings
;  CONFIG
;  __config 0xFF70

 __CONFIG _FOSC_INTOSCIO & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _BOREN_ON & _LVP_OFF & _CPD_OFF & _CP_OFF


;  with a value of  12 delay 16 seconds, for larger time increase the COUNTER_VALUE below
;  with a value of 0 the delay is between 17 y 18 seconds
;  
;  Ts = ( 65536 x (256 - COUNTER_VALUE) ) / 1.000.000  
;  1.000.000 *  Ts  = ( 65536 x (256 - COUNTER_VALUE) ) 
;  1.000.000* Ts / 65536 = 256 - COUNTER_VALUE
;  COUNTER_VALUE = 256 - (1.000.000 * Ts/65536)
;
;  COUNTER_VALUE= 256 - Ts/0.065536
#define COUNTER_VALUE  d'12'
   
INTERRUPTVEC org  0x04             ; interrupt vector
             goto ISR              ; call the interruption rutine
	      
             org 0x00 
             goto configure_ports
       	     
MAIN_PROG    code 0x006c
 
;------ Set up ------------------------
configure_ports:
    movlw 0x07        ; turn off coparators
    movwf CMCON       ;
      
    bsf   STATUS,RP0  ; change to bank 1
    movlw 0xFE        ; TRISA RA0 as output rest as inputs
    movwf TRISA       ;
    movlw 0x01        ; TRISB as output except RB0 as input
    movwf TRISB       ;
    bcf   STATUS,RP0  ; change back to bank 0

init_variables: 
    movlw COUNTER_VALUE      ; move the value  to working register
    movwf counter            ; Init counter to  the value of the working register
    clrf  PORTA              ; clear all the values of PORTA to cero just in case
    clrf  INT_OCURRED        ;
    clrf  M_STATE            ; clear M_STATE register where the actual state of the program is    
    bsf   M_STATE,TurnOFFBit ; Set Initial state turn_off_state
   
;-------------  Main loop of the program -----------------
Main:
    btfsc M_STATE,TurnOFFBit     ; if the state is turnOff call turn_off_state rutine
    call  turn_off_state
    btfsc M_STATE,TurnOnBit      ; if the state is TurnOn  call o turn_on state rutine
    call  turn_on_state
    btfsc M_STATE,TimeOutBit     ; if the statis is TimeOut call to time_out_state rutine
    call  time_out_state
    goto  Main
    
; --------- finite state machine button states -----------------------
turn_off_state:
    btfss PORTB,.0              ; if the button is pressed change state
    call change_to_On
    return                      ; if the button is not pressed return

turn_on_state:
    btfsc PORTB,.0              ; if the button is not pressed  change to state off
    call  change_to_Off
    return                      ; if the button is released keep state off and return
    
time_out_state:
    bcf   PORTA,.0
    btfsc PORTB,.0    
    call  turn_off_fromOutState
    return    
    
;----------------  Interrupt service rutine ------------
ISR:
   call disable_interrupts    ; disable all interrupts
   incf counter
   btfss STATUS,Z             
   call enable_interrupts
   btfss INTCON,GIE
   call change_to_Out         ; change state to out
   retfie                     ; return from interrption
   
;---------- Transition states subrutines --------
change_to_Out: 
    bcf   PORTA,.0            ; turn off led
    movlw COUNTER_VALUE       ; move the value  to working register
    movwf counter             ; Init counter to  the value of the working register
    clrf  M_STATE             ; clear the previous state
    bsf   M_STATE,TimeOutBit  ; 
    bsf   INT_OCURRED,INTFLAG ; set intflag to alert that we had an interruption 
    return
    
change_to_On:
    btfsc INT_OCURRED , INTFLAG   ; check if we came from an interrupt
    return
    bsf   PORTA,.0 
    clrf M_STATE              ; clear the previous state
    bsf  M_STATE,TurnOnBit    ; set the state to Turn On
    call enable_interrupts    ; enable timer1 interrupts
    call StartTimer           ; start timer
    return  
    
change_to_Off:
    btfsc INT_OCURRED , INTFLAG   ; check if we came from an interrupt
    return
    bcf   PORTA,.0 
    call disable_interrupts   ; disable all interrupts
    call StopTimer            ; Stop the timer
    clrf M_STATE              ; clear the previous state
    bsf  M_STATE,TurnOFFBit   ; set the state to turn off
    return
    
turn_off_fromOutState:
    bcf INT_OCURRED,INTFLAG ; clear the flag of interruption
    call change_to_Off      ; change state to off
    return
    
;------------- interrupts subrutines --------------
enable_interrupts:
    bsf INTCON,PEIE   ; enable periferial interruputs
    bsf INTCON,GIE    ; enable global interrupts
    bcf PIR1,TMR1IF   ; clear timer1 interrupt flag( is set when TMR1H overflows)
    bsf STATUS,RP0    ; change to bank 1 to acces PIE1 register
    bsf PIE1,TMR1IE   ; enable timer1 interrupts
    bcf STATUS,RP0    ; go to bank 0
    return
    
disable_interrupts:
    bcf INTCON,GIE   ; disable global interrupts
    bcf INTCON,PEIE  ; disable periferial interrupts
    bcf PIR1,TMR1IF  ; clear timer1 interrupt flag ( is set when TMR1H overflows)
    bsf STATUS,RP0   ; change to bank 1 to acces PIE1 register
    bcf PIE1,TMR1IE  ; disable Timer1 interrupts 
    bcf STATUS,RP0   ; go back to bank 0
    return
  
;------------- Timer subrutines --------------
StopTimer:
    btfss T1CON,TMR1ON
    return
stop:
    bcf   T1CON,TMR1ON   ; stop timer
    clrf  TMR1L          ; clear timer low
    clrf  TMR1H          ; clear timer high
    return

StartTimer:
    btfsc T1CON,TMR1ON   ; check if the timer is already running
    return               ; if its already running return
start:
    clrf TMR1L          ; set timer low bits to zero
    clrf TMR1H          ; set timer1 high bits to zero
    bsf  T1CON,TMR1ON   ; start timer1
    return
    
    end