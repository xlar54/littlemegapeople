; friend/seat.asm -- his friend: the seat at the kitchen table; Larry's side of their cards, video games, the introduction (see friend/visit.asm)
;---------------------------------------------------------------------------------------
; A seat at the end of the kitchen table: whenever Larry's there (cards, or a
; meal) he comes and sits with him, side on, on a chair that appears for him.
;---------------------------------------------------------------------------------------
SEAT_X          = 146       ; where he stands to sit down
SIT_X           = 135       ; the sitting sprite (knees under the table end)
SIT_Y           = 163
CHAIRSIDE_X     = 141
CHAIRSIDE_Y     = 172
FR_PLATE_X      = 127       ; his plate on the table, in front of him
FR_PLATE_Y      = 177
fr_seated:      .byte 0
fr_to_seat:     .byte 0     ; on his way to the seat
fr_after:       .byte 0     ; what Larry does once this conversation's over
fr_games:       .byte 0     ; card games this visit

; (his state swapped in) C = 1: Larry's at the table, or on his way there.
fr_larry_table:
        lda FR(p_state)
        cmp #PS_ACT
        bne +
        lda FR(p_act)
        bra l_flt_is
+       cmp #PS_IDLE
        beq l_flt_no
        lda FR(p_goal)
l_flt_is:
        cmp #A_CARDSF
        beq l_flt_yes
        cmp #A_MEAL
        beq l_flt_yes
        cmp #A_CARDS
        beq l_flt_yes
l_flt_no:
        clc
        rts
l_flt_yes:
        sec
        rts

; (swapped) Each frame: to the table, sit, play; up again when Larry goes.
; C = 1: that's all for this frame.
fr_seat_tick:
        lda fr_state
        cmp #FRS_VISIT
        bne l_fst_no
        lda fr_seated
        beq l_fst_not
        jsr fr_larry_table
        bcs l_fst_stay
        lda #0                  ; Larry's gone: up he gets
        sta fr_seated
        lda #PM_STAND
        sta p_mode
        lda #FLOOR0_Y
        sta p_y
        lda #PS_ACT
        sta p_state
        lda #60
        sta fr_pause
        lda #0
        sta fr_pause+1
        sec
        rts
l_fst_stay:
        ldx #<SPR_SITSIDE0      ; playing cards: now and then a card goes down
        ldy #>SPR_SITSIDE0
        lda FR(p_act)
        cmp #A_MEAL             ; eating with him: chewing
        bne l_fst_cards
        lda p_anim
        and #16
        beq l_fst_set
        ldx #<SPR_SITSIDECHEW
        ldy #>SPR_SITSIDECHEW
        bra l_fst_set
l_fst_cards:
        cmp #A_CARDSF
        bne l_fst_set
        lda p_anim
        and #$60
        cmp #$60
        bne l_fst_set
        ldx #<SPR_SITSIDE1
        ldy #>SPR_SITSIDE1
l_fst_set:
        stx pose_spr
        sty pose_spr+1
        lda #`SPR_SITSIDE0
        sta pose_spr+2
        sec
        rts
l_fst_not:
        lda fr_to_seat
        bne l_fst_no
        jsr fr_larry_table
        bcc l_fst_no
        lda p_state
        cmp #PS_CLIMB
        beq l_fst_no
        lda #0
        sta fr_jgo
        lda #1                  ; over to the table
        sta fr_to_seat
        lda #0
        sta goal_floor
        lda #<SEAT_X
        sta goal_x
        lda #>SEAT_X
        sta goal_x+1
        lda #A_NONE
        sta p_goal
        jsr set_walk_target
        lda #PS_WALK
        sta p_state
l_fst_no:
        clc
        rts

; (swapped) Got somewhere: if it's the seat (and Larry's still there), sit.
; C = 1: sat down.
fr_seat_arrive:
        lda fr_to_seat
        beq l_fsa_no
        lda #0
        sta fr_to_seat
        lda p_floor
        bne l_fsa_no
        lda p_x+1
        cmp #>SEAT_X
        bne l_fsa_no
        lda p_x
        cmp #<SEAT_X
        bne l_fsa_no
        jsr fr_larry_table
        bcc l_fsa_no
        lda #1
        sta fr_seated
        lda #PM_POSE
        sta p_mode
        lda #0
        sta p_flip
        lda #<SIT_X
        sta pose_x
        lda #>SIT_X
        sta pose_x+1
        lda #SIT_Y
        sta pose_y
        lda #<SPR_SITSIDE0
        sta pose_spr
        lda #>SPR_SITSIDE0
        sta pose_spr+1
        lda #`SPR_SITSIDE0
        sta pose_spr+2
        sec
        rts
l_fsa_no:
        clc
        rts

; (unswapped) Up from the table at once (he's off home).
fr_stand_up:
        lda #0
        sta fr_music
        sta fr_want
        sta fr_ask
        sta fr_to_seat
        sta fr_jgo
        lda fr_job              ; (joined in with Larry: stops)
        beq +
        lda #0
        sta fr_job
        lda #PM_STAND
        sta FR(p_mode)
+
        lda fr_seated
        beq +
        lda #0
        sta fr_seated
        lda #PM_STAND
        sta FR(p_mode)
        lda #FLOOR0_Y
        sta FR(p_y)
+       rts

; Larry watching his go at the video game, beside him, till it's over.
st_watchvg:
        lda #1
        sta p_flip
        lda #PM_STAND
        sta p_mode
        lda #60
        jmp set_timer_secs
tk_watchvg:
        lda fr_job              ; still at it (or on his way to it)?
        cmp #FRJ_VG
        beq +
        lda fr_jgo
        cmp #8
        beq +
        lda fr_want
        cmp #8
        beq +
        lda #0                  ; no: done watching
        sta act_timer
        sta act_timer+1
+       rts

; The first visit: Larry turns to you, taps on the screen, and introduces
; his friend, who says hello.
st_intro:
        lda #PM_FRONT
        sta p_mode
        lda #0
        sta knock_t
        sta fist_size
        lda #4
        sta fx_kind
        lda #15
        jmp set_timer_secs
tk_intro:
        lda knock_t
        cmp #KNOCK_TALK
        bcs +
        jmp tk_knock            ; (the taps on the glass)
+       inc knock_t
        bne +
        dec knock_t
+       cmp #KNOCK_TALK
        bne l_tki_2
        jsr fx_clear            ; "Hi <you>! Meet my pal Joey!"
        jsr sb_clear
        jsr sb_lcp
        ldx #<l_intro1
        ldy #>l_intro1
        jsr sb_strxy
        jsr sb_player
        ldx #<l_intro2
        ldy #>l_intro2
        jsr sb_strxy
        jsr ui_say_sb
        jmp speak
l_tki_2:
        cmp #KNOCK_TALK + 70    ; his hello
        bne l_tki_3
        ldx #<l_intro3
        ldy #>l_intro3
        jmp fr_say
l_tki_3:
        cmp #KNOCK_TALK + 135   ; done
        bne l_tki_out
        lda #0
        sta act_timer
        sta act_timer+1
l_tki_out:
        rts
en_intro:
        jsr fx_clear
        lda #PM_STAND
        sta p_mode
        rts
        .section ftext
l_intro1:       .null ": Hi "
        .send ftext
        .section ftext
l_intro2:       .null "! Meet my pal Joey!"
        .send ftext
        .section ftext
l_intro3:       .null "Hi there! Nice to meet you!"
        .send ftext

; Larry plays cards with him at the kitchen table: sat as for a hand with
; you, the cards out, a good while.
st_cardsf:
        lda fr_done             ; (cards: done, this visit)
        ora #FD_CARDS
        sta fr_done
        #POSE SPR_EATSHUT, POSE_EAT_X, POSE_EAT_Y
        lda #9
        sta fx_kind
        lda #45
        jmp set_timer_secs
en_cardsf:
        jsr fr_activity_over
        lda #0
        sta fx_kind
        lda #PM_STAND
        sta p_mode
        rts

CV_CARDS        = 7
cv_cards_tbl:   .word cv_cd0, cv_cd1, cv_cd2, cv_cd3, cv_cd4, cv_cd5, cv_cd6
cv_invite_tbl:  .word cv_invite, cv_music
        .section ftext
cv_music:
        .byte 0
        .null "Want to listen to some records?"
        .byte 1
        .null "Sure! Let's dance!"
        .byte $FF
        .send ftext
        .section ftext
cv_cd0:
        .byte 0
        .null "Your deal, Joey."
        .byte 1
        .null "Okay... five cards each."
        .byte $FF
        .send ftext
        .section ftext
cv_cd1:
        .byte 1
        .null "Got any sevens?"
        .byte 0
        .null "Go fish!"
        .byte $FF
        .send ftext
        .section ftext
cv_cd2:
        .byte 0
        .null "Ha! Gin!"
        .byte 1
        .null "Again? You're too good."
        .byte $FF
        .send ftext
        .section ftext
cv_cd3:
        .byte 1
        .null "I'll raise you a pretzel."
        .byte 0
        .null "Ha! I'm in."
        .byte $FF
        .send ftext
        .section ftext
cv_cd4:
        .byte 0
        .null "Hmm... I'll take two cards."
        .byte 1
        .null "Feeling lucky, huh?"
        .byte $FF
        .send ftext
        .section ftext
cv_cd5:
        .byte 1
        .null "Read 'em and weep! Full house!"
        .byte 0
        .null "Aw, nuts. Nice hand."
        .byte $FF
        .send ftext
        .section ftext
cv_cd6:
        .byte 0
        .null "No peeking at my cards!"
        .byte 1
        .null "I would never! ...Much."
        .byte $FF
        .send ftext
        .section ftext
cv_invite:
        .byte 0
        .null "Want to play some cards?"
        .byte 1
        .null "Sure, deal me in!"
        .byte $FF
        .send ftext

