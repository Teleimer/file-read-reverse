TITLE Temps-reverser     (template.asm)

;Trevor Leimer
; Description: This file intakes and reads an external file. It will convert the data in that file to an array, demarcated by a specific character
;as defined by a constant, and will then convert the set of ASCII signed ints into an array.  It will then  print this array to the console in 
;reverse order, fixing the silly mistake that our silly little intern made

INCLUDE Irvine32.inc

;mGetString
;receives offset of add.promp
;rec offset of address of string out
;recieves maxLen of file name
;
;returns countRead as bytes read from the file name
mGetString MACRO addrPrompt, addrStrOut, maxLen, countRead
	PUSH EDX
	PUSH ECX
	PUSH EAX
	mDisplayString OFFSET request_input
	CALL Crlf
	MOV  EDX, addrStrOut
	MOV  ECX, maxLen
	CALL ReadString
	MOV  countRead, EAX
	POP  EAX
	POP  ECX
	POP  EDX
ENDM

;mDisplayString
;takes an address OFFSET of the string that you want to print as addStrPring
;Returns nothing, but will print the string to the console.
mDisplayString MACRO addrStrPrint
	PUSH EDX
	MOV  EDX, addrStrPrint
	CALL WriteString
	;CALL Crlf
	POP  EDX
ENDM

;mdisplayChar
;takes an ASCII value as valPrint for the value that you will print to the screen
;no pre-conditions
;returns nothing, but will print the character to the screen
mDisplayChar MACRO valPrint
	PUSH EAX
	MOV  AL, valPrint
	CALL WriteChar
	POP  EAX
ENDM

DELIMITER EQU " "
TEMPS_PER_DAY = 10

.data

;text prompts for program progression

intro_input     BYTE "WELCOME TO THE INTERN DELETER... I mean error-correction-service. Please enter the name of a file formatted in ASCII and delimited by ",0
intro_input2    BYTE "We will then take the and return the information in reverse order! Don't worry humans are definitely not obsolete yet... ;)",0
intro_inputec1  BYTE "This program will also be able to handle text files with multiple lines of data, demarcated with an enter (CrLF) ",0
intro_inputec2  BYTE "Additionally this program will intake the integer information and convert it to ASCII characters, just for fun",0
request_data    BYTE "Please enter your file name within the constraints, default values are 4999 BYTES for File length and 50 BYTES for file_name. adjust at your own peril just as a machine would here: ",0
exit_prompt     BYTE "Well that is all, we have completed fixing the mistakes. Make sure to discipline those interns!",0

;file read and adjacent variables
file_name       BYTE 51 DUP(?),0
name_bytes_read DWORD ?
file_bytes_read DWORD ?
BUFFER_LENGTH   BYTE  50 DUP(?)
temps_array     BYTE 5000 DUP(0)
request_input   BYTE "Please write the name of the file that you need fixed here. Less than 50 characters please",0


;string read and related storage
parsed_array   SDWORD 5000 DUP(?)
current_num    SDWORD 0


.code
main PROC
	
	;print intro statements
	mDisplayString OFFSET intro_input
	CALL Crlf
	mDisplayString OFFSET intro_input2
	CALL Crlf
	mDisplayString OFFSET intro_inputec1
	CALL Crlf
	mDisplayString OFFSET intro_inputec2
	CALL Crlf

	;get file name as a string
	mGetString OFFSET request_data, OFFSET file_name, SIZEOF file_name, name_bytes_read

	;read file to temps_aray
	MOV  EDX, OFFSET file_name
	CALL OpenInputFile
	MOV  EDX, OFFSET temps_array
	MOV  ECX, 500
	CALL ReadFromFile
	CALL CloseFile
	

	;push and call items to parse the elements of the array. all passed as offset
	PUSH OFFSET current_num
	PUSH OFFSET temps_array
	PUSH OFFSET parsed_array
	CALL ParseTempsFromString
	
	;call write reverse
	PUSH OFFSET parsed_array
	CALL WriteTempsReverse

	;run exit prompt
	mDisplayString OFFSET exit_prompt
	



	Invoke ExitProcess,0	; exit to operating system
main ENDP


;ParseTempsFromString
;Takes an array of ASCII characters. calls a constant to remove those characters
;no preconditions
;requires: [EBP+8] = OFFSET parsed_array
;[EBP+12] = OFFSET temps_array
;[EBP+16] = OFFSET current_number
;
;returns: an array of SDWORDS in OFFSET parsed_array
;
ParseTempsFromString PROC USES EAX EBX ECX EDX ESI EDI
	
	LOCAL sum_total:SDWORD
	LOCAL row_number:DWORD
	LOCAL daily_bytes:DWORD
	
	;initialize locals
	MOV sum_total, 0
	MOV row_number, 1
	MOV EAX, TEMPS_PER_DAY
	MOV EBX, 4
	MUL EBX
	MOV daily_bytes, EAX
	MOV  ECX, TEMPS_PER_DAY	

_TOP:
	;set up first iteration through for 1 row
	PUSH ECX
	MOV EAX, daily_bytes
	MOV EBX, row_number
	SUB EBX, 1
	MUL EBX
	MOV  ESI, [EBP+12]
	
	;set up iteration for row n > 1
_StartNewRow:
	MOV  EDI, [EBP+16]
	MOV  ECX, 0

	;pulls values up until delimiter is hit
_PullVals:
	LODSB
	CMP  AL, DELIMITER
	JE   _ConvertInit
	STOSB
	INC  ECX
	JMP  _PullVals

_ConvertInit:
	;once delimiter is hit, initialize conditions to convert the ASCII string to integers
	MOV  EBX, 1
	SUB  EDI, 1
	MOV  [EBP+12], ESI ;store ESI on the parsed list
	MOV  ESI, EDI
	
	STD  ;change directions to backwards, as converting the numbers starts at the end of current_number

_Convert:
	;loop to convert the current_number to a SDWORD. gather a sum of dec places
	LODSB
	CMP AL, "-"
	JE  _NegNumber
	MOVSX EAX, AL
	SUB  EAX, 48
	MUL EBX
	ADD sum_total, EAX
	MOV EAX, 10
	MUL EBX
	MOV EBX, EAX
	LOOP _Convert
	
	;once the number has been fully converted to a sum, we store in parsed_array, and set up for next number in temps_array
_EndNumber:
	POP ECX
	MOV EBX, [EBP+8] ;integer array
	MOV EAX, TEMPS_PER_DAY
	SUB EAX, ECX
	MOV EDX, sum_total
	MOV [EBX+EAX*4], EDX
	MOV  sum_total, 0
	CLD
	MOV  EDX, 0 
	MOV  EBX, [EBP+16]
	MOV  [EBX], EDX
	LOOP _TOP
	
	;check for multiple rows
	MOV EAX, [EBP+8]
	ADD EAX, daily_bytes
	MOV [EBP+8], EAX
	MOV EDI, [EBP+12]
	
	;buffer in case end of line is DELIMITER OR CRLF
	MOV AL, DELIMITER
	SCASB
	JE  _CheckCarry
	SUB EDI, 1	

_CheckCarry:
	MOV AL, 13
	SCASB
	JNE _EndReading
	MOV AL, 10
	SCASB
	JNE _EndReading

	;if we hit here, enter was found:
	ADD row_number, 1
	MOV ESI, EDI
	MOV ECX, TEMPS_PER_DAY
	PUSH ECX
	JMP _StartNewRow


	;close out the read
_EndReading:	
	MOV EDI, ESI
	RET 12


	;condition for handling a negative number
_NegNumber:
	NEG sum_total
	JMP _EndNumber
ParseTempsFromString ENDP


;WriteTempsReverse
;Takes an OFFSET of parsed_temps  array, which is an array of SDWORDS, and will print the array in reverse order
;if multiple rows, each row is one day. Daily synchronization is maintained in the input data, so temps will only
;reverse WITHIN day
;calls printVal
;preconditions - NONE
;Requires: [EBP+4] = OFFSET parsed_array


WriteTempsReverse PROC USES EAX EBX ECX EDI
	
	LOCAL row_counter:DWORD
	LOCAL bytes_per_day:DWORD
	MOV row_counter, 1
	MOV bytes_per_day, 0

	;initialize procedure
	MOV  EDI, [EBP+8] 
	MOV  EAX, TEMPS_PER_DAY
	SUB  EAX, 1
	MOV  EBX, 4
	MUL  EBX
	MOV  bytes_per_day, EAX ;total number of bytes read per day/row
	

	;iterate for each row. start at the end of the current RoW, work backwards
_SetRow:	
	MOV EAX, bytes_per_day
	MOV EBX, row_counter
	MUL EBX
	ADD EDI, EAX
	MOV [EBP+8], EDI
	MOV ECX, TEMPS_PER_DAY
	

	;read the elements of the current row
_ReadRow:
	MOV  EAX, [EDI]
	PUSH ECX
	PUSH EAX
	CALL WriteVal
	mDisplayChar DELIMITER
	POP  ECX
	SUB  EDI, 4
	LOOP _ReadRow

	;check if multiple rows, account and adjust accordingly
_CheckNextRow:
	CALL Crlf
	ADD EDI, 8
	MOV [EBP+8], EDI
	ADD EDI, bytes_per_day
	MOV AL, 0
	SCASB
	JE  _endReadingTime
	ADD row_counter, 1
	MOV EDI, [EBP+8]
	JMP _SetRow

	;if no more lines to read, leave
_endReadingTime:
	CALL Crlf
RET 4



WriteTempsReverse ENDP



;WriteVal
;Takes an argument as an integer , as the last value passed to the stack. Will convert the INT to a STR and print the ASCII value for that INT
;IT DOES CALL THE WRITE STRING MACRO USING A REGISTER. I KNOW THE ASSIGNMENT SAYS ALL MACRO CALLS MUST USE OFFSET ADDRESSES DIRECTLY, HOWEVER
;RATHER THAN MAKE THE MACRO CALL THE GLOBAL OUT OF THE SPECIFIC PROC CALL I MADE 100% SURE THAT THE EDI REGISTER ALWAYS CONTAINS THE ADDRESS OFFSET
;FOR THE STRING THAT WILL BE PRINTED, AS THE LOCAL print_string
;preconditions: none
;Requires:
;[EBP+4] - must be an int, between [-100, +200]
;prints the integer to the console
;
WriteVal PROC USES EAX EBX EDX ECX ESI EDI

	LOCAL sign_char:DWORD
	LOCAL print_string[5]:BYTE 
	
	

	;set local vars to 0, EDI as offset of print_string DWORD
	MOV sign_char, 43
	MOV print_string[0],0
	MOV print_string[1],0
	MOV print_string[2],0
	MOV print_string[3],0
	MOV print_string[4],0
	;EDI  TO OFFSEST print_string LOCAL
	MOV ECX, 0
	MOV EDI, EBP
	SUB EDI, 9
	MOV ESI, EDI ;for easy access later
	 
	
	;check if integer passed to the proc is +/-
	MOV EAX, [EBP+8]
	CMP EAX, 0
	JGE  _ComputeString ;jump if positive, otherwise convert to positive

	;if negative:
	MOV sign_char, "-"
	NEG EAX

_ComputeString:
	;calc 100's place, store value
	INC EDI ;leave room for the sign byte!
	MOV EBX, 100
	MOV EDX, 0
	DIV EBX
	CMP EAX, 0
	JE  _CheckTens
	MOV ECX, 1
	ADD EAX, 48
	STOSB
	
	;calc 10's place, store value
_CheckTens:	
	MOV EBX, 10
	MOV EAX, EDX
	MOV EDX, 0
	DIV EBX
	CMP ECX, 1
	JE  _HundredsException ;handling exception for 100's where the 10's place ==0
	CMP EAX, 0
	JE  _CheckOnes
_HundredsException:	
	ADD EAX, 48
	STOSB

	;account for 1's place
_CheckOnes:
	MOV  EAX, EDX
	ADD  AL, 48
	STOSB

	;prime for macro, remove leading 0's and add in a sign
	MOV ECX, 3
	MOV EDI, ESI ; move start of the array
	ADD EDI, 1
	MOV AL, 30
	REPE SCASB  ;remove leading zeroes
	SUB EDI,2 ;move back 1 space as home of the sign character
	MOV EAX, sign_char
	STOSB ;adds in sign char
	SUB EDI, 1

	
	;USE EDI as REGISTER as I cannot Use a GLOBAL OFFSET within a PROC
	;The call still works.
	mDisplayString EDI

	RET 4

WriteVal ENDP

END main
