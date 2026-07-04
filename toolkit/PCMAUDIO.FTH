\ PCMAUDIO.FTH - VERA PCM playback register words for ForthX16.
\ ===========================================================================
\ The one-shot PCM register accessors were moved out of the ROM core to save
\ space (they are just C!/C@ to the VERA audio registers, which sit in the
\ always-visible I/O page, so they work in every build). The streaming
\ PCM-WRITE stays built in. Load with:  INCLUDE PCMAUDIO.FTH
\
\ Typical use: reset+configure, set the rate, then feed samples.
\   16 128 + PCMCTRL      \ volume 15, FIFO reset (bit7)
\   128 PCMRATE           \ ~48 kHz
\   BEGIN ... PCMFULL? 0= WHILE  next-byte PCM!  REPEAT   \ paced feeder
\   buf len PCM-WRITE     \ or blast a block (native)

HEX
9F3B CONSTANT VERA-AUDIO-CTRL       \ volume 0-15, bit4 stereo, bit5 16-bit, bit7 FIFO reset
9F3C CONSTANT VERA-AUDIO-RATE       \ 0 = stop .. 80 (128) = 48 kHz
9F3D CONSTANT VERA-AUDIO-DATA       \ FIFO data port
DECIMAL

: PCMCTRL   ( n -- )      VERA-AUDIO-CTRL C! ;   \ write AUDIO_CTRL
: PCMRATE   ( n -- )      VERA-AUDIO-RATE C! ;   \ write AUDIO_RATE
: PCM!      ( byte -- )   VERA-AUDIO-DATA C! ;   \ push one sample byte (dropped if full)
: PCMFULL?  ( -- flag )   VERA-AUDIO-CTRL C@ 128 AND 0<> ;   \ FIFO full?
