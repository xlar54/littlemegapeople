; sim/brain.asm -- The activity tables and his brain (what to do next) (part of the simulation; included after sim/sim.asm)
;---------------------------------------------------------------------------------------
; Activity table
;---------------------------------------------------------------------------------------
;               floor  x     face(1=right)
; The activity tables, filled in by #ACT (sim/activities.asm)
act_floor:      .dsection s_act_floor
act_xl:         .dsection s_act_xl
act_xh:         .dsection s_act_xh
act_face:       .dsection s_act_face
act_start_tbl:  .dsection s_act_start
act_tick_tbl:   .dsection s_act_tick
act_end_tbl:    .dsection s_act_end
act_names:      .dsection s_act_names
        .section ftext
nm_none:     .null " is pottering about."
        .send ftext
        .section ftext
nm_fridge:   .null " is getting some food."
        .send ftext
        .section ftext
nm_meal:     .null " is eating."
        .send ftext
        .section ftext
nm_drink:    .null " is having a drink."
        .send ftext
        .section ftext
nm_feeddog:  .null " is feeding the dog."
        .send ftext
        .section ftext
nm_phone:    .null " is on the phone."
        .send ftext
        .section ftext
nm_read:     .null " is picking out a book."
        .send ftext
        .section ftext
nm_readchair: .null " is reading a book."
        .send ftext
        .section ftext
nm_files:    .null " is rummaging in the filing cabinet."
        .send ftext
        .section ftext
nm_chat:     .null " is talking to you."
        .send ftext
        .section ftext
nm_tvoff:    .null " is switching off the TV."
        .send ftext
        .section ftext
nm_wash:     .null " is washing his hands."
        .send ftext
        .section ftext
nm_delivery: .null " is answering the door."
        .send ftext
        .section ftext
nm_stow:     .null " is putting the delivery away."
        .send ftext
        .section ftext
nm_askwater: .null " is asking you for water."
        .send ftext
        .section ftext
nm_vacuum:   .null " is vacuuming."
        .send ftext
        .section ftext
nm_dogwalk:  .null " is taking the dog for a walk."
        .send ftext
        .section ftext
nm_recstop:  .null " is stopping the record."
        .send ftext
        .section ftext
nm_dishes:   .null " is washing the dishes."
        .send ftext
        .section ftext
nm_phonecall: .null " is making a phone call."
        .send ftext
        .section ftext
nm_whistle:  .null " is whistling for the dog."
        .send ftext
        .section ftext
nm_greet:    .null " is letting Joey in."
        .send ftext
        .section ftext
nm_seeoff:   .null " is seeing Joey out."
        .send ftext
        .section ftext
nm_cardsf:   .null " is playing cards with Joey."
        .send ftext
        .section ftext
nm_watchvg:  .null " is playing video games with Joey."
        .send ftext
        .section ftext
nm_intro:    .null " is introducing his friend."
        .send ftext
        .section ftext
nm_relax:    .null " is relaxing in his armchair."
        .send ftext
        .section ftext
nm_getfood:  .null " is fetching something to cook."
        .send ftext
        .section ftext
nm_prep:     .null " is getting a meal ready."
        .send ftext
        .section ftext
nm_cook:     .null " is cooking."
        .send ftext
        .section ftext
nm_stoveoff: .null " is taking the pot off the stove."
        .send ftext
        .section ftext
nm_serve:    .null " is dishing up."
        .send ftext
        .section ftext
nm_fire:     .null " is lighting a fire."
        .send ftext
        .section ftext
nm_goout:    .null " has gone out."
        .send ftext
        .section ftext
nm_sleep:    .null " is asleep. Zzz..."
        .send ftext
        .section ftext
nm_exercise: .null " is exercising."
        .send ftext
        .section ftext
nm_brush:    .null " is brushing his teeth."
        .send ftext
        .section ftext
nm_wc:       .null " is in the bathroom."
        .send ftext
        .section ftext
nm_bath:     .null " is taking a bath."
        .send ftext
        .section ftext
nm_computer: .null " is playing a video game."
        .send ftext
        .section ftext
nm_letter:   .null " is typing you a letter."
        .send ftext
        .section ftext
nm_tv:       .null " is watching TV."
        .send ftext
        .section ftext
nm_record:   .null " is listening to records."
        .send ftext
        .section ftext
nm_dance:    .null " is dancing."
        .send ftext
        .section ftext
nm_piano:    .null " is playing the piano."
        .send ftext
        .section ftext
nm_change:   .null " is changing clothes."
        .send ftext
        .section ftext
nm_pool:     .null " is playing solitaire."
        .send ftext
        .section ftext
nm_cards:    .null " wants to play cards."
        .send ftext
        .section ftext
nm_knock:    .null " is trying to get your attention!"
        .send ftext
        .section ftext
nm_petdog:   .null " is playing with the dog."
        .send ftext
        .section ftext
nm_arrive:   .null " is moving in!"
        .send ftext
        .section ftext
nm_walking:  .null " is walking around."
        .send ftext

; Fill sb with "<name> is doing X." for the speech row.
activity_describe:
        jsr sb_lcp
        lda p_state
        cmp #PS_ACT
        beq +
        lda p_goal
        cmp #A_IDLE
        beq l_ad_walk
        cmp #A_NONE
        bne ++
l_ad_walk:
        ldx #<nm_walking
        ldy #>nm_walking
        jmp sb_strxy
+       lda p_act
+       asl
        tax
        lda act_names,x
        pha
        lda act_names+1,x
        tay
        plx
        jmp sb_strxy

;---------------------------------------------------------------------------------------
; Brain: choose what to do next.
;---------------------------------------------------------------------------------------
ai_choose:
        ; urgent needs come first, even at bedtime
        lda thirst
        cmp #75
        bcc +
        jsr drink_go
        bcs l_ai_ret
+       lda cook_stage          ; (a meal on the way: no snacking)
        bne +
        lda hunger
        cmp #75
        bcc +
        lda food
        beq +
        lda #A_FRIDGE
        rts
+       ; a delivery on the doorstep?
        lda delivery
        beq +
        lda #A_STOW             ; in his hands: put it away
        ldx carrying
        bne l_pc_dlv
        lda #A_DELIVERY
l_pc_dlv:
        rts
+       ; an empty plate in his hands: to the sink with it
        lda held
        cmp #HELD_PLATEE
        bne +
        lda #A_DISHES
        rts
+       ; a drink under way: carry on with it
        ldx drink_stage
        lda drink_act,x
        bne l_ai_ret
        ; the vacuuming under way: carry on with it (fetching it first if
        ; he left it standing somewhere)
        lda vac_parked
        beq +
        lda #A_VACPICK
        rts
+       ldx vac_stage
        lda vac_act,x
        bne l_ai_ret
        ; a dog walk under way: carry on with it
        ldx walk_stage
        lda walk_act,x
        bne l_ai_ret
        ; whistled the dog down for a game: the game
        lda fe_called
        beq +
        lda #A_FETCH
        rts
+
        ; cooking: carry on with the next step
        ldx cook_stage
        lda cook_act,x
        beq +
l_ai_ret:
        rts
+       ; fresh out of the shower: get dressed before anything else
        lda outfit
        cmp #2
        bne +
        lda #A_CHANGE
        rts
+       ; bedtime: 9pm, 11pm on Friday and Saturday; up at 7 (8 at weekends)
        jsr bedtime_hour
        cmp clock_hour
        beq l_ai_bed
        bcc l_ai_bed
        jsr wake_hour
        cmp clock_hour
        beq +
        bcs l_ai_sleep
+       lda energy
        cmp #12
        bcc l_ai_sleep
        ; an afternoon nap now and then when he's tired
        lda clock_hour
        cmp #13
        bcc +
        cmp #17
        bcs +
        lda energy
        cmp #50
        bcs +
        lda #6
        jsr rnd_range
        bne +
l_ai_sleep:
        jsr night_extras        ; (woken in the night: a few things first)
        bcs l_ai_x
        lda #A_SLEEP
l_ai_x:
        rts
l_ai_bed:
        jsr night_extras
        bcs l_ai_x
        lda outfit              ; pyjamas on first
        cmp #1
        beq l_ai_sleep
        lda #A_CHANGE
        rts
+       lda health
        cmp #40
        bcs +
        jsr rnd
        and #1
        bne +
        lda #A_SLEEP            ; sick: lie down a lot (every other choice)
        rts
+       ; morning routine
        lda dress_todo
        beq +
        lda #0
        sta dress_todo
        lda #A_CHANGE
        rts
+       ; the toilet: on getting up, then every five hours or so
        lda wc_need
        cmp #WC_EVERY
        bcc +
        lda #A_WC
        rts
+       ; breakfast, lunch, dinner: cook a meal
        jsr meal_due
        bcc +
        lda food
        beq +
        lda #1
        sta cook_stage
        lda #A_GETFOOD
        rts
+       ; a shower every morning, once breakfast is done (and
        ; dressed after it: in his pyjamas till then, so before the dog's walk)
        lda showered
        bne +
        lda cook_stage
        bne +
        lda clock_hour
        cmp #12
        bcs +
        cmp #10                 ; (by ten, breakfast or not)
        bcs l_ai_shower
        lda meals_done
        and #1
        beq +
l_ai_shower:
        lda #1
        sta showered
        lda #A_BATH
        rts
+       ; walkies, three times a day (not when he's sick; in the morning not
        ; till he's showered and dressed)
        lda health
        cmp #40
        bcc +
        lda clock_hour
        cmp #12
        bcs l_ai_walk
        lda showered
        beq +
l_ai_walk:
        jsr dog_walk_due
        bcc +
        lda #1
        sta walk_stage
        lda #A_LEASH
        rts
+       ; the morning paper: once a day, some time before eleven (by ten for
        ; certain)
        lda paper_done
        bne +
        lda clock_hour
        cmp #11
        bcs +
        cmp #10
        bcs l_ai_paper
        lda #3
        jsr rnd_range
        bne +
l_ai_paper:
        lda #A_PAPERGET
        rts
+       ; thirst
        lda thirst
        cmp #40
        bcc l_ai_food
        jsr drink_go
        bcs l_ai_ret
l_ai_food:
        lda hunger
        cmp #50
        bcc l_ai_brush
        lda food
        beq +
        lda #A_FRIDGE
        rts
+       jsr complain_food
l_ai_brush:
        lda brush_todo
        beq l_ai_dog
        lda #0
        sta brush_todo
        lda #A_BRUSH
        rts
l_ai_dog:
        lda dog_beg             ; the dog's begging (or gave up): feed it
        ora dog_gaveup
        beq l_ai_lonely
        lda bowl_full
        bne l_ai_lonely
        lda #A_FEEDDOG          ; a can already in his hands
        ldx held
        cpx #HELD_CAN
        beq l_ai_feed
        lda dogfood
        beq +
        lda #A_DOGFOOD
l_ai_feed:
        rts
+       jsr complain_dogfood
l_ai_lonely:
        lda health              ; sick: he comes and knocks far more often
        cmp #40
        bcs +
        lda knock_cd
        bne l_ai_letter
        lda #30
        sta knock_cd
        lda #A_KNOCK
        rts
+       lda lonely
        cmp #150
        bcc l_ai_letter
        lda knock_cd
        bne l_ai_letter
        lda #90
        sta knock_cd
        lda #A_KNOCK
        rts
l_ai_letter:
        lda sleep_plea          ; a letter asking to be let sleep
        beq +
        lda #A_LETTER
        rts
+       lda letter_cd
        bne l_ai_fire
        lda #4
        jsr rnd_range
        bne l_ai_fire
        lda #A_LETTER
        rts
l_ai_fire:
        lda clock_hour
        cmp #18
        bcc l_ai_fun
        lda fire_time
        bne l_ai_fun
        lda #3
        jsr rnd_range
        bne l_ai_fun
        lda #A_FIRE
        rts
l_ai_fun:
        lda call_cd             ; ring somebody up (every 2.5-3.5 hours, 9-9)
        bne l_ai_nocall
        lda clock_hour
        cmp #9
        bcc l_ai_nocall
        cmp #21
        bcs l_ai_nocall
        lda #60
        jsr rnd_range
        clc
        adc #150
        sta call_cd
        lda #A_PHONECALL
        rts
l_ai_nocall:
        lda health              ; sick: he wants to talk to you
        cmp #40
        bcs +
        jsr rnd
        and #1
        beq +
        lda #A_CHAT
        rts
+       jsr weekend_evening     ; Friday / Saturday night: often the TV
        bcc +
        lda #2
        jsr rnd_range
        bne +
        lda #A_TV
        rts
+       lda #l_fun_count
        jsr rnd_range
        tax
        lda l_fun_list,x
        jsr sick_banned         ; too much for him when he's sick: lie down
        bcc +
        lda #A_SLEEP
        rts
+       cmp #A_DANCE
        bne +
        ldx record_left
        bne +
        ldx record_left+1
        bne +
        lda #A_RECORD
+       cmp #A_VACGET           ; vacuuming: rare, and once a day at most
        bne l_ai_funout
        ldx vac_done
        bne l_ai_nofun
        jsr rnd
        and #1
        bne l_ai_nofun
        lda #A_VACGET
        rts
l_ai_nofun:
        lda #A_IDLE
l_ai_funout:
        rts
; A = activity: C = 1 if he's sick and it's too much for him (A kept)
sick_banned:
        ldx health
        cpx #40
        bcs l_sb_ok
        ldx #l_sick_n - 1
-       cmp l_sick_no,x
        beq l_sb_no
        dex
        bpl -
l_sb_ok:
        clc
        rts
l_sb_no:
        sec
        rts
l_sick_no:
        .byte A_LEASH, A_WALKOUT, A_EXERCISE, A_COMPUTER, A_READ, A_READCHAIR
        .byte A_DANCE, A_PIANO, A_GOOUT, A_VACGET, A_FETCH
l_sick_n = * - l_sick_no

l_fun_list:
        .byte A_TV, A_TV, A_RECORD, A_PIANO, A_PIANO, A_READ, A_READ, A_COMPUTER
        .byte A_EXERCISE, A_POOL, A_READ, A_COMPUTER, A_IDLE, A_IDLE, A_IDLE, A_PETDOG
        .byte A_GOOUT, A_DANCE, A_IDLE, A_READ, A_CARDS, A_FILES, A_CHAT, A_VACGET
        .byte A_RELAX, A_RELAX, A_FETCH
l_fun_count = * - l_fun_list

complain_water:
        lda complain_cd
        bne +
        lda #40
        sta complain_cd
        lda #3
        jsr mood_down
        ldx #<say_thirsty
        ldy #>say_thirsty
        jmp ui_say
+       rts
complain_food:
        lda complain_cd
        bne +
        lda #40
        sta complain_cd
        lda #3
        jsr mood_down
        ldx #<say_hungry
        ldy #>say_hungry
        jmp ui_say
+       rts
complain_dogfood:
        lda complain_cd
        bne +
        lda #40
        sta complain_cd
        ldx #<say_nodogfood
        ldy #>say_nodogfood
        jmp ui_say
+       rts

        .section ftext
say_thirsty:   .null "I'm thirsty! Fill my bottle? (CTRL-W)"
        .send ftext
        .section ftext
say_hungry:    .null "No food left! Send some? (CTRL-F)"
        .send ftext
        .section ftext
say_nodogfood: .null "The dog's hungry. Dog food? (CTRL-D)"
        .send ftext

