;=======================================================================================
; Title: the "LITTLE MEGA PEOPLE" guestbook (after the Amiga's House-On-A-Disk
; guestbook). Sign in with your name; the date and time come from the MEGA65's
; real-time clock (RETURN keeps them, or type over them), then he moves in.
;=======================================================================================

TF_COL          = 9         ; field column (inside the page)
TF_NAME_ROW     = 12
TF_DATE_ROW     = 14
TF_TIME_ROW     = 16
TF_AMPM_ROW     = 18
TF_HINT_ROW     = 20
TF_FOOT_ROW     = 21
NAME_MAX        = 12

F_NAME          = 0
F_DATE          = 1
F_TIME          = 2
F_AMPM          = 3
F_DONE          = 4

RTC_BASE        = $0FFD7110 ; sec, min, hour, day, month, year (BCD)

l_tt_field:      .byte 0
l_tt_digits:     .fill 6, 0  ; digits typed into the date/time field
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
        lda #F_NAME
        sta l_tt_field
        lda #0
        sta l_tt_ndig
        sta l_tt_name_len
        sta player_name
        ; defaults, replaced by the real-time clock when it reads sensibly
        lda #8
        sta l_tt_hour12
        lda #0
        sta l_tt_pm
        sta clock_min
        jsr rtc_read
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
        cmp #F_NAME
        bne +
        jsr title_key_name
        bra l_tr_after
+       cmp #F_AMPM
        bne +
        jsr title_key_ampm
        bra l_tr_after
+       jsr title_key_digits    ; date or time
l_tr_after:
        lda l_tt_field
        cmp #F_DONE
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

;---------------------------------------------------------------------------------------
; Real-time clock. Leaves the defaults alone if any value is not sensible BCD
; (no RTC, flat battery, or an emulator without one).
;---------------------------------------------------------------------------------------
l_rtc:  .fill 6, 0          ; sec, min, hour, day, month, year (binary)

rtc_read:
        lda #<RTC_BASE
        sta ZSRC
        lda #>RTC_BASE
        sta ZSRC+1
        lda #`RTC_BASE
        sta ZSRC+2
        lda #RTC_BASE >> 24
        sta ZSRC+3
        ; hour byte: bit 7 = 24h mode, else bit 5 = PM
        ldz #2
        lda [ZSRC],z
        sta l_rtc_hraw
        ldx #0
l_rtc_get:
        txa
        taz
        lda [ZSRC],z
        cpx #2
        bne +
        and #$3F                ; hour: strip the mode bits (PM handled below)
        bit l_rtc_hraw
        bmi +
        and #$1F
+       jsr bcd_to_bin
        bcc l_rtc_ok
        ; Xemu hands back the month in binary, not BCD: accept 1..12 as-is
        cpx #4
        bne l_rtc_bad
        lda ZTMP+2
        beq l_rtc_bad
        cmp #13
        bcs l_rtc_bad
l_rtc_ok:
        sta l_rtc,x
        inx
        cpx #6
        bne l_rtc_get
        ldz #0
        ; range checks
        lda l_rtc+1
        cmp #60
        bcs l_rtc_bad
        lda l_rtc+3
        beq l_rtc_bad
        cmp #32
        bcs l_rtc_bad
        lda l_rtc+4
        beq l_rtc_bad
        cmp #13
        bcs l_rtc_bad
        ; hour -> 24h
        lda l_rtc+2
        bit l_rtc_hraw
        bmi l_rtc_24
        cmp #12                 ; 12h mode: 12 AM = 0, add 12 for PM (bit 5)
        bne +
        lda #0
+       pha
        lda l_rtc_hraw
        and #$20
        beq +
        pla
        clc
        adc #12
        bra l_rtc_24
+       pla
l_rtc_24:
        cmp #24
        bcs l_rtc_bad
        ; accept: 24h -> 12h + AM/PM for the guestbook
        ldx #0
        cmp #12
        bcc +
        ldx #1
        sbc #12
+       stx l_tt_pm
        cmp #0
        bne +
        lda #12
+       sta l_tt_hour12
        lda l_rtc+1
        sta clock_min
        lda l_rtc+3
        sta date_day
        lda l_rtc+4
        sta date_month
        lda l_rtc+5
        sta date_year
        rts
l_rtc_bad:
        ldz #0
        rts
l_rtc_hraw: .byte 0

; A = BCD byte -> A = binary, C = 1 if either digit is not 0..9. Keeps X.
bcd_to_bin:
        sta ZTMP+2              ; keep the raw byte for callers
        sta ZTMP
        and #$0F
        cmp #10
        bcs l_b2b_bad
        sta ZTMP+1
        lda ZTMP
        lsr
        lsr
        lsr
        lsr
        cmp #10
        bcs l_b2b_bad
        sta ZTMP
        asl
        asl
        clc
        adc ZTMP                ; tens*5
        asl                     ; tens*10
        adc ZTMP+1
        clc
        rts
l_b2b_bad:
        sec
        rts

;---------------------------------------------------------------------------------------
; Fields
;---------------------------------------------------------------------------------------
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

; Date (MMDDYY) or time (HHMM / HMM): digits replace the shown value on RETURN.
title_key_digits:
        lda l_tr_key
        cmp #KEY_RETURN
        bne +
        lda l_tt_field
        cmp #F_DATE
        bne l_tkd_time
        jsr l_tt_parse_date
        bra l_tkd_next
l_tkd_time:
        jsr l_tt_parse_time
l_tkd_next:
        inc l_tt_field
        lda #SFX_BLIP
        jmp sfx_play
+       cmp #KEY_DEL
        bne +
        lda l_tt_ndig
        beq l_tkd_out
        dec l_tt_ndig
        rts
+       cmp #'0'
        bcc l_tkd_out
        cmp #'9'+1
        bcs l_tkd_out
        ldx l_tt_ndig
        cpx #6
        bcs l_tkd_out
        sec
        sbc #'0'
        sta l_tt_digits,x
        inc l_tt_ndig
        lda #SFX_TYPE
        jmp sfx_play
l_tkd_out:
        rts

; two typed digits at X, X+1 -> A = value
l_tt_pair:
        lda l_tt_digits,x
        asl
        sta ZTMP
        asl
        asl
        clc
        adc ZTMP
        adc l_tt_digits+1,x
        rts

; digits -> hour (1..12) and minutes; ignores nonsense
l_tt_parse_time:
        lda l_tt_ndig
        cmp #3
        bcc l_tpt_out
        cmp #5
        bcs l_tpt_out
        ; minutes = last two digits
        tax
        dex
        dex
        jsr l_tt_pair
        cmp #60
        bcs l_tpt_out
        sta ZTMP+1
        ; hours = first one or two digits
        lda l_tt_digits
        ldx l_tt_ndig
        cpx #4
        bne +
        ldx #0
        lda ZTMP+1
        pha
        jsr l_tt_pair
        tay
        pla
        sta ZTMP+1
        tya
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

; six digits MMDDYY -> date; ignores anything else
l_tt_parse_date:
        lda l_tt_ndig
        cmp #6
        bne l_tpd_out
        ldx #0
        jsr l_tt_pair
        beq l_tpd_out
        cmp #13
        bcs l_tpd_out
        sta ZTMP+2
        ldx #2
        jsr l_tt_pair
        beq l_tpd_out
        cmp #32
        bcs l_tpd_out
        sta ZTMP+3
        ldx #4
        jsr l_tt_pair
        sta date_year
        lda ZTMP+2
        sta date_month
        lda ZTMP+3
        sta date_day
l_tpd_out:
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
        rts
+       cmp #' '
        bne +
        lda l_tt_pm
        eor #1
        sta l_tt_pm
+       rts

;---------------------------------------------------------------------------------------
; Drawing
;---------------------------------------------------------------------------------------
; typed digits so far, then a cursor
l_tdf_typed:
        ldx #0
-       cpx l_tt_ndig
        beq +
        lda l_tt_digits,x
        clc
        adc #'0'
        phx
        jsr sb_char
        plx
        inx
        bra -
+       lda #'_'
        jmp sb_char

title_draw_fields:
        lda #C_PAGE
        sta txt_bg
        lda #C_PAGETEXT
        sta txt_fg
        ; NAME
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
        ; DATE
        jsr sb_clear
        ldx #<tt_date
        ldy #>tt_date
        jsr sb_strxy
        lda l_tt_field
        cmp #F_DATE
        bne +
        lda l_tt_ndig
        beq +
        jsr l_tdf_typed
        bra ++
+       jsr sb_date
+       ldy #TF_DATE_ROW
        jsr l_tdf_print
        ; TIME
        jsr sb_clear
        ldx #<tt_time
        ldy #>tt_time
        jsr sb_strxy
        lda l_tt_field
        cmp #F_TIME
        bne +
        lda l_tt_ndig
        beq +
        jsr l_tdf_typed
        bra ++
+       lda l_tt_hour12
        jsr sb_num2
        lda #':'
        jsr sb_char
        lda clock_min
        jsr sb_num2
+       ldy #TF_TIME_ROW
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
tt_date:   .null "DATE: "
tt_time:   .null "TIME: "
tt_ampm:   .null "AM or PM: "
tt_friend: .null "Friend"
tt_foot:   .null "A MEGA65 TRIBUTE"
tt_hints:  .word tt_h0, tt_h1, tt_h2, tt_h3, tt_h3
tt_h0:     .null "Sign in, then RETURN"
tt_h1:     .null "Type MMDDYY, or RETURN"
tt_h2:     .null "Type HHMM, or RETURN"
tt_h3:     .null "A or P, RETURN to begin"
