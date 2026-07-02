This a modified subset of Gerry Jackson's Forth test suite that can be found at:
https://github.com/gerryjackson/forth2012-test-suite
Only the relevant files have been included (tests for unsupported component have been omitted for now). Files are
modified for compatible line endings and brought to uppercase. There are a few local changes disabling tests
that are valid only for lowercase supporting systems. Only the relevant tests are enabled in RUNTESTS.FTH. The
dynamic memory tests is present but disabled - it can be reenabled by uncommening the corresponding line, but
make sure the dynamic-memory-allocation package is loaded and initialized before starting the test suite.
At this point all supported tests should pass with Forth X16 with no errors.

In addition, this folder contains tests and demos for the Commander X16 hardware
extension words (only present in the X16 build, forthx16.prg):
* X16TEST.FTH   - self-checking test of the VERA/sprite/PSG/FM/LOAD/SAVE words;
                  prints OK/FAIL per check and "ALL X16 TESTS PASSED" at the end.
* X16GFX.FTH    - self-checking test of the bitmap graphics words (GINIT, PSET,
                  LINE, RECT, FRAME, OVAL, RING); reads pixels back from VRAM.
* X16SPR.FTH    - self-checking test of the BASIC sprite commands (MOVSPR,
                  SPRMEM, SPRITE); reads the sprite attributes back from VRAM.
* X16INP.FTH    - self-checking test of the input words (JOY, MOUSE, MX, MY,
                  MB, MWHEEL); readings are 0 with nothing pressed.
* X16MATH.FTH   - self-checking test of the math helpers (SGN, RND, RANDOM, POS).
* X16TILE.FTH   - self-checking test of the tilemap words (TILE, TDATA, TATTR).
* X16CHAR.FTH   - self-checking test of GTEXT (bitmap text); confirms pixels drawn.
* X16PSG.FTH    - self-checking test of the PSG audio words (PSGINIT, PSGNOTE,
                  PSGPAN, PSGPLAY, PSGCHORD).
* X16FM.FTH     - self-checking test of the FM audio words (FMFREQ, FMDRUM, FMVIB,
                  FMPAN, FMPOKE, FMPLAY, FMCHORD).
* X16LDSV.FTH   - self-checking test of LOAD/SAVE (BLOAD, VLOAD, BVLOAD, BVERIFY).
                  Needs a host file RAW.BIN with bytes 10,20,30,40 present.
* X16SYS.FTH    - self-checking test of USR (calls a small ML routine).
                  (MONITOR is interactive - run it and exit with X.)
* X16MEM.FTH    - self-checking test of SETBANK, I2CPEEK, SLEEP, KEYMAP.
                  (I2CPOKE and RESET/REBOOT/POWEROFF reset/alter the machine.)
* X16STRT.FTH   - self-checking test of the toolkit/X16STR.FTH string functions
                  (HEX$ BIN$ STR$ VAL ASC CHR$ LEN LEFT$ RIGHT$ MID$ RPT$).
* X16FLT.FTH    - self-checking test of the floating-point words (F+ F- F* F/,
                  FSQRT/FSIN/FCOS/FTAN/FATAN/FLN/FEXP, F. and the float stack).
* X16SPRITE.FTH - interactive demo: a 16x16 sprite moved with the cursor keys.
* X16TONE.FTH   - plays a sustained two-note tone on the VERA PSG (needs audio).
Run any of them with e.g. INCLUDE X16TEST.FTH after starting forthx16.prg.