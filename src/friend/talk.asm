; friend/talk.asm -- his friend: talking: when they chat, the conversation reader, the conversations (see friend/visit.asm)
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
        jsr fr_pong_maybe       ; a game of ping pong? (once a visit)
        bcs l_fct_pp
        jsr fr_ask_go           ; may he have a go on the computer / TV?
        bcc +
l_fct_pp:
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
        ldx fr_cptr             ; (far: fetched, then kept in its own buffer
        ldy fr_cptr+1           ;  -- the names it's said with are far too)
        cpy #>FAR_TEXT
        bcc l_fl_near
        jsr far_fetch
        ldx #FT_LEN
-       lda ftbuf,x
        sta cvbuf,x
        dex
        bpl -
        ldx #<cvbuf
        ldy #>cvbuf
l_fl_near:
        stx ZPTR2
        sty ZPTR2+1
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
cvbuf:          .fill FT_LEN + 1, 0
l_fl_t:         .word 0

; Their conversations: (speaker 0 Larry / 1 Joey, the line) ..., $FF.
CV_GREETS       = 3
CV_CHATS        = 10
cv_greet_tbl:   .word cv_gr0, cv_gr1, cv_gr2
cv_chat_tbl:    .word cv_ch0, cv_ch1, cv_ch2, cv_ch3, cv_ch4, cv_ch5, cv_ch6, cv_ch7, cv_ch8, cv_ch9
        .section ftext
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
        .send ftext
        .section ftext
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
        .send ftext
        .section ftext
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
        .send ftext
        .section ftext
cv_ch0:
        .byte 0
        .null "So, what's new with you?"
        .byte 1
        .null "I took up painting. It's hard!"
        .byte 0
        .null "I'd love to see some."
        .byte $FF
        .send ftext
        .section ftext
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
        .send ftext
        .section ftext
cv_ch2:
        .byte 0
        .null "Can I get you a drink?"
        .byte 1
        .null "Maybe later, thanks."
        .byte $FF
        .send ftext
        .section ftext
cv_ch3:
        .byte 0
        .null "I think someone watches me."
        .byte 1
        .null "Ha! You're imagining things."
        .byte 0
        .null "Maybe. They do type a lot."
        .byte $FF
        .send ftext
        .section ftext
cv_ch4:
        .byte 0
        .null "How's your family doing?"
        .byte 1
        .null "Everyone's well. Mom says hi!"
        .byte 0
        .null "Tell her hi back."
        .byte $FF
        .send ftext
        .section ftext
cv_ch5:
        .byte 1
        .null "I'm thinking of getting a dog."
        .byte 0
        .null "Do it! Best thing I ever did."
        .byte 1
        .null "Yours does seem happy."
        .byte $FF
        .send ftext
        .section ftext
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
        .send ftext
        .section ftext
cv_ch7:
        .byte 1
        .null "What do you do all day here?"
        .byte 0
        .null "Read, play piano, cook..."
        .byte 1
        .null "Sounds like the good life."
        .byte $FF
        .send ftext
        .section ftext
cv_ch8:
        .byte 0
        .null "Been to the new diner in town?"
        .byte 1
        .null "Yes! The pie is amazing."
        .byte 0
        .null "We should go sometime."
        .byte $FF
        .send ftext
        .section ftext
cv_ch9:
        .byte 1
        .null "Remember that camping trip?"
        .byte 0
        .null "When the tent blew away? Ha!"
        .byte 1
        .null "Best trip ever."
        .byte $FF
        .send ftext

