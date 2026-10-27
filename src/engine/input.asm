;=======================================================================================
; Keyboard: the MEGA65 typing queue ($D610), the typed command line, CTRL gifts,
; and the keyword parser that turns "please play the piano" into a request.
;=======================================================================================

INPUT_MAX       = 36

input_buf:      .fill INPUT_MAX + 1, 0
input_len:      .byte 0
time_prompt:    .byte 0     ; 1 = CTRL-T: the line typed is a time for the clock

; Return next key in A (0 = none). Sets Z accordingly.
key_get:
        lda KEYQUEUE
        beq +
        cmp #$FF
        beq l_kg_skip
        pha
        sta KEYQUEUE
        pla
        cmp #0
        rts
l_kg_skip:
        sta KEYQUEUE
        lda #0
+       rts

; Drain the queue.
key_flush:
-       lda KEYQUEUE
        beq +
        sta KEYQUEUE
        bra -
+       rts

;---------------------------------------------------------------------------------------
; Per-frame keyboard handling in the house.
;---------------------------------------------------------------------------------------
input_tick:
        jsr key_get
        bne +
        rts
+       cmp #KEY_RETURN
        beq l_it_return
        cmp #KEY_DEL            ; (CTRL-T comes as the DEL code too)
        bne +
        lda KEYMODS
        and #KEYMOD_CTRL
        beq l_it_del
        jmp time_ask
+       cmp #KEY_F1
        bne +
        jmp help_show
+       cmp #KEY_F5             ; F5: flat out, or back to real time
        bne +
        lda #SPEED_MAX
        ldx fast_forward
        beq l_it_speed
        lda #0
l_it_speed:
        jmp speed_set
+       ldx input_len           ; + / - (not while typing): time twice as
        bne l_it_typing         ;  fast, or half
        cmp #'+'
        bne +
        lda fast_forward
        cmp #SPEED_MAX
        bcs l_it_out2
        inc a
        bra l_it_speed
+       cmp #'-'
        bne l_it_typing
        lda fast_forward
        beq l_it_out2
        dec a
        bra l_it_speed
l_it_out2:
        rts
l_it_typing:
+       cmp #KEY_F7
        bne +
        lda #1
        sta quit_request
        rts
+       cmp #KEY_ESC            ; (setting the time: never mind)
        bne +
        lda time_prompt
        beq l_it_out
        bra l_it_cancel
+       cmp #27                 ; CTRL-A .. CTRL-Z arrive as $01..$1A
        bcs l_it_print
        jmp ctrl_key
l_it_print:
        cmp #' '
        bcc l_it_out
        cmp #$7F
        bcs l_it_out
        ldx input_len
        cpx #INPUT_MAX
        bcs l_it_out
        sta input_buf,x
        inx
        stx input_len
        lda #0
        sta input_buf,x
        lda #1
        sta ui_dirty
        lda #SFX_TYPE
        jsr sfx_play
l_it_out:
        rts
l_it_del:
        ldx input_len
        beq l_it_out
        dex
        stx input_len
        lda #0
        sta input_buf,x
        lda #1
        sta ui_dirty
        rts
l_it_return:
        lda time_prompt         ; CTRL-T: a time for the clock
        beq +
        lda input_len
        beq l_it_cancel
        jsr set_time_typed
        bra l_it_cancel
+       lda input_len
        beq l_it_out
        jsr parse_command
l_it_cancel:
        lda #0
        sta time_prompt
        sta input_len
        sta input_buf
        lda #1
        sta ui_dirty
        rts

;---------------------------------------------------------------------------------------
; CTRL keys: gifts and actions (as in the original).
;---------------------------------------------------------------------------------------
ctrl_key:
        clc
        adc #'a' - 1
        cmp #'f'
        bne +
        jmp gift_food
+       cmp #'w'
        bne +
        jmp gift_water
+       cmp #'d'
        bne +
        jmp gift_dogfood
+       cmp #'b'
        bne +
        jmp gift_book
+       cmp #'r'
        bne +
        jmp gift_record
+       cmp #'p'
        bne +
        jmp pet_him
+       cmp #'c'
        bne +
        jmp phone_call
+       cmp #'a'
        bne +
        jmp alarm_ring
+       cmp #'t'
        bne +
        jmp time_ask
+       rts

;---------------------------------------------------------------------------------------
; CTRL-T: set the clock. The command line asks for a time ("9:30pm", "7am",
; "21:15"); RETURN sets it, ESC (or CTRL-T again) leaves it as it was.
;---------------------------------------------------------------------------------------
time_ask:
        lda time_prompt
        eor #1
        sta time_prompt
        lda #0
        sta input_len
        sta input_buf
        lda #1
        sta ui_dirty
        rts
l_time_q:       .null "Set the time: "

set_time_typed:
        ldx #0
        jsr l_st_skip
        jsr l_st_num            ; the hour
        bcc l_st_bad
        sta l_st_h
        lda #0
        sta l_st_m
        lda input_buf,x         ; :minutes (or .minutes)
        cmp #':'
        beq +
        cmp #'.'
        bne l_st_ampm
+       inx
        jsr l_st_num
        bcc l_st_bad
        cmp #60
        bcs l_st_bad
        sta l_st_m
l_st_ampm:
        jsr l_st_skip
        lda input_buf,x         ; am / pm, or a 24-hour time
        beq l_st_24
        ora #$20
        cmp #'a'
        beq l_st_am
        cmp #'p'
        bne l_st_bad
        lda l_st_h              ; pm: 1-12 -> 13-23 (12 stays noon)
        beq l_st_bad
        cmp #13
        bcs l_st_bad
        cmp #12
        beq l_st_set
        clc
        adc #12
        bra l_st_seth
l_st_am:
        lda l_st_h              ; am: 12 -> midnight
        beq l_st_bad
        cmp #13
        bcs l_st_bad
        cmp #12
        bne l_st_set
        lda #0
        bra l_st_seth
l_st_24:
        lda l_st_h
        cmp #24
        bcs l_st_bad
        bra l_st_set
l_st_seth:
        sta l_st_h
l_st_set:
        lda l_st_h
        sta clock_hour
        lda l_st_m
        sta clock_min
        lda #0                  ; (the new minute starts now)
        sta sp_count
        sta sp_count+1
        sta rt_secs
        jsr lights_update       ; day or night, and the office clock
        jsr clock_hands
        lda #1
        sta ui_dirty
        rts
l_st_bad:
        jsr sb_clear
        ldx #<l_say_badtime_t
        ldy #>l_say_badtime_t
        jsr sb_strxy
        jmp ui_say_sb
l_say_badtime_t: .null "That's not a time. Try 7:30pm or 21:30."
; X = position: past any spaces
l_st_skip:
        lda input_buf,x
        cmp #' '
        bne +
        inx
        bra l_st_skip
+       rts
; X = position: up to two digits -> A (C = 1 if there were any)
l_st_num:
        lda #0
        sta l_st_v
        ldy #0
-       lda input_buf,x
        cmp #'0'
        bcc l_stn_end
        cmp #'9' + 1
        bcs l_stn_end
        sec
        sbc #'0'
        pha
        lda l_st_v              ; v * 10 + digit
        asl
        sta l_st_v
        asl
        asl
        clc
        adc l_st_v
        sta l_st_v
        pla
        clc
        adc l_st_v
        sta l_st_v
        inx
        iny
        cpy #2
        bne -
l_stn_end:
        cpy #1
        lda l_st_v
        rts
l_st_h:         .byte 0
l_st_m:         .byte 0
l_st_v:         .byte 0

;---------------------------------------------------------------------------------------
; Parser. Lower-cases the line, notes "please", then finds the first keyword
; from the table (table order = priority).
;---------------------------------------------------------------------------------------
cmd_polite:     .byte 0
l_pc_tab         = ZTMP

parse_command:
        ; lower case in place
        ldx #0
-       lda input_buf,x
        cmp #'A'
        bcc +
        cmp #'Z'+1
        bcs +
        ora #$20
        sta input_buf,x
+       inx
        cpx input_len
        bcc -
        jsr knock_reply         ; answering his knock?
        bcc +
        rts
+       lda #<kw_please
        sta ZPTR2
        lda #>kw_please
        sta ZPTR2+1
        jsr find_word
        lda #0
        rol
        sta cmd_polite
        ; keyword table
        lda #<keyword_table
        sta l_pc_tab
        lda #>keyword_table
        sta l_pc_tab+1
l_pc_next:
        ldy #0
        lda (l_pc_tab),y
        bne +
        ; nothing matched
        ldx #<say_huh
        ldy #>say_huh
        jmp ui_say
+       sta ZPTR2
        iny
        lda (l_pc_tab),y
        sta ZPTR2+1
        jsr find_word
        bcs l_pc_hit
        clc
        lda l_pc_tab
        adc #3
        sta l_pc_tab
        bcc l_pc_next
        inc l_pc_tab+1
        bra l_pc_next
l_pc_hit:
        ldy #2
        lda (l_pc_tab),y
        jmp request_activity

; Is the zero-terminated keyword at ZPTR2 a whole word (or phrase) in
; input_buf? It must start and end on word boundaries, so "read" does not
; match "bread" and "eat" does not match "great". C = found.
find_word:
        ldx #0
l_fw_start:
        lda input_buf,x
        beq l_fw_no
        cpx #0
        beq l_fw_try
        lda input_buf-1,x       ; mid-word? not a candidate start
        jsr is_letter
        bcs l_fw_next
l_fw_try:
        stx l_fw_pos
        ldy #0
l_fw_cmp:
        lda (ZPTR2),y
        beq l_fw_end
        cmp input_buf,x
        bne l_fw_back
        inx
        iny
        bra l_fw_cmp
l_fw_end:
        lda input_buf,x         ; the word must end here too
        jsr is_letter
        bcc l_fw_yes
l_fw_back:
        ldx l_fw_pos
l_fw_next:
        inx
        bra l_fw_start
l_fw_yes:
        sec
        rts
l_fw_no:
        clc
        rts

; C = 1 if A is a lower-case letter
is_letter:
        cmp #'a'
        bcc +
        cmp #'z' + 1
        bcs ++
        sec
        rts
+       clc
        rts
+       clc
        rts
l_fw_pos: .byte 0

KW .macro text, req
        .word kwt
        .byte \req
        .section kwtext
kwt:    .null \text
        .send kwtext
.endmacro

kw_please:      .null "please"
say_huh:        .null "Huh? I don't understand."

keyword_table:
        #KW "hello", REQ_HELLO
        #KW "hi", REQ_HELLO
        #KW "hey", REQ_HELLO
        #KW "how are", REQ_HOWAREYOU
        #KW "ping pong", REQ_PINGPONG  ; (before "joey": "ping pong with Joey")
        #KW "pingpong", REQ_PINGPONG
        #KW "table tennis", REQ_PINGPONG
        #KW "invite", REQ_INVITE       ; (after the greetings, before "phone": "invite Joey",
        #KW "joey", REQ_INVITE         ;  "call Joey", "ask a friend over",
        #KW "friend", REQ_INVITE       ;  "have some company")
        #KW "company", REQ_INVITE
        #KW "fetch", REQ_FETCH         ; (before "pet", "dog", "play")
        #KW "play ball", REQ_FETCH
        #KW "throw ball", REQ_FETCH
        #KW "throw the ball", REQ_FETCH
        #KW "ball", REQ_FETCH
        #KW "play with the dog", REQ_FETCH
        #KW "feed", REQ_FEEDDOG
        #KW "pet", REQ_PETDOG
        #KW "piano", REQ_PIANO
        #KW "walk the dog", REQ_DOGWALK   ; (before "walk" and "dog")
        #KW "walk dog", REQ_DOGWALK
        #KW "dog for a walk", REQ_DOGWALK
        #KW "walkies", REQ_DOGWALK
        #KW "stop vacuuming", REQ_VACSTOP   ; (before "stop")
        #KW "stop the vacuum", REQ_VACSTOP
        #KW "stop vacuum", REQ_VACSTOP
        #KW "stop the record", REQ_RECSTOP  ; (before "stop" and "record")
        #KW "stop the music", REQ_RECSTOP
        #KW "stop record", REQ_RECSTOP
        #KW "stop music", REQ_RECSTOP
        #KW "stop", REQ_STOP        ; (whatever he's doing)
        #KW "record", REQ_RECORD
        #KW "records", REQ_RECORD
        #KW "stereo", REQ_RECORD
        #KW "music", REQ_RECORD
        #KW "dance", REQ_DANCE
        #KW "dancing", REQ_DANCE
        #KW "tv", REQ_TV
        #KW "television", REQ_TV
        #KW "letter", REQ_LETTER
        #KW "write", REQ_LETTER
        #KW "typewriter", REQ_LETTER
        #KW "solitaire", REQ_POOL
        #KW "card", REQ_CARDS
        #KW "cards", REQ_CARDS
        #KW "poker", REQ_CARDS
        #KW "blackjack", REQ_CARDS
        #KW "game", REQ_CARDS
        #KW "games", REQ_CARDS
        #KW "computer", REQ_COMPUTER
        #KW "program", REQ_COMPUTER
        #KW "read", REQ_READ
        #KW "reading", REQ_READ
        #KW "book", REQ_READ
        #KW "books", REQ_READ
        #KW "teeth", REQ_BRUSH
        #KW "brush", REQ_BRUSH
        #KW "toilet", REQ_WC
        #KW "bathroom", REQ_WC
        #KW "bath", REQ_BATH
        #KW "shower", REQ_BATH
        #KW "wash", REQ_BATH
        #KW "drink", REQ_DRINK
        #KW "water", REQ_DRINK
        #KW "thirsty", REQ_DRINK
        #KW "eat", REQ_EAT
        #KW "food", REQ_EAT
        #KW "hungry", REQ_EAT
        #KW "lunch", REQ_EAT
        #KW "dinner", REQ_EAT
        #KW "breakfast", REQ_EAT
        #KW "sleep", REQ_SLEEP
        #KW "bed", REQ_SLEEP
        #KW "nap", REQ_SLEEP
        #KW "exercise", REQ_EXERCISE
        #KW "jump", REQ_EXERCISE
        #KW "fire", REQ_FIRE
        #KW "fireplace", REQ_FIRE
        #KW "phone", REQ_PHONE
        #KW "clothes", REQ_CHANGE
        #KW "dress", REQ_CHANGE
        #KW "dressed", REQ_CHANGE
        #KW "change", REQ_CHANGE
        #KW "out", REQ_GOOUT
        #KW "outside", REQ_GOOUT
        #KW "walk", REQ_GOOUT
        #KW "file", REQ_FILES
        #KW "files", REQ_FILES
        #KW "filing", REQ_FILES
        #KW "cabinet", REQ_FILES
        #KW "dog", REQ_PETDOG
        #KW "thank", REQ_THANKS
        #KW "thanks", REQ_THANKS
        #KW "love", REQ_THANKS
        .word 0

        .dsection kwtext
