    
; Archivo:	main.s
; Dispositivo:	PIC16F887
; Autor:	Javier Monzón 20054
; Compilador:	pic-as (v2.30), MPLABX V5.40
;
; Programa:	Reloj digital con modo hora, fecha, alarma y timer
; Hardware:	LEDs en el puerto A y E, push-buttons en el puerto B
;		Displays de 7 segmentos en el puerto C
;		Transistores en el puerto D
;
; Creado:	21 febrero 2022
; Última modificación: 21 febrero 2022

PROCESSOR 16F887
#include <xc.inc>
    
; Configuration word 1
  CONFIG  FOSC = INTRC_NOCLKOUT ; Oscilador interno sin salidas
  CONFIG  WDTE = OFF            ; WDT disabled (reinicio repetitivo del PIC)
  CONFIG  PWRTE = OFF           ; PWRT enabled (espera de 72ms al iniciar)
  CONFIG  MCLRE = OFF           ; El pin de MCLR se utiliza como I/O
  CONFIG  CP = OFF              ; Sin protección de código 
  CONFIG  CPD = OFF             ; Sin protección de datos
  
  CONFIG  BOREN = OFF           ; Sin reinicio cuando el voltaje de alimentación baja de 4V
  CONFIG  IESO = OFF            ; Reinicio sin cambio de reloj de interno a externo
  CONFIG  FCMEN = OFF           ; Cambio de reloj externo a interno en caso de fallo
  CONFIG  LVP = OFF             ; Programación en bajo voltaje permitida
  
; Configuration word 2
  CONFIG  BOR4V = BOR40V        ; Reinicio abajo de 4V 
  CONFIG  WRT = OFF             ; Protección de autoescritura por el programa desactivada 
    
; ------- VARIABLES EN MEMORIA --------
PSECT udata_shr			; Memoria compartida
    wtemp:		DS  1
    status_temp:	DS  1
    
PSECT udata_bank0		; Variables almacenadas en el banco 0
    segundos:		DS  1
    segundos_t:		DS  1
    minutos:		DS  1
    minutos_t:		DS  1
    minutos_a:		DS  1
    horas:		DS  1
    horas_a:		DS  1
    dias:		DS  1
    meses:		DS  1
    unidades_s:		DS  1
    decenas_s:		DS  1
    unidades_m:		DS  1
    decenas_m:		DS  1
    unidades_h:		DS  1
    decenas_h:		DS  1
    unidades_d:		DS  1
    decenas_d:		DS  1
    unidades_mes:	DS  1
    decenas_mes:	DS  1
    unidades_st:	DS  1
    decenas_st:		DS  1
    unidades_mt:	DS  1
    decenas_mt:		DS  1
    unidades_ma:	DS  1
    decenas_ma:		DS  1
    unidades_ha:	DS  1
    decenas_ha:		DS  1
    banderas:		DS  1
    valor_s:		DS  1
    valor_st:		DS  1
    valor_m:		DS  1
    valor_mt:		DS  1
    valor_h:		DS  1
    valor_d:		DS  1
    valor_mes:		DS  1
    valor_ha:		DS  1
    valor_ma:		DS  1
    veces_us:		DS  1
    veces_ds:		DS  1
    veces_um:		DS  1
    veces_dm:		DS  1
    veces_uh:		DS  1
    veces_dh:		DS  1
    veces_ud:		DS  1
    veces_dd:		DS  1
    veces_umes:		DS  1
    veces_dmes:		DS  1
    veces_ust:		DS  1
    veces_dst:		DS  1
    veces_umt:		DS  1
    veces_dmt:		DS  1
    veces_uma:		DS  1
    veces_dma:		DS  1
    veces_uha:		DS  1
    veces_dha:		DS  1
    diez:		DS  1
    uno:		DS  1
    cont_1:		DS  1
    cont_2:		DS  1
    cont_3:		DS  1
    medio:		DS  1
    estados:		DS  1
    bandera_config:	DS  1
    num_config:		DS  1
    config_state:	DS  1
    bandera_alarma:	DS  1
    alarma_bandera:	DS  1
    display:		DS  4

PSECT resVect, class = CODE, abs, delta = 2
 ;-------------- vector reset ---------------
 ORG 00h			; Posición 00h para el reset
 resVect:
    goto main

PSECT intVect, class = CODE, abs, delta = 2
ORG 004h				; posición 0004h para interrupciones
;------- VECTOR INTERRUPCIONES ----------
 
push:
    movwf   wtemp		; Se guarda W en el registro temporal
    swapf   STATUS, W		
    movwf   status_temp		; Se guarda STATUS en el registro temporal
    
isr:
    banksel INTCON
    btfsc   T0IF		; Ver si bandera de TMR0 se encendió
    call    t0
    btfsc   TMR1IF		; Ver si bandera de TMR1 se encendió
    call    t1
    btfsc   TMR2IF		; Ver si bandera de TMR2 se encendió
    call    t2
    btfsc   RBIF
    call    intB
    
pop:
    swapf   status_temp, W	
    movwf   STATUS		; Se recupera el valor de STATUS
    swapf   wtemp, F
    swapf   wtemp, W		; Se recupera el valor de W
    retfie      
    
PSECT code,  delta = 2, abs
ORG 200h
 
main:
    call    config_IO		; Configuración de I/O
    call    config_clk		; Configuración de reloj
    call    config_tmr0		; Configuración de TMR0
    call    config_tmr1		; Configuración de TMR1
    call    config_tmr2		; Configuración de TMR2
    call    config_int		; Configuración de interrupciones
    
loop:
    btfsc   cont_1,	1	; Verifica si contador 1 es 2
    call    complete1
    
    movf    segundos,	0
    sublw   0x3C
    btfsc   STATUS,	2	; Verificar si segundos = 60
    call    minuto_complete
    
    btfsc   segundos_t,	7
    decf    minutos_t,	1
    movlw   0x3B
    btfsc   segundos_t,	7
    movwf   segundos_t		; Verificar si segundos de timer = 0
    
    btfsc   bandera_config,0
    goto    $+7
    movf    segundos_t,	1
    btfss   STATUS,	2
    goto    $+4
    movf    minutos_t,	1
    btfsc   STATUS,	2
    call    timer_complete	; Verificar si el timer se completó 
    
    btfss   PORTA,	6
    goto    $+7
    btfsc   bandera_alarma,   0
    call    apagar_alarma	; Apagar alarma de timer
    
    btfss   PORTA,	6
    goto    $+3
    btfss   alarma_bandera, 0
    call    alarma_off		; Apagar alarma 
    
    movf    minutos,	0
    sublw   0x3C
    btfsc   STATUS,	2	; Verificar si minutos = 60
    call    hora_complete
    
    movf    minutos_a,	0
    sublw   0x3C
    btfsc   STATUS,	2
    clrf    minutos_a		; Verificar si minutos alarma = 60
    
    movf    horas_a,	0
    sublw   0x17
    btfss   STATUS,	0
    clrf    horas_a		; Verificar si horas alarma = 24
    
    movf    horas,	0
    sublw   0x18
    btfsc   STATUS,	2
    call    dia_complete	; Verificar si horas = 24
    
    movf    minutos_t,	0
    sublw   0x64
    btfsc   STATUS,	2
    call    timer_minmax	; Verificar si minutos timer = 99
    
    btfsc   minutos_t,  7
    clrf    minutos_t		; Verificar si minutos timer es "negativo"
    
    movf    segundos_t,	0
    sublw   0x3C
    btfsc   STATUS,	2
    call    timer_segmax	; Verificar si segundos timer = 60
    
    btfsc   segundos_t,	7
    clrf    segundos_t		; Verificar si segundos timer es "negativo"
    
    movlw   0x3B
    btfsc   minutos,	7
    movwf   minutos		; Verificar si minutos es "negativo"
    
    movlw   0x3B
    btfsc   minutos_a,	7
    movwf   minutos_a		; Verificar si minutos alarma es "negativo"
    
    movlw   0x17
    btfsc   horas,	7
    movwf   horas		; Verificar si horas es "negativo"
    
    movlw   0x17
    btfsc   horas_a,	7
    movwf   horas_a		; Verificar si horas alarma es "negativo"
    
    movf    meses,	0
    sublw   0x0D
    btfsc   STATUS,	2
    call    ano_complete	; Verificar si meses = 12
    
    movlw   0x1F
    btfsc   dias,	7
    movwf   dias		; Verificar si dias es "negativo"
    
    movlw   0x0C
    btfsc   meses,	7
    movwf   meses		; Verificar si meses es "negativo"
    
    btfss   bandera_config, 0
    goto    $+8
    movf    minutos_t,	    1
    btfss   STATUS,	    2
    goto    $+5
    movf    segundos_t,	    1
    movlw   0x01
    btfsc   STATUS,	    2
    movwf   segundos_t		; Timer mínimo 1 seg
    
    movf    minutos_t,	    0
    sublw   0x64
    btfsc   STATUS,	    0
    goto    $+3
    movlw   0x63
    movwf   minutos_t		; Minutos timer max
    
    btfsc   bandera_config, 0
    goto    $+11
    btfss   alarma_bandera,0
    goto    $+9
    movf    horas_a,	0
    xorwf   horas,	0
    btfss   STATUS,	2
    goto    $+5
    movf    minutos_a,	0
    xorwf   minutos,	0
    btfsc   STATUS,	2
    call    alarma_complete	; Verificar si alarma es igual a hora 
    
    btfsc   alarma_bandera, 0
    goto    $+3   
    bcf	    PORTA,	4
    goto    $+2
    bsf	    PORTA,	4	; Encender LED de alarma encendida
    
    btfsc   bandera_config, 0
    goto    $+3
    bcf	    PORTA,	5
    goto    $+2
    bsf	    PORTA,	5	; Encender LED de modo configuracion
    
    movf    meses,	0
    xorlw   0x01
    btfsc   STATUS,	2
    call    mes31		; Verificar si es enero
    
    movf    meses,	0
    xorlw   0x02
    btfsc   STATUS,	2
    call    mes28		; Verificar si es febrero 
    
    movf    meses,	0
    xorlw   0x03
    btfsc   STATUS,	2
    call    mes31		; Verificar si es marzo 
    
    movf    meses,	0
    xorlw   0x04
    btfsc   STATUS,	2
    call    mes30		; Verificar si es abril
    
    movf    meses,	0
    xorlw   0x05
    btfsc   STATUS,	2
    call    mes31		; Verificar si es mayo 
    
    movf    meses,	0
    xorlw   0x06
    btfsc   STATUS,	2
    call    mes30		; Verificar si es junio 
    
    movf    meses,	0
    xorlw   0x07
    btfsc   STATUS,	2
    call    mes31		; Verificar si es julio 
    
    movf    meses,	0
    xorlw   0x08
    btfsc   STATUS,	2
    call    mes31		; Verificar si es agosto 
    
    movf    meses,	0
    xorlw   0x09
    btfsc   STATUS,	2
    call    mes30		; Verificar si es septiembre
    
    movf    meses,	0
    xorlw   0x0A
    btfsc   STATUS,	2
    call    mes31		; Verificar si es octubre 
    
    movf    meses,	0
    xorlw   0x0B
    btfsc   STATUS,	2
    call    mes30		; Verificar si es noviembre 
    
    movf    meses,	0
    xorlw   0x0C
    btfsc   STATUS,	2
    call    mes31		; Verificar si es diciembre
    
    movf    medio,	0
    movwf   PORTE
    
    btfsc   estados,	0	; Estados = 001 -> Fecha
    goto    loop_fecha
    btfsc   estados,	1	; Estados = 010 -> Alarma
    goto    loop_alarma
    btfsc   estados,	2	; Estados = 100 -> Timer
    goto    loop_timer
    goto    loop_reloj		; Estados = 000 -> Hora/reloj
    
loop_reloj:
    bsf	    PORTA,	0	; LED indicador de modo hora/reloj
    bcf	    PORTA,	1
    bcf	    PORTA,	2
    bcf	    PORTA,	3
    
    movf    segundos,	0
    movwf   valor_s		; Almacenar el valor de segundos en valor
    movf    minutos,	0
    movwf   valor_m		; Almacenar el valor de minutos en valor
    movf    horas,	0
    movwf   valor_h		; Almacenar el valor de horas en valor
    
    ; Convertir a decimal 
    clrf    veces_us
    clrf    veces_ds
    clrf    veces_um
    clrf    veces_dm
    clrf    veces_uh
    clrf    veces_dh
    
    movf    diez,   0
    subwf   valor_m,  1
    incf    veces_dm,	1
    btfsc   STATUS, 0
    goto    $-3
    call    check_decenas_m	; Obtener decenas de minutos

    movf    uno,    0
    subwf   valor_m,  1
    incf    veces_um,	1
    btfsc   STATUS, 0
    goto    $-3
    call    check_unidades_m	; Obtener unidades de minutos
    
    movf    diez,   0
    subwf   valor_h,  1
    incf    veces_dh,	1
    btfsc   STATUS, 0
    goto    $-3
    call    check_decenas_h	; Obtener decenas de horas

    movf    uno,    0
    subwf   valor_h,  1
    incf    veces_uh,	1
    btfsc   STATUS, 0
    goto    $-3
    call    check_unidades_h	; Obtener unidades de horas
   
    call    set_display_S0	; Setear display para mostrar horas y minutos
    goto    loop		; Volver a loop principal 
    
loop_fecha:
    bsf	    PORTE,	2	; LEDs que cuentan segundos siempre encendidos para ser diagonal
    bcf	    PORTA,	0
    bsf	    PORTA,	1	; LED indicador de modo fecha
    bcf	    PORTA,	2
    bcf	    PORTA,	3
    
    movf    dias,	0	; Almacenar el valor de dias en valor
    movwf   valor_d
    movf    meses,	0	; Almacenar el valor de meses en valor
    movwf   valor_mes
    
    ; Convertir a decimal 
    clrf    veces_ud
    clrf    veces_dd
    clrf    veces_umes
    clrf    veces_dmes
    
    movf    diez,   0
    subwf   valor_d,  1
    incf    veces_dd,	1
    btfsc   STATUS, 0
    goto    $-3
    call    check_decenas_d	; Obtener decenas de dias

    movf    uno,    0
    subwf   valor_d,  1
    incf    veces_ud,	1
    btfsc   STATUS, 0
    goto    $-3
    call    check_unidades_d	; Obtener unidades de dias
    
    movf    diez,   0
    subwf   valor_mes,  1
    incf    veces_dmes,	1
    btfsc   STATUS, 0
    goto    $-3
    call    check_decenas_mes	; Obtener decenas de mes

    movf    uno,    0
    subwf   valor_mes,  1
    incf    veces_umes,	1
    btfsc   STATUS, 0
    goto    $-3
    call    check_unidades_mes	; Obtener unidades de mes
    
    call    set_display_S1	; Configurar display para mostrar mes y dia
    goto    loop		; Volver a loop principal
    
loop_alarma:
    bcf	    PORTA,	0
    bcf	    PORTA,	1
    bsf	    PORTA,	2	; LED indicador de modo alarma
    bcf	    PORTA,	3
    
    clrf    veces_uma
    clrf    veces_dma
    clrf    veces_uha
    clrf    veces_dha
    
    movf    minutos_a,	0	; Almacenar valor de minutos en valor
    movwf   valor_ma
    movf    horas_a,	0	; Almacenar el valor de horas en valor
    movwf   valor_ha
    
    movf    diez,   0
    subwf   valor_ma,  1
    incf    veces_dma,	1
    btfsc   STATUS, 0
    goto    $-3
    call    check_decenas_ma	; Obtener decenas de minutos

    movf    uno,    0
    subwf   valor_ma,  1
    incf    veces_uma,	1
    btfsc   STATUS, 0
    goto    $-3
    call    check_unidades_ma	; OBtener unidades de minutos
    
    movf    diez,   0
    subwf   valor_ha,  1
    incf    veces_dha,	1
    btfsc   STATUS, 0
    goto    $-3
    call    check_decenas_ha	; Obtener deceas de horas

    movf    uno,    0
    subwf   valor_ha,  1
    incf    veces_uha,	1
    btfsc   STATUS, 0
    goto    $-3
    call    check_unidades_ha	; Obtener unidades de horas
	
    call    set_display_S3	; Configurar display para mostrar horas y minutos de alarma
    goto    loop		; Volver a loop principal 
    
loop_timer:
    bcf	    PORTA,	0
    bcf	    PORTA,	1
    bcf	    PORTA,	2
    bsf	    PORTA,	3	; LED indicador de modo timer
    
    clrf    veces_ust
    clrf    veces_dst
    clrf    veces_umt
    clrf    veces_dmt
    
    movf    segundos_t,	0	; Almacenar el valor de segundos en valor
    movwf   valor_st
    movf    minutos_t,	0	; Almacenar el valor de minutos en valor
    movwf   valor_mt
    
    movf    diez,   0
    subwf   valor_st,  1
    incf    veces_dst,	1
    btfsc   STATUS, 0
    goto    $-3
    call    check_decenas_st	; Obtener decenas de segundos

    movf    uno,    0
    subwf   valor_st,  1
    incf    veces_ust,	1
    btfsc   STATUS, 0
    goto    $-3
    call    check_unidades_st	; Obtener unidades de segundos
    
    movf    diez,   0
    subwf   valor_mt,  1
    incf    veces_dmt,	1
    btfsc   STATUS, 0
    goto    $-3
    call    check_decenas_mt	 ; Obtener decenas de minutos 

    movf    uno,    0
    subwf   valor_mt,  1
    incf    veces_umt,	1
    btfsc   STATUS, 0
    goto    $-3
    call    check_unidades_mt	; Obtener unidades de minutos 
    
    call    set_display_S4	; Configurar display para mostrar minutos y segundos de timer
    goto    loop		; Volver a loop principal 
    
;--------------- Subrutinas ------------------
config_IO:
    banksel ANSEL
    clrf    ANSEL
    clrf    ANSELH	    ; I/O digitales
    banksel TRISA
    movlw   0xFF
    movwf   TRISB	    ; Puerto B como entrada
    clrf    TRISA	    ; Puerto A como salida
    clrf    TRISC	    ; Puerto C como salida
    clrf    TRISD	    ; Puerto D como salida
    clrf    TRISE	    ; Puerto E como salida
    banksel PORTA
    clrf    PORTA
    clrf    PORTC
    clrf    PORTD
    clrf    PORTB
    clrf    PORTE
    movlw   0x00
    movwf   segundos	
    movlw   0x10
    movwf   minutos
    movlw   0x05
    movwf   horas
    movlw   0x00    
    movwf   unidades_s
    movlw   0x00
    movwf   decenas_s
    movlw   0x00
    movwf   unidades_m
    movlw   0x00
    movwf   decenas_m
    movlw   0x00
    movwf   unidades_h
    movlw   0x00
    movwf   decenas_h
    movlw   0x00
    movwf   veces_us
    movlw   0x00
    movwf   veces_ds
    movlw   0x00
    movwf   veces_um
    movlw   0x00
    movwf   veces_dm
    movlw   0x00
    movwf   veces_uh
    movlw   0x00
    movwf   veces_dh
    movlw   0x0A
    movwf   diez
    movlw   0x01
    movwf   uno
    movlw   0x00
    movwf   banderas
    movlw   0x00
    movwf   cont_1
    movlw   0x00
    movwf   cont_2
    movlw   0x00
    movwf   cont_3
    movlw   0xFF
    movwf   medio
    movlw   0x00
    movwf   estados
    movlw   0x0F
    movwf   dias
    movlw   0x06
    movwf   meses
    movlw   0xFE
    movwf   bandera_config
    movlw   0x00
    movwf   num_config
    movlw   0x00
    movwf   config_state
    movlw   0x00
    movwf   segundos_t
    movlw   0x01
    movwf   minutos_t
    movlw   0x11
    movwf   minutos_a
    movlw   0x05
    movwf   horas_a
    movlw   0x00
    movwf   bandera_alarma
    movlw   0x00
    movwf   alarma_bandera
    return
    
config_clk:
    banksel OSCCON	    ; cambiamos a banco de OSCCON
    bsf	    OSCCON,	 0  ; SCS -> 1, Usamos reloj interno
    bsf	    OSCCON,	 6
    bsf	    OSCCON,	 5
    bcf	    OSCCON,	 4  ; IRCF<2:0> -> 110 4MHz
    return
    
config_tmr0:
    banksel OPTION_REG	    ; Cambiamos a banco de OPTION_REG
    bcf	    OPTION_REG, 5   ; T0CS = 0 --> TIMER0 como temporizador 
    bcf	    OPTION_REG, 3   ; Prescaler a TIMER0
    bcf	    OPTION_REG, 2   ; PS2
    bcf	    OPTION_REG, 1   ; PS1
    bcf	    OPTION_REG, 0   ; PS0 Prescaler de 1 : 2
    banksel TMR0	    ; Cambiamos a banco 0 de TIMER0
    movlw   6		    ; Cargamos el valor 6 a W
    movwf   TMR0	    ; Cargamos el valor de W a TIMER0 para 2mS de delay
    bcf	    T0IF	    ; Borramos la bandera de interrupcion
    return  
    
config_tmr1:
    banksel T1CON	    ; Cambiamos a banco de tmr1
    bcf	    TMR1CS	    ; Reloj interno 
    bcf	    T1OSCEN	    ; Apagamos LP
    bsf	    T1CKPS1	    ; Prescaler 1:8
    bsf	    T1CKPS0
    bcf	    TMR1GE	    ; tmr1 siempre contando 
    bsf	    TMR1ON	    ; Encender tmr1
    call    reset_tmr1
    return
    
config_tmr2:
    banksel PR2
    movlw   243		    ; Para delay de 62.5 mS
    movwf   PR2
    banksel T2CON
    bsf	    T2CKPS1	    ; Prescaler de 1:16
    bsf	    T2CKPS0
    bsf	    TOUTPS3	    ; Postscaler de 1:16
    bsf	    TOUTPS2
    bsf	    TOUTPS1
    bsf	    TOUTPS0
    bsf	    TMR2ON	    ; tmr2 encendido 
    return
    
config_int:
    banksel IOCB
    bsf	    IOCB,   0	    ; Interrupcion en RB0
    bsf	    IOCB,   1	    ; Interrupcion en RB1
    bsf	    IOCB,   2	    ; Interrupcion en RB2
    bsf	    IOCB,   3	    ; Interrupcion en RB3
    bsf	    IOCB,   4	    ; Interrupcion en RB4
    banksel PIE1
    bsf	    TMR1IE	    ; Habilitamos interrupcion TMR1
    bsf	    TMR2IE	    ; Habilitamos interrupcion TMR2
    banksel INTCON
    bsf	    PEIE
    bsf	    GIE		    ; Habilitamos interrupciones
    bsf	    T0IE	    ; Habilitamos interrupcion TMR0
    bcf	    T0IF	    ; Limpiamos bandera de TMR0
    bcf	    TMR1IF	    ; Limpiamos bandera de TMR1
    bcf	    TMR2IF	    ; Limpiamos bandera de TMR2
    bsf	    RBIE	    ; Habilitamos interrupcion PORTB
    bcf	    RBIF	    ; Limpiamos bandera de PORTB
    return
    
reset_tmr0:
    banksel TMR0	    ; cambiamos de banco
    movlw   6
    movwf   TMR0	    ; delay 4.44mS
    bcf	    T0IF
    return

reset_tmr1:
    banksel TMR1H
    movlw   0x0B	    ; Configuración tmr1 H
    movwf   TMR1H
    movlw   0xDC	    ; Configuración tmr1 L
    movwf   TMR1L	    ; tmr1 a 500 mS
    bcf	    TMR1IF	    ; Limpiar bandera de tmr1
    
t0:
    call    reset_tmr0
    call    mostrar_valores
    return
    
t1:
    call    reset_tmr1
    incf    cont_1
    comf    medio
    return
    
t2:
    bcf	    TMR2IF	    ; Limpiar la bandera de tmr2
    return
    
intB:			    ; Interrupciones de puerto B
    btfss   PORTB,	0
    call    cambiar_estado  ; Ver si fue B1
    btfss   PORTB,	1
    call    configuracion   ; Ver si fue B2
    btfss   PORTB,	2
    call    inc		    ; Ver si fue B3
    btfss   PORTB,	3
    call    decr	    ; Ver si fue B4
    btfss   PORTB,	4
    call    change	    ; Ver si fue B5
    bcf	    RBIF	    ; Limpiar bandera de puerto B
    return
    
cambiar_estado:
    btfsc   estados,	0   ; Verificar en qué estado se encuentra la FSM
    goto    S2_change	    ; para verificar cuál debería de ser el siguiente
    btfsc   estados,	1
    goto    S3_change
    btfsc   estados,	2
    goto    S0_change
    goto    S1_change
    
    S0_change:
	bcf	    estados,	0
	bcf	    estados,	1
	bcf	    estados,	2
	return
    
    S1_change:
	bsf	    estados,	0
	bcf	    estados,	1
	bcf	    estados,	2
	return

    S2_change:
	bcf	    estados,	0
	bsf	    estados,	1
	bcf	    estados,	2
	return

    S3_change:
	bcf	    estados,	0
	bcf	    estados,	1
	bsf	    estados,	2
	return
    
configuracion:
    comf    bandera_config	    ; Habilitar o deshabilitar bandera de configuraciones 
    return
    
set_display_S0:			    ; Mostrar en el display horas y minutos de reloj
    movf    unidades_m,	w 
    call    tabla
    movwf   display+1
    
    movf    decenas_m,	w
    call    tabla
    movwf   display+2
    
    movf    unidades_h,	w
    call    tabla
    movwf   display+3
    
    movf    decenas_h,	w
    call    tabla
    movwf   display
    return    
    
set_display_S1:			    ; Mostrar en el display dia y mes de fecha 
    movf    unidades_mes,	w 
    call    tabla
    movwf   display+1
    
    movf    decenas_mes,	w
    call    tabla
    movwf   display+2
    
    movf    unidades_d,   w
    call    tabla
    movwf   display+3
    
    movf    decenas_d,    w
    call    tabla
    movwf   display
    return      
    
set_display_S3:			    ; Mostrar en el display hora y minutos de alarma 
    movf    unidades_ma,	w 
    call    tabla
    movwf   display+1
    
    movf    decenas_ma,	w
    call    tabla
    movwf   display+2
    
    movf    unidades_ha,   w
    call    tabla
    movwf   display+3
    
    movf    decenas_ha,    w
    call    tabla
    movwf   display
    return    
    
set_display_S4:			    ; Mostrar en display minutos y segundos de timer
    movf    unidades_st,	w 
    call    tabla
    movwf   display+1
    
    movf    decenas_st,	w
    call    tabla
    movwf   display+2
    
    movf    unidades_mt,   w
    call    tabla
    movwf   display+3
    
    movf    decenas_mt,    w
    call    tabla
    movwf   display
    return      
    
mostrar_valores:		    ; Multiplexado para displays de 7 segmentos 
    clrf    PORTD
    btfsc   banderas,	0
    goto    display_1
    btfsc   banderas,	1
    goto    display_2
    btfsc   banderas,	2
    goto    display_3
    goto    display_0
    
    display_0:			    
	movf    display+3,    W
	movwf   PORTC
	bsf	PORTD,	    0
	bsf	banderas,   0
	bcf	banderas,   1
	bcf	banderas,   2
return

    display_1:			    
	movf    display+2,  W
	movwf   PORTC
	bsf	PORTD,	    1
	bcf	banderas,   0
	bsf	banderas,   1
	bcf	banderas,   2
return
	
    display_2:			    
	movf	display+1,   W
	movwf	PORTC
	bsf	PORTD,	    2
	bcf	banderas,   0
	bcf	banderas,   1
	bsf	banderas,   2
return
	
    display_3:
	movf	display,    w
	movwf	PORTC
	bsf	PORTD,	    3
	bcf	banderas,   0
	bcf	banderas,   1
	bcf	banderas,   2
return	
	
check_decenas_s:
    decf    veces_ds,	1
    movf    diez,   0
    addwf   valor_s,  1
    movf    veces_ds,	0
    movwf   decenas_s
    return
    
check_unidades_s:
    decf    veces_us,	1
    movf    uno,    0
    addwf   valor_s,  1
    movf    veces_us,	0
    movwf   unidades_s
    return
    
check_decenas_m:
    decf    veces_dm,	1
    movf    diez,   0
    addwf   valor_m,  1
    movf    veces_dm,	0
    movwf   decenas_m
    return
    
check_unidades_m:
    decf    veces_um,	1
    movf    uno,    0
    addwf   valor_m,  1
    movf    veces_um,	0
    movwf   unidades_m
    return
    
check_decenas_h:
    decf    veces_dh,	1
    movf    diez,   0
    addwf   valor_h,  1
    movf    veces_dh,	0
    movwf   decenas_h
    return
    
check_unidades_h:
    decf    veces_uh,	1
    movf    uno,    0
    addwf   valor_h,  1
    movf    veces_uh,	0
    movwf   unidades_h
    return
    
check_decenas_d:
    decf    veces_dd,	1
    movf    diez,   0
    addwf   valor_d,  1
    movf    veces_dd,	0
    movwf   decenas_d
    return
    
check_unidades_d:
    decf    veces_ud,	1
    movf    uno,    0
    addwf   valor_d,  1
    movf    veces_ud,	0
    movwf   unidades_d
    return    
    
check_decenas_mes:
    decf    veces_dmes,	1
    movf    diez,   0
    addwf   valor_mes,  1
    movf    veces_dmes,	0
    movwf   decenas_mes
    return
    
check_unidades_mes:
    decf    veces_umes,	1
    movf    uno,    0
    addwf   valor_mes,  1
    movf    veces_umes,	0
    movwf   unidades_mes
    return  
    
check_decenas_st:
    decf    veces_dst,	1
    movf    diez,   0
    addwf   valor_st,  1
    movf    veces_dst,	0
    movwf   decenas_st
    return
    
check_unidades_st:
    decf    veces_ust,	1
    movf    uno,    0
    addwf   valor_st,  1
    movf    veces_ust,	0
    movwf   unidades_st
    return 
    
check_decenas_mt:
    decf    veces_dmt,	1
    movf    diez,   0
    addwf   valor_mt,  1
    movf    veces_dmt,	0
    movwf   decenas_mt
    return
    
check_unidades_mt:
    decf    veces_umt,	1
    movf    uno,    0
    addwf   valor_mt,  1
    movf    veces_umt,	0
    movwf   unidades_mt
    return 
    
check_decenas_ma:
    decf    veces_dma,	1
    movf    diez,   0
    addwf   valor_ma,  1
    movf    veces_dma,	0
    movwf   decenas_ma
    return
    
check_unidades_ma:
    decf    veces_uma,	1
    movf    uno,    0
    addwf   valor_ma,  1
    movf    veces_uma,	0
    movwf   unidades_ma
    return 
    
check_decenas_ha:
    decf    veces_dha,	1
    movf    diez,   0
    addwf   valor_ha,  1
    movf    veces_dha,	0
    movwf   decenas_ha
    return
    
check_unidades_ha:
    decf    veces_uha,	1
    movf    uno,    0
    addwf   valor_ha,  1
    movf    veces_uha,	0
    movwf   unidades_ha
    return
    
complete1:			; Contador de TMR1
    clrf    cont_1
    incf    segundos,	1
    btfss   bandera_alarma,   0
    return
    decf    segundos_t,	1
    return
    
minuto_complete:		; Se completó un minuto
    clrf    segundos
    incf    minutos,	1
    btfsc   PORTA, 6
    call    alarma_off		; Ver si la alarma estuvo encendida un minuto y apagarla
    return	
    
hora_complete:			; Se completó una hora
    clrf    minutos
    incf    horas,	1
    return
    
dia_complete:			; Se completó un día 
    clrf    horas
    incf    dias,	1
    return
    
ano_complete:			; Se complet+o un año
    movlw   0x01
    movwf   meses
    return
    
minutos_amax:			
    movlw   0x03B
    movwf   minutos_a
    return
    
horas_amax: 
    movlw   0x17
    movwf   horas_a
    return
    
timer_complete:			; Se completó el timer
    movlw   0x01		; Volver a cargar un minuto al timer
    movwf   minutos_t
    movlw   0x00
    movwf   segundos_t
    bsf	    PORTA,	6	; Encender alarma
    bcf	    bandera_alarma,   0
    return
    
alarma_complete:		; Se completó la alarma
    bsf	    PORTA,	6	; Emcemder alarma
    return
    
apagar_alarma:
    bcf	    PORTA,	6	; Apagar la alarma de timer con B5
    movlw   0x01		; Volver a cargar un minuto al timer
    movwf   minutos_t
    movlw   0x00
    movwf   segundos_t
    bcf	    bandera_alarma,	0
    return
    
alarma_off:			; Apagar alarma con B5
    bcf	    PORTA,	6
    bcf	    alarma_bandera, 0
    return
    
timer_minmax:
    movlw   0x63
    movwf   minutos_t
    return
    
timer_segmax:
    movlw   0x00
    movwf   segundos_t
    return
    
mes31:				; Subrutina para limitar meses de 31 días
    movf    dias,   0
    sublw   0x1F
    btfsc   STATUS, 0
    goto    $+4
    movlw   0x01
    movwf   dias
    incf    meses,  1
    return
    
mes28:				; Subrutina para limitar febrero de 28 días
    movf    dias,   0
    sublw   0x1C
    btfsc   STATUS, 0
    goto    $+4
    movlw   0x01
    movwf   dias
    incf    meses,  1
    return
    
mes30:				; Subrutina para limitar meses de 30 días
    movf    dias,   0
    sublw   0x1E
    btfsc   STATUS, 0
    goto    $+4
    movlw   0x01
    movwf   dias
    incf    meses,  1
    return
    
change:				; Cambiar de modo configuración
    btfsc   bandera_config,	0
    goto    state2
    goto    state1
    
    state1:
	btfsc   estados,	0
	goto	alarma_a    
	btfsc   estados,	1
	goto	alarma_a
	btfsc   estados,	2
	goto	timer_alarma
	goto    alarma_a
	
	timer_alarma:
	    comf    bandera_alarma, 1
	    return
	    
	alarma_a:
	    comf    alarma_bandera, 1
	    return
    
    state2:
    comf    config_state,   1
    return
    
inc:				    ; Subrutina para inrementar en modo configuración
    btfss   bandera_config,	0
    return
    
    btfsc   config_state,	0
    goto    config_2inc
    goto    config_1inc
    
    config_1inc:
	btfsc   estados,	0
	goto	inc_dias    
	btfsc   estados,	1
	goto	inc_ma
	btfsc   estados,	2
	goto	inc_st
	goto    inc_min
	
	inc_min:
	    incf    minutos
	    return
	    
	inc_dias:
	    incf    dias
	    return
	    
	inc_ma:
	    incf    minutos_a
	    return
	    
	inc_st:
	    incf    segundos_t
	    return
	    
    config_2inc:
	btfsc   estados,	0
	goto	inc_mes    
	btfsc   estados,	1
	goto	inc_ha
	btfsc   estados,	2
	goto	inc_mt
	goto    inc_hr
	
	inc_hr:
	    incf    horas
	    return
	    
	inc_mes:
	    incf    meses
	    return
	    
	inc_ha:
	    incf    horas_a
	    return
	    
	inc_mt:
	    incf    minutos_t
	    return
    
decr:					; Subrutina para decrementar en modo configuración 
    btfss   bandera_config, 0
    return
    
    btfsc   config_state,	0
    goto    config_2dec
    goto    config_1dec
    
    config_1dec:
	btfsc   estados,	0
	goto	dec_dia    
	btfsc   estados,	1
	goto	dec_ma
	btfsc   estados,	2
	goto	dec_st
	goto    dec_min
	
	dec_min:
	    decf    minutos
	    return
	    
	dec_dia:
	    decf    dias
	    return
	    
	dec_ma:
	    decf    minutos_a
	    return
	    
	dec_st:
	    decf    segundos_t
	    return
	    
    config_2dec:
	btfsc   estados,	0
	goto	dec_mes    
	btfsc   estados,	1
	goto	dec_ha
	btfsc   estados,	2
	goto	dec_mt
	goto    dec_hr
	
	dec_hr:
	    decf    horas
	    return 
	    
	dec_mes:
	    decf    meses
	    return
	    
	dec_ha:
	    decf    horas_a
	    return
	    
	dec_mt:
	    decf    minutos_t
	    return
	
org 100h
tabla:				; Tabla para obtener valores de display de 7 segmentos 
    clrf    PCLATH
    bsf	    PCLATH, 0
    andlw   0x0F
    addwf   PCL, 1		; Se suma el offset al PC y se almacena en dicho registro
    retlw   0b11101101		; Valor para 0 en display de 7 segmentos
    retlw   0b10100000		; Valor para 1 en display de 7 segmentos
    retlw   0b11001110		; Valor para 2 en display de 7 segmentos
    retlw   0b11101010		; Valor para 3 en display de 7 segmentos
    retlw   0b10100011		; Valor para 4 en display de 7 segmentos
    retlw   0b01101011		; Valor para 5 en display de 7 segmentos 
    retlw   0b01101111		; Valor para 6 en display de 7 segmentos 
    retlw   0b11100000		; Valor para 7 en display de 7 segmentos 
    retlw   0b11101111		; Valor para 8 en display de 7 segmentos
    retlw   0b11100011		; Valor para 9 en display de 7 segmentos 
    retlw   0b11100111		; Valor para A en display de 7 segmentos
    retlw   0b00101111		; Valor para B en display de 7 segmentos
    retlw   0b01001101		; Valor para C en display de 7 segmentos
    retlw   0b10101110		; Valor para D en display de 7 segmentos
    retlw   0b01001111		; Valor para E en display de 7 segmentos 
    retlw   0b01000111		; Valor para F en display de 7 segmentos
    
END