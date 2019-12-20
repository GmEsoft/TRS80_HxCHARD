BRK	DEFL	0		;Enable $BREAK
DBG	DEFL	0		;debug
TRC	DEFL	0		;trace
NOREL	DEFL	0		;don't relocate code (debug)
ASSERT	DEFL	0		;enable assertions
EIBRK	DEFL	0		;enable break on EI
SEG	DEFL	0		;enable relative segments

	IF	@@1
MODEL	EQU	@@1
	ELSE
MODEL	EQU	3
	ENDIF

	IFEQ	MODEL,3
SVCS	EQU	0		;using SVCs		  [0]
FREHD	EQU	1		;support for multiple partitions
				;(FreHD image support)	  [1]
BANKS	EQU	0		;support memory banks	  [0]
NOCLK	EQU	0		;disable clock display	  [0]
CACHE	EQU	0		;enable LBA sectors cache [0]
MVOUT	EQU	1		;move code out resid part [1]
LOGO	EQU	1		;enable hxc2001 logo	  [1]
	ENDIF

	IFEQ	MODEL,4
SVCS	EQU	1		;using SVCs		  [1]
FREHD	EQU	1		;support for multiple partitions
				;(FreHD image support)	  [1]
BANKS	EQU	1		;support memory banks	  [1]
NOCLK	EQU	1		;disable clock display	  [1]
CACHE	EQU	1		;enable LBA sectors cache [1]
MVOUT	EQU	1		;move code out resid part [1]
LOGO	EQU	1		;enable hxc2001 logo	  [1]
	ENDIF

LRU	EQU	1
JPBEG	EQU	0		;JR BEGIN0/JP BEGIN vs. JR BEGIN

$VER	MACRO
	IFEQ	MODEL,4
	DB	'6.'		;Model 4 prefix
	ENDIF
	IFEQ	MODEL,3
	DB	'5.'		;Model III prefix
	ENDIF
	DB	'0.0b3'		;Version number
	ENDM

;*=*=*
;	HXCHARD/DCT
;	Emulate hard disk in a DOS file in HxC Floppy Emulator
;
;	Copyright (c) 2016, Michel Bernard
;
;	Created 13-Feb-16 (pre-alpha)
;
;	Based on XTRSHARD/DCT and EHARD/DCT
;	Emulate hard disk in a DOS file under TRS80
;
;	Copyright (c) 1998, Timothy Mann
;
;	This software may be copied, modified, and used for any
;	purpose without fee, provided that (1) the above copyright
;	notice is retained, and (2) modified versions are clearly
;	marked as having been modified, with the modifier's name and
;	the date included.
;
;	Created 1-10-98
;		modified on Tue Sep 29 13:27:01 PDT 1998 by mann
;	Last modified on 05/19/99 by D. Keil
;	(change name, messages & offset to 4 bytes)
;
;	TODO:
;	- add param Sec/Cyl (override vhd setting)
;	- enable driver even when host drive not mounted
;	- support fragmented images
;	- LDOS 5 version
;	DONE:
;	- load in extended memory (bank 2 or 3)
;	- disable SYSGEN (cfr MEMDISK)
;	- smartdrv (sector caching)
;
;*=*=*

TER	EQU	BRK+TRC+ASSERT

$MSG	MACRO	#MSG
	IF	BRK
	DB	'<#MSG>'
	ENDIF
	ENDM

$BREAK	MACRO	#CMT
	IF	BRK
	IF	%%		;num of macro params
	CALL	DISTRC
	HALT
	DB	'<#CMT>'
;	REPT	%#CMT+3
;	DB	24
;	ENDM
	DB	0
	ENDIF
	DB	0EDH,0F5H	;$BREAK
	ENDIF
	ENDM

$TRACENL MACRO
	IF	TRC
	CALL	DISMPC
	HALT
	DB	0DH
	DB	0
	DB	0EDH,0F5H	;$BREAK
	ENDIF
	ENDM

$TRACE	MACRO	#CMT
	IF	TRC
	IF	%%		;num of macro params
	CALL	DISTRC
	HALT
	DB	'<#CMT>'
	DB	0
	ENDIF
	ENDIF
	ENDM

$TRACE4 MACRO
	IF	TRC
	CALL	DHEX4
	ENDIF
	ENDM

$$BREAK	MACRO
;	IFEQ	BRK,0
	DB	0EDH,0F5H	;$BREAK
;	ENDIF
	ENDM

$ALIGN	MACRO	#N
	IF	DBG
$?0	EQU	$
$?1	EQU	$?0-ORIGIN
$?2	EQU	$?1-1<-#N+1<#N
	ORG	ORIGIN+$?2
	ENDIF
	ENDM

$SVC	MACRO	#NUM
	IF	SVCS
	LD	A,#NUM
	RST	28H
	ELSE
	LD	A,C
	CALL	#NUM%&3		;#NUM + "3"
	ENDIF
	ENDM

$MODEL4	MACRO
	IF	MODEL.NE.4
	ERR	Model 4 Only
	ENDIF
	ENDM

$DI	MACRO
	DI
	IF	EIBRK
	DB	0EDH,0F8H	;$EIBON = Enable Break on EI
	ENDIF
	ENDM

$EI	MACRO
	IF	EIBRK
	DB	0EDH,0F9H	;$EIBOFF = Disable Break on EI
	ENDIF
	EI
	ENDM

; DOS temp buffer
BUFFER$	EQU	2300H
; Number of drives to allow
NDRIVE	EQU	8		;!!TODO currently only 1 out of 8
; ASCII chars
LF	EQU	10
CR	EQU	13
ETX	EQU	3

	IF	SVCS
; Model 4 SVC numbers
@EXIT	EQU	16H	; return to LS-DOS
@KBD	EQU	08H	; scan keyboard
@KEY	EQU	01H	; wait for key press
@DSP	EQU	02H	; display character
@VDCTL	EQU	0FH	; control video display
@HIGH	EQU	100
@DSPLY	EQU	10
@FLAGS	EQU	101
@LOGOT	EQU	12
@ERROR	EQU	26
@GTDCT	EQU	81
@GTDCB	EQU	82
@GTMOD	EQU	83
@DIV8	EQU	93
@MUL16	EQU	91
@DECHEX	EQU	96
@KEYIN	EQU	9
@BANK	EQU	66H
	ELSE
; Model III hard addresses
@EXIT3	EQU	402DH
@KBD3	EQU	002BH
@KEY3	EQU	0049H
M3FLAG$ EQU     0125H   	; 'I' in ROM on Model III
@LOGOT3 EQU     428AH
@DSPLY3 EQU     4467H
HIGH$3  EQU     4411H
CFLAG$3 EQU     4758H
@ICNFG3 EQU     421DH
@MULT3  EQU     444EH
@DIVEA3 EQU     4B7AH
@KEYIN3 EQU     0040H
@GTDCT3	EQU	478FH		;=GETDCT
@DSP3	EQU	0033H
@ERROR3	EQU	4409H
HIGH$3  EQU     4411H
CFLAG$3 EQU     4758H
	ENDIF

; Constants for emt_opendisk
;EO_RDONLY	EQU	   00O
;EO_WRONLY	EQU	   01O
;EO_RDWR	EQU	   02O
;EO_CREAT	EQU	 0100O
;EO_EXCL	EQU	 0200O
;EO_TRUNC	EQU	01000O
;EO_APPEND	EQU	02000O
;*=*=*
;	Set origin to be safe on both LDOS 5 and 6
;*=*=*
	IFEQ	MODEL,3
	ORG	6000H
	ENDIF
	IFEQ	MODEL,4
	ORG	5000H
	ENDIF
ORIGIN:
;*=*=*
;	Relocator for disk driver
;*=*=*
INSTAL: $BREAK	INSTAL
	LD	(DCT),DE	;Save DCT address
	IFEQ	MODEL,4
	LD	A,'4'		;Modify filename HARD4-n
	ELSE
	LD	A,'3'		;Modify filename HARD3-n
	ENDIF
	LD	(HMOD),A
	LD	HL,HELLO_
	$SVC	@DSPLY		;Display hello
;*=*=*
;	Check if entry from SYSTEM command.
;*=*=*
;	$$BREAK
	$SVC	@FLAGS		;Get flags pointer into IY

	IF	NOCLK
	$MODEL4			;assert model 4 version
	LD	A,(IY+'V'-'A')
	LD	(XVFLAG),A
	RES	4,(IY+'V'-'A')	;disable clock display
	SET	6,(IY+'V'-'A')	;disable cursor blinking
	ENDIF

	LD	A,(IY+'C'-'A')	;Get CFLAG$
	BIT	3,A		;System request?
	JP	Z,VIASET
	LD	DE,(DCT)
	LD	A,D		;DRIVE= must be specified
	OR	E
	JP	Z,NEEDDR
;*=*=*
;	Ask which unit number
;*=*=*
ASKU4:	LD	HL,UNIT_	;Ask which unit number
	$SVC	@DSPLY
	LD	HL,UNIT
	LD	BC,100H
	$SVC	@KEYIN
	JP	C,HITBRK
	JP	NZ,HITBRK
	LD	A,(UNIT)
	CP	'0'
	JR	C,ASKU4
	CP	'0'+NDRIVE
	JR	NC,ASKU4
;*=*=*
;	Ask which starting cyl number
;*=*=*
	IF	FREHD
	LD	HL,STACYL_
	$SVC	@DSPLY
	LD	HL,ERRBUF
	LD	BC,400H
	$SVC	@KEYIN
	JP	C,HITBRK
	JP	NZ,HITBRK
	$SVC	@DECHEX		;parse decimal number
	LD	HL,STACYL
	LD	(HL),C
	INC	HL
	LD	(HL),B
	ENDIF
;*=*=*
;	Ask cyl count
;*=*=*
	IF	FREHD
	LD	HL,NCYLS_
	$SVC	@DSPLY
	LD	HL,ERRBUF
	LD	BC,400H
	$SVC	@KEYIN
	JP	C,HITBRK
	JP	NZ,HITBRK
	$SVC	@DECHEX		;parse decimal number
	LD	HL,NCYLS
	LD	(HL),C
	INC	HL
	LD	(HL),B
	ENDIF
;*=*=*
;	Ask which host drive number
;*=*=*
ASKH4:	LD	HL,HOST_	;Ask which unit number
	$SVC	@DSPLY
	LD	HL,HOST
	LD	BC,100H
	$SVC	@KEYIN
	JP	C,HITBRK
	JP	NZ,HITBRK
	LD	A,(HOST)
	CP	'4'+1
	JR	NC,ASKH4
	SUB	'1'
	JR	C,ASKH4
	LD	HL,HOSTS
	LD	B,0
	LD	C,A
	ADD	HL,BC
	LD	A,(HL)
	LD	(XPHOST),A
;*=*=*
;	Ask which memory bank
;*=*=*
	IF	BANKS
;	$$BREAK
	LD	BC,0000H	; Init to REQ, Bank 0
CNTBNK:	INC	C		; Inc bank to request
	LD	A,C		; test if bank 10 reached
	CP	0AH		;
	JR	Z,$CBNK1	; exit test loop if yes
	PUSH	BC		; save bank num
	$SVC	@BANK		; Request bank
	POP	BC		; Get curr bank back
	JR	Z,CNTBNK	; Go look for next one
$CBNK1:	PUSH	BC		; Save total banks
	LD	C,B		; Go back to bank 0
	$SVC	@BANK
	POP	BC		; Get total back
	LD	A,'0'
	ADD	A,C
	LD	(BKMAX1),A
	DEC	A
	LD	(BKMAX_),A
ASKBNK:	LD	HL,BANK_	;Ask which unit number
	$SVC	@DSPLY
	LD	HL,BANK
	LD	BC,100H
	$SVC	@KEYIN
	JP	C,HITBRK
	JP	NZ,HITBRK
	LD	A,(BANK)
	CP	'7'+1
BKMAX1	EQU	$-1
	JR	NC,ASKBNK
;	$$BREAK
	SUB	'0'
	JR	C,ASKBNK
	LD	(XBANK),A
	ENDIF
;
;*=*=*
;	Check if driver already loaded
;*=*=*

	IF	LOGO
	CALL	LOGOON		;HxC2001 logo
	ENDIF

	LD	DE,MODNAM
	$SVC	@GTMOD
	$BREAK	@GTMOD_END
	PUSH	HL
	LD	DE,LENGTH-1
	ADD	HL,DE
	LD	(NEWEND),HL	;restore NEWEND for relocation
	POP	HL
	JP	Z,SETDCT1	;Already loaded, skip loading
				;but RELOCATE !!

	IF	BANKS
;	$$BREAK
	LD	A,(XBANK)
	OR	A
	JR	Z,$?BNKOK
	LD	C,A		;bank #
	LD	B,2
	$SVC	@BANK		;test bank
	JP	NZ,NOBANK	;error exit
$?BNKOK:
	ENDIF

	IFEQ	MODEL,4
;*=*=*
;	Obtain low memory driver pointer.	Bizarre API here!
;*=*=*
	$MODEL4			;assert model 4 version
	LD	E,'K'		;Locate pointer to *KI DCB
	LD	D,'I'		;	via @GTDCB SVC
	$SVC	@GTDCB		;!!EI!!
	JP	NZ,CURDL	;No error unless KI clobbered!
	DEC	HL		;Decrement to driver pointer
	LD	D,(HL)		;P/u hi-order of pointer,
	DEC	HL		;	decrement to and p/u
	LD	E,(HL)		;	lo-order of pointer
;*=*=*
;	Check if driver will fit into [(LCPTR), X'12FF']
;*=*=*
	PUSH	HL		;Save address of pointer
	LD	HL,LENGTH	;New pointer will be
	ADD	HL,DE		;	pointer + LENGTH
	LD	D,H		;Save a copy in DE
	LD	E,L
	LD	BC,1301H	;If > 1300H, driver won't fit
	SUB	A		;Reset carry flag
	SBC	HL,BC
	POP	HL		;Get back address of pointer
	JR	NC,USEHI	;Go if driver won't fit
	LD	(HL),E		;Store new value of pointer
	INC	HL
	LD	(HL),D
	DEC	DE		;Last byte of driver goes here
	LD	(NEWEND),DE
	JR	DORELO

	ENDIF			;MODEL.EQ.4
;*=*=*
;	Put in high memory instead.
;*=*=*
USEHI:
	IF	BANKS
	LD	A,(XBANK)
	OR	A
	JP	NZ,NOLMEM
	ENDIF

	LD	HL,0		;Get current HIGH$
	LD	B,L
	$SVC	@HIGH
	JP	NZ,NOMEM
	LD	(NEWEND),HL	;Last byte of driver goes here
	LD	DE,LENGTH
	SUB	A		;Reset carry flag
	SBC	HL,DE		;Compute new HIGH$
	$SVC	@HIGH		;Set new HIGH$ into the system
;*=*=*
;	Put extension in high memory
;	Relocate internal references in driver.
;	HL = address for last byte of driver.
;*=*=*
DORELO:
	IF	BANKS
;	$$BREAK
	LD	HL,0FFFFH
	LD	(XNEWEND),HL	;Last byte of driver goes here
	LD	A,(XBANK)
	OR	A
	JR	Z,DORELO0
	LD	C,A
	LD	B,3
	$SVC	@BANK		;reserve bank
;	$$BREAK
	$DI
	$BREAK	SELBK
	CALL	SELBK		;map bank
	JR	DORELO1
DORELO0:
	ENDIF

	LD	HL,0		;Get current HIGH$
	LD	B,L
	$SVC	@HIGH
	JP	NZ,NOMEM
	LD	(XNEWEND),HL	;Last byte of driver goes here
	LD	DE,XLENGTH
	SUB	A		;Reset carry flag
	SBC	HL,DE		;Compute new HIGH$
	$SVC	@HIGH		;Set new HIGH$ into the system

	IF	BANKS
DORELO1:
	ENDIF

	CALL	SETCPU		;Detect HD64180 (XLR8er)
	CALL	DVRINI		;Final driver init before move
	CALL	RELONEW
	JP	RELOEND

RELONEW:
	$BREAK	RELONEW
	LD	IX,ERRBUF	;relocate base driver
	LD	DE,ENTRY
	LD	(IX+0),E
	LD	(IX+1),D
	LD	DE,DVREND
	LD	(IX+2),E
	LD	(IX+3),D
	LD	DE,(NEWEND)
	LD	(IX+4),E
	LD	(IX+5),D
	LD	DE,SEGLIST
	LD	(IX+6),E
	LD	(IX+7),D

	CALL	AUTORELO

	LD	HL,(RX00)	;DOS header
	ADD	HL,BC		;BC = offset
	LD	(RX00),HL

	IF	JPBEG
	LD	HL,(RX01)	;DOS header
	ADD	HL,BC		;BC = offset
	LD	(RX01),HL
	ENDIF

	IF	FREHD
	LD	HL,(RXPART)	;DOS header
	ADD	HL,BC		;BC = offset
	LD	(RXPART),HL
	LD	HL,(RXUNITS)	;DOS header
	ADD	HL,BC		;BC = offset
	LD	(RXUNITS),HL
	LD	HL,(RXFD)	;DOS header
	ADD	HL,BC		;BC = offset
	LD	(RXFD),HL
	ENDIF

	IF	BANKS
	LD	HL,(RXPDCTS)	;DOS header
	ADD	HL,BC		;BC = offset
	LD	(RXPDCTS),HL
	ENDIF

	LD	IX,ERRBUF	;relocate HxC extension
	LD	DE,XENTRY
	LD	(IX+0),E
	LD	(IX+1),D
	LD	DE,XDVREND
	LD	(IX+2),E
	LD	(IX+3),D
	LD	DE,(XNEWEND)
	LD	(IX+4),E
	LD	(IX+5),D
	LD	DE,SEGLIST
	LD	(IX+6),E
	LD	(IX+7),D

	CALL	AUTORELO

	LD	HL,(XRX00)	;DOS header
	ADD	HL,BC		;BC = offset
	LD	(XRX00),HL

	RET

;*=*=*
;	Inhibit SYSGEN
;*=*=*
RELOEND:
	$SVC	@FLAGS		;Get flags pointer into IY

	IF	NOCLK
	LD	(PFLAGS),IY	;Save FLAGS pointer in driver
	ENDIF

	SET	5,(IY+'C'-'A')	;inhibit SYSGEN

;*=*=*
;	Move driver into low or high memory.
;*=*=*
MOVE:
	$BREAK
	LD	DE,(XNEWEND)	;Destination address
	LD	HL,XDVREND	;Last byte of module
	LD	BC,XLENGTH	;Length of filter
	LDDR
	LD	DE,(NEWEND)	;Destination address
	LD	HL,DVREND	;Last byte of module
	LD	BC,LENGTH	;Length of filter
	LDDR
	EX	DE,HL
	INC	HL		;Bump to driver entry
	$BREAK
	JR	SETDCT
;*=*=*
;	Setup DCT (iy+5 to iy+9 are reset by CKOPEN if successful)
;*=*=*
SETDCT1:			;enter here when driver already loaded
	PUSH	HL
	$BREAK	DVRLOADED
	LD	HL,LOADED_	;'Driver already loaded'
;	$SVC	@DSPLY
	CALL	LOGMSG		;log message
	IF	BANKS
;	$$BREAK
	$DI
	$BREAK	SELBK
	CALL	SELBK		;select bank
	LD	HL,0FFFFH
	LD	A,(XBANK)
	OR	A
	JR	NZ,SETDCT11
	ENDIF
	LD	DE,XMODNAM	;find driver extension
	$EI
	$SVC	@GTMOD		;!!EI!!
	$DI
	$BREAK	@XGTMOD_END
	LD	DE,XLENGTH-1
	ADD	HL,DE
SETDCT11:
	LD	(XNEWEND),HL	;restore XNEWEND for relocation

	CALL	RELONEW		;do address relocation without moving dvr
	POP	HL
SETDCT:
	LD	IY,(DCT)
	LD	(IY+1),L	;Driver address
	LD	(IY+2),H
	LD	(IY+3),00001100B;Flags: rigid, fixed, step rate 0

	IF	FREHD

	$BREAK	SETDCT
	LD	HL,PART
RXPART	EQU	$-2
	LD	A,(HL)
	INC	A
	LD	(HL),A		;TODO: assert A<8
	DEC	A
	PUSH	AF
	LD	HL,UNITS
RXUNITS	EQU	$-2
	LD	D,0
	LD	E,A
	ADD	HL,DE
	LD	A,(UNIT)
	AND	0FH
	LD	(HL),A
	POP	AF
	PUSH	AF
	LD	HL,FD+2
RXFD	EQU	$-2
	ADD	A,A
	ADD	A,A
	LD	E,A
	ADD	HL,DE
	LD	DE,(STACYL)
	LD	(HL),E
	INC	HL
	LD	(HL),D
	POP	AF

	ELSE

	LD	A,(UNIT)
	AND	0FH

	ENDIF

	OR	00010000B	;Flags: alien (=no index pulses), unit#
	LD	(IY+4),A
	LD	(IY+5),0	;LDOS undefined; we use as sec/cyl (0=256).

	IF	FREHD
	LD	A,(NCYLS)
	DEC	A
	LD	(IY+6),A	;high cylinder number
	ELSE
	LD	(IY+6),0FFH	;high cylinder number = undef
	ENDIF

	LD	(IY+7),11111111B;high head # (111), high sec/trak (11111)
	LD	(IY+8),11111111B;high gran # (111), high sec/gran (11111)
	LD	(IY+9),0FFH	;Directory cylinder
;*=*=*
;	Open file now so user can get error if any, and so geometry
;	is established as early as possible.
;*=*=*
	IF	BANKS
	$BREAK	LOADDCTS
	CALL	LOADDCTS
	ENDIF
	CALL	CKOPEN		;IX = *FCB
	JR	NZ,UERROR

	PUSH	AF		;save status

;	$$BREAK
	LD	L,(IX+0)	;check if VHD file is fragmented
	LD	H,(IX+1)
	PUSH	HL
	POP	IX
	BIT	FCB$FRG,(IX+FCBFLGS)
	JR	Z,NOFRAG

	$BREAK	ISFRAG!
	LD	HL,FRAG_	;fragmented file warning
;	$SVC	@DSPLY
	CALL	LOGMSG		;log message

NOFRAG:
;	$$BREAK
	$BREAK	VERSION
	LD	HL,HXCFW_	;'HxC FW Ver:'
	CALL	LOGMSG
	CALL	HXC_VERSION	;Display HxC Firmware Version
	CALL	LOGMSG
	CALL	LOGLN		;New Line

	IF	BANKS
	$BREAK
	$BREAK	SELBK0
	CALL	SELBK0		;restore bank

	CALL	ENAINT		;re-enable interrupts

	ENDIF

	LD	HL,BEGIN
	LD	DE,BEGIN+1
	LD	BC,XDVREND-BEGIN-1
	LD	(HL),76H	;fill with HALT to find missing relocations
	LDIR
	$BREAK

	CALL	DISLOG		;display log

	IF	LOGO
	CALL	LOGOOFF		;remove logo
	ENDIF

	POP	AF		;restore status
	LD	HL,0		;Successful completion
	RET	Z		;Fall thru if error
;*=*=*
UERROR: LD	HL,ERRBUF	;DOS error
	LD	BC,256
	CALL	HXC_STRERROR
	DEFB	0DDH
CURDL:	LD	HL,CURDL_	;Other error
	DEFB	0DDH
NEEDDR: LD	HL,NEEDDR_
	DEFB	0DDH
VIASET: LD	HL,VIASET_
	DEFB	0DDH
NOMEM:	LD	HL,NOMEM_
	DEFB	0DDH
HITBRK: LD	HL,HITBRK_
	DEFB	0DDH
NOLS63:	LD	HL,NOLS63_
	IF	BANKS
	DEFB	0DDH
NOBANK:	LD	HL,NOBANK_
	DEFB	0DDH
NOLMEM:	LD	HL,NOLMEM_
	ENDIF
LOGOT:
	IF	BANKS
	CALL	SELBK0		;Select main memory bank 0

	CALL	ENAINT		;re-enable interrupts

	ENDIF

	CALL	DISLOG		;display log

	IF	LOGO
	CALL	LOGOOFF		;remove logo
	ENDIF

	$SVC	@LOGOT
	LD	HL,-1		;Unuccessful completion
	RET


;*=*=*
;	Re-enable interrupts and
;	Restore clock display flag (VFLAG$)
;*=*=*
	IF	BANKS
ENAINT:
;	$$BREAK
	IF	NOCLK
	$MODEL4			;assert model 4 version
	$SVC	@FLAGS		;Get flags pointer into IY
	LD	(IY+'V'-'A'),0	;restore clock display flag
XVFLAG	EQU	$-1
	ENDIF
	$EI
	RET
	ENDIF

;*=*=*
;	Detect CPU type: Z80 or HD64180 (XLR8er)
;*=*=*
SETCPU:	;$BREAK	SETCPU
	PUSH	HL
	LD	HL,0FFFFH
	DEFB	0EDH,6CH	;MLT HL on HD64180
	LD	A,H		;FF*FF=FE01
	ADD	A,L		;FE+01=FF
	INC	A		;Zero if MLT HL worked as expected
	LD	(X64180),A	;save CPU type
	JR	NZ,SETZ80	;jump if not
	LD	HL,HD64180_	;'HD64180'
	DEFB	0DDH		;IX prefix
SETZ80:	LD	HL,Z80_		;'Z80'
;	$SVC	@DSPLY
	CALL	LOGMSG		;log message
	LD	HL,CPU_		;' cpu detected'
;	$SVC	@DSPLY
	CALL	LOGMSG		;log message
	POP	HL
	RET
;
;*=*=*
;       Search for existing copy of driver.
;        Rough Model I/III emulation of Model 4 @GTMOD,
;        hardcoded with driver address.
;       Entry: DE holds driver name address
;       Exit Z: HL holds driver address
;            NZ: driver not found
;*=*=*
	IFEQ	MODEL,3
@GTMOD3:
;	$$BREAK
	LD	C,0FFH
	PUSH	DE
$?GM300	INC	C
	LD	A,(DE)
	INC	DE
	OR	A
	JR	NZ,$?GM300
	POP	DE
	LD	HL,(HIGH$3)
$?GM30	INC     HL
        LD      A,H
        OR      L
        JR      NZ,XGTM1
        DEC     A               ;not found
        RET
XGTM1:  LD      A,(HL)
        CP      18H             ;unconditional jr?
        RET     NZ              ;not a module header
        PUSH    HL              ;save start address
        PUSH	DE
        INC     HL              ;skip jr
        INC     HL              ;skip offset
        INC     HL              ;skip start address
        INC     HL
        LD      A,(HL)          ;compare name length
        CP      C
        JR      NZ,NEXTMD       ;different - skip
        LD      B,A             ;compare name
        INC     HL
XGTM2:  LD      A,(DE)
        CP      (HL)
        JR      NZ,NEXTMD       ;different - skip
        INC     DE
        INC     HL
        DJNZ    XGTM2
        POP	DE
        POP     HL              ;same - found
        RET
NEXTMD: POP	DE
	POP     HL              ;get back start of module
        INC     HL
        INC     HL
        LD      A,(HL)          ;pointer to last byte
        INC     HL
        LD      H,(HL)
        LD	L,A
        JR      $?GM30
        ENDIF

;*=*=*
;	Load HIGH$ pointer
;*=*=*
	IFEQ	MODEL,3
@HIGH3	LD	A,H
	OR	L
	JR	Z,$?H3GET
	LD	(HIGH$3),HL
$?H3GET	LD	HL,(HIGH$3)
	RET
	ENDIF

;*=*=*
;	Load FLAGS$ pointer (only for 'C' !!)
;*=*=*
	IFEQ	MODEL,3
@FLAGS3	LD	IY,CFLAG$3+'A'-'C'
	RET
	ENDIF

;*=*=*
;	Convert decimal string to 16 bits
;*=*=*
	IFEQ	MODEL,3
@DECHEX3 LD	BC,0
;	$$BREAK
$?DH3L	LD	A,(HL)
	CP	'9'+1
	RET	NC
	SUB	'0'
	RET	C
	PUSH	HL
	LD	H,B
	LD	L,C
	ADD	HL,HL
	ADD	HL,HL
	ADD	HL,BC
	ADD	HL,HL
	ADD	A,L
	LD	C,A
	ADC	A,H
	SUB	C
	LD	B,A
	POP	HL
	INC	HL
	JR	$?DH3L
	ENDIF

;
;*=*=*
;	Load DCT tables
;*=*=*
	IF	BANKS
LOADDCTS:
;	$$BREAK
	PUSH	IY
	LD	BC,800H		;B=8, C=0
	LD	HL,XPDCTS
RXPDCTS	EQU	$-2
$LDDCT0:
	$SVC	@GTDCT
	PUSH	IY
	POP	DE
	LD	(HL),E
	INC	HL
	LD	(HL),D
	INC	HL
	INC	C
	DJNZ	$LDDCT0
	POP	IY
	RET
	ENDIF


;*=*=*
;	Add message to log buffer
;*=*=*
LOGLN:	LD	HL,ENDLN

;*=*=*
;	Add message to log buffer
;*=*=*
LOGMSG:	$BREAK	LOGMSG
	PUSH	DE
	LD	DE,(LOGPTR)
$?LM01:	LD	A,(HL)
	INC	HL
	OR	A
	JR	Z,$?LM02
	CP	3
	JR	Z,$?LM02
	CP	0DH
	JR	NZ,$?LM03
	LD	A,0AH
$?LM03:	LD	(DE),A
	INC	DE
	JR	NZ,$?LM01
$?LM02:	LD	A,3
	LD	(DE),A
	LD	(LOGPTR),DE
	POP	DE
	RET

;*=*=*
;	Display logged messages
;*=*=*
DISLOG:	$BREAK
	$EI
	PUSH	HL
	LD	HL,LOGBUF
	PUSH	HL
	$SVC	@DSPLY
	POP	HL
	LD	(HL),3
	LD	(LOGPTR),HL
	POP	HL
	RET

;*=*=*
;	Auto Relocator
;*=*=*
*GET	AUTORELO

;*=*=*
;	HiRes Logo
;*=*=*
*GET	HXCLOGO

;*=*=*
;	Messages and globals
;*=*=*
		;0---+---1---+---2---+---3---+---4---+---5---+---6---+---7---+---8---+---9---+---
HELLO_: DEFB	'HxCHARD FAT32/LBA - Virtual HD driver for HxC Floppy Emulator',LF
	DEFB	'V:'
	$VER
	IF	FREHD
	DEFB	'+FreHD'
	ENDIF
	IF	BANKS
	DEFB	'+Banks'
	ENDIF
	IF	CACHE
	DEFB	'+Cache'
	ENDIF
	DEFB	' - '
	DATE
	DEFB	' '
	TIME
	IFEQ	MODEL,4
	DEFB	' - Copyright (c) 2017, GmEsoft',LF
	ELSE
	DEFB	' - (c) 2017, GmEsoft',LF
	ENDIF
	DEFB	'Based on XTRSHARD/DCT - Copyright (c) 1998, Timothy Mann'
ENDLN:	DEFB	CR
Z80_:	DEFB	'Z80',ETX
HD64180_:
	DEFB	'HD64180',ETX
CPU_:	DEFB	' CPU detected',CR
LOADED_: DEFB	'Driver already loaded',CR
HXCFW_:	DEFB	'HxC FW ver: ',ETX
;
;-----	Error messages
CURDL_: DEFB	'LS-DOS is curdled!',CR
NOMEM_: DEFB	'High memory is not available!',CR
VIASET_: DEFB	'Must install via SYSTEM (DRIVE=,DRIVER=)!',CR
NEEDDR_: DEFB	'DRIVE= must be specified!',CR
HITBRK_: DEFB	'Aborted!',CR
NOLS63_: DEFB	'No LS-DOS 6',CR
FRAG_:	DEFB	'WARNING: VHD file is fragmented; mounting read-only!',CR
	IF	BANKS
NOBANK_: DEFB	'Memory bank is not available!',CR
NOLMEM_: DEFB	'Can''t load resident part in low memory!',CR
	ENDIF
;
;-----	Prompts
UNIT_:	DEFB	'Enter unit number (0-','0'+NDRIVE-1,')............: ',ETX
HOST_:	DEFB	'Enter host drive I/O address (1-4).: ',ETX
	IF	FREHD
STACYL_: DEFB	'Enter starting cylinder............: ',ETX
NCYLS_: DEFB	'Enter cylinder count (0=from VHD)..: ',ETX
	ENDIF
	IF	BANKS
BANK_:	DEFB	'Enter memory bank (0-'
BKMAX_:	DEFB	'?)............: ',ETX
	ENDIF
;
;-----	Globals
	IF	BANKS
BANK:	DEFB	0
	ENDIF
HOSTS:	DEFB	1,2,4,8		;Phys drives table
LCPTR:	DEFW	0
NEWEND: DEFW	0
XNEWEND: DEFW	0
DCT:	DEFW	0
LOGPTR:	DEFW	LOGBUF		;pointer to log buffer
LOGBUF: DEFB	3		;log buffer
	DEFS	255
	IF	FREHD
STACYL:	DEFS	2
NCYLS:	DEFS	2
	ENDIF
UNIT:	DEFS	2
HOST:	DEFS	2
ERRBUF: DEFS	256
;=============================================================
;
; Driver - Based on skeletal driver from the Guide
;
;=============================================================
	IF	JPBEG
ENTRY:	JR	BEGIN0		;The driver starts with the
	ELSE
ENTRY:	JR	BEGIN		;The driver starts with the
	ENDIF
	DEFW	DVREND		;	DOS standard header
RX00	EQU	$-2
	DEFB	MODPTR-MODNAM	;Length of name

	IF	BANKS
MODNAM: DEFB	'HxC'		;Name for @GTMOD requests
	ELSE
	IF	FREHD
MODNAM: DEFB	'MHxCHD'	;Name for @GTMOD requests
	ELSE
MODNAM: DEFB	'HxCHD'		;Name for @GTMOD requests
	ENDIF
	ENDIF

MODPTR: DEFW	0		;These pointers are unused
	DEFW	0

	IF	JPBEG
BEGIN0:	JP	BEGIN
RX01	EQU	$-2
	ENDIF

	IF	FREHD
PART:	DEFW	0
UNITS	DEFS	NDRIVE
FD:	DEFS	NDRIVE*4	;Host file descriptors + starting cylinder
	ELSE
FD:	DEFS	NDRIVE*2	;Host file descriptors
	ENDIF

	IF	BANKS
XBUF:	DEFW	0		;sector buffer
XBANK:	DEFB	0		;memory bank
XPDCTS:	DS	8*2		;DCT pointers
	IF	NOCLK
PFLAGS:	DEFW	0		;pointer to FLAGS$
	ENDIF
	ENDIF

CYL:	DEFS	4
OFFSET: DEFS	4		;lseek offset buffer

	IF	BANKS
SPTEST:	DC	32,'$'		;stack space
MYSTACK	EQU	$
	ENDIF
;*=*=*
;	First make sure the file is open and correct the geometry
;	in the DCT if needed.
;*=*=*
;	$MSG	DRIVER

BEGIN:
	$DI
	IF	BANKS
	LD	(SAVSP0+1),SP
	LD	SP,MYSTACK
	LD	(XBUF),HL
	CALL	SELBK
	ENDIF

	PUSH	IX
;	$$BREAK

	IF	NOCLK
	LD	IX,(PFLAGS)
	LD	A,(IX+'V'-'A')
	LD	(SAVVFL),A
	RES	4,(IX+'V'-'A')
	SET	6,(IX+'V'-'A')	;disable cursor blinking
	ENDIF

	CALL	CKOPEN
	CALL	BODY

	IF	NOCLK
	LD	IX,(PFLAGS)
	LD	(IX+'V'-'A'),0
SAVVFL	EQU	$-1
	ENDIF

	POP	IX

	IF	BANKS
	PUSH	AF
	CALL	SELBK0
	POP	AF
SAVSP0:	LD	SP,$-$
	ENDIF

	$EI
	RET


;*=*=*
;	Driver Body
;*=*=*
BODY:	LD	A,32		;"Illegal drive number"
	RET	NZ
	LD	A,B		;The first test will return
	AND	A		;	to the caller on @DCSTAT
	RET	Z		;	and set the Z-flag with A=0
NOTDCS: CP	7
	JR	Z,RSLCT		;Transfer on @RSLCT
	JR	NC,DISKIO	;Transfer on physical I/O request
;*=*=*
;	@SLCT, @DCINIT, @DCRES, @RSTOR, @STEPI or @SEEK: no-op
;*=*=*
RETZER: SUB	A
	RET
;
	IF	BANKS

;*=*=*
;	Select memory bank
;*=*=*
SELBK:	LD	A,(XBANK)
;	$$BREAK
	JR	SELBKA
;*=*=*
;	Select memory bank 0
;*=*=*
SELBK0:	XOR	A
SELBKA:	PUSH	BC
	LD	C,A
	LD	B,0
	$SVC	@BANK
	POP	BC
	RET
;*=*=*
;	Select buffer
;*=*=*
SELBUF:	PUSH	DE
	LD	DE,(XBUF)
	LD	HL,7F00H
	OR	A
	SBC	HL,DE
	EX	DE,HL
	POP	DE
	RET	NC
	LD	HL,BUFFER$
	RET
;*=*=*
;	Get buffer to write
;*=*=*
GETBUF:	CALL	SELBUF
	RET	NC
;	$$BREAK
	PUSH	DE
	PUSH	HL
	LD	DE,(XBUF)
	EX	DE,HL
GETBU0:	CALL	SELBK0
	PUSH	BC
	LD	BC,100H
	LDIR
	POP	BC
	POP	HL
	POP	DE
	JP	SELBK
;*=*=*
;	Put buffer from read
;*=*=*
PUTBUF:	CALL	SELBUF
	RET	NC
;	$$BREAK
	PUSH	DE
	LD	DE,(XBUF)
	PUSH	DE
	JR	GETBU0

	ENDIF			;IF BANKS
;
;*=*=*
;	The RSLCT function should return with the hardware
;	write protection status. Set bit 6 of the accumulator
;	to indicate the drive is write-protected
;*=*=*
RSLCT:
	;$BREAK	RSLCT
	CALL	GETFDX		;get file desc in IX
	LD	L,(IX+0)
	LD	H,(IX+1)
	PUSH	HL
	POP	IX
	BIT	FCB$FRG,(IX+FCBFLGS)
				;fragmented? => WP on
	LD	A,0
	RET	Z
	XOR	A		;set Z
	SET	6,A		;bit 6 set = WP
	RET
;*=*=*
DISKIO: ;$BREAK	DISKIO
	BIT	2,B		;Test if read or write commands
	JP	NZ,WRCMD	;Transfer if functions <12-15>
	CP	10
	JR	Z,VRSEC
	JP	NC,RDTRK
	CP	9
	JR	Z,RDSEC
RDHDR:	LD	A,32		;Not supported ("Illegal drive number")
	AND	A
	RET
;*=*=*
RDSEC:	;$BREAK	RDSEC		;Read a sector of data
	LD	A,(IY+6)	;Get high cyl #
	CP	D		;At or below it?
	JR	NC,RDOK
	LD	A,2		;"Seek error during read"
	RET			;NZ already set
RDOK:	PUSH	DE
	PUSH	HL
	CALL	DOSEEK		;Setup and do lseek
	POP	HL
	LD	A,5		;"Data record not found during read"
	JR	NZ,RDDUN

	IF	BANKS
	CALL	SELBUF
	ENDIF

	LD	BC,256
	CALL	HXC_READ

	IF	BANKS
	PUSH	AF
	CALL	PUTBUF
	POP	AF
	ENDIF

	LD	A,4		;"Parity error during read"
RDDUN:	POP	DE
	RET	NZ

	IF	0
	LD	A,B		;Check for end of file
	OR	C
	JR	NZ,RDDUN2
	PUSH	DE
	PUSH	HL		;Return a block full of 0E5H
	PUSH	BC
	LD	(HL),0E5H
	LD	D,H
	LD	E,L
	INC	DE
	LD	BC,0FFH
	LDIR
	POP	BC
	POP	HL
	POP	DE
	SUB	A
	RET
	ENDIF

RDDUN2: LD	A,D
	SUB	(IY+9)
	JR	NZ,RDDUN1
	ADD	A,6		;"Attempted to read system data record"
	RET
RDDUN1: SUB	A
	RET
;*=*=*
VRSEC:	;$BREAK	VRSEC		;Read/verify -- we don't bother reading
	LD	A,(IY+6)	;Get high cyl #
	CP	D		;At or below it?
	JR	NC,RDDUN2	;Go if so
	LD	A,2		;"Seek error during read"
	RET			;NZ already set
;*=*=*
;	On RDSEC and VRSEC, if the read referenced the
;	directory cylinder and was successful,
;	then you need to return an error code 6. A floppy
;	disk controller will provide the indicated status.
;	Hard disk users may have to compare the requested
;	cylinder to DIRCYL in the DCT.
;*=*=*
RDTRK:	LD	A,32		;Not supported ("Illegal drive number")
	AND	A
	RET
;*=*=*
WRCMD:	BIT	7,(IY+3)	;Check for software write protect
	JR	Z,WRCMD1	;Transfer if no soft WP
	LD	A,15		;Set "Write protected disk" error
	RET
WRCMD1: CP	14		;Now parse functions 12-15
	JR	Z,WRSSC
	JP	NC,WRTRK
	CP	13
	JR	Z,WRSEC
;*=*=*
HDFMT:				;Low-level format (=erase)
	LD	A,32		;Not supported ("Illegal drive number")
	AND	A
	RET

;*=*=*
WRSEC:				;Write with X'FB' data address mark
	;$BREAK	WRSEC
	LD	A,(IY+9)	;Can't do on designated dir cylinder
	CP	D
	JR	NZ,WROK
BADDAM: LD	A,12		;"Directory write error" (?)
	AND	A
	RET
;*=*=*
WRSSC:				;Write with X'F8' data address mark
	;$BREAK	WRSSC.DIR
	LD	A,(IY+9)	;Can do only on designated dir cylinder
	CP	D
	JR	NZ,BADDAM
;*=*=*
WROK:	LD	A,(IY+6)	;Get high cyl #
	CP	D		;Beyond it?
	JR	NC,WROK1
	LD	A,10		;"Seek error during write"
	RET			;NZ already set
;*=*=*
WROK1:	PUSH	DE
	PUSH	HL
	CALL	DOSEEK
	POP	HL
	LD	A,13		;"Data record not found during write"
	JR	NZ,WRDUN

	IF	BANKS
	CALL	GETBUF
	ENDIF

	LD	BC,256
	CALL	HXC_WRITE

	IF	BANKS
	LD	HL,(XBUF)	;restore buffer ptr
	ENDIF

	LD	A,12		;"Parity error during write"
	;$BREAK	WRDUN
WRDUN:	POP	DE
	RET	NZ
	LD	A,(IY+9)
	CP	D
	CALL	Z,HXC_FLUSH	;flush if dir cylinder
	SUB	A
	RET
;*=*=*
WRTRK:	LD	A,32		;Write track
	AND	A		;Not supported ("Illegal drive number")
	RET
;*=*=*
;	Perform lseek before r/w
;*=*=*
DOSEEK: ;$BREAK	DOSEEK
	IF	MVOUT
	CALL	CALCDRS
	ELSE			;!MVOUT
	SUB	A		;sec/cyl to hl, xlate 0 to 256
	LD	H,A
	ADD	A,(IY+5)
	LD	L,A
	JR	NZ,NOINC
	INC	H
NOINC:
	IF	FREHD
	LD	B,H
	LD	C,L
	LD	HL,0
	LD	(CYL+2),HL
	LD	HL,CYL
	LD	A,D		;cyl#
	ADD	A,(IX+2)
	LD	(HL),A
	INC	HL
	LD	A,0
	ADC	A,(IX+3)
	LD	(HL),A
	DEC	HL

	$TRACE	CYL
	$TRACE4

	PUSH	DE
	EX	DE,HL
	LD	HL,OFFSET
	CALL	MOV32
	LD	A,8
	CALL	SHL32
	LD	A,B
	CALL	MUL328
	EX	DE,HL
	LD	A,C
	CALL	MUL328
	EX	DE,HL
	CALL	ADD32
	POP	DE

	$TRACE	SEC0
	$TRACE4

	LD	D,0
	INC	DE		;1 extra for header
	LD	(CYL),DE
	LD	DE,0
	LD	(CYL+2),DE
	LD	DE,CYL
	CALL	ADD32
	$TRACE	SEC
	$TRACE4
	$TRACENL
	INC	HL
	INC	HL
	LD	D,H
	LD	E,L
	INC	DE
	LD	BC,3
	LDDR
	EX	DE,HL
	LD	(HL),C		;0

	ELSE			;!FREHD

	LD	C,D		;cyl# to c
	LD	B,E		;sec# to b
	LD	A,C		;model I/III call uses a, not c
DOMUL:	$SVC	@MUL16		;hla = hl * c, smash de
	LD	D,H		;sec# to de (h is 0)
	LD	E,B
	LD	H,L		;product to hl
	LD	L,A
	INC	HL		;add 1 extra for header
	ADD	HL,DE
	EX	DE,HL		;offset to de
	LD	HL,OFFSET+3
	LD	(HL),00H
	DEC	HL
	LD	(HL),D
	DEC	HL
	LD	(HL),E
	DEC	HL
	LD	BC,0
	LD	(HL),C

	ENDIF			;ELSE !FREHD

	ENDIF			;ELSE !MVOUT
	LD	E,(IX)		;Get fd
	LD	D,(IX+1)
	CALL	HXC_LSEEK
	RET
;*=*=*
;	Open file and read geometry if needed, and
;	get address of correct fd to ix.
;*=*=*
CKOPEN: $BREAK	CKOPEN
	$DI

	IF	MVOUT

	CALL	CKOPENX

	ELSE

	CALL	GETFDX

	LD	A,(IX)		;fd == -1?
	AND	(IX+1)
	INC	A
	JR	Z,DOOPEN
	SUB	A
	RET
DOOPEN: PUSH	DE
	PUSH	BC
	PUSH	HL
	LD	A,(IY+4)
	AND	0FH

	IF	FREHD
	LD	HL,UNITS
	ADD	A,L
	LD	L,A
	LD	A,0
	ADC	A,H
	LD	H,A
	LD	A,(HL)
	ENDIF

	ADD	A,'0'
	LD	HL,HARD_	;name
	LD	(HADR),A
	CALL	HXC_OPENDISK
	LD	(IX),E
	LD	(IX+1),D
	JR	NZ,OPNERR
	LD	HL,OFFSET+3	;Prepare to read geometry
	XOR	A
	LD	BC,300H
DOOPN0:	LD	(HL),A
	DEC	HL
	DJNZ	DOOPN0
	LD	(HL),28		;offset to cyl/sec/gran params
	CALL	HXC_LSEEK
	JR	NZ,OPNERR
	LD	BC,3		;length
	CALL	HXC_READ
	JR	NZ,OPNERR
	$TRACENL
	LD	A,(IY+6)	;configured max cyl
	INC	A
	JR	NZ,DOOPN1	;keepif defined
	LD	A,(HL)		;cyl
	DEC	A
	LD	(IY+6),A	;max cylinder
DOOPN1:	INC	HL
	LD	B,(HL)		;sec
	LD	(IY+5),B

	IF	FREHD
	DEC	B		;(#heads-1)<<5 + (32 secs/track or gran - 1)
	LD	(IY+7),B	;heads, secs per track
	LD	(IY+8),B	;grans, secs per gran
	ELSE
	INC	HL
	LD	C,(HL)		;gran
	LD	E,B		;compute sec/gran
	LD	A,C		;model I/III call uses a, not c
DODIV:	$SVC	@DIV8		;a = e / c, e = e % c
				;remainder mbz, but we don't check here
	DEC	A
	DEC	C
	RRC	C
	RRC	C
	RRC	C
	OR	C
	LD	(IY+7),A	;heads, secs per track
	LD	(IY+8),A	;grans, secs per gran
	ENDIF

	LD	(IY+9),0FFH	;dircyl unknown
	SUB	A		;no error
OPNERR: POP	HL
	POP	BC
	POP	DE

	ENDIF

	RET
;*=*=*
;	Driver initialization (TODO: in driver part or in init part ??)
;*=*=*
DVRINI: ;$BREAK	DVRINI
	LD	HL,FD
	LD	D,H
	LD	E,L
	INC	DE
	LD	(HL),0FFH

	IF	FREHD
	LD	BC,NDRIVE*4-1
	ELSE
	LD	BC,NDRIVE*2-1
	ENDIF

	LDIR
	RET

ENDMAIN	EQU	$
;	$MSG	/DRIVER



;*=*=*
;	Disk name: hardM-N for model M (1,3,4), number N (0-7)
;*=*=*
HARD_:	DEFB	'hard'
HMOD:	DEFB	'1-'
HADR:	DEFB	'0',0,0,0,0,0
DVREND	EQU	$-1
LENGTH	EQU	$-ENTRY


;
;=====	HxC Emulator Additions
XENTRY	EQU	$

	JR	XBEGIN		;The driver starts with the
	DEFW	XDVREND		;	DOS standard header
XRX00	EQU	$-2
	DEFB	XMODPTR-XMODNAM	;Length of name

XMODNAM: DEFB	'HxCExt'	;Name for @GTMOD requests

XMODPTR: DEFW	0		;These pointers are unused
	DEFW	0

XBEGIN	EQU	$

;=====	Begin of code moved out of main part

	IF	MVOUT

;*=*=*
;	Get file descriptor in IX from DCT at IY
;*=*=*
GETFDX:
	LD	IX,FD		;Compute fd address
	PUSH	DE
	LD	D,0
	LD	A,(IY+4)
	AND	0FH
	RLCA

	IF	FREHD
	RLCA
	ENDIF

	LD	E,A
	ADD	IX,DE
	POP	DE
	RET

;*=*=*
;	Calculate Drive-Relative-Sector
;*=*=*
CALCDRS:
	SUB	A		;sec/cyl to hl, xlate 0 to 256
	LD	H,A
	ADD	A,(IY+5)
	LD	L,A
	JR	NZ,NOINC
	INC	H
NOINC:
	IF	FREHD
	LD	B,H
	LD	C,L
	LD	HL,0
	LD	(CYL+2),HL
	LD	HL,CYL
	LD	A,D		;cyl#
	ADD	A,(IX+2)
	LD	(HL),A
	INC	HL
	LD	A,0
	ADC	A,(IX+3)
	LD	(HL),A
	DEC	HL

	$TRACE	CYL
	$TRACE4

	PUSH	DE
	EX	DE,HL
	LD	HL,OFFSET
	CALL	MOV32
	LD	A,8
	CALL	SHL32
	LD	A,B
	CALL	MUL328
	EX	DE,HL
	LD	A,C
	CALL	MUL328
	EX	DE,HL
	CALL	ADD32
	POP	DE

	$TRACE	SEC0
	$TRACE4

	LD	D,0
	INC	DE		;1 extra for header
	LD	(CYL),DE
	LD	DE,0
	LD	(CYL+2),DE
	LD	DE,CYL
	CALL	ADD32
	$TRACE	SEC
	$TRACE4
	$TRACENL
	INC	HL
	INC	HL
	LD	D,H
	LD	E,L
	INC	DE
	LD	BC,3
	LDDR
	EX	DE,HL
	LD	(HL),C		;0

	ELSE			;!FREHD

	LD	C,D		;cyl# to c
	LD	B,E		;sec# to b
	LD	A,C		;model I/III call uses a, not c
DOMUL:	$SVC	@MUL16	;hla = hl * c, smash de
	LD	D,H		;sec# to de (h is 0)
	LD	E,B
	LD	H,L		;product to hl
	LD	L,A
	INC	HL		;add 1 extra for header
	ADD	HL,DE
	EX	DE,HL		;offset to de
	LD	HL,OFFSET+3
	LD	(HL),00H
	DEC	HL
	LD	(HL),D
	DEC	HL
	LD	(HL),E
	DEC	HL
	LD	BC,0
	LD	(HL),C

	ENDIF			;ELSE !FREHD

	RET

;*=*=*
;	Open file and read geometry if needed, and
;	get address of correct fd to ix.
;*=*=*
CKOPENX:
	CALL	GETFDX
	LD	A,(IX)		;fd == -1?
	AND	(IX+1)
	INC	A
	JR	Z,DOOPEN
	SUB	A
	RET
DOOPEN: PUSH	DE
	PUSH	BC
	PUSH	HL
	LD	A,(IY+4)
	AND	0FH

	IF	FREHD
	LD	HL,UNITS
	ADD	A,L
	LD	L,A
	LD	A,0
	ADC	A,H
	LD	H,A
	LD	A,(HL)
	ENDIF

	ADD	A,'0'
	LD	HL,HARD_	;name
	LD	(HADR),A
	CALL	HXC_OPENDISK
	LD	(IX),E
	LD	(IX+1),D
	JR	NZ,OPNERR
	LD	HL,OFFSET+3	;Prepare to read geometry
	XOR	A
	LD	BC,300H
DOOPN0:	LD	(HL),A
	DEC	HL
	DJNZ	DOOPN0
	LD	(HL),28		;offset to cyl/sec/gran params
	CALL	HXC_LSEEK
	JR	NZ,OPNERR
	LD	BC,3		;length
	CALL	HXC_READ
	JR	NZ,OPNERR
	$TRACENL
	LD	A,(IY+6)	;configured max cyl
	INC	A
	JR	NZ,DOOPN1	;keepif defined
	LD	A,(HL)		;cyl
	DEC	A
	LD	(IY+6),A	;max cylinder
DOOPN1:	INC	HL
	LD	B,(HL)		;sec
	LD	(IY+5),B

	IF	FREHD
	DEC	B		;(#heads-1)<<5 + (32 secs/track or gran - 1)
	LD	(IY+7),B	;heads, secs per track
	LD	(IY+8),B	;grans, secs per gran
	ELSE
	INC	HL
	LD	C,(HL)		;gran
	LD	E,B		;compute sec/gran
	LD	A,C		;model I/III call uses a, not c
DODIV:	$SVC	@DIV8		;a = e / c, e = e % c
				;remainder mbz, but we don't check here
	DEC	A
	DEC	C
	RRC	C
	RRC	C
	RRC	C
	OR	C
	LD	(IY+7),A	;heads, secs per track
	LD	(IY+8),A	;grans, secs per gran
	ENDIF

	LD	(IY+9),0FFH	;dircyl unknown
	SUB	A		;no error
OPNERR: POP	HL
	POP	BC
	POP	DE
	RET

	ENDIF			;IF MVOUT

;=====	End of code moved out of main part
XENDMAIN EQU	$

*GET	HXCSYS			;System routines
*GET	HXCFDC			;HxC FDC routines
*GET	HXCLBA			;LBA routines
*GET	HXCFAT32		;FAT32 routines
*GET	HXCFILE			;File routines

XDVREND	EQU	$-1
XLENGTH	EQU	$-XENTRY

	IFNDEF	CACHE_NSECS
CACHE_NSECS EQU	0		;needed by next 'IF' even if not CACHE !!!
	ENDIF

	IF	CACHE
	IF	CACHE_NSECS*206H+XLENGTH.GT.8000H
	ERR	CACHE_NSECS overflow !!
	ENDIF
	ENDIF

;==============================================================

RELTAB: DEFW	0

SEGLIST:
	DW	BEGIN,ENDMAIN
	DW	XBEGIN,XENDMAIN
	CSEG_FILE
	CSEG_SYS
	CSEG_LBA
	CSEG_FAT32
	CSEG_FDC
	DW	0

	END	INSTAL
