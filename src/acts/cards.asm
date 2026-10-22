; acts/cards.asm -- activities: card games at the kitchen table

; Card games at the kitchen table: sitting where he eats, cards laid out in
; front of him.
TABLECARDS_X    = 106
TABLECARDS_Y    = 180

st_pool:
        #POSE SPR_EATSHUT, POSE_EAT_X, POSE_EAT_Y
        lda #9                  ; the cards on the table
        sta fx_kind
        lda #12
        jmp set_timer_secs
tk_pool:
        lda p_anim
        and #63
        bne +
        lda #SFX_CLACK
        jsr sfx_play
+       rts
en_pool:
        lda #3
        jmp mood_up
st_cards:
        #POSE SPR_EATSHUT, POSE_EAT_X, POSE_EAT_Y
        lda #9
        sta fx_kind
        lda #1
        jmp set_timer_secs
en_cards:
        jmp ovl_cards_play

        .section ftext
l_say_yum:     .null "Mmm, that hit the spot!"
        .send ftext
        .section ftext
l_say_goodboy: .null "Here you go, boy!"
        .send ftext
        .section ftext
l_say_hello1:  .null ": Hello? Oh, hi "
        .send ftext
        .section ftext
l_say_hello2:  .null "! Nice of you to call."
        .send ftext
        .section ftext
l_say_cozy:    .null "Nice and cozy."
        .send ftext
        .section ftext
l_say_back:    .null "I'm back! Lovely day out there."
        .send ftext
        .section ftext
l_say_arr1:    .null "Hi "
        .send ftext
        .section ftext
l_say_arr2:    .null "! Nice house! I'm "
        .send ftext
l_say_knock:   .null "KNOCK KNOCK! Hello? Anybody out there?"
        .section ftext
l_say_clean:   .null "Ahh, squeaky clean!"
        .send ftext


