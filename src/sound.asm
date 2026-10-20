;=======================================================================================
; SID sound: a tiny two-voice tune player (voices 1 and 2) plus one-shot sound
; effects on voice 3. sound_tick runs once per frame.
;
; Tune format: pairs of (note, frames). note 0 = rest, note $FF = loop to start,
; note $FE = end. Voice 2 plays the bass line of the same tune table (third byte
; of each step): steps are (melody note, bass note, frames).
;=======================================================================================

TUNE_NONE       = 0
TUNE_PIANO      = 1
TUNE_RECORD     = 2
TUNE_DANCE      = 3
TUNE_ODE        = 4         ; more piano pieces...
TUNE_MINUET     = 5
TUNE_ENTERTAINER = 6
TUNE_CANCAN     = 7         ; ...and records
TUNE_SUSANNA    = 8
TUNE_CAMPTOWN   = 9

SFX_NONE        = 0
SFX_PHONE       = 1
SFX_ALARM       = 2
SFX_KNOCK       = 3
SFX_FLUSH       = 4
SFX_SPLASH      = 5
SFX_BARK        = 6
SFX_TYPE        = 7
SFX_DOOR        = 8
SFX_GLUG        = 9
SFX_CHIME       = 10
SFX_CLACK       = 11
SFX_BLIP        = 12
SFX_STEP        = 13
SFX_TINK        = 14
SFX_TALK        = 15
SFX_BRUSH       = 16
SFX_SHUT        = 17        ; a door shutting: a soft thud, the latch clicks

;---------------------------------------------------------------------------------------
; Digital sample playback on audio DMA channel 0 (his voice on the phone).
; $D720 control: bit7 enable, bit6 loop, bit5 unsigned, bits1-0 size (10 = 8-bit)
; $D724-6 rate step, $D727-8 end address (low 16 bits), $D729 volume,
; $D72A-C current/start address. $D711 bit 7 enables audio DMA.
;---------------------------------------------------------------------------------------
; His voice and the other digital sounds live in Attic RAM; sample_play DMAs
; one into the chip-RAM buffer SND_BUF and starts audio DMA channel 0 on it.
snd_ofs_l:  .byte <SND_TALK_OFS, <SND_FLUSH_OFS, <SND_BELL_OFS, <SND_BARK_OFS, <SND_ALARM_OFS
snd_ofs_h:  .byte >SND_TALK_OFS, >SND_FLUSH_OFS, >SND_BELL_OFS, >SND_BARK_OFS, >SND_ALARM_OFS
snd_len_l:  .byte <SND_TALK_LEN, <SND_FLUSH_LEN, <SND_BELL_LEN, <SND_BARK_LEN, <SND_ALARM_LEN
snd_len_h:  .byte >SND_TALK_LEN, >SND_FLUSH_LEN, >SND_BELL_LEN, >SND_BARK_LEN, >SND_ALARM_LEN
snd_fq0:    .byte <SND_TALK_FREQ, <SND_FLUSH_FREQ, <SND_BELL_FREQ, <SND_BARK_FREQ, <SND_ALARM_FREQ
snd_fq1:    .byte >SND_TALK_FREQ, >SND_FLUSH_FREQ, >SND_BELL_FREQ, >SND_BARK_FREQ, >SND_ALARM_FREQ
snd_fq2:    .byte `SND_TALK_FREQ, `SND_FLUSH_FREQ, `SND_BELL_FREQ, `SND_BARK_FREQ, `SND_ALARM_FREQ

talk_play:
        ldx #SND_TALK
        jmp sample_play
; A little dog's bark -- unless another sample (his voice, the bell...) is
; playing: that isn't cut off.
bark_play:
        jsr talk_level
        bcc +
        rts
+       ldx #SND_BARK
        jmp sample_play
alarm_play:
        ldx #SND_ALARM
        jmp sample_play
doorbell_play:
        ldx #SND_BELL
        jmp sample_play
flush_play:
        ldx #SND_FLUSH
; X = sound number
sample_play:
        lda #0
        sta $D720
        ; Attic -> play buffer
        lda #ATTIC_MB
        sta dma_src_mb
        lda #0
        sta dma_dst_mb
        lda snd_ofs_l,x
        sta dma_src
        lda snd_ofs_h,x
        sta dma_src+1
        lda #ATTIC_SOUNDS_BANK
        sta dma_src_bank
        lda #<SND_BUF
        sta dma_dst
        lda #>SND_BUF
        sta dma_dst+1
        lda #`SND_BUF
        sta dma_dst_bank
        lda snd_len_l,x
        sta dma_len
        lda snd_len_h,x
        sta dma_len+1
        phx
        jsr dma_copy
        plx
        ; play it
        lda #$80
        sta $D711
        lda #<SND_BUF
        sta $D72A
        lda #>SND_BUF
        sta $D72B
        lda #`SND_BUF
        sta $D72C
        clc
        lda #<SND_BUF
        adc snd_len_l,x
        sta $D727
        lda #>SND_BUF
        adc snd_len_h,x
        sta $D728
        lda snd_fq0,x           ; this sound's playback rate
        sta $D724
        lda snd_fq1,x
        sta $D725
        lda snd_fq2,x
        sta $D726
        lda #$FF
        sta $D729
        sta $D71C               ; channel 0 to the right side as well
        lda #%10100010          ; enable, unsigned, 8-bit
        sta $D720
        rts

talk_stop:
        lda #0
        sta $D720
        rts

; C = 1 while the sample is still playing; A = how loud it is right now
; (0..127), for lip sync.
talk_level:
        lda $D720
        bpl l_tl_quiet
        and #$08                ; stop flag
        bne l_tl_quiet
        lda $D72A
        sta ZTMP
        lda $D72B
        sta ZTMP+1
        lda $D72C
        sta ZTMP+2
        lda #0
        sta ZTMP+3
        ldz #0
        lda [ZTMP],z
        sec
        sbc #128
        bpl +
        eor #$FF
+       sec
        rts
l_tl_quiet:
        lda #0
        clc
        rts

sound_init:
        ldx #$18
        lda #0
-       sta SID,x
        dex
        bpl -
        lda #$0F
        sta SID_VOLUME
        ; voice 1: piano-ish pulse
        lda #$00
        sta SID+2
        lda #$08
        sta SID+3
        lda #$09
        sta SID+5               ; A=0 D=9
        lda #$00
        sta SID+6               ; S=0 R=0
        ; voice 2: bass triangle
        lda #$0A
        sta SID+12
        lda #$00
        sta SID+13
        lda #0
        sta tune_id
        sta sfx_id
        rts

;---------------------------------------------------------------------------------------
; Tunes
;---------------------------------------------------------------------------------------
tune_id:    .byte 0
tune_once:  .byte 0         ; 1 = stop at the end instead of looping
l_tn_ptr:    .word 0
l_tn_pos:    .word 0
l_tn_left:   .byte 0

; A = tune id (0 stops)
tune_play:
        sta tune_id
        pha
        lda #0                  ; loops unless told otherwise (tune_once)
        sta tune_once
        pla
        cmp #0
        bne +
        lda #$40
        sta SID+4
        sta SID+11
        rts
+       asl
        tax
        lda tune_table-2,x
        sta l_tn_ptr
        lda tune_table-1,x
        sta l_tn_ptr+1
        lda #0
        sta l_tn_pos
        sta l_tn_pos+1
        sta l_tn_left
        rts

tune_table:
        .word tuned_piano, tuned_record, tuned_dance
        .word tuned_ode, tuned_minuet, tuned_entertainer
        .word tuned_cancan, tuned_susanna, tuned_camptown
; the pieces he plays on the piano, and the records he owns
piano_tunes:    .byte TUNE_PIANO, TUNE_ODE, TUNE_MINUET, TUNE_ENTERTAINER
record_tunes:   .byte TUNE_RECORD, TUNE_CANCAN, TUNE_SUSANNA, TUNE_CAMPTOWN

l_tune_step:
        clc
        lda l_tn_ptr
        adc l_tn_pos
        sta ZPTR2
        lda l_tn_ptr+1
        adc l_tn_pos+1
        sta ZPTR2+1
        ldy #0
        lda (ZPTR2),y
        cmp #$FF
        bne +
        lda tune_once           ; the end: once only (a record)? then stop
        beq l_tst_loop
        lda #0
        jmp tune_play
l_tst_loop:
        lda #0
        sta l_tn_pos
        sta l_tn_pos+1
        bra l_tune_step
+       cmp #$FE
        bne +
        lda #0
        jmp tune_play
+       ; melody
        lda #$40
        sta SID+4               ; gate off (pulse)
        lda (ZPTR2),y
        beq l_ts_bass
        tax
        lda note_lo,x
        sta SID+0
        lda note_hi,x
        sta SID+1
        lda #$41
        sta SID+4
l_ts_bass:
        lda #$10
        sta SID+11
        iny
        lda (ZPTR2),y
        beq l_ts_len
        tax
        lda note_lo,x
        sta SID+7
        lda note_hi,x
        sta SID+8
        lda #$11
        sta SID+11
l_ts_len:
        iny
        lda (ZPTR2),y
        sta l_tn_left
        clc
        lda l_tn_pos
        adc #3
        sta l_tn_pos
        bcc +
        inc l_tn_pos+1
+       rts

;---------------------------------------------------------------------------------------
; Sound effects (voice 3)
;---------------------------------------------------------------------------------------
sfx_id:     .byte 0
l_sfx_t:     .byte 0

; A = effect id
sfx_play:
        sta sfx_id
        lda #0
        sta shower_gate         ; the effect takes voice 3; the shower resumes after
        lda sfx_id
        lda #0
        sta l_sfx_t
        rts

sound_tick:
        jsr shower_tick
        lda tune_id
        beq l_st_sfx
        lda l_tn_left
        beq +
        dec l_tn_left
        bne l_st_sfx
+       jsr l_tune_step
l_st_sfx:
        lda sfx_id
        bne +
        rts
+       asl
        tax
        lda sfx_table-2,x
        sta ZPTR2
        lda sfx_table-1,x
        sta ZPTR2+1
        ; script: per step (frame, freq_hi, control, AD, SR); frame $FF = end
        ldy #0
l_sx_find:
        lda (ZPTR2),y
        cmp #$FF
        beq l_sx_end
        sta l_sx_last
        cmp l_sfx_t
        beq l_sx_fire
        tya
        clc
        adc #5
        tay
        bra l_sx_find
l_sx_fire:
        iny
        lda (ZPTR2),y
        sta SID+15
        lda #0
        sta SID+14
        iny
        lda (ZPTR2),y
        pha
        iny
        lda (ZPTR2),y
        sta SID+19
        iny
        lda (ZPTR2),y
        sta SID+20
        pla
        sta SID+18
l_sx_next:
        inc l_sfx_t
        rts
l_sx_end:
        ; let the last note ring for a moment, then free the voice
        lda l_sx_last
        clc
        adc #12
        cmp l_sfx_t
        bcs l_sx_next
        lda #0
        sta sfx_id
        sta SID+18
        rts

l_sx_last: .byte 0

; Shower: one long steady hiss of noise on voice 3 while shower_on is set
; (gated once, never re-triggered, so it doesn't stutter).
shower_on:      .byte 0
shower_gate:    .byte 0
shower_pitch:   .byte $C0   ; noise pitch: $C0 shower spray, lower for the tap

shower_tick:
        lda shower_on
        bne +
        lda shower_gate
        beq l_sh_out
        lda #0
        sta shower_gate
        lda #$80                ; let it fade out
        sta SID+18
        rts
+       lda sfx_id
        bne l_sh_out
        lda shower_gate
        bne l_sh_out
        lda #1
        sta shower_gate
        lda #0
        sta SID+14
        lda shower_pitch
        sta SID+15              ; high noise = water spray
        lda #$60                ; soft attack
        sta SID+19
        lda #$A9                ; sustain 10, release 9 (tap: same, lower pitch)
        sta SID+20
        lda #$81
        sta SID+18
l_sh_out:
        rts

sfx_table:
        .word sfxd_phone, sfxd_alarm, sfxd_knock, sfxd_flush, sfxd_splash, sfxd_bark
        .word sfxd_type, sfxd_door, sfxd_glug, sfxd_chime, sfxd_clack, sfxd_blip
        .word sfxd_step, sfxd_tink, sfxd_talk, sfxd_brush, sfxd_shut

; frame, freq hi, control, attack/decay, sustain/release
sfxd_phone:
        .byte 0, $30, $15, $00, $F0
        .byte 3, $34, $15, $00, $F0
        .byte 6, $30, $15, $00, $F0
        .byte 9, $34, $15, $00, $F0
        .byte 12, $30, $15, $00, $F0
        .byte 15, $34, $15, $00, $F0
        .byte 18, $30, $15, $00, $F0
        .byte 21, $34, $15, $00, $F0
        .byte 24, $30, $14, $00, $F0
        .byte 50, $30, $15, $00, $F0
        .byte 53, $34, $15, $00, $F0
        .byte 56, $30, $15, $00, $F0
        .byte 59, $34, $15, $00, $F0
        .byte 62, $30, $15, $00, $F0
        .byte 65, $34, $15, $00, $F0
        .byte 68, $30, $14, $00, $F0
        .byte $FF
sfxd_alarm:
        .byte 0, $50, $41, $00, $F0
        .byte 4, $50, $40, $00, $F0
        .byte 8, $50, $41, $00, $F0
        .byte 12, $50, $40, $00, $F0
        .byte 16, $50, $41, $00, $F0
        .byte 20, $50, $40, $00, $F0
        .byte 24, $50, $41, $00, $F0
        .byte 28, $50, $40, $00, $F0
        .byte 32, $50, $41, $00, $F0
        .byte 36, $50, $40, $00, $F0
        .byte $FF
sfxd_knock:
        .byte 0, $08, $81, $00, $06
        .byte 2, $08, $80, $00, $06
        .byte 12, $08, $81, $00, $06
        .byte 14, $08, $80, $00, $06
        .byte 24, $08, $81, $00, $06
        .byte 26, $08, $80, $00, $06
        .byte $FF
sfxd_flush:
        .byte 0, $20, $81, $0C, $AB
        .byte 20, $18, $81, $0C, $AB
        .byte 40, $10, $80, $0C, $AB
        .byte $FF
sfxd_splash:
        .byte 0, $40, $81, $0A, $89
        .byte 10, $38, $80, $0A, $89
        .byte 25, $48, $81, $0A, $89
        .byte 35, $40, $80, $0A, $89
        .byte $FF
sfxd_bark:
        .byte 0, $0C, $81, $00, $A4
        .byte 4, $09, $80, $00, $A4
        .byte 10, $0C, $81, $00, $A4
        .byte 14, $09, $80, $00, $A4
        .byte $FF
sfxd_type:
        .byte 0, $60, $81, $00, $03
        .byte 1, $60, $80, $00, $03
        .byte $FF
sfxd_door:
        .byte 0, $06, $81, $08, $08
        .byte 6, $05, $80, $08, $08
        .byte $FF
sfxd_glug:
        .byte 0, $08, $11, $00, $A6
        .byte 5, $06, $10, $00, $A6
        .byte 10, $08, $11, $00, $A6
        .byte 15, $06, $10, $00, $A6
        .byte $FF
sfxd_chime:
        .byte 0, $22, $11, $09, $00
        .byte 8, $2B, $11, $09, $00
        .byte 16, $33, $11, $09, $00
        .byte 30, $33, $10, $09, $00
        .byte $FF
sfxd_shut:
        .byte 0, $05, $81, $06, $06
        .byte 4, $05, $80, $06, $06
        .byte 6, $70, $81, $00, $01
        .byte 7, $70, $80, $00, $01
        .byte $FF
sfxd_clack:
        .byte 0, $70, $81, $00, $02
        .byte 1, $70, $80, $00, $02
        .byte $FF
sfxd_tink:
        .byte 0, $70, $11, $07, $00
        .byte 1, $70, $10, $07, $00
        .byte $FF
; mumbling down the phone: a few short syllables
sfxd_talk:
        .byte 0, $12, $11, $00, $63
        .byte 4, $12, $10, $00, $63
        .byte 6, $16, $11, $00, $63
        .byte 9, $16, $10, $00, $63
        .byte 11, $10, $11, $00, $63
        .byte 15, $10, $10, $00, $63
        .byte $FF
; one toothbrush stroke: "chhh" -- a burst of mid-high noise that fades
sfxd_brush:
        .byte 0, $48, $81, $04, $00
        .byte 3, $48, $80, $04, $00
        .byte $FF
sfxd_step:
        .byte 0, $06, $81, $00, $01
        .byte 1, $06, $80, $00, $01
        .byte $FF
sfxd_blip:
        .byte 0, $40, $11, $00, $03
        .byte 2, $40, $10, $00, $03
        .byte $FF

;---------------------------------------------------------------------------------------
; Tune data: (melody note, bass note, frames). MIDI note numbers.
;---------------------------------------------------------------------------------------
; Fur Elise (Beethoven, public domain), opening phrase.
tuned_piano:
        .byte 76,0,10, 75,0,10, 76,0,10, 75,0,10, 76,0,10, 71,0,10, 74,0,10, 72,0,10
        .byte 69,45,20, 0,52,10, 60,57,10, 64,0,10, 69,0,10
        .byte 71,40,20, 0,52,10, 64,56,10, 68,0,10, 71,0,10
        .byte 72,45,20, 0,52,10, 64,57,10
        .byte 76,0,10, 75,0,10, 76,0,10, 75,0,10, 76,0,10, 71,0,10, 74,0,10, 72,0,10
        .byte 69,45,20, 0,52,10, 60,57,10, 64,0,10, 69,0,10
        .byte 71,40,20, 0,52,10, 64,56,10, 72,0,10, 71,0,10
        .byte 69,45,40, 0,0,20
        .byte $FF
; A bouncy record: walking bass boogie.
tuned_record:
        .byte 67,43,8, 0,47,8, 70,50,8, 0,52,8, 72,53,8, 70,52,8, 67,50,8, 0,47,8
        .byte 67,43,8, 0,47,8, 70,50,8, 0,52,8, 72,53,8, 70,52,8, 67,50,8, 0,47,8
        .byte 72,48,8, 0,52,8, 75,55,8, 0,57,8, 77,58,8, 75,57,8, 72,55,8, 0,52,8
        .byte 67,43,8, 0,47,8, 70,50,8, 0,52,8, 72,53,8, 70,52,8, 67,50,8, 0,47,8
        .byte 74,50,8, 72,54,8, 70,57,8, 67,54,8, 72,48,8, 70,52,8, 67,55,8, 0,52,8
        .byte 67,43,16, 0,0,16
        .byte $FF
; Ode to Joy (Beethoven, public domain).
tuned_ode:
        .byte 76,48,12, 76,0,12, 77,55,12, 79,0,12
        .byte 79,43,12, 77,0,12, 76,50,12, 74,0,12
        .byte 72,48,12, 72,0,12, 74,55,12, 76,0,12
        .byte 76,43,18, 74,0,6, 74,50,24
        .byte 76,48,12, 76,0,12, 77,55,12, 79,0,12
        .byte 79,43,12, 77,0,12, 76,50,12, 74,0,12
        .byte 72,48,12, 72,0,12, 74,55,12, 76,0,12
        .byte 74,43,18, 72,0,6, 72,48,24, 0,0,24
        .byte $FF
; Minuet in G (Petzold, once credited to Bach; public domain).
tuned_minuet:
        .byte 74,55,14, 67,0,7, 69,0,7, 71,0,7, 72,0,7
        .byte 74,59,14, 67,55,14, 67,0,14
        .byte 76,48,14, 72,0,7, 74,0,7, 76,0,7, 78,0,7
        .byte 79,55,14, 67,0,14, 67,0,14
        .byte 72,52,14, 74,0,7, 72,0,7, 71,0,7, 69,0,7
        .byte 71,55,14, 72,0,7, 71,0,7, 69,0,7, 67,0,7
        .byte 66,50,14, 67,0,7, 69,0,7, 71,0,7, 67,0,7
        .byte 69,50,42, 0,0,14
        .byte $FF
; The Entertainer (Scott Joplin, 1902, public domain), the opening.
tuned_entertainer:
        .byte 74,0,5, 75,0,5, 76,48,10, 84,0,20, 76,52,10, 84,0,20, 76,55,10, 84,48,30, 0,0,10
        .byte 84,0,10, 86,0,10, 87,0,10, 88,48,10, 84,0,10, 86,0,10, 88,52,20
        .byte 83,55,10, 86,0,20, 84,48,30, 0,0,20
        .byte $FF
; The Can-Can (Offenbach's galop, public domain).
tuned_cancan:
        .byte 72,48,12, 74,0,6, 77,43,6, 76,0,6, 74,0,6, 79,48,12, 79,43,12
        .byte 79,48,6, 81,0,6, 76,43,6, 77,0,6, 74,50,12, 74,43,12
        .byte 74,50,6, 77,0,6, 76,43,6, 74,0,6, 72,48,6, 84,0,6, 83,43,6, 81,0,6
        .byte 79,48,6, 77,0,6, 76,43,6, 74,0,6, 72,48,12, 0,0,12
        .byte $FF
; Oh! Susanna (Stephen Foster, public domain).
tuned_susanna:
        .byte 72,0,8, 74,0,8
        .byte 76,48,16, 79,0,16, 79,55,16, 81,0,16
        .byte 79,48,16, 76,0,16, 72,55,24, 74,0,8
        .byte 76,48,16, 76,0,16, 74,55,16, 72,0,16
        .byte 74,43,48, 0,0,16, 72,0,8, 74,0,8
        .byte 76,48,16, 79,0,16, 79,55,16, 81,0,16
        .byte 79,48,16, 76,0,16, 72,55,24, 74,0,8
        .byte 76,48,16, 76,0,16, 74,43,16, 74,0,16
        .byte 72,48,48, 0,0,16
        .byte $FF
; Camptown Races (Stephen Foster, public domain).
tuned_camptown:
        .byte 79,48,10, 79,0,10, 76,55,10, 79,0,10
        .byte 81,48,10, 79,0,10, 76,55,20
        .byte 76,43,10, 74,0,30, 76,43,10, 74,0,30
        .byte 79,48,10, 79,0,10, 76,55,10, 79,0,10
        .byte 81,48,10, 79,0,10, 76,55,20
        .byte 74,43,20, 76,0,10, 74,0,10, 72,48,30, 0,0,10
        .byte $FF
; Short jingle for dancing / exercise.
tuned_dance:
        .byte 72,48,6, 0,0,6, 72,48,6, 76,0,6, 79,55,12, 76,0,6, 79,0,6
        .byte 81,53,12, 79,0,6, 76,0,6, 72,48,12, 0,0,12
        .byte $FF
