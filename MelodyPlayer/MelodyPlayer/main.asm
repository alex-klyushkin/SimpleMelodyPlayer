;
; MusicBox.asm
;
; Created: 12.03.2020 23:28:50
; Author : Алексей
;

; 1) написать запуск проигрывания одной ноты по данным лежащим в буфере - обработка прерываний на обоих таймерах
; 2) сделать старт/стоп мелодии. В мелодию добавить маркер конца.
; 3) проигрывание мелодии запускать в 2 случаях: начало проигрывания, переход от паузы к проигрыванию. 
;    останавливать при паузе (счетчик циклов таймера0 не обнулять), при стопе 
;    (обнулять счетчик циклов и указатели на данные в буфере мелодии) и в конце мелодии (так же как и при стопе)


.include "tn2313adef.inc"



/******************************************************************************
* registers aliases 
******************************************************************************/
.def usartDataByte		= r15
.def temp1				= r16
.def temp2				= r17

; count of timer0 launches
.def timer0DelayCycles	= r18

; for cyclic buffer with uart data
.def startData			= r19
.def endData			= r20

; output message byte for sending
.def byteNumForOut		= r21

; for input message
.def receivedMsgState   = r22
.def receivedMsgType    = r23
.def receivedMsgLen     = r24
.def currentState       = r25



/******************************************************************************
* constants 
******************************************************************************/
.equ UART_BUFFER_SIZE		= 49
.equ TIMER_8BIT_REPETITION	= 32

; magic
.equ PROT_MAGIC1			= 0xcc
.equ PROT_MAGIC2			= 0xaa
.equ PROT_MAGIC_LEN			= 2
.equ PROT_MAX_MSG_LEN		= 32
.equ PROT_HEADER_SIZE       = 4

; commands
; from app
.equ PLAY         = 0x01
.equ CONT_PLAY    = 0x02
.equ STOP         = 0x03
.equ PAUSE        = 0x04
.equ CONNECT      = 0x05
.equ DISCONNECT   = 0x06
.equ STATUS_REQ   = 0x07
; to app
.equ DISCONNECTED = 0x08
.equ PLAYING      = 0x09
.equ STOPPED      = 0x0a
.equ PAUSED       = 0x0b
.equ NEXT_CHUNK   = 0x0c


.equ FIRST_MAGIC_BYTE_MASK			= 0x01
.equ SECOND_MAGIC_BYTE_MASK			= 0x02
.equ MSG_TYPE_BYE_MASK				= 0x04
.equ FULL_MSG_HEADER_MASK			= 0x08
.equ FIRST_MAGIC_BYTE_BIT			= 0
.equ SECOND_MAGIC_BYTE_BIT			= 1
.equ MSG_TYPE_BYTE_BIT				= 2
.equ FULL_MSG_HEADER_BIT			= 3
.equ NEED_SEND_ANSWER_BIT			= 4
.equ STATE_BYTE_NUMBER_IN_HEADER	= 2

.equ END_MELODY_MARKER				= 0xFF



/******************************************************************************
* macro definitions
******************************************************************************/
; @0 - label address
.MACRO STORE_BYTE_TO_DSEG_MACRO
	ldi ZL, LOW(@0)
	ldi ZH, HIGH(@0)
	rcall STORE_BYTE_TO_DSEG_FUNC
.ENDMACRO



; @0 - label address
.MACRO LOAD_BYTE_FROM_DSEG_MACRO
	ldi ZL, LOW(@0)
	ldi ZH, HIGH(@0)
	rcall LOAD_BYTE_FROM_DSEG_FUNC
.ENDMACRO


; @0 - state for saving
.MACRO SET_AND_SAVE_CUR_STATE_FOR_SENDING_MACRO
	sbr receivedMsgState, (1 << NEED_SEND_ANSWER_BIT)
	ldi currentState, @0
	rcall SAVE_CUR_STATE_IN_OUT_BUFFER_FUNC
.ENDMACRO



.MACRO LOAD_WORD_FROM_PROG_MEM_MACRO
	ldi ZL, LOW(@0 * 2)
	ldi ZH, LOW(@0 * 2)
	rcall LOAD_WORD_FROM_PROG_MEM_FUNC
.ENDMACRO



/******************************************************************************
* variables in sram
******************************************************************************/
.dseg
msgHdrOutBuffer: .db PROT_MAGIC1, PROT_MAGIC2, 0, 0
//49 bytes for uart data
uartBuffer: .db 0, 0, 0, 0, 0, 0, 0, 0
			.db 0, 0, 0, 0, 0, 0, 0, 0
			.db 0, 0, 0, 0, 0, 0, 0, 0
			.db 0, 0, 0, 0, 0, 0, 0, 0
			.db 0, 0, 0, 0, 0, 0, 0, 0
			.db 0, 0, 0, 0, 0, 0, 0, 0
			.db 0



/******************************************************************************
* interrupts vector
******************************************************************************/
.cseg
; interrupts vector
rjmp START
.org 7
rjmp USART0_RX_COMPLETE_ISR
.org 9
rjmp USART0_TX_COMPLETE_ISR
.org 13
rjmp TIMER0_COMPA_ISR
.org 22



/******************************************************************************
* usart rx complete isr, for inbound messages
******************************************************************************/
USART0_RX_COMPLETE_ISR:
	in temp1, UDR

	; choose what data is
	sbrs receivedMsgState, FIRST_MAGIC_BYTE_BIT
	rjmp check_first_magic_byte
	sbrs receivedMsgState, SECOND_MAGIC_BYTE_BIT
	rjmp check_second_magic_byte
	sbrs receivedMsgState, MSG_TYPE_BYTE_BIT
	rjmp process_msg_type
	sbrs receivedMsgState, FULL_MSG_HEADER_BIT
	rjmp process_msg_length
	rjmp store_msg_data

check_first_magic_byte:
	cpi temp1, PROT_MAGIC1
	brne usart0_rx_complete_isr_end
	sbr receivedMsgState, (1 << FIRST_MAGIC_BYTE_BIT)
	rjmp usart0_rx_complete_isr_end

check_second_magic_byte:
	rcall CHECK_SECONG_MAGIC_BYTE_FUNC
	rjmp usart0_rx_complete_isr_end

process_msg_type:
	sbr receivedMsgState, (1 << MSG_TYPE_BYTE_BIT)
	mov receivedMsgType, temp1
	rcall PROCESS_MSG_TYPE_FUNC
	rjmp usart0_rx_complete_isr_end

process_msg_length:
	sbr receivedMsgState, (1 << MSG_TYPE_BYTE_BIT)
	mov receivedMsgLen, temp1
	rcall PROCESS_MSG_LENGTH_FUNC
	rjmp usart0_rx_complete_isr_end

store_msg_data:
	mov usartDataByte, temp1
	rcall STORE_MSG_DATA_FUNC

usart0_rx_complete_isr_end:
	reti



CHECK_SECONG_MAGIC_BYTE_FUNC:
	cpi temp1, PROT_MAGIC2
	breq complete_second_magic_byte
	clr receivedMsgState
	ret

complete_second_magic_byte:
	sbr receivedMsgState, (1 << SECOND_MAGIC_BYTE_BIT)
	ret



/******************************************************************************
* Functions for processing message type
******************************************************************************/
PROCESS_MSG_TYPE_FUNC:
	cpi receivedMsgType, PLAY
	breq PROCESS_PLAY_MSG_FUNC
	cpi receivedMsgType, CONT_PLAY
	breq PROCESS_CONT_PLAY_MSG_FUNC
	cpi receivedMsgType, STOP
	breq PROCESS_STOP_MSG_FUNC
	cpi receivedMsgType, PAUSE
	breq PROCESS_PAUSE_MSG_FUNC
	cpi receivedMsgType, CONNECT
	breq PROCESS_CONNECT_MSG_FUNC
	cpi receivedMsgType, DISCONNECT
	breq PROCESS_DISCONNECT_MSG_FUNC
	cpi receivedMsgType, STATUS_REQ
	breq PROCESS_STATUS_REQ_MSG_FUNC
	ret



; temp1 - offset, temp2 - value to store
STORE_BYTE_TO_DSEG_FUNC:
	add ZL, temp1
	brcc store_byte_to_dseg_func_store
	inc ZH
store_byte_to_dseg_func_store:
	st Z, temp2
	ret



SAVE_CUR_STATE_IN_OUT_BUFFER_FUNC:
	ldi temp1, STATE_BYTE_NUMBER_IN_HEADER
	mov temp2, currentState
	STORE_BYTE_TO_DSEG_MACRO msgHdrOutBuffer
	ret



PROCESS_PLAY_MSG_FUNC:
	cpi currentState, STOPPED
	brne process_play_msg_func_end

	SET_AND_SAVE_CUR_STATE_FOR_SENDING_MACRO PLAYING

process_play_msg_func_end:
	ret



PROCESS_CONT_PLAY_MSG_FUNC:
	cpi currentState, PAUSED
	brne process_cont_play_msg_func_end

	SET_AND_SAVE_CUR_STATE_FOR_SENDING_MACRO PLAYING

process_cont_play_msg_func_end:
	ret



PROCESS_STOP_MSG_FUNC:
	cpi currentState, PLAYING
	breq process_stop_msg_func_apply_stop
	cpi currentState, PAUSED
	brne process_stop_msg_func_end

process_stop_msg_func_apply_stop:
	SET_AND_SAVE_CUR_STATE_FOR_SENDING_MACRO STOPPED
	rcall STOP_TIMER0_FUNC
	rcall STOP_TIMER1_FUNC
	clr startData
	clr endData
	clr timer0DelayCycles

process_stop_msg_func_end:
	ret



PROCESS_PAUSE_MSG_FUNC:
	cpi currentState, PLAYING
	brne process_pause_msg_func_end

	SET_AND_SAVE_CUR_STATE_FOR_SENDING_MACRO PAUSED
	rcall STOP_TIMER0_FUNC
	rcall STOP_TIMER1_FUNC

process_pause_msg_func_end:
	ret



PROCESS_STATUS_REQ_MSG_FUNC:
	;load currentState to msgHdrOutBuffer
	rcall SAVE_CUR_STATE_IN_OUT_BUFFER_FUNC
	ret



PROCESS_CONNECT_MSG_FUNC:
	ldi temp1, DISCONNECTED
	cpse currentState, temp1
	breq process_connect_msg_func_end
	
	;currentState = STOPPED
	SET_AND_SAVE_CUR_STATE_FOR_SENDING_MACRO STOPPED

process_connect_msg_func_end:
	ret



PROCESS_DISCONNECT_MSG_FUNC:
	cpi currentState, DISCONNECTED
	breq process_disconnect_msg_func_end

	;currentState = DISCONNECTED
	SET_AND_SAVE_CUR_STATE_FOR_SENDING_MACRO DISCONNECTED

process_disconnect_msg_func_end:
	ret



/******************************************************************************
* Functions for processing message length
******************************************************************************/
PROCESS_MSG_LENGTH_FUNC:
	tst receivedMsgLen
	brne process_msg_length_func_end

	; process messages with zero length
	; load from msgHdrOutBuffer first byte and send it
	sbrc receivedMsgState, NEED_SEND_ANSWER_BIT
	rcall SEND_ANSWER_TO_USART_FUNC
	clr receivedMsgState

process_msg_length_func_end:
	ret



SEND_ANSWER_TO_USART_FUNC:
	clr temp1
	LOAD_BYTE_FROM_DSEG_MACRO msgHdrOutBuffer
	mov temp1, temp2
	ldi byteNumForOut, 1
	rcall USART0_TRANSMIT_FUNC
	ret



/******************************************************************************
* Function for storing data from usart to uartBuffer
******************************************************************************/
STORE_MSG_DATA_FUNC:
	mov temp1, endData
	mov temp2, usartDataByte
	STORE_BYTE_TO_DSEG_MACRO uartBuffer
	rcall INC_UART_DATA_END_PTR_FUNC

store_msg_data_func_check_msg_len:
	dec receivedMsgLen
	tst receivedMsgLen
	brne store_msg_data_func_end
	; if needs - send answer
	sbrc receivedMsgState, NEED_SEND_ANSWER_BIT
	rcall SEND_ANSWER_TO_USART_FUNC
	clr receivedMsgState
    ; if needs - start playing

store_msg_data_func_end:
	ret



; temp1 - offset, loaded value stored to temp2
LOAD_BYTE_FROM_DSEG_FUNC:
	clr temp2
	add ZL, temp1
	adc ZH, temp2
	ld temp2, Z
	ret



PLAY_NEXT_NOTE_FUNC:
	; load delay value
	mov temp1, startData
	LOAD_BYTE_FROM_DSEG_MACRO uartBuffer
	mov temp1, temp2
	rcall INC_UART_DATA_START_PTR_FUNC

	rcall STOP_TIMER0_FUNC
	rcall NORMALIZE_TIMER0_DELAYS_COUNT_FUNC
	out OCR0A, temp1

	; load freq number value
	mov temp1, startData
	LOAD_BYTE_FROM_DSEG_MACRO uartBuffer
	mov temp1, temp2
	rcall INC_UART_DATA_START_PTR_FUNC
	rcall STOP_TIMER1_FUNC
	LOAD_WORD_FROM_PROG_MEM_MACRO octavaMinor ; after this func complete we will have freq in temp1:temp2
	rcall SETUP_TIMER1_REGS_VALUE_FUNC

	; play note
	rcall START_TIMER0_1024_PRESCALING_FUNC
	rcall START_TIMER1_NO_PRESCALING_FUNC
	ret



LOAD_WORD_FROM_PROG_MEM_FUNC:
	rol temp1
	clr temp2
	add ZL, temp1
	adc ZH, temp2
	lpm temp1, Z+
	lpm temp2, Z
	ret



INC_UART_DATA_START_PTR_FUNC:
	inc startData
	cpi startData, UART_BUFFER_SIZE
	brlo inc_uart_data_start_ptr_func_end
	clr startData

inc_uart_data_start_ptr_func_end:
	ret



INC_UART_DATA_END_PTR_FUNC:
	inc endData
	cpi endData, UART_BUFFER_SIZE
	brlo inc_uart_data_end_ptr_func_end
	clr endData

inc_uart_data_end_ptr_func_end:
	ret



/******************************************************************************
* Functions for sending bytes to usart
* send data from msgHdrOutBuffer; first byte has already sent from another ISR
******************************************************************************/
USART0_TX_COMPLETE_ISR:
	cpi byteNumForOut, PROT_HEADER_SIZE
	brsh usart0_tx_complete_isr_end

	; load byte from msgHdrOutBuffer
	mov temp1, byteNumForOut
	LOAD_BYTE_FROM_DSEG_MACRO msgHdrOutBuffer
	mov temp1, temp2
	rcall USART0_TRANSMIT_FUNC
	inc byteNumForOut

usart0_tx_complete_isr_end:
	reti



; temp1 contain byte for sending
USART0_TRANSMIT_FUNC:
	sbis UCSRA,UDRE
	rjmp USART0_TRANSMIT_FUNC
	out UDR, temp1
	ret



/******************************************************************************
* ISR for CTC mode 8-bit timer0
******************************************************************************/
TIMER0_COMPA_ISR:
	dec timer0DelayCycles
	clr temp1
	cpse timer0DelayCycles, temp1
	reti

	;load next note and next delay
	reti



/******************************************************************************
* Reset interrupt function
******************************************************************************/
START:
	; set up stack
	ldi temp1, LOW(RAMEND)
	out SPL, temp1

	; init registers
	ldi byteNumForOut, PROT_HEADER_SIZE
	ldi currentState, DISCONNECTED

	; PORTB 4 - output OC1B
	ldi temp1, 0x10
	out DDRB, temp1

	; on 8 MHz 250 kbps
	clr temp2
	ldi temp1, 1
	rcall USART_INIT_FUNC

	; enable OCIE0A interrupt
	ldi temp1, (1 << OCIE0A)
	out TIMSK, temp1

	; setup timers
	rcall SETUP_TIMER1_FAST_PWM_OUTPUTB_FUNC
	rcall SETUP_TIMER0_CTC_MODE_FUNC

	; enable global interrupt
	sei

inf_loop:
	rjmp inf_loop



/******************************************************************************
* Init usart in asinchronous mode
******************************************************************************/
USART_INIT_FUNC:
	; Set baud rate
	out UBRRH, temp2
	out UBRRL, temp1
	; Enable receiver and transmitter, tx and rx complete interrupts
	ldi temp1, (1 << RXEN | 1 << TXEN | 1 << RXCIE | 1 << TXCIE)
	out UCSRB, temp1
	; Set frame format: 8data, 1 stop bit, even parity
	ldi temp1, (1 << UCSZ1 | 1 << UCSZ0 | 1 << UPM1)
	out UCSRC, temp1
	ret



/******************************************************************************
* Functions for 16-bit timer1
******************************************************************************/
SETUP_TIMER1_FAST_PWM_OUTPUTB_FUNC:
	; Clear OC1B on Compare Match, set OC1B at TOP
	; Fast PWM, OCR1A TOP
	ldi temp1, (1 << COM1B1 | 1 << WGM11 | 1 << WGM10)
	out TCCR1A, temp1
	ldi temp1, (1 << WGM13 | 1 << WGM12)
	out TCCR1B, temp1
	ret



SETUP_TIMER1_REGS_VALUE_FUNC:
	out OCR1AH, temp2
	out OCR1AL, temp1
	clc
	ror temp1
	ror temp2
	out OCR1BH, temp2
	out OCR1BL, temp1
	ret



START_TIMER1_NO_PRESCALING_FUNC:
	in temp1, TCCR1B
	sbr temp1, (1 << CS10)
	out TCCR1B, temp1
	ret



STOP_TIMER1_FUNC:
	in temp1, TCCR1B
	cbr temp1, (1 << CS12 | 1 << CS11 | 1 << CS10)
	out TCCR1B, temp1
	clr temp1
	out TCNT1H, temp1
	out TCNT1L, temp2
	ret



/******************************************************************************
* Functions for 8-bit timer0
******************************************************************************/
SETUP_TIMER0_CTC_MODE_FUNC:
	ldi temp1, (1 << WGM01)
	out TCCR0A, temp1
	ret



START_TIMER0_1024_PRESCALING_FUNC:
	in temp1, TCCR0B
	sbr temp1, (1 << CS02 | 1 << CS00)
	out TCCR0B, temp1
	ret



STOP_TIMER0_FUNC:
	in temp1, TCCR0B
	cbr temp1, (1 << CS02 | 1 << CS01 | 1 << CS00)
	out TCCR0B, temp1
	clr temp1
	out TCNT0, temp1
	ret



/******************************************************************************
* Notes and delays in programm memory
******************************************************************************/
; 				 do		do#    re     re#    mi     fa     fa#    sol    sol#   la     la#    si
octavaMinor: .dw 61157, 57724, 54484, 51427, 48541, 45816, 43243, 40816, 38526, 36364, 34323, 32396
octavaOne:   .dw 30578, 28862, 27242, 25714, 24270, 22908, 21622, 20408, 19263, 18182, 17162, 16198
;octavaTwo:   .dw 15289, 14431‬, 13621, 12857, 12135, 11454, 10811, 10204,  9632,  9091,  8581,  8099
octavaThree: .dw  7645,  7216,  6810,  6428,  6068,  5727,  5405,  5102,  4816,  4545,  4290,  4050
octavaFour:  .dw  3822,  3608,  3405,  3214,  3034,  2863,  2703,  2551,  2408,  2273,  2145,  2025
;octavaAddrs: .dw octavaMinor * 2, octavaOne * 2, octavaTwo * 2, octavaThree * 2, octavaFour * 2