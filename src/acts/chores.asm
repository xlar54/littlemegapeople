; acts/chores.asm -- activities: chores: deliveries, cooking, vacuuming

; Deliveries. He opens the front door, bends to pick the package up off the
; step, carries it in front of him, and puts it where it belongs (facing it:
; cupboard, low cabinet, bookshelf, record player). Food and dog food go into
; the supplies then; a book gets read, a record played.
DLV_FOOD        = 1
DLV_DOG         = 2
DLV_BOOK        = 3
DLV_RECORD      = 4
delivery:       .byte 0     ; what's on the step / in his hands (0 = nothing)
carrying:       .byte 0     ; 1 = in his hands
dlv_t:          .byte 0
;                 food  dog   book  record
stow_floor:     .byte 0,    0,    1,    2
stow_x:         .byte 78,   56,   252,  74
stow_bend:      .byte 0,    0,    0,    1
stow_px:        .byte 74,   52,   248,  70     ; where the package sits as he puts it away
stow_py:        .byte 150,  150,  104,  45
pkg_l:          .byte <SPR_PKGFOOD, <SPR_PKGDOG, <SPR_PKGBOOK, <SPR_PKGRECORD
pkg_h:          .byte >SPR_PKGFOOD, >SPR_PKGDOG, >SPR_PKGBOOK, >SPR_PKGRECORD

st_delivery:
        ldx #PATCH_DOOR
        jsr patch_apply
        lda #SFX_DOOR
        jsr sfx_play
        lda #0
        sta dlv_t
        lda #1
        sta p_flip              ; facing out of the door
        lda #3
        jmp set_timer_secs
tk_delivery:
        inc dlv_t
        lda dlv_t
        cmp #30                 ; bend down for it
        bne +
        lda #PM_BENDSIDE
        sta p_mode
        rts
+       cmp #80                 ; picked up: straighten, in his hands
        bne +
        lda #PM_STAND
        sta p_mode
        lda #1
        sta carrying
        rts
+       cmp #110
        bne +
        ldx #PATCH_DOOR         ; shut the door
        jmp patch_remove
+       rts
en_delivery:
        ldx #PATCH_DOOR
        jsr patch_remove
        lda #1
        sta carrying
        lda #A_STOW
        sta p_pending
        rts

st_stow:
        lda #0
        sta dlv_t
        lda #PM_BACKSTAND
        ldx delivery
        ldy stow_bend-1,x
        beq +
        lda #PM_BEND
+       sta p_mode
        lda #0
        sta carrying            ; now on the shelf / in the cupboard
        lda #2
        ldx delivery
        cpx #DLV_DOG + 1
        bcs +
        dex                     ; groceries / dog food: open up, put it in, close
        stx cb_which
        lda #3
+       jmp set_timer_secs
; Groceries / dog food: the cupboard doors open on the jars (cans) already
; there, the bag goes in and becomes one more (the supply goes up), the doors
; close.
cb_which:       .byte 0     ; 0 food cupboard, 1 dog-food cupboard
tk_stow:
        inc dlv_t
        lda delivery
        beq +                   ; (already put in: it's on the shelf)
        cmp #DLV_DOG + 1
        bcc +
        rts
+       lda dlv_t
        cmp #2
        bne +
        lda #SFX_DOOR
        jsr sfx_play
        jmp cupboard_show
+       cmp #60
        bne +
        lda delivery            ; in: now it's food on the shelf
        jsr delivery_apply
        lda #0
        sta delivery
        jmp cupboard_show
+       cmp #120
        bne l_tkst_out
        jmp cupboard_close
l_tkst_out:
        rts
en_stow:
        jsr cupboard_close
        lda delivery
        beq +
        jsr delivery_apply
+       lda #0
        sta delivery
        sta carrying
        rts

; Show the cupboard open with a jar (can) for every two food (dog food),
; at most 4.
cupboard_show:
        jsr cupboard_forget
        lda food
        ldx cb_which
        beq +
        lda dogfood
+       clc
        adc #1
        lsr
        cmp #5
        bcc +
        lda #4
+       ldx cb_which
        beq +
        clc
        adc #PATCH_DOGCAB - PATCH_CUPBOARD
+       clc
        adc #PATCH_CUPBOARD
        tax
        jmp patch_apply
; Shut it (whichever jar picture is up).
cupboard_close:
        ldx #PATCH_CUPBOARD
-       phx
        jsr patch_remove
        plx
        inx
        cpx #PATCH_DOGCAB + 5
        bne -
        rts
; The new picture overwrites the old one: just mark them all as not shown.
cupboard_forget:
        lda #0
        ldx #9
-       sta patch_state + PATCH_CUPBOARD,x
        dex
        bpl -
        rts

; A = delivery type: it's in the house now
delivery_apply:
        cmp #DLV_FOOD
        bne +
        lda food
        clc
        adc #3
        cmp #10
        bcc l_da_food
        lda #9
l_da_food:
        sta food
        lda gift_flags
        ora #4
        sta gift_flags
        lda #1
        sta ui_dirty
        lda #3
        jmp mood_up
+       cmp #DLV_DOG
        bne +
        lda dogfood
        clc
        adc #3
        cmp #10
        bcc l_da_dog
        lda #9
l_da_dog:
        sta dogfood
        lda #1
        sta ui_dirty
        rts
+       cmp #DLV_BOOK
        bne +
        lda gift_flags
        ora #1
        sta gift_flags
        lda #8
        jsr mood_up
        lda #A_READCHAIR        ; a new book: read it
        sta p_pending
        rts
+       lda gift_flags          ; a record: play it
        ora #2
        sta gift_flags
        lda #8
        jsr mood_up
        lda #A_RECORD
        sta p_pending
        rts

; Cooking. At mealtimes he takes a jar from the food cupboard, prepares it at
; the counter, puts the pot on the stove (a flame under it) and goes off while
; it cooks; then the pot comes off, he dishes up at the counter and carries
; the plate to the table. cook_stage says which step is next, so he picks up
; where he left off if something interrupts him.
cook_stage:     .byte 0     ; 0 none, 1 get food, 2 prep, 3 stove on,
                            ; 4 cooking, 5 stove off, 6 serve, 7 eat
cook_act:       .byte 0, A_GETFOOD, A_PREP, A_STOVEON, 0, A_STOVEOFF, A_SERVE, A_MEAL
cook_left:      .word 0     ; frames until it's done
COOK_FRAMES     = 1500      ; about half a minute
meals_done:     .byte 0     ; today: bit 0 breakfast, 1 lunch, 2 dinner
ck_t:           .byte 0
held:           .byte 0     ; in his hands: 0 nothing, 1 jar, 2 pot, 3 plate
HELD_JAR        = 1
HELD_POT        = 2
HELD_PLATE      = 3
HELD_CAN        = 4
held_l:         .byte <SPR_HELDJAR, <SPR_HELDPOT, <SPR_HELDPLATE, <SPR_HELDCAN, <SPR_HELDCUP, <SPR_HELDCUPFULL, <SPR_HELDVAC, <SPR_HELDPLATEE, <SPR_HELDBOOK, <SPR_HELDPAPER
held_h:         .byte >SPR_HELDJAR, >SPR_HELDPOT, >SPR_HELDPLATE, >SPR_HELDCAN, >SPR_HELDCUP, >SPR_HELDCUPFULL, >SPR_HELDVAC, >SPR_HELDPLATEE, >SPR_HELDBOOK, >SPR_HELDPAPER
HELD_BOOK       = 9         ; a book off the shelf, to the armchair
HELD_PAPER      = 10        ; the morning paper, to the armchair
COUNTER_HANDS_Y = 174         ; just above his waist

; C = 1 if it's time for a meal he hasn't had today (and marks it had):
; breakfast until 10, lunch 12-2, dinner 6-8.
meal_due:
        lda clock_hour
        ldx #1
        cmp #10
        bcc l_md_check
        ldx #2
        cmp #12
        bcc l_md_no
        cmp #14
        bcc l_md_check
        ldx #4
        cmp #18
        bcc l_md_no
        cmp #20
        bcs l_md_no
l_md_check:
        txa
        and meals_done
        bne l_md_no
        txa
        ora meals_done
        sta meals_done
        sec
        rts
l_md_no:
        clc
        rts

; every sim tick: the pot cooks
cook_tick:
        lda cook_left
        ora cook_left+1
        beq l_ckt_out
        lda cook_left
        bne +
        dec cook_left+1
+       dec cook_left
        lda cook_left
        ora cook_left+1
        bne l_ckt_out
        lda cook_stage          ; done: time to take it off
        cmp #4
        bne l_ckt_out
        lda #5
        sta cook_stage
l_ckt_out:
        rts

; 1: a jar from the food cupboard (one fewer on the shelf)
st_getfood:
        lda #PM_BACKSTAND
        sta p_mode
        lda #0
        sta ck_t
        sta cb_which
        lda #3
        jmp set_timer_secs
tk_getfood:
        inc ck_t
        lda ck_t
        cmp #2
        bne +
        lda #SFX_DOOR
        jsr sfx_play
        jmp cupboard_show
+       cmp #60
        bne +
        lda food                ; take one
        beq l_tkg_out
        dec food
        lda #1
        sta ui_dirty
        lda #HELD_JAR
        sta held
        lda #2
        sta cook_stage
        jmp cupboard_show
+       cmp #110
        bne l_tkg_out
        jmp cupboard_close
l_tkg_out:
        rts
en_getfood:
        jsr cupboard_close
        lda cook_stage
        cmp #1
        bne +
        lda #0                  ; nothing in the cupboard after all
        sta cook_stage
        jmp complain_food
+       jsr rnd                 ; half the time: something from the fridge too
        and #1
        beq +
        lda #A_FRIDGEGET
        sta p_pending
+       rts

; the fridge door opens, he reaches in, it shuts
st_fridgeget:
        ldx #PATCH_FRIDGE
        jsr patch_apply
        lda #SFX_DOOR
        jsr sfx_play
        lda #0
        sta ck_t
        lda #2
        jmp set_timer_secs
tk_fridgeget:
        inc ck_t
        lda ck_t
        cmp #30                 ; reaching in
        bne +
        lda #PM_BENDSIDE
        sta p_mode
        rts
+       cmp #65
        bne +
        lda #PM_STAND
        sta p_mode
        rts
+       cmp #80
        bne +
        ldx #PATCH_FRIDGE
        jmp patch_remove
+       rts
en_fridgeget:
        ldx #PATCH_FRIDGE
        jmp patch_remove

; 2 and 6: at the counter, his hands busy (chopping, then dishing up)
st_prep:
        lda #PM_BACKSTAND
        sta p_mode
        lda #0
        sta held                ; (it's on the counter now)
        sta ck_t
        lda #COUNTER_HANDS_Y
        jsr hands_rummage
        lda #3
        jmp set_timer_secs
tk_prep:
        inc ck_t
        lda ck_t
        and #15
        bne +
        lda #SFX_CLACK          ; chop, chop
        jmp sfx_play
+       rts
en_prep:
        lda ck_t
        cmp #140
        bcc +
        lda #HELD_POT           ; ready for the stove
        sta held
        lda #3
        sta cook_stage
        lda #A_STOVEON
        sta p_pending
        rts
+       lda #HELD_JAR           ; (interrupted: still to do)
        sta held
        rts
st_serve:
        lda #PM_BACKSTAND
        sta p_mode
        lda #0
        sta held
        sta ck_t
        lda #COUNTER_HANDS_Y
        jsr hands_rummage
        lda #3
        jmp set_timer_secs
en_serve:
        lda ck_t
        cmp #140
        bcc +
        lda #HELD_PLATE         ; dinner is served
        sta held
        lda #7
        sta cook_stage
        lda #A_MEAL
        sta p_pending
        rts
+       lda #HELD_POT
        sta held
        rts

; 3: the pot onto the stove, flame lit; off he goes while it cooks
st_stoveon:
        lda #0
        sta ck_t
        sta p_flip              ; facing the stove
        lda #2
        jmp set_timer_secs
tk_stoveon:
        inc ck_t
        lda ck_t
        cmp #30
        bne +
        lda #0
        sta held
        ldx #PATCH_POT
        jsr patch_apply
        lda #4
        sta cook_stage
        lda #<COOK_FRAMES
        sta cook_left
        lda #>COOK_FRAMES
        sta cook_left+1
        lda #SFX_CLACK
        jmp sfx_play
+       rts
en_stoveon:
        lda #PM_STAND
        sta p_mode
        rts

; 5: done: the pot off the stove, to the counter
st_stoveoff:
        lda #0
        sta ck_t
        sta p_flip
        lda #2
        jmp set_timer_secs
tk_stoveoff:
        inc ck_t
        lda ck_t
        cmp #30
        bne +
        ldx #PATCH_POT
        jsr patch_remove
        lda #HELD_POT
        sta held
        lda #6
        sta cook_stage
        lda #SFX_CLACK
        jmp sfx_play
+       rts
en_stoveoff:
        lda #PM_STAND
        sta p_mode
        lda cook_stage
        cmp #6
        bne +
        lda #A_SERVE
        sta p_pending
+       rts

; Vacuuming (now and then): the vacuum cleaner from the attic closet, back
; and forth over the attic floor and the middle floor with it humming, then
; back in the closet.
vac_stage:      .byte 0     ; 0 none, 1 fetch, 2 attic, 3 middle floor,
                            ; 4 ground floor, 5 put away
vac_act:        .byte 0, A_VACGET, A_VACATTIC, A_VACMID, A_VACGROUND, A_VACPUT
vac_done:       .byte 0     ; 1 = done today
vac_t:          .byte 0
vac_lo:         .byte 0     ; this floor's sweep: from, to, passes left
vac_hi:         .byte 0
vac_pass:       .byte 0
HELD_VAC        = 7
vac_parked:     .byte 0     ; 1 = left standing where he was
park_floor:     .byte 0
park_x:         .word 0
park_flip:      .byte 0

; Asked to stop vacuuming: C = 1 if he was (and it's going back in the closet,
; fetched first if he'd left it standing somewhere; done for today).
vac_stop:
        lda vac_stage
        ora vac_parked
        bne +
        clc
        rts
+       lda #1
        sta vac_done
        lda held
        cmp #HELD_VAC
        bne l_vs_notheld
        lda #5                  ; in his hands: straight back to the closet
        sta vac_stage
        lda #A_VACPUT
        bra l_vs_go
l_vs_notheld:
        lda vac_parked          ; left standing: pick it up, then put it away
        beq l_vs_none
        lda #5
        sta vac_stage
        lda #A_VACPICK
        bra l_vs_go
l_vs_none:
        lda #0                  ; (not even out of the closet yet)
        sta vac_stage
        jsr vac_closet_shut
        lda #A_IDLE
l_vs_go:
        jsr request_pending
        ldx #<l_say_vacstop
        ldy #>l_say_vacstop
        jsr ui_say
        sec
        rts
        .section ftext
l_say_vacstop:  .null "OK, I'll put the vacuum away."
        .send ftext

; X = what he's about to do. Anything but the vacuuming while he has the
; vacuum: he leaves it standing where he is (and comes back for it).
vac_maybe_park:
        lda held                ; (the book or paper he was taking to the
        cmp #HELD_BOOK          ;  armchair: something else instead, so it's
        bne +                   ;  put down)
        cpx #A_READCHAIR
        bne l_vmp_drop
+       cmp #HELD_PAPER
        bne +
        cpx #A_PAPERREAD
        beq +
l_vmp_drop:
        lda #0
        sta held
+       lda held
        cmp #HELD_VAC
        bne l_vmp_out
        cpx #A_VACGET
        bcc +
        cpx #A_VACGROUND + 1
        bcc l_vmp_out           ; (45..49: the vacuuming itself)
+       cpx #A_VACPICK
        beq l_vmp_out
        lda #1
        sta vac_parked
        lda p_floor
        sta park_floor
        lda p_x
        sta park_x
        lda p_x+1
        sta park_x+1
        lda p_flip
        sta park_flip
        lda #0
        sta held
l_vmp_out:
        rts

; back at the vacuum: bend, take hold of it, carry on
st_vacpick:
        lda park_flip
        sta p_flip
        lda #PM_BENDSIDE
        sta p_mode
        lda #0
        sta vac_t
        lda #1
        jmp set_timer_secs
tk_vacpick:
        inc vac_t
        lda vac_t
        cmp #25
        bne +
        lda #HELD_VAC
        sta held
        lda #0
        sta vac_parked
        lda #PM_STAND
        sta p_mode
+       rts
en_vacpick:
        lda #PM_STAND
        sta p_mode
        lda vac_parked          ; (interrupted before he got it: still there)
        bne +
        lda #HELD_VAC
        sta held
+       rts
;                 ground  middle (up to the bed)  attic (between the slopes)
vac_lo_tbl:     .byte 40,     74,                     36
vac_hi_tbl:     .byte 250,    250,                    250
VAC_PITCH       = $28       ; the hum: low noise

st_vacget:
        lda #1
        sta vac_stage
        lda #PM_BACKSTAND
        sta p_mode
        lda #0
        sta vac_t
        ldx #PATCH_VACCLOSET
        jsr patch_apply
        lda #SFX_DOOR
        jsr sfx_play
        lda #3
        jmp set_timer_secs
tk_vacget:
        inc vac_t
        lda vac_t
        cmp #60                 ; out it comes
        bne +
        lda #HELD_VAC
        sta held
        lda #2
        sta vac_stage
        ldx #PATCH_VACCLOSET + 1
        jmp patch_apply
+       cmp #120
        bne +
        jmp vac_closet_shut
+       rts
en_vacget:
vac_closet_shut:
        ldx #PATCH_VACCLOSET    ; (both pictures: whichever is up)
        jsr patch_remove
        ldx #PATCH_VACCLOSET + 1
        jmp patch_remove

; 2, 3: back and forth across the floor, twice over, humming
st_vacsweep:
        lda held
        cmp #HELD_VAC
        beq +
        lda #0                  ; (lost it somehow: put it away)
        sta vac_stage
        lda #1
        jmp set_timer_secs
+       ldx p_floor             ; this floor's stretch (the vacuum's head
        lda vac_lo_tbl,x        ;  runs 15px ahead of him)
        sta vac_lo
        lda vac_hi_tbl,x
        sta vac_hi
        lda #3
        sta vac_pass
        lda #PM_WALK
        sta p_mode
        lda #VAC_PITCH
        sta shower_pitch
        lda #1
        sta shower_on
        lda #60
        jmp set_timer_secs
tk_vacsweep:
        lda vac_pass
        bne +
        rts
+       lda p_anim              ; a step every other frame
        and #1
        bne l_tkv_out
        lda p_flip
        bne l_tkv_right
        lda p_x                 ; left
        cmp vac_lo
        bcc l_tkv_turn
        beq l_tkv_turn
        dec p_x
        rts
l_tkv_right:
        lda p_x
        cmp vac_hi
        bcs l_tkv_turn
        inc p_x
        rts
l_tkv_turn:
        lda p_flip
        eor #1
        sta p_flip
        dec vac_pass
        bne l_tkv_out
        lda #0                  ; this floor's done
        sta act_timer
        sta act_timer+1
        lda vac_stage
        clc
        adc #1
        sta vac_stage
l_tkv_out:
        rts
en_vacsweep:
        lda #0
        sta shower_on
        lda #$C0
        sta shower_pitch
        lda #PM_STAND
        sta p_mode
        rts

; 4: back in the closet
st_vacput:
        lda #PM_BACKSTAND
        sta p_mode
        lda #0
        sta vac_t
        ldx #PATCH_VACCLOSET + 1
        jsr patch_apply
        lda #SFX_DOOR
        jsr sfx_play
        lda #3
        jmp set_timer_secs
tk_vacput:
        inc vac_t
        lda vac_t
        cmp #60                 ; in it goes
        bne +
        lda #0
        sta held
        sta vac_stage
        lda #1
        sta vac_done
        ldx #PATCH_VACCLOSET + 1
        jsr patch_remove
        ldx #PATCH_VACCLOSET
        jmp patch_apply
+       cmp #120
        bne +
        jmp vac_closet_shut
+       rts
en_vacput:
        jmp vac_closet_shut

