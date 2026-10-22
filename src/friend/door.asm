; friend/door.asm -- his friend: at the front door: letting him in, a sick Larry, seeing him off (see friend/visit.asm)
;---------------------------------------------------------------------------------------
; Larry lets him in: to the door, it opens, in he comes, it shuts.
;---------------------------------------------------------------------------------------
gr_t:           .byte 0
st_greet:
        lda #1
        sta p_flip
        ldx #PATCH_DOOR
        jsr patch_apply
        lda #SFX_DOOR
        jsr sfx_play
        lda #0
        sta gr_t
        lda #10
        jmp set_timer_secs
tk_greet:
        lda fr_state
        cmp #FRS_RING
        bne l_tkgr_in
        inc gr_t
        lda gr_t
        cmp #20
        bne l_tkgr_out
        lda health              ; feeling sick: not today
        cmp #40
        bcs +
        jmp gr_sick
+
        ; the door's open: in he comes, from behind it
        lda #FRS_ENTER
        sta fr_state
        lda #0
        sta FR(p_floor)
        sta FR(p_flip)
        sta FR(p_state)
        lda #<WO_OUT_X
        sta FR(p_x)
        lda #>WO_OUT_X
        sta FR(p_x+1)
        lda #FLOOR0_Y - 5
        sta FR(p_y)
        lda #PM_WALK
        sta FR(p_mode)
        jmp fr_visit_len
l_tkgr_in:
        ldx gr_sick_n
        beq l_tkgr_vis
        inc gr_t
        lda gr_t
        cmp #125
        bne l_tkgr_out
        lda #0
        sta gr_t
        inc gr_sick_n
        lda gr_sick_n
        cmp #5
        bcc gr_sick_line
        lda #0
        sta gr_sick_n
        ldx #PATCH_DOOR
        jmp patch_remove
l_tkgr_vis:
        lda fr_state
        cmp #FRS_VISIT
        bne l_tkgr_out
        lda gr_t                ; he's in: shut the door, say hello
        bne l_tkgr_shut
        lda fr_cptr+1           ; (and stays while they talk)
        beq l_tkgr_out
        lda #50
        sta act_timer
        lda #0
        sta act_timer+1
        rts
l_tkgr_shut:
        lda #0
        sta gr_t
        ldx #PATCH_DOOR
        jsr patch_remove
        lda #CV_GREETS
        jsr rnd_range
        ldx #<cv_greet_tbl
        ldy #>cv_greet_tbl
        jsr fr_convo_start
        lda #120
        sta fr_ct
        lda #<150
        sta act_timer
        lda #>150
        sta act_timer+1
        ldx #<l_say_hijoey
        ldy #>l_say_hijoey
        jsr ui_say
        jmp talk_play
l_tkgr_out:
        rts
en_greet:
        lda fr_state            ; in, and you've not met him: Larry
        cmp #FRS_VISIT          ;  introduces him
        bne +
        lda fr_met
        bne +
        lda #1
        sta fr_met
        lda #A_INTRO
        sta p_pending
        lda #11                 ; (and he comes to stand beside him: spot 10)
        sta fr_want
+       lda #0
        sta gr_sick_n
        ldx #PATCH_DOOR
        jsr patch_remove
        lda fr_state            ; (cut short: he's in anyway)
        cmp #FRS_ENTER
        beq +
        cmp #FRS_RING
        bne l_eng_out
        jsr fr_visit_len
+       lda #FRS_VISIT
        sta fr_state
        lda #0
        sta FR(p_floor)
        lda #PS_IDLE
        sta FR(p_state)
        lda #<FR_IN_X
        sta FR(p_x)
        lda #>FR_IN_X
        sta FR(p_x+1)
        lda #FLOOR0_Y
        sta FR(p_y)
        lda #PM_STAND
        sta FR(p_mode)
l_eng_out:
        rts
        .section ftext
l_say_hijoey:   .null "Hi, Joey! Come on in!"
        .send ftext

; Larry's sick: on the step they talk (he never comes in), the door shuts,
; and he'll come another day.
gr_sick_lines:  .word l_say_sick1, l_fr_sick1, l_say_sick2, l_fr_sick2
        .section ftext
l_say_sick1:    .null "Sorry Joey, I'm feeling sick."
        .send ftext
        .section ftext
l_fr_sick1:     .null "Oh no! Get well soon."
        .send ftext
        .section ftext
l_say_sick2:    .null "Come by another day?"
        .send ftext
        .section ftext
l_fr_sick2:     .null "Sure thing. Feel better!"
        .send ftext
gr_sick:
        lda #FRS_AWAY           ; (he stays out on the step)
        sta fr_state
        lda #180                ; another day (a few hours)
        sta fr_cd
        lda #1
        sta gr_sick_n
        lda #<(5 * 125 + 60)
        sta act_timer
        lda #>(5 * 125 + 60)
        sta act_timer+1
        lda #0
        sta gr_t
gr_sick_line:
        ldx gr_sick_n           ; the next line, Larry and he in turn
        dex
        txa
        asl
        tax
        lda gr_sick_lines,x
        pha
        lda gr_sick_lines+1,x
        tay
        plx
        lda gr_sick_n
        and #1
        beq +
        jsr ui_say              ; (Larry: lines 1, 3)
        jmp speak
+       jmp fr_say
gr_sick_n:      .byte 0         ; lines said (0: not sick at the door)

; Seeing him out: at the door, facing him, until he's gone.
st_seeoff:
        lda #1
        sta p_flip
        lda #PM_STAND
        sta p_mode
        lda #40
        jmp set_timer_secs
tk_seeoff:
        lda fr_state            ; gone: done
        bne +
        sta act_timer
        sta act_timer+1
+       rts
en_seeoff:
        lda fr_bye              ; (called away: he lets himself out)
        cmp #3
        beq +
        lda #0
        sta fr_bye
+       rts

