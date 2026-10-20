;=======================================================================================
; Keyboard: the MEGA65 typing queue ($D610), the typed command line, CTRL gifts,
; and the keyword parser that turns "please play the piano" into a request.
;=======================================================================================

INPUT_MAX       = 36

input_buf:      .fill INPUT_MAX + 1, 0
input_len:      .byte 0

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
        cmp #KEY_DEL
        beq l_it_del
        cmp #KEY_F1
        bne +
        jmp help_show
+       cmp #KEY_F5
        bne +
        lda fast_forward
        eor #1
        sta fast_forward
        lda #1
        sta ui_dirty
        rts
+       cmp #KEY_F7
        bne +
        lda #1
        sta quit_request
        rts
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
        lda input_len
        beq l_it_out
        jsr parse_command
        lda #0
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
+       rts

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
        #KW "feed", REQ_FEEDDOG
        #KW "pet", REQ_PETDOG
        #KW "piano", REQ_PIANO
        #KW "walk the dog", REQ_DOGWALK   ; (before "walk" and "dog")
        #KW "walk dog", REQ_DOGWALK
        #KW "dog for a walk", REQ_DOGWALK
        #KW "walkies", REQ_DOGWALK
        #KW "stop", REQ_RECSTOP     ; (before "record": "stop the record")
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
