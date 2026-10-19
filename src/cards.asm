;=======================================================================================
; Cards: Twenty-One against him (the Amiga original offers him a game of cards too).
; Modal: runs its own loop until you quit. Win too often and he sulks.
;
; A card is rank (1..13) + suit*16 (0 spade, 1 heart, 2 diamond, 3 club).
;=======================================================================================

CW_X0           = 2
CW_Y0           = 3
CW_X1           = 37
CW_Y1           = 22

hand_p:         .fill 8, 0
hand_d:         .fill 8, 0
hand_pn:        .byte 0
hand_dn:        .byte 0
chips_p:        .byte 100
chips_d:        .byte 100
l_cd_hide:       .byte 1     ; dealer hole card hidden
l_cd_tot:        .byte 0
l_cd_aces:       .byte 0

cards_play:
        lda #CW_X0
        sta win_x0
        lda #CW_Y0
        sta win_y0
        lda #CW_X1
        sta win_x1
        lda #CW_Y1
        sta win_y1
        lda #1
        sta ui_hidden
        lda #CW_X0
        sta rc_x0
        lda #CW_Y0
        sta rc_y0
        lda #CW_X1
        sta rc_x1
        lda #CW_Y1
        sta rc_y1
        lda #C_YELLOW
        sta win_border_col
        lda #C_FELT
        jsr draw_window
        lda #C_INK
        sta win_border_col
        lda #100
        sta chips_p
        sta chips_d
        ; which game?
        lda #0
        sta cards_mode
        jsr cards_clear_table
        ldx #<cs_choose
        ldy #>cs_choose
        jsr cards_msg
l_cp_choose:
        jsr l_cp_key
        cmp #'p'
        beq l_cp_poker
        cmp #'t'
        beq l_cp_round
        cmp #'2'
        beq l_cp_round
        cmp #'b'
        beq l_cp_round
        cmp #'q'
        beq l_cp_no
        cmp #'n'
        beq l_cp_no
        cmp #KEY_ESC
        beq l_cp_no
        bra l_cp_choose
l_cp_poker:
        lda #1
        sta cards_mode
        jmp poker_round
l_cp_no:
        lda #3
        jsr mood_down
        jsr window_close
        ldx #<cs_aww
        ldy #>cs_aww
        jmp ui_say

l_cp_round:
        jsr cards_clear_table
        lda #0
        sta hand_pn
        sta hand_dn
        lda #1
        sta l_cd_hide
        jsr deal_p
        jsr deal_d
        jsr deal_p
        jsr deal_d
        jsr cards_draw_all
        ldx #<cs_prompt
        ldy #>cs_prompt
        jsr cards_msg
l_cp_player:
        jsr l_cp_key
        cmp #'h'
        beq l_cp_hit
        cmp #KEY_F1
        beq l_cp_hit
        cmp #'s'
        beq l_cp_stand
        cmp #KEY_F3
        beq l_cp_stand
        cmp #'q'
        bne l_cp_player
        jmp l_cp_quit
l_cp_hit:
        jsr deal_p
        jsr cards_draw_all
        ldx #<hand_p
        ldy hand_pn
        jsr hand_total
        cmp #22
        bcc l_cp_player
        ldx #<cs_bust
        ldy #>cs_bust
        jsr cards_msg
        jmp l_cp_he_wins
l_cp_stand:
        lda #0
        sta l_cd_hide
l_cp_dealer:
        jsr cards_draw_all
        ldx #<hand_d
        ldy hand_dn
        jsr hand_total
        cmp #17
        bcs l_cp_compare
        ldy #25
-       jsr wait_frame
        jsr sound_tick
        dey
        bne -
        jsr deal_d
        bra l_cp_dealer
l_cp_compare:
        sta l_cd_tot
        cmp #22
        bcs l_cp_you_win
        ldx #<hand_p
        ldy hand_pn
        jsr hand_total
        cmp l_cd_tot
        beq l_cp_push
        bcs l_cp_you_win
l_cp_he_wins:
        lda #0
        sta l_cd_hide
        jsr cards_draw_all
        clc
        lda chips_d
        adc #10
        sta chips_d
        sec
        lda chips_p
        sbc #10
        sta chips_p
        lda #3
        jsr mood_up
        lda #SFX_CHIME
        jsr sfx_play
        ldx #<cs_hewins
        ldy #>cs_hewins
        jsr cards_msg
        jmp l_cp_again
l_cp_push:
        ldx #<cs_push
        ldy #>cs_push
        jsr cards_msg
        jmp l_cp_again
l_cp_you_win:
        clc
        lda chips_p
        adc #10
        sta chips_p
        sec
        lda chips_d
        sbc #10
        sta chips_d
        inc cards_won
        lda #SFX_BLIP
        jsr sfx_play
        lda cards_won
        cmp #4
        bcs l_cp_sulk
        lda #1
        jsr mood_up
        ldx #<cs_youwin
        ldy #>cs_youwin
        jsr cards_msg
        bra l_cp_again
l_cp_sulk:
        lda #4
        jsr mood_down
        ldx #<cs_sulk
        ldy #>cs_sulk
        jsr cards_msg
l_cp_again:
        jsr cards_chips
        lda chips_p
        beq l_cp_quit_wait
        lda chips_d
        beq l_cp_quit_wait
        ldx #<cs_again
        ldy #>cs_again
        jsr cards_msg2
-       jsr l_cp_key
        cmp #'y'
        beq l_cp_more
        cmp #KEY_RETURN
        bne +
l_cp_more:
        lda cards_mode
        beq l_cp_more21
        jmp poker_round
l_cp_more21:
        jmp l_cp_round
+       cmp #'n'
        beq l_cp_quit
        cmp #'q'
        beq l_cp_quit
        bra -
l_cp_quit_wait:
        ldx #<cs_over
        ldy #>cs_over
        jsr cards_msg2
        jsr wait_dismiss
l_cp_quit:
        lda #0
        sta cards_won
        jmp window_close

; key, lower-cased
l_cp_key:
-       jsr wait_frame
        jsr sound_tick
        jsr key_get
        beq -
        cmp #'A'
        bcc +
        cmp #'Z'+1
        bcs +
        ora #$20
+       rts

deal_p:
        jsr random_card
        ldx hand_pn
        cpx #7
        bcs +
        sta hand_p,x
        inc hand_pn
+       lda #SFX_CLACK
        jmp sfx_play
deal_d:
        jsr random_card
        ldx hand_dn
        cpx #7
        bcs +
        sta hand_d,x
        inc hand_dn
+       rts

random_card:
        lda #13
        jsr rnd_range
        clc
        adc #1
        sta ZTMP+2
        lda #4
        jsr rnd_range
        asl
        asl
        asl
        asl
        ora ZTMP+2
        rts

; X = <hand (hand_p or hand_d, same page assumed via table below), Y = count
; -> A = best total
hand_total:
        sty ZTMP+3
        lda #0
        sta l_cd_tot
        sta l_cd_aces
        ldy #0
-       cpy ZTMP+3
        beq l_ht_fix
        cpx #<hand_p
        bne +
        lda hand_p,y
        bra ++
+       lda hand_d,y
+       and #15
        cmp #1
        bne +
        inc l_cd_aces
        lda #11
        bra ++
+       cmp #11
        bcc +
        lda #10
+       clc
        adc l_cd_tot
        sta l_cd_tot
        iny
        bra -
l_ht_fix:
        lda l_cd_tot
        cmp #22
        bcc +
        lda l_cd_aces
        beq +
        dec l_cd_aces
        sec
        lda l_cd_tot
        sbc #10
        sta l_cd_tot
        bra l_ht_fix
+       lda l_cd_tot
        rts

;---------------------------------------------------------------------------------------
; Drawing
;---------------------------------------------------------------------------------------
cards_clear_table:
        lda #CW_X0 + 1
        sta rc_x0
        lda #CW_Y0 + 1
        sta rc_y0
        lda #CW_X1 - 1
        sta rc_x1
        lda #CW_Y1 - 1
        sta rc_y1
        lda #C_FELT
        jsr fill_cells
        lda #C_FELT
        sta txt_bg
        lda #C_UIWHITE
        sta txt_fg
        jsr sb_clear
        ldx #<cs_title
        ldy #>cs_title
        lda cards_mode
        beq +
        ldx #<cs_ptitle
        ldy #>cs_ptitle
+       jsr sb_strxy
        jsr sb_lcp
        ldy #0
        jsr cards_print
        jsr sb_clear
        jsr sb_lcp
        ldx #<cs_his
        ldy #>cs_his
        jsr sb_strxy
        ldy #2
        jsr cards_print
        jsr sb_clear
        ldx #<cs_yours
        ldy #>cs_yours
        jsr sb_strxy
        ldy #9
        jsr cards_print
        jmp cards_chips

; print sb on window row Y (relative), col +2
cards_print:
        tya
        clc
        adc #CW_Y0 + 1
        tay
        ldx #CW_X0 + 2
        lda #<sb
        sta ZPTR
        lda #>sb
        sta ZPTR+1
        jmp print_str

cards_chips:
        lda #C_FELT
        sta txt_bg
        lda #C_YELLOW
        sta txt_fg
        jsr sb_clear
        ldx #<cs_chips1
        ldy #>cs_chips1
        jsr sb_strxy
        lda chips_p
        jsr sb_num
        ldx #<cs_chips2
        ldy #>cs_chips2
        jsr sb_strxy
        jsr sb_lcp
        lda #':'
        jsr sb_char
        lda #' '
        jsr sb_char
        lda chips_d
        jsr sb_num
        lda #' '
        jsr sb_char
        jsr sb_char
        ldy #17
        jmp cards_print

cards_msg:
        stx l_cm_p
        sty l_cm_p+1
        lda #16
        sta l_cm_row
        bra l_cm_go
cards_msg2:
        stx l_cm_p
        sty l_cm_p+1
        lda #15
        sta l_cm_row
l_cm_go:
        lda #C_FELT
        sta txt_bg
        lda #C_YELLOW
        sta txt_fg
        jsr sb_clear
        ldx l_cm_p
        ldy l_cm_p+1
        jsr sb_strxy
-       lda sb_len
        cmp #32
        bcs +
        lda #' '
        jsr sb_char
        bra -
+       ldy l_cm_row
        jmp cards_print
l_cm_p:   .word 0
l_cm_row: .byte 0

l_cd_i:   .byte 0
l_cd_col: .byte 0
l_cd_row: .byte 0
l_cd_card: .byte 0

cards_draw_all:
        ; his hand on rows 4..6, yours on rows 11..13 (window-relative +1)
        lda #CW_Y0 + 4
        sta l_cd_row
        lda #0
        sta l_cd_i
-       lda l_cd_i
        cmp hand_dn
        bcs +
        tax
        lda hand_d,x
        sta l_cd_card
        lda #0
        cpx #1
        bne l_cda_show
        lda l_cd_hide
l_cda_show:
        jsr draw_card
        inc l_cd_i
        bra -
+       lda #CW_Y0 + 11
        sta l_cd_row
        lda #0
        sta l_cd_i
-       lda l_cd_i
        cmp hand_pn
        bcs +
        tax
        lda hand_p,x
        sta l_cd_card
        lda #0
        jsr draw_card
        inc l_cd_i
        bra -
+       ; totals
        lda #C_FELT
        sta txt_bg
        lda #C_UIWHITE
        sta txt_fg
        jsr sb_clear
        lda l_cd_hide
        bne +
        ldx #<cs_total
        ldy #>cs_total
        jsr sb_strxy
        ldx #<hand_d
        ldy hand_dn
        jsr hand_total
        jsr sb_num
+       lda #' '
        jsr sb_char
        jsr sb_char
        jsr sb_char
        ldy #6
        jsr cards_print
        jsr sb_clear
        ldx #<cs_total
        ldy #>cs_total
        jsr sb_strxy
        ldx #<hand_p
        ldy hand_pn
        jsr hand_total
        jsr sb_num
        lda #' '
        jsr sb_char
        ldy #13
        jmp cards_print

; Draw card l_cd_card at slot l_cd_i on l_cd_row. A = 1 for face down.
draw_card:
        sta l_dc_back
        lda l_cd_i
        asl
        asl
        clc
        adc #CW_X0 + 3
        sta l_cd_col
        sta rc_x0
        clc
        adc #2
        sta rc_x1
        lda l_cd_row
        sta rc_y0
        clc
        adc #2
        sta rc_y1
        lda #C_CARDBACK
        ldx l_dc_back
        bne +
        lda #C_UIWHITE
+       jsr fill_cells
        lda l_dc_back
        bne l_dc_out
        lda #C_UIWHITE
        sta txt_bg
        lda l_cd_card
        and #$30
        cmp #$10
        beq +
        cmp #$20
        beq +
        lda #C_CARDBLACK
        bra ++
+       lda #C_CARDRED
+       sta txt_fg
        ; rank, top-left
        lda l_cd_card
        and #15
        tax
        lda rank_ch,x
        ldx l_cd_col
        ldy l_cd_row
        jsr draw_glyph
        lda l_cd_card
        and #15
        cmp #10
        bne +
        lda #'0'
        ldx l_cd_col
        inx
        ldy l_cd_row
        jsr draw_glyph
+       ; suit, centre
        lda l_cd_card
        lsr
        lsr
        lsr
        lsr
        clc
        adc #1
        ldx l_cd_col
        inx
        ldy l_cd_row
        iny
        jsr draw_glyph
        ; rank, bottom-right
        lda l_cd_card
        and #15
        tax
        lda rank_ch,x
        ldx l_cd_col
        inx
        inx
        ldy l_cd_row
        iny
        iny
        jsr draw_glyph
l_dc_out:
        rts
l_dc_back: .byte 0
rank_ch:  .text "?A23456789"
          .text "1JQK"

cs_title:  .null "   TWENTY-ONE with "
cs_ptitle: .null "   POKER with "
cs_choose: .null "Poker or Twenty-One? (P/T, Q=no)"
cs_aww:    .null "Aww, maybe some other time then."
cs_his:    .null "'s cards:"
cs_yours:  .null "Your cards:"
cs_total:  .null "Total: "
cs_prompt: .null "H = hit   S = stand   Q = quit"
cs_bust:   .null "Bust! Over 21."
cs_hewins: .null "Ha! I win this one!"
cs_youwin: .null "You win! Nice hand."
cs_sulk:   .null "Hmph. You win AGAIN?"
cs_push:   .null "A tie. Nobody wins."
cs_again:  .null "Another hand? (Y/N)"
cs_over:   .null "That's all the chips. Good game!"
cs_chips1: .null "Your chips: "
cs_chips2: .null "   "
