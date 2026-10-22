; acts/kitchen.asm -- activities: the kitchen: fridge, meals, washing up, drinks, the dog's dinner

; --- kitchen ---------------------------------------------------------------------------
st_fridge:
        ldx #PATCH_FRIDGE
        jsr patch_apply
        lda #SFX_DOOR
        jsr sfx_play
        lda #2
        jmp set_timer_secs
en_fridge:
        ldx #PATCH_FRIDGE
        jsr patch_remove
        lda food
        beq +
        dec food
        lda #A_MEAL
        sta p_pending
+       rts
st_meal:
        lda #0                  ; the plate is on the table
        sta held
        lda cook_stage
        cmp #7
        bne +
        lda #0
        sta cook_stage
+       #POSE SPR_EAT, POSE_EAT_X, POSE_EAT_Y
        lda #7
        jmp set_timer_secs
; chew (mouth open/shut), and every couple of seconds a bite: hand to mouth
tk_meal:
        lda p_anim
        and #127
        cmp #24
        bcs l_tkm_chew
        lda #<SPR_EATHAND
        ldx #>SPR_EATHAND
        bra l_tkm_set
l_tkm_chew:
        lda p_anim
        and #8
        bne +
        lda #<SPR_EATSHUT
        ldx #>SPR_EATSHUT
        bra l_tkm_set
+       lda #<SPR_EAT
        ldx #>SPR_EAT
l_tkm_set:
        sta pose_spr
        stx pose_spr+1
        rts
en_meal:
        jsr feel_better         ; (a good meal puts the colour back in his cheeks)
        lda #0
        sta hunger
        lda #1
        sta brush_todo
        lda #HELD_PLATEE        ; the empty plate to the sink
        sta held
        lda #A_DISHES
        sta p_pending
        lda #3
        jsr mood_up
        #SAY l_say_yum
        rts

; Fed (or watered) when he's sick: out of the green at once.
feel_better:
        lda health
        cmp #45
        bcs +
        lda #45
        sta health
+       rts

; Washing up: at the kitchen sink, back to you, hands busy, the tap running.
HELD_PLATEE     = 8
DISH_CLOSE      = 5             ; he steps right up to the sink
st_dishes:
        lda #PM_BACKSTAND
        sta p_mode
        lda p_y
        sec
        sbc #DISH_CLOSE
        sta p_y
        lda #0                  ; (in the sink)
        sta held
        lda #COUNTER_HANDS_Y - DISH_CLOSE
        jsr hands_rummage
        lda #$90                ; the tap
        sta shower_pitch
        lda #1
        sta shower_on
        lda #5
        jmp set_timer_secs
en_dishes:
        lda #FLOOR0_Y           ; back out to the middle of the floor
        sta p_y
        lda #0
        sta shower_on
        sta held
        lda #$C0
        sta shower_pitch
        lda #PM_STAND
        sta p_mode
        lda #1
        jmp mood_up
; A drink of water: a cup from beside the sink, filled at the cooler (the
; bottle's level drops), drunk facing you with the cup tipped up, then back
; in the sink. A dry bottle makes him glum; the third time running he asks
; you for water, out loud or in a letter.
drink_stage:    .byte 0     ; 0 none, 1 cup in hand (to the cooler), 2 cup to the sink
drink_act:      .byte 0, A_DRINK, A_CUPSINK
drinking:       .byte 0     ; 1 = cup at his lips (front view)
dry_count:      .byte 0     ; dry bottles in a row
ask_water:      .byte 0     ; 1 = ask for water once the cup's put away
dk_t:           .byte 0
HELD_CUP        = 5
HELD_CUPFULL    = 6

; Thirsty: off for a drink? C = 1 with A = what to do. Not back to a dry
; bottle more than every half hour or so.
drink_go:
        lda water
        bne +
        lda complain_cd
        beq +
        clc
        rts
+       lda #A_GETCUP
        sec
        rts

st_getcup:
        lda #PM_BACKSTAND
        sta p_mode
        lda #0
        sta dk_t
        lda #1
        jmp set_timer_secs
tk_getcup:
        inc dk_t
        lda dk_t
        cmp #25
        bne +
        lda #HELD_CUP
        sta held
        lda #1
        sta drink_stage
        lda #SFX_TINK
        jmp sfx_play
+       rts
en_getcup:
        lda drink_stage
        cmp #1
        bne +
        lda #A_DRINK
        sta p_pending
+       rts

st_drink:
        lda #0
        sta dk_t
        lda #1                  ; facing the cooler
        sta p_flip
        lda #7
        jmp set_timer_secs
tk_drink:
        inc dk_t
        lda dk_t
        cmp #15                 ; fill the cup
        bne l_tkdr_1
        lda held
        cmp #HELD_CUPFULL
        beq l_tkdr_out          ; (already filled)
        lda water
        bne +
        jmp drink_dry
+       dec water
        lda #1
        sta ui_dirty
        lda #HELD_CUPFULL
        sta held
        lda #SFX_GLUG
        jmp sfx_play
l_tkdr_1:
        cmp #40                 ; the glass in front of him...
        bne +
        lda #0                  ; (drawn with him now)
        sta held
        jmp sip_down
+       cmp #65                 ; ...up for a sip, a second and a half...
        beq l_tkdr_up
        cmp #165                ; ...and again
        beq l_tkdr_up
        cmp #140
        beq l_tkdr_down
        cmp #240
        beq l_tkdr_down
        cmp #255                ; ahh
        bne l_tkdr_out
        bra l_tkdr_done
l_tkdr_up:
        jmp sip_up
l_tkdr_down:
        jmp sip_down
l_tkdr_done:
        jsr feel_better         ; (a drink helps too, if it was thirst)
        lda #0
        sta drinking
        sta thirst
        sta dry_count
        lda #PM_STAND
        sta p_mode
        lda #HELD_CUP
        sta held
        lda #2
        sta drink_stage
        lda #1
        sta ui_dirty
l_tkdr_out:
        rts
; A glass of water (him, or his friend swapped in): held in front of him,
; or up at his lips with a glug.
sip_down:
        lda #PM_SIPDOWN
        sta p_mode
        rts
sip_up:
        lda #PM_SIPUP
        sta p_mode
        lda #SFX_GLUG
        jmp sfx_play
; Drawing him with it (4 columns of padding in front).
sip_person_sprite:
        #SETACT 0, SPR_SIPDOWN
        lda p_mode
        cmp #PM_SIPUP
        bne +
        #SETACT 0, SPR_SIPUP
+       lda p_flip
        bne +
        sec                     ; facing left: the padding's on the left
        lda act_xl2+0
        sbc #4
        sta act_xl2+0
        lda act_xh2+0
        sbc #0
        sta act_xh2+0
+       jmp l_ab_person_done

; the bottle's dry: glum, and after a few times, ask
drink_dry:
        lda #3
        jsr mood_down
        lda #30                 ; not back for a while
        sta complain_cd
        lda #2
        sta drink_stage
        inc dry_count
        lda dry_count
        cmp #3
        bcc +
        lda #0
        sta dry_count
        lda #1
        sta ask_water
+       lda #0                  ; that's that
        sta act_timer
        sta act_timer+1
        #SAY l_say_dry
        rts
en_drink:
        lda #0
        sta drinking
        lda #PM_STAND
        sta p_mode
        lda drink_stage
        cmp #2
        bne +
        lda #A_CUPSINK
        sta p_pending
+       rts

st_cupsink:
        lda #PM_BACKSTAND
        sta p_mode
        lda #0
        sta dk_t
        lda #1
        jmp set_timer_secs
tk_cupsink:
        inc dk_t
        lda dk_t
        cmp #25
        bne l_tkcs_out
        lda #0                  ; in the sink
        sta held
        sta drink_stage
        lda #SFX_TINK
        jsr sfx_play
        lda ask_water           ; and now: please, some water
        beq l_tkcs_out
        lda #0
        sta ask_water
        lda #A_ASKWATER
        sta p_pending
        jsr rnd
        and #1
        beq l_tkcs_out
        lda #A_LETTER           ; (or a letter about it)
        sta p_pending
l_tkcs_out:
        rts

st_askwater:
        lda #PM_FRONT
        sta p_mode
        #SAY l_say_needwater
        jsr speak
        lda #4
        jmp set_timer_secs
        .section ftext
l_say_dry:       .null "Empty! Not a drop left..."
        .send ftext
        .section ftext
l_say_needwater: .null "I'm SO thirsty! Could you fill my water bottle? (CTRL-W)"
        .send ftext
; Feeding the dog: a can from the dog-food cupboard (one fewer on the shelf),
; then beside the stove he leans down and fills the bowl.
st_dogfood:
        lda #PM_BACKSTAND
        sta p_mode
        lda #0
        sta ck_t
        lda #1
        sta cb_which
        lda #3
        jmp set_timer_secs
tk_dogfood:
        inc ck_t
        lda ck_t
        cmp #2
        bne +
        lda #SFX_DOOR
        jsr sfx_play
        jmp cupboard_show
+       cmp #60
        bne +
        lda dogfood
        beq l_tkdf_out
        dec dogfood
        lda #1
        sta ui_dirty
        lda #HELD_CAN
        sta held
        jmp cupboard_show
+       cmp #110
        bne l_tkdf_out
        jmp cupboard_close
l_tkdf_out:
        rts
en_dogfood:
        jsr cupboard_close
        lda held
        cmp #HELD_CAN
        bne +
        lda #A_FEEDDOG
        sta p_pending
+       rts

st_feeddog:
        lda #0
        sta ck_t
        sta p_flip              ; facing the bowl
        lda held                ; (asked to feed it with no can in hand: one
        cmp #HELD_CAN           ;  from the cupboard, unseen)
        beq +
        lda dogfood
        beq +
        dec dogfood
        lda #HELD_CAN
        sta held
        lda #1
        sta ui_dirty
+       lda #3
        jmp set_timer_secs
tk_feeddog:
        inc ck_t
        lda ck_t
        cmp #20                 ; down to the bowl
        bne +
        lda #PM_BENDSIDE
        sta p_mode
        rts
+       cmp #60                 ; tip it in
        bne +
        lda held
        cmp #HELD_CAN
        bne l_tkfd_out
        lda #0
        sta held
        lda #1
        sta bowl_full
        lda #SFX_CLACK
        jmp sfx_play
+       cmp #100
        bne l_tkfd_out
        lda #PM_STAND
        sta p_mode
l_tkfd_out:
        rts
en_feeddog:
        lda #PM_STAND
        sta p_mode
        lda bowl_full
        beq +
        #SAY l_say_goodboy
+       rts

