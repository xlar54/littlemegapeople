;=======================================================================================
; Title: the "LITTLE MEGA PEOPLE" guestbook (after the Amiga's House-On-A-Disk
; guestbook). Sign in with your name and the time of day, then move him in.
;=======================================================================================

TF_COL          = 9         ; field column (inside the page)
TF_NAME_ROW     = 12
TF_TIME_ROW     = 14
TF_AMPM_ROW     = 16
TF_HINT_ROW     = 19
TF_FOOT_ROW     = 21
NAME_MAX        = 12

l_tt_field:      .byte 0     ; 0 name, 1 time, 2 am/pm
l_tt_digits:     .fill 4, 0
l_tt_ndig:       .byte 0
l_tt_pm:         .byte 0
l_tt_hour12:     .byte 8
l_tt_shim:       .byte 0
l_tt_shim4:      .byte 0
l_tt_name_len:   .byte 0

title_run:
        lda #ATTIC_TITLE_BANK
        jsr image_from_attic
        lda #255
        sta pal_dim
        jsr pal_apply_all
        jsr screen_on
        lda #0
        sta l_tt_field
        sta l_tt_ndig
        sta l_tt_pm
        sta l_tt_name_len
        sta player_name
        lda #8
        sta l_tt_hour12
        jsr title_draw_fields
        lda #C_PAGEDARK
        sta txt_fg
        ldx #<tt_foot
        ldy #>tt_foot
        stx ZPTR
        sty ZPTR+1
        ldx #TF_COL + 2
        ldy #TF_FOOT_ROW
        jsr print_str
        ; swallow anything still queued from the autoboot "RUN" for a second
        lda #50
        sta l_tr_key
-       jsr wait_frame
        jsr title_shimmer
        jsr key_flush
        dec l_tr_key
        bne -
l_tr_loop:
        jsr wait_frame
        jsr title_shimmer
        jsr sound_tick
        jsr key_get
        beq l_tr_loop
        sta l_tr_key
        lda l_tt_field
        bne +
        jsr title_key_name
        bra l_tr_after
+       cmp #1
        bne +
        jsr title_key_time
        bra l_tr_after
+       jsr title_key_ampm
l_tr_after:
        lda l_tt_field
        cmp #3
        beq l_tr_done
        jsr title_draw_fields
        bra l_tr_loop
l_tr_done:
        ; commit the clock
        lda l_tt_hour12
        cmp #12
        bne +
        lda #0
+       ldx l_tt_pm
        beq +
        clc
        adc #12
+       sta clock_hour
        lda #SFX_CHIME
        jsr sfx_play
        rts
l_tr_key: .byte 0

title_key_name:
        lda l_tr_key
        cmp #KEY_RETURN
        bne +
        lda l_tt_name_len
        bne l_tkn_next
        ; no name? call you Friend
        ldx #0
-       lda tt_friend,x
        sta player_name,x
        beq l_tkn_next
        inx
        bra -
l_tkn_next:
        inc l_tt_field
        lda #SFX_BLIP
        jmp sfx_play
+       cmp #KEY_DEL
        bne +
        ldx l_tt_name_len
        beq l_tkn_out
        dex
        stx l_tt_name_len
        lda #0
        sta player_name,x
        rts
+       cmp #' '
        bcc l_tkn_out
        cmp #$7F
        bcs l_tkn_out
        ldx l_tt_name_len
        cpx #NAME_MAX
        bcs l_tkn_out
        ; capitalise the first letter
        cpx #0
        bne +
        cmp #'a'
        bcc +
        cmp #'z'+1
        bcs +
        and #$DF
+       sta player_name,x
        inx
        stx l_tt_name_len
        lda #0
        sta player_name,x
        lda #SFX_TYPE
        jmp sfx_play
l_tkn_out:
        rts

title_key_time:
        lda l_tr_key
        cmp #KEY_RETURN
        bne +
        ; accept typed HHMM / HMM if valid
        jsr l_tt_parse_time
        inc l_tt_field
        lda #SFX_BLIP
        jmp sfx_play
+       cmp #KEY_DEL
        bne +
        lda l_tt_ndig
        beq l_tkt_out
        dec l_tt_ndig
        rts
+       cmp #'0'
        bcc l_tkt_out
        cmp #'9'+1
        bcs l_tkt_out
        ldx l_tt_ndig
        cpx #4
        bcs l_tkt_out
        sec
        sbc #'0'
        sta l_tt_digits,x
        inc l_tt_ndig
        lda #SFX_TYPE
        jmp sfx_play
l_tkt_out:
        rts

; digits -> hour (1..12) and minutes; ignores nonsense
l_tt_parse_time:
        lda l_tt_ndig
        cmp #3
        bcc l_tpt_out
        ; minutes = last two digits
        tax
        lda l_tt_digits-2,x
        asl
        sta ZTMP
        asl
        asl
        clc
        adc ZTMP                ; tens*10
        adc l_tt_digits-1,x
        cmp #60
        bcs l_tpt_out
        sta ZTMP+1
        ; hours = first one or two digits
        lda l_tt_digits
        cpx #4
        bne +
        asl
        sta ZTMP
        asl
        asl
        clc
        adc ZTMP
        adc l_tt_digits+1
+       cmp #1
        bcc l_tpt_out
        cmp #13
        bcs l_tpt_out
        sta l_tt_hour12
        lda ZTMP+1
        sta clock_min
l_tpt_out:
        lda #0
        sta l_tt_ndig
        rts

title_key_ampm:
        lda l_tr_key
        cmp #KEY_RETURN
        bne +
        inc l_tt_field
        rts
+       ora #$20
        cmp #'a'
        bne +
        lda #0
        sta l_tt_pm
        rts
+       cmp #'p'
        bne +
        lda #1
        sta l_tt_pm
+       cmp #' '
        bne +
        lda l_tt_pm
        eor #1
        sta l_tt_pm
+       rts

title_draw_fields:
        lda #C_PAGE
        sta txt_bg
        ; NAME
        lda #C_PAGETEXT
        sta txt_fg
        jsr sb_clear
        ldx #<tt_name
        ldy #>tt_name
        jsr sb_strxy
        jsr sb_player
        lda l_tt_field
        bne +
        lda #'_'
        jsr sb_char
+       ldy #TF_NAME_ROW
        jsr l_tdf_print
        ; TIME
        jsr sb_clear
        ldx #<tt_time
        ldy #>tt_time
        jsr sb_strxy
        lda l_tt_field
        cmp #1
        bne l_tdf_time_show
        lda l_tt_ndig
        beq l_tdf_time_show
        ldx #0
-       lda l_tt_digits,x
        clc
        adc #'0'
        phx
        jsr sb_char
        plx
        inx
        cpx l_tt_ndig
        bne -
        lda #'_'
        jsr sb_char
        bra l_tdf_time_done
l_tdf_time_show:
        lda l_tt_hour12
        jsr sb_num2
        lda #':'
        jsr sb_char
        lda clock_min
        jsr sb_num2
l_tdf_time_done:
        ldy #TF_TIME_ROW
        jsr l_tdf_print
        ; AM/PM
        jsr sb_clear
        ldx #<tt_ampm
        ldy #>tt_ampm
        jsr sb_strxy
        lda #'A'
        ldx l_tt_pm
        beq +
        lda #'P'
+       jsr sb_char
        lda #'M'
        jsr sb_char
        ldy #TF_AMPM_ROW
        jsr l_tdf_print
        ; hint
        lda #C_PAGEDARK
        sta txt_fg
        lda l_tt_field
        asl
        tax
        lda tt_hints,x
        ldy tt_hints+1,x
        tax
        jsr sb_clear
        jsr sb_strxy
        ldy #TF_HINT_ROW
        jmp l_tdf_print

; print sb at (TF_COL, Y) padded to 26 columns
l_tdf_print:
        sty l_tdf_row
-       lda sb_len
        cmp #26
        bcs +
        lda #' '
        jsr sb_char
        bra -
+       lda #<sb
        sta ZPTR
        lda #>sb
        sta ZPTR+1
        ldx #TF_COL
        ldy l_tdf_row
        jmp print_str
l_tdf_row: .byte 0

; Sweep the logo gradient: rotate palette entries 80..143 by one gradient row.
title_shimmer:
        lda frame_count
        inc frame_count
        and #3
        bne l_ts_out
        inc l_tt_shim
        lda l_tt_shim
        asl
        asl
        and #63
        sta l_tt_shim4          ; whole gradient rows only (keeps antialias level)
        ldx #0
l_ts_loop:
        txa
        clc
        adc l_tt_shim4
        and #63
        tay
        lda pal_r + 80,y
        sta ZTMP
        lda pal_g + 80,y
        sta ZTMP+1
        lda pal_b + 80,y
        sta ZTMP+2
        ldy ZTMP
        lda nib_swap,y
        sta PALREG_R + 80,x
        ldy ZTMP+1
        lda nib_swap,y
        sta PALREG_G + 80,x
        ldy ZTMP+2
        lda nib_swap,y
        sta PALREG_B + 80,x
        inx
        cpx #64
        bne l_ts_loop
l_ts_out:
        rts

tt_name:   .null "NAME: "
tt_time:   .null "TIME: "
tt_ampm:   .null "AM or PM: "
tt_friend: .null "Friend"
tt_foot:   .null "A MEGA65 TRIBUTE"
tt_hints:  .word tt_h0, tt_h1, tt_h2, tt_h2
tt_h0:     .null "Sign in, then RETURN"
tt_h1:     .null "Type HHMM, or RETURN"
tt_h2:     .null "A or P, RETURN to begin"
