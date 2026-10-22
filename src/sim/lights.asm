; sim/lights.asm -- Lights and palette animation (part of the simulation; included after sim/sim.asm)
;---------------------------------------------------------------------------------------
; Lights and palette animation
;---------------------------------------------------------------------------------------
is_night:
        ; C = 1 between 20:00 and 05:59
        lda clock_hour
        cmp #20
        bcs +
        cmp #6
        bcc +
        clc
        rts
+       sec
        rts

lights_update:
        lda #255
        sta l_lu_dim
        jsr is_night
        bcc l_lu_set
        lda #190
        sta l_lu_dim
        lda p_act
        cmp #A_SLEEP
        bne l_lu_set
        lda p_state
        cmp #PS_ACT
        bne l_lu_set
        lda #105                ; lights out
        sta l_lu_dim
l_lu_set:
        lda l_lu_dim
        cmp pal_dim
        beq +
        sta pal_dim
        jsr pal_apply_all
+       rts
l_lu_dim: .byte 255

; Sky colour per hour (r, g, b)
; black from 8pm to 5am, dark navy before dawn, sunrise, day, sunset, dusk
sky_rgb:
        .byte 0,0,0, 0,0,0, 0,0,0, 0,0,0, 0,0,0, 17,17,85                   ; 0-5
        .byte 170,85,119, 68,102,238, 0,0,221, 0,0,221, 0,0,221, 0,0,221     ; 6-11
        .byte 0,0,221, 0,0,221, 0,0,221, 0,0,221, 0,0,221, 34,68,221         ; 12-17
        .byte 204,102,68, 136,51,102, 0,0,0, 0,0,0, 0,0,0, 0,0,0             ; 18-23
; Window glass: the same times of day, but its own light cyan by day
win_rgb:
        .byte 0,0,0, 0,0,0, 0,0,0, 0,0,0, 0,0,0, 17,17,85                   ; 0-5
        .byte 221,136,170, 136,204,238, 0,204,204, 0,204,204, 0,204,204, 0,204,204 ; 6-11
        .byte 0,204,204, 0,204,204, 0,204,204, 0,204,204, 0,204,204, 68,187,221    ; 12-17
        .byte 238,153,85, 136,68,136, 0,0,0, 0,0,0, 0,0,0, 0,0,0             ; 18-23

outfit_rgb:     ; shirt, shirt shade, pants, far trouser leg, shirt dots, pants dots
        .byte 34,102,255, 17,51,170, 255,255,255, 170,170,170, 34,102,255, 255,255,255  ; day
        .byte 51,85,221, 34,51,153, 51,85,221, 34,51,153, 255,136,204, 255,136,204      ; pyjamas
        .byte 255,204,153, 230,170,120, 255,204,153, 221,160,110, 255,204,153, 255,204,153 ; nothing

; The stereo while a record plays: tone-arm shimmer, panel lights, power.
stereo_animate:
        lda record_left
        ora record_left+1
        bne l_sa_on
        ldx #C_SPIN_A           ; off: their house colours
-       jsr pal_own
        inx
        cpx #C_LED + 1
        bne -
        rts
l_sa_on:
        lda frame_count
        lsr
        lsr
        and #1
        sta l_sa_tg             ; 0/1: which shimmer entry is bright
        ldx #C_SPIN_A
        jsr l_sa_spin
        lda l_sa_tg
        eor #1
        sta l_sa_tg
        ldx #C_SPIN_B
        jsr l_sa_spin
        lda frame_count         ; panel lights: new levels a few times a second
        and #7
        bne l_sa_led
        jsr rnd
        sta l_sa_lv
        ldx #C_VU_R1
        lda #255
        sta l_sa_r
        lda #60
        sta pe_g
        sta pe_b
        lda l_sa_lv
        and #1
        jsr l_sa_light
        ldx #C_VU_R2
        lda l_sa_lv
        and #2
        jsr l_sa_light
        ldx #C_VU_B
        lda #60
        sta l_sa_r
        lda #140
        sta pe_g
        lda #255
        sta pe_b
        lda l_sa_lv
        and #4
        jsr l_sa_light
l_sa_led:
        lda #34
        sta pe_g                ; (set below)
        lda #0
        sta pe_b
        lda #238
        sta pe_g
        lda #34
        ldx #C_LED
        jmp pal_set
; l_sa_tg = 1: bright
l_sa_spin:
        lda #255
        sta pe_g
        sta pe_b
        ldy l_sa_tg
        bne +
        lda #119
        sta pe_g
        sta pe_b
+       jmp pal_set
; A != 0: lit, else dim (colour l_sa_r / pe_g / pe_b)
l_sa_light:
        bne +
        lsr pe_g
        lsr pe_g
        lsr pe_b
        lsr pe_b
        lda l_sa_r
        lsr
        lsr
        jsr pal_set
        asl pe_g                ; (restore for the next light)
        asl pe_g
        asl pe_b
        asl pe_b
        rts
+       lda l_sa_r
        jmp pal_set
l_sa_lv:    .byte 0
l_sa_tg:    .byte 0
l_sa_r:     .byte 0

; Palette entry X back to its own colour from the palette tables.
pal_own:
        lda pal_g,x
        sta pe_g
        lda pal_b,x
        sta pe_b
        lda pal_r,x
        jmp pal_set

palette_animate:
        ; sky
        lda #<sky_rgb
        sta ZPTR
        lda #>sky_rgb
        sta ZPTR+1
        ldy clock_hour
        ldx #C_SKY
        jsr pal_set_from
        lda #<win_rgb           ; the window glass
        sta ZPTR
        lda #>win_rgb
        sta ZPTR+1
        ldy clock_hour
        ldx #C_WINSKY
        jsr pal_set_from
        ; clothes
        lda #<outfit_rgb
        sta ZPTR
        lda #>outfit_rgb
        sta ZPTR+1
        lda outfit
        asl
        adc outfit
        asl
        tay                     ; 6 entries per outfit
        sty l_pa_o
        ldx #C_SHIRT
        jsr pal_set_from
        ldy l_pa_o
        iny
        ldx #C_SHIRT2
        jsr pal_set_from
        ldy l_pa_o
        iny
        iny
        ldx #C_PANTS
        jsr pal_set_from
        ldy l_pa_o
        iny
        iny
        iny
        ldx #C_PANTS2
        jsr pal_set_from
        lda l_pa_o
        clc
        adc #4
        tay
        ldx #C_DOTS_SHIRT
        jsr pal_set_from
        lda l_pa_o
        clc
        adc #5
        tay
        ldx #C_DOTS_PANTS
        jsr pal_set_from
        jsr stereo_animate
        jsr friend_palette
        ; skin and hair: green when he's sick (face, and the back of his head)
        lda health
        cmp #40
        bcc l_pan_sick
        lda #204                ; well: his own colours
        sta pe_g
        lda #153
        sta pe_b
        lda #255
        ldx #C_SKIN
        jsr pal_set
        lda #119
        sta pe_g
        lda #0
        sta pe_b
        lda #238
        ldx #C_HAIR
        jsr pal_set
        bra l_pan_skin_done
l_pan_sick:
        lda #221                ; sick: a sickly green face...
        sta pe_g
        lda #102
        sta pe_b
        lda #136
        ldx #C_SKIN
        jsr pal_set
        lda #153                ; ...and greenish hair
        sta pe_g
        lda #34
        sta pe_b
        lda #85
        ldx #C_HAIR
        jsr pal_set
l_pan_skin_done:
        ; water bottle: five bands, each blue while the water reaches it
        ldx #0
-       phx
        txa
        asl
        cmp water               ; band i holds water while water > 2i
        bcs l_pan_dry
        lda #0
        sta pe_g
        lda #221
        sta pe_b
        lda #0
        bra l_pan_band
l_pan_dry:
        lda #221                ; empty: pale clear plastic
        sta pe_g
        lda #238
        sta pe_b
        lda #204
l_pan_band:
        pha
        txa
        clc
        adc #C_BOTTLE0
        tax
        pla
        jsr pal_set
        plx
        inx
        cpx #5
        bne -
        ; attic TV
        lda tv_on
        beq l_pan_tvoff
        lda frame_count
        lsr
        lsr
        lsr
        and #3
        tay
        lda l_tv_g,y
        sta pe_g
        lda l_tv_b,y
        sta pe_b
        lda l_tv_r,y
        bra l_pan_tvset
l_pan_tvoff:
        lda #255
        sta pe_g
        sta pe_b
l_pan_tvset:
        ldx #C_TVSCR
        jsr pal_set
        ; study monitor
        lda #0
        sta pe_g
        sta pe_b
        lda monitor_on
        beq +
        lda frame_count
        and #16
        ora #136
        sta pe_g
        lda #68
        sta pe_b
        lda #34
+       ldx #C_MONITOR
        jsr pal_set
        ; fire: rotate three flame colours
        lda frame_count
        lsr
        lsr
        and #3
        cmp #3
        bne +
        lda #0
+       sta l_pa_o
        ldx #0
-       txa
        clc
        adc l_pa_o
        cmp #3
        bcc +
        sbc #3
+       tay
        lda l_fire_g,y
        sta pe_g
        lda l_fire_b,y
        sta pe_b
        lda l_fire_r,y
        phx
        pha
        txa
        clc
        adc #C_FIRE_A
        tax
        pla
        jsr pal_set
        plx
        inx
        cpx #3
        bne -
        rts
l_pa_o:  .byte 0
l_tv_r:  .byte 170,221,136,255
l_tv_g:  .byte 204,255,170,221
l_tv_b:  .byte 255,255,221,170
l_fire_r: .byte 255,238,255
l_fire_g: .byte 0,119,221
l_fire_b: .byte 0,0,0

