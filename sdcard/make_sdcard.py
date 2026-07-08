#!/usr/bin/env python
# Build a 35 MB FAT32 SD-card image for ForthX16 (MBR + one FAT32 partition at
# LBA 2048), populated with the toolkit + other/ .FTH files and the HELP system.
#
#   python sdcard/make_sdcard.py
#
# Produces  sdcard/sdcard.img .  Launch a build with  x16emu ... -sdcard sdcard\sdcard.img
# and device 8 becomes this card:  S" ASSEMBLER.FTH" INCLUDED , INCLUDE HELP , DIR , ...
#
# 35 MB is the smallest size that is a spec-valid FAT32 (>= 65525 clusters at a
# 512-byte cluster); the X16 KERNAL is FAT32-only. Needs pyfatfs (pip install pyfatfs).

import struct, os, glob
from pyfatfs.PyFat import PyFat
from pyfatfs.PyFatFS import PyFatFS

ROOT   = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT    = os.path.join(ROOT, "sdcard", "sdcard.img")
PART   = OUT + ".part"
SECTOR = 512
IMG_SIZE = 35 * 1024 * 1024
PART_LBA = 2048
part_bytes = IMG_SIZE - PART_LBA * SECTOR

# 1. format the FAT32 partition (as a standalone file)
with open(PART, "wb") as f:
    f.truncate(part_bytes)
pf = PyFat()
pf.mkfs(PART, fat_type=PyFat.FAT_TYPE_FAT32, size=part_bytes, sector_size=SECTOR, label="FORTH")
pf.close()

# 2. populate it
fs = PyFatFS(PART)
def put(src, dst):
    with open(src, "rb") as f:
        fs.writebytes(dst, f.read())
    print("  +", dst)

for f in sorted(glob.glob(os.path.join(ROOT, "toolkit", "*.FTH"))):
    put(f, "/" + os.path.basename(f))
for f in sorted(glob.glob(os.path.join(ROOT, "other", "*.FTH"))):
    put(f, "/" + os.path.basename(f))
put(os.path.join(ROOT, "help", "HELP"), "/HELP")
# loaders so the ROM-bank-32 build can start from this card ( LOAD"LOADER32",8 );
# named without an extension because the KERNAL LOAD does not append .PRG.
for ldr, name in (("loader.prg", "LOADER"), ("loader32.prg", "LOADER32")):
    p = os.path.join(ROOT, ldr)
    if os.path.exists(p):
        put(p, "/" + name)
fs.makedir("/helpdoc")
for f in sorted(glob.glob(os.path.join(ROOT, "help", "helpdoc", "*.TXT"))):
    put(f, "/helpdoc/" + os.path.basename(f))
# a friendly boot script (device 8 = this card when launched with -sdcard)
fs.writebytes("/AUTORUN.FTH",
    b'S" HELP" INCLUDED\n'
    b'CR .( ForthX16 SD card ready - type  HELP  for topics, or  DIR  for files.) CR\n')
print("  + /AUTORUN.FTH")
fs.close()

# 3. wrap the partition in an MBR image
img = bytearray(IMG_SIZE)
pe = 446
img[pe]            = 0x00                              # not bootable
img[pe+1:pe+4]     = bytes([0xFE, 0xFF, 0xFF])         # CHS start (dummy)
img[pe+4]          = 0x0C                              # type = FAT32 (LBA)
img[pe+5:pe+8]     = bytes([0xFE, 0xFF, 0xFF])         # CHS end (dummy)
img[pe+8:pe+12]    = struct.pack("<I", PART_LBA)       # LBA start
img[pe+12:pe+16]   = struct.pack("<I", part_bytes // SECTOR)
img[510], img[511] = 0x55, 0xAA
with open(PART, "rb") as f:
    part = f.read()
img[PART_LBA*SECTOR : PART_LBA*SECTOR + len(part)] = part
with open(OUT, "wb") as f:
    f.write(img)
os.remove(PART)
print("wrote %s  (%d bytes)" % (OUT, os.path.getsize(OUT)))
