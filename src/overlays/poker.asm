;=======================================================================================
; Five-card draw poker (shares the card table window with Twenty-One in overlays/cards.asm).
; Ante 10 each; mark cards to swap with 1-5, RETURN draws; best hand takes the pot.
;=======================================================================================
cards_mode:     .byte 0     ; 0 twenty-one, 1 poker
deck:           .fill 52, 0
deck_pos:       .byte 0
pk_mark:        .fill 5, 0
pk_key_p:       .fill 6, 0
pk_key_d:       .fill 6, 0
pk_counts:      .fill 15, 0
l_pk_tmp:       .byte 0
l_pk_j:         .byte 0

; fresh shuffled deck
deck_shuffle:
        ldx #0
l_dsh_fill:
        txa
        ldy #0                  ; y = suit, a = rank-1
-       cmp #13
        bcc +
        sbc #13
        iny
        bra -
+       clc
        adc #1
        sta l_pk_tmp
        tya
        asl
        asl
        asl
        asl
        ora l_pk_tmp
        sta deck,x
        inx
        cpx #52
        bne l_dsh_fill
        ; Fisher-Yates
        ldx #51
l_dsh_mix:
        phx
        inx
        txa
        jsr rnd_range
        tay
        plx
        lda deck,x
        pha
        lda deck,y
        sta deck,x
        pla
        sta deck,y
        dex
        bne l_dsh_mix
        lda #0
        sta deck_pos
        rts

deck_deal:
        ldx deck_pos
        lda deck,x
        inc deck_pos
        rts

poker_round:
        jsr cards_clear_table
        lda #10                 ; the win / lose paths move this many chips
        sta l_cd_win
        lda #0
        sta l_cd_say+1
        lda chips_p
        cmp #10
        bcs +
        jmp l_cp_quit_wait
+       lda chips_d
        cmp #10
        bcs +
        jmp l_cp_quit_wait
+       sec
        lda chips_p
        sbc #10
        sta chips_p
        sec
        lda chips_d
        sbc #10
        sta chips_d
        jsr cards_chips
        jsr deck_shuffle
        ldx #0
l_pr_deal:
        phx
        jsr deck_deal
        plx
        sta hand_p,x
        phx
        jsr deck_deal
        plx
        sta hand_d,x
        lda #0
        sta pk_mark,x
        inx
        cpx #5
        bne l_pr_deal
        lda #5
        sta hand_pn
        sta hand_dn
        lda #1
        sta l_cd_hide
        jsr poker_draw
        ldx #<cs_pk_prompt
        ldy #>cs_pk_prompt
        jsr cards_msg
l_pk_pick:
        jsr l_cp_key
        cmp #'q'
        bne +
        jmp l_cp_quit
+       cmp #KEY_RETURN
        beq l_pk_draw
        cmp #'1'
        bcc l_pk_pick
        cmp #'6'
        bcs l_pk_pick
        sec
        sbc #'1'
        tax
        lda pk_mark,x
        eor #1
        sta pk_mark,x
        lda #SFX_BLIP
        jsr sfx_play
        jsr poker_marks
        bra l_pk_pick
l_pk_draw:
        ; your swaps
        ldx #0
l_pk_swap:
        lda pk_mark,x
        beq +
        phx
        jsr deck_deal
        plx
        sta hand_p,x
        lda #0
        sta pk_mark,x
+       inx
        cpx #5
        bne l_pk_swap
        lda #SFX_CLACK
        jsr sfx_play
        ; his swaps, then the showdown
        jsr poker_ai
        lda #0
        sta l_cd_hide
        jsr poker_draw
        ldx #<hand_p
        ldy #>hand_p
        jsr poker_eval
        ldx #5
-       lda pk_key_d,x
        sta pk_key_p,x
        dex
        bpl -
        lda pk_key_p
        ldy #13
        jsr poker_show_name
        ldx #<hand_d
        ldy #>hand_d
        jsr poker_eval
        lda pk_key_d
        ldy #6
        jsr poker_show_name
        ldx #0
l_pk_cmp:
        lda pk_key_p,x
        cmp pk_key_d,x
        bne l_pk_decided
        inx
        cpx #6
        bne l_pk_cmp
        ; identical hands: split the pot
        clc
        lda chips_p
        adc #10
        sta chips_p
        clc
        lda chips_d
        adc #10
        sta chips_d
        jmp l_cp_push
l_pk_decided:
        bcc l_pk_he_wins
        ; you take the pot. (l_cp_you_win moves another 10 from him to you, so
        ; pre-pay it: net result = you +20, him +0 after the antes.)
        clc
        lda chips_p
        adc #10
        sta chips_p
        clc
        lda chips_d
        adc #10
        sta chips_d
        jmp l_cp_you_win
l_pk_he_wins:
        clc
        lda chips_d
        adc #10
        sta chips_d
        clc
        lda chips_p
        adc #10
        sta chips_p
        jmp l_cp_he_wins

; Draw both hands (his face down until the showdown).
poker_draw:
        lda #CW_Y0 + 4
        sta l_cd_row
        lda #0
        sta l_cd_i
-       ldx l_cd_i
        lda hand_d,x
        sta l_cd_card
        lda l_cd_hide
        jsr draw_card
        inc l_cd_i
        lda l_cd_i
        cmp #5
        bne -
        lda #CW_Y0 + 11
        sta l_cd_row
        lda #0
        sta l_cd_i
-       ldx l_cd_i
        lda hand_p,x
        sta l_cd_card
        lda #0
        jsr draw_card
        inc l_cd_i
        lda l_cd_i
        cmp #5
        bne -
        lda l_cd_hide
        beq +
        jmp poker_marks
+       rts

; Card numbers / swap marks under your hand (window row 13).
poker_marks:
        lda #C_FELT
        sta txt_bg
        lda #C_YELLOW
        sta txt_fg
        jsr sb_clear
        ldx #0
l_pm_loop:
        phx
        lda #' '
        jsr sb_char
        plx
        lda pk_mark,x
        beq l_pm_num
        phx
        lda #'X'
        jsr sb_char
        lda #'X'
        jsr sb_char
        plx
        bra l_pm_gap
l_pm_num:
        txa
        clc
        adc #'1'
        phx
        jsr sb_char
        lda #' '
        jsr sb_char
        plx
l_pm_gap:
        phx
        lda #' '
        jsr sb_char
        plx
        inx
        cpx #5
        bne l_pm_loop
        ldy #13
        jmp cards_print

; A = category, Y = window row: print the hand's name there.
poker_show_name:
        sty l_pk_tmp
        asl
        tax
        lda pk_names,x
        pha
        lda pk_names+1,x
        tay
        plx
        lda #C_FELT
        sta txt_bg
        lda #C_UIWHITE
        sta txt_fg
        jsr sb_clear
        jsr sb_strxy
-       lda sb_len
        cmp #20
        bcs +
        lda #' '
        jsr sb_char
        bra -
+       ldy l_pk_tmp
        jmp cards_print

pk_names:
        .word pkn0, pkn1, pkn2, pkn3, pkn4, pkn5, pkn6, pkn7, pkn8
pkn0:   .null "High card"
pkn1:   .null "One pair"
pkn2:   .null "Two pair"
pkn3:   .null "Three of a kind"
pkn4:   .null "Straight"
pkn5:   .null "Flush"
pkn6:   .null "Full house"
pkn7:   .null "Four of a kind"
pkn8:   .null "Straight flush!"

;---------------------------------------------------------------------------------------
; Evaluate the 5-card hand at X/Y into pk_key_d: [category, tiebreak ranks...].
; Categories 0 high card .. 8 straight flush. Aces are 14 (5 in A-2-3-4-5).
;---------------------------------------------------------------------------------------
l_pe_flush: .byte 0
l_pe_str:   .byte 0
l_pe_high:  .byte 0
l_pe_c:     .byte 0
l_pe_n:     .byte 0
l_pe_pairs: .byte 0
l_pe_three: .byte 0
l_pe_four:  .byte 0

poker_eval:
        stx ZPTR2
        sty ZPTR2+1
        ldx #14
        lda #0
-       sta pk_counts,x
        dex
        bpl -
        ldx #5
-       sta pk_key_d,x
        dex
        bpl -
        ; rank counts; flush if every suit matches the first card's
        lda #1
        sta l_pe_flush
        ldy #0
        lda (ZPTR2),y
        and #$30
        sta l_pk_tmp
l_pe_scan:
        lda (ZPTR2),y
        and #$30
        cmp l_pk_tmp
        beq +
        lda #0
        sta l_pe_flush
+       lda (ZPTR2),y
        and #15
        cmp #1
        bne +
        lda #14
+       tax
        inc pk_counts,x
        iny
        cpy #5
        bne l_pe_scan
        ; pairs / trips / quads
        lda #0
        sta l_pe_pairs
        sta l_pe_three
        sta l_pe_four
        ldx #14
l_pe_groups:
        lda pk_counts,x
        cmp #2
        bne +
        inc l_pe_pairs
+       cmp #3
        bne +
        inc l_pe_three
+       cmp #4
        bne +
        inc l_pe_four
+       dex
        cpx #1
        bne l_pe_groups
        ; straight: the highest card starts a run of five singles
        lda #0
        sta l_pe_str
        ldx #14
l_pe_top:
        lda pk_counts,x
        bne l_pe_run
        dex
        cpx #5
        bcs l_pe_top
        bra l_pe_cat
l_pe_run:
        cmp #1
        bne l_pe_cat
        cpx #5
        bcc l_pe_cat
        lda pk_counts-1,x
        cmp #1
        bne l_pe_wheel
        lda pk_counts-2,x
        cmp #1
        bne l_pe_wheel
        lda pk_counts-3,x
        cmp #1
        bne l_pe_wheel
        lda pk_counts-4,x
        cmp #1
        bne l_pe_wheel
        stx l_pe_high
        lda #1
        sta l_pe_str
        bra l_pe_cat
l_pe_wheel:
        ; A-2-3-4-5
        cpx #14
        bne l_pe_cat
        lda pk_counts+2
        and pk_counts+3
        and pk_counts+4
        and pk_counts+5
        cmp #1
        bne l_pe_cat
        lda #5
        sta l_pe_high
        lda #1
        sta l_pe_str
l_pe_cat:
        lda #0
        ldx l_pe_pairs
        cpx #1
        bne +
        lda #1
+       cpx #2
        bne +
        lda #2
+       ldx l_pe_three
        beq +
        lda #3
        ldx l_pe_pairs
        beq +
        lda #6
+       ldx l_pe_str
        beq +
        cmp #4
        bcs +
        lda #4
+       ldx l_pe_flush
        beq +
        cmp #5
        bcs +
        lda #5
+       ldx l_pe_four
        beq +
        lda #7
+       ldx l_pe_str
        beq +
        ldx l_pe_flush
        beq +
        lda #8
+       sta pk_key_d
        ; tiebreaks: straights by top card, else ranks by count then rank
        lda l_pe_str
        beq +
        lda l_pe_high
        sta pk_key_d+1
        rts
+       lda #1
        sta l_pe_n
        lda #4
        sta l_pe_c
l_pe_cnt:
        ldx #14
l_pe_rank:
        lda pk_counts,x
        cmp l_pe_c
        bne +
        txa
        ldy l_pe_n
        sta pk_key_d,y
        inc l_pe_n
+       dex
        cpx #1
        bne l_pe_rank
        dec l_pe_c
        bne l_pe_cnt
        rts

;---------------------------------------------------------------------------------------
; His draw: keep anything paired (or a made straight/flush); with nothing, keep
; his two highest cards and swap the rest.
;---------------------------------------------------------------------------------------
poker_ai:
        ldx #<hand_d
        ldy #>hand_d
        jsr poker_eval
        lda pk_key_d
        cmp #4
        bcs l_pai_none
        lda #0
        sta l_pk_j
        ldx #0
l_pai_loop:
        lda hand_d,x
        and #15
        cmp #1
        bne +
        lda #14
+       sta l_pk_tmp
        tay
        lda pk_counts,y
        cmp #2
        bcs l_pai_keep
        lda pk_key_d
        bne l_pai_swap
        lda l_pk_tmp
        cmp pk_key_d+1
        beq l_pai_keep
        cmp pk_key_d+2
        beq l_pai_keep
l_pai_swap:
        phx
        jsr deck_deal
        plx
        sta hand_d,x
        inc l_pk_j
l_pai_keep:
        inx
        cpx #5
        bne l_pai_loop
        jsr sb_clear
        jsr sb_lcp
        ldx #<cs_pk_draws
        ldy #>cs_pk_draws
        jsr sb_strxy
        lda l_pk_j
        jsr sb_num
        bra l_pai_msg
l_pai_none:
        jsr sb_clear
        jsr sb_lcp
        ldx #<cs_pk_stands
        ldy #>cs_pk_stands
        jsr sb_strxy
l_pai_msg:
        ldx #0
-       lda sb,x
        sta pk_msg,x
        inx
        cpx #SB_MAX + 1
        bne -
        ldx #<pk_msg
        ldy #>pk_msg
        jmp cards_msg2
pk_msg: .fill SB_MAX + 1, 0

cs_pk_prompt: .null "1-5 mark cards, RETURN = draw"
cs_pk_draws:  .null " draws "
cs_pk_stands: .null " stands pat."
