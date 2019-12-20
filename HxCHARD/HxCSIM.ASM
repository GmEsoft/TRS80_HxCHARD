*MOD

	IF	SEG
	CSEG
	ENDIF

	IF	SIM

SIM_BEGIN:

;-----	Open image file
IMOPEN:
;	$BREAK	IMOPEN
	PUSH	BC
	PUSH	DE
	PUSH	HL
	LD	HL,(XHIMFILE)
	LD	A,H
	OR	L
	LD	A,0		;no error exit
	JR	NZ,BIMOPENX	;exit if image already open
	LD	HL,IMFILE
	LD	BC,0
	LD	DE,0
	LD	A,0FFH		;ret code if simOPEN not supported
	DB	0EDH,30H	;simOPEN
	OR	A
	JR	Z,BIMOPEN1	;jump if error in simOPEN
	LD	HL,IMFILE
	CALL	DISM
	LD	HL,MNOIMFILE
	CALL	DISM
	JR	BIMOPENX
BIMOPEN1:
	LD	(XHIMFILE),DE	;save handle
	XOR	A		;no error
BIMOPENX:
	OR	A
	POP	HL
	POP	DE
	POP	BC
	RET


;-----	Close image file
IMCLOSE:
;	$BREAK
	PUSH	DE
	LD	DE,(XHIMFILE)
	LD	A,D
	OR	E
	JR	Z,BIMCLOSX	;exit if image closed or not open
	LD	A,0FFH		;ret code if simCLOSE not supported
	DB	0EDH,31H	;simCLOSE
	OR	A
	JR	NZ,BIMCLOSX	;jump if error in simCLOSE
	LD	E,A		;check handle != 0
	LD	D,A
	LD	(XHIMFILE),DE	;save handle
	XOR	A		;no error
BIMCLOSX:
	OR	A
	POP	DE
	RET


;-----	Sub to seek LBA in image
IMSEEK:
	LD	DE,(XHIMFILE)
	LD	A,D
	OR	E
	LD	A,0FFH		;error code
	JR	Z,BIMREADX	;exit if image closed or not open
	PUSH	DE
	EX	DE,HL		;LBA to DE
	LD	HL,XIMOFFS	;offset = LBA << 9
	CALL	MOV32
	LD	A,9
	CALL	SHL32
	POP	DE
	LD	A,0FFH
	LD	C,0
	DB	0EDH,34H	;seek
	OR	A
	JR	NZ,BIMREADX	;error
	RET

;-----	Read LBA sector from image file
;	IN	DE = buffer ptr
;		(HL) = LBA
IMREAD:
;	$BREAK
	PUSH	BC
	PUSH	HL
	PUSH	DE

	CALL	IMSEEK

	POP	HL		;buffer
	PUSH	HL
	LD	BC,200H		;length
	DB	0EDH,32H	;simREAD
BIMREADX:
	OR	A
	POP	DE
	POP	HL
	POP	BC
	RET

;-----	Write LBA sector from image file
;	IN	DE = buffer ptr
;		(HL) = LBA
IMWRITE:
	$BREAK	IMWRITE
	PUSH	BC
	PUSH	HL
	PUSH	DE

	CALL	IMSEEK

	POP	HL		;buffer
	PUSH	HL
	LD	BC,200H		;length
	DB	0EDH,33H	;simWRITE
BIMWRITEX:
	OR	A
	POP	DE
	POP	HL
	POP	BC
	RET

SIM_END:

;-----	Image file data
IMFILE:	DB	'G:\1GB.VHD',0

MNOIMFILE:
	DB	': file not found',0DH

XHIMFILE:
	DW	0
XIMOFFS:
	DS	4

	ENDIF


CSEG_SIM	MACRO
	IF	SIM
	DW	SIM_BEGIN,SIM_END
	ENDIF
	ENDM

	END

