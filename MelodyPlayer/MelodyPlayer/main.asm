;
; MusicBox.asm
;
; Created: 12.03.2020 23:28:50
; Author : Алексей
;



.include "tn2313adef.inc"



/******************************************************************************
* registers aliases 
******************************************************************************/
.def isTransmitInProg   = r12
.def nextStateForSend   = r13
.def isNeedNextChunk	= r14
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
.def bytesFromUsart		= r26



/******************************************************************************
* constants 
******************************************************************************/
.equ UART_BUFFER_SIZE		= 49
.equ TIMER_8BIT_REPETITION	= 64

; magic
.equ PROT_MAGIC1			= 0xcc
.equ PROT_MAGIC2			= 0xaa
.equ PROT_MAGIC_LEN			= 2
.equ PROT_MAX_MSG_LEN		= 32
.equ PROT_HEADER_SIZE       = 4

; commands
; from app
.equ EMPTY_STATE  = 0x00
.equ PLAY         = 0x01
.equ CONT_PLAY    = 0x02
.equ STOP         = 0x03
.equ PAUSE        = 0x04
.equ CONNECT      = 0x05
.equ DISCONNECT   = 0x06
.equ STATUS_REQ   = 0x07
.equ END_MELODY   = 0x08
; to app
.equ DISCONNECTED = 0x09
.equ PLAYING      = 0x0a
.equ STOPPED      = 0x0b
.equ PAUSED       = 0x0c
.equ NEXT_CHUNK   = 0x0d


.equ FIRST_MAGIC_BYTE_MASK			= 0x01
.equ SECOND_MAGIC_BYTE_MASK			= 0x02
.equ MSG_TYPE_BYE_MASK				= 0x04
.equ FULL_MSG_HEADER_MASK			= 0x08
.equ FIRST_MAGIC_BYTE_BIT			= 0
.equ SECOND_MAGIC_BYTE_BIT			= 1
.equ MSG_TYPE_BYTE_BIT				= 2
.equ FULL_MSG_HEADER_BIT			= 3
.equ NEED_SEND_ANSWER_BIT			= 4
.equ NEED_PLAY_MELODY_BIT			= 5
.equ MELODY_END_BIT1				= 6
.equ MELODY_END_BIT2				= 7
.equ STATE_BYTE_NUMBER_IN_HEADER	= 2

.equ END_MELODY_MARKER				= 0xFF

.equ NEED_NEXT_PORTION_OF_MELODY_BYTES_COUNT = 16


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
	ldi ZH, HIGH(@0 * 2)
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
.org 0
rjmp START
.org 7
rjmp USART0_RX_COMPLETE_ISR
.org 9
rjmp USART0_TX_COMPLETE_ISR
.org 13
rjmp TIMER0_COMPA_ISR



/******************************************************************************
* usart rx complete isr, for inbound messages
******************************************************************************/
UPDATE_LEDS_FUNC:
	mov temp1, bytesFromUsart
	lsl temp1
	lsl temp1
	in temp2, PORTD
	cbr temp2, 0xFC
	or temp2, temp1
	out PORTD, temp2
	ret



USART0_RX_COMPLETE_ISR:
	in temp1, UDR

usart_rx_complete_isr_choose_data:
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
	sbr receivedMsgState, (1 << FULL_MSG_HEADER_BIT)
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

; temp1 - offset, temp2 - value to store
STORE_BYTE_TO_DSEG_FUNC:
	add ZL, temp1
	brcc store_byte_to_dseg_func_store
	inc ZH
store_byte_to_dseg_func_store:
	st Z, temp2
	ret



SAVE_CUR_STATE_IN_OUT_BUFFER_FUNC:
	mov temp1, isTransmitInProg
	cpi temp1, 0
	breq save_cur_state_in_out_buffer_func_send_byte
	mov nextStateForSend, currentState
	rjmp save_cur_state_in_out_buffer_func_end

save_cur_state_in_out_buffer_func_send_byte:
	ldi temp1, STATE_BYTE_NUMBER_IN_HEADER
	mov temp2, currentState
	STORE_BYTE_TO_DSEG_MACRO msgHdrOutBuffer

save_cur_state_in_out_buffer_func_end:
	ret



PROCESS_PLAY_MSG_FUNC:
	cpi currentState, STOPPED
	brne process_play_msg_func_end

	SET_AND_SAVE_CUR_STATE_FOR_SENDING_MACRO PLAYING
	sbr receivedMsgState, (1 << NEED_PLAY_MELODY_BIT)
	ldi temp1, 1
	mov isNeedNextChunk, temp1

process_play_msg_func_end:
	ret



PROCESS_CONT_PLAY_MSG_FUNC:
	cpi currentState, PAUSED
	brne process_cont_play_msg_func_end

	SET_AND_SAVE_CUR_STATE_FOR_SENDING_MACRO PLAYING
	sbr receivedMsgState, (1 << NEED_PLAY_MELODY_BIT)

process_cont_play_msg_func_end:
	ret



PROCESS_MSG_TYPE_FUNC:
	cpi receivedMsgType, PLAY
	brne process_msg_type_func_is_cont_play
	rcall PROCESS_PLAY_MSG_FUNC
	rjmp process_msg_type_func_end

process_msg_type_func_is_cont_play:
	cpi receivedMsgType, CONT_PLAY
	brne process_msg_type_func_is_stop
	rcall PROCESS_CONT_PLAY_MSG_FUNC
	rjmp process_msg_type_func_end

process_msg_type_func_is_stop:
	cpi receivedMsgType, STOP
	brne process_msg_type_func_is_pause
	rcall PROCESS_STOP_MSG_FUNC
	rjmp process_msg_type_func_end

process_msg_type_func_is_pause:
	cpi receivedMsgType, PAUSE
	brne process_msg_type_func_is_connect
	rcall PROCESS_PAUSE_MSG_FUNC
	rjmp process_msg_type_func_end

process_msg_type_func_is_connect:
	cpi receivedMsgType, CONNECT
	brne process_msg_type_func_is_disconnect
	rcall PROCESS_CONNECT_MSG_FUNC
	rjmp process_msg_type_func_end

process_msg_type_func_is_disconnect:
	cpi receivedMsgType, DISCONNECT
	brne process_msg_type_func_is_status_req
	rcall PROCESS_DISCONNECT_MSG_FUNC
	rjmp process_msg_type_func_end

process_msg_type_func_is_status_req:
	cpi receivedMsgType, STATUS_REQ
	brne process_msg_type_func_is_end_melody
	rcall PROCESS_STATUS_REQ_MSG_FUNC
	rjmp process_msg_type_func_end

process_msg_type_func_is_end_melody:
	cpi receivedMsgType, END_MELODY
	brne process_msg_type_func_end
	rcall PROCESS_STATUS_END_MELODY_FUNC

process_msg_type_func_end:
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



PROCESS_STATUS_END_MELODY_FUNC:
	clr isNeedNextChunk
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
	sbrc receivedMsgState, NEED_PLAY_MELODY_BIT
	rcall PLAY_NEXT_NOTE_FUNC
	clr receivedMsgState

process_msg_length_func_end:
	ret



SEND_ANSWER_TO_USART_FUNC:
	ldi temp1, 1
	mov isTransmitInProg, temp1
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
	rcall CALCULATE_BYTE_COUNT_IN_BUFFER_FUNC
	cpi temp1, (UART_BUFFER_SIZE - 1)
	; if there is no enough place for next byte - skip it
	brsh store_msg_data_func_check_msg_len
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
    ; if needs - start playing
	sbrc receivedMsgState, NEED_PLAY_MELODY_BIT
	rcall PLAY_NEXT_NOTE_FUNC
	clr receivedMsgState

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
	rcall STOP_TIMER0_FUNC
	rcall STOP_TIMER1_FUNC

	rcall CALCULATE_BYTE_COUNT_IN_BUFFER_FUNC
	cpi temp1, 2
	brsh play_next_note_func_load_delay
	SET_AND_SAVE_CUR_STATE_FOR_SENDING_MACRO PAUSED
	rcall SEND_ANSWER_TO_USART_FUNC
	clr receivedMsgState
	ret

play_next_note_func_load_delay:
	; load delay value
	mov temp1, startData
	rcall INC_UART_DATA_START_PTR_FUNC
	LOAD_BYTE_FROM_DSEG_MACRO uartBuffer
	mov temp1, temp2
	cpi temp1, END_MELODY_MARKER
	brne play_next_note_func_prepare_timer0
	sbr receivedMsgState, (1 << MELODY_END_BIT1)

play_next_note_func_prepare_timer0:
	rcall NORMALIZE_TIMER0_DELAYS_COUNT_FUNC
	out OCR0A, temp1

	; load freq number value
	mov temp1, startData
	rcall INC_UART_DATA_START_PTR_FUNC
	LOAD_BYTE_FROM_DSEG_MACRO uartBuffer
	mov temp1, temp2
	cpi temp1, END_MELODY_MARKER
	brne play_next_note_func_prepare_timer1
	sbr receivedMsgState, MELODY_END_BIT2

	sbrc receivedMsgState, MELODY_END_BIT1
	sbrs receivedMsgState, MELODY_END_BIT2
	rjmp play_next_note_func_prepare_timer1
	ldi currentState, STOPPED
	cbr receivedMsgState, (1 << MELODY_END_BIT1 | 1 << MELODY_END_BIT2)
	clr startData
	clr endData
	SET_AND_SAVE_CUR_STATE_FOR_SENDING_MACRO STOPPED
	rcall SEND_ANSWER_TO_USART_FUNC
	ret

play_next_note_func_prepare_timer1:
	cpi temp1, 0 ; is it pause?
	breq play_next_note_func_pause_start
	dec temp1
	LOAD_WORD_FROM_PROG_MEM_MACRO octavaMinor ; after this func complete we will have freq in temp1:temp2
	rcall SETUP_TIMER1_REGS_VALUE_FUNC

	cbr receivedMsgState, (1 << MELODY_END_BIT1 | 1 << MELODY_END_BIT2)

	; play note
	rcall START_TIMER1_NO_PRESCALING_FUNC
play_next_note_func_pause_start:
	rcall START_TIMER0_1024_PRESCALING_FUNC
	ret



CALCULATE_BYTE_COUNT_IN_BUFFER_FUNC:
	cp startData, endData
	brsh calculate_byte_count_in_buffer_func_not_lower
	; startData lower than endData
	mov temp1, endData
	sub temp1, startData
	ret

calculate_byte_count_in_buffer_func_not_lower:
	breq calculate_byte_count_in_buffer_func_equal
	; endData lower than startData
	mov temp2, startData
	sub temp2, endData
	ldi temp1, UART_BUFFER_SIZE
	sub temp1, temp2
	ret

calculate_byte_count_in_buffer_func_equal:
	; startData equal endData
	clr temp1
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



NORMALIZE_TIMER0_DELAYS_COUNT_FUNC:
	ldi timer0DelayCycles, TIMER_8BIT_REPETITION

	; is it full pause?
	cpi temp1, 0
	breq normalize_timer0_delays_count_func_setup_full_note

normalize_timer0_delays_count_func_cycle:
	cpi temp1, 128
	brsh normalize_timer0_delays_count_func_end
	sbrc timer0DelayCycles, 0
	rjmp normalize_timer0_delays_count_func_end
	lsl temp1
	lsr timer0DelayCycles
	rjmp normalize_timer0_delays_count_func_cycle

normalize_timer0_delays_count_func_setup_full_note:
	ldi timer0DelayCycles, TIMER_8BIT_REPETITION * 2
	ldi temp1, 128

normalize_timer0_delays_count_func_end:
	ret



/******************************************************************************
* Functions for sending bytes to usart
* send data from msgHdrOutBuffer; first byte has already sent from another ISR
******************************************************************************/
USART0_TX_COMPLETE_ISR:
	cpi byteNumForOut, PROT_HEADER_SIZE
	brsh usart0_tx_complete_isr_check_second_state

usart0_tx_complete_isr_check_send_normal_byte:
	; load byte from msgHdrOutBuffer
	mov temp1, byteNumForOut
	LOAD_BYTE_FROM_DSEG_MACRO msgHdrOutBuffer
	mov temp1, temp2
	rcall USART0_TRANSMIT_FUNC
	inc byteNumForOut
	rjmp usart0_tx_complete_isr_end

usart0_tx_complete_isr_check_second_state:
	mov temp1, nextStateForSend 
	cpi temp1, EMPTY_STATE
	breq usart0_tx_complete_isr_stop_transmit
	ldi temp1, 2
	mov temp2, nextStateForSend
	STORE_BYTE_TO_DSEG_MACRO msgHdrOutBuffer
	ldi temp1, EMPTY_STATE
	mov nextStateForSend, temp1

	; load byte from msgHdrOutBuffer
	clr temp1
	LOAD_BYTE_FROM_DSEG_MACRO msgHdrOutBuffer
	mov temp1, temp2
	rcall USART0_TRANSMIT_FUNC
	ldi byteNumForOut, 1
	rjmp usart0_tx_complete_isr_end

usart0_tx_complete_isr_stop_transmit:
	; clear tx flag
	clr temp1
	mov isTransmitInProg, temp1

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
	tst timer0DelayCycles
	brne timer0_compa_isr_end

	rcall PLAY_NEXT_NOTE_FUNC
	rcall CALCULATE_BYTE_COUNT_IN_BUFFER_FUNC

	cpi temp1, NEED_NEXT_PORTION_OF_MELODY_BYTES_COUNT + 1
	brsh timer0_compa_isr_end
	cpi currentState, PLAYING
	brne timer0_compa_isr_end
	mov temp1, isNeedNextChunk
	cpi temp1, 1
	brne timer0_compa_isr_end

	push currentState
	ldi currentState, NEXT_CHUNK
	rcall SAVE_CUR_STATE_IN_OUT_BUFFER_FUNC
	pop currentState
	rcall SEND_ANSWER_TO_USART_FUNC

timer0_compa_isr_end:
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

	; PORTB 4 - output OC1B, PORTB 0, 1 - debug leds
	ldi temp1, 0x13
	out DDRB, temp1

	; PORTD 1 - usart tx, 2, 3, 4, 5, 6, 7 - debug leds
	ldi temp1, 0xFE
	out DDRD, temp1

	; on 8 MHz 76.8 kbps
	clr temp2
	ldi temp1, 12
	rcall USART_INIT_FUNC

	; enable OCIE0A interrupt
	ldi temp1, (1 << OCIE0A)
	out TIMSK, temp1

	; setup timers
	rcall SETUP_TIMER1_FAST_PWM_OUTPUTB_FUNC
	rcall SETUP_TIMER0_CTC_MODE_FUNC

	ldi temp1, 0
	ldi temp2, PROT_MAGIC1
	STORE_BYTE_TO_DSEG_MACRO msgHdrOutBuffer
	ldi temp1, 1
	ldi temp2, PROT_MAGIC2
	STORE_BYTE_TO_DSEG_MACRO msgHdrOutBuffer

	clr bytesFromUsart
	clr receivedMsgState
	clr nextStateForSend

	clr isTransmitInProg
	clr isNeedNextChunk
	clr usartDataByte
	clr timer0DelayCycles
	clr startData
	clr endData
	clr receivedMsgType
	clr receivedMsgLen

	clr temp2
	ldi temp1, STATE_BYTE_NUMBER_IN_HEADER
	STORE_BYTE_TO_DSEG_MACRO msgHdrOutBuffer
	ldi temp1, STATE_BYTE_NUMBER_IN_HEADER + 1
	STORE_BYTE_TO_DSEG_MACRO msgHdrOutBuffer

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
	in temp1, UCSRA
	sbr temp1, (1 << U2X)
	out UCSRA, temp1
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
	ror temp2
	ror temp1
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
octavaTwo:   .dw 15289, 14430, 13621, 12857, 12135, 11454, 10811, 10204,  9632,  9091,  8581,  8099
octavaThree: .dw  7645,  7216,  6810,  6428,  6068,  5727,  5405,  5102,  4816,  4545,  4290,  4050
octavaFour:  .dw  3822,  3608,  3405,  3214,  3034,  2863,  2703,  2551,  2408,  2273,  2145,  2025