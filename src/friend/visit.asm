;=======================================================================================
; A friend who drops by. He rings the doorbell (now and then on his own, or a
; while after Larry rings him up to invite him), Larry lets him in, he spends
; a while in the house, then lets himself out. He never stays the night.
;
; He walks with Larry's own walking and stair code: his position and walking
; state live in fr_p / fr_cl, which are swapped in over Larry's (p_state ..
; pose_y and the climb state) while he moves or is drawn, then swapped back.
; He is drawn as actor 7 with Larry's sprites, recoloured (C_FR_SKIN ..).
;=======================================================================================
FRS_AWAY         = 0         ; not here
FRS_COMING       = 1         ; on his way: rings when fr_t runs out
FRS_RING         = 2         ; on the step, waiting to be let in
FRS_ENTER        = 3         ; coming in through the door
FRS_VISIT        = 4         ; in the house
FRS_LEAVE        = 5         ; on his way to the door
FRS_EXIT         = 6         ; out of the door

FR_IN_X         = 292       ; where he stops inside the door
BEDROOM_END     = 136       ; the middle floor left of this is Larry's bedroom

P_BLOCK         = pose_y + 1 - p_state
CL_BLOCK        = l_cl_dest + 1 - l_cl_ptr
FR .function field          ; his copy of one of Larry's variables
.endf fr_p + (field - p_state)

fr_state:       .byte FRS_AWAY
fr_t:           .word 0
fr_cd:          .byte 120   ; minutes until he might drop by
fr_stay:        .byte 0     ; minutes left of his visit
fr_pause:       .word 0     ; frames standing about where he's got to
fr_acc:         .byte 0     ; walking pace
fr_ph:          .byte 0
fr_bye:         .byte 0     ; leaving: 1 Larry's coming to see him out, 2 their
                            ;  goodbyes, 3 said (0: he lets himself out)
fr_p:           .fill P_BLOCK, 0
fr_cl:          .fill CL_BLOCK, 0
        .section ftext
fr_name:        .null "Joey"
        .send ftext
fr_met:         .byte 0     ; 1 = Larry's introduced him to you

; his colours: skin, hair, shirt, shirt shade, trousers, shoes, far leg
fr_rgb:         .byte 214,160,120, 60,40,30, 210,40,50, 140,20,35
                .byte 70,90,60, 40,30,20, 50,66,44

; Swap his walking state in over Larry's (and back again).
fr_swap:
        ldx #P_BLOCK - 1
-       lda p_state,x
        ldy fr_p,x
        sta fr_p,x
        tya
        sta p_state,x
        dex
        bpl -
        ldx #CL_BLOCK - 1
-       lda l_cl_ptr,x
        ldy fr_cl,x
        sta fr_cl,x
        tya
        sta l_cl_ptr,x
        dex
        bpl -
        rts

; C = 1: Larry's in, up and free to come to the door.
fr_can_ring:
        jsr person_sleeping
        bcs l_fcr_no
        lda p_mode
        cmp #PM_HIDDEN
        beq l_fcr_no
        lda walk_stage
        ora delivery
        bne l_fcr_no
        sec
        rts
l_fcr_no:
        clc
        rts

; Ding dong, and Larry comes to let him in.
fr_ring:
        jsr doorbell_play
        lda #A_GREET
        jsr request_pending
        lda #FRS_RING
        sta fr_state
        lda #<1500              ; (rings again in half a minute if need be)
        sta fr_t
        lda #>1500
        sta fr_t+1
        rts

; fr_t - 1; Z = 1 when it reaches 0
fr_count:
        lda fr_t
        bne +
        dec fr_t+1
+       dec fr_t
        lda fr_t
        ora fr_t+1
        rts

; Every frame.
fr_lrp:         .word 0     ; something Larry says in a moment...
fr_lrt:         .byte 0     ; ...in this many frames
        .section ftext
l_fr_going:     .null "Well, I'd better get going."
        .send ftext
        .section ftext
l_say_walkout:  .null "Already? I'll walk you out."
        .send ftext
        .section ftext
l_say_takecare: .null "Bye, Joey! Take care!"
        .send ftext
friend_update:
        lda fr_lrt              ; Larry's line, when it's due
        beq +
        dec fr_lrt
        bne +
        ldx fr_lrp
        ldy fr_lrp+1
        jsr ui_say
        jsr speak
+       lda fr_state
        bne +
        rts
+       cmp #FRS_COMING
        bne l_fru_ring
        jsr fr_count
        bne l_fru_out
        jsr fr_can_ring
        bcs fr_ring
        lda #<3000              ; (not now: try again in a minute)
        sta fr_t
        lda #>3000
        sta fr_t+1
l_fru_out:
        rts
l_fru_ring:
        cmp #FRS_RING
        bne l_fru_in
        jsr fr_count
        bne l_fru_out
        lda p_act               ; nobody's come: ring again
        cmp #A_GREET
        beq +
        lda p_pending
        cmp #A_GREET
        beq +
        jsr fr_can_ring
        bcc +
        jmp fr_ring
+       lda #<1500
        sta fr_t
        lda #>1500
        sta fr_t+1
        rts
l_fru_in:
        jsr fr_stairs_order
        jsr fr_chat_tick
        jsr fr_swap
        jsr fr_body
        jmp fr_swap

; (his state swapped in: p_x etc. are his)
fr_body:
        inc p_anim
        lda fr_state
        cmp #FRS_ENTER
        bne +
        jmp fr_enter
+       cmp #FRS_EXIT
        bne +
        jmp fr_exit
+       jsr fr_job_tick
        bcc +
        rts
+       jsr fr_seat_tick
        bcc +
        rts
+       lda p_state
        cmp #PS_IDLE
        beq fr_choose
        cmp #PS_ACT
        beq l_fb_stand
        lda #230                ; (walking at Larry's pace when he's well)
        clc
        adc fr_acc
        sta fr_acc
        bcs +
        rts
+       lda p_state
        cmp #PS_CLIMB
        bne +
        jmp person_climb
+       jsr person_walk
        lda p_state
        cmp #PS_ACT
        bne l_fb_out
        jsr fr_seat_arrive
        bcs l_fb_out
        jsr fr_job_arrive
        bcs l_fb_out
        ; got there: stand about a while (2-8 s), facing either way
        lda #2
        jsr rnd_range
        sta p_flip
        lda #0
        sta fr_pause+1
        lda #250
        jsr rnd_range
        clc
        adc #100
        sta fr_pause
        bcc +
        inc fr_pause+1
+       lda fr_state            ; (on his way out: no hanging about)
        cmp #FRS_LEAVE
        bne l_fb_out
        lda #1
        sta fr_pause
        lda #0
        sta fr_pause+1
l_fb_out:
        rts
l_fb_stand:
        lda fr_pause
        bne +
        dec fr_pause+1
+       dec fr_pause
        lda fr_pause
        ora fr_pause+1
        bne l_fb_out
        lda #PS_IDLE
        sta p_state
        rts

; Somewhere to go: anywhere in the house, or the door when it's time.
fr_choose:
        lda #0                  ; (the seat: fr_seat_tick sends him if need be)
        sta fr_to_seat
        sta fr_jgo
        lda fr_state
        cmp #FRS_LEAVE
        bne l_fc_wander
        lda p_floor             ; at the door already?
        bne l_fc_door
        lda p_x+1
        cmp #>FR_IN_X
        bne l_fc_door
        lda p_x
        cmp #<FR_IN_X
        bne l_fc_door
        lda #FRS_EXIT
        sta fr_state
        lda #0
        sta fr_ph
        sta fr_t
        rts
l_fc_door:
        lda #0
        sta goal_floor
        lda #<FR_IN_X
        sta goal_x
        lda #>FR_IN_X
        sta goal_x+1
        bra l_fc_go
l_fc_wander:
        jsr fr_pick_job
        bcc +
        rts
+       lda #2                  ; half the time: over to Larry (his state's
        jsr rnd_range           ;  in fr_p just now)
        bne l_fc_any
        lda FR(p_state)
        cmp #PS_CLIMB
        beq l_fc_any
        lda FR(p_mode)
        cmp #PM_HIDDEN
        beq l_fc_any
        lda FR(p_floor)         ; (not into his bedroom)
        cmp #1
        bne +
        lda FR(p_x+1)
        bne +
        lda FR(p_x)
        cmp #BEDROOM_END
        bcc l_fc_any
+       lda FR(p_floor)
        sta goal_floor
        lda FR(p_x+1)           ; beside him, on the roomier side
        bne l_fc_left
        lda FR(p_x)
        cmp #160
        bcs l_fc_left
        clc
        adc #24
        sta goal_x
        lda #0
        sta goal_x+1
        bra l_fc_go
l_fc_left:
        sec
        lda FR(p_x)
        sbc #24
        sta goal_x
        lda FR(p_x+1)
        sbc #0
        sta goal_x+1
        bra l_fc_go
l_fc_any:
        lda #3
        jsr rnd_range
        sta goal_floor
        lda #200
        jsr rnd_range
        clc
        adc #50
        ldx goal_floor          ; (the middle floor: not the bedroom end)
        cpx #1
        bne +
        cmp #BEDROOM_END
        bcs +
        adc #100
+       sta goal_x
        lda #0
        sta goal_x+1
l_fc_go:
        lda #A_NONE
        sta p_goal
        jsr set_walk_target
        lda #PS_WALK
        sta p_state
        rts

; Going out of the door (or coming in) he rises towards its foot, as Larry does.
fr_heights:
        sec
        lda p_x
        sbc #<280
        tax
        lda p_x+1
        sbc #>280
        bcs +
        ldx #0
+       txa
        lsr
        lsr
        cmp #6
        bcc +
        lda #5
+       sta l_fh_t
        lda #FLOOR0_Y
        sec
        sbc l_fh_t
        sta p_y
        rts
l_fh_t: .byte 0

; Coming in (Larry has the door open): a step every other frame.
fr_enter:
        lda p_anim
        and #1
        bne l_fe_out
        lda p_x
        bne +
        dec p_x+1
+       dec p_x
        jsr fr_heights
        lda p_x+1
        cmp #>FR_IN_X
        bne l_fe_out
        lda p_x
        cmp #<FR_IN_X
        bne l_fe_out
        ; in: Larry shuts the door; he has a look round in a moment
        lda #PM_STAND
        sta p_mode
        lda #PS_ACT
        sta p_state
        lda #150
        sta fr_pause
        lda #0
        sta fr_pause+1
        lda #FRS_VISIT
        sta fr_state
l_fe_out:
        rts

; Out of the door: (Larry comes to see him off, they say goodbye,) it opens,
; he steps out, it clicks shut behind him. (Larry's state is in fr_p now.)
fr_exit:
        lda fr_bye
        beq l_fx_go
        cmp #3
        beq l_fx_go
        cmp #1
        bne l_fx_talk
        lda FR(p_act)           ; 1: Larry at the door yet?
        cmp #A_SEEOFF
        bne l_fx_coming
        lda FR(p_state)
        cmp #PS_ACT
        bne l_fx_out
        lda #2                  ; face to face: goodbyes
        sta fr_bye
        lda #0
        sta p_flip
        sta fr_t
        ldx #<l_say_byejoey
        ldy #>l_say_byejoey
        jsr ui_say
        jmp talk_play
l_fx_coming:
        lda FR(p_pending)       ; (not coming after all: off he goes)
        cmp #A_SEEOFF
        beq l_fx_out
        lda #0
        sta fr_bye
        rts
l_fx_talk:
        inc fr_t                ; 2: his reply, Larry's goodbye, then out
        lda fr_t                ;  he goes
        cmp #120
        bne +
        jmp fr_say_soon
+       cmp #230
        bne +
        ldx #<l_say_takecare
        ldy #>l_say_takecare
        jsr ui_say
        jmp speak
+       cmp #250
        bne l_fx_out
        lda #3
        sta fr_bye
        lda #0
        sta fr_t
        rts
l_fx_go:
        ldx fr_ph
        bne l_fx_1
        lda walk_stage          ; (not while Larry's at the door himself)
        ora delivery
        ora patch_state + PATCH_DOOR
        bne l_fx_out
        ldx #PATCH_DOOR
        jsr patch_apply
        lda #SFX_DOOR
        jsr sfx_play
        lda #1
        sta p_flip
        lda #0
        sta fr_t
        inc fr_ph
        lda fr_bye              ; (said goodbye already)
        ldx #0
        stx fr_bye
        cmp #0
        bne l_fx_out
        ldx #<l_fr_bye
        ldy #>l_fr_bye
        jmp fr_say
l_fx_1:
        cpx #1
        bne l_fx_2
        inc fr_t
        lda fr_t
        cmp #20
        bcc l_fx_out
        lda #PM_WALK
        sta p_mode
        inc fr_ph
l_fx_out:
        rts
l_fx_2:
        cpx #2
        bne l_fx_3
        lda p_anim
        and #1
        bne l_fx_out
        inc p_x
        bne +
        inc p_x+1
+       jsr fr_heights
        lda p_x+1
        beq l_fx_out
        lda p_x
        cmp #<WO_OUT_X
        bcc l_fx_out
        lda #PM_HIDDEN
        sta p_mode
        lda #0
        sta fr_t
        inc fr_ph
        rts
l_fx_3:
        inc fr_t
        lda fr_t
        cmp #20
        bne l_fx_out
        ldx #PATCH_DOOR
        jsr patch_remove
        jsr talk_low_stop       ; (gone: his voice with him)
        lda #FRS_AWAY
        sta fr_state
        lda #220                ; a good while before he drops by again
        jsr rnd_range
        clc
        adc #180
        bcc +
        lda #255
+       sta fr_cd
        rts

; (swapped) The same, but only if Larry's on his floor to hear it.
fr_say_if:
        lda FR(p_mode)          ; (out of the house, or out of sight: no)
        cmp #PM_HIDDEN
        beq +
        lda walk_stage
        cmp #2
        beq +
        lda p_floor
        cmp FR(p_floor)
        beq fr_say
+       rts

; X/Y = what he says ("Joey: ...")
fr_say:
        stx l_frs_p
        sty l_frs_p+1
        jsr sb_clear
        ldx #<fr_name
        ldy #>fr_name
        jsr sb_strxy
        lda #':'
        jsr sb_char
        lda #' '
        jsr sb_char
        ldx l_frs_p
        ldy l_frs_p+1
        jsr sb_strxy
        jsr ui_say_sb
        jmp talk_low_play       ; (and his voice)
l_frs_p: .word 0
        .section ftext
l_fr_bye:       .null "Bye! See you soon!"
        .send ftext
        .section ftext
l_say_byejoey:  .null "Thanks for coming over, Joey!"
        .send ftext

; "Joey: Any time, Larry! See you soon."
fr_say_soon:
        jsr sb_clear
        ldx #<fr_name
        ldy #>fr_name
        jsr sb_strxy
        ldx #<l_fr_any
        ldy #>l_fr_any
        jsr sb_strxy
        jsr sb_lcp
        ldx #<l_fr_soon
        ldy #>l_fr_soon
        jsr sb_strxy
        jsr ui_say_sb
        jmp talk_low_play       ; (and his voice)
        .section ftext
l_fr_any:       .null ": Any time, "
        .send ftext
        .section ftext
l_fr_soon:      .null "! See you soon."
        .send ftext

; Every game minute.
friend_minute:
        lda fr_state
        bne l_fm_here
        lda fr_cd               ; away: drops by now and then, 10am-6pm
        beq +
        dec fr_cd
        rts
+       lda clock_hour
        cmp #10
        bcc l_fm_out
        cmp #19
        bcs l_fm_out
        lda #FRS_COMING
        sta fr_state
        lda #<100
        sta fr_t
        lda #>100
        sta fr_t+1
l_fm_out:
        rts
l_fm_here:
        cmp #FRS_VISIT
        bne l_fm_out
        lda fr_stay             ; time to go? (or Larry's off to bed)
        beq l_fm_go
        dec fr_stay
        jsr person_sleeping
        bcs l_fm_go
        jsr bedtime_hour
        sec
        sbc #1
        cmp clock_hour
        beq l_fm_go
        bcc l_fm_go
        rts
l_fm_go:
        lda fr_job              ; (busy on his own: in a minute)
        cmp #FRJ_SNACK
        bcc +
        rts
+       lda #0
        sta fr_bye
        jsr person_sleeping     ; (Larry asleep: he lets himself out)
        bcs l_fm_alone
        jsr fr_can_ring         ; (Larry out with the dog, or at the door:
        bcs +                   ;  he waits for him)
        rts
+       jsr fr_near             ; together: he says he's off, Larry walks
        bcc l_fm_see            ;  him out
        ldx #<l_fr_going
        ldy #>l_fr_going
        jsr fr_say
        lda #<l_say_walkout
        sta fr_lrp
        lda #>l_say_walkout
        sta fr_lrp+1
        lda #110
        sta fr_lrt
l_fm_see:
        lda #1
        sta fr_bye
        lda #A_SEEOFF
        jsr request_pending
l_fm_alone:
        jsr fr_stand_up
        lda #FRS_LEAVE
        sta fr_state
        lda FR(p_state)         ; (walking somewhere: turn round for the door)
        cmp #PS_WALK
        beq +
        cmp #PS_ACT
        bne l_fm_out
+       lda #PS_IDLE
        sta FR(p_state)
        rts

