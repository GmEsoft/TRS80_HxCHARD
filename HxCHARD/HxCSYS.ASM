;
;	HXCSYS/ASM		;System routines
;
*MOD
BRK	DEFL	0		;Enable Breakpoints

KIDO	DEFL	TER

	IF	SEG
	CSEG
	ENDIF

	IF	KIDO
DODVR	EQU	0BCFH		;DODVR entry point
CURSOR  EQU	0BDCH		;Cursor position (RAM address)
CRSAVE  EQU	0BDEH		;Character under cursor
CSRCHAR EQU	0BDFH		;Cursor character ('_')

	DC	100H,0		;local stack
$?STACK:
	ENDIF

	$MSG	HxCSYS
SYS_BEGIN:

;======	SYSTEM CALL ROUTINES ====================

;-----	Display char in A
DDISA:
	IF	KIDO

;	$$BREAK

	DI			;DISABLE INTERRUPTS

	LD	($DDISA_STK),SP	;save SP
	LD	SP,$?STACK	;local stack

	PUSH	AF
	LD	A,(78H)		;OPREG$
	RES	0,A
	OUT	(84H),A		;enable video RAM
	POP	AF

	PUSH	AF
	PUSH	HL
	PUSH	DE
	PUSH	BC

	LD	BC,(0211H)	;*DO driver
	LD	HL,CURSOR-DODVR	;Cursor position
	ADD	HL,BC
	LD	E,(HL)
	INC	HL
	LD	D,(HL)
	DEC	HL
	EX	DE,HL		;DE=posptr, HL=pos
	CP	' '
	JR	C,$?DD10	;go if ctrl char
	LD	(HL),A
	INC	HL
	JR	$?DD00
;
;	control chars
;
$?DD10:	LD	(HL),' '
	CP	0AH
	JR	Z,$?DDNL
	CP	0DH		;<ENTER>
	JR	NZ,$?DD11

$?DDNL:	PUSH	BC
	PUSH	DE
	INC	HL
	EX	DE,HL
	LD	BC,80
	LD	HL,0F800H
$?DDN0:	ADD	HL,BC
	LD	A,L
	SUB	D
	LD	A,H
	SBC	A,E
	JR	C,$?DDN0
	POP	DE
	POP	BC
	JR	$?DD00

$?DD11:				;for extension...
	$$BREAK
;
;	check for scroll
;
$?DD00:	LD	A,.LOW.0FF7FH
	SUB	L
	LD	A,.HIGH.0FF7FH
	SBC	A,H
	JR	NC,$?DD01	;go if no scroll
;
;	do scroll
;
	PUSH	DE
	PUSH	BC
	LD	HL,0F850H	;scroll color memory
	LD	DE,0F800H
	LD	BC,00730H
	LDIR
	LD	H,D		;fill last line with color
	LD	L,E
	PUSH	HL
	INC	DE
	LD	C,4FH
	LD	(HL),' '
	LDIR
	POP	HL
	POP	BC
	POP	DE
;
;	save pos and display cursor
;
$?DD01:	LD	(HL),'_'
	EX	DE,HL
	LD	(HL),E
	INC	HL
	LD	(HL),D
	DEC	HL
;	end
$?DD99:	LD	A,(78H)		;OPREG$
	OUT	(84H),A		;disable video RAM
	POP	BC
	POP	DE
	POP	HL
	POP	AF

	LD	SP,$-$		;restore SP
$DDISA_STK EQU	$-2
	ELSE	;!KIDO

	PUSH	AF
	PUSH	DE
	LD	C,A
	$SVC	@DSP
	LD	A,C
	POP	DE
	POP	AF

	ENDIF	;!KIDO

	RET


;-----	Display message @ HL
DISM:	;LD	A,0BFH
	;CALL	DDISA
$?DISM:	LD	A,(HL)
	INC	HL
	OR	A
	RET	Z
	CP	3
	RET	Z
	CALL	DDISA
	CP	0DH
	RET	Z
	JR	$?DISM

;================================================
	IF	TER
;================================================

;-----	Clear Screen
CLS:
	LD	A,1CH
	CALL	DDISA
	LD	A,1FH
	CALL	DDISA
	RET

;-----	Display A in dec
DISDA:	PUSH	AF
	PUSH	BC
	NOP			;skip reloc
	LD	BC,100<8+'0'-1
	CALL	BDISDA1
	NOP			;skip reloc
	LD	BC,10<8+'0'-1
	CALL	BDISDA1
	NOP			;skip reloc
	LD	BC,1<8+'0'-1
	CALL	BDISDA1
	POP	BC
	POP	AF
	RET

BDISDA1	SUB	B
	INC	C
	JR	NC,BDISDA1
	ADD	A,B
	PUSH	AF
	LD	A,C
	CALL	DDISA
	POP	AF
	RET

;-----	Display A in hex
DHEXA:	PUSH	AF
	SRL	A
	SRL	A
	SRL	A
	SRL	A
	CALL	ADJHA
	POP	AF
	AND	0FH
ADJHA:	ADD	A,30H
	CP	3AH
	JR	C,DCHRA
	ADD	A,7

;-----	Put char to disp buffer @ IY
DCHRA:	JP	DDISA

;-----	Put 4 bytes @ HL to disp buffer @ IY
DHEX4:
	PUSH	AF
	LD	A,'['
	CALL	DDISA
	PUSH	BC
	LD	BC,4
	ADD	HL,BC
	LD	B,C
DHEX41:	DEC	HL
	LD	A,(HL)
	CALL	DHEXA
	DJNZ	DHEX41
	POP	BC
	LD	A,']'
	CALL	DDISA
	POP	AF
	RET


;-----	Display trace message @ PC
DISTRC:	EX	(SP),HL
	INC	HL
	JR	$DISPC

;-----	Display message @ PC
DISMPC:	EX	(SP),HL
$DISPC:	PUSH	AF
	CALL	DISM
	POP	AF
	EX	(SP),HL
	RET

;-----	Poll keyboard - 'Q' to exit
GETKEY:
	$SVC	@KBD
	CP	'S'-40H
	JR	Z,WAITKI
	OR	A
VRET:	RET

;-----	Break Vector
VBREAK:	JP	VRET

;-----	Abort Vector
VABORT:	JP	VRET

;-----	Wait 1 character from keyboard
WAITKI	$SVC	@KEY
	CP	80H		;Break
	JR	Z,VBREAK
	CP	3		;Ctrl-C = abort
	JR	Z,VABORT
	OR	A
	RET

;-----	Exit to DOS
DOSEXIT:
	$SVC	@EXIT

;================================================
	ENDIF
;================================================

;-----	Store 32b from (HL) to (DE)
STO32:	PUSH	HL
	PUSH	DE
	JR	BMV321

;-----	Move 32b from (DE) to (HL)
;	(HL) := (DE)
;
MOV32:	PUSH	HL
	PUSH	DE
	EX	DE,HL
BMV321:	PUSH	BC
	LD	BC,4
	LDIR
	POP	BC
	POP	DE
	POP	HL
	RET

;
;
;-----	Add 32 @ HL by 32 @ DE
;	IN	HL = addend ptr (32b)
;		DE = adder ptr (32b)
;	USED	A
ADD32:	PUSH	BC
	PUSH	DE
	PUSH	HL
	LD	B,4
	OR	A
BA320:	LD	A,(HL)
	EX	DE,HL
	ADC	A,(HL)
	INC	HL
	EX	DE,HL
	LD	(HL),A
	INC	HL
	DJNZ	BA320
	POP	HL
	POP	DE
	POP	BC
	RET
;
;
;-----	Decrement 32 @ HL
;	IN	HL = dword ptr (32b)
;	USED	A
	IF	1
DEC32:	PUSH	BC
	PUSH	DE
	PUSH	HL
	LD	BC,-1
	LD	A,2
	OR	A
BD320:	LD	E,(HL)
	INC	HL
	LD	D,(HL)
	DEC	HL
	EX	DE,HL
	ADC	HL,BC
	EX	DE,HL
	LD	(HL),E
	INC	HL
	LD	(HL),D
	INC	HL
	DEC	A
	JR	NZ,BD320
	POP	HL
	POP	DE
	POP	BC
	RET
	ENDIF
;
;
;-----	Increment 32 @ HL
;	IN	HL = dword ptr (32b)
;	USED	A
	IF	1
INC32:	PUSH	BC
	PUSH	DE
	PUSH	HL
	LD	BC,1
	LD	A,2
	OR	A
BI320:	LD	E,(HL)
	INC	HL
	LD	D,(HL)
	DEC	HL
	EX	DE,HL
	ADC	HL,BC
	EX	DE,HL
	LD	(HL),E
	INC	HL
	LD	(HL),D
	INC	HL
	DEC	C
	DEC	A
	JR	NZ,BI320
	POP	HL
	POP	DE
	POP	BC
	RET
	ENDIF
;
;
;-----	Sub 32 @ HL by 32 @ DE
;	IN	HL = subtrahend ptr (32b)
;		DE = subtractor ptr (32b)
;	USED	A
	IF	1
SUB32:	PUSH	BC
	PUSH	DE
	PUSH	HL
	LD	B,4
	OR	A
BS320:	LD	A,(HL)
	EX	DE,HL
	SBC	A,(HL)
	INC	HL
	EX	DE,HL
	LD	(HL),A
	INC	HL
	DJNZ	BS320
	POP	HL
	POP	DE
	POP	BC
	RET
	ENDIF
;
;
;-----	Sub 32 @ HL by 8
;	IN	HL = subtrahend ptr (32b)
;		A = subtractor (8b)
;	USED	A
	IF	0
SUB328:	PUSH	BC
	PUSH	HL
	LD	B,A
	LD	A,(HL)
	SUB	B
	LD	(HL),A
	INC	HL
	NOP			;skip reloc
	LD	BC,0300H
BS3280:	LD	A,(HL)
	SBC	A,C
	LD	(HL),A
	INC	HL
	DJNZ	BS3280
	POP	HL
	POP	BC
	RET
	ENDIF
;
;
;-----	Multiply 32 @ HL by 8
;	IN	HL = multiplicand ptr (32b)
;		A = multiplicator (8b)
;	USED	A
MUL328:	PUSH	BC
	PUSH	DE
	PUSH	HL
	LD	DE,0
	LD	B,D
	LD	C,E
	LD	H,A
	LD	L,8
BM3280:	OR	A
	RL	E
	RL	D
	RL	C
	RL	B
	RL	H
	JR	NC,BM3281
	EX	(SP),HL
	LD	A,(HL)
	ADD	A,E
	LD	E,A
	INC	HL
	LD	A,(HL)
	ADC	A,D
	LD	D,A
	INC	HL
	LD	A,(HL)
	ADC	A,C
	LD	C,A
	INC	HL
	LD	A,(HL)
	ADC	A,B
	LD	B,A
	DEC	HL
	DEC	HL
	DEC	HL
	EX	(SP),HL
BM3281:	DEC	L
	JR	NZ,BM3280
	POP	HL
	LD	(HL),E
	INC	HL
	LD	(HL),D
	INC	HL
	LD	(HL),C
	INC	HL
	LD	(HL),B
	DEC	HL
	DEC	HL
	DEC	HL
	POP	DE
	POP	BC
	RET


;-----	Left shift 32b @HL by A
;	IN;	HL = shiftand
;		A = shiftor
	IF	1
SHL32:
BSL320:	OR	A	;also clr CF
	RET	Z
	RL	(HL)
	INC	HL
	RL	(HL)
	INC	HL
	RL	(HL)
	INC	HL
	RL	(HL)
	DEC	HL
	DEC	HL
	DEC	HL
	DEC	A
	JR	BSL320
	ENDIF

;-----	Right shift 32b @HL by A
;	IN;	HL = shiftand
;		A = shiftor
	IF	1
SHR32:
BSR320:	OR	A	;also clr CF
	RET	Z
	INC	HL
	INC	HL
	INC	HL
	RR	(HL)
	DEC	HL
	RR	(HL)
	DEC	HL
	RR	(HL)
	DEC	HL
	RR	(HL)
	DEC	A
	JR	BSR320
	ENDIF

;-----	Zero 32b @ HL
ZERO32:
	XOR	A
	LD	(HL),A
	INC	HL
	LD	(HL),A
	INC	HL
	LD	(HL),A
	INC	HL
	LD	(HL),A
	DEC	HL
	DEC	HL
	DEC	HL
	RET


;-----	Test if null 32b @ HL
;	IN	HL = dword ptr
;	OUT	A == 0 if null
;		Z == 1 if null
	IF	0
ISNUL32:
	LD	A,(HL)
	INC	HL
	OR	(HL)
	INC	HL
	OR	(HL)
	INC	HL
	OR	(HL)
	DEC	HL
	DEC	HL
	DEC	HL
	RET
	ENDIF

;-----	Compare 32b @ HL with 32b @ DE
;	IN	HL = dword ptr 1
;		DE = dword ptr 2
;	OUT	A == 0 if (HL)==(DE)
;		Z == (HL)==(DE)
;		CF == (HL)<(DE)
	IF	1
CMP32:
	PUSH	HL
	PUSH	DE
	PUSH	BC
	EX	DE,HL
	INC	HL
	INC	DE
	INC	HL
	INC	DE
	INC	HL
	INC	DE
	LD	B,4
BC320:	LD	A,(DE)
	CP	(HL)
	JR	NZ,BC32X
	DEC	HL
	DEC	DE
	DJNZ	BC320
BC32X:	POP	BC
	POP	DE
	POP	HL
	RET
	ENDIF

;-----	Compare byte arrays
;	IN:	HL = array1
;		DE = array2
;		BC = bytes count
;	OUT:	Z = array1 == array2
;		C = array1 < array2
;	USED:	A,BC
	IF	1
MEMCMP:	PUSH	HL
	PUSH	DE
	EX	DE,HL
BMCMP1:	LD	A,(DE)
	SUB	(HL)
	JR	NZ,BMCMPX
	INC	DE
	INC	HL
	DEC	BC
	LD	A,B
	OR	C
	JR	NZ,BMCMP1
BMCMPX:	POP	DE
	POP	HL
	RET
	ENDIF

;-----	Copy byte array
;	IN:	HL = source
;		DE = dest
;		BC = bytes count
;	USED:	BC
	IF	0
MEMCPY:	PUSH	HL
	PUSH	DE
	LDIR
	POP	DE
	POP	HL
	RET
	ENDIF

;-----	CP HL,DE
CPHLDE:	LD	A,H
	CP	D
	RET	NZ
	LD	A,L
	CP	E
	RET

SYS_END:
	$MSG	/HxCSYS

	IF	SEG
	DSEG
	ENDIF

CSEG_SYS 	MACRO
	DW	SYS_BEGIN,SYS_END
	ENDM

	END
