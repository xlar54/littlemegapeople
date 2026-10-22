; acts/middle.asm -- activities: the middle floor: sleep, exercise, teeth, the toilet

; --- middle floor ----------------------------------------------------------------------
st_sleep:
        lda #0
        sta sleep_min
        lda #PM_HIDDEN
        sta p_mode
        lda #<$FFFF
        sta act_timer
        lda #>$FFFF
        sta act_timer+1
        jsr fx_zz_on
        jmp lights_update
tk_sleep:
        ; get up for food or water if he needs it and there is some
        lda thirst
        cmp #75
        bcc +
        lda water
        bne l_tks_wake
+       lda hunger
        cmp #75
        bcc +
        lda food
        bne l_tks_wake
+       ; otherwise wake in the daytime: in the morning, or after a nap of an
        ; hour (or once rested)
        jsr wake_hour           ; (at his getting-up hour the alarm wakes him)
        cmp clock_hour
        beq l_tks_out
        bcs l_tks_out
        jsr bedtime_hour
        cmp clock_hour
        beq l_tks_out
        bcc l_tks_out
        lda sleep_min
        cmp #60
        bcs l_tks_wake
        lda energy
        cmp #70
        bcc l_tks_out
l_tks_wake:
        lda #0
        sta act_timer
        sta act_timer+1
l_tks_out:
        rts
en_sleep:
        lda outfit              ; up after a night's sleep (not a nap): the
        cmp #1                  ;  toilet first thing; he stays in his
        bne +                   ;  pyjamas till his shower
        jsr rest_plea_check     ; (woken up too often? a letter about it)
        lda #WC_EVERY
        sta wc_need
+
        lda #PM_STAND
        sta p_mode
        rts
st_exercise:
        lda #PM_JUMP
        sta p_mode
        lda #10
        jmp set_timer_secs
en_exercise:
        lda health
        cmp #95
        bcs +
        clc
        adc #5
        sta health
+       lda energy
        sec
        sbc #5
        bcs +
        lda #0
+       sta energy
        lda #2
        jmp mood_up
st_brush:
        #POSE SPR_BRUSH, POSE_BRUSH_X, POSE_BRUSH_Y
        lda #5
        jmp set_timer_secs
; scrub up and down, a little "shh" on each stroke
tk_brush:
        lda p_anim
        and #4
        tay
        lda #<SPR_BRUSH
        ldx #>SPR_BRUSH
        cpy #0
        beq +
        lda #<SPR_BRUSHUP
        ldx #>SPR_BRUSHUP
+       sta pose_spr
        stx pose_spr+1
        lda p_anim              ; a "chhh" on every stroke, up and down
        and #3
        bne +
        lda #SFX_BRUSH
        jsr sfx_play
+       rts
en_brush:
        lda #1
        jmp mood_up
; The toilet: the WC door opens, he steps in behind it, it closes; a while
; later (and a flush) it opens, he steps out, it closes; then he washes up.
wc_t:           .byte 0

; The toilet first thing, then every three hours.
WC_EVERY        = 90            ; in 2-minute steps: three hours
wc_need:        .byte 0
showered:       .byte 0         ; 1 = had today's shower
st_wc:
        lda #0
        sta wc_need
        ldx #PATCH_WC
        jsr patch_apply
        lda #SFX_DOOR
        jsr sfx_play
        lda #0
        sta wc_t
        lda #6
        jmp set_timer_secs
tk_wc:
        lda wc_t
        cmp #255
        beq +
        inc wc_t
+       lda wc_t
        cmp #20                 ; steps in
        bne +
        lda #PM_HIDDEN
        sta p_mode
        rts
+       cmp #32                 ; door shut behind him
        bne +
        ldx #PATCH_WC
        jmp patch_remove
+       ; the way out, counted down from the end of the visit
        lda act_timer+1
        bne l_tkw_out
        lda act_timer
        cmp #140
        bne +
        jmp flush_play
+       cmp #50                 ; door opens
        bne +
        ldx #PATCH_WC
        jsr patch_apply
        lda #SFX_DOOR
        jmp sfx_play
+       cmp #38                 ; he steps out
        bne +
        lda #PM_STAND
        sta p_mode
        rts
+       cmp #16                 ; and the door closes
        bne l_tkw_out
        ldx #PATCH_WC
        jmp patch_remove
l_tkw_out:
        rts
en_wc:
        ldx #PATCH_WC           ; (in case he was interrupted)
        jsr patch_remove
        lda #A_WASH             ; then wash his hands
        sta p_pending
        rts

