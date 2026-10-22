; acts/dogwalk.asm -- activities: walking the dog

; Walking the dog, three times a day: he bends to clip the leash on, the
; dog leads him to the front door, out they go; back a while later, and the
; leash comes off.
walk_stage:     .byte 0     ; 0 none, 1 leash on, 2 out, 3 leash off
walk_act:       .byte 0, A_LEASH, A_WALKOUT, A_UNLEASH
dog_walks:      .byte 0     ; today: bits 0 morning, 1 afternoon, 2 evening
dog_lead:       .byte 0     ; 1 = on the lead
dog_hold:       .byte 0     ; 1 = staying put for him
dog_petted:     .byte 0     ; 1 = he's petting it: sat up facing him, wagging
dog_out:        .byte 0     ; 1 = outside
lead_t:         .byte 0
DOG_LEAD_DX     = 24        ; the dog this far ahead of him

; C = 1 at walk time (9-11am, 2-4pm, 7-9pm) if not walked then (and marks
; it); only with the dog in, and not begging or eating.
dog_walk_due:
        lda dog_floor           ; (it's downstairs)
        bne l_dwd_no
        lda dog_state
        beq l_dwd_no
        cmp #3
        beq l_dwd_no
        lda dog_beg
        bne l_dwd_no
        lda clock_hour
        ldx #1
        cmp #9
        bcc l_dwd_no
        cmp #11
        bcc l_dwd_check
        ldx #2
        cmp #14
        bcc l_dwd_no
        cmp #16
        bcc l_dwd_check
        ldx #4
        cmp #19
        bcc l_dwd_no
        cmp #21
        bcs l_dwd_no
l_dwd_check:
        txa
        and dog_walks
        bne l_dwd_no
        txa
        ora dog_walks
        sta dog_walks
        sec
        rts
l_dwd_no:
        clc
        rts

; every frame on the lead: the dog trots just ahead of him (or is out)
dog_on_lead:
        lda #1                  ; (and it goes behind the open door)
        sta act_masked+1
        lda dog_out
        beq +
        lda #0
        sta dog_state
        rts
+       lda #1
        sta dog_state
        lda p_flip
        sta dog_flip
        bne +
        sec
        lda p_x
        sbc #DOG_LEAD_DX
        sta dog_x
        lda p_x+1
        sbc #0
        sta dog_x+1
        rts
+       clc
        lda p_x
        adc #DOG_LEAD_DX
        sta dog_x
        lda p_x+1
        adc #0
        sta dog_x+1
        rts

; 1 and 3: bent down beside the dog, clipping the leash on / off
st_leash:
        lda #1                  ; the dog's to his right
        sta p_flip
st_unleash:                     ; (the dog's ahead of him, the way he faces)
        lda #PM_BENDSIDE
        sta p_mode
        lda #0
        sta lead_t
        lda #2
        jmp set_timer_secs
tk_leash:
        inc lead_t
        lda lead_t
        cmp #50                 ; click
        bne +
        lda #SFX_TINK
        jsr sfx_play
        lda p_act
        cmp #A_LEASH
        bne l_tkl_off
        lda #1
        sta dog_lead
        lda #0
        sta dog_hold
        lda #2
        sta walk_stage
        rts
l_tkl_off:
        lda #0
        sta dog_lead
        sta act_masked+1
        sta walk_stage
        lda #2                  ; free: a rest, then off it goes
        sta dog_state
        lda #120
        sta dog_timer
        rts
+       cmp #75
        bne +
        lda #PM_STAND
        sta p_mode
+       rts
en_leash:
        lda #0
        sta dog_hold
        lda #PM_STAND
        sta p_mode
        lda walk_stage
        cmp #2
        bne +
        lda #A_WALKOUT
        sta p_pending
+       rts
en_unleash:
        lda #PM_STAND
        sta p_mode
        lda #0
        sta dog_lead
        sta act_masked+1
        lda walk_stage
        bne +
        lda #3
        jsr mood_up
        #SAY l_say_walkies
+       rts

; 2: out of the front door with the dog: the door opens, they step forward,
; the dog goes out behind the door, then him, and it clicks shut. Half a
; minute later the door opens, they come back in, it clicks shut again.
wo_ph:          .byte 0
dog_up:         .byte 0     ; the dog drawn this much higher (going out)

; Going out of the door they rise towards its foot, as if walking off into
; the distance: him over his last 20px before it, the dog likewise.
; the dog's place beside him, if it's on the lead
wo_dog:
        lda dog_lead
        bne +
        rts
+       jmp dog_on_lead

wo_heights:
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
+       sta l_woh_t
        lda #FLOOR0_Y
        sec
        sbc l_woh_t
        sta p_y
        sec
        lda dog_x
        sbc #<288
        tax
        lda dog_x+1
        sbc #>288
        bcs +
        ldx #0
+       txa
        lsr
        lsr
        cmp #7
        bcc +
        lda #6
+       ldx dog_lead            ; (only a dog on the lead goes out with him)
        bne +
        lda #0
+       sta dog_up
        rts
l_woh_t: .byte 0
WO_OUT_X        = 308           ; out of sight behind the door from here
WO_IN_X         = 268

st_walkout:
        lda #1
        sta p_flip
        ldx #PATCH_DOOR
        jsr patch_apply
        lda #SFX_DOOR
        jsr sfx_play
        lda #0
        sta lead_t
        sta wo_ph
        lda #<1500
        sta act_timer
        lda #>1500
        sta act_timer+1
        rts
tk_walkout:
        ldx wo_ph
        beq l_two_open
        cpx #1
        beq l_two_out
        cpx #2
        beq l_two_shut1
        cpx #3
        beq l_two_away
        cpx #4
        beq l_two_in
        cpx #5
        beq l_two_shut2
l_two_rts:
        rts
l_two_open:                     ; 0: the door swings open
        inc lead_t
        lda lead_t
        cmp #20
        bcc l_two_rts
        inc wo_ph
        lda #PM_WALK
        sta p_mode
        rts
l_two_out:                      ; 1: out they go, a step every other frame
        lda p_anim
        and #1
        bne l_two_rts
        inc p_x
        bne l_two_o1
        inc p_x+1
l_two_o1:
        jsr wo_dog              ; (the dog's place, then both heights)
        jsr wo_heights
        lda dog_lead            ; (out on his own: no dog to see out)
        beq l_two_o2
        lda dog_x+1             ; the dog's through (x >= 312: all but its
        beq l_two_o2            ;  tail behind the door)
        lda dog_x
        cmp #<312
        bcc l_two_o2
        lda #1
        sta dog_out
l_two_o2:
        lda p_x+1               ; and him (x >= WO_OUT_X)
        beq l_two_rts
        lda p_x
        cmp #<WO_OUT_X
        bcc l_two_rts
        lda #PM_HIDDEN
        sta p_mode
        lda #0
        sta lead_t
        inc wo_ph
        rts
l_two_shut1:                    ; 2: the door shuts behind them
        inc lead_t
        lda lead_t
        cmp #20
        bne l_two_rts
        inc wo_ph
        ldx #PATCH_DOOR
        jmp patch_remove
l_two_away:                     ; 3: away; home with a bark near the end
        lda act_timer+1
        bne l_two_rts
        lda act_timer
        cmp #110
        bcs l_two_rts
        ldx #PATCH_DOOR
        jsr patch_apply
        lda #SFX_DOOR
        jsr sfx_play
        lda dog_lead            ; (a bark, if the dog's with him)
        beq +
        jsr bark_play
+       lda #<WO_OUT_X
        sta p_x
        lda #>WO_OUT_X
        sta p_x+1
        lda #0
        sta p_flip
        sta dog_out
        lda #PM_WALK
        sta p_mode
        jsr wo_dog
        jsr wo_heights
        inc wo_ph
        rts
l_two_in:                       ; 4: back in, a step every other frame
        lda p_anim
        and #1
        bne l_two_rts
        lda p_x
        bne l_two_i1
        dec p_x+1
l_two_i1:
        dec p_x
        jsr wo_dog
        jsr wo_heights
        lda p_x+1
        cmp #>WO_IN_X
        bne l_two_rts
        lda p_x
        cmp #<WO_IN_X
        bne l_two_rts
        lda #PM_STAND
        sta p_mode
        lda #0
        sta lead_t
        inc wo_ph
        rts
l_two_shut2:                    ; 5: the door shuts
        inc lead_t
        lda lead_t
        cmp #15
        bne l_two_rts
        inc wo_ph
        ldx #PATCH_DOOR
        jmp patch_remove
en_walkout:
        ldx #PATCH_DOOR         ; (whatever happened, they're home)
        jsr patch_remove
        lda #FLOOR0_Y           ; back on the floor
        sta p_y
        lda #0
        sta dog_up
        lda #0
        sta dog_out
        lda #PM_STAND
        sta p_mode
        lda #3
        sta walk_stage
        lda #A_UNLEASH
        sta p_pending
        rts
        .section ftext
l_say_walkies: .null "Good walk, boy!"
        .send ftext

; The office wall clock keeps the real time: its face is repainted each
; minute with a minute hand (3px) and an hour hand (2px) in black, pointing
; to one of twelve positions round the dial (x 274-282, y 82-88, centre
; 278,85). Pixels go into the house image in Attic RAM and onto the screen.
CK_X            = 278
CK_Y            = 85
ck_m1x: .byte 0, 0, 1, 1, 1, 0, 0, 0, 255, 255, 255, 255
ck_m1y: .byte 255, 255, 0, 0, 0, 1, 1, 1, 0, 0, 0, 255
ck_m2x: .byte 0, 1, 2, 2, 2, 1, 0, 255, 254, 254, 254, 255
ck_m2y: .byte 254, 255, 255, 0, 1, 1, 2, 1, 1, 0, 255, 255
ck_m3x: .byte 0, 2, 3, 3, 3, 2, 0, 254, 253, 253, 253, 254
ck_m3y: .byte 254, 254, 255, 0, 1, 2, 2, 2, 1, 0, 255, 254
ck_h1x: .byte 0, 0, 1, 1, 1, 0, 0, 0, 255, 255, 255, 255
ck_h1y: .byte 255, 255, 0, 0, 0, 1, 1, 1, 0, 0, 0, 255
ck_h2x: .byte 0, 1, 2, 2, 2, 1, 0, 255, 254, 254, 254, 255
ck_h2y: .byte 254, 255, 255, 0, 1, 1, 2, 1, 1, 0, 255, 255
ck_px:          .byte 0
ck_py:          .byte 0
ck_col:         .byte 0
ck_dir:         .byte 0

clock_hands:
        lda #1                  ; fresh face (the painted hands too)
        sta patch_state + PATCH_CLOCKFACE
        ldx #PATCH_CLOCKFACE
        jsr patch_remove
        lda #C_WHITE            ; white out the face's painted-on hand
        sta ck_col
        ldx #<(CK_X - 1)
        ldy #CK_Y
        jsr ck_plot
        lda #C_BLACK
        sta ck_col
        ; minute hand: minutes / 5
        lda clock_min
        ldx #0
-       cmp #5
        bcc +
        sbc #5
        inx
        bra -
+       stx ck_dir
        lda ck_m1x,x
        ldy ck_m1y,x
        jsr ck_plot_rel
        ldx ck_dir
        lda ck_m2x,x
        ldy ck_m2y,x
        jsr ck_plot_rel
        ldx ck_dir
        lda ck_m3x,x
        ldy ck_m3y,x
        jsr ck_plot_rel
        ; hour hand: hour mod 12, a step on after half past
        lda clock_hour
-       cmp #12
        bcc +
        sbc #12
        bra -
+       ldx clock_min
        cpx #30
        bcc +
        clc
        adc #1
        cmp #12
        bcc +
        lda #0
+       tax
        stx ck_dir
        lda ck_h1x,x
        ldy ck_h1y,x
        jsr ck_plot_rel
        ldx ck_dir
        lda ck_h2x,x
        ldy ck_h2y,x
        jsr ck_plot_rel
        ldx #<CK_X              ; the centre pin
        ldy #CK_Y
        jmp ck_plot
; A = dx, Y = dy (signed) from the centre
ck_plot_rel:
        clc
        adc #<CK_X
        tax
        tya
        clc
        adc #CK_Y
        tay
; X, Y = pixel (x 256..287 assumed: x is CK_X-relative low byte), colour ck_col
ck_plot:
        stx ck_px
        sty ck_py
        ; offset = (y>>3)*2560 + (x>>3)*64 + (y&7)*8 + (x&7), x here + 256
        lda #0
        sta ZDST+1
        lda ck_py
        and #7
        asl
        asl
        asl
        sta ZDST
        lda ck_px
        and #7
        ora ZDST
        sta ZDST
        lda ck_px               ; (x>>3) + 32 (x is 256+low byte) -> *64
        lsr
        lsr
        lsr
        clc
        adc #32
        ; *64 = <<6: high gets >>2, low gets <<6
        pha
        lsr
        lsr
        clc
        adc ZDST+1
        sta ZDST+1
        pla
        asl
        asl
        asl
        asl
        asl
        asl
        clc
        adc ZDST
        sta ZDST
        bcc +
        inc ZDST+1
+       lda ck_py               ; (y>>3) * 2560 = (y>>3) * 10 * 256
        lsr
        lsr
        lsr
        sta MULTINA
        lda #10
        sta MULTINB
        lda MULTOUT
        clc
        adc ZDST+1
        sta ZDST+1
        ; screen character data
        lda #`CHAR_DATA
        sta ZDST+2
        lda #0
        sta ZDST+3
        ldz #0
        lda ck_col
        sta [ZDST],z
        ; the house image in Attic RAM (so it stays when restored)
        lda #ATTIC_WORK_BANK
        sta ZDST+2
        lda #ATTIC_MB >> 4
        sta ZDST+3
        lda ck_col
        sta [ZDST],z
        rts

; Walking the dog but it's upstairs: facing you he whistles for it (again
; every two and a half seconds) and it comes down to him; then the leash (or, if it
; never comes, he fetches it after all). Also for a game of fetch (fe_called).
wh_t:           .byte 0
st_whistle:
        lda #PM_FRONT
        sta p_mode
        lda #1
        sta dog_called
        lda #0
        sta wh_t
        lda dog_state           ; (resting or wandering: it hears it now)
        cmp #5
        beq +
        lda #2
        sta dog_state
        lda #1
        sta dog_timer
+       jsr whistle_play
        lda #15
        jmp set_timer_secs
tk_whistle:
        lda dog_floor           ; here yet? (downstairs and stopped)
        bne l_tkwh_more
        lda dog_state
        cmp #1
        beq l_tkwh_more
        cmp #5
        beq l_tkwh_more
        lda #0                  ; it's come: on with the leash
        sta act_timer
        sta act_timer+1
        rts
l_tkwh_more:
        inc wh_t                ; whistle again every two and a half seconds
        lda wh_t
        cmp #125
        bcc l_tkwh_out
        lda #0
        sta wh_t
        jmp whistle_play
l_tkwh_out:
        rts
en_whistle:
        lda #0
        sta dog_called
        lda #PM_STAND
        sta p_mode
        rts

