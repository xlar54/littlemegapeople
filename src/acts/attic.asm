; acts/attic.asm -- activities: the attic: TV, records, dancing, piano; changing clothes

; --- attic -----------------------------------------------------------------------------
; Watching TV: sitting in the blue attic chair, facing the set.
SITTV_X         = 97
SITTV_Y         = 35
CHAIRFRONT_X    = 99            ; the chair's back and arm, drawn over him
CHAIRFRONT_Y    = 44

st_tv:
        #POSE SPR_SITTV, SITTV_X, SITTV_Y
        lda #6                  ; chair back/arm overlay (in front of him)
        sta fx_kind
        lda #15
        jmp set_timer_secs
en_tv:
        lda #4
        jsr mood_up
        jsr rnd                 ; about half the time he switches it off after
        and #1
        beq +
        lda #A_TVOFF
        sta p_pending
+       rts

; Leaning over the set to work the knob.
st_tvswitch:
        lda #PM_BENDSIDE
        sta p_mode
        lda #2
        jmp set_timer_secs
en_tvon:
        lda #1
        sta tv_on
        lda #SFX_CLACK
        jsr sfx_play
        lda #A_TV               ; now sit down and watch
        sta p_pending
        rts
en_tvoff:
        lda #0
        sta tv_on
        lda #SFX_CLACK
        jmp sfx_play
; Records: facing the stereo he bends to pick one from the shelf underneath,
; straightens up and puts it on. It plays for a few minutes whatever he does
; next (the tone arm shimmers, the panel lights dance); often he dances to it.
RECORD_FRAMES   = 9000          ; about 3 minutes
record_left:    .word 0         ; frames of music left (0 = not playing)
record_tune:    .byte 0
rec_t:          .byte 0

; A = height: his little hands working away at either side of him, bent
; over a shelf or drawer (the effect is cleared when the activity ends).
hands_rummage:
        sta fx_hands_y
        sec
        lda p_x
        sbc #7
        sta fx_hands_x
        lda p_x+1
        sbc #0
        sta fx_hands_x+1
        lda #7
        sta fx_kind
        rts

REC_CLOSE       = 4             ; he steps up this close to the stereo
st_record:
        lda #PM_BEND            ; rummaging through the records
        sta p_mode
        lda p_y
        sec
        sbc #REC_CLOSE
        sta p_y
        lda #51                 ; his hands in the record shelf
        jsr hands_rummage
        lda #0
        sta rec_t
        lda #4
        jmp set_timer_secs
tk_record:
        inc rec_t
        lda rec_t
        cmp #70                 ; this one: stand up with it
        bne +
        lda #PM_BACKSTAND
        sta p_mode
        lda #0
        sta fx_kind
        rts
+       cmp #110                ; on it goes
        bne +
        jmp record_start
+       bcs +
        and #15                 ; rummaging: sleeves rustle
        bne +
        lda #SFX_STEP
        jmp sfx_play
+       rts
en_record:
        lda p_y                 ; back out to the middle of the floor
        clc
        adc #REC_CLOSE
        sta p_y
        lda rec_t
        cmp #110
        bcc +                   ; (interrupted before it went on)
        lda #6
        jsr mood_up
        lda health              ; (not when he's sick)
        cmp #40
        bcc +
        lda #3                  ; and two times in three, a dance
        jsr rnd_range
        beq +
        lda #A_DANCE
        sta p_pending
+       rts

record_start:
        lda #<RECORD_FRAMES
        sta record_left
        lda #>RECORD_FRAMES
        sta record_left+1
        lda #4                  ; one of his records
        jsr rnd_range
        tax
        lda record_tunes,x
        sta record_tune
        jsr tune_play
        lda #1                  ; the song plays through once
        sta tune_once
        rts
record_stop:
        lda record_left
        ora record_left+1
        beq +
        lda #0
        sta record_left
        sta record_left+1
        lda #TUNE_NONE
        jmp tune_play
+       rts
; every sim tick: the record runs down, or its song's over
record_tick:
        lda record_left
        ora record_left+1
        beq l_rk_out
        lda tune_id             ; the song's finished: the record stops
        bne +
        lda #0
        sta record_left
        sta record_left+1
        rts
+
        lda record_left
        bne +
        dec record_left+1
+       dec record_left
        lda record_left
        ora record_left+1
        bne l_rk_out
        lda #TUNE_NONE          ; the end of the side
        jmp tune_play
l_rk_out:
        rts

; Asked to stop the record: up to the stereo, click, quiet.
st_recstop:
        lda #PM_BACKSTAND
        sta p_mode
        lda #0
        sta rec_t
        lda #1
        jmp set_timer_secs
tk_recstop:
        inc rec_t
        lda rec_t
        cmp #30
        bne +
        jsr record_stop
        lda #SFX_TINK
        jsr sfx_play
        #SAY l_say_quiet
+       rts
        .section ftext
l_say_quiet:    .null "There, all quiet."
        .send ftext
        .section ftext
say_norecord:   .null "There's no record on."
        .send ftext

st_dance:
        lda #PM_DANCE
        sta p_mode
        lda record_left
        ora record_left+1
        bne +                   ; dancing to the record
        lda #TUNE_DANCE         ; (asked to dance with no record on: hum along)
        jsr tune_play
+       lda #8
        jmp set_timer_secs
en_dance:
        lda record_left
        ora record_left+1
        bne +
        lda #TUNE_NONE
        jsr tune_play
+       lda energy
        sec
        sbc #3
        bcs +
        lda #0
+       sta energy
        lda #5
        jmp mood_up
st_piano:
        jsr record_stop         ; can't hear himself play over it
        #POSE SPR_PIANO, POSE_PIANO_X, POSE_PIANO_Y
        lda #4                  ; one of his pieces
        jsr rnd_range
        tax
        lda piano_tunes,x
        jsr tune_play
        lda #22
        jmp set_timer_secs
tk_piano:
        lda p_anim
        and #63
        bne +
        jsr fx_note_on_piano
+       rts
en_piano:
        lda #TUNE_NONE
        jsr tune_play
        lda #5
        jmp mood_up
; Changing clothes at the bedroom closet: the door opens, he steps in behind
; it, changes (pyjamas in the evening, else today's shirt), steps out and
; shuts the door.
chg_t:          .byte 0
st_change:
        ldx #PATCH_CLOSET
        jsr patch_apply
        lda #SFX_DOOR
        jsr sfx_play
        lda #0
        sta chg_t
        lda #5
        jmp set_timer_secs
tk_change:
        inc chg_t
        lda chg_t
        cmp #20                 ; in he goes
        bne +
        lda #PM_HIDDEN
        sta p_mode
        rts
+       cmp #120                ; changed
        bne +
        jmp change_outfit
+       cmp #180                ; out again
        bne +
        lda #PM_FRONT
        sta p_mode
        rts
+       cmp #215                ; door shut
        bne +
        ldx #PATCH_CLOSET
        jmp patch_remove
+       rts
en_change:
        ldx #PATCH_CLOSET
        jsr patch_remove
        lda chg_t
        cmp #120
        bcs +
        jsr change_outfit       ; (cut short: still changed)
+       lda #PM_STAND
        sta p_mode
        rts

; Pyjamas from 6pm until he gets up, else day clothes in today's colour.
change_outfit:
        jsr wake_hour
        cmp clock_hour
        beq l_co_day
        bcs l_co_pj
        lda clock_hour
        cmp #18
        bcs l_co_pj
l_co_day:
        jsr shirt_pick
        lda #0
        bra +
l_co_pj:
        lda #1
+       sta outfit
        lda #1
        sta ui_dirty
        rts

; Today's shirt: a colour for each day of the week, into the day outfit.
shirt_pick:
        jsr day_of_week
        sta l_sp_n
        asl
        clc
        adc l_sp_n
        asl                     ; * 6
        tax
        ldy #0
-       lda shirt_rgb,x
        sta outfit_rgb,y
        cpy #3
        bcs +
        sta outfit_rgb+12,y     ; the (hidden) dots match the shirt
+       inx
        iny
        cpy #6
        bne -
        rts
l_sp_n: .byte 0
shirt_rgb:      ; shirt, shirt shade: Sunday .. Saturday
        .byte 34,170,170, 17,102,102        ; teal
        .byte 34,102,255, 17,51,170         ; blue
        .byte 221,51,51, 153,17,17          ; red
        .byte 51,170,68, 17,102,34          ; green
        .byte 238,204,51, 170,136,17        ; yellow
        .byte 136,68,204, 85,34,136         ; purple
        .byte 238,136,34, 170,85,17         ; orange
; Typing a letter, like a real typewriter: three lines, each a key every 8
; frames with the carriage stepping along (his right to his left), then the
; return -- the carriage back with the bell's ding, a moment, and the next
; line.
CAR_STEP        = 20        ; frames per pixel of carriage travel
CAR_TYPING      = 120       ; frames of typing a line
CAR_NEXT        = 140       ; ...and with the return, the next line starts
car_t:          .byte 0
car_line:       .byte 0     ; lines typed
car_pos:        .byte 0     ; the carriage: 0 home, 1-5 pixels along
tk_typing:
        lda car_line
        cmp #3                  ; (that's the letter: done)
        bcs l_tkt_out
        inc car_t
        lda car_t
        cmp #CAR_TYPING
        bcs l_tkt_return
        and #7                  ; a key
        bne +
        lda #SFX_TYPE
        jsr sfx_play
+       ldx #5                  ; the carriage steps along
-       lda car_steps-1,x
        cmp car_t
        beq l_tkt_step
        dex
        bne -
l_tkt_out:
        rts
l_tkt_step:
        txa
        jmp carriage_set
l_tkt_return:
        bne +                   ; (CAR_TYPING: the return)
        lda #0                  ; back it goes: ding!
        jsr carriage_set
        lda #SFX_DING
        jmp sfx_play
+       cmp #CAR_NEXT           ; the next line
        bcc l_tkt_out
        lda #0
        sta car_t
        inc car_line
        lda car_line            ; (the last: done soon)
        cmp #3
        bcc l_tkt_out
        lda #25
        sta act_timer
        lda #0
        sta act_timer+1
        rts
car_steps:      .byte CAR_STEP, CAR_STEP * 2, CAR_STEP * 3, CAR_STEP * 4, CAR_STEP * 5

; A = 0-5: the carriage there (the patch for it, or none: home).
carriage_set:
        cmp car_pos
        beq l_cs_out
        pha
        ldx car_pos             ; (the old one off -- quietly, by the new one
        beq +                   ;  going over it, unless it's home again)
        pla
        pha
        bne l_cs_over
        txa
        clc
        adc #PATCH_CARRIAGE - 1
        tax
        jsr patch_remove
        bra +
l_cs_over:
        txa
        clc
        adc #PATCH_CARRIAGE - 1
        tax
        lda #0
        sta patch_state,x
+       pla
        sta car_pos
        beq l_cs_out
        clc
        adc #PATCH_CARRIAGE - 1
        tax
        jmp patch_apply
l_cs_out:
        rts

