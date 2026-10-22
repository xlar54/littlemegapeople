; acts/upstairs.asm -- activities: the bathroom and office: washing, the shower, the computer, letters

; Washing his hands at the sink: back to you, elbows working, water running.
st_wash:
        lda #PM_WASH
        sta p_mode
        sec                     ; hands at his sides, over the basin
        lda p_x
        sbc #7
        sta fx_hands_x
        lda p_x+1
        sbc #0
        sta fx_hands_x+1
        lda p_y
        sec
        sbc #13
        sta fx_hands_y
        lda #7
        sta fx_kind
        lda #$90                ; tap water: softer and lower than the shower
        sta shower_pitch
        lda #1
        sta shower_on
        lda #4
        jmp set_timer_secs
en_wash:
        lda #0
        sta shower_on
        lda #$C0
        sta shower_pitch
        rts
; Shower: he steps behind the curtain, it slides shut (right to left, like an
; accordion) over the tub, the water runs, then it slides open and he steps
; out -- undressed, so he heads for the closet with a mosaic over him.
BATH_SECS       = 9
bath_t:         .byte 0

st_bath:
        lda #PM_HIDDEN
        sta p_mode
        lda #0
        sta bath_t
        lda #1
        sta shower_on
        lda #BATH_SECS
        jmp set_timer_secs
tk_bath:
        lda bath_t
        cmp #255
        beq +
        inc bath_t
+       lda bath_t
        cmp #2
        bne +
        lda #1
        jmp curtain_set
+       cmp #8
        bne +
        lda #2
        jmp curtain_set
+       cmp #14
        bne +
        lda #3
        jmp curtain_set
+       ; open again in the last moments
        lda act_timer+1
        bne l_tkb_out
        lda act_timer
        cmp #20
        bne +
        lda #0
        sta shower_on
        lda #2
        jmp curtain_set
+       cmp #12
        bne l_tkb_out
        lda #1
        jmp curtain_set
l_tkb_out:
        rts

; A = 0 open (bunched at the right), 1..3 = drawn a third / two thirds / shut
curtain_set:
        sta l_cs_level
        ; the three steps share cells: restore the open curtain, then draw one
        lda #0
        sta patch_state + PATCH_CURTAIN1
        sta patch_state + PATCH_CURTAIN2
        lda #1
        sta patch_state + PATCH_CURTAIN3
        ldx #PATCH_CURTAIN3
        jsr patch_remove
        lda l_cs_level
        beq +
        clc
        adc #PATCH_CURTAIN1 - 1
        tax
        jsr patch_apply
+       rts
l_cs_level: .byte 0

en_bath:
        lda #0
        sta shower_on
        jsr curtain_set
        lda #2                  ; out of the shower with nothing on
        sta outfit
        lda #3
        jsr mood_up
        lda health
        cmp #96
        bcs +
        clc
        adc #4
        sta health
+       #SAY l_say_clean
        rts
; Playing a video game on the computer: a maze muncher or a space shooter
; running on its screen, with little game blips.
VG_X            = 292
VG_Y            = 99
vg_game:        .byte 0     ; 0 maze, 16 shooter (first frame in vg_l/h)
vg_l:           .byte <SPR_VGM0, <SPR_VGM1, <SPR_VGM2, <SPR_VGM3, <SPR_VGM4, <SPR_VGM5, <SPR_VGM6, <SPR_VGM7, <SPR_VGM8, <SPR_VGM9, <SPR_VGM10, <SPR_VGM11, <SPR_VGM12, <SPR_VGM13, <SPR_VGM14, <SPR_VGM15, <SPR_VGS0, <SPR_VGS1, <SPR_VGS2, <SPR_VGS3, <SPR_VGS4, <SPR_VGS5, <SPR_VGS6, <SPR_VGS7, <SPR_VGS8, <SPR_VGS9, <SPR_VGS10, <SPR_VGS11, <SPR_VGS12, <SPR_VGS13, <SPR_VGS14, <SPR_VGS15
vg_h:           .byte >SPR_VGM0, >SPR_VGM1, >SPR_VGM2, >SPR_VGM3, >SPR_VGM4, >SPR_VGM5, >SPR_VGM6, >SPR_VGM7, >SPR_VGM8, >SPR_VGM9, >SPR_VGM10, >SPR_VGM11, >SPR_VGM12, >SPR_VGM13, >SPR_VGM14, >SPR_VGM15, >SPR_VGS0, >SPR_VGS1, >SPR_VGS2, >SPR_VGS3, >SPR_VGS4, >SPR_VGS5, >SPR_VGS6, >SPR_VGS7, >SPR_VGS8, >SPR_VGS9, >SPR_VGS10, >SPR_VGS11, >SPR_VGS12, >SPR_VGS13, >SPR_VGS14, >SPR_VGS15
st_computer:
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
        lda #15
        jmp set_timer_secs
; the game's noises, in time with the frames on its screen
tk_computer:
        lda p_anim
        and #7                  ; (a new frame every 8)
        bne l_tkc_out
        lda p_anim
        lsr
        lsr
        lsr
        and #15
        tax                     ; X = the frame
        lda vg_game
        bne l_tkc_shoot
        txa                     ; the maze: waka, waka...
        and #1
        beq +
        lda #SFX_WAKA2
        jmp sfx_play
+       lda #SFX_WAKA
        jmp sfx_play
l_tkc_shoot:
        cpx #6                  ; his shot
        bne +
        lda #SFX_PEW
        jmp sfx_play
+       cpx #11                 ; the diver hit
        bne +
        lda #SFX_BOOM
        jmp sfx_play
+       txa                     ; the formation marching
        and #3
        bne l_tkc_out
        lda #SFX_STEP
        jmp sfx_play
l_tkc_out:
        rts
en_computer:
        lda #0
        sta monitor_on
        lda #3
        jmp mood_up
; The attic desk with the typewriter: he types his letters here, seated on
; the far side of the desk facing you.
DESK_POSE_X     = 215         ; behind the typewriter, facing you
DESK_POSE_Y     = 38

HANDS_X         = 216           ; his hands on the typewriter keys
HANDS_Y         = 47
fx_hands_x:        .word HANDS_X   ; where the little-hands effect is drawn
fx_hands_y:        .byte HANDS_Y

st_letter:
        #POSE SPR_SITDESK, DESK_POSE_X, DESK_POSE_Y
        lda #<HANDS_X
        sta fx_hands_x
        lda #>HANDS_X
        sta fx_hands_x+1
        lda #HANDS_Y
        sta fx_hands_y
        lda #7                  ; hands on the keys
        sta fx_kind
        lda #0
        sta car_t
        sta car_line
        jsr carriage_set
        lda #9
        jmp set_timer_secs
en_letter:
        lda #0                  ; (the carriage back where it lives)
        jsr carriage_set
        lda #0
        sta monitor_on
        lda #200
        sta letter_cd
        lda #PM_STAND
        sta p_mode
        jsr ovl_letter_show
        lda #0
        sta sleep_plea          ; (said it)
        rts

