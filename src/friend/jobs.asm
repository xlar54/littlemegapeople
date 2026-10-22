; friend/jobs.asm -- his friend: things he does: joining in, his own errands, asking for a go, once a visit, the stairs order, invitations (see friend/visit.asm)
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
FRJ_PONG        = 9         ; at his end of the attic desk, playing ping pong
FRJ_CUPSINK     = 10        ; his glass in the kitchen sink (after a drink)
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
FD_PONG         = 32
FD_ALL          = FD_CARDS | FD_MUSIC | FD_VG | FD_TV
fr_music:       .byte 0     ; 1 = they're off to put a record on together
fr_want:        .byte 0     ; allowed a go on the computer / TV: spot + 1
fr_tvon:        .byte 0     ; he switched the TV on (so he'll switch it off)
fr_turn:        .byte 0     ; 1 = Larry's turn at the game next
fr_turns:       .byte 0     ; turns taken at it, this go
;                 TV     dance  comp.  piano  snack  water  WC
fj_act:     .byte A_TV,  A_DANCE, A_COMPUTER, A_PIANO
;                                                            comp.  TV chair
;                                                                          sink   intro  ping pong
;                                                                                               kitchen sink
fj_floor:   .byte 2,     2,     1,     2,     0,     0,     1,     1,     2,     1,     0,     2,     0
fj_x:       .byte 132,   104,   250,   198,   52,    138,   196,   <278,  108,   177,   <270,  <262,  82
fj_xh:      .byte 0,     0,     0,     0,     0,     0,     0,     >278,  0,     0,     >270,  >262,  0
fj_face:    .byte 0,     0,     1,     0,     0,     1,     1,     1,     0,     0,     0,     0,     0
FJ_CUPSINK      = 12        ; (the kitchen sink spot)
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
+       cmp #FRJ_PONG
        bne +
        jmp fr_pong
+       cmp #FRJ_CUPSINK
        bne +
        jmp fr_cupsink
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
        txa                     ; 4-11: snack, water, WC, computer, TV, sink,
                                ;  intro, ping pong
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
        .section ftext
l_fr_vgdone:    .null "That was fun! New high score!"
        .send ftext
        .section ftext
l_fr_yourturn:  .null "Your turn!"
        .send ftext
        .section ftext
l_fr_myturn:    .null "My turn!"
        .send ftext
        .section ftext
l_fr_gg:        .null "Good game! That was fun."
        .send ftext

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
        .section ftext
l_fr_snack:     .null "Mind if I grab a snack?"
        .send ftext
        .section ftext
l_fr_tasty:     .null "Mmm, tasty!"
        .send ftext

; a drink at the water cooler (the bottle goes down a little): a glass
; filled, two sips -- up to his lips, half a second, down again -- then the
; glass to the kitchen sink
fr_sipped:      .byte 0
fr_water:
        lda fr_jt+1
        bne l_fwa_end
        lda fr_jt
        cmp #20
        bne l_fwa_1
        lda #0
        sta fr_sipped
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
        sta fr_sipped
        lda #SFX_GLUG
        jsr sfx_play
        jsr sip_down
        sec
        rts
l_fwa_1:
        ldx fr_sipped           ; (nothing to drink: no sipping)
        beq l_fwa_2
        cmp #40                 ; up for a sip, a second and a half, down;
        beq l_fwa_up            ;  and again
        cmp #135
        beq l_fwa_up
        cmp #115
        beq l_fwa_down
        cmp #210
        bne l_fwa_2
        jsr sip_down
        sec
        rts
l_fwa_up:
        jsr sip_up
        sec
        rts
l_fwa_down:
        jsr sip_down
        sec
        rts
l_fwa_2:
        cmp #225
        bne +
        lda #PM_STAND
        sta p_mode
        ldx #<l_fr_ahh
        ldy #>l_fr_ahh
        jsr fr_say_if
        sec
        rts
+       cmp #250
        bcc l_fsn_out
l_fwa_end:
        lda fr_sipped           ; then the glass to the sink
        beq +
        lda #FJ_CUPSINK + 1
        sta fr_want
+       jmp fr_job_end

; his glass into the kitchen sink: back to you at it, a tink
fr_cupsink:
        lda fr_jt
        cmp #1
        bne +
        lda #PM_BACKSTAND
        sta p_mode
        sec
        rts
+       cmp #25
        bne +
        lda #SFX_TINK
        jsr sfx_play
        sec
        rts
+       cmp #50
        bcc l_fcs_out
        jmp fr_job_end
l_fcs_out:
        sec
        rts
        .section ftext
l_fr_nowater:   .null "Oops, the water's all gone."
        .send ftext
        .section ftext
l_fr_ahh:       .null "Ahh, refreshing."
        .send ftext

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
        ldx fr_state            ; (expecting him: no going out)
        cpx #FRS_COMING
        bcc +
        cpx #FRS_ENTER
        bcs +
        cmp #A_GOOUT
        bne +
        lda #A_IDLE
        rts
+       ldx fr_state            ; (a book with a guest over: rude)
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
        .section ftext
cv_askvg:
        .byte 1
        .null "Want to play video games with me?"
        .byte 0
        .null "Sure! You go first."
        .byte $FF
        .send ftext
        .section ftext
cv_asktv:
        .byte 1
        .null "Mind if I watch some TV?"
        .byte 0
        .null "Sure, help yourself!"
        .byte $FF
        .send ftext
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
        lda fr_force            ; (you asked him to: it's Joey, for sure)
        beq +
        lda #0
        sta fr_force
        bra l_fi_yes
+       lda clock_hour
        cmp #18
        bcs l_fi_no
        lda #3
        jsr rnd_range
        bne l_fi_no
l_fi_yes:
        lda #<l_call_fr
        sta l_tpc_p
        lda #>l_call_fr
        sta l_tpc_p+1
        lda #FRS_COMING          ; on his way: there in 1 1/2 - 4 minutes
        sta fr_state
        jsr rnd                 ; (4500 + 0..255 * 30 frames)
        sta fr_t
        lda #0
        sta fr_t+1
        ldx #5                  ; *32 ...
-       asl fr_t
        rol fr_t+1
        dex
        bne -
        clc
        lda fr_t
        adc #<4500
        sta fr_t
        lda fr_t+1
        adc #>4500
        sta fr_t+1
        sec
        rts
l_fi_no:
        clc
        rts
        .section ftext
l_call_fr:      .null ": Hey Joey! Want to come over for a while?"
        .send ftext

; You asked him to call Joey over: the call, and it's Joey he rings.
fr_force:       .byte 0
st_callfriend:
        lda #1
        sta fr_force
        jmp st_phonecall

; Asked to invite Joey: C = 1 he can; else X/Y = why not.
fr_can_invite:
        ldx #<l_say_joeyhere
        ldy #>l_say_joeyhere
        lda fr_state
        cmp #FRS_ENTER
        bcs l_fci_no
        ldx #<l_say_joeycoming
        ldy #>l_say_joeycoming
        cmp #FRS_COMING
        bcs l_fci_no
        ldx #<l_say_joeysick
        ldy #>l_say_joeysick
        lda health
        cmp #40
        bcc l_fci_no
        ldx #<l_say_badtime     ; (before 9am, from 7pm)
        ldy #>l_say_badtime
        lda clock_hour
        cmp #9
        bcc l_fci_no
        cmp #19
        bcs l_fci_no
        sec
        rts
l_fci_no:
        clc
        rts
        .section ftext
l_say_joeyhere:     .null "Joey's already here!"
l_say_joeycoming:   .null "He's on his way already!"
l_say_joeysick:     .null "I'm not up to company today."
nm_callfriend:      .null " is calling Joey."
        .send ftext

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

