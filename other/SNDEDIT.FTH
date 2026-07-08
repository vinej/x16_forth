\ SNDEDIT.FTH - a tune / song / noise editor for the Commander X16.
\ ===========================================================================
\ Enter a monophonic song as a list of steps (a note + a duration in jiffies),
\ play it on either the VERA PSG or the YM2151 FM synth, and save/reload it so a
\ game can BLOAD and play it. A "note" byte is  octave<<4 | semitone(1..12), with
\ 0 = rest/off - the same encoding PSGNOTE and FMNOTE use. PSG waveform 3 = noise.
\
\ Load:   INCLUDE SNDEDIT.FTH
\
\ Quick start
\   SG-DEMO   SG-PLAY          \ build a sample tune and play it (PSG)
\   FM  SG-PLAY                \ same tune on the FM synth
\   SNDED                      \ interactive editor
\   S" TUNE.SNG" SG-SAVE       \ later, even in a game: S" TUNE.SNG" SG-LOAD SG-PLAY
\
\ Building a song from Forth
\   SG-CLR                     \ empty the song
\   $41 8 NOTE,  $45 8 NOTE,   \ append C4 and E4, 8 jiffies each ( note dur NOTE, )
\   0 12 NOTE,                 \ a 12-jiffy rest
\   PSG | FM                   \ pick the synth ; VOICE ( n -- ) picks voice/channel

DECIMAL

\ --- data model ------------------------------------------------------------
\ SGBUF: [0]=len [1]=synth [2]=chan [3]=wave/inst  [4..131]=64 steps of (note,dur)
CREATE SGBUF  132 ALLOT
SGBUF 4 + CONSTANT SONG        \ the step bytes start here
64 CONSTANT MAXSTEP

0 VALUE SYNTH     \ 0 = PSG, 1 = FM
0 VALUE CHAN      \ PSG voice (0-15) or FM channel (0-7)
0 VALUE WAVE      \ PSG waveform 0-3 (3 = noise)
0 VALUE INST      \ FM instrument patch
4 VALUE ED-OCT    \ octave used when entering notes
8 VALUE ED-DUR    \ duration used when entering notes (jiffies)
0 VALUE SG-LEN    \ number of active steps
0 VALUE EC        \ editor cursor (step index)
0 VALUE ED-QUIT

: STEP@ ( i -- note dur )  2* SONG +  DUP C@  SWAP 1+ C@ ;
: STEP! ( note dur i -- )  2* SONG + >R  R@ 1+ C!  R> C! ;
: SG-CLR ( -- )  SONG MAXSTEP 2* 0 FILL  0 TO SG-LEN ;
: NOTE, ( note dur -- )
   SG-LEN MAXSTEP < IF SG-LEN STEP!  SG-LEN 1+ TO SG-LEN ELSE 2DROP THEN ;

\ --- synth selection -------------------------------------------------------
: PSG   ( -- )  0 TO SYNTH ;
: FM    ( -- )  1 TO SYNTH ;
: VOICE ( n -- )  TO CHAN ;
: SND-INIT ( -- )              \ configure the selected synth for playback
   SYNTH IF
      FMINIT  INST CHAN FMINST  63 CHAN FMVOL
   ELSE
      PSGINIT  WAVE CHAN PSGWAV  63 CHAN PSGVOL
   THEN ;
: SND-NOTE ( note -- )  SYNTH IF CHAN FMNOTE ELSE CHAN PSGNOTE THEN ;

\ --- play the whole song (blocking, jiffy timing) --------------------------
: SG-PLAY ( -- )
   SND-INIT
   SG-LEN 0 ?DO  I STEP@ SWAP SND-NOTE  SLEEP  LOOP
   0 SND-NOTE ;

\ --- disk (device 8) -------------------------------------------------------
: >HDR ( -- )  SG-LEN SGBUF C!  SYNTH SGBUF 1+ C!  CHAN SGBUF 2 + C!
               SYNTH IF INST ELSE WAVE THEN  SGBUF 3 + C! ;
: HDR> ( -- )  SGBUF C@ TO SG-LEN  SGBUF 1+ C@ TO SYNTH  SGBUF 2 + C@ TO CHAN
               SGBUF 3 + C@  SYNTH IF TO INST ELSE TO WAVE THEN ;
: SG-SAVE ( c-addr u -- )  >HDR  8 SGBUF  SGBUF 132 +  SAVE ;
: SG-LOAD ( c-addr u -- )  8 SGBUF BLOAD  HDR> ;

\ --- note names ------------------------------------------------------------
CREATE NMTAB  ," C C#D D#E F F#G G#A A#B "     \ 12 * 2 chars, index = (semi-1)*2
: .NOTE ( note -- )            \ "C 4" style, or "---" for a rest
   DUP 0= IF DROP ." ---" EXIT THEN
   DUP 15 AND 1- 2*  NMTAB 1+ +  2 TYPE        \ semitone name
   4 RSHIFT [CHAR] 0 + EMIT ;                  \ octave digit

\ --- a sample tune ---------------------------------------------------------
: SG-DEMO ( -- )               \ a C major up/down run
   SG-CLR
   $41 8 NOTE,  $43 8 NOTE,  $45 8 NOTE,  $46 8 NOTE,
   $48 8 NOTE,  $46 8 NOTE,  $45 8 NOTE,  $43 8 NOTE,
   $41 16 NOTE, ;

\ --- interactive editor (incremental redraw: only changed rows repaint) -----
CREATE PIANOKEYS  ," ZSXDCVGBHNJM"             \ index+1 = semitone
: >UPPER ( c -- c )  DUP [CHAR] a [CHAR] z 1+ WITHIN IF 32 - THEN ;
: KEY>SEMI ( key -- semi true | false )
   12 0 DO
      DUP  PIANOKEYS 1+ I + C@  =  IF DROP I 1+ TRUE UNLOOP EXIT THEN
   LOOP  DROP FALSE ;
: GETKEY ( -- key )  BEGIN KEY ?DUP UNTIL ;    \ KEY is non-blocking; wait for a key

0 VALUE LTOP                     \ song index on the top list row
: STEP-LINE ( s -- )         \ one step's text, padded to overwrite
   DUP EC = IF [CHAR] > EMIT ELSE SPACE THEN
   DUP 2 .R ." : "
   DUP SG-LEN < IF  STEP@ SWAP .NOTE ." /" 3 .R ."       "
   ELSE  SG-LEN = IF ." --- (end)     " ELSE ."                " THEN  THEN ;
: DRAW-ROW  ( s -- )   DUP LTOP - 2 +  0 LOCATE  STEP-LINE ;
: DRAW-LIST ( -- )     LTOP 16 +  LTOP  DO  I DRAW-ROW  LOOP ;
: DRAW-HDR ( -- )
   0 0 LOCATE  ." AUDIO EDITOR   "
   SYNTH IF ." FM inst=" INST . ELSE ." PSG wave=" WAVE . THEN
   ." ch=" CHAN . ." oct=" ED-OCT . ." dur=" ED-DUR . ." steps=" SG-LEN . ."   " ;
: DRAW-HELP ( -- )           \ static, drawn once
   19 0 LOCATE
   ." ZSXDCVGBHNJM set pitch  1-8 oct  INS add step  DEL del  SPACE rest" CR
   ." +/- note dur  P play  T PSG/FM  W wave  I inst  , . chan  Q quit" ;

: CUR-MOVE ( d -- )          \ repaint only the 2 changed rows
   EC + 0 MAX SG-LEN MIN     ( newEC )
   DUP EC = IF DROP EXIT THEN
   EC SWAP TO EC             ( oldEC )
   EC LTOP - 0 16 WITHIN IF                 \ new cursor still visible?
      DRAW-ROW  EC DRAW-ROW                 \ old row off, new row on
   ELSE
      DROP  EC LTOP < IF EC ELSE EC 15 - THEN TO LTOP  DRAW-LIST
   THEN ;
: PUT-NOTE ( note -- )       \ short pitch blip, then set the note at the cursor
   DUP SND-NOTE  3 SLEEP  0 SND-NOTE
   EC SG-LEN = IF                          \ at the end: append and advance
      SG-LEN MAXSTEP < IF
         SG-LEN 1+ TO SG-LEN  ED-DUR EC STEP!  1 CUR-MOVE
      ELSE DROP THEN
   ELSE                                    \ on a note: change it in place, stay
      ED-DUR EC STEP!  EC DRAW-ROW
   THEN ;
: DEL-STEP ( -- )            \ remove step, shift up, redraw
   EC SG-LEN < IF
      SG-LEN 1- EC ?DO  I 1+ STEP@ I STEP!  LOOP
      SG-LEN 1- TO SG-LEN  EC SG-LEN MIN TO EC  DRAW-LIST
   THEN ;
: SET-DUR@CUR ( -- )         \ change the duration of the note under the cursor
   EC SG-LEN < IF  EC STEP@ DROP  ED-DUR EC STEP!  EC DRAW-ROW  THEN ;
: INS-STEP ( -- )            \ insert a rest at the cursor, shifting the rest down (grow)
   SG-LEN MAXSTEP < IF
      SG-LEN EC - 0 ?DO  SG-LEN 1- I -  DUP STEP@  ROT 1+ STEP!  LOOP
      0 ED-DUR EC STEP!  SG-LEN 1+ TO SG-LEN  DRAW-LIST
   THEN ;

: SET-OCT ( key -- )  [CHAR] 0 -  TO ED-OCT ;
: SYN-TOGGLE ( -- )  SYNTH 0= 1 AND TO SYNTH  0 TO CHAN  SND-INIT ;
: ED-KEY ( key -- )
   >UPPER
   DUP KEY>SEMI IF NIP  ED-OCT 4 LSHIFT OR  PUT-NOTE EXIT THEN
   CASE
      145 OF -1 CUR-MOVE ENDOF                 \ cursor up
      17  OF  1 CUR-MOVE ENDOF                 \ cursor down
      32  OF  0 PUT-NOTE ENDOF                 \ SPACE = rest
      20  OF DEL-STEP ENDOF                    \ DEL = remove step
      148 OF INS-STEP ENDOF                    \ INS = insert step
      [CHAR] + OF ED-DUR 1+ 60 MIN TO ED-DUR SET-DUR@CUR ENDOF
      [CHAR] - OF ED-DUR 1- 1 MAX TO ED-DUR SET-DUR@CUR ENDOF
      [CHAR] . OF CHAN 1+ SYNTH IF 7 ELSE 15 THEN MIN TO CHAN ENDOF
      [CHAR] , OF CHAN 1- 0 MAX TO CHAN ENDOF
      [CHAR] W OF SYNTH 0= IF WAVE 1+ 3 AND TO WAVE SND-INIT THEN ENDOF
      [CHAR] I OF SYNTH IF INST 1+ 31 AND TO INST SND-INIT THEN ENDOF
      [CHAR] P OF SG-PLAY ENDOF
      [CHAR] T OF SYN-TOGGLE ENDOF
      [CHAR] Q OF 1 TO ED-QUIT ENDOF
      DUP [CHAR] 1 [CHAR] 8 1+ WITHIN IF DUP SET-OCT THEN   \ default: octave digit
   ENDCASE ;
: SNDED ( -- )
   0 TO EC  0 TO ED-QUIT  0 TO LTOP  SND-INIT
   CLS  DRAW-HELP  DRAW-HDR  DRAW-LIST         \ full draw once
   BEGIN
      GETKEY ED-KEY  DRAW-HDR  ED-QUIT   \ header cheap; list is incremental
   UNTIL
   0 SND-NOTE  CLS
   ." Song kept in memory.  SG-PLAY to hear, SG-SAVE to keep it." CR ;

CR .( SNDEDIT loaded.  SG-DEMO SG-PLAY | SNDED | PSG/FM ) CR
