;=======================================================================================
; The simulation: clock, needs, the little person's brain and body, the dog, and the
; actor renderer.
;
; Coordinates are native 320x200 pixels. The person's position is his feet
; (p_x = centre column, p_y = bottom row). Floors: 0 ground, 1 middle, 2 attic.
;=======================================================================================

FLOOR0_Y        = 186
FLOOR1_Y        = 123
FLOOR2_Y        = 63
DOG_Y           = 189

TICKS_PER_MIN   = 25        ; sim ticks per game minute (50 ticks per second)

; person states
PS_IDLE         = 0
PS_WALK         = 1
PS_CLIMB        = 2
PS_ACT          = 3

; person drawing modes
PM_HIDDEN       = 0
PM_WALK         = 1
PM_STAND        = 2
PM_POSE         = 3
PM_CLIMB        = 4
PM_JUMP         = 5
PM_DANCE        = 6
PM_FRONT        = 7         ; facing out of the screen
PM_DOWNSTEP     = 8         ; coming down a front step block, facing you

; activities (also request ids)
A_NONE          = 0
A_FRIDGE        = 1
A_MEAL          = 2
A_DRINK         = 3
A_FEEDDOG       = 4
A_PHONE         = 5
A_READ          = 6
A_FIRE          = 7
A_GOOUT         = 8
A_SLEEP         = 9
A_EXERCISE      = 10
A_BRUSH         = 11
A_WC            = 12
A_BATH          = 13
A_COMPUTER      = 14
A_LETTER        = 15
A_TV            = 16
A_RECORD        = 17
A_DANCE         = 18
A_PIANO         = 19
A_CHANGE        = 20
A_POOL          = 21
A_CARDS         = 22
A_KNOCK         = 23
A_IDLE          = 24
A_PETDOG        = 25
A_ARRIVE        = 26
A_COUNT         = 27

REQ_EAT         = A_FRIDGE
REQ_DRINK       = A_DRINK
REQ_FEEDDOG     = A_FEEDDOG
REQ_PHONE       = A_PHONE
REQ_READ        = A_READ
REQ_FIRE        = A_FIRE
REQ_GOOUT       = A_GOOUT
REQ_SLEEP       = A_SLEEP
REQ_EXERCISE    = A_EXERCISE
REQ_BRUSH       = A_BRUSH
REQ_WC          = A_WC
REQ_BATH        = A_BATH
REQ_COMPUTER    = A_COMPUTER
REQ_LETTER      = A_LETTER
REQ_TV          = A_TV
REQ_RECORD      = A_RECORD
REQ_DANCE       = A_DANCE
REQ_PIANO       = A_PIANO
REQ_CHANGE      = A_CHANGE
REQ_POOL        = A_POOL
REQ_CARDS       = A_CARDS
REQ_PETDOG      = A_PETDOG
REQ_HELLO       = $80
REQ_HOWAREYOU   = $81
REQ_THANKS      = $82

;---------------------------------------------------------------------------------------
; State
;---------------------------------------------------------------------------------------
frame_count:    .byte 0
fast_forward:   .byte 0
quit_request:   .byte 0
rnd_seed:       .word $ACE1

clock_hour:     .byte 8
clock_min:      .byte 0
clock_tick:     .byte 0
minute_count:   .byte 0     ; free-running game-minute counter

food:           .byte 5
water:          .byte 5
dogfood:        .byte 5
hunger:         .byte 20    ; 0 = full .. 100 = starving
thirst:         .byte 20
energy:         .byte 80    ; 100 = rested
mood:           .byte 60    ; 0 = miserable .. 100 = delighted
health:         .byte 100
lonely:         .byte 0     ; game minutes since you last paid attention (cap 255)
dog_hunger:     .byte 20
bowl_full:      .byte 0
outfit:         .byte 0     ; 0 day clothes, 1 pyjamas, 2 nothing (after a shower)
brush_todo:     .byte 0
dress_todo:     .byte 0
fire_time:      .byte 0     ; game minutes of fire left
complain_cd:    .byte 0     ; cooldowns, in game minutes
knock_cd:       .byte 90
letter_cd:      .byte 120
cards_won:      .byte 0     ; your wins this session, he sulks if you win too much
gift_flags:     .byte 0     ; bit0 book, bit1 record, bit2 food, bit3 water (for letters)
tv_on:          .byte 0
monitor_on:     .byte 0
lcp_name_ptr:   .word lcp_names

player_name:    .fill 13, 0

p_state:        .byte PS_IDLE
p_mode:         .byte PM_HIDDEN
p_floor:        .byte 0
p_x:            .word 300
p_y:            .byte FLOOR0_Y
p_flip:         .byte 0
p_tx:           .word 0
p_anim:         .byte 0
p_act:          .byte A_NONE
p_goal:         .byte A_NONE
p_pending:      .byte A_NONE
goal_floor:     .byte 0
goal_x:         .word 0
act_timer:      .word 0
act_phase:      .byte 0
pose_spr:       .byte 0, 0, 0
pose_x:         .word 0
pose_y:         .byte 0

lcp_names:
        .null "Hank"
        .null "Larry"
        .null "Walt"
        .null "Gus"
        .null "Mel"
        .null "Ted"
        .null "Ollie"
        .null "Ned"
LCP_NAME_COUNT = 8

;---------------------------------------------------------------------------------------
; Random numbers: 16-bit Galois LFSR.
;---------------------------------------------------------------------------------------
rnd:
        lsr rnd_seed+1
        ror rnd_seed
        bcc +
        lda rnd_seed+1
        eor #$B4
        sta rnd_seed+1
+       lda rnd_seed
        rts

; A = n -> A = random 0..n-1
rnd_range:
        sta l_rr_n
        jsr rnd
        sta MULTINA
        lda l_rr_n
        sta MULTINB
        lda MULTOUT+1
        rts
l_rr_n:  .byte 0

;---------------------------------------------------------------------------------------
; Clock and needs. sim_tick runs 1x per frame (4x when fast forward is on).
;---------------------------------------------------------------------------------------
sim_init:
        jsr mult_init
        lda VIC_RASTER
        ora #1
        sta rnd_seed
        ; pick his name
        lda #LCP_NAME_COUNT
        jsr rnd_range
        tax
        lda #<lcp_names
        sta ZPTR
        lda #>lcp_names
        sta ZPTR+1
-       cpx #0
        beq +
        ldy #0
-       lda (ZPTR),y
        inw ZPTR
        cmp #0
        bne -
        dex
        bra --
+       lda ZPTR
        sta lcp_name_ptr
        lda ZPTR+1
        sta lcp_name_ptr+1
        ; he arrives through the front door
        lda #A_ARRIVE
        sta p_pending
        lda #PS_IDLE
        sta p_state
        lda #PM_HIDDEN
        sta p_mode
        lda #0
        sta p_floor
        lda #<300
        sta p_x
        lda #>300
        sta p_x+1
        lda #FLOOR0_Y
        sta p_y
        jsr dog_init
        rts

sim_tick:
        inc clock_tick
        lda clock_tick
        cmp #TICKS_PER_MIN
        bcc +
        lda #0
        sta clock_tick
        jsr game_minute
+       jsr person_update
        jsr dog_update
        jsr fx_update
        rts

game_minute:
        inc minute_count
        lda #1
        sta ui_dirty
        inc clock_min
        lda clock_min
        cmp #60
        bcc l_gm_needs
        lda #0
        sta clock_min
        inc clock_hour
        lda clock_hour
        cmp #24
        bcc l_gm_hour
        lda #0
        sta clock_hour
l_gm_hour:
        jsr lights_update
l_gm_needs:
        ; cooldowns
        ldx #complain_cd - complain_cd
        jsr l_gm_dec
        ldx #knock_cd - complain_cd
        jsr l_gm_dec
        ldx #letter_cd - complain_cd
        jsr l_gm_dec
        lda knock_wait
        beq +
        dec knock_wait
+
        lda fire_time
        beq +
        dec fire_time
        bne +
        ldx #PATCH_FIRE
        jsr patch_remove
+       lda lonely
        cmp #255
        beq +
        inc lonely
+
        ; asleep: hunger and thirst creep up slowly (every 16 minutes)
        jsr person_sleeping
        bcc l_gm_needs_awake
        lda minute_count
        and #15
        bne l_gm_dog
        lda #thirst - hunger
        jsr l_gm_up
        lda #0
        jsr l_gm_up
        bra l_gm_dog
l_gm_needs_awake:
        ; awake: thirst every 4 minutes, hunger every 6
        lda minute_count
        and #3
        bne +
        lda #thirst - hunger
        jsr l_gm_up
+       lda minute_count
        jsr l_mod6
        bne l_gm_dog
        lda #0
        jsr l_gm_up
l_gm_dog:       ; every 8 minutes: dog hunger
        lda minute_count
        and #7
        bne +
        lda #dog_hunger - hunger
        jsr l_gm_up
+       ; energy
        lda p_act
        cmp #A_SLEEP
        bne l_gm_awake
        lda p_state
        cmp #PS_ACT
        bne l_gm_awake
        lda minute_count
        and #3
        bne l_gm_health
        lda energy
        cmp #100
        bcs l_gm_health
        inc energy
        bra l_gm_health
l_gm_awake:
        lda minute_count
        jsr l_mod9
        bne l_gm_health
        lda energy
        beq l_gm_health
        dec energy
l_gm_health:
        ; starving or parched hurts; otherwise heal slowly
        lda hunger
        cmp #90
        bcs l_gm_hurt
        lda thirst
        cmp #90
        bcs l_gm_hurt
        lda minute_count
        and #15
        bne l_gm_mood
        lda health
        cmp #100
        bcs l_gm_mood
        inc health
        bra l_gm_mood
l_gm_hurt:
        lda minute_count
        and #3
        bne l_gm_mood
        lda health
        beq l_gm_mood
        dec health
l_gm_mood:
        lda minute_count
        and #15
        bne l_gm_out
        ; unhappy when hungry, thirsty, lonely or sick
        lda hunger
        cmp #70
        bcs l_gm_sad
        lda thirst
        cmp #70
        bcs l_gm_sad
        lda lonely
        cmp #200
        bcs l_gm_sad
        lda health
        cmp #40
        bcc l_gm_sad
        ; drift towards 50
        lda mood
        cmp #50
        beq l_gm_out
        bcc +
        dec mood
        bra l_gm_out
+       inc mood
        bra l_gm_out
l_gm_sad:
        lda #2
        jmp mood_down
l_gm_out:
        rts

l_gm_dec:
        lda complain_cd,x
        beq +
        dec complain_cd,x
+       rts

; increase need X-offset (from hunger) by one, cap 100
l_gm_up:
        tax
        lda hunger,x
        cmp #100
        bcs +
        inc hunger,x
+       rts

l_mod6:
-       cmp #6
        bcc +
        sbc #6
        bra -
+       cmp #0
        rts
l_mod9:
-       cmp #9
        bcc +
        sbc #9
        bra -
+       cmp #0
        rts

; A = amount
mood_up:
        clc
        adc mood
        cmp #101
        bcc +
        lda #100
+       sta mood
        lda #1
        sta ui_dirty
        rts

mood_down:
        sta l_md_n
        sec
        lda mood
        sbc l_md_n
        bcs +
        lda #0
+       sta mood
        lda #1
        sta ui_dirty
        rts
l_md_n:  .byte 0

;---------------------------------------------------------------------------------------
; Lights and palette animation
;---------------------------------------------------------------------------------------
is_night:
        ; C = 1 between 20:00 and 05:59
        lda clock_hour
        cmp #20
        bcs +
        cmp #6
        bcc +
        clc
        rts
+       sec
        rts

lights_update:
        lda #255
        sta l_lu_dim
        jsr is_night
        bcc l_lu_set
        lda #190
        sta l_lu_dim
        lda p_act
        cmp #A_SLEEP
        bne l_lu_set
        lda p_state
        cmp #PS_ACT
        bne l_lu_set
        lda #105                ; lights out
        sta l_lu_dim
l_lu_set:
        lda l_lu_dim
        cmp pal_dim
        beq +
        sta pal_dim
        jsr pal_apply_all
+       rts
l_lu_dim: .byte 255

; Sky colour per hour (r, g, b)
sky_rgb:
        .byte 17,17,85, 17,17,85, 17,17,85, 17,17,85, 17,17,102, 51,34,136   ; 0-5
        .byte 170,85,119, 68,102,238, 0,0,221, 0,0,221, 0,0,221, 0,0,221     ; 6-11
        .byte 0,0,221, 0,0,221, 0,0,221, 0,0,221, 0,0,221, 34,68,221         ; 12-17
        .byte 204,102,68, 136,51,102, 51,34,119, 34,17,102, 17,17,85, 17,17,85 ; 18-23

outfit_rgb:     ; shirt, shirt shade, pants, far trouser leg (day, pyjamas, nothing)
        .byte 34,102,255, 17,51,170, 255,255,255, 170,170,170
        .byte 221,34,153, 153,17,102, 255,204,221, 204,153,170
        .byte 255,204,153, 230,170,120, 255,204,153, 221,160,110

palette_animate:
        ; sky
        lda #<sky_rgb
        sta ZPTR
        lda #>sky_rgb
        sta ZPTR+1
        ldy clock_hour
        ldx #C_SKY
        jsr pal_set_from
        ; clothes
        lda #<outfit_rgb
        sta ZPTR
        lda #>outfit_rgb
        sta ZPTR+1
        lda outfit
        asl
        asl
        tay                     ; 4 entries per outfit
        sty l_pa_o
        ldx #C_SHIRT
        jsr pal_set_from
        ldy l_pa_o
        iny
        ldx #C_SHIRT2
        jsr pal_set_from
        ldy l_pa_o
        iny
        iny
        ldx #C_PANTS
        jsr pal_set_from
        ldy l_pa_o
        iny
        iny
        iny
        ldx #C_PANTS2
        jsr pal_set_from
        ; skin: green when sick
        lda #204
        sta pe_g
        lda #153
        sta pe_b
        lda #255
        ldx health
        cpx #40
        bcs +
        lda #136
        sta pe_g
        lda #102
        sta pe_b
        lda #153
+       ldx #C_SKIN
        jsr pal_set
        ; water bottle: blue while there is water
        lda #0
        sta pe_g
        lda #221
        sta pe_b
        lda #0
        ldx water
        bne +
        lda #204
        sta pe_g
        sta pe_b
+       ldx #C_BOTTLE
        jsr pal_set
        ; attic TV
        lda tv_on
        beq l_pan_tvoff
        lda frame_count
        lsr
        lsr
        lsr
        and #3
        tay
        lda l_tv_g,y
        sta pe_g
        lda l_tv_b,y
        sta pe_b
        lda l_tv_r,y
        bra l_pan_tvset
l_pan_tvoff:
        lda #255
        sta pe_g
        sta pe_b
l_pan_tvset:
        ldx #C_TVSCR
        jsr pal_set
        ; study monitor
        lda #0
        sta pe_g
        sta pe_b
        lda monitor_on
        beq +
        lda frame_count
        and #16
        ora #136
        sta pe_g
        lda #68
        sta pe_b
        lda #34
+       ldx #C_MONITOR
        jsr pal_set
        ; fire: rotate three flame colours
        lda frame_count
        lsr
        lsr
        and #3
        cmp #3
        bne +
        lda #0
+       sta l_pa_o
        ldx #0
-       txa
        clc
        adc l_pa_o
        cmp #3
        bcc +
        sbc #3
+       tay
        lda l_fire_g,y
        sta pe_g
        lda l_fire_b,y
        sta pe_b
        lda l_fire_r,y
        phx
        pha
        txa
        clc
        adc #C_FIRE_A
        tax
        pla
        jsr pal_set
        plx
        inx
        cpx #3
        bne -
        rts
l_pa_o:  .byte 0
l_tv_r:  .byte 170,221,136,255
l_tv_g:  .byte 204,255,170,221
l_tv_b:  .byte 255,255,221,170
l_fire_r: .byte 255,238,255
l_fire_g: .byte 0,119,221
l_fire_b: .byte 0,0,0

;---------------------------------------------------------------------------------------
; Activity table
;---------------------------------------------------------------------------------------
;               floor  x     face(1=right)
act_floor:
        .byte 0, 0,0,0,0,0, 0,0,0, 1,1,1,1,1, 1,2, 2,2,2,2, 2,2,2, 0,0,0,0
act_xl:
        .byte 0, <52,<122,<138,<34,<213, <226,<248,<302, <40,<115,<170,<196,<222, <278,<228
        .byte <80,<100,<120,<154, <188,<228,<228, <160,0,0,<300
act_xh:
        .byte 0, >52,>122,>138,>34,>213, >226,>248,>302, >40,>115,>170,>196,>222, >278,>228
        .byte >80,>100,>120,>154, >188,>228,>228, >160,0,0,>300
act_face:
        .byte 0, 0,1,1,0,0, 0,1,1, 0,0,0,1,1, 1,1, 0,0,0,0, 1,1,1, 0,0,0,0

act_start_tbl:
        .word st_none, st_fridge, st_meal, st_drink, st_feeddog, st_phone, st_read, st_fire
        .word st_goout, st_sleep, st_exercise, st_brush, st_wc, st_bath, st_computer
        .word st_letter, st_tv, st_record, st_dance, st_piano, st_change, st_pool
        .word st_cards, st_knock, st_idle, st_petdog, st_arrive
act_tick_tbl:
        .word tk_none, tk_none, tk_none, tk_none, tk_none, tk_phone, tk_none, tk_none
        .word tk_goout, tk_sleep, tk_none, tk_none, tk_none, tk_bath, tk_computer
        .word tk_pool, tk_none, tk_record, tk_none, tk_piano, tk_none, tk_pool
        .word tk_none, tk_knock, tk_none, tk_none, tk_arrive
act_end_tbl:
        .word en_none, en_fridge, en_meal, en_drink, en_feeddog, en_phone, en_read, en_fire
        .word en_goout, en_sleep, en_exercise, en_brush, en_wc, en_bath, en_computer
        .word en_letter, en_tv, en_record, en_dance, en_piano, en_change, en_pool
        .word en_cards, en_knock, en_none, en_petdog, en_arrive

act_names:
        .word nm_none, nm_fridge, nm_meal, nm_drink, nm_feeddog, nm_phone, nm_read, nm_fire
        .word nm_goout, nm_sleep, nm_exercise, nm_brush, nm_wc, nm_bath, nm_computer
        .word nm_letter, nm_tv, nm_record, nm_dance, nm_piano, nm_change, nm_pool
        .word nm_cards, nm_knock, nm_none, nm_petdog, nm_arrive
nm_none:     .null " is pottering about."
nm_fridge:   .null " is getting some food."
nm_meal:     .null " is eating."
nm_drink:    .null " is having a drink."
nm_feeddog:  .null " is feeding the dog."
nm_phone:    .null " is on the phone."
nm_read:     .null " is reading a book."
nm_fire:     .null " is lighting a fire."
nm_goout:    .null " has gone out."
nm_sleep:    .null " is asleep. Zzz..."
nm_exercise: .null " is exercising."
nm_brush:    .null " is brushing his teeth."
nm_wc:       .null " is in the bathroom."
nm_bath:     .null " is taking a bath."
nm_computer: .null " is using the computer."
nm_letter:   .null " is typing you a letter."
nm_tv:       .null " is watching TV."
nm_record:   .null " is listening to records."
nm_dance:    .null " is dancing."
nm_piano:    .null " is playing the piano."
nm_change:   .null " is changing clothes."
nm_pool:     .null " is playing solitaire."
nm_cards:    .null " wants to play cards."
nm_knock:    .null " is trying to get your attention!"
nm_petdog:   .null " is playing with the dog."
nm_arrive:   .null " is moving in!"
nm_walking:  .null " is walking around."

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
        lda water
        beq +
        lda #A_DRINK
        rts
+       lda hunger
        cmp #75
        bcc +
        lda food
        beq +
        lda #A_FRIDGE
        rts
+       ; fresh out of the shower: get dressed before anything else
        lda outfit
        cmp #2
        bne +
        lda #A_CHANGE
        rts
+       ; bedtime
        lda clock_hour
        cmp #22
        bcs l_ai_sleep
        cmp #6
        bcc l_ai_sleep
        lda energy
        cmp #12
        bcs +
l_ai_sleep:
        lda #A_SLEEP
        rts
+       lda health
        cmp #30
        bcs +
        lda #3
        jsr rnd_range
        bne +
        lda #A_SLEEP            ; sick: lie down a lot
        rts
+       ; morning routine
        lda dress_todo
        beq +
        lda #0
        sta dress_todo
        lda #A_CHANGE
        rts
+       ; thirst
        lda thirst
        cmp #50
        bcc l_ai_food
        lda water
        beq +
        lda #A_DRINK
        rts
+       jsr complain_water
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
        lda dog_hunger
        cmp #60
        bcc l_ai_lonely
        lda bowl_full
        bne l_ai_lonely
        lda dogfood
        beq +
        lda #A_FEEDDOG
        rts
+       jsr complain_dogfood
l_ai_lonely:
        lda lonely
        cmp #150
        bcc l_ai_letter
        lda knock_cd
        bne l_ai_letter
        lda #90
        sta knock_cd
        lda #A_KNOCK
        rts
l_ai_letter:
        lda letter_cd
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
        lda #l_fun_count
        jsr rnd_range
        tax
        lda l_fun_list,x
        rts
l_fun_list:
        .byte A_TV, A_TV, A_RECORD, A_PIANO, A_PIANO, A_READ, A_READ, A_COMPUTER
        .byte A_EXERCISE, A_POOL, A_BATH, A_WC, A_IDLE, A_IDLE, A_IDLE, A_PETDOG
        .byte A_GOOUT, A_DANCE, A_IDLE, A_READ, A_CARDS
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

say_thirsty:   .null "I'm thirsty! Fill my bottle? (CTRL-W)"
say_hungry:    .null "No food left! Send some? (CTRL-F)"
say_nodogfood: .null "The dog's hungry. Dog food? (CTRL-D)"

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
+       ; will he? mood/2 + random(50) + 25 if polite, -15 if not
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
l_say_no1:  .null "I don't feel like it."
l_say_no2:  .null "Maybe later."
l_say_no3:  .null "Nah, not right now."
l_say_yes1: .null "OK!"
l_say_yes2: .null "Sure, good idea!"
l_say_yes3: .null "Alright, if you say so."
l_say_please: .null "Hey, what's the magic word?"
l_say_hi1:   .null ": Hi there, "
l_say_welcome: .null "Aw, you're welcome!"
l_say_great:  .null "I'm feeling great, thanks!"
l_say_sick:   .null "I don't feel so well..."
l_say_hungry2: .null "I'm really hungry."
l_say_thirsty2: .null "I could use a drink."
l_say_tired:  .null "I'm so tired..."
l_say_blue:   .null "I'm feeling kind of blue."
l_say_zzz:    .null "Zzzz... (he's asleep. CTRL-A rings the alarm)"
l_say_out:    .null "He's out right now."

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
        lda food
        clc
        adc #3
        cmp #10
        bcc +
        lda #9
+       sta food
        lda gift_flags
        ora #4
        sta gift_flags
        lda #SFX_CHIME
        jsr sfx_play
        lda #3
        jsr mood_up
        ldx #<l_say_gfood
        ldy #>l_say_gfood
        jmp ui_note
gift_water:
        lda water
        cmp #9
        bcs +
        inc water
+       lda gift_flags
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
        lda dogfood
        clc
        adc #3
        cmp #10
        bcc +
        lda #9
+       sta dogfood
        lda #SFX_CHIME
        jsr sfx_play
        lda #1
        sta ui_dirty
        ldx #<l_say_gdog
        ldy #>l_say_gdog
        jmp ui_note
gift_book:
        lda gift_flags
        ora #1
        sta gift_flags
        lda #8
        jsr mood_up
        lda #SFX_CHIME
        jsr sfx_play
        jsr person_sleeping
        bcs +
        lda #A_READ
        jsr request_pending
+       ldx #<l_say_gbook
        ldy #>l_say_gbook
        jmp ui_say
gift_record:
        lda gift_flags
        ora #2
        sta gift_flags
        lda #8
        jsr mood_up
        lda #SFX_CHIME
        jsr sfx_play
        jsr person_sleeping
        bcs +
        lda #A_RECORD
        jsr request_pending
+       ldx #<l_say_grecord
        ldy #>l_say_grecord
        jmp ui_say
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
        cpx #A_READ
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
        lda #SFX_PHONE
        jsr sfx_play
        jsr person_sleeping
        bcs +
        lda #A_PHONE
        jsr request_pending
        ldx #<l_say_ring
        ldy #>l_say_ring
        jmp ui_note
+       ldx #<l_say_ring2
        ldy #>l_say_ring2
        jmp ui_note
alarm_ring:
        lda #SFX_ALARM
        jsr sfx_play
        jsr person_sleeping
        bcc +
        jsr act_end
        lda #PS_IDLE
        sta p_state
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

l_say_gfood:   .null "A box of groceries arrived!"
l_say_gwater:  .null "You topped up the water bottle."
l_say_gdog:    .null "A bag of dog food arrived!"
l_say_gbook:   .null "A new book! Thank you!"
l_say_grecord: .null "A new record! Let's give it a spin!"
l_say_pet:     .null "Hee hee, that tickles!"
l_say_ring:    .null "Ring ring! The phone is ringing."
l_say_ring2:   .null "Ring ring... he sleeps right through it."
l_say_midnight: .null "Hey! It's the middle of the night!"
l_say_morning: .null "Yawn... good morning!"

;---------------------------------------------------------------------------------------
; Body: the per-tick state machine
;---------------------------------------------------------------------------------------
person_update:
        inc p_anim
        lda p_state
        cmp #PS_IDLE
        beq person_choose
        cmp #PS_WALK
        bne +
        jmp person_walk
+       cmp #PS_CLIMB
        bne +
        jmp person_climb
+       ; PS_ACT
        jsr act_tick
        lda act_timer
        ora act_timer+1
        beq l_pu_end
        lda act_timer
        bne +
        dec act_timer+1
+       dec act_timer
        rts
l_pu_end:
        jsr act_end
        lda #PS_IDLE
        sta p_state
        rts

person_choose:
        lda p_pending
        beq +
        ldx #A_NONE
        stx p_pending
        bra ++
+       jsr ai_choose
+       sta p_goal
        tax
        lda act_floor,x
        sta goal_floor
        lda act_xl,x
        sta goal_x
        lda act_xh,x
        sta goal_x+1
        cpx #A_IDLE
        bne +
        ; wander somewhere on this floor
        lda p_floor
        sta goal_floor
        lda #200
        jsr rnd_range
        clc
        adc #60
        sta goal_x
        lda #0
        sta goal_x+1
        bra l_pc_go
+       cpx #A_KNOCK
        bne +
        ; knock from a clear spot on whatever floor he is on
        lda p_floor
        sta goal_floor
        tay
        lda knock_x,y
        sta goal_x
        lda #0
        sta goal_x+1
        bra l_pc_go
+       cpx #A_PETDOG
        bne +
        lda dog_x
        clc
        adc #18
        sta goal_x
        lda dog_x+1
        adc #0
        sta goal_x+1
        bra l_pc_go
+       cpx #A_ARRIVE
        bne l_pc_go
        ; already at the door: start straight away
        lda #PS_ACT
        sta p_state
        stx p_act
        jmp act_start
l_pc_go:
        jsr set_walk_target
        lda #PS_WALK
        sta p_state
        lda #1
        sta ui_dirty
        rts

; p_tx = goal_x on this floor, else the foot/head of the staircase towards
; goal_floor.
set_walk_target:
        lda p_floor
        cmp goal_floor
        bne +
        lda goal_x
        sta p_tx
        lda goal_x+1
        sta p_tx+1
        rts
+       ldx #STAIR0_BOTTOM_X    ; ground floor: up
        lda p_floor
        beq l_swt_x
        cmp #2
        bne +
        ldx #STAIR1_TOP_X       ; attic: down
        bra l_swt_x
+       ldx #STAIR0_TOP_X       ; middle floor, going down
        lda goal_floor
        beq l_swt_x
        ldx #STAIR1_BOTTOM_X    ; middle floor, going up
l_swt_x:
        stx p_tx
        lda #0
        sta p_tx+1
        rts

person_walk:
        lda p_x+1
        cmp p_tx+1
        bne l_pw_move
        lda p_x
        cmp p_tx
        bne l_pw_move
        ; arrived
        lda p_floor
        cmp goal_floor
        beq l_pw_arrive
        jmp climb_start
l_pw_arrive:
        lda #PS_ACT
        sta p_state
        ldx p_goal
        stx p_act
        lda act_face,x
        sta p_flip
        lda #PM_STAND
        sta p_mode
        lda #1
        sta ui_dirty
        jmp act_start
l_pw_move:
        lda #PM_WALK
        sta p_mode
        lda p_x
        jsr footstep
        ; 16-bit compare p_x < p_tx ?
        lda p_x
        cmp p_tx
        lda p_x+1
        sbc p_tx+1
        bcc l_pw_right
        lda #0
        sta p_flip
        lda p_x
        bne +
        dec p_x+1
+       dec p_x
        rts
l_pw_right:
        lda #1
        sta p_flip
        inc p_x
        bne +
        inc p_x+1
+
        rts

;---------------------------------------------------------------------------------------
; Stairs. Each flight is a front-facing block of steps (climbed in back view,
; centred on the block) joined to a side-on flight he walks along sideways,
; feet on the treads. Paths are lists of 4-byte waypoints:
;     x, y (feet), mode (0 = climb in back view, 1 = walk sideways; bit 7 =
;     last waypoint), ticks per pixel step.
; Movement between waypoints is a Bresenham line.
;---------------------------------------------------------------------------------------
STAIR0_BOTTOM_X = 177       ; ground floor, centre of the red step block
STAIR0_TOP_X    = 128       ; middle floor, where the side flight comes out
STAIR1_BOTTOM_X = 141       ; middle floor, centre of the red step block
STAIR1_TOP_X    = 190       ; attic, where the side flight comes out

path_up0:
        .byte 177, 159, 0, 2
        .byte 166, 157, 1, 1
        .byte 136, 137, 1, 1
        .byte 128, FLOOR1_Y, $81, 1
path_down0:
        .byte 136, 137, 1, 1
        .byte 166, 157, 1, 1
        .byte 177, 159, 1, 1
        .byte 177, FLOOR0_Y, $82, 2
path_up1:
        .byte 141, 96, 0, 2
        .byte 152, 94, 1, 1
        .byte 183, 72, 1, 1
        .byte 190, FLOOR2_Y, $81, 1
path_down1:
        .byte 183, 72, 1, 1
        .byte 152, 94, 1, 1
        .byte 141, 96, 1, 1
        .byte 141, FLOOR1_Y, $82, 2

l_cl_ptr:   .word 0
l_cl_seg:   .byte 0
l_cl_t:     .byte 0
l_cl_err:   .byte 0
l_cl_dest:  .byte 0

climb_start:
        lda p_floor
        bne +
        ldx #<path_up0
        ldy #>path_up0
        lda #1
        bra l_cs_set
+       cmp #2
        bne +
        ldx #<path_down1
        ldy #>path_down1
        lda #1
        bra l_cs_set
+       lda goal_floor
        beq +
        ldx #<path_up1
        ldy #>path_up1
        lda #2
        bra l_cs_set
+       ldx #<path_down0
        ldy #>path_down0
        lda #0
l_cs_set:
        sta l_cl_dest
        stx l_cl_ptr
        sty l_cl_ptr+1
        lda #0
        sta l_cl_seg
        sta l_cl_t
        sta l_cl_err
        sta p_x+1
        lda #PS_CLIMB
        sta p_state
        rts

person_climb:
        lda l_cl_ptr
        sta ZPTR2
        lda l_cl_ptr+1
        sta ZPTR2+1
        lda l_cl_seg
        asl
        asl
        tay
        lda (ZPTR2),y
        sta l_pcl_x1
        iny
        lda (ZPTR2),y
        sta l_pcl_y1
        iny
        lda (ZPTR2),y
        sta l_pcl_mode
        iny
        lda (ZPTR2),y
        sta l_pcl_rate
        ; how it looks: on the step blocks back view going up and facing you
        ; coming down (mode bit 1); side view on the flights (bit 0)
        lda l_pcl_mode
        and #2
        beq +
        lda #PM_DOWNSTEP
        sta p_mode
        bra l_pcl_pace
+       lda l_pcl_mode
        and #1
        beq l_pcl_back
        lda #PM_WALK
        sta p_mode
        lda l_pcl_x1
        cmp p_x
        beq l_pcl_pace
        lda #0                  ; target to the left: face left
        bcc +
        lda #1
+       sta p_flip
        bra l_pcl_pace
l_pcl_back:
        lda #PM_CLIMB
        sta p_mode
l_pcl_pace:
        inc l_cl_t
        lda l_cl_t
        cmp l_pcl_rate
        bcs +
        rts
+       lda #0
        sta l_cl_t
        ; reached the waypoint?
        lda p_x
        cmp l_pcl_x1
        bne l_pcl_step
        lda p_y
        cmp l_pcl_y1
        bne l_pcl_step
        lda #0
        sta l_cl_err
        lda l_pcl_mode
        bmi l_pcl_landed
        inc l_cl_seg
        rts
l_pcl_step:
        lda p_x
        clc
        adc p_y
        jsr footstep
        ; dx, dy magnitudes and directions
        lda #1
        sta l_pcl_sx
        sec
        lda l_pcl_x1
        sbc p_x
        bcs +
        eor #$FF
        adc #1
        ldx #$FF
        stx l_pcl_sx
+       sta l_pcl_dx
        lda #1
        sta l_pcl_sy
        sec
        lda l_pcl_y1
        sbc p_y
        bcs +
        eor #$FF
        adc #1
        ldx #$FF
        stx l_pcl_sy
+       sta l_pcl_dy
        cmp l_pcl_dx
        bcs l_pcl_ymajor
        ; x major
        clc
        lda p_x
        adc l_pcl_sx
        sta p_x
        clc
        lda l_cl_err
        adc l_pcl_dy
        sta l_cl_err
        cmp l_pcl_dx
        bcc +
        sbc l_pcl_dx
        sta l_cl_err
        clc
        lda p_y
        adc l_pcl_sy
        sta p_y
+       rts
l_pcl_ymajor:
        clc
        lda p_y
        adc l_pcl_sy
        sta p_y
        lda l_pcl_dx
        beq +
        clc
        lda l_cl_err
        adc l_pcl_dx
        sta l_cl_err
        cmp l_pcl_dy
        bcc +
        sbc l_pcl_dy
        sta l_cl_err
        clc
        lda p_x
        adc l_pcl_sx
        sta p_x
+       rts
l_pcl_landed:
        lda l_cl_dest
        sta p_floor
        tax
        lda floor_y,x
        sta p_y
        lda #PM_STAND
        sta p_mode
        jsr set_walk_target
        lda #PS_WALK
        sta p_state
        rts

l_pcl_x1:     .byte 0
l_pcl_y1:     .byte 0
l_pcl_mode:   .byte 0
l_pcl_rate:   .byte 0
l_pcl_dx:     .byte 0
l_pcl_dy:     .byte 0
l_pcl_sx:     .byte 0
l_pcl_sy:     .byte 0
floor_y:     .byte FLOOR0_Y, FLOOR1_Y, FLOOR2_Y

;---------------------------------------------------------------------------------------
; Activity dispatch
;---------------------------------------------------------------------------------------
act_start:
        lda #0
        sta act_phase
        lda p_act
        asl
        tax
        jmp (act_start_tbl,x)
act_tick:
        lda p_act
        asl
        tax
        jmp (act_tick_tbl,x)
act_end:
        lda #1
        sta ui_dirty
        lda p_act
        asl
        tax
        jsr l_ae_jump
        lda #A_NONE
        sta p_act
        lda #PM_STAND
        sta p_mode
        jsr fx_clear
        jmp lights_update
l_ae_jump:
        jmp (act_end_tbl,x)

; A/X = seconds -> act_timer = seconds * 50
set_timer_secs:
        sta MULTINA
        lda #50
        sta MULTINB
        lda MULTOUT
        sta act_timer
        lda MULTOUT+1
        sta act_timer+1
        rts

; Show pose sprite: X/Y/A = sprite addr lo/hi/bank, then pose_x/pose_y set by caller.
use_pose:
        stx pose_spr
        sty pose_spr+1
        sta pose_spr+2
        lda #PM_POSE
        sta p_mode
        rts

POSE .macro spr, px, py
        lda #<\px
        sta pose_x
        lda #>\px
        sta pose_x+1
        lda #\py
        sta pose_y
        ldx #<\spr
        ldy #>\spr
        lda #`\spr
        jsr use_pose
.endmacro

SAY .macro text
        ldx #<\text
        ldy #>\text
        jsr ui_say
.endmacro

st_none:
tk_none:
en_none:
        rts

st_idle:
        lda #3
        jsr rnd_range
        bne +
        lda #PM_FRONT           ; sometimes just stand and look out at you
        sta p_mode
+       lda #4
        jsr rnd_range
        clc
        adc #2
        jmp set_timer_secs

; --- kitchen ---------------------------------------------------------------------------
st_fridge:
        ldx #PATCH_FRIDGE
        jsr patch_apply
        lda #SFX_DOOR
        jsr sfx_play
        lda #2
        jmp set_timer_secs
en_fridge:
        ldx #PATCH_FRIDGE
        jsr patch_remove
        lda food
        beq +
        dec food
        lda #A_MEAL
        sta p_pending
+       rts
st_meal:
        #POSE SPR_EAT, POSE_EAT_X, POSE_EAT_Y
        lda #7
        jmp set_timer_secs
en_meal:
        lda #0
        sta hunger
        lda #1
        sta brush_todo
        lda #3
        jsr mood_up
        #SAY l_say_yum
        rts
st_drink:
        lda #SFX_GLUG
        jsr sfx_play
        lda #3
        jmp set_timer_secs
en_drink:
        lda water
        beq +
        dec water
+       lda #0
        sta thirst
        lda #1
        sta ui_dirty
        rts
st_feeddog:
        lda #2
        jmp set_timer_secs
en_feeddog:
        lda dogfood
        beq +
        dec dogfood
        lda #1
        sta bowl_full
        #SAY l_say_goodboy
+       rts

; --- living room -----------------------------------------------------------------------
st_phone:
        lda #6
        jmp set_timer_secs
tk_phone:
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
en_phone:
        lda #8
        jsr mood_up
        lda #0
        sta lonely
        rts
st_read:
        #POSE SPR_CHAIR, POSE_CHAIR_X, POSE_CHAIR_Y
        lda #20
        jmp set_timer_secs
en_read:
        lda #4
        jmp mood_up
st_fire:
        lda #3
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
st_goout:
        ldx #PATCH_DOOR
        jsr patch_apply
        lda #SFX_DOOR
        jsr sfx_play
        lda #<1200
        sta act_timer
        lda #>1200
        sta act_timer+1
        rts
tk_goout:
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
+       jsr sb_strxy
        jmp ui_say_sb
en_knock:
        lda #100
        sta lonely
        rts
l_tk_pick: .byte 0
l_say_knock1: .null "Hey! Anybody out there? Hello, "
l_say_knock2: .null "Psst! Psst! "
l_say_knock3: .null "Knock knock, "
l_say_knock4: .null " I'm bored. Talk to me?"
l_say_knock5: .null " Wanna play poker? (YES?)"

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
l_say_deal:  .null "Great! I'll deal!"
l_say_there: .null "Oh good, you ARE there!" 
st_petdog:
        jsr fx_heart_on_person
        lda #3
        jmp set_timer_secs
en_petdog:
        lda #3
        jsr mood_up
        lda #SFX_BARK
        jmp sfx_play

; --- middle floor ----------------------------------------------------------------------
st_sleep:
        lda #PM_HIDDEN
        sta p_mode
        lda #1
        sta outfit
        lda #<$FFFF
        sta act_timer
        lda #>$FFFF
        sta act_timer+1
        jsr fx_zz_on
        jmp lights_update
tk_sleep:
        ; get up for food or water if he needs it and there is some
        lda thirst
        cmp #75
        bcc +
        lda water
        bne l_tks_wake
+       lda hunger
        cmp #75
        bcc +
        lda food
        bne l_tks_wake
+       ; otherwise wake when rested in the daytime
        lda clock_hour
        cmp #7
        bcc l_tks_out
        cmp #21
        bcs l_tks_out
        lda energy
        cmp #70
        bcc l_tks_out
l_tks_wake:
        lda #0
        sta act_timer
        sta act_timer+1
l_tks_out:
        rts
en_sleep:
        lda #1
        sta dress_todo
        lda #PM_STAND
        sta p_mode
        rts
st_exercise:
        lda #PM_JUMP
        sta p_mode
        lda #TUNE_DANCE
        jsr tune_play
        lda #10
        jmp set_timer_secs
en_exercise:
        lda #TUNE_NONE
        jsr tune_play
        lda health
        cmp #95
        bcs +
        clc
        adc #5
        sta health
+       lda energy
        sec
        sbc #5
        bcs +
        lda #0
+       sta energy
        lda #2
        jmp mood_up
st_brush:
        #POSE SPR_BRUSH, POSE_BRUSH_X, POSE_BRUSH_Y
        lda #5
        jmp set_timer_secs
en_brush:
        lda #1
        jmp mood_up
st_wc:
        lda #PM_HIDDEN
        sta p_mode
        lda #4
        jmp set_timer_secs
en_wc:
        lda #SFX_FLUSH
        jmp sfx_play
; Shower: he steps behind the curtain, it slides shut (right to left, like an
; accordion) over the tub, the water runs, then it slides open and he steps
; out -- undressed, so he heads for the closet with a mosaic over him.
BATH_SECS       = 9
bath_t:         .byte 0

st_bath:
        lda #PM_HIDDEN
        sta p_mode
        lda #0
        sta bath_t
        lda #1
        sta shower_on
        lda #BATH_SECS
        jmp set_timer_secs
tk_bath:
        lda bath_t
        cmp #255
        beq +
        inc bath_t
+       lda bath_t
        cmp #2
        bne +
        lda #1
        jmp curtain_set
+       cmp #8
        bne +
        lda #2
        jmp curtain_set
+       cmp #14
        bne +
        lda #3
        jmp curtain_set
+       ; open again in the last moments
        lda act_timer+1
        bne l_tkb_out
        lda act_timer
        cmp #20
        bne +
        lda #0
        sta shower_on
        lda #2
        jmp curtain_set
+       cmp #12
        bne l_tkb_out
        lda #1
        jmp curtain_set
l_tkb_out:
        rts

; A = 0 open (bunched at the right), 1..3 = drawn a third / two thirds / shut
curtain_set:
        sta l_cs_level
        ; the three steps share cells: restore the open curtain, then draw one
        lda #0
        sta patch_state + PATCH_CURTAIN1
        sta patch_state + PATCH_CURTAIN2
        lda #1
        sta patch_state + PATCH_CURTAIN3
        ldx #PATCH_CURTAIN3
        jsr patch_remove
        lda l_cs_level
        beq +
        clc
        adc #PATCH_CURTAIN1 - 1
        tax
        jsr patch_apply
+       rts
l_cs_level: .byte 0

en_bath:
        lda #0
        sta shower_on
        jsr curtain_set
        lda #2                  ; out of the shower with nothing on
        sta outfit
        lda #3
        jsr mood_up
        lda health
        cmp #96
        bcs +
        clc
        adc #4
        sta health
+       #SAY l_say_clean
        rts
st_computer:
        #POSE SPR_COMPUTER, POSE_COMPUTER_X, POSE_COMPUTER_Y
        lda #1
        sta monitor_on
        lda #15
        jmp set_timer_secs
tk_computer:
        lda p_anim
        and #7
        bne +
        lda #4
        jsr rnd_range
        bne +
        lda #SFX_TYPE
        jsr sfx_play
+       rts
en_computer:
        lda #0
        sta monitor_on
        lda #3
        jmp mood_up
; The attic desk with the typewriter: letters, solitaire and card games happen
; here, seated on the far side of the desk facing you.
DESK_POSE_X     = 215         ; behind the typewriter, facing you
DESK_POSE_Y     = 39

st_letter:
        #POSE SPR_SITDESK, DESK_POSE_X, DESK_POSE_Y
        lda #6
        jmp set_timer_secs
en_letter:
        lda #0
        sta monitor_on
        lda #200
        sta letter_cd
        lda #PM_STAND
        sta p_mode
        jmp letter_show

; --- attic -----------------------------------------------------------------------------
st_tv:
        lda #1
        sta tv_on
        lda #15
        jmp set_timer_secs
en_tv:
        lda #0
        sta tv_on
        lda #4
        jmp mood_up
st_record:
        lda #TUNE_RECORD
        jsr tune_play
        lda #16
        jmp set_timer_secs
tk_record:
        ; put the record on, then dance
        lda p_anim
        and #63
        bne +
        jsr fx_note_on_person
+       lda act_timer+1
        cmp #3
        bcs +
        lda #PM_DANCE
        sta p_mode
+       rts
en_record:
        lda #TUNE_NONE
        jsr tune_play
        lda #6
        jmp mood_up
st_dance:
        lda #PM_DANCE
        sta p_mode
        lda #TUNE_DANCE
        jsr tune_play
        lda #8
        jmp set_timer_secs
en_dance:
        lda #TUNE_NONE
        jsr tune_play
        lda energy
        sec
        sbc #3
        bcs +
        lda #0
+       sta energy
        lda #5
        jmp mood_up
st_piano:
        #POSE SPR_PIANO, POSE_PIANO_X, POSE_PIANO_Y
        lda #TUNE_PIANO
        jsr tune_play
        lda #22
        jmp set_timer_secs
tk_piano:
        lda p_anim
        and #63
        bne +
        jsr fx_note_on_piano
+       rts
en_piano:
        lda #TUNE_NONE
        jsr tune_play
        lda #5
        jmp mood_up
st_change:
        ldx #PATCH_CLOSET
        jsr patch_apply
        lda #SFX_DOOR
        jsr sfx_play
        lda #PM_HIDDEN
        sta p_mode
        lda #3
        jmp set_timer_secs
en_change:
        ldx #PATCH_CLOSET
        jsr patch_remove
        jsr is_night
        lda #0
        bcc +
        lda #1
+       sta outfit
        lda #PM_STAND
        sta p_mode
        rts
; solitaire at the desk
st_pool:
        #POSE SPR_SITDESK, DESK_POSE_X, DESK_POSE_Y
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
        #POSE SPR_SITDESK, DESK_POSE_X, DESK_POSE_Y
        lda #1
        jmp set_timer_secs
en_cards:
        jmp cards_play

l_say_yum:     .null "Mmm, that hit the spot!"
l_say_goodboy: .null "Here you go, boy!"
l_say_hello1:  .null ": Hello? Oh, hi "
l_say_hello2:  .null "! Nice of you to call."
l_say_cozy:    .null "Nice and cozy."
l_say_back:    .null "I'm back! Lovely day out there."
l_say_arr1:    .null "Hi "
l_say_arr2:    .null "! Nice house! I'm "
l_say_knock:   .null "KNOCK KNOCK! Hello? Anybody out there?"
l_say_clean:   .null "Ahh, squeaky clean!"

;---------------------------------------------------------------------------------------
; The dog. Lives on the ground floor.
;---------------------------------------------------------------------------------------
dog_x:          .word 290
dog_tx:         .word 290
dog_flip:       .byte 0
dog_state:      .byte 0     ; 0 hidden, 1 walk, 2 rest, 3 eat
dog_timer:      .byte 0

dog_init:
        lda #0
        sta dog_state
        rts

dog_arrive:
        lda #<280
        sta dog_x
        lda #>280
        sta dog_x+1
        lda #2
        sta dog_state
        lda #50
        sta dog_timer
        lda #SFX_BARK
        jmp sfx_play

dog_update:
        lda dog_state
        bne +
        rts
+       cmp #1
        beq l_dg_walk
        ; resting or eating: count down
        dec dog_timer
        bne l_dg_out
        lda dog_state
        cmp #3
        bne l_dg_choose
        lda #0
        sta bowl_full
        sta dog_hunger
l_dg_choose:
        ; hungry and food in the bowl?
        lda bowl_full
        beq +
        lda #<30
        sta dog_tx
        lda #0
        sta dog_tx+1
        lda #1
        sta dog_state
        rts
+       ; follow him around the ground floor, or wander
        lda #3
        jsr rnd_range
        bne +
        lda p_floor
        bne +
        lda p_x
        sta dog_tx
        lda p_x+1
        sta dog_tx+1
        bra l_dg_go
+       lda #230
        jsr rnd_range
        clc
        adc #40
        sta dog_tx
        lda #0
        sta dog_tx+1
l_dg_go:
        lda #1
        sta dog_state
        lda #10
        jsr rnd_range
        bne l_dg_out
        lda #SFX_BARK
        jsr sfx_play
l_dg_out:
        rts
l_dg_walk:
        lda p_anim
        and #1
        bne l_dg_out             ; dogs trot at half speed
        lda dog_x+1
        cmp dog_tx+1
        bne l_dg_move
        lda dog_x
        cmp dog_tx
        bne l_dg_move
        ; arrived
        lda bowl_full
        beq +
        lda dog_x
        cmp #31
        bcs +
        lda #3
        sta dog_state
        lda #150
        sta dog_timer
        lda #0
        sta dog_flip
        rts
+       lda #2
        sta dog_state
        lda #200
        jsr rnd_range
        clc
        adc #50
        sta dog_timer
        rts
l_dg_move:
        lda dog_x
        cmp dog_tx
        lda dog_x+1
        sbc dog_tx+1
        bcc l_dgm_right
        lda #0
        sta dog_flip
        lda dog_x
        bne +
        dec dog_x+1
+       dec dog_x
        rts
l_dgm_right:
        lda #1
        sta dog_flip
        inc dog_x
        bne +
        inc dog_x+1
+
        rts

;---------------------------------------------------------------------------------------
; Floating effects: zzz over the bed, music notes, hearts.
;---------------------------------------------------------------------------------------
fx_kind:        .byte 0     ; 0 none, 1 zz, 2 note, 3 heart
fx_loop:        .byte 0
fx_x:           .word 0
fx_y:           .byte 0
fx_y0:          .byte 0
fx_t:           .byte 0

fx_clear:
        lda #0
        sta fx_kind
        rts

fx_zz_on:
        lda #1
        ldx #30
        ldy #100
        sec
        bra l_fx_set
fx_note_on_piano:
        lda #2
        ldx #<(POSE_PIANO_X + 6)
        ldy #POSE_PIANO_Y - 2
        clc
        bra l_fx_set
fx_note_on_person:
        lda p_x
        sec
        sbc #3
        tax
        lda p_y
        sec
        sbc #34
        tay
        lda #2
        clc
        bra l_fx_set
fx_heart_on_person:
        ldx p_x
        lda p_y
        sec
        sbc #36
        tay
        lda p_mode
        cmp #PM_POSE
        bne +
        ldx pose_x
        inx
        inx
        inx
        inx
        lda pose_y
        sec
        sbc #8
        tay
+       lda #3
        clc
l_fx_set:
        sta fx_kind
        lda #0
        rol
        sta fx_loop
        stx fx_x
        lda #0
        sta fx_x+1
        lda fx_kind
        cmp #1
        beq +
        lda p_x+1               ; notes/hearts follow his 16-bit x
        sta fx_x+1
+       sty fx_y
        sty fx_y0
        lda #0
        sta fx_t
        rts

fx_update:
        lda fx_kind
        beq l_fu_out
        cmp #4                  ; the knocking fist is driven by tk_knock
        beq l_fu_out
        inc fx_t
        lda fx_t
        and #3
        bne l_fu_out
        dec fx_y
        lda fx_y0
        sec
        sbc fx_y
        cmp #14
        bcc l_fu_out
        lda fx_loop
        beq fx_clear
        lda fx_y0
        sta fx_y
l_fu_out:
        rts

;---------------------------------------------------------------------------------------
; Actor renderer: erase last frame's sprites, draw this frame's.
; Actor 0 = person, 1 = dog, 2 = effect, 3 = dog bowl food, 4 = sleeping head.
;---------------------------------------------------------------------------------------
ACTORS          = 6         ; 5 = censor mosaic
act_vis:        .fill ACTORS, 0
act_sprl:       .fill ACTORS, 0
act_sprh:       .fill ACTORS, 0
act_sprb:       .fill ACTORS, 0
act_xl2:        .fill ACTORS, 0
act_xh2:        .fill ACTORS, 0
act_y:          .fill ACTORS, 0
act_flip:       .fill ACTORS, 0
prev_valid:     .fill ACTORS, 0
prev_cx0:       .fill ACTORS, 0
prev_cy0:       .fill ACTORS, 0
prev_cx1:       .fill ACTORS, 0
prev_cy1:       .fill ACTORS, 0

; After a window closes the cells it covered are restored from the house image;
; the actors' previous rectangles stay valid so stale sprite pixels outside the
; window still get erased next frame. Nothing to do.
actors_force_redraw:
        rts

; X = actor, sprite address in A(bank)/ZTMP(lo)/ZTMP+1(hi) -- helper macro
SETACT .macro n, spr
        lda #<\spr
        sta act_sprl+\n
        lda #>\spr
        sta act_sprh+\n
        lda #`\spr
        sta act_sprb+\n
.endmacro

dogw_l:    .byte <SPR_DOGW0, <SPR_DOGW1, <SPR_DOGW2, <SPR_DOGW3
dogw_h:    .byte >SPR_DOGW0, >SPR_DOGW1, >SPR_DOGW2, >SPR_DOGW3
fist_l:    .byte <SPR_FIST0, <SPR_FIST1, <SPR_FIST2, <SPR_FIST3
fist_h:    .byte >SPR_FIST0, >SPR_FIST1, >SPR_FIST2, >SPR_FIST3
fist_half: .byte 2, 4, 5, 7
walk_sprl: .byte <SPR_WALK0, <SPR_WALK1, <SPR_WALK2, <SPR_WALK3
walk_sprh: .byte >SPR_WALK0, >SPR_WALK1, >SPR_WALK2, >SPR_WALK3
bounce:    .byte 0, 1, 3, 4, 5, 4, 3, 1

actors_build:
        ; --- person ---
        lda #0
        sta act_vis+0
        sta act_vis+4
        lda p_mode
        cmp #PM_HIDDEN
        bne +
        jmp l_ab_person_done
+       lda #1
        sta act_vis+0
        lda p_flip
        sta act_flip+0
        ; default placement for standing sprites: (x-7, y-29)
        sec
        lda p_x
        sbc #7
        sta act_xl2+0
        lda p_x+1
        sbc #0
        sta act_xh2+0
        lda p_y
        sec
        sbc #29
        sta act_y+0
        lda #`SPR_STAND
        sta act_sprb+0
        lda p_mode
        cmp #PM_WALK
        bne +
        lda p_x
        lsr
        lsr
        and #3
        tax
        lda walk_sprl,x
        sta act_sprl+0
        lda walk_sprh,x
        sta act_sprh+0
        jmp l_ab_person_done
+       cmp #PM_STAND
        bne +
        #SETACT 0, SPR_STAND
        jmp l_ab_person_done
+       cmp #PM_FRONT
        bne +
        #SETACT 0, SPR_FRONT
        lda fx_kind
        cmp #4
        bne l_ab_front_xy
        #SETACT 0, SPR_FRONTKNOCK
l_ab_front_xy:
        sec
        lda p_x
        sbc #9
        sta act_xl2+0
        lda p_x+1
        sbc #0
        sta act_xh2+0
        lda #0
        sta act_flip+0
        jmp l_ab_person_done
+       cmp #PM_POSE
        bne +
        lda pose_spr
        sta act_sprl+0
        lda pose_spr+1
        sta act_sprh+0
        lda pose_spr+2
        sta act_sprb+0
        lda pose_x
        sta act_xl2+0
        lda pose_x+1
        sta act_xh2+0
        lda pose_y
        sta act_y+0
        lda #0
        sta act_flip+0
        jmp l_ab_person_done
+       cmp #PM_DOWNSTEP
        bne l_ab_notdown
        ; facing you, stepping down: tiny sway and bob per step
        #SETACT 0, SPR_FRONT
        sec
        lda p_x
        sbc #9
        sta act_xl2+0
        lda p_x+1
        sbc #0
        sta act_xh2+0
        lda p_y
        lsr
        lsr
        and #1
        sta act_flip+0
        lda p_y
        and #2
        lsr
        clc
        adc act_y+0
        sta act_y+0
        jmp l_ab_person_done
l_ab_notdown:
        cmp #PM_CLIMB
        bne +
        #SETACT 0, SPR_CLIMB
        sec
        lda p_x
        sbc #10
        sta act_xl2+0
        lda p_y
        sec
        sbc #28
        sta act_y+0
        lda p_y
        lsr
        lsr
        and #1
        sta act_flip+0
        jmp l_ab_person_done
+       ; jumping / dancing: alternate frames and bounce
        lda p_anim
        lsr
        lsr
        and #7
        tax
        lda act_y+0
        sec
        sbc bounce,x
        sta act_y+0
        lda p_anim
        and #16
        beq +
        #SETACT 0, SPR_WALK1
        bra ++
+       #SETACT 0, SPR_STAND
+       lda p_mode
        cmp #PM_DANCE
        bne l_ab_person_done
        lda p_anim
        lsr
        lsr
        lsr
        lsr
        lsr
        and #1
        sta act_flip+0
l_ab_person_done:
        ; censor mosaic over his hips while he has nothing on
        lda #0
        sta act_vis+5
        lda outfit
        cmp #2
        bne l_ab_nomosaic
        lda act_vis+0
        beq l_ab_nomosaic
        lda p_mode
        cmp #PM_POSE
        beq l_ab_nomosaic
        lda #1
        sta act_vis+5
        #SETACT 5, SPR_MOSAIC0
        lda frame_count
        and #8
        beq +
        #SETACT 5, SPR_MOSAIC1
+       sec
        lda p_x
        sbc #4
        sta act_xl2+5
        lda p_x+1
        sbc #0
        sta act_xh2+5
        lda p_y
        sec
        sbc #13
        sta act_y+5
        lda #0
        sta act_flip+5
l_ab_nomosaic:
        ; sleeping head on the pillow
        jsr person_sleeping
        bcc +
        lda #1
        sta act_vis+4
        #SETACT 4, SPR_SLEEPHEAD
        lda #22
        sta act_xl2+4
        lda #0
        sta act_xh2+4
        sta act_flip+4
        lda #108                ; chin just above the blanket, head on the pillow
        sta act_y+4
+
        ; --- dog ---
        lda #0
        sta act_vis+1
        lda dog_state
        beq l_ab_dog_done
        lda #1
        sta act_vis+1
        lda dog_flip
        sta act_flip+1
        sec
        lda dog_x
        sbc #11
        sta act_xl2+1
        lda dog_x+1
        sbc #0
        sta act_xh2+1
        lda #DOG_Y - 14
        sta act_y+1
        lda dog_state
        cmp #1
        bne l_ab_dog_rest
        ; trotting: four leg frames, one every 3 pixels
        lda dog_x
        ldx #0
-       cmp #12
        bcc +
        sbc #12
        bra -
+       lsr
        lsr
        cmp #3
        bcc +
        lda #3
+       tax
        lda dogw_l,x
        sta act_sprl+1
        lda dogw_h,x
        sta act_sprh+1
        lda #`SPR_DOGW0
        sta act_sprb+1
        lda act_xl2+1           ; walk frames have a 1px margin
        bne +
        dec act_xh2+1
+       dec act_xl2+1
        lda #DOG_Y - 15
        sta act_y+1
        bra l_ab_dog_done
l_ab_dog_rest:
        #SETACT 1, SPR_DOG3
        lda #DOG_Y - 12
        sta act_y+1
l_ab_dog_done:
        ; --- effect ---
        lda #0
        sta act_vis+2
        lda fx_kind
        beq l_ab_fx_done
        lda #1
        sta act_vis+2
        lda fx_x
        sta act_xl2+2
        lda fx_x+1
        sta act_xh2+2
        lda fx_y
        sta act_y+2
        lda #0
        sta act_flip+2
        lda fx_kind
        cmp #4
        bne l_ab_notfist
        ; knocking fist: out past his raised left arm (screen right), growing
        ; outwards from the end of the sleeve as it nears the glass
        ldx fist_size
        lda fist_l,x
        sta act_sprl+2
        lda fist_h,x
        sta act_sprh+2
        lda #`SPR_FIST0
        sta act_sprb+2
        clc
        lda p_x
        adc #7
        sta act_xl2+2
        lda p_x+1
        adc #0
        sta act_xh2+2
        lda p_y
        sec
        sbc #19
        sec
        sbc fist_half,x
        sta act_y+2
        bra l_ab_fx_done
l_ab_notfist:
        cmp #1
        bne +
        #SETACT 2, SPR_ZZ
        bra l_ab_fx_done
+       cmp #2
        bne +
        #SETACT 2, SPR_NOTE
        bra l_ab_fx_done
+       #SETACT 2, SPR_HEART
l_ab_fx_done:
        ; --- food in the dog bowl ---
        lda bowl_full
        sta act_vis+3
        #SETACT 3, SPR_DOGFOOD
        lda #10
        sta act_xl2+3
        lda #0
        sta act_xh2+3
        sta act_flip+3
        lda #187
        sta act_y+3
        rts

actors_render:
        ; erase
        ldx #0
l_ar_erase:
        lda prev_valid,x
        beq +
        lda prev_cx0,x
        sta rc_x0
        lda prev_cy0,x
        sta rc_y0
        lda prev_cx1,x
        sta rc_x1
        lda prev_cy1,x
        sta rc_y1
        phx
        jsr restore_cells
        plx
        lda #0
        sta prev_valid,x
+       inx
        cpx #ACTORS
        bne l_ar_erase
        ; draw back to front: bowl, dog, sleeping head, person, effect
        ldx #3
        jsr l_ar_draw
        ldx #1
        jsr l_ar_draw
        ldx #4
        jsr l_ar_draw
        ldx #0
        jsr l_ar_draw
        ldx #5
        jsr l_ar_draw
        ldx #2
        jmp l_ar_draw

l_ar_draw:
        lda act_vis,x
        beq l_ard_out
        lda act_sprl,x
        sta spr_addr
        lda act_sprh,x
        sta spr_addr+1
        lda act_sprb,x
        sta spr_addr+2
        lda act_xl2,x
        sta spr_x
        lda act_xh2,x
        sta spr_x+1
        lda act_y,x
        sta spr_y
        lda act_flip,x
        sta spr_flip
        phx
        jsr draw_sprite
        plx
        bcs l_ard_out           ; off screen: nothing drawn, nothing to erase
        lda #1
        sta prev_valid,x
        lda spr_cx0
        sta prev_cx0,x
        lda spr_cy0
        sta prev_cy0,x
        lda spr_cx1
        sta prev_cx1,x
        lda spr_cy1
        sta prev_cy1,x
l_ard_out:
        rts
