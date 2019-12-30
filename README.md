HxCHARD FAT32/LBA - Virtual HD driver for HxC Floppy Emulator for LDOS 5.3 and LS-DOS 6.3
=========================================================================================

HxCHARD FAT32/LBA - Emulated hard disk driver for HxC Floppy Emulator

Version 6.0.0b3+FreHD+Banks+Cache - Copyright (c) 2017, GmEsoft

Version 5.0.0b3+FreHD - Copyright (c) 2017, GmEsoft

Based on XTRSHARD/DCT - Copyright (c) 1998, Timothy Mann


Version 6.0.0b3(LS-DOS6)/5.0.0b3(LDOS5)  - beta version
-------------------------------------------------------

Version  6.x of the driver is compatible with TRS-80 Model 4 running LS-DOS 6.3
and  equipped  with  an HxC  Floppy  Emulator  with  an  SD card  formatted  as
FAT32/LBA.

Version  5.x of  the driver is compatible  with TRS-80 Models III and 4 running
LDOS 5.3.

A  VHD file  must exist in the root  directory of the SD card and must be named
HARD4-n  for version  6.x or HARD3-n for version  5.x where n is a digit in the
range  0..7.  This  file  is  not  expandable so  its  full  capacity  must  be
allocated.  Two  sample image  files are  provided: HARD4-1  for LS-DOS6 with a
total  capacity of 39 MB, and HARD3-1 for LDOS5 with a total capacity of 64 MB.
They  should be  copied on  the SD  card without  being fragmented  because the
current version of the driver cannot handle fragmented image files.

To load the driver, issue the following command at the DOS Ready prompt:

    SYSTEM (DRIVE=m, DRIVER="HXCHARDx" [, ENABLE] [, SWAP=s] )

The driver then asks the following information:

    Enter unit number (0-7)....................: n
    Enter starting cylinder....................: sta
    Enter cylinder count (0=default from VHD)..: cnt
    Enter host drive I/O address (1-4).........: h
    Enter memory bank (0-n)....................: b           [version 6.x only]

where:

    x   = 3 for LDOS 5.3 "HXCHARD3", 4 for LS-DOS 6.3 "HXCHARD4";
    n   = second digit of the VHD file name (HARD4-n/HARD3-n);
    m   = logical drive number (:0 - :7);
    sta = starting cylinder of the selected partition;
    cnt = cylinder count of the selected partition;
    h   = physical host drive number of the HxC Floppy Emulator.
    b   = memory bank (0-0 for 64kB system, 0-2 for 128kB system, ...)
          where bank 0 is  the top half of  the main memory.

If b = 0, then HIGH$ is lowered by the amount of memory required by the driver.

If  b  > 0,  then the DOS  interface part of  the driver  must be loaded in low
memory.  

If  b >  0, then  LBA sector caching  is enabled  (27.5kB). Be sure to
specify  the  same bank number  for all instances  of the driver, otherwise the
system will become instable.

Currently the driver does not support HxC in dual floppy emulation mode (A+B).

The  included disk  image file HARD4-1 for LS-DOS6 contains 6 partitions of 140
cylinders each. The following script can be used to mount the 6 partitions:

    system (drive=1,driver="HXCHARD4/DCT",enable)
    1 [unit number]
    0 [starting cyl]
    140 [cyl count]
    1 [host phys drive]
    0
    system (drive=2,driver="HXCHARD4/DCT",enable)
    1
    140
    140
    1
    0
    system (drive=3,driver="HXCHARD4/DCT",enable)
    1
    280
    140
    1
    0
    system (drive=4,driver="HXCHARD4/DCT",enable)
    1
    420
    140
    1
    0
    system (drive=5,driver="HXCHARD4/DCT",enable)
    1
    560
    140
    1
    0
    system (drive=6,driver="HXCHARD4/DCT",enable)
    1
    700
    140
    1
    0

The  included  disk image file  HARD3-1 for LDOS5  contains 6 partitions of 170
cylinders each. The following script can be used to mount the 6 partitions:

    system (drive=1,driver="HXCHARD3/DCT",enable)
    1 [unit number]
    0 [starting cyl]
    170 [cyl count]
    1 [host phys drive]
    system (drive=2,driver="HXCHARD3/DCT",enable)
    1
    170
    170
    1
    system (drive=3,driver="HXCHARD3/DCT",enable)
    1
    340
    170
    1
    system (drive=4,driver="HXCHARD3/DCT",enable)
    1
    510
    170
    1
    system (drive=5,driver="HXCHARD3/DCT",enable)
    1
    680
    170
    1
    system (drive=6,driver="HXCHARD3/DCT",enable)
    1
    850
    170
    1


Notes
-----

1.  This  driver is not  SYSGENable. Trying to  SYSGEN after loading the driver
will result in this error message:

    ** SYSGEN inhibited at this time **

2.  The  host physical drive  must be mounted and  enabled. The driver uses its
DCT to store the current track number (255 in Direct Access mode).

3.  The SD  card must be formatted as FAT32/LBA, partition type 0x0C. Generally
SDHC  cards  are already  formatted as  FAT32/LBA. If  this is  not the case, a
tool like  the  free  MiniTool  Partition  Wizard can  be  used  to  change the
partition type of the SD card to FAT32/LBA (0x0C).  The tool is available here:

    https://www.partitionwizard.com/

4.  The  VHD image  file must be  contiguous on the  SD card, ie. unfragmented.
This  image  file is not  expandable, so  the full capacity  of the VHD must be
allocated.

5.  The hard  disk emulation is done using the physical floppy disk controller.
So  the performance of the virtual hard disk will be limited by the performance
of  the controller.  Moreover, data  transfer with  the image  file is  done by
blocks of 512 bytes, corresponding to the sector size of the FAT32 file system.
So,  when  an LS-DOS sector of  256 bytes is to  be written on the SD-card, the
target  512  bytes sector must  be first read  from the SD  card, half of it is
then updated and the sector is written back to the SD.  This update is deferred
for non-DIR sectors, but done immediately for DIR sectors.

6. The current version of the HxC firmware does not support sector interleaving
in direct access mode.  Based on that fact, we have empirically determined that
the optimal number of data sectors on track 255 in Direct Access mode is 2 (so,
track  #255  presents the control/status sector  followed by two 512 bytes data
sectors).  With a  newer firmware  supporting sector  interleaving, the  number
of data sectors can possibly be raised to 8, hopefully with better performance.

7.  From version  0.9 on, part of  the driver can be loaded in extended memory.
In  order to  allow this, the DOS  interface part must be loaded in low memory,
and  a  bank number greater than  0 must be specified.  If a bank number > 0 is
specified  and  there is no  sufficient low memory  space available to load the
DOS  interface,  the driver will  fail to load. When  the driver is loaded into
extended  memory,  some sectors transfers  can be  slower, if the sector buffer
of  the  application is located above  7F00H, because a temporary buffer in low
memory  must be  used between  the application  and the  driver's 512  bytes SD
sector buffer in extended memory.

8.  From version  0.9 on, when driver  is loaded in extended memory, LBA sector
caching  is enabled.  The remaining space in the 32K extended memory bank after
the  driver is loaded is used to cache up to 55 512-bytes LBA sectors, ie. 27.5
kilobytes of cache memory.

9.  From version  0.9 on, fragmented image files are detected and mounted read-
only.  If  the driver detects a  fragmented file, it will display the following
message:

    WARNING: VHD file is fragmented; mounting read-only!

10.  From  versions 5.0.0/6.0.0 on, separate  versions for LDOS 5 and LS-DOS 6.
Version 5.0.0 for LDOS 5 is named HXCHARD3/DCT and currently has no support for
extended memory (Model 4, above 64K) and no caching. Version 6.0.0 for LS-DOS 6
is named HXCHARD4/DCT.


Error messages
--------------

- `High  memory is not  available!` - The driver can't be loaded either in low or
in high memory.

- `Must  install via  SYSTEM (DRIVE=,DRIVER=)!`  - The  driver must  be installed
using the DOS command :
```
SYSTEM (DRIVE=n, DRIVER="HXCHARD")
```    
and not directly as a /CMD program.

- `DRIVE=  must be  specified!` -  The  logical drive  must be  specified in  the
command:
```
SYSTEM (DRIVE=n, DRIVER="HXCHARD")
```
- `Aborted!` - BREAK was hit during initialization.

- `No LS-DOS 6` - This version of the driver supports TRSDOS/LS-DOS 6.x only.

- `Memory  bank is  not available!` - The specified memory bank is either already
used or inexistent.

- `Can't  load  resident part  in low memory!`  - The DOS  interface part  of the
driver  must  be loaded in  low memory if the  specified memory bank is greater
than 0.


Version history
---------------

Version 0.5 - preliminary test version - Mar 15, 2016
- First version delivered to test users.

Version 0.6 - preliminary test version - Mar 17, 2016
- drive selection (XDRIVE)

Version 0.7 - preliminary test version - Apr 19, 2016
- Fixed missing track register update in FDC I/O routines (0xF1)

Version 0.7a - preliminary test version - Apr 20, 2016
- Disabled SYSGEN

Version 0.8 - preliminary test version - Apr 25, 2016
- Support HD64180 by slowing down CPU during FDC I/O

Version 0.8a - unreleased - Apr 30, 2016
- Split driver in 2 parts:
	- DOS interface part, loadable in low memory
	- SD part, loadable in high memory

Version 0.9 - preliminary test version - May 07, 2016
- SD Driver loadable in 32K extended memory bank
- LBA Sector Caching when loaded in extended memory
- Reduced resident part size (smaller low memory requirement)

Version 0.9a - preliminary test version - May 08, 2016
- Better handling of fragmented files
- Fragmented files mounted read-only to avoid SD corruption
- Reduced resident part size; can now load EXMEM/CMD
- Resident module name is now "HxC"

Version 0.9b - beta version - May 14, 2016
- Fixed bug with buffer pointer HL destroyed on @WRSEC/@WRSSC when
- temporary buffer is used (if source buffer HL > 7F00H); appeared
- during backup operations.
- Limit bank number to 9.

Version 5.0.0b1/6.0.0b1 - beta version - May 24, 2016
- First version for LDOS 5.3: version 5.0.0b1 without EXMEM support
    and without cache (version for LS-DOS 6.3 is 6.0.0b1)
- Optimized Direct Access Mode activation
- Fixed bug with DCT pointers table
- Version 5.x.x is for LDOS 5 and is named HXCHARD3/DCT
- Version 6.x.x is for LS-DOS 6 and is named HXCHARD4/DCT

Version 5.0.0b2/6.0.0b2 - beta version - Jun 5, 2016
- Fixed bug in sector caching handler (bad status on exit)
- Restore XLR8er speed after entering Direct Access Mode
- New HxC2001 HiRes Logo (overlay mode for Micro-Labs Grafyx boards)

Version 5.0.0b3/6.0.0b3 - beta version - Jul 26, 2017
- Direct Access Mode I/O: when I/O fails, force Direct Access Mode
    and try again.
- When wrong host drive is specified, error message changed from x'05'
    (data record not found during read) to x'32' (illegal drive number).


NOTE:
-----

HXCHARD/DCT  is  freeware, but remember that  it is not public domain software.
All  copyrights connected  with the program and its accompanying document files
remain with me (Michel Bernard).

Any  feature request or defect report can be sent to me at the following e-mail
address:

  mailto:michel_bernard@hotmail.com

The  softwares included  in the  provided VHD  image are  copyrighted by  their
respective authors.  This VHD image is freely downloadable from the web page:

  http://ianmav.customer.netspace.net.au/hires/M4FreHDHRG.zip

The  HxC Floppy Emulator  is a piece of hardware that can emulate 1 or 2 floppy
drives using image files stored into an SD or SDHC card. More information about
the design of this device on the HxC2001 site:

  http://hxc2001.com/

The  HxC Floppy  Emulator is  built and  sold by  Lotharek and  can be  ordered
here:

  http://www.lotharek.pl/category.php?kid=7


CREDITS:
--------

HxCHARD/DCT  would not  have  been  possible without  the  contribution of  the
following people:

Jean-Francois  Del Nero  who designed that fantastic piece of hardware, the HxC
Floppy Emulator.

Przemyslaw  "Lotharek"  Krawczyk from  Poland, who builds  and sells HxC Floppy
Emulators.

Tim  Mann  from California, who  developed XTRSHARD/DCT on which HxCHARD/DCT is
based.

Gazza  from "Downunder" and Martin Lucas from Texas who spent considerable time
to test and help me in debugging the driver.

Ian  Mavric from  Australia, who builds and sells FreHD Hard Disk emulators and
publishes some VHD images on his web site.

Raymond  Whitehurst  from Australia  who  introduced  HxCHARD to  his  friends,
including Gazza and Ian Mavric.

Many thanks to all of them for keeping the TRS-80 alive !
