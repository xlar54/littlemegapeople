; acts/living.asm -- activities: the living room: phone, reading, relaxing, files, the fire, going out, knocking, chatting

; --- living room -----------------------------------------------------------------------
; On the phone (as in the Amiga original): in the armchair facing you, the
; handset to his ear, the phone on the side table showing its empty cradle.
; He chatters in his own language -- the sampled voice from the original --
; mouth moving with it, pauses to listen, chatters again.
phone_talk:     .byte 0     ; 1 = mouth open this moment
phone_spells:   .byte 0

st_phone:
        #POSE SPR_PHONE0, POSE_CHAIR_X, POSE_CHAIR_Y
        jsr phone_ring_off      ; (picked up: in his hand now)
        ldx #PATCH_PHONE
        jsr patch_apply
        lda #0
        sta phone_talk
        sta phone_spells
        lda #14
        jmp set_timer_secs
tk_phone:
        jsr talk_level
        bcs l_tkp_talking
        ; quiet: listen for a moment, then chatter again (twice per call)
        lda #0
        sta phone_talk
        lda p_anim
        and #63
        bne l_tkp_pose
        lda phone_spells
        cmp #2
        bcs l_tkp_pose
        inc phone_spells
        jsr talk_play
        bra l_tkp_pose
l_tkp_talking:
        ldx #0                  ; lip sync: mouth open on the loud bits
        cmp #24
        bcc +
        ldx #1
+       stx phone_talk
l_tkp_pose:
        lda #<SPR_PHONE0
        ldx #>SPR_PHONE0
        ldy phone_talk
        beq +
        lda #<SPR_PHONE1
        ldx #>SPR_PHONE1
+       sta pose_spr
        stx pose_spr+1
        lda act_phase
        bne +
        inc act_phase
        jsr sb_clear
        jsr sb_lcp
        ldx #<l_say_hello1
        ldy #>l_say_hello1
        jsr sb_strxy
        jsr sb_player
        ldx #<l_say_hello2
        ldy #>l_say_hello2
        jsr sb_strxy
        jmp ui_say_sb
+       rts
; Ringing someone up himself: handset up, he dials (beep beep...), then a
; chat as when you call him.
call_t:         .byte 0
call_lines:     .word l_call1, l_call2, l_call3, l_call4, l_call5
        .section ftext
l_call1:        .null ": Hello, Mom? It's me!"
        .send ftext
        .section ftext
l_call2:        .null ": Hi! Just calling to say hello."
        .send ftext
        .section ftext
l_call3:        .null ": Hello, is that the library? About my book..."
        .send ftext
        .section ftext
l_call4:        .null ": Hey, buddy! Long time no talk!"
        .send ftext
        .section ftext
l_call5:        .null ": Hello? Is your refrigerator running?"
        .send ftext
st_phonecall:
        jsr st_phone
        lda #1                  ; (not answering: no "nice of you to call")
        sta act_phase
        lda #2                  ; (and he does the talking when he's ready)
        sta phone_spells
        lda #0
        sta call_t
        rts
tk_phonecall:
        lda call_t
        cmp #110
        bcs l_tpc_talk
        inc call_t
        lda call_t
        and #7                  ; dialling: a beep every few frames...
        bne +
        lda call_t
        cmp #80                 ; ...seven digits
        bcs +
        lda #SFX_BLIP
        jsr sfx_play
+       lda call_t
        cmp #110                ; they pick up: he talks
        bne +
        jsr friend_invite       ; (or it's his friend, and he's coming over)
        bcs l_tpc_said
        lda #5
        jsr rnd_range
        asl
        tax
        lda call_lines,x
        pha
        lda call_lines+1,x
        sta l_tpc_p+1
        pla
        sta l_tpc_p
l_tpc_said:
        jsr sb_clear
        jsr sb_lcp
        ldx l_tpc_p
        ldy l_tpc_p+1
        jsr sb_strxy
        jsr ui_say_sb
        lda #0
        sta phone_spells
        jsr talk_play
+       rts
l_tpc_talk:
        jmp tk_phone
l_tpc_p:        .word 0

; The phone ringing on its own, a few times a day (9am-9pm, every 2 1/2 -
; 4 1/2 hours): it rings till he gets to it, he answers -- "Hello?" -- and
; it's his friend (who may come over), Mom, a telemarketer, a wrong number...
phone_cd:       .byte (AUTOPHONE != 0) ? 1 : 90     ; minutes till it might ring
phone_rt:       .byte 0     ; frames till it rings again (while he gets there)
phone_who:      .byte 0
PHONE_WHO_N     = 6
phone_minute:
        lda phone_cd
        beq +
        dec phone_cd
        rts
+       lda clock_hour
        cmp #9
        bcc l_pm_later
        cmp #21
        bcs l_pm_later
        jsr phone_can_ring
        bcc l_pm_later
        lda #120                ; (the next one in 2 1/2 - 4 1/2 hours)
        jsr rnd_range
        clc
        adc #150
        sta phone_cd
        lda #0
        sta lonely
        lda #150
        sta phone_rt
        lda #SFX_PHONE
        jsr sfx_play
        lda #A_PHONEIN
        jsr request_pending
        ldx #<l_say_ring
        ldy #>l_say_ring
        jmp ui_note
l_pm_later:
        lda #10                 ; (not now: try again in a bit)
        sta phone_cd
        rts

; C = 1: he's about, and free enough to get the phone.
phone_no:       .byte A_SLEEP, A_BATH, A_WC, A_GOOUT, A_PHONE, A_PHONECALL
                .byte A_CALLFRIEND, A_PHONEIN, A_DELIVERY, A_STOW, A_GREET
                .byte A_SEEOFF, A_INTRO, A_CHAT, A_ASKWATER, A_KNOCK, A_ARRIVE
                .byte A_PINGPONG, A_CARDS, A_CARDSF, A_LETTER, A_WALKOUT
PHONE_NO_N      = * - phone_no
phone_can_ring:
        jsr person_sleeping
        bcs l_pcr_no
        lda walk_stage
        ora p_pending
        bne l_pcr_no
        lda p_mode
        cmp #PM_HIDDEN
        beq l_pcr_no
        ldx #PHONE_NO_N - 1
-       lda phone_no,x
        cmp p_act
        beq l_pcr_no
        cmp p_goal
        beq l_pcr_no
        dex
        bpl -
        sec
        rts
l_pcr_no:
        clc
        rts

; Every frame: still ringing while he's on his way to it (your call, or one
; out of the blue), the handset jumping about over the phone.
phone_ringing:  .byte 0
phone_ring_tick:
        lda p_pending
        jsr l_prt_is
        beq l_prt_ring
        lda p_goal
        jsr l_prt_is
        bne l_prt_off
        lda p_state
        cmp #PS_ACT
        beq l_prt_off
        cmp #PS_IDLE
        beq l_prt_off
l_prt_ring:
        lda phone_ringing
        bne +
        lda #1
        sta phone_ringing
        ldx #PATCH_PHONERING    ; (off its cradle: the sprite has it)
        jsr patch_apply
+       dec phone_rt
        bne l_prt_out
        lda #150
        sta phone_rt
        lda #SFX_PHONE
        jmp sfx_play
l_prt_off:
        lda #150
        sta phone_rt
        jmp phone_ring_off
l_prt_out:
        rts
; Z = 1: A is answering the phone
l_prt_is:
        cmp #A_PHONEIN
        beq +
        cmp #A_PHONE
+       rts
; not ringing (any more): the handset back on the cradle
phone_ring_off:
        lda phone_ringing
        beq +
        lda #0
        sta phone_ringing
        ldx #PATCH_PHONERING
        jmp patch_remove
+       rts

; Drawing the ringing handset (actor 4: his sleeping head's, and he's up):
; tipped / then \, hopping a pixel, over the cradle.
PHONE_HS_X      = 195
PHONE_HS_Y      = 168
phone_sprite:
        lda phone_ringing
        beq +
        lda #1
        sta act_vis+4
        #SETACT 4, SPR_HANDSET
        lda #<PHONE_HS_X
        sta act_xl2+4
        lda #>PHONE_HS_X
        sta act_xh2+4
        lda frame_count         ; which way, every 4 frames
        lsr
        lsr
        and #1
        sta act_flip+4
        eor #1                  ; (and up a pixel on one of them)
        clc
        adc #PHONE_HS_Y - 1
        sta act_y+4
+       rts

st_phonein:
        jsr st_phone
        lda #1                  ; (no "nice of you to call")
        sta act_phase
        lda #2                  ; (he talks when there's someone to talk to)
        sta phone_spells
        lda #0
        sta call_t
        lda #PHONE_WHO_N        ; who is it?
        jsr rnd_range
        .if AUTOPHONE > 1
        lda #AUTOPHONE - 2
        .endif
        sta phone_who
        rts
tk_phonein:
        lda call_t
        cmp #120
        bcs l_tpi_talk
        inc call_t
        lda call_t
        cmp #20                 ; picked up: "Hello?"
        bne +
        ldx #<l_pin_hello
        ldy #>l_pin_hello
        jsr l_pin_say
        bra l_tpi_talk
+       cmp #120                ; and who it is
        bne l_tpi_talk
        jsr phonein_who
        jsr l_pin_say
l_tpi_talk:
        jmp tk_phone
; X/Y = his line (": ..."): said, his voice with it
l_pin_say:
        stx l_tpc_p
        sty l_tpc_p+1
        jsr sb_clear
        jsr sb_lcp
        ldx l_tpc_p
        ldy l_tpc_p+1
        jsr sb_strxy
        jsr ui_say_sb
        jmp talk_play

; Who's calling (phone_who): X/Y = what he says. Joey may come over; the
; telemarketers spoil his mood a little; some calls are over quickly.
phonein_who:
        lda phone_who
        bne l_pw_1
        lda fr_state            ; Joey: coming over (if he can), or a chat
        bne l_pw_chat
        lda clock_hour
        cmp #18
        bcs l_pw_chat
        lda health
        cmp #40
        bcc l_pw_chat
        lda #1
        sta fr_force
        jsr friend_invite
        ldx #<l_pin_joey
        ldy #>l_pin_joey
        bra l_pw_long
l_pw_chat:
        ldx #<l_pin_joeychat
        ldy #>l_pin_joeychat
        bra l_pw_long
l_pw_1:
        cmp #1
        bne l_pw_2
        ldx #<l_pin_mom
        ldy #>l_pin_mom
l_pw_long:
        lda #0                  ; (a good chat)
        sta phone_spells
        lda #10
        jmp l_pw_secs
l_pw_2:
        cmp #4
        bcs l_pw_short
        tax                     ; 2, 3: telemarketers -- no thank you!
        lda #10
        jsr mood_down
        ldy #>l_pin_sell1
        ldx #<l_pin_sell1
        lda phone_who
        cmp #2
        beq l_pw_brief
        ldy #>l_pin_sell2
        ldx #<l_pin_sell2
        bra l_pw_brief
l_pw_short:
        bne +                   ; 4: a wrong number
        ldx #<l_pin_wrong
        ldy #>l_pin_wrong
        bra l_pw_brief
+       ldx #<l_pin_hungup      ; 5: nobody there
        ldy #>l_pin_hungup
l_pw_brief:
        lda #4                  ; (over quickly)
l_pw_secs:
        phx
        phy
        jsr set_timer_secs
        ply
        plx
        rts
        .section ftext
l_pin_hello:    .null ": Hello?"
l_pin_joey:     .null ": Oh, hi Joey! Sure, come on over!"
l_pin_joeychat: .null ": Hey Joey! Yeah, I'm good. You?"
l_pin_mom:      .null ": Hi Mom! Yes, I'm eating well."
l_pin_sell1:    .null ": A new vacuum? No thank you!"
l_pin_sell2:    .null ": A free cruise? No thanks!"
l_pin_wrong:    .null ": Pizza? Sorry, wrong number."
l_pin_hungup:   .null ": Hello? ...Hello? They hung up."
        .send ftext

en_phone:
        jsr talk_stop
        ldx #PATCH_PHONE        ; handset back on the phone
        jsr patch_remove
        lda #8
        jsr mood_up
        lda #0
        sta lonely
        rts
; Reading: pick a book off the study shelf (facing it), then down to the
; armchair with it, turning a page every few seconds.
BOOK_X          = POSE_CHAIR_X + 1
BOOK_Y          = POSE_CHAIR_Y + 10
book_page:      .byte 0     ; ticks left showing the page turning over

READ_CLOSE      = 6             ; he steps up this close to the bookcase
st_read:
        lda #PM_BEND            ; bent over the shelf, looking for a good one
        sta p_mode
        lda p_y
        sec
        sbc #READ_CLOSE
        sta p_y
        lda #114 - READ_CLOSE   ; hands along the bottom shelf
        jsr hands_rummage
        lda #3
        jmp set_timer_secs
en_read:
        lda #FLOOR1_Y           ; back out from the shelf
        sta p_y
        lda #HELD_BOOK          ; the book in his hand, to the armchair
        sta held
        lda #SFX_CLACK
        jsr sfx_play
        lda #A_READCHAIR
        sta p_pending
        rts
st_readchair:
        lda #0                  ; (open in his lap now)
        sta held
        #POSE SPR_READING, POSE_CHAIR_X, POSE_CHAIR_Y
        lda #5                  ; the open book
        sta fx_kind
        lda #0
        sta book_page
        lda #20
        jmp set_timer_secs
tk_readchair:
        ; his head turns from one page to the other and back
        lda #<SPR_READING
        ldx #>SPR_READING
        ldy p_anim
        cpy #128
        bcc +
        lda #<SPR_READING2
        ldx #>SPR_READING2
+       sta pose_spr
        stx pose_spr+1
        lda book_page
        beq +
        dec book_page
        rts
+       lda p_anim              ; done with the right-hand page: turn over
        bne +
        lda #4
        jsr rnd_range
        beq +                   ; now and then he lingers on a page
        lda #10
        sta book_page
        lda #SFX_STEP           ; soft paper flick
        jsr sfx_play
+       rts
en_readchair:
        lda #4
        jmp mood_up

; The morning paper: out of the front door for it (it's on the step), bend,
; and back in with it to the armchair; then a read, the day's news out loud
; now and then -- a minute or so.
paper_done:     .byte 0     ; 1 = had today's
paper_on:       .byte 0     ; 1 = it's the paper in his hands, not a book
paper_t:        .byte 0
news_t:         .word 0
news_n:         .byte 0     ; the next item
news_left:      .byte 0
NEWS_EVERY      = 600       ; frames between items (12 s)
st_paperget:
        lda #1
        sta paper_done
        ldx #PATCH_DOOR
        jsr patch_apply
        lda #SFX_DOOR
        jsr sfx_play
        lda #0
        sta paper_t
        lda #1
        sta p_flip              ; facing out of the door
        lda #3
        jmp set_timer_secs
tk_paperget:
        inc paper_t
        lda paper_t
        cmp #30                 ; bend down for it
        bne +
        lda #PM_BENDSIDE
        sta p_mode
        rts
+       cmp #80                 ; got it: straighten up, in his hand
        bne +
        lda #PM_STAND
        sta p_mode
        lda #HELD_PAPER
        sta held
        lda #SFX_STEP
        jmp sfx_play
+       cmp #110
        bne +
        ldx #PATCH_DOOR         ; shut the door
        jmp patch_remove
+       rts
en_paperget:
        ldx #PATCH_DOOR
        jsr patch_remove
        lda held
        cmp #HELD_PAPER
        bne +
        lda #A_PAPERREAD        ; and a sit down with it
        sta p_pending
+       rts

; the paper on the step till he picks it up (actor 4: he's up)
paper_step_sprite:
        lda p_act
        cmp #A_PAPERGET
        bne +
        lda p_state
        cmp #PS_ACT
        bne +
        lda held
        bne +
        lda #1
        sta act_vis+4
        #SETACT 4, SPR_HELDPAPER
        lda #0
        sta act_flip+4
        clc
        lda p_x
        adc #5
        sta act_xl2+4
        lda p_x+1
        adc #0
        sta act_xh2+4
        lda p_y
        sec
        sbc #6
        sta act_y+4
+       rts

st_paperread:
        lda #1
        sta paper_on
        lda #NEWS_COUNT         ; today's news, from somewhere in the list
        jsr rnd_range
        sta news_n
        lda #5
        sta news_left
        lda #<(NEWS_EVERY - 150) ; (the first in a few seconds)
        sta news_t
        lda #>(NEWS_EVERY - 150)
        sta news_t+1
        jsr st_readchair
        lda #65
        jmp set_timer_secs
tk_paperread:
        jsr tk_readchair        ; reading, the pages turning
        inc news_t
        bne +
        inc news_t+1
+       lda news_t
        cmp #<NEWS_EVERY
        bne l_tpr_out
        lda news_t+1
        cmp #>NEWS_EVERY
        bne l_tpr_out
        lda #0
        sta news_t
        sta news_t+1
        lda news_left
        beq l_tpr_out
        dec news_left
        lda news_n              ; the next item of news
        asl
        tax
        lda news_lines+1,x
        tay
        lda news_lines,x
        tax
        jsr ui_say
        jsr speak
        inc news_n
        lda news_n
        cmp #NEWS_COUNT
        bcc l_tpr_out
        lda #0
        sta news_n
l_tpr_out:
        rts
en_paperread:
        lda #0
        sta paper_on
        lda #3
        jmp mood_up
news_lines:     .word l_news0, l_news1, l_news2, l_news3, l_news4, l_news5
                .word l_news6, l_news7, l_news8, l_news9
NEWS_COUNT      = 10        ; (items in news_lines)
        .section ftext
l_news0:        .null "It says it'll rain tomorrow."
l_news1:        .null "The town fair is this weekend!"
l_news2:        .null "Our team won again last night!"
l_news3:        .null "Gas prices are up again. Typical."
l_news4:        .null "A cat got stuck up a tree again."
l_news5:        .null "The new mall opens on Monday."
l_news6:        .null "Ooh, a sale on records at Stan's!"
l_news7:        .null "The mayor wants a new park. Nice!"
l_news8:        .null "Hmm, a new diner opened downtown."
l_news9:        .null "Ha! Look at this comic strip."
nm_paperget:    .null " is fetching the newspaper."
nm_paperread:   .null " is reading the newspaper."
        .send ftext

; Relaxing in the armchair: sat back, hands behind his head, no book; his
; head turns now and then, and (half the time) a remark as he settles in.
relax_says:     .word l_say_relax1, l_say_relax2, l_say_relax3
        .section ftext
l_say_relax1:   .null "What a nice day."
        .send ftext
        .section ftext
l_say_relax2:   .null "Ahh, this is the life."
        .send ftext
        .section ftext
l_say_relax3:   .null "Time to put my feet up."
        .send ftext
st_relax:
        #POSE SPR_CHAIR, POSE_CHAIR_X, POSE_CHAIR_Y
        jsr rnd
        and #1
        beq +
        lda #3
        jsr rnd_range
        asl
        tax
        lda relax_says+1,x
        tay
        lda relax_says,x
        tax
        jsr ui_say
        jsr speak
+       lda #20
        jmp set_timer_secs
tk_relax:
        lda p_anim              ; every couple of seconds, maybe a look round
        and #127
        bne +
        jsr rnd
        and #1
        beq +
        lda pose_spr
        ldx pose_spr+1
        cmp #<SPR_CHAIR
        bne l_tkr_front
        cpx #>SPR_CHAIR
        bne l_tkr_front
        lda #<SPR_CHAIR2
        ldx #>SPR_CHAIR2
        bra l_tkr_set
l_tkr_front:
        lda #<SPR_CHAIR
        ldx #>SPR_CHAIR
l_tkr_set:
        sta pose_spr
        stx pose_spr+1
+       rts
en_relax:
        lda #3
        jmp mood_up

; Filing cabinet: bend over, pull the top drawer out (it grows towards you),
; rummage, push it shut (thunk), stand up.
files_t:        .byte 0

st_files:
        lda #PM_BEND
        sta p_mode
        lda #0
        sta files_t
        lda #6
        jmp set_timer_secs
tk_files:
        lda files_t
        cmp #255
        beq +
        inc files_t
+       lda files_t
        cmp #20
        bne +
        lda #SFX_DOOR
        jsr sfx_play
        lda #1
        jmp drawer_set
+       cmp #28
        bne +
        lda #2
        jmp drawer_set
+       cmp #34                 ; hands into the open drawer
        bne +
        lda #49
        jmp hands_rummage
+       cmp #60
        bcc l_tkf_end
        lda p_anim              ; rummaging: paper rustles
        and #31
        bne l_tkf_end
        lda #SFX_STEP
        jsr sfx_play
l_tkf_end:
        ; closing in the last second, then he stands up
        lda act_timer+1
        bne l_tkf_out
        lda act_timer
        cmp #50
        bne +
        lda #0                  ; hands out, drawer in
        sta fx_kind
        lda #1
        jmp drawer_set
+       cmp #42
        bne +
        lda #SFX_SHUT           ; thunk-click
        jsr sfx_play
        lda #0
        jmp drawer_set
+       cmp #25
        bne l_tkf_out
        lda #PM_STAND
        sta p_mode
l_tkf_out:
        rts
en_files:
        lda #0
        jsr drawer_set
        lda #2
        jmp mood_up

; A = 0 shut, 1 half out, 2 all the way out
drawer_set:
        sta l_ds_level
        lda #0
        sta patch_state + PATCH_DRAWER1
        lda #1
        sta patch_state + PATCH_DRAWER2
        ldx #PATCH_DRAWER2
        jsr patch_remove
        lda l_ds_level
        beq +
        clc
        adc #PATCH_DRAWER1 - 1
        tax
        jsr patch_apply
+       rts
l_ds_level: .byte 0
; Lighting the fire: in front of the fireplace with his back to you, bent
; down, hands busy (the bend frames alternate); then it catches.
st_fire:
        lda #PM_BEND
        sta p_mode
        lda #4
        jmp set_timer_secs
en_fire:
        ldx #PATCH_FIRE
        jsr patch_apply
        lda #120
        sta fire_time
        lda #3
        jsr mood_up
        #SAY l_say_cozy
        rts
; Going out: out through the front door like the dog walks (into the
; doorway and behind the open door, which clicks shut), back the same way.
st_goout:
        jmp st_walkout
tk_goout:
        jmp tk_walkout
st_goout_old:
        ldx #PATCH_DOOR
        jsr patch_apply
        lda #SFX_DOOR
        jsr sfx_play
        lda #<1200
        sta act_timer
        lda #>1200
        sta act_timer+1
        rts
tk_goout_old:
        ; phase 0: step out, close door; phase 1: away; last second: door opens
        lda act_phase
        bne +
        lda act_timer+1
        cmp #>1150
        bcs ++
        lda #PM_HIDDEN
        sta p_mode
        ldx #PATCH_DOOR
        jsr patch_remove
        inc act_phase
+       lda act_phase
        cmp #1
        bne +
        lda act_timer+1
        bne +
        lda act_timer
        cmp #40
        bcs +
        ldx #PATCH_DOOR
        jsr patch_apply
        lda #SFX_DOOR
        jsr sfx_play
        inc act_phase
+       rts
en_goout:
        lda #PM_STAND
        sta p_mode
        ldx #PATCH_DOOR
        jsr patch_remove
        lda #FLOOR0_Y           ; back on the floor
        sta p_y
        lda #0
        sta dog_up
        lda #3
        jsr mood_up
        #SAY l_say_back
        rts
st_arrive:
        ldx #PATCH_DOOR
        jsr patch_apply
        lda #SFX_DOOR
        jsr sfx_play
        lda #PM_HIDDEN
        sta p_mode
        lda #2
        jmp set_timer_secs
tk_arrive:
        rts
en_arrive:
        lda #PM_STAND
        sta p_mode
        ldx #PATCH_DOOR
        jsr patch_remove
        jsr sb_clear
        ldx #<l_say_arr1
        ldy #>l_say_arr1
        jsr sb_strxy
        jsr sb_player
        ldx #<l_say_arr2
        ldy #>l_say_arr2
        jsr sb_strxy
        jsr sb_lcp
        lda #'!'
        jsr sb_char
        jsr ui_say_sb
        jsr dog_arrive
        lda #A_IDLE
        sta p_pending
        rts
; Knocking on the screen: he turns to face you, reaches out, and taps on the
; inside of the glass three times (his fist grows as it nears the glass, tink!),
; then talks to you. Ticks: 0-19 reach out, 20-115 three taps, then he speaks.
KNOCK_TAPS_START = 20
KNOCK_TAP_LEN    = 32
KNOCK_TALK       = KNOCK_TAPS_START + 3 * KNOCK_TAP_LEN
knock_t:        .byte 0
knock_wait:     .byte 0     ; game minutes he waits for your answer
knock_invite:   .byte 0     ; 1 = he asked you to play poker
fist_size:      .byte 0
fist_sizes:     .byte 0, 1, 2, 3, 3, 2, 1, 0
knock_x:        .byte 150, 110, 120

st_knock:
        lda #PM_FRONT
        sta p_mode
        lda #0
        sta knock_t
        sta fist_size
        lda #4
        sta fx_kind
        lda #6
        jmp set_timer_secs
tk_knock:
        lda knock_t
        cmp #KNOCK_TALK
        beq l_tk_talk
        bcs l_tk_out
        inc knock_t
        cmp #KNOCK_TAPS_START
        bcc l_tk_out
        sec
        sbc #KNOCK_TAPS_START
-       cmp #KNOCK_TAP_LEN
        bcc +
        sbc #KNOCK_TAP_LEN
        bra -
+       cmp #12
        bne +
        pha
        lda #SFX_TINK
        jsr sfx_play
        pla
+       lsr
        lsr
        tax
        lda fist_sizes,x
        sta fist_size
l_tk_out:
        rts
l_tk_talk:
        inc knock_t
        jsr fx_clear
        jsr rnd
        and #1
        beq +
        jsr speak                ; ...and says it out loud
+
        lda #30
        sta knock_wait
        lda #0
        sta knock_invite
        lda #3
        jsr rnd_range
        sta l_tk_pick
        cmp #2
        bne +
        lda #1
        sta knock_invite
+       jsr sb_clear
        lda #<l_say_knock1
        ldx l_tk_pick
        beq +
        lda #<l_say_knock2
        cpx #1
        beq +
        lda #<l_say_knock3
+       pha
        lda #>l_say_knock1
        ldx l_tk_pick
        beq +
        lda #>l_say_knock2
        cpx #1
        beq +
        lda #>l_say_knock3
+       tay
        plx
        jsr sb_strxy
        jsr sb_player
        lda #'!'
        jsr sb_char
        lda health              ; sick: no games, just how he feels
        cmp #40
        bcs l_tk_well
        lda #0
        sta knock_invite
        ldx #<l_say_ksick
        ldy #>l_say_ksick
        jmp l_tk_line
l_tk_well:
        ldx l_tk_pick
        beq +
        ldx #<l_say_knock4
        ldy #>l_say_knock4
        lda l_tk_pick
        cmp #2
        bne ++
        ldx #<l_say_knock5
        ldy #>l_say_knock5
+
+
l_tk_line:
        jsr sb_strxy
        jmp ui_say_sb
        .section ftext
l_say_ksick: .null " I feel so sick... send food?"
        .send ftext
en_knock:
        lda #100
        sta lonely
        jmp talk_stop

; Now and then he comes to the front, faces you and chats (in his own
; language, with the words on the top line).
st_chat:
        lda #PM_FRONT
        sta p_mode
        jsr speak
        lda health              ; sick: how he's feeling
        cmp #40
        bcs l_ch_well
        lda #4
        jsr rnd_range
        asl
        tax
        lda chat_sick,x
        sta l_ch_p
        lda chat_sick+1,x
        sta l_ch_p+1
        bra l_ch_said
l_ch_well:
        lda #8
        jsr rnd_range
        asl
        tax
        lda chat_lines,x
        sta l_ch_p
        lda chat_lines+1,x
        sta l_ch_p+1
l_ch_said:
        jsr sb_clear
        jsr sb_lcp
        lda #':'
        jsr sb_char
        lda #' '
        jsr sb_char
        ; expand @ in the line to your name
        ldy #0
-       lda (l_ch_p),y
        beq ++
        cmp #'@'
        bne +
        phy
        jsr sb_player
        ply
        iny
        bra -
+       phy
        jsr sb_char
        ply
        iny
        bra -
+       jsr ui_say_sb
        lda #0
        sta lonely
        lda #3                  ; about half his voice clip; en_chat cuts it off
        jmp set_timer_secs
en_chat:
        jsr talk_stop
        lda #2
        jmp mood_up
l_ch_p = ZPTR2

chat_lines:
        .word chl0, chl1, chl2, chl3, chl4, chl5, chl6, chl7
chl0:   .null "Hi @! Just saying hello."
chl1:   .null "Nice day, isn't it, @?"
chl2:   .null "The dog snores, you know."
chl3:   .null "I wonder what's for dinner."
chl4:   .null "Thanks for the company, @!"
chl5:   .null "I just love this house."
chl6:   .null "Do you ever get bored out there?"
chl7:   .null "Hey @, you look nice today!"
chat_sick:
        .word chs0, chs1, chs2, chs3
chs0:   .null "Ugh, @... I feel awful."
chs1:   .null "Tummy's rumbling, @. Any food?"
chs2:   .null "I'm all green and wobbly..."
chs3:   .null "Please look after me, @."

; Talk out loud: start his voice; actors_build moves his mouth with it.
speaking:       .byte 0
mouth_open:     .byte 0
speak:
        lda #1
        sta speaking
        jmp talk_play

; once per frame: mouth follows the loudness of his voice
lip_sync:
        lda #0
        sta mouth_open
        lda speaking
        beq l_ls_out
        jsr talk_level
        bcs +
        lda #0
        sta speaking
        rts
+       cmp #24
        bcc l_ls_out
        lda #1
        sta mouth_open
l_ls_out:
        rts
l_tk_pick: .byte 0
        .section ftext
l_say_knock1: .null "Hey! Anybody out there? Hello, "
        .send ftext
        .section ftext
l_say_knock2: .null "Psst! Psst! "
        .send ftext
        .section ftext
l_say_knock3: .null "Knock knock, "
        .send ftext
        .section ftext
l_say_knock4: .null " I'm bored. Talk to me?"
        .send ftext
        .section ftext
l_say_knock5: .null " Wanna play poker? (YES?)"
        .send ftext

; Called by the parser before keywords: answers to his knock.
knock_reply:
        lda knock_wait
        beq l_kr_no
        lda #<kw_yes
        sta ZPTR2
        lda #>kw_yes
        sta ZPTR2+1
        jsr find_word
        bcs l_kr_yes
        lda #<kw_sure
        sta ZPTR2
        lda #>kw_sure
        sta ZPTR2+1
        jsr find_word
        bcs l_kr_yes
        lda #<kw_ok
        sta ZPTR2
        lda #>kw_ok
        sta ZPTR2+1
        jsr find_word
        bcs l_kr_yes
        lda #<kw_okay
        sta ZPTR2
        lda #>kw_okay
        sta ZPTR2+1
        jsr find_word
        bcs l_kr_yes
        lda #<kw_yeah
        sta ZPTR2
        lda #>kw_yeah
        sta ZPTR2+1
        jsr find_word
        bcs l_kr_yes
l_kr_no:
        clc
        rts
l_kr_yes:
        lda #0
        sta knock_wait
        sta lonely
        lda #8
        jsr mood_up
        lda knock_invite
        beq +
        ldx #<l_say_deal
        ldy #>l_say_deal
        jsr ui_say
        lda #A_CARDS
        jsr request_pending
        sec
        rts
+       ldx #<l_say_there
        ldy #>l_say_there
        jsr ui_say
        sec
        rts
kw_yes:  .null "yes"
kw_sure: .null "sure"
kw_ok:   .null "ok"
kw_okay: .null "okay"
kw_yeah: .null "yeah"
        .section ftext
l_say_deal:  .null "Great! I'll deal!"
        .send ftext
        .section ftext
l_say_there: .null "Oh good, you ARE there!" 
        .send ftext
; Petting the dog: beside it, leaning down, his hand stroking it; it stays
; put, sits up facing him and wags; a happy bark when he's done.
pet_wig:        .byte 0     ; 1: his hand's at the end of a stroke
st_petdog:
        lda #PM_BENDSIDE
        sta p_mode
        lda #0                  ; (the dog's to his left)
        sta p_flip
        sta pet_wig
        lda #1
        sta dog_hold            ; it stays put...
        sta dog_petted          ; ...sitting up for it
        sta dog_flip            ; ...facing him
        jsr fx_heart_on_dog     ; hearts over its head
        lda #4
        jmp set_timer_secs
tk_petdog:
        lda p_anim              ; a stroke every 12 frames or so
        and #15
        bne +
        lda pet_wig
        eor #1
        sta pet_wig
+       rts
en_petdog:
        jsr fx_clear
        lda #0
        sta dog_hold
        sta dog_petted
        sta pet_wig
        lda #PM_STAND
        sta p_mode
        lda #3
        jsr mood_up
        jmp bark_play

; Fetch: in the middle of the living room the dog trots up to him; he throws
; the ball (it arcs across the floor and bounces), the dog races after it,
; brings it back in its mouth, drops it at his feet and sits up wagging; he
; picks it up and throws again -- three times. The dog's held (dog_hold)
; and moved from here throughout.
FE_THROWS       = 3
FE_WAIT_DX      = 18        ; the dog waits this far in front of him
fe_ph:          .byte 0     ; 0 dog to him, 1 aim, 2 the throw, 3 back, 4 picked up
fe_t:           .byte 0
fe_n:           .byte 0     ; throws so far
ball_vis:       .byte 0
ball_x:         .word 0
ball_y:         .byte 0
ball_free:      .byte 0     ; 1 = on the floor, not in anyone's hand or mouth
BALL_FLOOR      = DOG_Y - 5 ; (top of the ball, resting on the floor)
; the throw, frame by frame: how far it goes (left) and how high it is --
; flying at 4px a frame, two bounces, then rolling to a stop
fe_dx:  .byte 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4
        .byte 3, 3, 3, 3, 3, 3, 3, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2
        .byte 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
fe_h:   .byte 19, 23, 26, 29, 32, 33, 35, 35, 35, 35, 34, 32, 30, 28, 24, 21, 16, 11, 6, 0
        .byte 3, 6, 8, 8, 6, 3, 0, 2, 3, 2, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
FE_ROLL_N       = * - fe_h

; C = 1: the dog's free for a game (downstairs, about, not eating, begging,
; out or on the lead)
fetch_ok:
        lda dog_floor
        bne l_fok_no
        lda dog_state
        cmp #1
        beq +
        cmp #2
        bne l_fok_no
+       lda dog_lead
        ora dog_out
        ora dog_beg
        bne l_fok_no
        sec
        rts
l_fok_no:
        clc
        rts

; C = 1: the dog's free for a game but not down here with him (on another
; floor, or on the stairs): he'll whistle it down first
fetch_away:
        lda dog_lead
        ora dog_out
        ora dog_beg
        bne l_faw_no
        lda dog_state
        cmp #5
        beq l_faw_yes
        cmp #1
        beq +
        cmp #2
        bne l_faw_no
+       lda dog_floor
        beq l_faw_no
l_faw_yes:
        sec
        rts
l_faw_no:
        clc
        rts

; A = what he's chosen (or you asked for): fetch only if the dog's up for it;
; with it away upstairs he whistles it down first, then the game
fe_called:      .byte 0     ; 1 = whistled it down for a game
fetch_filter:
        cmp #A_FETCH
        bne l_ff_out
        lda fe_called           ; (whistled for already: the game, or nothing)
        bne l_ff_try
        jsr fetch_away
        bcc l_ff_try
        lda #1
        sta fe_called
        lda #A_WHISTLE
        rts
l_ff_try:
        lda #0
        sta fe_called
        jsr fetch_ok
        bcc l_ff_no
        lda #1                  ; on: the dog stays put downstairs while he
        sta dog_hold            ;  comes to it (not off up the stairs)
        lda #2
        sta dog_state
        lda #A_FETCH
        rts
l_ff_no:
        lda #A_IDLE
l_ff_out:
        rts

; the ball in his hand (facing left: out in front of him)
fe_ball_hand:
        sec
        lda p_x
        sbc #11
        sta ball_x
        lda p_x+1
        sbc #0
        sta ball_x+1
        lda p_y
        sec
        sbc #17
        sta ball_y
        lda #0
        sta ball_free
        lda #1
        sta ball_vis
        rts

; A = speed: the dog runs towards X/Y (its x); C = 1 when it's there
fe_dog_to:
        sta l_fdt_v
        stx l_fdt_x
        sty l_fdt_x+1
        lda #1
        sta dog_state
        ldy l_fdt_v
-       lda dog_x+1
        cmp l_fdt_x+1
        bne +
        lda dog_x
        cmp l_fdt_x
        beq l_fdt_there
+       lda dog_x
        cmp l_fdt_x
        lda dog_x+1
        sbc l_fdt_x+1
        bcs l_fdt_left
        lda #1
        sta dog_flip
        inc dog_x
        bne +
        inc dog_x+1
+       dey
        bne -
        clc
        rts
l_fdt_left:
        lda #0
        sta dog_flip
        lda dog_x
        bne +
        dec dog_x+1
+       dec dog_x
        dey
        bne -
        clc
        rts
l_fdt_there:
        sec
        rts
l_fdt_v:        .byte 0
l_fdt_x:        .word 0

st_fetch:
        lda #PM_STAND
        sta p_mode
        lda #0                  ; (throwing to the left, across the room)
        sta p_flip
        sta fe_ph
        sta fe_t
        sta fe_n
        sta dog_petted
        lda #1
        sta dog_hold
        jsr fe_ball_hand
        lda #60
        jmp set_timer_secs
tk_fetch:
        ldx fe_ph
        bne l_tkfe_1
        ; 0: the dog trots up to wait in front of him
        sec
        lda p_x
        sbc #FE_WAIT_DX
        tax
        lda p_x+1
        sbc #0
        tay
        lda #1
        jsr fe_dog_to
        bcc l_tkfe_out
        lda #2                  ; there: sits, facing the way he'll throw
        sta dog_state
        lda #0
        sta dog_flip
        sta fe_t
        inc fe_ph
l_tkfe_out:
        rts
l_tkfe_1:
        cpx #1
        bne l_tkfe_2
        ; 1: ready... then the throw
        inc fe_t
        lda fe_t
        cmp #2
        bne +
        lda fe_n
        bne l_tkfe_out
        #SAY l_say_fetch
        rts
+       cmp #70
        bne l_tkfe_out
        lda #PM_BENDSIDE        ; the throw
        sta p_mode
        lda #0
        sta fe_t
        inc fe_ph
        lda #SFX_BLIP
        jmp sfx_play
l_tkfe_2:
        cpx #2
        bne l_tkfe_3
        ; 2: the ball flies (twice the dog's speed), bounces twice and rolls
        ; to a stop; the dog chases it and grabs it once it's still
        lda fe_t
        cmp #8
        bne +
        lda #PM_STAND           ; (arm down again)
        sta p_mode
+       ldx fe_t
        cpx #FE_ROLL_N
        bcs l_tkfe_landed
        inc fe_t
        lda ball_x              ; along by this frame's step...
        sec
        sbc fe_dx,x
        sta ball_x
        bcs +
        dec ball_x+1
+       lda #BALL_FLOOR         ; ...at this frame's height
        sec
        sbc fe_h,x
        sta ball_y
        cpx #19                 ; (a tink as it hits the floor)
        beq l_tkfe_tink
        cpx #26
        beq l_tkfe_tink
        cpx #30
        bne l_tkfe_chase
l_tkfe_tink:
        lda #SFX_TINK
        jsr sfx_play
        bra l_tkfe_chase
l_tkfe_landed:
        lda #1
        sta ball_free
l_tkfe_chase:
        lda fe_t                ; (off after it almost at once)
        cmp #4
        bcc l_tkfe_out2
        lda ball_x              ; to the ball as it is now (its nose at it)
        clc
        adc #6
        tax
        lda ball_x+1
        adc #0
        tay
        lda #2
        jsr fe_dog_to
        bcc l_tkfe_out2
        lda ball_free           ; got it (once it's stopped)
        beq l_tkfe_out2
        lda #0
        sta ball_free
        lda #SFX_STEP
        jsr sfx_play
        inc fe_ph
l_tkfe_out2:
        rts
l_tkfe_3:
        cpx #3
        bne l_tkfe_4
        ; 3: back to him with it in its mouth
        sec
        lda p_x
        sbc #FE_WAIT_DX
        tax
        lda p_x+1
        sbc #0
        tay
        lda #2
        jsr fe_dog_to
        php
        jsr fe_ball_mouth
        plp
        bcc l_tkfe_out2
        lda #1                  ; dropped at his feet: sits up wagging, a bark
        sta dog_flip
        sta dog_petted
        sta ball_free
        sec
        lda p_x
        sbc #10
        sta ball_x
        lda p_x+1
        sbc #0
        sta ball_x+1
        lda #BALL_FLOOR
        sta ball_y
        lda #0
        sta fe_t
        inc fe_ph
        jmp bark_play
l_tkfe_4:
        ; 4: he bends for it, and it's in his hand again; again, or done
        inc fe_t
        lda fe_t
        cmp #40
        bne +
        lda #PM_BENDSIDE
        sta p_mode
        rts
+       cmp #60
        bne l_tkfe_out2
        lda #PM_STAND
        sta p_mode
        jsr fe_ball_hand
        lda #0
        sta dog_petted
        sta dog_flip
        lda #2
        sta dog_state
        lda #0
        sta fe_t
        lda #1
        sta fe_ph
        inc fe_n
        lda fe_n
        cmp #FE_THROWS
        bcc l_tkfe_out2
        lda #0                  ; that's three: a good boy, and done
        sta act_timer
        sta act_timer+1
        #SAY l_say_goodfetch
        rts
; the ball in its mouth, at the front of its head (it faces him: right)
fe_ball_mouth:
        clc
        lda dog_x
        adc #7
        sta ball_x
        lda dog_x+1
        adc #0
        sta ball_x+1
        lda dog_yb
        sec
        sbc #11
        sta ball_y
        rts
en_fetch:
        lda #0
        sta ball_vis
        sta dog_hold
        sta dog_petted
        lda #2                  ; (a rest, then off it goes)
        sta dog_state
        lda #120
        sta dog_timer
        lda #PM_STAND
        sta p_mode
        lda #4
        jmp mood_up
        .section ftext
l_say_fetch:    .null "Ready, boy? Fetch!"
l_say_goodfetch: .null "Good boy! What a catch!"
nm_fetch:       .null " is playing fetch with the dog."
        .send ftext

; Drawing the ball (actor 11): the dog's, or a ping pong ball.
ball_sprite:
        lda ball_vis
        sta act_vis+11
        beq ++
        #SETACT 11, SPR_BALL
        lda p_act
        cmp #A_PINGPONG
        bne +
        #SETACT 11, SPR_PPBALL
+
        lda ball_x
        sta act_xl2+11
        lda ball_x+1
        sta act_xh2+11
        lda ball_y
        sta act_y+11
        lda #0
        sta act_flip+11
+       rts
