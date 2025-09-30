; CONFIG1
  CONFIG  FOSC = INTOSCIO       
  CONFIG  WDTE = OFF            
  CONFIG  PWRTE = ON            
  CONFIG  MCLRE = ON            
  CONFIG  BOREN = ON            
  CONFIG  LVP = OFF              
  CONFIG  CPD = OFF             
  CONFIG  WRT = OFF             
  CONFIG  CCPMX = RB0           
  CONFIG  CP = OFF              
; CONFIG2
  CONFIG  FCMEN = OFF           
  CONFIG  IESO = OFF           

; ======== PIC16F88 : Timer0 + interruption, PIC-AS (xc.inc) ========
#include <xc.inc>

; --- Constantes (Fosc=8MHz, TMR0 -> 10ms par overflow) ---
TMR0_AUTOLOAD    equ 178       ; 256 - 178 ? 10 ms

; --- Vecteurs -------------------------------------------------------
PSECT resetVec,class=CODE,delta=2,abs
ORG 0x000
    goto start

PSECT intVec,class=CODE,delta=2,abs
ORG 0x004
; --- Sauvegarde contexte minimal ---
    movwf   W_TEMP
    swapf   STATUS,W
    movwf   STATUS_TEMP
    movf    PCLATH,W
    movwf   PCLATH_TEMP

; --- ISR Timer0 -----------------------------------------------------
    banksel INTCON
    btfss   INTCON,2          ; TMR0IF?
    goto    ISR_End
    bcf     INTCON,2          ; clear TMR0IF

    ; Recharger TMR0 pour compenser la latence et garder ~10 ms
    banksel TMR0
    movlw   TMR0_AUTOLOAD
    movwf   TMR0
    
    ;OPERATION DE L'INTERUPT---------------------------
    bsf flag_10_ms,0

ISR_End:
    ; --- Restauration contexte ---
    movf    PCLATH_TEMP,W
    movwf   PCLATH
    swapf   STATUS_TEMP,W
    movwf   STATUS
    swapf   W_TEMP,F
    swapf   W_TEMP,W
    retfie

; --- Programme principal -------------------------------------------
PSECT code,class=CODE,delta=2
start:
    call    init_pic


 ; --- loop -------------------------------------------   
loop:
    call Test_Boutons
    btfsc Flag_Bouton_1,0
    call Change_Led
    btfsc Flag_Bouton_2,0
    call Vitesse_Led
    call Etat_Constant
    call Toggle_LED   ;si le temps est venu
    goto loop  
  
 ; --- Fonctions -------------------------------------------   
Test_Boutons:
    call Bouton_1
    call Bouton_2
    call Bouton_3
    return
    
    
Change_Led:
    clrf Flag_Bouton_1
    btfsc LED,0
    goto LED_VAUT_0
    goto LED_VAUT_1
LED_VAUT_0:
    clrf LED
    return
LED_VAUT_1:
    bsf LED,0
    return
    
Vitesse_Led:
    clrf Flag_Bouton_2
    incf etat
    movf etat,w
    sublw 4
    btfsc STATUS,2
    clrf etat
    call Etat_Vitesse
Etat_Constant:
    btfss Flag_Bouton_3,0
    return
    bsf PORTB,3
    bsf PORTB,4
    return
    
Etat_Vitesse:
    movf etat,w
    btfsc STATUS,2
    goto vitesse1
    addlw -1
    btfsc STATUS,2
    goto vitesse2
    addlw -1
    btfsc STATUS,2
    goto vitesse3
    goto vitesse4   
vitesse1:
    movlw 5
    movwf vit
    return
vitesse2:
    movlw 10
    movwf vit
    return
vitesse3:
    movlw 25
    movwf vit
    return
vitesse4:
    movlw 50
    movwf vit
    return
    
 Toggle_LED:
    btfss flag_10_ms,0
    return
    bcf flag_10_ms,0
    ; --- Ex: diviseur logiciel pour ~500 ms ---
    banksel tick_div
    decfsz  tick_div,f        ; 50 * 10ms = 500ms
    return
    movf   vit,w
    movwf   tick_div

    ; --- Toggle RB3, forcer RB4 à 0 (exemple propre sans RMW piégeux) ---
    banksel PORTB
    movf    PORTB,W
    btfss LED,0
    goto Diode1
    goto Diode2
Diode1:
    andlw   11101111B       ; RB4=0
    xorlw   00001000B       ; toggle RB3
    movwf   PORTB
    return
Diode2:
    andlw   11110111B       ; RB3=0
    xorlw   00010000B       ; toggle RB4
    movwf   PORTB
    return
    
                     ; --- Bouton 1 ---
Bouton_1:
    banksel (PORTB)
    btfsc PORTB,6
    goto relache1
    goto presse1

relache1:
    clrf old1
    return
presse1:
    btfsc old1,0
    return
    bsf old1,0
    movlw 1
    movwf Flag_Bouton_1
    return
    
                         ; --- Bouton 2 ---
Bouton_2:
    banksel (PORTB)
    btfsc PORTB,7
    goto relache2
    goto presse2

relache2:
    clrf old2
    return
presse2:
    btfsc old2,0
    return
    bsf old2,0
    movlw 1
    movwf Flag_Bouton_2
    return
    
                           ; --- Bouton 3 ---
Bouton_3:
    banksel (PORTA)
    btfsc PORTA,7
    goto relache3
    goto presse3

relache3:
    clrf old3
    return
presse3:
    btfsc old3,0
    return
    bsf old3,0
    movlw 00000001B
    xorwf Flag_Bouton_3          ; toggle flag 3
    return
   
; --- Init -----------------------------------------------------------
init_pic:
    ; Oscillateur interne 8 MHz (si déjà configuré par config bits, OK)
    banksel OSCCON
    movlw   01111000B       ; IRCF=111 (8MHz)
    movwf   OSCCON

    ; Tout en digital
    banksel ANSEL
    clrf    ANSEL

    ; LEDs RB3/RB4 en sortie
    banksel TRISB
    bcf     TRISB,3
    bcf     TRISB,4

    ; Eteindre pour partir propre
    banksel PORTB
    bcf     PORTB,3
    bcf     PORTB,4

    ; Timer0: horloge interne, préscaler 1:256 attribué à TMR0
    ; OPTION_REG bits: RBPU INTEDG T0CS T0SE PSA PS2 PS1 PS0
    ;                   1      x     0    0    0   1   1   1  => 0x87
    banksel OPTION_REG
    movlw   10000111B       ; pullups off, TMR0 intclk, presc 1:256
    movwf   OPTION_REG

    ; Précharge pour ~10ms
    banksel TMR0
    movlw   TMR0_AUTOLOAD
    movwf   TMR0

    ; Flags + interruptions
    banksel INTCON
    bcf     INTCON,2          ; TMR0IF=0
    bsf     INTCON,5          ; TMR0IE=1 (enable)
    bsf     INTCON,7          ; GIE=1

    ; Init du diviseur logiciel (50 * 10ms = 500ms)
    banksel tick_div
    movlw   50
    movwf   tick_div
    return

; --- RAM partagée pour l?ISR (évite les soucis de bank) ------------
PSECT udata_shr
W_TEMP:         ds 1
STATUS_TEMP:    ds 1
PCLATH_TEMP:    ds 1
tick_div:       ds 1
d1: ds 1
d2: ds 1
d3: ds 1
vit: ds 1
LED: ds 1
etat: ds 1
old2:  ds 1
old1:  ds 1
old3: ds 1
Flag_Bouton_1:  ds 1
Flag_Bouton_2:  ds 1
Flag_Bouton_3:  ds 1
PSECT udata       ; RAM normale (banques)
flag_10_ms: ds 1
    end