@echo off

set NAME=HXCHARD
set ZMAC=zmac\zmac
set MAIN=%NAME%_ZMAC.ASM
call DATETIME
echo.>%MAIN%
echo	DATE	MACRO >>%MAIN%
echo		DB	'%DATE8%' >>%MAIN%
echo	ENDM >>%MAIN%
echo	TIME	MACRO >>%MAIN%
echo		DB	'%TIME8%' >>%MAIN%
echo	ENDM >>%MAIN%
echo	ZMAC	EQU	1 >>%MAIN%
echo		ORG	3000H >>%MAIN%
echo	*GET	%NAME% >>%MAIN%
echo		END	INSTAL >>%MAIN%


%ZMAC% --mras %MAIN% -P1=3 -o %NAME%3.CMD -o %NAME%3.LST -o %NAME%3.BDS --od .
if errorlevel 1 pause && goto :eof
move %NAME%3.CMD %NAME%3.DCT
if errorlevel 1 pause && goto :eof
::run_hxchard_lsdos5.bat