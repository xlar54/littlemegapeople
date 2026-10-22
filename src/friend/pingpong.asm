; friend/pingpong.asm -- ping pong with his friend at the attic desk (see friend/visit.asm)
;---------------------------------------------------------------------------------------
; Once a visit one of them asks the other for a game. Up they go to the attic
; desk: Larry at its left end, Joey at its right. Larry clears it (the
; typewriter and papers away, a net across the middle) and they knock the
; ball back and forth over the net -- a bounce on the far side each shot --
; till one of them misses and it flies off the end onto the floor: a point to
; the other. Five points, then the desk is put back.
; Larry's activity (A_PINGPONG) runs the game; Joey's job (FRJ_PONG) stands
; at his end with his paddle for as long as Larry's playing.
;---------------------------------------------------------------------------------------
PP_LX           = 203       ; the ball (its left edge) at Larry's paddle...
PP_JX           = 251       ; ...and at Joey's
PP_HIT_Y        = 48        ; (its top) on a paddle
PP_TABLE_Y      = 51        ; bouncing on the table
PP_MID          = 228       ; left of this, Larry's end (for the swings)
PP_POINTS       = 5
PP_SPOT         = 11        ; Joey's spot at the right end (fj_ tables)
PP_SWING        = 8         ; frames a swing shows

pp_ph:          .byte 0     ; 0 clearing the desk, 1 waiting for Joey, 2 the
                            ;  serve, 3 the rally, 4 a miss, 5 game over
pp_t:           .word 0
pp_dir:         .byte 0     ; the ball's going 0 right (Larry hit it), 1 left
pp_pos:         .byte 0     ; how far it's come this shot
pp_left:        .byte 0     ; returns still to come this rally
pp_pts:         .byte 0     ; points played
pp_lw:          .byte 0     ;  ...won by Larry
pp_swl:         .byte 0     ; frames left of Larry's swing...
pp_swr:         .byte 0     ;  ...and Joey's

; a shot, every other pixel across: the ball's height over the table --
; up over the net, down to bounce on the far side, up to the paddle
pp_h:   .byte 3, 4, 5, 6, 7, 8, 8, 9, 9, 9, 9, 9, 8, 8, 7, 6, 4, 2, 0, 1, 2, 3, 3, 3
PP_SHOT_N       = * - pp_h
; a miss: on past the paddle, down onto the floor, a bounce and a roll
pp_my:  .byte 49, 50, 51, 52, 54, 56, 58, 60, 62, 64, 62, 61, 60, 61, 62, 64
        .byte 64, 64, 64, 64, 64, 64
pp_mdx: .byte 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1
        .byte 1, 1, 1, 0, 1, 0
PP_MISS_N       = * - pp_mdx

; the ball where it's got to (pp_pos from whoever hit it)
pp_setx:
        lda pp_dir
        bne l_psx_left
        clc
        lda #<PP_LX
        adc pp_pos
        sta ball_x
        lda #>PP_LX
        adc #0
        sta ball_x+1
        rts
l_psx_left:
        sec
        lda #<PP_JX
        sbc pp_pos
        sta ball_x
        lda #>PP_JX
        sbc #0
        sta ball_x+1
        rts

; whoever's hitting it now (pp_dir) swings: pock, and it's off
pp_hit:
        lda #PP_SWING
        ldx pp_dir
        bne +
        sta pp_swl
        bra ++
+       sta pp_swr
+       lda #0
        sta pp_pos
        lda #PP_HIT_Y
        sta ball_y
        jsr pp_setx
        lda #SFX_POCK
        jmp sfx_play

st_pingpong:
        lda #1                  ; facing down the desk, leaning over it to
        sta p_flip              ;  clear it
        lda #PM_BENDSIDE
        sta p_mode
        lda #0
        sta pp_ph
        sta pp_t
        sta pp_t+1
        sta pp_pts
        sta pp_lw
        sta pp_swl
        sta pp_swr
        sta ball_vis
        #SAY l_say_ppclear
        lda #240                ; (four minutes at most)
        jmp set_timer_secs

tk_pingpong:
        lda pp_swl              ; the swings
        beq +
        dec pp_swl
+       lda pp_swr
        beq +
        dec pp_swr
+       inc pp_t
        bne +
        inc pp_t+1
+       lda pp_ph
        cmp #2                  ; (Joey gone off in the middle of it: that's
        bcc l_tkpp_0            ;  that)
        lda fr_job
        cmp #FRJ_PONG
        beq l_tkpp_0
        jmp pp_stop
l_tkpp_0:
        lda pp_ph
        bne l_tkpp_1
        ; 0: the typewriter and papers off the desk, the net up
        lda pp_t
        cmp #40
        bne +
        ldx #PATCH_PONG
        jsr patch_apply
        lda #SFX_CLACK
        jmp sfx_play
+       cmp #70
        bne l_tkpp_out
        lda #PM_PONG            ; his paddle, ready
        sta p_mode
        bra l_tkpp_next
l_tkpp_1:
        cmp #1
        bne l_tkpp_2
        ; 1: Joey at his end yet?
        lda fr_job
        cmp #FRJ_PONG
        bne +
        lda FR(p_mode)
        cmp #PM_PONG
        bne +
        lda #0                  ; Larry serves first
        sta pp_dir
        bra l_tkpp_next
+       lda pp_t                ; (asked for by you, not between them: Larry
        cmp #1                  ;  calls him up, once)
        bne l_tkpp_wait
        lda pp_t+1
        bne l_tkpp_wait
        jsr pp_summon
l_tkpp_wait:
        lda pp_t+1              ; (half a minute and no Joey: never mind)
        cmp #6
        bcc l_tkpp_out
        jmp pp_stop
l_tkpp_next:
        inc pp_ph
        lda #0
        sta pp_t
        sta pp_t+1
l_tkpp_out:
        rts
l_tkpp_2:
        cmp #2
        bne l_tkpp_3
        ; 2: the serve -- the ball on the server's paddle, a moment, then off
        lda pp_t
        cmp #1
        bne +
        lda #0
        sta pp_pos
        jsr pp_setx
        lda #PP_HIT_Y
        sta ball_y
        lda #1
        sta ball_vis
        lda #8                  ; (2-9 returns before someone misses)
        jsr rnd_range
        clc
        adc #2
        sta pp_left
        rts
+       cmp #50
        bne l_tkpp_out
        jsr pp_hit
        bra l_tkpp_next
l_tkpp_3:
        cmp #3
        bne l_tkpp_4
        ; 3: the rally
        inc pp_pos
        inc pp_pos
        lda pp_pos
        lsr
        tax
        cpx #PP_SHOT_N
        bcs l_tkpp_there
        lda #PP_TABLE_Y
        sec
        sbc pp_h,x
        sta ball_y
        lda pp_h,x              ; (on the table: pick)
        bne +
        lda #SFX_PICK
        jsr sfx_play
+       jmp pp_setx
l_tkpp_there:
        lda pp_left             ; back it goes...
        beq l_tkpp_miss
        dec pp_left
        lda pp_dir
        eor #1
        sta pp_dir
        jmp pp_hit
l_tkpp_miss:
        lda #PP_SWING           ; ...or he swings and misses
        ldx pp_dir
        bne +
        sta pp_swr
        bra l_tkpp_next
+       sta pp_swl
        bra l_tkpp_next
l_tkpp_4:
        cmp #4
        bne l_tkpp_5
        ; 4: the miss -- off the end, onto the floor; the point; the next serve
        ldx pp_t
        dex
        cpx #PP_MISS_N
        bcs l_tkpp_after
        lda pp_mdx,x
        clc
        adc pp_pos
        sta pp_pos
        lda pp_my,x
        sta ball_y
        cpx #9                  ; (it lands, and again)
        beq +
        cpx #15
        bne ++
+       lda #SFX_PICK
        jsr sfx_play
+       jmp pp_setx
l_tkpp_after:
        lda pp_t
        cmp #PP_MISS_N + 10
        bne +
        jmp pp_point
+       cmp #PP_MISS_N + 110
        bne l_tkpp_out2
        lda #0
        sta ball_vis
        lda pp_pts              ; that's the game?
        cmp #PP_POINTS
        bcs l_tkpp_over
        lda #2                  ; the winner serves (pp_dir: who hit it last)
        sta pp_ph
        lda #0
        sta pp_t
        sta pp_t+1
l_tkpp_out2:
        rts
l_tkpp_over:
        jsr pp_result
        jmp l_tkpp_next
l_tkpp_5:
        ; 5: game over: a moment, and done
        lda pp_t
        cmp #150
        bne l_tkpp_out2
pp_stop:
        lda #0
        sta act_timer
        sta act_timer+1
        rts

; Joey not on his way to his end (you asked for the game): off he goes, as
; soon as he's free -- and he's up for it.
pp_summon:
        lda fr_state
        cmp #FRS_VISIT
        bne l_pps_out
        lda fr_job
        cmp #FRJ_PONG
        beq l_pps_out
        lda fr_jgo
        cmp #PP_SPOT + 1
        beq l_pps_out
        lda fr_want
        cmp #PP_SPOT + 1
        beq l_pps_out
        lda #PP_SPOT + 1
        sta fr_want
        lda fr_done             ; (played, this visit)
        ora #FD_PONG
        sta fr_done
        lda #<l_fr_ppyes
        sta fr_rp
        lda #>l_fr_ppyes
        sta fr_rp+1
        lda #40
        sta fr_rt
l_pps_out:
        rts
        .section ftext
l_fr_ppyes:     .null "Ping pong? You're on!"
        .send ftext

; a point to whoever hit it last: he says so
pp_point:
        inc pp_pts
        lda #3
        jsr rnd_range
        asl
        tax
        lda pp_dir
        bne l_ppt_joey
        inc pp_lw
        lda pp_say_l,x
        pha
        lda pp_say_l+1,x
        tay
        plx
        jmp ui_say
l_ppt_joey:
        lda pp_say_j,x
        pha
        lda pp_say_j+1,x
        tay
        plx
        jmp fr_say_if

; the game's over: who won, and Joey's answer
pp_result:
        lda pp_lw
        cmp #PP_POINTS / 2 + 1
        bcc +
        #SAY l_say_ppwin
        lda #<l_fr_pplose
        ldx #>l_fr_pplose
        bra ++
+       #SAY l_say_pplose
        lda #<l_fr_ppwin
        ldx #>l_fr_ppwin
+       sta fr_rp
        stx fr_rp+1
        lda #110
        sta fr_rt
        rts

en_pingpong:
        lda #0
        sta ball_vis
        sta pp_swl
        sta pp_swr
        lda patch_state + PATCH_PONG    ; the desk put back as it was
        beq +
        ldx #PATCH_PONG
        jsr patch_remove
        lda #SFX_CLACK
        jsr sfx_play
+       lda #PM_STAND
        sta p_mode
        lda #6
        jmp mood_up

pp_say_l:       .word l_say_pp0, l_say_pp1, l_say_pp2
pp_say_j:       .word l_fr_pp0, l_fr_pp1, l_fr_pp2
        .section ftext
l_say_ppclear:  .null "Let me clear the desk off."
l_say_pp0:      .null "Ha! My point!"
l_say_pp1:      .null "Too fast for you, Joey?"
l_say_pp2:      .null "Got you there!"
l_fr_pp0:       .null "My point!"
l_fr_pp1:       .null "Ha! Didn't see that coming, huh?"
l_fr_pp2:       .null "Gotcha!"
l_say_ppwin:    .null "That's game! I win!"
l_say_pplose:   .null "You win, Joey! Good game."
l_fr_pplose:    .null "Rematch next time!"
l_fr_ppwin:     .null "Good game! That was fun."
nm_pingpong:    .null " is playing ping pong with Joey."
        .send ftext

; (swapped) Joey's end of it: at his end of the desk, paddle ready, while
; Larry's on his way to the game or at it.
fr_pong:
        lda fr_jt+1
        bne +
        lda fr_jt
        cmp #1
        bne +
        lda #PM_PONG
        sta p_mode
        lda #0
        sta p_flip
+       lda fr_jt+1             ; (five minutes at most)
        cmp #60
        bcs l_fpp_off
        lda FR(p_pending)
        cmp #A_PINGPONG
        beq l_fpp_on
        lda FR(p_goal)
        cmp #A_PINGPONG
        bne l_fpp_off
l_fpp_on:
        sec
        rts
l_fpp_off:
        jsr fr_activity_over
        jmp fr_job_end

; (talking, unswapped) A game of ping pong? Once a visit, one of them asks;
; C = 1: the conversation's started (and agreed: off they go after it).
fr_pong_maybe:
        .if AUTOFRIEND != 10    ; (test build 10: straight away)
        lda #3
        jsr rnd_range
        bne l_fpm_no
        .endif
        lda fr_done             ; (played already this visit)
        and #FD_PONG
        bne l_fpm_no
        lda health              ; (not when he's poorly, nor at his dinner)
        cmp #40
        bcc l_fpm_no
        lda p_act
        cmp #A_MEAL
        beq l_fpm_no
        lda fr_done
        ora #FD_PONG
        sta fr_done
        lda #A_PINGPONG         ; Larry to his end after it...
        sta fr_after
        lda #PP_SPOT + 1        ; ...and Joey to his
        sta fr_ask
        jsr rnd                 ; who asks
        and #1
        ldx #<cv_pong_tbl
        ldy #>cv_pong_tbl
        jsr fr_convo_start
        sec
        rts
l_fpm_no:
        clc
        rts
cv_pong_tbl:    .word cv_pong0, cv_pong1
        .section ftext
cv_pong0:
        .byte 0
        .null "Fancy a game of ping pong, Joey?"
        .byte 1
        .null "You're on! Prepare to lose!"
        .byte $FF
cv_pong1:
        .byte 1
        .null "Hey, want to play some ping pong?"
        .byte 0
        .null "Sure! Up to the attic!"
        .byte $FF
        .send ftext

; Drawing either of them with his paddle: ready, or swinging (Larry's end
; or Joey's, by where he stands); 7 columns of padding in front.
pong_person_sprite:
        #SETACT 0, SPR_PONG0
        ldx pp_swl
        lda p_x+1
        bne l_pps_r
        lda p_x
        cmp #PP_MID
        bcc l_pps_sw
l_pps_r:
        ldx pp_swr
l_pps_sw:
        txa
        beq l_pps_pad
        #SETACT 0, SPR_PONG1
l_pps_pad:
        lda p_flip
        bne l_pps_done
        sec                     ; facing left: the padding's on the left
        lda act_xl2+0
        sbc #7
        sta act_xl2+0
        lda act_xh2+0
        sbc #0
        sta act_xh2+0
l_pps_done:
        jmp l_ab_person_done
