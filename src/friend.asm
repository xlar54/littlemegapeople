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
fr_name:        .null "Joey"
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
l_fr_going:     .null "Well, I'd better get going."
l_say_walkout:  .null "Already? I'll walk you out."
l_say_takecare: .null "Bye, Joey! Take care!"
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
l_fr_bye:       .null "Bye! See you soon!"
l_say_byejoey:  .null "Thanks for coming over, Joey!"

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
l_fr_any:       .null ": Any time, "
l_fr_soon:      .null "! See you soon."

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

;---------------------------------------------------------------------------------------
; Talking. While he's in, whenever they're near each other (the same floor,
; a few steps apart) and Larry's free, he stops, faces Larry and they talk,
; taking turns; then a while before the next. Larry carries on with what he's
; doing (he turns to him if he's only standing about). Unswapped: p_x etc.
; are Larry's here, FR(p_x) his.
;---------------------------------------------------------------------------------------
fr_cptr:        .word 0     ; the next line of the conversation (0 = none)
fr_ct:          .byte 0     ; frames until it's said
fr_chat_cd:     .word 300   ; frames before they get talking again
FR_NEAR_PX         = 90        ; (pixels apart)
FR_LINE_T       = 125       ; (frames a line)

; A = conversation number, from the table at X/Y: start it in a moment.
fr_convo_start:
        stx ZPTR2
        sty ZPTR2+1
        asl
        tay
        lda (ZPTR2),y
        sta fr_cptr
        iny
        lda (ZPTR2),y
        sta fr_cptr+1
        lda #30
        sta fr_ct
        rts

; C = 1: on the same floor (neither on the stairs), close together.
fr_near:
        lda walk_stage          ; (Larry's out with the dog)
        cmp #2
        beq l_fn_no
        lda p_floor
        cmp FR(p_floor)
        bne l_fn_no
        lda p_mode
        cmp #PM_HIDDEN
        beq l_fn_no
        lda FR(p_mode)          ; (he's in the bathroom, say)
        cmp #PM_HIDDEN
        beq l_fn_no
        lda p_state
        cmp #PS_CLIMB
        beq l_fn_no
        lda FR(p_state)
        cmp #PS_CLIMB
        beq l_fn_no
        sec
        lda FR(p_x)
        sbc p_x
        sta l_fn_d
        lda FR(p_x+1)
        sbc p_x+1
        bpl +
        eor #$FF                ; |dx|
        pha
        lda l_fn_d
        eor #$FF
        clc
        adc #1
        sta l_fn_d
        pla
        adc #0
+       bne l_fn_no
        lda l_fn_d
        cmp #FR_NEAR_PX
        bcs l_fn_no
        sec
        rts
l_fn_no:
        clc
        rts
l_fn_d: .byte 0

; C = 1: Larry's free to talk (not asleep, bathing, on the phone, out...).
fr_busy_list:   .byte A_SLEEP, A_WC, A_BATH, A_PHONE, A_PHONECALL, A_GOOUT
                .byte A_WALKOUT, A_LEASH, A_UNLEASH, A_WHISTLE, A_DELIVERY
                .byte A_STOW, A_SEEOFF, A_GREET, A_KNOCK, A_CHAT, A_ASKWATER, A_INTRO
FR_BUSY_N       = * - fr_busy_list
fr_larry_free:
        lda walk_stage          ; (out with the dog, or about to be)
        bne l_flf_no
        lda p_act
        ldx #FR_BUSY_N - 1
-       cmp fr_busy_list,x
        beq l_flf_no
        dex
        bpl -
        sec
        rts
l_flf_no:
        clc
        rts

; Each frame he's in.
fr_chat_tick:
        lda fr_state
        cmp #FRS_VISIT
        beq +
        rts
+       ldx fr_turn             ; Larry's turn at the game (1), or to watch
        beq +                   ;  his (2)?
        stx l_fct_t
        lda #0
        sta fr_turn
        jsr fr_larry_free       ; (clobbers X)
        bcc +
        lda #A_COMPUTER
        ldx l_fct_t
        cpx #1
        beq l_fct_turn
        lda #A_WATCHVG
l_fct_turn:
        jsr request_pending
+       lda fr_rt               ; a reply due?
        beq +
        dec fr_rt
        bne +
        lda FR(p_mode)
        cmp #PM_HIDDEN
        beq +
        lda p_floor
        cmp FR(p_floor)
        bne +
        ldx fr_rp
        ldy fr_rp+1
        jsr fr_say
+       lda fr_cptr+1
        bne l_fct_on
        lda fr_chat_cd          ; not talking: a while between chats
        ora fr_chat_cd+1
        beq +
        lda fr_chat_cd
        bne l_fct_cd
        dec fr_chat_cd+1
l_fct_cd:
        dec fr_chat_cd
        rts
+       lda fr_jgo              ; (on his way somewhere: not now)
        bne l_fct_out
        lda fr_job              ; (busy with a snack etc.: not now)
        cmp #FRJ_SNACK
        bcs l_fct_out
        jsr fr_near
        bcc l_fct_out
        jsr fr_larry_free
        bcc l_fct_out
        lda p_act               ; at cards: card talk
        cmp #A_CARDSF
        bne +
        lda #CV_CARDS
        jsr rnd_range
        ldx #<cv_cards_tbl
        ldy #>cv_cards_tbl
        jsr fr_convo_start
        bra l_fct_on
+       lda fr_job              ; (busy together: just talk)
        ora fr_want
        ora fr_turn
        bne l_fct_chat
        lda p_act
        cmp #A_WATCHVG
        beq l_fct_chat
        cmp #A_COMPUTER
        beq l_fct_chat
        jsr fr_ask_go           ; may he have a go on the computer / TV?
        bcc +
        jmp l_fct_on
+       lda fr_games            ; a game of cards? (twice a visit at most)
        cmp #2
        bcs l_fct_chat
        lda p_act
        cmp #A_MEAL
        beq l_fct_chat
        cmp #A_CARDS
        beq l_fct_chat
        .if AUTOFRIEND < 2      ; (test builds 2/3/6: straight to cards/a
        lda #3                  ;  meal/music)
        jsr rnd_range
        bne l_fct_chat
        .endif
        inc fr_games
        .if AUTOFRIEND != 6
        lda #2                  ; cards, or music?
        jsr rnd_range
        beq l_fct_cards
        .endif
        lda fr_done             ; (music: not again, nor when he's sick,
        and #FD_MUSIC           ;  or with a record already on)
        bne l_fct_cards
        lda health
        cmp #40
        bcc l_fct_cards
        lda record_left
        ora record_left+1
        bne l_fct_cards
        lda #A_RECORD
        sta fr_after
        lda #1
        ldx #<cv_invite_tbl
        ldy #>cv_invite_tbl
        jsr fr_convo_start
        bra l_fct_on
l_fct_cards:
        lda fr_done             ; (played cards already: just talk)
        and #FD_CARDS
        bne l_fct_chat
        lda #A_CARDSF
        .if AUTOFRIEND == 3
        lda #A_MEAL
        .endif
        sta fr_after
        lda #0
        ldx #<cv_invite_tbl
        ldy #>cv_invite_tbl
        jsr fr_convo_start
        bra l_fct_on
l_fct_chat:
        jsr fr_pick_chat        ; one they've not had yet this visit
        bcs +
        lda fr_stay             ; (talked themselves out: home soon)
        cmp #2
        bcc l_fct_none
        lda #1
        sta fr_stay
l_fct_none:
        rts
+       ldx #<cv_chat_tbl
        ldy #>cv_chat_tbl
        jsr fr_convo_start
l_fct_on:
        jsr fr_near             ; (one of them's walked off: that's that,
        bcs +                   ;  and nothing agreed)
        lda #0
        sta fr_after
        sta fr_ask
        bra l_fct_end
+
        lda fr_seated           ; (sat at the table, joined in, or on his
        ora fr_job              ;  way somewhere: as he is)
        ora fr_jgo
        ora fr_want
        bne l_fct_say
        lda #PS_ACT             ; he stays put, facing Larry
        sta FR(p_state)
        lda #PM_STAND
        sta FR(p_mode)
        lda #200
        sta fr_pause
        lda #0
        sta fr_pause+1
        ldx #0                  ; which way: he faces Larry, Larry him
        lda FR(p_x)
        cmp p_x
        lda FR(p_x+1)
        sbc p_x+1
        bcs +
        inx
+       stx FR(p_flip)
        txa
        eor #1
        tax
        lda p_mode              ; (Larry only if he's just standing about)
        cmp #PM_STAND
        bne +
        lda p_act
        cmp #A_IDLE
        beq l_fct_face
        cmp #A_GREET
        beq l_fct_face
        cmp #A_SEEOFF
        bne +
l_fct_face:
        stx p_flip
+
l_fct_say:
        dec fr_ct
        bne l_fct_out
        lda #FR_LINE_T
        sta fr_ct
        jsr fr_line
        bcs l_fct_end
l_fct_out:
        rts
l_fct_t:        .byte 0
l_fct_end:
        lda #0
        sta fr_cptr
        sta fr_cptr+1
        lda fr_ask              ; (allowed his go: off he goes)
        beq +
        sta fr_want
        cmp #8                  ; (the video game: Larry comes too, and
        bne l_fct_noturn        ;  watches his turn)
        lda #2
        sta fr_turn
l_fct_noturn:
        lda #0
        sta fr_ask
+       lda fr_after            ; (agreed on something: off Larry goes)
        beq +
        ldx #0
        stx fr_after
        cmp #A_RECORD           ; (music: he goes up too)
        bne l_fct_req
        ldx #1
        stx fr_music
l_fct_req:
        jsr request_pending
+       lda p_act               ; at cards: the next remark sooner (5-10 s)
        cmp #A_CARDSF
        bne +
        lda #250
        jsr rnd_range
        clc
        adc #250
        sta fr_chat_cd
        lda #0
        adc #0
        sta fr_chat_cd+1
        rts
+
        lda #60                 ; he'll wander off in a moment
        sta fr_pause
        lda #0
        sta fr_pause+1
        lda #250                ; and talk again in 20-40 s
        jsr rnd_range
        asl
        sta fr_chat_cd
        lda #0
        rol
        sta fr_chat_cd+1
        clc
        lda fr_chat_cd
        adc #<1000
        sta fr_chat_cd
        lda fr_chat_cd+1
        adc #>1000
        sta fr_chat_cd+1
        rts

; Say the next line (C = 1: there are no more).
fr_line:
        lda fr_cptr
        sta ZPTR2
        lda fr_cptr+1
        sta ZPTR2+1
        ldy #0
        lda (ZPTR2),y
        cmp #$FF
        bne +
        sec
        rts
+       sta l_fl_who
        clc                     ; the text: just after
        lda ZPTR2
        adc #1
        sta l_fl_t
        lda ZPTR2+1
        adc #0
        sta l_fl_t+1
-       iny                     ; the next line: past its terminator
        lda (ZPTR2),y
        bne -
        iny
        tya
        clc
        adc fr_cptr
        sta fr_cptr
        bcc +
        inc fr_cptr+1
+       ldx l_fl_t
        ldy l_fl_t+1
        lda l_fl_who
        bne +
        jsr ui_say              ; Larry
        jsr speak
        clc
        rts
+       jsr fr_say              ; him
        clc
        rts
l_fl_who:       .byte 0
l_fl_t:         .word 0

; Their conversations: (speaker 0 Larry / 1 Joey, the line) ..., $FF.
CV_GREETS       = 3
CV_CHATS        = 10
cv_greet_tbl:   .word cv_gr0, cv_gr1, cv_gr2
cv_chat_tbl:    .word cv_ch0, cv_ch1, cv_ch2, cv_ch3, cv_ch4, cv_ch5, cv_ch6, cv_ch7, cv_ch8, cv_ch9
cv_gr0:
        .byte 1
        .null "Hi! Thanks for having me over."
        .byte 0
        .null "Good to see you! How are you?"
        .byte 1
        .null "Not bad at all. Busy week!"
        .byte 0
        .null "Well, make yourself at home."
        .byte $FF
cv_gr1:
        .byte 1
        .null "Hey! Nice place you've got."
        .byte 0
        .null "Thanks! Come in, come in."
        .byte 1
        .null "Ooh, is that a new record?"
        .byte 0
        .null "Sure is. I'll put it on later."
        .byte $FF
cv_gr2:
        .byte 1
        .null "Hello! I brought my appetite."
        .byte 0
        .null "Ha! There's food in the kitchen."
        .byte 1
        .null "How's the dog doing?"
        .byte 0
        .null "Happy as ever. He missed you!"
        .byte $FF
cv_ch0:
        .byte 0
        .null "So, what's new with you?"
        .byte 1
        .null "I took up painting. It's hard!"
        .byte 0
        .null "I'd love to see some."
        .byte $FF
cv_ch1:
        .byte 1
        .null "Did you see the game last night?"
        .byte 0
        .null "I missed it! Who won?"
        .byte 1
        .null "We did, in overtime!"
        .byte 0
        .null "Aw, I should've watched."
        .byte $FF
cv_ch2:
        .byte 0
        .null "Can I get you a drink?"
        .byte 1
        .null "Maybe later, thanks."
        .byte $FF
cv_ch3:
        .byte 0
        .null "I think someone watches me."
        .byte 1
        .null "Ha! You're imagining things."
        .byte 0
        .null "Maybe. They do type a lot."
        .byte $FF
cv_ch4:
        .byte 0
        .null "How's your family doing?"
        .byte 1
        .null "Everyone's well. Mom says hi!"
        .byte 0
        .null "Tell her hi back."
        .byte $FF
cv_ch5:
        .byte 1
        .null "I'm thinking of getting a dog."
        .byte 0
        .null "Do it! Best thing I ever did."
        .byte 1
        .null "Yours does seem happy."
        .byte $FF
cv_ch6:
        .byte 0
        .null "Heard any good jokes lately?"
        .byte 1
        .null "Why did the computer sneeze?"
        .byte 0
        .null "I don't know, why?"
        .byte 1
        .null "It caught a virus!"
        .byte $FF
cv_ch7:
        .byte 1
        .null "What do you do all day here?"
        .byte 0
        .null "Read, play piano, cook..."
        .byte 1
        .null "Sounds like the good life."
        .byte $FF
cv_ch8:
        .byte 0
        .null "Been to the new diner in town?"
        .byte 1
        .null "Yes! The pie is amazing."
        .byte 0
        .null "We should go sometime."
        .byte $FF
cv_ch9:
        .byte 1
        .null "Remember that camping trip?"
        .byte 0
        .null "When the tent blew away? Ha!"
        .byte 1
        .null "Best trip ever."
        .byte $FF

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
l_intro1:       .null ": Hi "
l_intro2:       .null "! Meet my pal Joey!"
l_intro3:       .null "Hi there! Nice to meet you!"

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
cv_music:
        .byte 0
        .null "Want to listen to some records?"
        .byte 1
        .null "Sure! Let's dance!"
        .byte $FF
cv_cd0:
        .byte 0
        .null "Your deal, Joey."
        .byte 1
        .null "Okay... five cards each."
        .byte $FF
cv_cd1:
        .byte 1
        .null "Got any sevens?"
        .byte 0
        .null "Go fish!"
        .byte $FF
cv_cd2:
        .byte 0
        .null "Ha! Gin!"
        .byte 1
        .null "Again? You're too good."
        .byte $FF
cv_cd3:
        .byte 1
        .null "I'll raise you a pretzel."
        .byte 0
        .null "Ha! I'm in."
        .byte $FF
cv_cd4:
        .byte 0
        .null "Hmm... I'll take two cards."
        .byte 1
        .null "Feeling lucky, huh?"
        .byte $FF
cv_cd5:
        .byte 1
        .null "Read 'em and weep! Full house!"
        .byte 0
        .null "Aw, nuts. Nice hand."
        .byte $FF
cv_cd6:
        .byte 0
        .null "No peeking at my cards!"
        .byte 1
        .null "I would never! ...Much."
        .byte $FF
cv_invite:
        .byte 0
        .null "Want to play some cards?"
        .byte 1
        .null "Sure, deal me in!"
        .byte $FF

;---------------------------------------------------------------------------------------
; Things he does. Joining in with Larry: watching the TV with him, dancing
; to his record, watching him at the computer, listening to the piano -- he
; stays while Larry does. Or on his own now and then: a snack from the
; fridge, a drink at the water cooler, the bathroom (once a visit).
;---------------------------------------------------------------------------------------
FRJ_JOIN        = 1         ; fr_job: joining in with Larry
FRJ_SNACK       = 2
FRJ_WATER       = 3
FRJ_WC          = 4
FRJ_VG          = 5         ; a go on the computer (asked for)
FRJ_TV          = 6         ; the TV, in the armchair (asked for)
FRJ_WASH        = 7         ; washing his hands (after the bathroom)
FRJ_INTRO       = 8         ; beside Larry, facing you, being introduced
FJ_JOINS        = 4         ; spots 0-3 are joining in, 4-6 his own
fr_job:         .byte 0
fr_jgo:         .byte 0     ; on his way to spot fr_jgo - 1
fr_jt:          .word 0
fr_jact:        .byte 0     ; what Larry's doing that he's joined
fr_wc_done:     .byte 0
fr_done:        .byte 0     ; done together this visit (FD_ bits): not again
fr_chats:       .word 0     ; conversations had this visit (a bit each)
FD_CARDS        = 1
FD_MUSIC        = 2
FD_VG           = 4
FD_TV           = 8
FD_PIANO        = 16
FD_ALL          = FD_CARDS | FD_MUSIC | FD_VG | FD_TV
fr_music:       .byte 0     ; 1 = they're off to put a record on together
fr_want:        .byte 0     ; allowed a go on the computer / TV: spot + 1
fr_tvon:        .byte 0     ; he switched the TV on (so he'll switch it off)
fr_turn:        .byte 0     ; 1 = Larry's turn at the game next
fr_turns:       .byte 0     ; turns taken at it, this go
;                 TV     dance  comp.  piano  snack  water  WC
fj_act:     .byte A_TV,  A_DANCE, A_COMPUTER, A_PIANO
;                                                            comp.  TV chair
;                                                                          sink   intro
fj_floor:   .byte 2,     2,     1,     2,     0,     0,     1,     1,     2,     1,     0
fj_x:       .byte 132,   104,   250,   198,   52,    138,   196,   <278,  108,   177,   <270
fj_xh:      .byte 0,     0,     0,     0,     0,     0,     0,     >278,  0,     0,     >270
fj_face:    .byte 0,     0,     1,     0,     0,     1,     1,     1,     0,     0,     0
fj_mode:    .byte PM_STAND, PM_DANCE, PM_STAND, PM_STAND
fj_bit:     .byte FD_TV,  FD_MUSIC, FD_VG, FD_PIANO

; (swapped) X = spot: off he goes to it.
fr_go_spot:
        inx
        stx fr_jgo
        dex
        lda fj_floor,x
        sta goal_floor
        lda fj_x,x
        sta goal_x
        lda fj_xh,x
        sta goal_x+1
        lda #0
        sta fr_to_seat
        lda #A_NONE
        sta p_goal
        jsr set_walk_target
        lda #PS_WALK
        sta p_state
        rts

; (swapped) X = join spot if Larry's doing one of those things (C = 1), and
; A = what (or FJ_RECORD: a record's playing and they're both in the attic).
FJ_RECORD       = $FF
fr_joinable:
        lda FR(p_state)
        cmp #PS_ACT
        bne l_fj_rec
        lda FR(p_act)
        ldx #FJ_JOINS - 1
-       cmp fj_act,x
        beq l_fj_act
        dex
        bpl -
l_fj_rec:
        jsr fr_record_on
        bcc l_fj_no
        lda fr_done             ; (danced already this visit)
        and #FD_MUSIC
        bne l_fj_no
        ldx #1                  ; (the dancing spot)
        lda #FJ_RECORD
l_fj_yes:
        sec
        rts
l_fj_act:
        pha
        lda fj_bit,x            ; done that already?
        and fr_done
        beq l_fj_ok
        cpx #2                  ; (the computer, mid-session: their turns)
        bne l_fj_done
        lda fr_turns
        bne l_fj_ok
l_fj_done:
        pla
        bra l_fj_no
l_fj_ok:
        pla
        bra l_fj_yes
l_fj_no:
        clc
        rts

; (swapped) C = 1: a record's playing, and Larry's up in the attic with it.
fr_record_on:
        lda record_left
        ora record_left+1
        beq l_fro_no
        lda FR(p_floor)
        cmp #2
        bne l_fro_no
        lda FR(p_state)
        cmp #PS_CLIMB
        beq l_fro_no
        sec
        rts
l_fro_no:
        clc
        rts

; (swapped) Each frame: what he's doing. C = 1: that's all for this frame.
fr_job_tick:
        lda fr_state
        cmp #FRS_VISIT
        bne l_fjt_no
        lda fr_job
        beq l_fjt_idle
        cmp #FRJ_JOIN
        bne l_fjt_solo
        lda fr_jact
        cmp #FJ_RECORD
        beq l_fjt_rec
        lda FR(p_state)         ; joined in: until Larry stops
        cmp #PS_ACT
        bne l_fjt_stopped
        lda FR(p_act)
        cmp fr_jact
        bne l_fjt_stopped
        sec
        rts
l_fjt_stopped:
        lda fr_jact             ; Larry's turn at the game over: his again
        cmp #A_COMPUTER
        bne +
        lda fr_turns
        beq +
        cmp #3
        bcs +
        inc fr_turns
        lda #8                  ; (the computer: spot 7)
        sta fr_want
        lda #2
        sta fr_turn
        ldx #<l_fr_myturn
        ldy #>l_fr_myturn
        jsr fr_say_if
        jmp fr_job_end
+       lda fr_jact             ; (their last turn: good game)
        cmp #A_COMPUTER
        bne +
        lda fr_turns
        cmp #3
        bcc +
        lda #0
        sta fr_turns
        ldx #<l_fr_gg
        ldy #>l_fr_gg
        jsr fr_say_if
+       jsr fr_activity_over
        jmp fr_job_end
l_fjt_rec:
        jsr fr_record_on        ; dancing to the record: till it stops (or
        bcs l_fjt_dance         ;  Larry goes downstairs)
        lda fr_music            ; not on yet: waiting for Larry to put it on?
        beq l_fjt_stop
        lda FR(p_act)
        cmp #A_RECORD
        beq l_fjt_wait
        lda FR(p_goal)
        cmp #A_RECORD
        beq l_fjt_wait
l_fjt_stop:
        lda #0
        sta fr_music
        jsr fr_activity_over
        jmp fr_job_end
l_fjt_wait:
        lda #PM_STAND
        sta p_mode
        sec
        rts
l_fjt_dance:
        lda #PM_DANCE
        sta p_mode
        lda FR(p_state)         ; Larry only pottering about up here? He
        cmp #PS_ACT             ;  comes and dances too
        bne l_fjt_held
        lda FR(p_act)
        cmp #A_IDLE
        bne l_fjt_held
        lda FR(p_pending)
        bne l_fjt_held
        lda #A_DANCE
        sta FR(p_pending)
        lda #PS_IDLE
        sta FR(p_state)
l_fjt_held:
        sec
        rts
l_fjt_solo:
        inc fr_jt
        bne +
        inc fr_jt+1
+       lda fr_job
        cmp #FRJ_SNACK
        bne +
        jmp fr_snack
+       cmp #FRJ_WATER
        bne +
        jmp fr_water
+       cmp #FRJ_VG
        bne +
        jmp fr_vg
+       cmp #FRJ_TV
        bne +
        jmp fr_tv
+       cmp #FRJ_WASH
        bne +
        jmp fr_wash
+       cmp #FRJ_INTRO
        bne +
        jmp fr_intro
+       jmp fr_wc
l_fjt_idle:
        lda fr_jgo              ; (on his way somewhere already, or to the
        ora fr_to_seat          ;  table, or sat at it)
        ora fr_seated
        bne l_fjt_no
        lda p_state
        cmp #PS_CLIMB
        beq l_fjt_no
        ldx fr_want             ; allowed a go on something: there
        beq l_fjt_nowant
        lda #0
        sta fr_want
        dex
        bra +
l_fjt_nowant:
        ldx #1                  ; music agreed: up to the dancing spot
        lda fr_music
        bne +
        jsr fr_joinable
        bcc l_fjt_no
+       jsr fr_go_spot
l_fjt_no:
        clc
        rts
fr_job_end:
        lda #0
        sta fr_job
        lda #PM_STAND
        sta p_mode
        lda #PS_ACT
        sta p_state
        lda #40
        sta fr_pause
        lda #0
        sta fr_pause+1
        sec
        rts

; (swapped) Got somewhere: one of his spots? Start what he came for (C = 1).
fr_job_arrive:
        ldx fr_jgo
        beq l_fja_no
        lda #0
        sta fr_jgo
        dex
        lda p_floor
        cmp fj_floor,x
        bne l_fja_no
        lda p_x+1
        cmp fj_xh,x
        bne l_fja_no
        lda p_x
        cmp fj_x,x
        bne l_fja_no
        lda fj_face,x
        sta p_flip
        cpx #FJ_JOINS
        bcs l_fja_solo
        lda #FJ_RECORD          ; (come up for the music: waits for it)
        ldy fr_music
        bne +
        jsr fr_joinable         ; (still at it?)
        bcc l_fja_no
+       sta fr_jact
        lda fj_bit,x            ; (done, this visit)
        ora fr_done
        sta fr_done
        lda fj_mode,x
        sta p_mode
        lda #FRJ_JOIN
        sta fr_job
        sec
        rts
l_fja_solo:
        txa                     ; 4-8: snack, water, WC, computer, TV
        sec
        sbc #FJ_JOINS - FRJ_SNACK
        sta fr_job
        lda #0
        sta fr_jt
        sta fr_jt+1
        lda #PM_STAND
        sta p_mode
        sec
        rts
l_fja_no:
        clc
        rts

; (swapped, choosing) C = 1: off to do something of his own (1 time in 5).
fr_pick_job:
        .if AUTOFRIEND != 4     ; (test build 4: always)
        lda #4
        jsr rnd_range
        bne l_fpj_no
        .endif
        lda fr_wc_done          ; (not been yet: the bathroom, half the time)
        bne +
        .if AUTOFRIEND == 7     ; (test build 7: straight to the bathroom)
        bra l_fpj_wc
        .endif
        lda #2
        jsr rnd_range
        beq l_fpj_wc
+       lda #2
        jsr rnd_range
        beq l_fpj_snack
        bra l_fpj_water
l_fpj_wc:
        lda fr_wc_done          ; the bathroom: once a visit, if it's free
        ora patch_state + PATCH_WC
        bne l_fpj_no
        lda FR(p_act)
        cmp #A_WC
        beq l_fpj_no
        cmp #A_BATH
        beq l_fpj_no
        ldx #6
        bra l_fpj_go
l_fpj_snack:
        lda patch_state + PATCH_FRIDGE
        bne l_fpj_no
        lda FR(p_floor)         ; (not with Larry busy in the kitchen)
        bne +
        lda FR(p_x+1)
        bne +
        lda FR(p_x)
        cmp #100
        bcc l_fpj_no
+       ldx #4
        bra l_fpj_go
l_fpj_water:
        lda FR(p_act)
        cmp #A_DRINK
        beq l_fpj_no
        ldx #5
l_fpj_go:
        jsr fr_go_spot
        sec
        rts
l_fpj_no:
        clc
        rts

; His go on the computer: sat at it, a game on the screen, its noises.
fr_vg:
        lda fr_jt+1
        cmp #3                  ; (about 15 seconds)
        beq l_fvg_end
        ora fr_jt
        cmp #1
        bne l_fvg_play
        #POSE SPR_COMPUTER, POSE_COMPUTER_X, POSE_COMPUTER_Y
        lda #0
        sta vg_game
        jsr rnd
        and #1
        beq +
        lda #16
        sta vg_game
+       lda #1
        sta monitor_on
        sec
        rts
l_fvg_play:
        jsr tk_computer
        sec
        rts
l_fvg_end:
        lda #0
        sta monitor_on
        lda fr_turns            ; Larry here (and turns left)? His turn
        cmp #3
        bcs l_fvg_bye
        lda FR(p_floor)
        cmp #1
        bne l_fvg_bye
        lda FR(p_mode)
        cmp #PM_HIDDEN
        beq l_fvg_bye
        inc fr_turns
        lda #1
        sta fr_turn
        ldx #<l_fr_yourturn
        ldy #>l_fr_yourturn
        jsr fr_say
        jmp fr_job_end
l_fvg_bye:
        ldx #<l_fr_vgdone
        ldy #>l_fr_vgdone
        jsr fr_say_if
        jsr fr_activity_over
        jmp fr_job_end
l_fr_vgdone:    .null "That was fun! New high score!"
l_fr_yourturn:  .null "Your turn!"
l_fr_myturn:    .null "My turn!"
l_fr_gg:        .null "Good game! That was fun."

; His turn with the TV: in the armchair (switching it on, and off after).
fr_tv:
        lda fr_jt+1
        cmp #3
        beq l_ftv_end
        ora fr_jt
        cmp #1
        bne l_ftv_out
        #POSE SPR_SITTV, SITTV_X, SITTV_Y
        lda tv_on
        bne l_ftv_out
        lda #1
        sta tv_on
        sta fr_tvon
        lda #SFX_CLACK
        jsr sfx_play
l_ftv_out:
        sec
        rts
l_ftv_end:
        jsr fr_activity_over
        lda fr_tvon
        beq +
        lda #0
        sta tv_on
        sta fr_tvon
        lda #SFX_CLACK
        jsr sfx_play
+       jmp fr_job_end

; the snack: the fridge opens, he takes something, it shuts; tasty
fr_snack:
        lda fr_jt+1
        bne l_fsn_2
        lda fr_jt
        cmp #1
        bne l_fsn_1
        ldx #PATCH_FRIDGE
        jsr patch_apply
        lda #SFX_DOOR
        jsr sfx_play
        ldx #<l_fr_snack
        ldy #>l_fr_snack
        jsr fr_say_if
        sec
        rts
l_fsn_1:
        cmp #70
        bne +
        ldx #PATCH_FRIDGE
        jsr patch_remove
        sec
        rts
+       cmp #110
        bne +
        ldx #<l_fr_tasty
        ldy #>l_fr_tasty
        jsr fr_say_if
        sec
        rts
+       cmp #200
        bne l_fsn_out
l_fsn_2:
        ldx #PATCH_FRIDGE       ; (done)
        jsr patch_remove
        jmp fr_job_end
l_fsn_out:
        sec
        rts
l_fr_snack:     .null "Mind if I grab a snack?"
l_fr_tasty:     .null "Mmm, tasty!"

; a drink at the water cooler (the bottle goes down a little)
fr_water:
        lda fr_jt+1
        bne l_fwa_end
        lda fr_jt
        cmp #20
        bne l_fwa_1
        lda water
        bne +
        ldx #<l_fr_nowater      ; empty
        ldy #>l_fr_nowater
        jsr fr_say_if
        lda #150
        sta fr_jt
        sec
        rts
+       dec water
        lda #1
        sta ui_dirty
        lda #SFX_GLUG
        jsr sfx_play
        sec
        rts
l_fwa_1:
        cmp #90
        bne +
        ldx #<l_fr_ahh
        ldy #>l_fr_ahh
        jsr fr_say_if
        sec
        rts
+       cmp #200
        bcc l_fsn_out
l_fwa_end:
        jmp fr_job_end
l_fr_nowater:   .null "Oops, the water's all gone."
l_fr_ahh:       .null "Ahh, refreshing."

; Being introduced: beside Larry, facing you, till Larry's done.
fr_intro:
        lda fr_jt+1
        bne l_fin_end
        lda fr_jt
        cmp #1
        bne +
        lda #PM_FRONT
        sta p_mode
        sec
        rts
+       lda FR(p_act)           ; (Larry still at it, or on his way to it?)
        cmp #A_INTRO
        beq +
        lda FR(p_pending)
        cmp #A_INTRO
        bne l_fin_end
+       sec
        rts
l_fin_end:
        jmp fr_job_end

; washing his hands at the sink, back to you, the tap running (Larry's tap
; sound: the shower's noise, softer and lower)
fr_wash:
        lda fr_jt+1
        bne l_fwh_end
        lda fr_jt
        cmp #1
        bne +
        lda #PM_WASH
        sta p_mode
        lda #$90
        sta shower_pitch
        lda #1
        sta shower_on
        sec
        rts
+       cmp #160
        bcs l_fwh_end
        sec
        rts
l_fwh_end:
        lda #0
        sta shower_on
        lda #$C0
        sta shower_pitch
        jmp fr_job_end

; the bathroom: in, the door shuts; a while, the flush; out again
fr_wc_tl:   .word 1, 20, 32, 300, 390, 402, 424, 440
fr_wc:
        ldx #0
-       lda fr_jt
        cmp fr_wc_tl,x
        bne +
        lda fr_jt+1
        cmp fr_wc_tl+1,x
        beq l_fwc_at
+       inx
        inx
        cpx #16
        bne -
        sec
        rts
l_fwc_at:
        txa
        lsr
        tax
        beq l_fwc_open
        dex
        beq l_fwc_hide
        dex
        beq l_fwc_shut
        dex
        beq l_fwc_flush
        dex
        beq l_fwc_open
        dex
        beq l_fwc_show
        dex
        beq l_fwc_shut
        ldx #PATCH_WC
        jsr patch_remove
        lda #10                 ; then wash his hands (the sink: spot 9)
        sta fr_want
        jmp fr_job_end
l_fwc_open:
        lda #1                  ; (been, this visit)
        sta fr_wc_done
        ldx #PATCH_WC
        jsr patch_apply
        lda #SFX_DOOR
        jsr sfx_play
        sec
        rts
l_fwc_hide:
        lda #PM_HIDDEN
        sta p_mode
        sec
        rts
l_fwc_show:
        lda #PM_STAND
        sta p_mode
        sec
        rts
l_fwc_shut:
        ldx #PATCH_WC
        jsr patch_remove
        sec
        rts
l_fwc_flush:
        jsr flush_play
        sec
        rts

; A = what Larry's chosen to do: with his friend here, a game of cards is
; with him (not you).
fr_ai_filter:
        ldx fr_state            ; (a book with a guest over: rude)
        cpx #FRS_VISIT
        bne l_faf_music
        ldx fr_want             ; (his turn at the video game, or on his
        cpx #8                  ;  way to it: Larry watches)
        beq l_faf_watch
        ldx fr_jgo
        cpx #8
        beq l_faf_watch
        ldx fr_job
        cpx #FRJ_VG
        bne +
        ldx fr_turns            ; (a session together: watches)
        bne l_faf_watch
        cmp #A_COMPUTER         ; (on his own: Larry leaves it to him)
        beq l_faf_idle
+       cpx #FRJ_TV
        bne +
        cmp #A_TV
        beq l_faf_idle
        cmp #A_TVON
        beq l_faf_idle
        cmp #A_TVOFF
        bne +
l_faf_idle:
        lda #A_IDLE
        rts
l_faf_watch:
        lda #A_WATCHVG
        rts
+
        .if AUTOFRIEND == 8     ; (test build 8: every choice is a book)
        bra l_faf_book
        .endif
        cmp #A_READ
        beq l_faf_book
        cmp #A_READCHAIR
        beq l_faf_book
        cmp #A_GOOUT            ; (nor going out and leaving him)
        bne l_faf_music
l_faf_book:
        jmp fr_instead_of_book
l_faf_music:
        ldx fr_music            ; the record they came up for: he dances
        beq l_faf_cards
        ldx record_left
        bne l_faf_dance
        ldx record_left+1
        beq l_faf_cards
l_faf_dance:
        ldx #0
        stx fr_music
        lda #A_DANCE
        rts
l_faf_cards:
        ldx fr_state
        cpx #FRS_VISIT
        bne l_faf_out
        cmp #A_CARDS
        bne +
        lda #A_CARDSF
+       ldy #FAF_N - 1          ; done that with him already? He potters
-       cmp faf_act,y           ;  about (and they talk) instead
        beq l_faf_got
        dey
        bpl -
l_faf_out:
        rts
l_faf_got:
        pha
        lda faf_bit,y
        and fr_done
        beq +
        pla
        lda #A_IDLE
        rts
+       pla
        rts
faf_act:        .byte A_CARDSF, A_TV, A_TVON, A_COMPUTER, A_RECORD, A_DANCE, A_PIANO
faf_bit:        .byte FD_CARDS, FD_TV, FD_TV, FD_VG, FD_MUSIC, FD_MUSIC, FD_PIANO
FAF_N           = * - faf_bit

; A = a conversation they've not had yet this visit (marked had); C = 0:
; they've had them all.
fr_pick_chat:
        lda #CV_CHATS
        jsr rnd_range
        sta l_fpc_n
        ldy #CV_CHATS
-       ldx l_fpc_n
        lda fpc_bit,x
        cpx #8
        bcs l_fpc_hi
        and fr_chats
        beq l_fpc_lo
        bra l_fpc_next
l_fpc_hi:
        and fr_chats+1
        beq l_fpc_mhi
l_fpc_next:
        inx                     ; had it: the next one round
        cpx #CV_CHATS
        bcc +
        ldx #0
+       stx l_fpc_n
        dey
        bne -
        clc
        rts
l_fpc_lo:
        lda fpc_bit,x
        ora fr_chats
        sta fr_chats
        bra l_fpc_got
l_fpc_mhi:
        lda fpc_bit,x
        ora fr_chats+1
        sta fr_chats+1
l_fpc_got:
        lda l_fpc_n
        sec
        rts
l_fpc_n:        .byte 0
fpc_bit:        .byte 1, 2, 4, 8, 16, 32, 64, 128, 1, 2, 4, 8, 16, 32, 64, 128

; Something they did together is over: they get talking again shortly; and
; now and then (or when they've done everything) it's time he went home.
fr_activity_over:
        lda #100
        sta fr_chat_cd
        lda #0
        sta fr_chat_cd+1
        lda fr_done
        and #FD_ALL
        cmp #FD_ALL
        beq l_fao_home
        lda #3
        jsr rnd_range
        bne l_fao_out
l_fao_home:
        lda fr_stay             ; (in a minute or so)
        cmp #2
        bcc l_fao_out
        lda #1
        sta fr_stay
l_fao_out:
        rts

; Instead of reading (rude, with a guest): he potters about near him.
fr_instead_of_book:
        lda #A_IDLE
        rts

; Joey asks if he may play a video game, or watch the TV (1 time in 4 they
; get talking, if it's free); C = 1: the conversation's started.
fr_ask:         .byte 0     ; the spot + 1 he's asked for
cv_ask_tbl:     .word cv_askvg, cv_asktv
cv_askvg:
        .byte 1
        .null "Want to play video games with me?"
        .byte 0
        .null "Sure! You go first."
        .byte $FF
cv_asktv:
        .byte 1
        .null "Mind if I watch some TV?"
        .byte 0
        .null "Sure, help yourself!"
        .byte $FF
fr_ask_go:
        .if AUTOFRIEND != 9     ; (test build 9: always)
        lda #4
        jsr rnd_range
        bne l_fag_no
        .endif
        lda #2
        jsr rnd_range
        tax
        .if AUTOFRIEND == 9     ; (the video game, in the test)
        ldx #0
        .endif
        lda fib_bit,x           ; (had his go already)
        and fr_done
        bne l_fag_no
        lda fib_spot,x          ; (not if Larry's on it, or on his way)
        ldy fib_act,x
        cpy p_act
        beq l_fag_no
        cpy p_goal
        beq l_fag_no
        clc
        adc #1
        sta fr_ask
        lda fib_bit,x           ; (done, this visit)
        ora fr_done
        sta fr_done
        lda #0
        sta fr_turns
        txa
        ldx #<cv_ask_tbl
        ldy #>cv_ask_tbl
        jsr fr_convo_start
        sec
        rts
l_fag_no:
        clc
        rts
fib_spot:       .byte 7, 8
fib_act:        .byte A_COMPUTER, A_TV
fib_bit:        .byte FD_VG, FD_TV

fr_rp:          .word 0     ; his reply to come...
fr_rt:          .byte 0     ; ...in this many frames

; The stairs: whoever got onto them first is drawn in front.
fr_front:       .byte 0     ; 1 = he's ahead of Larry on the stairs
l_fso_lp:       .byte 0     ; (last frame's states)
l_fso_fp:       .byte 0
fr_stairs_order:
        lda p_state             ; Larry just onto the stairs: in front,
        cmp #PS_CLIMB           ;  unless he's on them already
        bne l_fso_l
        cmp l_fso_lp
        beq l_fso_l
        ldx #0
        lda FR(p_state)
        cmp #PS_CLIMB
        bne +
        inx
+       stx fr_front
l_fso_l:
        lda FR(p_state)         ; he's just onto them: in front, unless
        cmp #PS_CLIMB           ;  Larry is on them already
        bne l_fso_f
        cmp l_fso_fp
        beq l_fso_f
        ldx #1
        lda p_state
        cmp #PS_CLIMB
        bne +
        dex
+       stx fr_front
l_fso_f:
        lda p_state
        sta l_fso_lp
        lda FR(p_state)
        sta l_fso_fp
        rts

; C = 1: draw him in front of Larry. On the stairs the follower is drawn in
; front of whoever went first going up, and behind him coming down.
fr_in_front:
        lda fr_state
        cmp #FRS_ENTER
        bcc l_fif_no
        lda p_state             ; (one of them on the stairs)
        cmp #PS_CLIMB
        beq +
        lda FR(p_state)
        cmp #PS_CLIMB
        bne l_fif_no
+       ldx fr_front            ; the leader's way (the other's, if he's off
        beq l_fif_larry         ;  them already)
        lda FR(p_state)
        cmp #PS_CLIMB
        beq l_fif_joey
l_fif_larry:
        lda p_state
        cmp #PS_CLIMB
        bne l_fif_joey
        lda l_cl_dest           ; going up: the floor ahead is higher
        cmp p_floor
        bra l_fif_dir
l_fif_joey:
        lda fr_cl + (l_cl_dest - l_cl_ptr)
        cmp FR(p_floor)
l_fif_dir:
        lda #0                  ; A = 1 going up (C from the compare)
        bcc +
        lda #1
+       eor fr_front            ; he leads coming down, or follows going up
        beq l_fif_no
        sec
        rts
l_fif_no:
        clc
        rts

; Larry, ringing someone up: now and then it's him, and he's coming over.
; C = 1: l_tpc_p = what Larry says.
friend_invite:
        lda fr_state
        bne l_fi_no
        lda clock_hour
        cmp #18
        bcs l_fi_no
        lda #3
        jsr rnd_range
        bne l_fi_no
        lda #<l_call_fr
        sta l_tpc_p
        lda #>l_call_fr
        sta l_tpc_p+1
        lda #FRS_COMING          ; on his way: there in a few minutes
        sta fr_state
        lda #<9000
        sta fr_t
        lda #>9000
        sta fr_t+1
        sec
        rts
l_fi_no:
        clc
        rts
l_call_fr:      .null ": Hey Joey! Want to come over for a while?"

; Start a visit: he's here for 30-90 minutes.
fr_visit_len:
        .if AUTOFRIEND == 7     ; (test build 7: the bathroom first thing)
        lda #7
        sta fr_want
        .endif
        .if AUTOFRIEND != 0
        lda #3                  ; (test build: a short visit)
        sta fr_stay
        rts
        .endif
        lda #60
        jsr rnd_range
        clc
        adc #30
        sta fr_stay
        lda #0
        sta fr_games
        sta fr_wc_done
        sta fr_done
        sta fr_chats
        sta fr_chats+1
        rts

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
l_say_hijoey:   .null "Hi, Joey! Come on in!"

; Larry's sick: on the step they talk (he never comes in), the door shuts,
; and he'll come another day.
gr_sick_lines:  .word l_say_sick1, l_fr_sick1, l_say_sick2, l_fr_sick2
l_say_sick1:    .null "Sorry Joey, I'm feeling sick."
l_fr_sick1:     .null "Oh no! Get well soon."
l_say_sick2:    .null "Come by another day?"
l_fr_sick2:     .null "Sure thing. Feel better!"
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

;---------------------------------------------------------------------------------------
; Drawing: Larry's sprite code run on his state, into actor 7.
;---------------------------------------------------------------------------------------
friend_sprite:
        lda #0
        sta act_vis+7
        sta act_vis+8
        sta act_vis+9
        sta act_vis+10
        lda fr_job              ; his game on the computer screen
        cmp #FRJ_VG
        bne +
        lda FR(p_mode)
        cmp #PM_POSE
        bne +
        lda #1
        sta act_vis+10
        lda FR(p_anim)
        lsr
        lsr
        lsr
        and #15
        clc
        adc vg_game
        tax
        lda vg_l,x
        sta act_sprl+10
        lda vg_h,x
        sta act_sprh+10
        lda #`SPR_VGM0
        sta act_sprb+10
        lda #<VG_X
        sta act_xl2+10
        lda #>VG_X
        sta act_xh2+10
        lda #VG_Y
        sta act_y+10
        lda #0
        sta act_flip+10
+        lda fr_job              ; in the TV armchair: its back and arm over him
        cmp #FRJ_TV
        bne +
        lda FR(p_mode)
        cmp #PM_POSE
        bne +
        lda #1
        sta act_vis+9
        #SETACT 9, SPR_CHAIRFRONT
        lda #<CHAIRFRONT_X
        sta act_xl2+9
        lda #>CHAIRFRONT_X
        sta act_xh2+9
        lda #CHAIRFRONT_Y
        sta act_y+9
        lda #0
        sta act_flip+9
+        lda fr_seated           ; his chair, while he sits on it
        beq +
        lda #1
        sta act_vis+8
        #SETACT 8, SPR_CHAIRSIDE
        lda #<CHAIRSIDE_X
        sta act_xl2+8
        lda #>CHAIRSIDE_X
        sta act_xh2+8
        lda #CHAIRSIDE_Y
        sta act_y+8
        lda #0
        sta act_flip+8
        lda p_act               ; and a plate of his own, if they're eating
        cmp #A_MEAL
        bne +
        lda #1
        sta act_vis+9
        #SETACT 9, SPR_HELDPLATE
        lda #<FR_PLATE_X
        sta act_xl2+9
        lda #>FR_PLATE_X
        sta act_xh2+9
        lda #FR_PLATE_Y
        sta act_y+9
        lda #0
        sta act_flip+9
+
        lda fr_state
        cmp #FRS_ENTER
        bcs +
        rts
+       jsr fr_swap
        lda mouth_open          ; (Larry's talking, drinking... not his)
        pha
        lda drinking
        pha
        lda fx_kind
        pha
        lda #0
        sta mouth_open
        sta drinking
        sta fx_kind
        jsr person_sprite
        pla
        sta fx_kind
        pla
        sta drinking
        pla
        sta mouth_open
        lda act_vis+0
        sta act_vis+7
        lda act_sprl+0
        sta act_sprl+7
        lda act_sprh+0
        sta act_sprh+7
        lda act_sprb+0
        sta act_sprb+7
        lda act_xl2+0
        sta act_xl2+7
        lda act_xh2+0
        sta act_xh2+7
        lda act_y+0
        sta act_y+7
        lda act_flip+0
        sta act_flip+7
        jmp fr_swap

; his colours (each frame, with the house lights)
friend_palette:
        lda #<fr_rgb
        sta ZPTR
        lda #>fr_rgb
        sta ZPTR+1
        ldy #0
-       phy
        tya
        clc
        adc #C_FR_SKIN
        tax
        jsr pal_set_from
        ply
        iny
        cpy #7
        bne -
        rts
