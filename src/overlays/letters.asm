;=======================================================================================
; Letters. Every so often he sits at the computer and writes to you. What he
; writes about depends on how things are going in the house.
;=======================================================================================

; Each topic: a condition routine (C = 1 to include) and a list of lines.
topic_cond:
        .word tc_sleep, tc_water, tc_food, tc_dogfood, tc_book, tc_record, tc_sick
        .word tc_lonely, tc_happy, tc_never, tc_never, tc_never, tc_never
topic_text:
        .word tt_sleep, tt_water, tt_food, tt_dogfood, tt_book, tt_record, tt_sick
        .word tt_lonely, tt_happy, tt_dog, tt_party, tt_piano, tt_weather
TOPIC_COUNT     = 13
TOPIC_RANDOM0   = 9         ; topics from here on are filler, chosen at random

l_lt_n:     .byte 0
l_lt_i:     .byte 0

letter_show:
        lda #SFX_CHIME
        jsr sfx_play
        lda #3
        sta win_x0
        lda #3
        sta win_y0
        lda #36
        sta win_x1
        lda #21                 ; (room for a long topic and a short one)
        sta win_y1
        jsr window_open
        jsr sb_clear
        jsr sb_date
        ldy #0
        jsr window_print_sb
        ldx #<lt_head
        ldy #>lt_head
        lda #2
        sta l_wl_row
        jsr window_print_more
        ; pick up to two topics: urgent ones first, then random filler
        lda #0
        sta l_lt_n
        ldx #TOPIC_COUNT-1
-       sta l_lt_used,x
        dex
        bpl -
        lda #0
        sta l_lt_i
l_lt_scan:
        lda l_lt_i
        asl
        tax
        jsr l_lt_cond
        bcc l_lt_skip
        ldx l_lt_i
        jsr l_lt_print
        lda l_lt_n
        cmp #2
        beq l_lt_tail
l_lt_skip:
        inc l_lt_i
        lda l_lt_i
        cmp #TOPIC_RANDOM0
        bne l_lt_scan
l_lt_fill:
        lda l_lt_n
        cmp #2
        beq l_lt_tail
        lda #TOPIC_COUNT - TOPIC_RANDOM0
        jsr rnd_range
        clc
        adc #TOPIC_RANDOM0
        tax
        lda l_lt_used,x
        bne l_lt_fill
        jsr l_lt_print
        bra l_lt_fill
l_lt_tail:
        ldx #<lt_tail
        ldy #>lt_tail
        jsr window_print_more
        lda #0
        sta gift_flags
        lda #5
        jsr mood_up
        jsr wait_dismiss_1min   ; (RETURN, or it goes after a minute)
        jmp window_close

l_lt_cond:
        jmp (topic_cond,x)

; X = topic: print it followed by a blank line
l_lt_print:
        lda #1
        sta l_lt_used,x
        inc l_lt_n
        txa
        asl
        tax
        lda topic_text,x
        pha
        lda topic_text+1,x
        tay
        plx
        jsr window_print_more
        inc l_wl_row
        rts

tc_sleep:                       ; woken up too often last night
        lda sleep_plea
        beq tc_never
        sec
        rts
tc_water:
        lda water
        cmp #3
        bra l_tc_low
tc_never:
        clc
        rts
tc_food:
        lda food
        cmp #3
        bra l_tc_low
tc_dogfood:
        lda dogfood
        cmp #3
        bra l_tc_low
l_tc_low:
        ; C = 1 (>= 3) -> not low
        bcs tc_never
        sec
        rts
tc_book:
        lda gift_flags
        and #1
        bra l_tc_flag
tc_record:
        lda gift_flags
        and #2
l_tc_flag:
        beq tc_never
        sec
        rts
tc_sick:
        lda health
        cmp #50
        bra l_tc_low
tc_lonely:
        lda lonely
        cmp #120
        rts
tc_happy:
        lda mood
        cmp #70
        rts

lt_head:
        .null "Dear @N,"
        .null " "
        .byte 0
lt_tail:
        .null "Your pal,"
        .null "@L"
        .null " "
        .null "          (PRESS RETURN)"
        .byte 0

tt_sleep:
        .null "I hope you don't mind me asking,"
        .null "but could you let me sleep at"
        .null "night? I really need my beauty"
        .null "sleep!"
        .byte 0
tt_water:
        .null "My water bottle is almost"
        .null "empty. Could you fill it up?"
        .null "(Just press CTRL-W.)"
        .byte 0
tt_food:
        .null "I'm running low on food."
        .null "Could you send some groceries?"
        .null "(CTRL-F does the trick.)"
        .byte 0
tt_dogfood:
        .null "The dog keeps staring at his"
        .null "empty bowl. Dog food? (CTRL-D)"
        .byte 0
tt_book:
        .null "Thanks so much for the book!"
        .null "I couldn't put it down."
        .byte 0
tt_record:
        .null "That record you sent is great!"
        .null "I've been dancing all week."
        .byte 0
tt_sick:
        .null "I've been feeling a bit under"
        .null "the weather lately."
        .byte 0
tt_lonely:
        .null "I haven't heard from you in a"
        .null "while. Is everything OK?"
        .null "Drop me a line sometime!"
        .byte 0
tt_happy:
        .null "I really love living here."
        .null "This house is just perfect!"
        .byte 0
tt_dog:
        .null "I think I'd like to try to"
        .null "teach the dog a few tricks."
        .null "Got any ideas?"
        .byte 0
tt_party:
        .null "I'm thinking of throwing a"
        .null "party. Want to come over?"
        .byte 0
tt_piano:
        .null "I've been practicing the"
        .null "piano. I'm getting better!"
        .byte 0
tt_weather:
        .null "The weather has been lovely."
        .null "I might go for a walk soon."
        .byte 0
