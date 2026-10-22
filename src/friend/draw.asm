; friend/draw.asm -- his friend: drawing him and his things (see friend/visit.asm)
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
+       jsr fr_glass_sprite     ; (his glass, to the sink)
        lda fr_state
        cmp #FRS_ENTER
        bcs +
        rts
+       lda fr_glass_on         ; (his glass in his hand: his arm to it)
        sta carry_now
        jsr fr_swap
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

; His drunk glass in front of him on his way to the kitchen sink (actor 9:
; the TV chair's and the plate's, not about now), where Larry carries things.
fr_glass_on:    .byte 0
fr_glass_sprite:
        lda #0
        sta fr_glass_on
        lda fr_jgo
        cmp #FJ_CUPSINK + 1
        beq +
        lda fr_want
        cmp #FJ_CUPSINK + 1
        bne l_fgs_out
+       lda FR(p_mode)
        cmp #PM_HIDDEN
        beq l_fgs_out
        cmp #PM_CLIMB
        beq l_fgs_out
        lda #1
        sta act_vis+9
        sta fr_glass_on
        #SETACT 9, SPR_HELDCUP
        lda #0
        sta act_flip+9
        lda FR(p_y)             ; chest height, in front of him
        sec
        sbc #17
        sta act_y+9
        lda FR(p_flip)
        bne l_fgs_right
        sec
        lda FR(p_x)
        sbc #11
        sta act_xl2+9
        lda FR(p_x+1)
        sbc #0
        sta act_xh2+9
        rts
l_fgs_right:
        clc
        lda FR(p_x)
        adc #4
        sta act_xl2+9
        lda FR(p_x+1)
        adc #0
        sta act_xh2+9
l_fgs_out:
        rts

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

