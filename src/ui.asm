;=======================================================================================
; UI: the two text rows over the sky (speech + input/status), a string builder,
; and text windows (help, letters).
;
; Row 0: what he says (or what he is doing when he is quiet).
; Row 1: your typed line once you start typing, otherwise the status line.
;=======================================================================================

SB_MAX          = 40

sb:             .fill SB_MAX + 1, 0
sb_len:         .byte 0

sb_clear:
        lda #0
        sta sb_len
        sta sb
        rts

; append zero-terminated string at ZPTR
sb_str:
        ldy #0
-       lda (ZPTR),y
        beq +
        jsr sb_char
        iny
        bne -
+       rts

; append A (preserves Y)
sb_char:
        ldx sb_len
        cpx #SB_MAX
        bcs +
        sta sb,x
        inx
        stx sb_len
        lda #0
        sta sb,x
+       rts

; A = 0..99 as two digits
sb_num2:
        ldx #'0'
-       cmp #10
        bcc +
        sec
        sbc #10
        inx
        bra -
+       pha
        txa
        jsr sb_char
        pla
        clc
        adc #'0'
        jmp sb_char

; A = 0..255, no leading zeros
sb_num:
        ldx #0
        stx l_sbn_lead
        ldx #0
-       cmp #100
        bcc +
        sbc #100
        inx
        bra -
+       pha
        txa
        beq +
        clc
        adc #'0'
        jsr sb_char
        inc l_sbn_lead
+       pla
        ldx #0
-       cmp #10
        bcc +
        sbc #10
        inx
        bra -
+       pha
        txa
        bne +
        ldx l_sbn_lead
        beq ++
+       clc
        adc #'0'
        jsr sb_char
+       pla
        clc
        adc #'0'
        jmp sb_char
l_sbn_lead: .byte 0

; append a word of text from a 16-bit pointer in X (lo) / Y (hi)
sb_strxy:
        stx ZPTR
        sty ZPTR+1
        jmp sb_str

sb_player:
        ldx #<player_name
        ldy #>player_name
        jmp sb_strxy

sb_lcp:
        ldx lcp_name_ptr
        ldy lcp_name_ptr+1
        jmp sb_strxy

; "hh:mmAM"
sb_time:
        lda clock_hour
        cmp #12
        bcc +
        sbc #12
+       cmp #0
        bne +
        lda #12
+       cmp #10
        bcs +
        pha
        lda #' '
        jsr sb_char
        pla
        jsr sb_num
        bra ++
+       jsr sb_num2
+       lda #':'
        jsr sb_char
        lda clock_min
        jsr sb_num2
        lda #'A'
        ldx clock_hour
        cpx #12
        bcc +
        lda #'P'
+       jsr sb_char
        lda #'M'
        jmp sb_char

;---------------------------------------------------------------------------------------
; Bar rows
;---------------------------------------------------------------------------------------
; Print the string builder on row Y, padded with spaces to 40 columns.
print_sb_row:
        sty l_psr_row
        lda #<sb
        sta ZPTR
        lda #>sb
        sta ZPTR+1
        ldx #0
        jsr print_str
        lda #COLS
        sec
        sbc sb_len
        beq +
        ldx sb_len
        ldy l_psr_row
        jmp print_spaces
+       rts
l_psr_row: .byte 0

speech:         .fill SB_MAX + 1, 0
speech_timer:   .byte 0     ; frames left (x4) for the current speech
ui_dirty:       .byte 1     ; redraw both bar rows next frame
ui_hidden:      .byte 0     ; a window/game owns the screen: skip bar redraws

; Say the string builder (row 0) for ~5 seconds.
ui_say_sb:
        ldx #0
-       lda sb,x
        sta speech,x
        beq +
        inx
        cpx #SB_MAX
        bne -
        lda #0
        sta speech,x
+       lda #80
        sta speech_timer
        lda #1
        sta ui_dirty
        rts

; Say a fixed string: X/Y = pointer. "NAME: " prefix with his name.
ui_say:
        stx l_uis_p
        sty l_uis_p+1
        jsr sb_clear
        jsr sb_lcp
        lda #':'
        jsr sb_char
        lda #' '
        jsr sb_char
        ldx l_uis_p
        ldy l_uis_p+1
        jsr sb_strxy
        jmp ui_say_sb
l_uis_p: .word 0

; Narration (no name prefix)
ui_note:
        jsr sb_clear
        jsr sb_strxy
        jmp ui_say_sb

; Called every frame.
ui_tick:
        lda frame_count
        and #3
        bne +
        lda speech_timer
        beq +
        dec speech_timer
        bne +
        lda #1
        sta ui_dirty
+       lda ui_hidden
        bne l_ut_out
        lda ui_dirty
        beq l_ut_out
        lda #0
        sta ui_dirty
        jsr ui_draw_row0
        jsr ui_draw_row1
l_ut_out:
        rts

ui_draw_row0:
        lda #C_BAR
        sta txt_bg
        lda speech_timer
        beq l_ur0_doing
        lda #C_SPEECH
        sta txt_fg
        jsr sb_clear
        ldx #<speech
        ldy #>speech
        jsr sb_strxy
        ldy #0
        jmp print_sb_row
l_ur0_doing:
        lda #C_TEXT
        sta txt_fg
        jsr sb_clear
        jsr activity_describe
        ldy #0
        jmp print_sb_row

ui_draw_row1:
        lda #C_BAR
        sta txt_bg
        lda #C_TEXT
        sta txt_fg
        lda input_len
        beq ui_draw_status
        jsr sb_clear
        lda #'>'
        jsr sb_char
        ldx #<input_buf
        ldy #>input_buf
        jsr sb_strxy
        lda #9                  ; block cursor
        jsr sb_char
        ldy #1
        jmp print_sb_row

ui_draw_status:
        jsr sb_clear
        jsr sb_time
        ldx #<l_st_food
        ldy #>l_st_food
        jsr sb_strxy
        lda food
        jsr sb_num
        ldx #<l_st_water
        ldy #>l_st_water
        jsr sb_strxy
        lda water
        jsr sb_num
        ldx #<l_st_dog
        ldy #>l_st_dog
        jsr sb_strxy
        lda dogfood
        jsr sb_num
        ldx #<l_st_mood
        ldy #>l_st_mood
        jsr sb_strxy
        lda #5
        ldx mood
        cpx #45
        bcs +
        lda #6
+       jsr sb_char
        lda fast_forward
        beq +
        ldx #<l_st_ff
        ldy #>l_st_ff
        jsr sb_strxy
        bra ++
+       ldx #<l_st_help
        ldy #>l_st_help
        jsr sb_strxy
+       ldy #1
        jsr print_sb_row
        ; colour the mood face
        lda #C_GREEN
        ldx mood
        cpx #45
        bcs +
        lda #C_RED
+       sta txt_fg
        lda #5
        ldx mood
        cpx #45
        bcs +
        lda #6
+       ldx #34
        ldy #1
        jsr draw_glyph
        lda #C_TEXT
        sta txt_fg
        rts

l_st_food:  .null " FOOD:"
l_st_water: .null " WATER:"
l_st_dog:   .null " DOG:"
l_st_mood:  .null " MOOD:"
l_st_help:  .null "  F1"
l_st_ff:    .null "  >>"

;---------------------------------------------------------------------------------------
; Text window: lines of text in a paper box. win_lines points to a list of
; zero-terminated strings ending with an empty string; special: a line that starts
; with "@N" prints the player's name, "@L" his name.
;---------------------------------------------------------------------------------------
win_x0: .byte 3
win_y0: .byte 3
win_x1: .byte 36
win_y1: .byte 22
l_wl_row: .byte 0

window_open:
        lda #1
        sta ui_hidden
        lda win_x0
        sta rc_x0
        lda win_y0
        sta rc_y0
        lda win_x1
        sta rc_x1
        lda win_y1
        sta rc_y1
        lda #C_PAPER
        jsr draw_window
        lda #C_PAPER
        sta txt_bg
        lda #C_INK
        sta txt_fg
        rts

window_close:
        lda win_x0
        sta rc_x0
        lda win_y0
        sta rc_y0
        lda win_x1
        sta rc_x1
        lda win_y1
        sta rc_y1
        jsr restore_cells
        lda #0
        sta ui_hidden
        lda #1
        sta ui_dirty
        jsr actors_force_redraw
        rts

; Print sb on window row Y (relative), indented 1 column.
window_print_sb:
        tya
        clc
        adc win_y0
        adc #1
        tay
        ldx win_x0
        inx
        lda #<sb
        sta ZPTR
        lda #>sb
        sta ZPTR+1
        jmp print_str

; Print a list of strings (X/Y = list start) from window row 1.
window_print_list:
        lda #1
        sta l_wl_row
; Same, continuing at the current window row (l_wl_row).
window_print_more:
        stx ZPTR2
        sty ZPTR2+1
l_wpl:
        ldy #0
        lda (ZPTR2),y
        beq l_wpl_done
        jsr sb_clear
        ; expand @N / @L
        ldy #0
l_wpl_c:
        lda (ZPTR2),y
        beq l_wpl_eol
        cmp #'@'
        bne l_wpl_plain
        iny
        lda (ZPTR2),y
        phy
        cmp #'N'
        bne +
        jsr sb_player
        bra l_wpl_exp
+       jsr sb_lcp
l_wpl_exp:
        ply
        iny
        bra l_wpl_c
l_wpl_plain:
        phy
        jsr sb_char
        ply
        iny
        bra l_wpl_c
l_wpl_eol:
        iny
        tya
        clc
        adc ZPTR2
        sta ZPTR2
        bcc +
        inc ZPTR2+1
+       ldy l_wl_row
        jsr window_print_sb
        inc l_wl_row
        bra l_wpl
l_wpl_done:
        rts

; Wait for RETURN / ESC / SPACE (keeps sound running).
wait_dismiss:
-       jsr wait_frame
        jsr sound_tick
        jsr key_get
        beq -
        cmp #KEY_RETURN
        beq +
        cmp #' '
        beq +
        cmp #KEY_ESC
        beq +
        cmp #KEY_F1
        bne -
+       rts

help_lines:
        .null "  LITTLE MEGA PEOPLE - HOW TO PLAY"
        .null " "
        .null "@L lives in this house. Talk to"
        .null "him by typing, then RETURN. Be"
        .null "polite! Try PLEASE PLAY THE PIANO,"
        .null "WATCH TV, READ A BOOK, EAT, DRINK,"
        .null "DANCE, EXERCISE, TAKE A BATH,"
        .null "BRUSH TEETH, WRITE A LETTER, PLAY"
        .null "CARDS, FEED THE DOG, LIGHT A FIRE,"
        .null "GO TO BED, CHANGE CLOTHES, GO OUT."
        .null " "
        .null "CTRL-F food     CTRL-W water"
        .null "CTRL-D dog food CTRL-B book"
        .null "CTRL-R record   CTRL-P pet him"
        .null "CTRL-C call him CTRL-A alarm"
        .null "F5 fast time    F7 quit"
        .null " "
        .null "        PRESS RETURN"
        .byte 0

help_show:
        lda #3
        sta win_x0
        lda #3
        sta win_y0
        lda #36
        sta win_x1
        lda #23
        sta win_y1
        jsr window_open
        ldx #<help_lines
        ldy #>help_lines
        jsr window_print_list
        jsr wait_dismiss
        jmp window_close
