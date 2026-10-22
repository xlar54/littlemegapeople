; sim/requests.asm -- Requests from the keyboard, gifts and CTRL actions (part of the simulation; included after sim/sim.asm)
;---------------------------------------------------------------------------------------
; Requests from the keyboard
;---------------------------------------------------------------------------------------
request_activity:
        sta l_ra_req
        lda #0
        sta lonely
        ; talk-only requests
        lda l_ra_req
        bpl l_ra_act
        cmp #REQ_HELLO
        bne +
        lda #2
        jsr mood_up
        jsr sb_clear
        jsr sb_lcp
        ldx #<l_say_hi1
        ldy #>l_say_hi1
        jsr sb_strxy
        jsr sb_player
        lda #'!'
        jsr sb_char
        jmp ui_say_sb
+       cmp #REQ_THANKS
        bne +
        lda #4
        jsr mood_up
        ldx #<l_say_welcome
        ldy #>l_say_welcome
        jmp ui_say
+       ; how are you
        ldx #<l_say_great
        ldy #>l_say_great
        lda health
        cmp #40
        bcs +
        ldx #<l_say_sick
        ldy #>l_say_sick
        jmp ui_say
+       lda hunger
        cmp #60
        bcc +
        ldx #<l_say_hungry2
        ldy #>l_say_hungry2
        jmp ui_say
+       lda thirst
        cmp #60
        bcc +
        ldx #<l_say_thirsty2
        ldy #>l_say_thirsty2
        jmp ui_say
+       lda energy
        cmp #25
        bcs +
        ldx #<l_say_tired
        ldy #>l_say_tired
        jmp ui_say
+       lda mood
        cmp #45
        bcs +
        ldx #<l_say_blue
        ldy #>l_say_blue
+       jmp ui_say

l_ra_act:
        ; asleep? only the alarm wakes him
        jsr person_sleeping
        bcc +
        ldx #<l_say_zzz
        ldy #>l_say_zzz
        jmp ui_note
+       lda p_act
        cmp #A_GOOUT
        bne +
        lda p_state
        cmp #PS_ACT
        bne +
        ldx #<l_say_out
        ldy #>l_say_out
        jmp ui_note
+       ; too ill for it? he comes and tells you how he feels instead
        lda l_ra_req
        jsr sick_banned
        bcc +
        lda #A_CHAT
        jmp request_pending
+       ; can he?
        lda l_ra_req
        cmp #A_FRIDGE
        bne +
        lda food
        bne +
        ldx #<say_hungry
        ldy #>say_hungry
        jmp ui_say
+       lda l_ra_req
        cmp #A_DRINK
        bne +
        lda water
        bne +
        ldx #<say_thirsty
        ldy #>say_thirsty
        jmp ui_say
+       lda l_ra_req
        cmp #A_FEEDDOG
        bne +
        lda dogfood
        bne +
        ldx #<say_nodogfood
        ldy #>say_nodogfood
        jmp ui_say
+       lda l_ra_req            ; "stop": whatever he's doing
        cmp #A_IDLE
        bne +
        jmp stop_doing
+       lda l_ra_req            ; "stop the record"
        cmp #A_RECSTOP
        bne +
        lda record_left
        ora record_left+1
        bne +
        ldx #<say_norecord
        ldy #>say_norecord
        jmp ui_say
+       lda l_ra_req            ; "stop vacuuming"
        cmp #A_VACPUT
        bne l_ra_fetch          ; (named: stop_doing sits in between)
        jsr vac_stop
        bcs l_ra_stopped
        ldx #<say_novac
        ldy #>say_novac
        jmp ui_say
l_ra_stopped:
        rts
        .section ftext
say_novac:      .null "I'm not vacuuming!"
        .send ftext

; "Stop!": he stops what he's doing. Dancing or listening to a record, that's
; the record off; vacuuming, the vacuum put away; out with the dog, not
; till they're home; otherwise he leaves off and potters about.
stop_doing:
        lda p_act               ; (the music he's at: off it goes)
        cmp #A_RECORD
        beq +
        cmp #A_DANCE
        bne l_sd_vac
+       lda record_left
        ora record_left+1
        beq l_sd_vac
        lda #A_RECSTOP
        jsr request_pending
        ldx #<say_stopok
        ldy #>say_stopok
        jmp ui_say
l_sd_vac:
        jsr vac_stop
        bcs l_ra_stopped
        lda walk_stage          ; (out with the dog: not in the middle of it)
        beq +
        ldx #<say_stopwalk
        ldy #>say_stopwalk
        jmp ui_say
+       lda p_state             ; doing nothing much anyway?
        cmp #PS_ACT
        beq +
        lda p_goal              ; (on his way to something)
        bra ++
+       lda p_act
+       cmp #A_IDLE
        beq l_sd_nothing
        cmp #A_NONE
        beq l_sd_nothing
        lda #A_IDLE
        jsr request_pending
        ldx #<say_stopok
        ldy #>say_stopok
        jmp ui_say
l_sd_nothing:
        ldx #<say_stopnone
        ldy #>say_stopnone
        jmp ui_say
        .section ftext
say_stopok:     .null "OK, I'll stop."
say_stopnone:   .null "I'm not doing anything!"
say_stopwalk:   .null "Not now, we're out for a walk!"
        .send ftext
l_ra_fetch:
        lda l_ra_req            ; ping pong: only with his friend here
        cmp #A_PINGPONG
        bne +
        lda fr_state
        cmp #FRS_VISIT
        beq +
        ldx #<say_nopong
        ldy #>say_nopong
        jmp ui_say
        .section ftext
say_nopong:     .null "I need someone to play with!"
        .send ftext
+       lda l_ra_req            ; fetch: only with the dog free (downstairs,
        cmp #A_FETCH            ;  or upstairs and he whistles it down)
        bne +
        jsr fetch_ok
        bcs +
        jsr fetch_away
        bcs +
        ldx #<l_say_nofetch
        ldy #>l_say_nofetch
        jmp ui_say
+       lda l_ra_req            ; asking Joey over: not if he's here, on his
        cmp #A_CALLFRIEND       ;  way, too late, or Larry's sick
        bne +
        jsr fr_can_invite
        bcs +
        jmp ui_say
+       ; late at night (past his bedtime, before his getting-up time) or worn
        ; out, he'll often be too tired -- though never too tired for bed,
        ; a bite or a drink
        lda l_ra_req
        cmp #A_SLEEP
        beq l_ra_awake
        cmp #A_FRIDGE
        beq l_ra_awake
        cmp #A_DRINK
        beq l_ra_awake
        lda energy
        cmp #15
        bcc l_ra_tired
        jsr bedtime_hour
        cmp clock_hour
        beq l_ra_tired
        bcc l_ra_tired
        jsr wake_hour
        cmp clock_hour
        beq l_ra_awake
        bcc l_ra_awake
l_ra_tired:
        lda #3                  ; two times in three
        jsr rnd_range
        beq l_ra_awake
        ldx #<say_tired
        ldy #>say_tired
        jmp ui_say
l_ra_awake:
        ; will he? mood/2 + random(50) + 25 if polite, -15 if not
        lda mood
        lsr
        sta l_ra_score
        lda #50
        jsr rnd_range
        clc
        adc l_ra_score
        sta l_ra_score
        lda cmd_polite
        beq l_ra_rude
        lda #1
        jsr mood_up
        clc
        lda l_ra_score
        adc #25
        bra l_ra_judge
l_ra_rude:
        lda #1
        jsr mood_down
        sec
        lda l_ra_score
        sbc #15
        bcs l_ra_judge
        lda #0
l_ra_judge:
        cmp #50
        bcs l_ra_yes
        lda cmd_polite
        bne +
        ldx #<l_say_please
        ldy #>l_say_please
        jmp ui_say
+       lda #3
        jsr rnd_range
        asl
        tax
        lda l_no_list,x
        pha
        lda l_no_list+1,x
        tay
        plx
        jmp ui_say
l_ra_yes:
        lda #3
        jsr rnd_range
        asl
        tax
        lda l_yes_list,x
        pha
        lda l_yes_list+1,x
        tay
        plx
        jsr ui_say
        lda l_ra_req
        jmp request_pending

l_ra_req:   .byte 0
l_ra_score: .byte 0
l_no_list:  .word l_say_no1, l_say_no2, l_say_no3
l_yes_list: .word l_say_yes1, l_say_yes2, l_say_yes3
        .section ftext
l_say_no1:  .null "I don't feel like it."
        .send ftext
        .section ftext
l_say_no2:  .null "Maybe later."
        .send ftext
        .section ftext
l_say_no3:  .null "Nah, not right now."
        .send ftext
        .section ftext
l_say_yes1: .null "OK!"
        .send ftext
        .section ftext
l_say_yes2: .null "Sure, good idea!"
        .send ftext
        .section ftext
l_say_yes3: .null "Alright, if you say so."
        .send ftext
        .section ftext
l_say_please: .null "Hey, what's the magic word?"
        .send ftext
        .section ftext
l_say_hi1:   .null ": Hi there, "
        .send ftext
        .section ftext
l_say_welcome: .null "Aw, you're welcome!"
        .send ftext
        .section ftext
l_say_great:  .null "I'm feeling great, thanks!"
        .send ftext
        .section ftext
l_say_sick:   .null "I don't feel so well..."
        .send ftext
        .section ftext
l_say_hungry2: .null "I'm really hungry."
        .send ftext
        .section ftext
l_say_thirsty2: .null "I could use a drink."
        .send ftext
        .section ftext
l_say_tired:  .null "I'm so tired..."
        .send ftext
        .section ftext
l_say_blue:   .null "I'm feeling kind of blue."
        .send ftext
        .section ftext
l_say_zzz:    .null "Zzzz... (he's asleep. CTRL-A rings the alarm)"
        .send ftext
        .section ftext
l_say_out:    .null "He's out right now."
        .send ftext

; C = 1 if he is asleep in bed
person_sleeping:
        lda p_act
        cmp #A_SLEEP
        bne +
        lda p_state
        cmp #PS_ACT
        bne +
        sec
        rts
+       clc
        rts

; A = position: a soft footstep every 8 pixels, if no other effect is playing.
footstep:
        and #7
        bne +
        lda sfx_id
        bne +
        lda #SFX_STEP
        jmp sfx_play
+       rts

; A = activity: stop what he is doing and do A next.
request_pending:
        pha
        jsr person_interrupt
        pla
        sta p_pending
        rts

; Stop what he is doing so the pending request runs next.
person_interrupt:
        lda p_state
        cmp #PS_ACT
        bne +
        jsr act_end
        lda #PS_IDLE
        sta p_state
        rts
+       cmp #PS_WALK
        bne +
        lda #PS_IDLE
        sta p_state
+       rts

;---------------------------------------------------------------------------------------
; Gifts and CTRL actions
;---------------------------------------------------------------------------------------
gift_food:
        lda #DLV_FOOD
        ldx #<l_say_gfood
        ldy #>l_say_gfood
        jmp deliver
gift_water:
        lda #9                  ; the bottle filled right up
        sta water
        lda #0
        sta dry_count
        lda gift_flags
        ora #8
        sta gift_flags
        lda #SFX_GLUG
        jsr sfx_play
        lda #1
        sta ui_dirty
        ldx #<l_say_gwater
        ldy #>l_say_gwater
        jmp ui_note
gift_dogfood:
        lda #DLV_DOG
        ldx #<l_say_gdog
        ldy #>l_say_gdog
        jmp deliver
gift_book:
        lda #DLV_BOOK
        ldx #<l_say_gbook
        ldy #>l_say_gbook
        jmp deliver
gift_record:
        lda #DLV_RECORD
        ldx #<l_say_grecord
        ldy #>l_say_grecord
        jmp deliver

; A = what arrived, X/Y = the message. Ding dong: he goes to the door unless
; he's asleep (then it waits on the step). One package at a time; anything
; else arriving meanwhile goes straight into the cupboard.
deliver:
        stx l_dv_msg
        sty l_dv_msg+1
        ldx delivery
        beq +
        jsr delivery_apply      ; already one waiting: just add this one
        bra l_dv_note
+       sta delivery
        jsr doorbell_play
        jsr person_sleeping
        bcc +
        jsr night_wake          ; (it gets him out of bed)
+       lda #A_DELIVERY
        jsr request_pending
l_dv_note:
        ldx l_dv_msg
        ldy l_dv_msg+1
        jmp ui_note
l_dv_msg: .word 0

pet_him:
        lda #0
        sta lonely
        jsr person_sleeping
        bcs l_ph_sleep
        lda p_mode
        cmp #PM_HIDDEN
        beq l_ph_out
        lda #3
        ldx p_act
        cpx #A_READCHAIR
        bne +
        lda #7
+       jsr mood_up
        jsr fx_heart_on_person
        ldx #<l_say_pet
        ldy #>l_say_pet
        jmp ui_say
l_ph_sleep:
        ldx #<l_say_zzz
        ldy #>l_say_zzz
        jmp ui_note
l_ph_out:
        rts
phone_call:
        lda #0
        sta lonely
        lda #150                ; (again in a moment, till he gets to it)
        sta phone_rt
        lda #SFX_PHONE
        jsr sfx_play
        jsr person_sleeping
        bcc l_pc_awake
        jsr night_wake          ; (it gets him out of bed)
        lda #A_PHONE
        jsr request_pending
        ldx #<l_say_ring3
        ldy #>l_say_ring3
        jmp ui_note
l_pc_awake:
        lda #A_PHONE
        jsr request_pending
        ldx #<l_say_ring
        ldy #>l_say_ring
        jmp ui_note
+       ldx #<l_say_ring2
        ldy #>l_say_ring2
        jmp ui_note
alarm_ring:
        jsr alarm_play
        lda #ALARM_TIME
        sta alarm_t
        jsr person_sleeping
        bcc +
        jsr night_wake
        jsr is_night
        bcc ++
        lda #12
        jsr mood_down
        ldx #<l_say_midnight
        ldy #>l_say_midnight
        jmp ui_say
+       rts
+       ldx #<l_say_morning
        ldy #>l_say_morning
        jmp ui_say

        .section ftext
l_say_gfood:   .null "Ding dong! Groceries at the door."
        .send ftext
        .section ftext
l_say_gwater:  .null "You topped up the water bottle."
        .send ftext
        .section ftext
l_say_gdog:    .null "Ding dong! Dog food at the door."
        .send ftext
        .section ftext
l_say_gbook:   .null "Ding dong! A parcel at the door."
        .send ftext
        .section ftext
l_say_grecord: .null "Ding dong! A parcel at the door."
        .send ftext
        .section ftext
l_say_pet:     .null "Hee hee, that tickles!"
        .send ftext
        .section ftext
l_say_ring:    .null "Ring ring! The phone is ringing."
        .send ftext
        .section ftext
l_say_ring2:   .null "Ring ring... he sleeps right through it."
        .send ftext
        .section ftext
l_say_ring3:   .null "Ring ring! He stumbles out of bed for it..."
        .send ftext
        .section ftext
say_tired:     .null "Yawn... sorry, I'm just too tired."
        .send ftext

; Woken up in the night (alarm, doorbell, phone): out of bed -- not dressing
; -- a bit grumpy; once he's seen to it maybe the bathroom, maybe some TV,
; then he wants his bed again.
night_wc:      .byte 0
night_trip:    .byte 0     ; tonight's hour to get up for the bathroom (0 none)
night_wakes:   .byte 0     ; times you woke him up tonight
sleep_plea:    .byte 0     ; 1 = he'll write asking to be let sleep

; The morning after: woken twice or more in the night, two times in three
; he writes to you about it today.
rest_plea_check:
        lda night_wakes
        cmp #2
        bcc +
        lda #3
        jsr rnd_range
        beq +
        lda #1
        sta sleep_plea
+       lda #0
        sta night_wakes
        rts
night_tv:      .byte 0
night_wake:
        jsr act_end
        lda #PS_IDLE
        sta p_state
        jsr is_night
        bcc l_nw_out
        lda night_wakes         ; (counted: too many and he'll say so)
        cmp #255
        beq +
        inc night_wakes
+
        lda #0                  ; (still pyjamas: no dressing)
        sta dress_todo
        lda #6
        jsr mood_down
        lda #1                  ; the bathroom, always
        sta night_wc
        lda #3                  ; a time in three, some TV
        jsr rnd_range
        cmp #0
        bne l_nw_out
        lda #1
        sta night_tv
l_nw_out:
        rts
; C = 1, A = what: the little extras before going back to bed
night_extras:
        lda night_wc
        beq l_nx_tv
        lda #0
        sta night_wc
        lda #A_WC
        sec
        rts
l_nx_tv:
        lda night_tv
        beq l_nx_no
        lda #0
        sta night_tv
        lda #A_TV
        sec
        rts
l_nx_no:
        clc
        rts
        .section ftext
l_say_midnight: .null "Hey! It's the middle of the night!"
        .send ftext
        .section ftext
l_say_morning: .null "Yawn... good morning!"
        .send ftext

; The alarm clock rattling on the bedside table while it rings (two pictures
; of it a pixel left and right, swapped every few frames).
ALARM_TIME      = 100
alarm_t:        .byte 0
alarm_tick:
        lda alarm_t
        beq l_alt_out
        dec alarm_t
        beq l_alt_stop
        and #4
        beq +
        ldx #PATCH_ALARM + 1
        jsr patch_remove
        ldx #PATCH_ALARM
        jmp patch_apply
+       ldx #PATCH_ALARM
        jsr patch_remove
        ldx #PATCH_ALARM + 1
        jmp patch_apply
l_alt_stop:
        ldx #PATCH_ALARM
        jsr patch_remove
        ldx #PATCH_ALARM + 1
        jmp patch_remove
l_alt_out:
        rts

; Turning down a request at the wrong hour (any request can use it).
        .section ftext
l_say_badtime:  .null "Not the best time right now."
        .send ftext
        .section ftext
l_say_nofetch:  .null "The dog's not up for it now."
        .send ftext
