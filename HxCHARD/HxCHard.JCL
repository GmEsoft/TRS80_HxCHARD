. MRAS JCL SCRIPT
.DO #NAME# (I) - to import source from host
//ASSIGN NAME=HxCHARD
//ASSIGN NAME1=Autorelo
//ASSIGN NAME2=HxCFAT32
//ASSIGN NAME3=HxCFDC
//ASSIGN NAME4=HxCFile
//ASSIGN NAME5=HxCLBA
//ASSIGN NAME6=HxCLogo
//ASSIGN NAME7=HxCSys
//if -D
//assign D=1
//end
//if -T
//assign T=1
//end
//if F
sim f
//end
//if PURGE+CLEAN
remove #NAME#/jcl:#D#
remove #NAME#/asm:#D#
remove #NAME1#/asm:#D#
remove #NAME2#/asm:#D#
remove #NAME3#/asm:#D#
remove #NAME4#/asm:#D#
remove #NAME5#/asm:#D#
remove #NAME6#/asm:#D#
remove #NAME7#/asm:#D#
//if F
sim s
//end
//exit
//end
//if I
import -n #NAME#.jcl #NAME#/jcl:#D#
import -n #NAME#.asm #NAME#/asm:#D#
import -n #NAME1#.asm #NAME1#/asm:#D#
import -n #NAME2#.asm #NAME2#/asm:#D#
import -n #NAME3#.asm #NAME3#/asm:#D#
import -n #NAME4#.asm #NAME4#/asm:#D#
import -n #NAME5#.asm #NAME5#/asm:#D#
import -n #NAME6#.asm #NAME6#/asm:#D#
import -n #NAME7#.asm #NAME7#/asm:#D#
//end
//if X
export -n #NAME#/jcl:#D#
export -n #NAME#/asm:#D#
export -n #NAME1#/asm:#D#
export -n #NAME2#/asm:#D#
export -n #NAME3#/asm:#D#
export -n #NAME4#/asm:#D#
export -n #NAME5#/asm:#D#
export -n #NAME6#/asm:#D#
export -n #NAME7#/asm:#D#
//if F
sim s
//end
//exit
//end
//if E
//if F
sim s
//end
TIME(CLOCK=N)
.%1F.0: #NAME# %0A.1: #NAME1#%0A.2: #NAME2#%0A.3: #NAME3#
.4: #NAME4#%0A.5: #NAME5#%0A.6: #NAME6#%0A.7: #NAME7#
.9: #NAME#/JCL
//KEYIN %1DChoice (ENTER to build, BREAK to exit)?
//0
edt #NAME#/asm:#D#
//if F
sim f
//end
do *
//1
edt #NAME1#/asm:#D#
//if F
sim f
//end
do *
//2
edt #NAME2#/asm:#D#
//if F
sim f
//end
do *
//3
edt #NAME3#/asm:#D#
//if F
sim f
//end
do *
//4
edt #NAME4#/asm:#D#
//if F
sim f
//end
do *
//5
edt #NAME5#/asm:#D#
//if F
sim f
//end
do *
//6
edt #NAME6#/asm:#D#
//if F
sim f
//end
do *
//7
edt #NAME7#/asm:#D#
//if F
sim f
//end
do *
//9
edt #NAME#/jcl:#D#
//exit
///
TIME(CLOCK)
//PAUSE -- DO * to restart JCL
//end
//if F
sim f
//end
//if -M
//assign M=3
//end
//assign N=#NAME#
//if L
mras #N#:#D# +o=#N##M#/DCT:#D# -nm-ne-nc-we-gc (P1=#M#)
//else
mras #N#:#D# +o=#N##M#/DCT:#D# +s=:#D# -nl-gc (P1=#M#)
//end
//IF F
sim s
//END
//ALERT 7,0,1,0,7,0,1,0
//IF I
export #N##M#/DCT:#D#
//END
//if R
//INCLUDE HXCTEST
device
//PAUSE -- Ready to copy driver to :7?
copy #N##M#/DCT:#D# :7
//EXIT
//end
