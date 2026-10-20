;=======================================================================================
; The simulation: clock, needs, the little person's brain and body, the dog, and the
; actor renderer.
;
; Coordinates are native 320x200 pixels. The person's position is his feet
; (p_x = centre column, p_y = bottom row). Floors: 0 ground, 1 middle, 2 attic.
;=======================================================================================

FLOOR0_Y        = 190         ; mid-floor, behind the kitchen table's front legs
FLOOR1_Y        = 128         ; mid-floor
FLOOR2_Y        = 66          ; mid-floor
DOG_Y           = 194         ; the dog trots nearer the viewer than him

TICKS_PER_MIN   = 25        ; fast forward (F5): sim ticks per game minute

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
PM_JUMP         = 5         ; jumping jacks, facing you
PM_DANCE        = 6
PM_FRONT        = 7         ; facing out of the screen
PM_DOWNSTEP     = 8         ; coming down a front step block, facing you
PM_BEND         = 9         ; back to you, bent down looking for something
PM_BENDSIDE     = 10        ; side view, leaning forward (switching the TV)
PM_WASH         = 11        ; back to you at the sink, elbows working
PM_BACKSTAND    = 12        ; back to you, standing (putting things away)

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
A_READCHAIR     = 27        ; reading in the armchair (after the bookshelf)
A_FILES         = 28        ; looking through the filing cabinet
A_CHAT          = 29        ; comes to the front and talks to you
A_TVON          = 30        ; walks to the attic TV and switches it on
A_TVOFF         = 31        ; ...and off again
A_WASH          = 32        ; washes his hands at the bathroom sink
A_DELIVERY      = 33        ; answers the door and picks up a delivery
A_STOW          = 34        ; puts the delivery away
A_GETFOOD       = 35        ; cooking: a jar from the food cupboard
A_PREP          = 36        ;   ...preparing it at the counter
A_STOVEON       = 37        ;   ...the pot onto the stove
A_STOVEOFF      = 38        ;   ...and off again when it's done
A_SERVE         = 39        ;   ...dishing up at the counter (then A_MEAL)
A_FRIDGEGET     = 40        ;   ...sometimes something from the fridge too
A_DOGFOOD       = 41        ; a can from the dog-food cupboard (then A_FEEDDOG)
A_GETCUP        = 42        ; a cup from beside the sink (then A_DRINK)
A_CUPSINK       = 43        ; the cup back in the sink
A_ASKWATER      = 44        ; the bottle's dry: asks you for water
A_VACGET        = 45        ; (rare) the vacuum from the attic closet...
A_VACATTIC      = 46        ;   ...vacuums the attic
A_VACMID        = 47        ;   ...and the middle floor
A_VACPUT        = 48        ;   ...and puts it away
A_VACGROUND     = 49        ;   ...and the ground floor
A_LEASH         = 50        ; walking the dog: the leash on...
A_WALKOUT       = 51        ;   ...out of the front door and back
A_UNLEASH       = 52        ;   ...and the leash off
A_RECSTOP       = 53        ; stops the record (when asked)
A_VACPICK       = 54        ; back to the vacuum he left, picks it up
A_DISHES        = 55        ; washes up at the kitchen sink after eating
A_PHONECALL     = 56        ; rings someone up himself
A_COUNT         = 57

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
REQ_RECSTOP     = A_RECSTOP
REQ_DANCE       = A_DANCE
REQ_PIANO       = A_PIANO
REQ_CHANGE      = A_CHANGE
REQ_POOL        = A_POOL
REQ_CARDS       = A_CARDS
REQ_PETDOG      = A_PETDOG
REQ_FILES       = A_FILES
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

date_month:     .byte 1     ; set from the RTC on the title screen
date_day:       .byte 1
date_year:      .byte 87    ; two digits
clock_hour:     .byte 8
clock_min:      .byte 0
clock_tick:     .byte 0
minute_count:   .byte 0     ; free-running game-minute counter
rt_last:        .byte $FF   ; last RTC seconds byte seen ($FF = none yet)
rt_frames:      .byte 0     ; frames since it last changed
rt_secs:        .byte 0     ; seconds into the current minute
sleep_min:      .byte 0     ; minutes asleep this time (cap 255)

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
call_cd:        .byte 60        ; minutes until he might ring someone
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
        jsr clock_hands
        jmp shirt_pick

; The clock runs in real time, paced by the real-time clock's seconds (or,
; if the RTC isn't ticking, by counting 50 frames a second). Fast forward
; (F5) runs a game minute every TICKS_PER_MIN ticks instead.
sim_tick:
        lda fast_forward
        beq l_st_real
        inc clock_tick
        lda clock_tick
        cmp #TICKS_PER_MIN
        bcc l_st_go
        lda #0
        sta clock_tick
        jsr game_minute
        bra l_st_go
l_st_real:
        jsr realtime_tick
l_st_go:
        jsr alarm_tick
        jsr record_tick
        jsr cook_tick
        jsr person_update
        jsr dog_update
        jsr fx_update
        rts

realtime_tick:
        lda #<RTC_BASE
        sta ZSRC
        lda #>RTC_BASE
        sta ZSRC+1
        lda #`RTC_BASE
        sta ZSRC+2
        lda #RTC_BASE >> 24
        sta ZSRC+3
        ldz #0
        lda [ZSRC],z
        ldx rt_last
        cpx #$FF
        bne +
        sta rt_last             ; first look: just remember it
        rts
+       cmp rt_last
        beq l_rt_same
        sta rt_last
        lda #0
        sta rt_frames
        bra l_rt_sec
l_rt_same:
        inc rt_frames
        lda rt_frames
        cmp #75                 ; no RTC tick for 1.5 s: count frames instead
        bcc l_rt_out
        lda #25
        sta rt_frames
l_rt_sec:
        inc rt_secs
        lda rt_secs
        cmp #60
        bcc l_rt_out
        lda #0
        sta rt_secs
        jmp game_minute
l_rt_out:
        rts

; A = day of the week for the current date, 0 = Sunday .. 6 = Saturday
; (Sakamoto's method, years 2000-2099: the century terms come to 0 mod 7).
day_of_week:
        lda date_year
        ldx date_month
        cpx #3
        bcs +
        cmp #0
        beq +
        dec a                   ; January / February count with last year
+       sta l_dw_y
        lsr
        lsr
        clc
        adc l_dw_y
        adc dow_month-1,x
        adc date_day
-       cmp #7
        bcc +
        sbc #7
        bra -
+       rts
l_dw_y:     .byte 0
dow_month:  .byte 0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4

; A = the hour he goes to bed tonight: 21, or 23 on Friday and Saturday.
bedtime_hour:
        jsr day_of_week
        cmp #5
        bcc +
        lda #23
        rts
+       lda #21
        rts
; A = the hour he gets up: 7, or 8 at the weekend.
wake_hour:
        jsr day_of_week
        cmp #0
        beq +
        cmp #6
        beq +
        lda #7
        rts
+       lda #8
        rts
; C = 1 on a Friday or Saturday evening (from 19:00): a late night in.
weekend_evening:
        lda clock_hour
        cmp #19
        bcc +
        jsr day_of_week
        cmp #5
        rts                     ; C = 1 for 5 (Fri) and 6 (Sat)
+       clc
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
        jsr next_day
l_gm_hour:
        jsr lights_update
        ; the alarm clock: rings at his getting-up time if he's asleep
        jsr wake_hour
        cmp clock_hour
        bne l_gm_needs
        jsr person_sleeping
        bcc l_gm_needs
        jsr alarm_ring
l_gm_needs:
        jsr clock_hands         ; the office clock keeps time
        ; cooldowns
        ldx #complain_cd - complain_cd
        jsr l_gm_dec
        ldx #knock_cd - complain_cd
        jsr l_gm_dec
        ldx #letter_cd - complain_cd
        jsr l_gm_dec
        ldx #call_cd - complain_cd
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
        lda sleep_min
        cmp #255
        beq +
        inc sleep_min
+       lda minute_count
        and #15
        bne l_gm_dog
        lda #thirst - hunger
        jsr l_gm_up
        lda #0
        jsr l_gm_up
        bra l_gm_dog
l_gm_needs_awake:
        ; awake: thirst every 2 minutes, hunger every 6, the toilet's call
        lda minute_count
        and #1
        bne +
        lda wc_need
        cmp #255
        beq l_gm_wcfull
        inc wc_need
l_gm_wcfull:
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

; Midnight: the calendar moves on.
next_day:
        lda #0
        sta vac_done
        sta dog_walks
        sta meals_done
        sta showered
        sta dog_meals
        inc date_day
        ldx date_month
        lda month_days-1,x
        cpx #2
        bne l_nd_cmp
        tay
        lda date_year
        and #3
        bne +
        iny                     ; leap year February
+       tya
l_nd_cmp:
        cmp date_day
        bcs l_nd_out
        lda #1
        sta date_day
        inc date_month
        lda date_month
        cmp #13
        bcc l_nd_out
        lda #1
        sta date_month
        inc date_year
        lda date_year
        cmp #100
        bcc l_nd_out
        lda #0
        sta date_year
l_nd_out:
        rts
month_days: .byte 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31

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

outfit_rgb:     ; shirt, shirt shade, pants, far trouser leg, shirt dots, pants dots
        .byte 34,102,255, 17,51,170, 255,255,255, 170,170,170, 34,102,255, 255,255,255  ; day
        .byte 51,85,221, 34,51,153, 51,85,221, 34,51,153, 255,136,204, 255,136,204      ; pyjamas
        .byte 255,204,153, 230,170,120, 255,204,153, 221,160,110, 255,204,153, 255,204,153 ; nothing

; The stereo while a record plays: tone-arm shimmer, panel lights, power.
stereo_animate:
        lda record_left
        ora record_left+1
        bne l_sa_on
        ldx #C_SPIN_A           ; off: their house colours
-       jsr pal_own
        inx
        cpx #C_LED + 1
        bne -
        rts
l_sa_on:
        lda frame_count
        lsr
        lsr
        and #1
        sta l_sa_tg             ; 0/1: which shimmer entry is bright
        ldx #C_SPIN_A
        jsr l_sa_spin
        lda l_sa_tg
        eor #1
        sta l_sa_tg
        ldx #C_SPIN_B
        jsr l_sa_spin
        lda frame_count         ; panel lights: new levels a few times a second
        and #7
        bne l_sa_led
        jsr rnd
        sta l_sa_lv
        ldx #C_VU_R1
        lda #255
        sta l_sa_r
        lda #60
        sta pe_g
        sta pe_b
        lda l_sa_lv
        and #1
        jsr l_sa_light
        ldx #C_VU_R2
        lda l_sa_lv
        and #2
        jsr l_sa_light
        ldx #C_VU_B
        lda #60
        sta l_sa_r
        lda #140
        sta pe_g
        lda #255
        sta pe_b
        lda l_sa_lv
        and #4
        jsr l_sa_light
l_sa_led:
        lda #34
        sta pe_g                ; (set below)
        lda #0
        sta pe_b
        lda #238
        sta pe_g
        lda #34
        ldx #C_LED
        jmp pal_set
; l_sa_tg = 1: bright
l_sa_spin:
        lda #255
        sta pe_g
        sta pe_b
        ldy l_sa_tg
        bne +
        lda #119
        sta pe_g
        sta pe_b
+       jmp pal_set
; A != 0: lit, else dim (colour l_sa_r / pe_g / pe_b)
l_sa_light:
        bne +
        lsr pe_g
        lsr pe_g
        lsr pe_b
        lsr pe_b
        lda l_sa_r
        lsr
        lsr
        jsr pal_set
        asl pe_g                ; (restore for the next light)
        asl pe_g
        asl pe_b
        asl pe_b
        rts
+       lda l_sa_r
        jmp pal_set
l_sa_lv:    .byte 0
l_sa_tg:    .byte 0
l_sa_r:     .byte 0

; Palette entry X back to its own colour from the palette tables.
pal_own:
        lda pal_g,x
        sta pe_g
        lda pal_b,x
        sta pe_b
        lda pal_r,x
        jmp pal_set

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
        adc outfit
        asl
        tay                     ; 6 entries per outfit
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
        lda l_pa_o
        clc
        adc #4
        tay
        ldx #C_DOTS_SHIRT
        jsr pal_set_from
        lda l_pa_o
        clc
        adc #5
        tay
        ldx #C_DOTS_PANTS
        jsr pal_set_from
        jsr stereo_animate
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
        ; water bottle: five bands, each blue while the water reaches it
        ldx #0
-       phx
        txa
        asl
        cmp water               ; band i holds water while water > 2i
        bcs l_pan_dry
        lda #0
        sta pe_g
        lda #221
        sta pe_b
        lda #0
        bra l_pan_band
l_pan_dry:
        lda #221                ; empty: pale clear plastic
        sta pe_g
        lda #238
        sta pe_b
        lda #204
l_pan_band:
        pha
        txa
        clc
        adc #C_BOTTLE0
        tax
        pla
        jsr pal_set
        plx
        inx
        cpx #5
        bne -
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
        .byte 0, 0,0,0,0,0, 1,0,0, 1,1,1,1,1, 1,2, 2,2,2,2, 1,0,0, 0,0,0,0, 0, 2, 0, 2, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 1, 2, 0, 0, 0, 0, 2, 0, 0, 0
act_xl:
        .byte 0, <52,<122,<138,<28,<226, <252,<268,<302, <40,<113,<170,<196,<222, <278,<228
        .byte <108,<73,<76,<154, <83,<122,<122, <160,0,0,<300, <226, <266, 0, <62, <62, <177, <294, 0, <78, <58, <28, <28, <58, <52, <56, <82, <82, 0, <186, <186, <141, <186, <177, 0, <268, <268, <73, 0, <82, <226
act_xh:
        .byte 0, >52,>122,>138,>28,>226, >252,>268,>302, >40,>113,>170,>196,>222, >278,>228
        .byte >108,>73,>76,>154, >83,>122,>122, >160,0,0,>300, >226, >266, 0, >62, >62, >177, >294, 0, >78, >58, >28, >28, >58, >52, >56, >82, >82, 0, >186, >186, >141, >186, >177, 0, >268, >268, >73, 0, >82, >226
act_face:
        .byte 0, 0,1,1,0,0, 1,1,1, 0,0,0,1,1, 1,1, 0,0,0,0, 0,1,1, 0,0,0,0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0

act_start_tbl:
        .word st_none, st_fridge, st_meal, st_drink, st_feeddog, st_phone, st_read, st_fire
        .word st_goout, st_sleep, st_exercise, st_brush, st_wc, st_bath, st_computer
        .word st_letter, st_tv, st_record, st_dance, st_piano, st_change, st_pool
        .word st_cards, st_knock, st_idle, st_petdog, st_arrive, st_readchair, st_files, st_chat, st_tvswitch, st_tvswitch, st_wash, st_delivery, st_stow
        .word st_getfood, st_prep, st_stoveon, st_stoveoff, st_serve, st_fridgeget, st_dogfood
        .word st_getcup, st_cupsink, st_askwater
        .word st_vacget, st_vacsweep, st_vacsweep, st_vacput, st_vacsweep
        .word st_leash, st_walkout, st_unleash, st_recstop, st_vacpick, st_dishes, st_phonecall
act_tick_tbl:
        .word tk_none, tk_none, tk_meal, tk_drink, tk_feeddog, tk_phone, tk_none, tk_none
        .word tk_goout, tk_sleep, tk_none, tk_brush, tk_wc, tk_bath, tk_computer
        .word tk_typing, tk_none, tk_record, tk_none, tk_piano, tk_change, tk_pool
        .word tk_none, tk_knock, tk_none, tk_none, tk_arrive, tk_readchair, tk_files, tk_none, tk_none, tk_none, tk_none, tk_delivery, tk_stow
        .word tk_getfood, tk_prep, tk_stoveon, tk_stoveoff, tk_prep, tk_fridgeget, tk_dogfood
        .word tk_getcup, tk_cupsink, tk_none
        .word tk_vacget, tk_vacsweep, tk_vacsweep, tk_vacput, tk_vacsweep
        .word tk_leash, tk_walkout, tk_leash, tk_recstop, tk_vacpick, tk_none, tk_phonecall
act_end_tbl:
        .word en_none, en_fridge, en_meal, en_drink, en_feeddog, en_phone, en_read, en_fire
        .word en_goout, en_sleep, en_exercise, en_brush, en_wc, en_bath, en_computer
        .word en_letter, en_tv, en_record, en_dance, en_piano, en_change, en_pool
        .word en_cards, en_knock, en_none, en_petdog, en_arrive, en_readchair, en_files, en_chat, en_tvon, en_tvoff, en_wash, en_delivery, en_stow
        .word en_getfood, en_prep, en_stoveon, en_stoveoff, en_serve, en_fridgeget, en_dogfood
        .word en_getcup, en_none, en_none
        .word en_vacget, en_vacsweep, en_vacsweep, en_vacput, en_vacsweep
        .word en_leash, en_walkout, en_unleash, en_none, en_vacpick, en_dishes, en_phone

act_names:
        .word nm_none, nm_fridge, nm_meal, nm_drink, nm_feeddog, nm_phone, nm_read, nm_fire
        .word nm_goout, nm_sleep, nm_exercise, nm_brush, nm_wc, nm_bath, nm_computer
        .word nm_letter, nm_tv, nm_record, nm_dance, nm_piano, nm_change, nm_pool
        .word nm_cards, nm_knock, nm_none, nm_petdog, nm_arrive, nm_readchair, nm_files, nm_chat, nm_tv, nm_tvoff, nm_wash, nm_delivery, nm_stow
        .word nm_getfood, nm_prep, nm_cook, nm_stoveoff, nm_serve, nm_getfood, nm_feeddog
        .word nm_drink, nm_drink, nm_askwater
        .word nm_vacuum, nm_vacuum, nm_vacuum, nm_vacuum, nm_vacuum
        .word nm_dogwalk, nm_dogwalk, nm_dogwalk, nm_recstop, nm_vacuum, nm_dishes, nm_phonecall
nm_none:     .null " is pottering about."
nm_fridge:   .null " is getting some food."
nm_meal:     .null " is eating."
nm_drink:    .null " is having a drink."
nm_feeddog:  .null " is feeding the dog."
nm_phone:    .null " is on the phone."
nm_read:     .null " is picking out a book."
nm_readchair: .null " is reading a book."
nm_files:    .null " is rummaging in the filing cabinet."
nm_chat:     .null " is talking to you."
nm_tvoff:    .null " is switching off the TV."
nm_wash:     .null " is washing his hands."
nm_delivery: .null " is answering the door."
nm_stow:     .null " is putting the delivery away."
nm_askwater: .null " is asking you for water."
nm_vacuum:   .null " is vacuuming."
nm_dogwalk:  .null " is taking the dog for a walk."
nm_recstop:  .null " is stopping the record."
nm_dishes:   .null " is washing the dishes."
nm_phonecall: .null " is making a phone call."
nm_getfood:  .null " is fetching something to cook."
nm_prep:     .null " is getting a meal ready."
nm_cook:     .null " is cooking."
nm_stoveoff: .null " is taking the pot off the stove."
nm_serve:    .null " is dishing up."
nm_fire:     .null " is lighting a fire."
nm_goout:    .null " has gone out."
nm_sleep:    .null " is asleep. Zzz..."
nm_exercise: .null " is exercising."
nm_brush:    .null " is brushing his teeth."
nm_wc:       .null " is in the bathroom."
nm_bath:     .null " is taking a bath."
nm_computer: .null " is playing a video game."
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
        lda #A_SLEEP
        rts
l_ai_bed:
        lda outfit              ; pyjamas on first
        cmp #1
        beq l_ai_sleep
        lda #A_CHANGE
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
+       ; walkies, three times a day
        jsr dog_walk_due
        bcc +
        lda #1
        sta walk_stage
        lda #A_LEASH
        rts
+       ; a shower every morning, once breakfast is done
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
        lda dog_beg             ; the dog's begging: feed it
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
        jsr weekend_evening     ; Friday / Saturday night: often the TV
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
        cmp #A_DANCE
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
l_fun_list:
        .byte A_TV, A_TV, A_RECORD, A_PIANO, A_PIANO, A_READ, A_READ, A_COMPUTER
        .byte A_EXERCISE, A_POOL, A_READ, A_COMPUTER, A_IDLE, A_IDLE, A_IDLE, A_PETDOG
        .byte A_GOOUT, A_DANCE, A_IDLE, A_READ, A_CARDS, A_FILES, A_CHAT, A_VACGET
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
+       lda l_ra_req
        cmp #A_RECSTOP
        bne +
        lda record_left
        ora record_left+1
        bne +
        ldx #<say_norecord
        ldy #>say_norecord
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
        bcs l_dv_note
        lda #A_DELIVERY
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
        jsr alarm_play
        lda #ALARM_TIME
        sta alarm_t
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

l_say_gfood:   .null "Ding dong! Groceries at the door."
l_say_gwater:  .null "You topped up the water bottle."
l_say_gdog:    .null "Ding dong! Dog food at the door."
l_say_gbook:   .null "Ding dong! A parcel at the door."
l_say_grecord: .null "Ding dong! A parcel at the door."
l_say_pet:     .null "Hee hee, that tickles!"
l_say_ring:    .null "Ring ring! The phone is ringing."
l_say_ring2:   .null "Ring ring... he sleeps right through it."
l_say_midnight: .null "Hey! It's the middle of the night!"
l_say_morning: .null "Yawn... good morning!"

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
+       cmp #A_TV
        bne +
        ldx tv_on
        bne +
        lda #A_TVON             ; it's off: go and switch it on first
+       sta p_goal
        tax
        jsr vac_maybe_park
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
+       cpx #A_VACPICK
        bne +
        lda park_floor
        sta goal_floor
        lda park_x
        sta goal_x
        lda park_x+1
        sta goal_x+1
        jmp l_pc_go
+       cpx #A_LEASH
        bne ++
        lda #0
        sta goal_floor
        sec                     ; just to the dog's left
        lda dog_x
        sbc #DOG_LEAD_DX
        sta goal_x
        lda dog_x+1
        sbc #0
        sta goal_x+1
        bcs +
        lda #20                 ; (not off the left of the house)
        sta goal_x
        lda #0
        sta goal_x+1
+       lda #1                  ; (the dog stays put for him)
        sta dog_hold
        lda #2
        sta dog_state
        jmp l_pc_go
+       cpx #A_STOW
        bne +
        ldy delivery
        lda stow_floor-1,y
        sta goal_floor
        lda stow_x-1,y
        sta goal_x
        lda #0
        sta goal_x+1
        bra l_pc_go
+       cpx #A_CHAT
        beq l_pc_front
        cpx #A_ASKWATER
        beq l_pc_front
        cpx #A_KNOCK
        bne +
l_pc_front:
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
        lda dog_floor           ; (whichever floor it's on)
        sta goal_floor
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
        lda #0                  ; the plate is on the table
        sta held
        lda cook_stage
        cmp #7
        bne +
        lda #0
        sta cook_stage
+       #POSE SPR_EAT, POSE_EAT_X, POSE_EAT_Y
        lda #7
        jmp set_timer_secs
; chew (mouth open/shut), and every couple of seconds a bite: hand to mouth
tk_meal:
        lda p_anim
        and #127
        cmp #24
        bcs l_tkm_chew
        lda #<SPR_EATHAND
        ldx #>SPR_EATHAND
        bra l_tkm_set
l_tkm_chew:
        lda p_anim
        and #8
        bne +
        lda #<SPR_EATSHUT
        ldx #>SPR_EATSHUT
        bra l_tkm_set
+       lda #<SPR_EAT
        ldx #>SPR_EAT
l_tkm_set:
        sta pose_spr
        stx pose_spr+1
        rts
en_meal:
        lda #0
        sta hunger
        lda #1
        sta brush_todo
        lda #HELD_PLATEE        ; the empty plate to the sink
        sta held
        lda #A_DISHES
        sta p_pending
        lda #3
        jsr mood_up
        #SAY l_say_yum
        rts

; Washing up: at the kitchen sink, back to you, hands busy, the tap running.
HELD_PLATEE     = 8
DISH_CLOSE      = 5             ; he steps right up to the sink
st_dishes:
        lda #PM_BACKSTAND
        sta p_mode
        lda p_y
        sec
        sbc #DISH_CLOSE
        sta p_y
        lda #0                  ; (in the sink)
        sta held
        lda #COUNTER_HANDS_Y - DISH_CLOSE
        jsr hands_rummage
        lda #$90                ; the tap
        sta shower_pitch
        lda #1
        sta shower_on
        lda #5
        jmp set_timer_secs
en_dishes:
        lda #FLOOR0_Y           ; back out to the middle of the floor
        sta p_y
        lda #0
        sta shower_on
        sta held
        lda #$C0
        sta shower_pitch
        lda #PM_STAND
        sta p_mode
        lda #1
        jmp mood_up
; A drink of water: a cup from beside the sink, filled at the cooler (the
; bottle's level drops), drunk facing you with the cup tipped up, then back
; in the sink. A dry bottle makes him glum; the third time running he asks
; you for water, out loud or in a letter.
drink_stage:    .byte 0     ; 0 none, 1 cup in hand (to the cooler), 2 cup to the sink
drink_act:      .byte 0, A_DRINK, A_CUPSINK
drinking:       .byte 0     ; 1 = cup at his lips (front view)
dry_count:      .byte 0     ; dry bottles in a row
ask_water:      .byte 0     ; 1 = ask for water once the cup's put away
dk_t:           .byte 0
HELD_CUP        = 5
HELD_CUPFULL    = 6

; Thirsty: off for a drink? C = 1 with A = what to do. Not back to a dry
; bottle more than every half hour or so.
drink_go:
        lda water
        bne +
        lda complain_cd
        beq +
        clc
        rts
+       lda #A_GETCUP
        sec
        rts

st_getcup:
        lda #PM_BACKSTAND
        sta p_mode
        lda #0
        sta dk_t
        lda #1
        jmp set_timer_secs
tk_getcup:
        inc dk_t
        lda dk_t
        cmp #25
        bne +
        lda #HELD_CUP
        sta held
        lda #1
        sta drink_stage
        lda #SFX_TINK
        jmp sfx_play
+       rts
en_getcup:
        lda drink_stage
        cmp #1
        bne +
        lda #A_DRINK
        sta p_pending
+       rts

st_drink:
        lda #0
        sta dk_t
        lda #1                  ; facing the cooler
        sta p_flip
        lda #5
        jmp set_timer_secs
tk_drink:
        inc dk_t
        lda dk_t
        cmp #15                 ; fill the cup
        bne l_tkdr_1
        lda held
        cmp #HELD_CUPFULL
        beq l_tkdr_out          ; (already filled)
        lda water
        bne +
        jmp drink_dry
+       dec water
        lda #1
        sta ui_dirty
        lda #HELD_CUPFULL
        sta held
        lda #SFX_GLUG
        jmp sfx_play
l_tkdr_1:
        cmp #70                 ; turn round and drink
        bne +
        lda #PM_FRONT
        sta p_mode
        lda #1
        sta drinking
        lda #SFX_GLUG
        jmp sfx_play
+       cmp #200                ; ahh
        bne l_tkdr_out
        lda #0
        sta drinking
        sta thirst
        sta dry_count
        lda #PM_STAND
        sta p_mode
        lda #HELD_CUP
        sta held
        lda #2
        sta drink_stage
        lda #1
        sta ui_dirty
l_tkdr_out:
        rts
; the bottle's dry: glum, and after a few times, ask
drink_dry:
        lda #3
        jsr mood_down
        lda #30                 ; not back for a while
        sta complain_cd
        lda #2
        sta drink_stage
        inc dry_count
        lda dry_count
        cmp #3
        bcc +
        lda #0
        sta dry_count
        lda #1
        sta ask_water
+       lda #0                  ; that's that
        sta act_timer
        sta act_timer+1
        #SAY l_say_dry
        rts
en_drink:
        lda #0
        sta drinking
        lda #PM_STAND
        sta p_mode
        lda drink_stage
        cmp #2
        bne +
        lda #A_CUPSINK
        sta p_pending
+       rts

st_cupsink:
        lda #PM_BACKSTAND
        sta p_mode
        lda #0
        sta dk_t
        lda #1
        jmp set_timer_secs
tk_cupsink:
        inc dk_t
        lda dk_t
        cmp #25
        bne l_tkcs_out
        lda #0                  ; in the sink
        sta held
        sta drink_stage
        lda #SFX_TINK
        jsr sfx_play
        lda ask_water           ; and now: please, some water
        beq l_tkcs_out
        lda #0
        sta ask_water
        lda #A_ASKWATER
        sta p_pending
        jsr rnd
        and #1
        beq l_tkcs_out
        lda #A_LETTER           ; (or a letter about it)
        sta p_pending
l_tkcs_out:
        rts

st_askwater:
        lda #PM_FRONT
        sta p_mode
        #SAY l_say_needwater
        jsr speak
        lda #4
        jmp set_timer_secs
l_say_dry:       .null "Empty! Not a drop left..."
l_say_needwater: .null "I'm SO thirsty! Could you fill my water bottle? (CTRL-W)"
; Feeding the dog: a can from the dog-food cupboard (one fewer on the shelf),
; then beside the stove he leans down and fills the bowl.
st_dogfood:
        lda #PM_BACKSTAND
        sta p_mode
        lda #0
        sta ck_t
        lda #1
        sta cb_which
        lda #3
        jmp set_timer_secs
tk_dogfood:
        inc ck_t
        lda ck_t
        cmp #2
        bne +
        lda #SFX_DOOR
        jsr sfx_play
        jmp cupboard_show
+       cmp #60
        bne +
        lda dogfood
        beq l_tkdf_out
        dec dogfood
        lda #1
        sta ui_dirty
        lda #HELD_CAN
        sta held
        jmp cupboard_show
+       cmp #110
        bne l_tkdf_out
        jmp cupboard_close
l_tkdf_out:
        rts
en_dogfood:
        jsr cupboard_close
        lda held
        cmp #HELD_CAN
        bne +
        lda #A_FEEDDOG
        sta p_pending
+       rts

st_feeddog:
        lda #0
        sta ck_t
        sta p_flip              ; facing the bowl
        lda held                ; (asked to feed it with no can in hand: one
        cmp #HELD_CAN           ;  from the cupboard, unseen)
        beq +
        lda dogfood
        beq +
        dec dogfood
        lda #HELD_CAN
        sta held
        lda #1
        sta ui_dirty
+       lda #3
        jmp set_timer_secs
tk_feeddog:
        inc ck_t
        lda ck_t
        cmp #20                 ; down to the bowl
        bne +
        lda #PM_BENDSIDE
        sta p_mode
        rts
+       cmp #60                 ; tip it in
        bne +
        lda held
        cmp #HELD_CAN
        bne l_tkfd_out
        lda #0
        sta held
        lda #1
        sta bowl_full
        lda #SFX_CLACK
        jmp sfx_play
+       cmp #100
        bne l_tkfd_out
        lda #PM_STAND
        sta p_mode
l_tkfd_out:
        rts
en_feeddog:
        lda #PM_STAND
        sta p_mode
        lda bowl_full
        beq +
        #SAY l_say_goodboy
+       rts

; --- living room -----------------------------------------------------------------------
; On the phone (as in the Amiga original): in the armchair facing you, the
; handset to his ear, the phone on the side table showing its empty cradle.
; He chatters in his own language -- the sampled voice from the original --
; mouth moving with it, pauses to listen, chatters again.
phone_talk:     .byte 0     ; 1 = mouth open this moment
phone_spells:   .byte 0

st_phone:
        #POSE SPR_PHONE0, POSE_CHAIR_X, POSE_CHAIR_Y
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
l_call1:        .null ": Hello, Mom? It's me!"
l_call2:        .null ": Hi! Just calling to say hello."
l_call3:        .null ": Hello, is that the library? About my book..."
l_call4:        .null ": Hey, buddy! Long time no talk!"
l_call5:        .null ": Hello? Is your refrigerator running?"
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

st_read:
        lda #PM_BEND            ; bent over the shelf, looking for a good one
        sta p_mode
        lda #114                ; hands along the bottom shelf
        jsr hands_rummage
        lda #3
        jmp set_timer_secs
en_read:
        lda #SFX_CLACK
        jsr sfx_play
        lda #A_READCHAIR
        sta p_pending
        rts
st_readchair:
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
        jmp talk_stop

; Now and then he comes to the front, faces you and chats (in his own
; language, with the words on the top line).
st_chat:
        lda #PM_FRONT
        sta p_mode
        jsr speak
        lda #8
        jsr rnd_range
        asl
        tax
        lda chat_lines,x
        sta l_ch_p
        lda chat_lines+1,x
        sta l_ch_p+1
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
l_say_deal:  .null "Great! I'll deal!"
l_say_there: .null "Oh good, you ARE there!" 
st_petdog:
        jsr fx_heart_on_person
        lda #3
        jmp set_timer_secs
en_petdog:
        lda #3
        jsr mood_up
        jmp bark_play

; --- middle floor ----------------------------------------------------------------------
st_sleep:
        lda #0
        sta sleep_min
        lda #PM_HIDDEN
        sta p_mode
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
+       ; otherwise wake in the daytime: in the morning, or after a nap of an
        ; hour (or once rested)
        jsr wake_hour           ; (at his getting-up hour the alarm wakes him)
        cmp clock_hour
        beq l_tks_out
        bcs l_tks_out
        jsr bedtime_hour
        cmp clock_hour
        beq l_tks_out
        bcc l_tks_out
        lda sleep_min
        cmp #60
        bcs l_tks_wake
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
        lda #WC_EVERY           ; first thing: the toilet
        sta wc_need
        lda outfit              ; up out of pyjamas: get dressed
        cmp #1
        bne +
        lda #1
        sta dress_todo
+
        lda #PM_STAND
        sta p_mode
        rts
st_exercise:
        lda #PM_JUMP
        sta p_mode
        lda #10
        jmp set_timer_secs
en_exercise:
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
; scrub up and down, a little "shh" on each stroke
tk_brush:
        lda p_anim
        and #4
        tay
        lda #<SPR_BRUSH
        ldx #>SPR_BRUSH
        cpy #0
        beq +
        lda #<SPR_BRUSHUP
        ldx #>SPR_BRUSHUP
+       sta pose_spr
        stx pose_spr+1
        lda p_anim              ; a "chhh" on every stroke, up and down
        and #3
        bne +
        lda #SFX_BRUSH
        jsr sfx_play
+       rts
en_brush:
        lda #1
        jmp mood_up
; The toilet: the WC door opens, he steps in behind it, it closes; a while
; later (and a flush) it opens, he steps out, it closes; then he washes up.
wc_t:           .byte 0

; The toilet about three times a day: first thing, then every five hours.
WC_EVERY        = 150           ; in 2-minute steps: five hours
wc_need:        .byte 0
showered:       .byte 0         ; 1 = had today's shower
st_wc:
        lda #0
        sta wc_need
        ldx #PATCH_WC
        jsr patch_apply
        lda #SFX_DOOR
        jsr sfx_play
        lda #0
        sta wc_t
        lda #6
        jmp set_timer_secs
tk_wc:
        lda wc_t
        cmp #255
        beq +
        inc wc_t
+       lda wc_t
        cmp #20                 ; steps in
        bne +
        lda #PM_HIDDEN
        sta p_mode
        rts
+       cmp #32                 ; door shut behind him
        bne +
        ldx #PATCH_WC
        jmp patch_remove
+       ; the way out, counted down from the end of the visit
        lda act_timer+1
        bne l_tkw_out
        lda act_timer
        cmp #140
        bne +
        jmp flush_play
+       cmp #50                 ; door opens
        bne +
        ldx #PATCH_WC
        jsr patch_apply
        lda #SFX_DOOR
        jmp sfx_play
+       cmp #38                 ; he steps out
        bne +
        lda #PM_STAND
        sta p_mode
        rts
+       cmp #16                 ; and the door closes
        bne l_tkw_out
        ldx #PATCH_WC
        jmp patch_remove
l_tkw_out:
        rts
en_wc:
        ldx #PATCH_WC           ; (in case he was interrupted)
        jsr patch_remove
        lda #A_WASH             ; then wash his hands
        sta p_pending
        rts

; Deliveries. He opens the front door, bends to pick the package up off the
; step, carries it in front of him, and puts it where it belongs (facing it:
; cupboard, low cabinet, bookshelf, record player). Food and dog food go into
; the supplies then; a book gets read, a record played.
DLV_FOOD        = 1
DLV_DOG         = 2
DLV_BOOK        = 3
DLV_RECORD      = 4
delivery:       .byte 0     ; what's on the step / in his hands (0 = nothing)
carrying:       .byte 0     ; 1 = in his hands
dlv_t:          .byte 0
;                 food  dog   book  record
stow_floor:     .byte 0,    0,    1,    2
stow_x:         .byte 78,   56,   252,  74
stow_bend:      .byte 0,    0,    0,    1
stow_px:        .byte 74,   52,   248,  70     ; where the package sits as he puts it away
stow_py:        .byte 150,  150,  104,  45
pkg_l:          .byte <SPR_PKGFOOD, <SPR_PKGDOG, <SPR_PKGBOOK, <SPR_PKGRECORD
pkg_h:          .byte >SPR_PKGFOOD, >SPR_PKGDOG, >SPR_PKGBOOK, >SPR_PKGRECORD

st_delivery:
        ldx #PATCH_DOOR
        jsr patch_apply
        lda #SFX_DOOR
        jsr sfx_play
        lda #0
        sta dlv_t
        lda #1
        sta p_flip              ; facing out of the door
        lda #3
        jmp set_timer_secs
tk_delivery:
        inc dlv_t
        lda dlv_t
        cmp #30                 ; bend down for it
        bne +
        lda #PM_BENDSIDE
        sta p_mode
        rts
+       cmp #80                 ; picked up: straighten, in his hands
        bne +
        lda #PM_STAND
        sta p_mode
        lda #1
        sta carrying
        rts
+       cmp #110
        bne +
        ldx #PATCH_DOOR         ; shut the door
        jmp patch_remove
+       rts
en_delivery:
        ldx #PATCH_DOOR
        jsr patch_remove
        lda #1
        sta carrying
        lda #A_STOW
        sta p_pending
        rts

st_stow:
        lda #0
        sta dlv_t
        lda #PM_BACKSTAND
        ldx delivery
        ldy stow_bend-1,x
        beq +
        lda #PM_BEND
+       sta p_mode
        lda #0
        sta carrying            ; now on the shelf / in the cupboard
        lda #2
        ldx delivery
        cpx #DLV_DOG + 1
        bcs +
        dex                     ; groceries / dog food: open up, put it in, close
        stx cb_which
        lda #3
+       jmp set_timer_secs
; Groceries / dog food: the cupboard doors open on the jars (cans) already
; there, the bag goes in and becomes one more (the supply goes up), the doors
; close.
cb_which:       .byte 0     ; 0 food cupboard, 1 dog-food cupboard
tk_stow:
        inc dlv_t
        lda delivery
        beq +                   ; (already put in: it's on the shelf)
        cmp #DLV_DOG + 1
        bcc +
        rts
+       lda dlv_t
        cmp #2
        bne +
        lda #SFX_DOOR
        jsr sfx_play
        jmp cupboard_show
+       cmp #60
        bne +
        lda delivery            ; in: now it's food on the shelf
        jsr delivery_apply
        lda #0
        sta delivery
        jmp cupboard_show
+       cmp #120
        bne l_tkst_out
        jmp cupboard_close
l_tkst_out:
        rts
en_stow:
        jsr cupboard_close
        lda delivery
        beq +
        jsr delivery_apply
+       lda #0
        sta delivery
        sta carrying
        rts

; Show the cupboard open with a jar (can) for every two food (dog food),
; at most 4.
cupboard_show:
        jsr cupboard_forget
        lda food
        ldx cb_which
        beq +
        lda dogfood
+       clc
        adc #1
        lsr
        cmp #5
        bcc +
        lda #4
+       ldx cb_which
        beq +
        clc
        adc #PATCH_DOGCAB - PATCH_CUPBOARD
+       clc
        adc #PATCH_CUPBOARD
        tax
        jmp patch_apply
; Shut it (whichever jar picture is up).
cupboard_close:
        ldx #PATCH_CUPBOARD
-       phx
        jsr patch_remove
        plx
        inx
        cpx #PATCH_DOGCAB + 5
        bne -
        rts
; The new picture overwrites the old one: just mark them all as not shown.
cupboard_forget:
        lda #0
        ldx #9
-       sta patch_state + PATCH_CUPBOARD,x
        dex
        bpl -
        rts

; A = delivery type: it's in the house now
delivery_apply:
        cmp #DLV_FOOD
        bne +
        lda food
        clc
        adc #3
        cmp #10
        bcc l_da_food
        lda #9
l_da_food:
        sta food
        lda gift_flags
        ora #4
        sta gift_flags
        lda #1
        sta ui_dirty
        lda #3
        jmp mood_up
+       cmp #DLV_DOG
        bne +
        lda dogfood
        clc
        adc #3
        cmp #10
        bcc l_da_dog
        lda #9
l_da_dog:
        sta dogfood
        lda #1
        sta ui_dirty
        rts
+       cmp #DLV_BOOK
        bne +
        lda gift_flags
        ora #1
        sta gift_flags
        lda #8
        jsr mood_up
        lda #A_READCHAIR        ; a new book: read it
        sta p_pending
        rts
+       lda gift_flags          ; a record: play it
        ora #2
        sta gift_flags
        lda #8
        jsr mood_up
        lda #A_RECORD
        sta p_pending
        rts

; Cooking. At mealtimes he takes a jar from the food cupboard, prepares it at
; the counter, puts the pot on the stove (a flame under it) and goes off while
; it cooks; then the pot comes off, he dishes up at the counter and carries
; the plate to the table. cook_stage says which step is next, so he picks up
; where he left off if something interrupts him.
cook_stage:     .byte 0     ; 0 none, 1 get food, 2 prep, 3 stove on,
                            ; 4 cooking, 5 stove off, 6 serve, 7 eat
cook_act:       .byte 0, A_GETFOOD, A_PREP, A_STOVEON, 0, A_STOVEOFF, A_SERVE, A_MEAL
cook_left:      .word 0     ; frames until it's done
COOK_FRAMES     = 1500      ; about half a minute
meals_done:     .byte 0     ; today: bit 0 breakfast, 1 lunch, 2 dinner
ck_t:           .byte 0
held:           .byte 0     ; in his hands: 0 nothing, 1 jar, 2 pot, 3 plate
HELD_JAR        = 1
HELD_POT        = 2
HELD_PLATE      = 3
HELD_CAN        = 4
held_l:         .byte <SPR_HELDJAR, <SPR_HELDPOT, <SPR_HELDPLATE, <SPR_HELDCAN, <SPR_HELDCUP, <SPR_HELDCUPFULL, <SPR_HELDVAC, <SPR_HELDPLATEE
held_h:         .byte >SPR_HELDJAR, >SPR_HELDPOT, >SPR_HELDPLATE, >SPR_HELDCAN, >SPR_HELDCUP, >SPR_HELDCUPFULL, >SPR_HELDVAC, >SPR_HELDPLATEE
COUNTER_HANDS_Y = 174         ; just above his waist

; C = 1 if it's time for a meal he hasn't had today (and marks it had):
; breakfast until 10, lunch 12-2, dinner 6-8.
meal_due:
        lda clock_hour
        ldx #1
        cmp #10
        bcc l_md_check
        ldx #2
        cmp #12
        bcc l_md_no
        cmp #14
        bcc l_md_check
        ldx #4
        cmp #18
        bcc l_md_no
        cmp #20
        bcs l_md_no
l_md_check:
        txa
        and meals_done
        bne l_md_no
        txa
        ora meals_done
        sta meals_done
        sec
        rts
l_md_no:
        clc
        rts

; every sim tick: the pot cooks
cook_tick:
        lda cook_left
        ora cook_left+1
        beq l_ckt_out
        lda cook_left
        bne +
        dec cook_left+1
+       dec cook_left
        lda cook_left
        ora cook_left+1
        bne l_ckt_out
        lda cook_stage          ; done: time to take it off
        cmp #4
        bne l_ckt_out
        lda #5
        sta cook_stage
l_ckt_out:
        rts

; 1: a jar from the food cupboard (one fewer on the shelf)
st_getfood:
        lda #PM_BACKSTAND
        sta p_mode
        lda #0
        sta ck_t
        sta cb_which
        lda #3
        jmp set_timer_secs
tk_getfood:
        inc ck_t
        lda ck_t
        cmp #2
        bne +
        lda #SFX_DOOR
        jsr sfx_play
        jmp cupboard_show
+       cmp #60
        bne +
        lda food                ; take one
        beq l_tkg_out
        dec food
        lda #1
        sta ui_dirty
        lda #HELD_JAR
        sta held
        lda #2
        sta cook_stage
        jmp cupboard_show
+       cmp #110
        bne l_tkg_out
        jmp cupboard_close
l_tkg_out:
        rts
en_getfood:
        jsr cupboard_close
        lda cook_stage
        cmp #1
        bne +
        lda #0                  ; nothing in the cupboard after all
        sta cook_stage
        jmp complain_food
+       jsr rnd                 ; half the time: something from the fridge too
        and #1
        beq +
        lda #A_FRIDGEGET
        sta p_pending
+       rts

; the fridge door opens, he reaches in, it shuts
st_fridgeget:
        ldx #PATCH_FRIDGE
        jsr patch_apply
        lda #SFX_DOOR
        jsr sfx_play
        lda #0
        sta ck_t
        lda #2
        jmp set_timer_secs
tk_fridgeget:
        inc ck_t
        lda ck_t
        cmp #30                 ; reaching in
        bne +
        lda #PM_BENDSIDE
        sta p_mode
        rts
+       cmp #65
        bne +
        lda #PM_STAND
        sta p_mode
        rts
+       cmp #80
        bne +
        ldx #PATCH_FRIDGE
        jmp patch_remove
+       rts
en_fridgeget:
        ldx #PATCH_FRIDGE
        jmp patch_remove

; 2 and 6: at the counter, his hands busy (chopping, then dishing up)
st_prep:
        lda #PM_BACKSTAND
        sta p_mode
        lda #0
        sta held                ; (it's on the counter now)
        sta ck_t
        lda #COUNTER_HANDS_Y
        jsr hands_rummage
        lda #3
        jmp set_timer_secs
tk_prep:
        inc ck_t
        lda ck_t
        and #15
        bne +
        lda #SFX_CLACK          ; chop, chop
        jmp sfx_play
+       rts
en_prep:
        lda ck_t
        cmp #140
        bcc +
        lda #HELD_POT           ; ready for the stove
        sta held
        lda #3
        sta cook_stage
        lda #A_STOVEON
        sta p_pending
        rts
+       lda #HELD_JAR           ; (interrupted: still to do)
        sta held
        rts
st_serve:
        lda #PM_BACKSTAND
        sta p_mode
        lda #0
        sta held
        sta ck_t
        lda #COUNTER_HANDS_Y
        jsr hands_rummage
        lda #3
        jmp set_timer_secs
en_serve:
        lda ck_t
        cmp #140
        bcc +
        lda #HELD_PLATE         ; dinner is served
        sta held
        lda #7
        sta cook_stage
        lda #A_MEAL
        sta p_pending
        rts
+       lda #HELD_POT
        sta held
        rts

; 3: the pot onto the stove, flame lit; off he goes while it cooks
st_stoveon:
        lda #0
        sta ck_t
        sta p_flip              ; facing the stove
        lda #2
        jmp set_timer_secs
tk_stoveon:
        inc ck_t
        lda ck_t
        cmp #30
        bne +
        lda #0
        sta held
        ldx #PATCH_POT
        jsr patch_apply
        lda #4
        sta cook_stage
        lda #<COOK_FRAMES
        sta cook_left
        lda #>COOK_FRAMES
        sta cook_left+1
        lda #SFX_CLACK
        jmp sfx_play
+       rts
en_stoveon:
        lda #PM_STAND
        sta p_mode
        rts

; 5: done: the pot off the stove, to the counter
st_stoveoff:
        lda #0
        sta ck_t
        sta p_flip
        lda #2
        jmp set_timer_secs
tk_stoveoff:
        inc ck_t
        lda ck_t
        cmp #30
        bne +
        ldx #PATCH_POT
        jsr patch_remove
        lda #HELD_POT
        sta held
        lda #6
        sta cook_stage
        lda #SFX_CLACK
        jmp sfx_play
+       rts
en_stoveoff:
        lda #PM_STAND
        sta p_mode
        lda cook_stage
        cmp #6
        bne +
        lda #A_SERVE
        sta p_pending
+       rts

; Vacuuming (now and then): the vacuum cleaner from the attic closet, back
; and forth over the attic floor and the middle floor with it humming, then
; back in the closet.
vac_stage:      .byte 0     ; 0 none, 1 fetch, 2 attic, 3 middle floor,
                            ; 4 ground floor, 5 put away
vac_act:        .byte 0, A_VACGET, A_VACATTIC, A_VACMID, A_VACGROUND, A_VACPUT
vac_done:       .byte 0     ; 1 = done today
vac_t:          .byte 0
vac_lo:         .byte 0     ; this floor's sweep: from, to, passes left
vac_hi:         .byte 0
vac_pass:       .byte 0
HELD_VAC        = 7
vac_parked:     .byte 0     ; 1 = left standing where he was
park_floor:     .byte 0
park_x:         .word 0
park_flip:      .byte 0

; X = what he's about to do. Anything but the vacuuming while he has the
; vacuum: he leaves it standing where he is (and comes back for it).
vac_maybe_park:
        lda held
        cmp #HELD_VAC
        bne l_vmp_out
        cpx #A_VACGET
        bcc +
        cpx #A_VACGROUND + 1
        bcc l_vmp_out           ; (45..49: the vacuuming itself)
+       cpx #A_VACPICK
        beq l_vmp_out
        lda #1
        sta vac_parked
        lda p_floor
        sta park_floor
        lda p_x
        sta park_x
        lda p_x+1
        sta park_x+1
        lda p_flip
        sta park_flip
        lda #0
        sta held
l_vmp_out:
        rts

; back at the vacuum: bend, take hold of it, carry on
st_vacpick:
        lda park_flip
        sta p_flip
        lda #PM_BENDSIDE
        sta p_mode
        lda #0
        sta vac_t
        lda #1
        jmp set_timer_secs
tk_vacpick:
        inc vac_t
        lda vac_t
        cmp #25
        bne +
        lda #HELD_VAC
        sta held
        lda #0
        sta vac_parked
        lda #PM_STAND
        sta p_mode
+       rts
en_vacpick:
        lda #PM_STAND
        sta p_mode
        lda vac_parked          ; (interrupted before he got it: still there)
        bne +
        lda #HELD_VAC
        sta held
+       rts
;                 ground  middle (up to the bed)  attic (between the slopes)
vac_lo_tbl:     .byte 40,     74,                     36
vac_hi_tbl:     .byte 250,    250,                    250
VAC_PITCH       = $28       ; the hum: low noise

st_vacget:
        lda #1
        sta vac_stage
        lda #PM_BACKSTAND
        sta p_mode
        lda #0
        sta vac_t
        ldx #PATCH_VACCLOSET
        jsr patch_apply
        lda #SFX_DOOR
        jsr sfx_play
        lda #3
        jmp set_timer_secs
tk_vacget:
        inc vac_t
        lda vac_t
        cmp #60                 ; out it comes
        bne +
        lda #HELD_VAC
        sta held
        lda #2
        sta vac_stage
        ldx #PATCH_VACCLOSET + 1
        jmp patch_apply
+       cmp #120
        bne +
        jmp vac_closet_shut
+       rts
en_vacget:
vac_closet_shut:
        ldx #PATCH_VACCLOSET    ; (both pictures: whichever is up)
        jsr patch_remove
        ldx #PATCH_VACCLOSET + 1
        jmp patch_remove

; 2, 3: back and forth across the floor, twice over, humming
st_vacsweep:
        lda held
        cmp #HELD_VAC
        beq +
        lda #0                  ; (lost it somehow: put it away)
        sta vac_stage
        lda #1
        jmp set_timer_secs
+       ldx p_floor             ; this floor's stretch (the vacuum's head
        lda vac_lo_tbl,x        ;  runs 15px ahead of him)
        sta vac_lo
        lda vac_hi_tbl,x
        sta vac_hi
        lda #3
        sta vac_pass
        lda #PM_WALK
        sta p_mode
        lda #VAC_PITCH
        sta shower_pitch
        lda #1
        sta shower_on
        lda #60
        jmp set_timer_secs
tk_vacsweep:
        lda vac_pass
        bne +
        rts
+       lda p_anim              ; a step every other frame
        and #1
        bne l_tkv_out
        lda p_flip
        bne l_tkv_right
        lda p_x                 ; left
        cmp vac_lo
        bcc l_tkv_turn
        beq l_tkv_turn
        dec p_x
        rts
l_tkv_right:
        lda p_x
        cmp vac_hi
        bcs l_tkv_turn
        inc p_x
        rts
l_tkv_turn:
        lda p_flip
        eor #1
        sta p_flip
        dec vac_pass
        bne l_tkv_out
        lda #0                  ; this floor's done
        sta act_timer
        sta act_timer+1
        lda vac_stage
        clc
        adc #1
        sta vac_stage
l_tkv_out:
        rts
en_vacsweep:
        lda #0
        sta shower_on
        lda #$C0
        sta shower_pitch
        lda #PM_STAND
        sta p_mode
        rts

; 4: back in the closet
st_vacput:
        lda #PM_BACKSTAND
        sta p_mode
        lda #0
        sta vac_t
        ldx #PATCH_VACCLOSET + 1
        jsr patch_apply
        lda #SFX_DOOR
        jsr sfx_play
        lda #3
        jmp set_timer_secs
tk_vacput:
        inc vac_t
        lda vac_t
        cmp #60                 ; in it goes
        bne +
        lda #0
        sta held
        sta vac_stage
        lda #1
        sta vac_done
        ldx #PATCH_VACCLOSET + 1
        jsr patch_remove
        ldx #PATCH_VACCLOSET
        jmp patch_apply
+       cmp #120
        bne +
        jmp vac_closet_shut
+       rts
en_vacput:
        jmp vac_closet_shut

; Walking the dog, three times a day: he bends to clip the leash on, the
; dog leads him to the front door, out they go; back a while later, and the
; leash comes off.
walk_stage:     .byte 0     ; 0 none, 1 leash on, 2 out, 3 leash off
walk_act:       .byte 0, A_LEASH, A_WALKOUT, A_UNLEASH
dog_walks:      .byte 0     ; today: bits 0 morning, 1 afternoon, 2 evening
dog_lead:       .byte 0     ; 1 = on the lead
dog_hold:       .byte 0     ; 1 = staying put for him
dog_out:        .byte 0     ; 1 = outside
lead_t:         .byte 0
DOG_LEAD_DX     = 24        ; the dog this far ahead of him

; C = 1 at walk time (9-11am, 2-4pm, 7-9pm) if not walked then (and marks
; it); only with the dog in, and not begging or eating.
dog_walk_due:
        lda dog_floor           ; (it's downstairs)
        bne l_dwd_no
        lda dog_state
        beq l_dwd_no
        cmp #3
        beq l_dwd_no
        lda dog_beg
        bne l_dwd_no
        lda clock_hour
        ldx #1
        cmp #9
        bcc l_dwd_no
        cmp #11
        bcc l_dwd_check
        ldx #2
        cmp #14
        bcc l_dwd_no
        cmp #16
        bcc l_dwd_check
        ldx #4
        cmp #19
        bcc l_dwd_no
        cmp #21
        bcs l_dwd_no
l_dwd_check:
        txa
        and dog_walks
        bne l_dwd_no
        txa
        ora dog_walks
        sta dog_walks
        sec
        rts
l_dwd_no:
        clc
        rts

; every frame on the lead: the dog trots just ahead of him (or is out)
dog_on_lead:
        lda #1                  ; (and it goes behind the open door)
        sta act_masked+1
        lda dog_out
        beq +
        lda #0
        sta dog_state
        rts
+       lda #1
        sta dog_state
        lda p_flip
        sta dog_flip
        bne +
        sec
        lda p_x
        sbc #DOG_LEAD_DX
        sta dog_x
        lda p_x+1
        sbc #0
        sta dog_x+1
        rts
+       clc
        lda p_x
        adc #DOG_LEAD_DX
        sta dog_x
        lda p_x+1
        adc #0
        sta dog_x+1
        rts

; 1 and 3: bent down beside the dog, clipping the leash on / off
st_leash:
        lda #1                  ; the dog's to his right
        sta p_flip
st_unleash:                     ; (the dog's ahead of him, the way he faces)
        lda #PM_BENDSIDE
        sta p_mode
        lda #0
        sta lead_t
        lda #2
        jmp set_timer_secs
tk_leash:
        inc lead_t
        lda lead_t
        cmp #50                 ; click
        bne +
        lda #SFX_TINK
        jsr sfx_play
        lda p_act
        cmp #A_LEASH
        bne l_tkl_off
        lda #1
        sta dog_lead
        lda #0
        sta dog_hold
        lda #2
        sta walk_stage
        rts
l_tkl_off:
        lda #0
        sta dog_lead
        sta act_masked+1
        sta walk_stage
        lda #2                  ; free: a rest, then off it goes
        sta dog_state
        lda #120
        sta dog_timer
        rts
+       cmp #75
        bne +
        lda #PM_STAND
        sta p_mode
+       rts
en_leash:
        lda #0
        sta dog_hold
        lda #PM_STAND
        sta p_mode
        lda walk_stage
        cmp #2
        bne +
        lda #A_WALKOUT
        sta p_pending
+       rts
en_unleash:
        lda #PM_STAND
        sta p_mode
        lda #0
        sta dog_lead
        sta act_masked+1
        lda walk_stage
        bne +
        lda #3
        jsr mood_up
        #SAY l_say_walkies
+       rts

; 2: out of the front door with the dog: the door opens, they step forward,
; the dog goes out behind the door, then him, and it clicks shut. Half a
; minute later the door opens, they come back in, it clicks shut again.
wo_ph:          .byte 0
dog_up:         .byte 0     ; the dog drawn this much higher (going out)

; Going out of the door they rise towards its foot, as if walking off into
; the distance: him over his last 20px before it, the dog likewise.
wo_heights:
        sec
        lda p_x
        sbc #<280
        tax
        lda p_x+1
        sbc #>280
        bcs +
        ldx #0
+       txa
        lsr
        lsr
        cmp #6
        bcc +
        lda #5
+       sta l_woh_t
        lda #FLOOR0_Y
        sec
        sbc l_woh_t
        sta p_y
        sec
        lda dog_x
        sbc #<288
        tax
        lda dog_x+1
        sbc #>288
        bcs +
        ldx #0
+       txa
        lsr
        lsr
        cmp #7
        bcc +
        lda #6
+       sta dog_up
        rts
l_woh_t: .byte 0
WO_OUT_X        = 308           ; out of sight behind the door from here
WO_IN_X         = 268

st_walkout:
        lda #1
        sta p_flip
        ldx #PATCH_DOOR
        jsr patch_apply
        lda #SFX_DOOR
        jsr sfx_play
        lda #0
        sta lead_t
        sta wo_ph
        lda #<1500
        sta act_timer
        lda #>1500
        sta act_timer+1
        rts
tk_walkout:
        ldx wo_ph
        beq l_two_open
        cpx #1
        beq l_two_out
        cpx #2
        beq l_two_shut1
        cpx #3
        beq l_two_away
        cpx #4
        beq l_two_in
        cpx #5
        beq l_two_shut2
l_two_rts:
        rts
l_two_open:                     ; 0: the door swings open
        inc lead_t
        lda lead_t
        cmp #20
        bcc l_two_rts
        inc wo_ph
        lda #PM_WALK
        sta p_mode
        rts
l_two_out:                      ; 1: out they go, a step every other frame
        lda p_anim
        and #1
        bne l_two_rts
        inc p_x
        bne l_two_o1
        inc p_x+1
l_two_o1:
        jsr dog_on_lead         ; (the dog's place, then both heights)
        jsr wo_heights
        lda dog_x+1             ; the dog's through (x >= 312: all but its
        beq l_two_o2            ;  tail behind the door)
        lda dog_x
        cmp #<312
        bcc l_two_o2
        lda #1
        sta dog_out
l_two_o2:
        lda p_x+1               ; and him (x >= WO_OUT_X)
        beq l_two_rts
        lda p_x
        cmp #<WO_OUT_X
        bcc l_two_rts
        lda #PM_HIDDEN
        sta p_mode
        lda #0
        sta lead_t
        inc wo_ph
        rts
l_two_shut1:                    ; 2: the door shuts behind them
        inc lead_t
        lda lead_t
        cmp #20
        bne l_two_rts
        inc wo_ph
        ldx #PATCH_DOOR
        jmp patch_remove
l_two_away:                     ; 3: away; home with a bark near the end
        lda act_timer+1
        bne l_two_rts
        lda act_timer
        cmp #110
        bcs l_two_rts
        ldx #PATCH_DOOR
        jsr patch_apply
        lda #SFX_DOOR
        jsr sfx_play
        jsr bark_play
        lda #<WO_OUT_X
        sta p_x
        lda #>WO_OUT_X
        sta p_x+1
        lda #0
        sta p_flip
        sta dog_out
        lda #PM_WALK
        sta p_mode
        jsr dog_on_lead
        jsr wo_heights
        inc wo_ph
        rts
l_two_in:                       ; 4: back in, a step every other frame
        lda p_anim
        and #1
        bne l_two_rts
        lda p_x
        bne l_two_i1
        dec p_x+1
l_two_i1:
        dec p_x
        jsr dog_on_lead
        jsr wo_heights
        lda p_x+1
        cmp #>WO_IN_X
        bne l_two_rts
        lda p_x
        cmp #<WO_IN_X
        bne l_two_rts
        lda #PM_STAND
        sta p_mode
        lda #0
        sta lead_t
        inc wo_ph
        rts
l_two_shut2:                    ; 5: the door shuts
        inc lead_t
        lda lead_t
        cmp #15
        bne l_two_rts
        inc wo_ph
        ldx #PATCH_DOOR
        jmp patch_remove
en_walkout:
        ldx #PATCH_DOOR         ; (whatever happened, they're home)
        jsr patch_remove
        lda #FLOOR0_Y           ; back on the floor
        sta p_y
        lda #0
        sta dog_up
        lda #0
        sta dog_out
        lda #PM_STAND
        sta p_mode
        lda #3
        sta walk_stage
        lda #A_UNLEASH
        sta p_pending
        rts
l_say_walkies: .null "Good walk, boy!"

; The office wall clock keeps the real time: its face is repainted each
; minute with a minute hand (3px) and an hour hand (2px) in black, pointing
; to one of twelve positions round the dial (x 274-282, y 82-88, centre
; 278,85). Pixels go into the house image in Attic RAM and onto the screen.
CK_X            = 278
CK_Y            = 85
ck_m1x: .byte 0, 0, 1, 1, 1, 0, 0, 0, 255, 255, 255, 255
ck_m1y: .byte 255, 255, 0, 0, 0, 1, 1, 1, 0, 0, 0, 255
ck_m2x: .byte 0, 1, 2, 2, 2, 1, 0, 255, 254, 254, 254, 255
ck_m2y: .byte 254, 255, 255, 0, 1, 1, 2, 1, 1, 0, 255, 255
ck_m3x: .byte 0, 2, 3, 3, 3, 2, 0, 254, 253, 253, 253, 254
ck_m3y: .byte 254, 254, 255, 0, 1, 2, 2, 2, 1, 0, 255, 254
ck_h1x: .byte 0, 0, 1, 1, 1, 0, 0, 0, 255, 255, 255, 255
ck_h1y: .byte 255, 255, 0, 0, 0, 1, 1, 1, 0, 0, 0, 255
ck_h2x: .byte 0, 1, 2, 2, 2, 1, 0, 255, 254, 254, 254, 255
ck_h2y: .byte 254, 255, 255, 0, 1, 1, 2, 1, 1, 0, 255, 255
ck_px:          .byte 0
ck_py:          .byte 0
ck_col:         .byte 0
ck_dir:         .byte 0

clock_hands:
        lda #1                  ; fresh face (the painted hands too)
        sta patch_state + PATCH_CLOCKFACE
        ldx #PATCH_CLOCKFACE
        jsr patch_remove
        lda #C_WHITE            ; white out the face's painted-on hand
        sta ck_col
        ldx #<(CK_X - 1)
        ldy #CK_Y
        jsr ck_plot
        lda #C_BLACK
        sta ck_col
        ; minute hand: minutes / 5
        lda clock_min
        ldx #0
-       cmp #5
        bcc +
        sbc #5
        inx
        bra -
+       stx ck_dir
        lda ck_m1x,x
        ldy ck_m1y,x
        jsr ck_plot_rel
        ldx ck_dir
        lda ck_m2x,x
        ldy ck_m2y,x
        jsr ck_plot_rel
        ldx ck_dir
        lda ck_m3x,x
        ldy ck_m3y,x
        jsr ck_plot_rel
        ; hour hand: hour mod 12, a step on after half past
        lda clock_hour
-       cmp #12
        bcc +
        sbc #12
        bra -
+       ldx clock_min
        cpx #30
        bcc +
        clc
        adc #1
        cmp #12
        bcc +
        lda #0
+       tax
        stx ck_dir
        lda ck_h1x,x
        ldy ck_h1y,x
        jsr ck_plot_rel
        ldx ck_dir
        lda ck_h2x,x
        ldy ck_h2y,x
        jsr ck_plot_rel
        ldx #<CK_X              ; the centre pin
        ldy #CK_Y
        jmp ck_plot
; A = dx, Y = dy (signed) from the centre
ck_plot_rel:
        clc
        adc #<CK_X
        tax
        tya
        clc
        adc #CK_Y
        tay
; X, Y = pixel (x 256..287 assumed: x is CK_X-relative low byte), colour ck_col
ck_plot:
        stx ck_px
        sty ck_py
        ; offset = (y>>3)*2560 + (x>>3)*64 + (y&7)*8 + (x&7), x here + 256
        lda #0
        sta ZDST+1
        lda ck_py
        and #7
        asl
        asl
        asl
        sta ZDST
        lda ck_px
        and #7
        ora ZDST
        sta ZDST
        lda ck_px               ; (x>>3) + 32 (x is 256+low byte) -> *64
        lsr
        lsr
        lsr
        clc
        adc #32
        ; *64 = <<6: high gets >>2, low gets <<6
        pha
        lsr
        lsr
        clc
        adc ZDST+1
        sta ZDST+1
        pla
        asl
        asl
        asl
        asl
        asl
        asl
        clc
        adc ZDST
        sta ZDST
        bcc +
        inc ZDST+1
+       lda ck_py               ; (y>>3) * 2560 = (y>>3) * 10 * 256
        lsr
        lsr
        lsr
        sta MULTINA
        lda #10
        sta MULTINB
        lda MULTOUT
        clc
        adc ZDST+1
        sta ZDST+1
        ; screen character data
        lda #`CHAR_DATA
        sta ZDST+2
        lda #0
        sta ZDST+3
        ldz #0
        lda ck_col
        sta [ZDST],z
        ; the house image in Attic RAM (so it stays when restored)
        lda #ATTIC_WORK_BANK
        sta ZDST+2
        lda #ATTIC_MB >> 4
        sta ZDST+3
        lda ck_col
        sta [ZDST],z
        rts

; Washing his hands at the sink: back to you, elbows working, water running.
st_wash:
        lda #PM_WASH
        sta p_mode
        sec                     ; hands at his sides, over the basin
        lda p_x
        sbc #7
        sta fx_hands_x
        lda p_x+1
        sbc #0
        sta fx_hands_x+1
        lda p_y
        sec
        sbc #13
        sta fx_hands_y
        lda #7
        sta fx_kind
        lda #$90                ; tap water: softer and lower than the shower
        sta shower_pitch
        lda #1
        sta shower_on
        lda #4
        jmp set_timer_secs
en_wash:
        lda #0
        sta shower_on
        lda #$C0
        sta shower_pitch
        rts
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
; Playing a video game on the computer: a maze muncher or a space shooter
; running on its screen, with little game blips.
VG_X            = 292
VG_Y            = 99
vg_game:        .byte 0     ; 0 maze, 16 shooter (first frame in vg_l/h)
vg_l:           .byte <SPR_VGM0, <SPR_VGM1, <SPR_VGM2, <SPR_VGM3, <SPR_VGM4, <SPR_VGM5, <SPR_VGM6, <SPR_VGM7, <SPR_VGM8, <SPR_VGM9, <SPR_VGM10, <SPR_VGM11, <SPR_VGM12, <SPR_VGM13, <SPR_VGM14, <SPR_VGM15, <SPR_VGS0, <SPR_VGS1, <SPR_VGS2, <SPR_VGS3, <SPR_VGS4, <SPR_VGS5, <SPR_VGS6, <SPR_VGS7, <SPR_VGS8, <SPR_VGS9, <SPR_VGS10, <SPR_VGS11, <SPR_VGS12, <SPR_VGS13, <SPR_VGS14, <SPR_VGS15
vg_h:           .byte >SPR_VGM0, >SPR_VGM1, >SPR_VGM2, >SPR_VGM3, >SPR_VGM4, >SPR_VGM5, >SPR_VGM6, >SPR_VGM7, >SPR_VGM8, >SPR_VGM9, >SPR_VGM10, >SPR_VGM11, >SPR_VGM12, >SPR_VGM13, >SPR_VGM14, >SPR_VGM15, >SPR_VGS0, >SPR_VGS1, >SPR_VGS2, >SPR_VGS3, >SPR_VGS4, >SPR_VGS5, >SPR_VGS6, >SPR_VGS7, >SPR_VGS8, >SPR_VGS9, >SPR_VGS10, >SPR_VGS11, >SPR_VGS12, >SPR_VGS13, >SPR_VGS14, >SPR_VGS15
st_computer:
        #POSE SPR_COMPUTER, POSE_COMPUTER_X, POSE_COMPUTER_Y
        lda #0
        sta vg_game
        jsr rnd
        and #1
        beq +
        lda #16
        sta vg_game
+       lda #1
        sta monitor_on
        lda #15
        jmp set_timer_secs
tk_computer:
        lda p_anim
        and #15
        bne +
        lda #3
        jsr rnd_range
        bne +
        lda #SFX_BLIP           ; bleep
        jsr sfx_play
+       rts
en_computer:
        lda #0
        sta monitor_on
        lda #3
        jmp mood_up
; The attic desk with the typewriter: he types his letters here, seated on
; the far side of the desk facing you.
DESK_POSE_X     = 215         ; behind the typewriter, facing you
DESK_POSE_Y     = 38

HANDS_X         = 216           ; his hands on the typewriter keys
HANDS_Y         = 47
fx_hands_x:        .word HANDS_X   ; where the little-hands effect is drawn
fx_hands_y:        .byte HANDS_Y

st_letter:
        #POSE SPR_SITDESK, DESK_POSE_X, DESK_POSE_Y
        lda #<HANDS_X
        sta fx_hands_x
        lda #>HANDS_X
        sta fx_hands_x+1
        lda #HANDS_Y
        sta fx_hands_y
        lda #7                  ; hands on the keys
        sta fx_kind
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
; Watching TV: sitting in the blue attic chair, facing the set.
SITTV_X         = 97
SITTV_Y         = 35
CHAIRFRONT_X    = 99            ; the chair's back and arm, drawn over him
CHAIRFRONT_Y    = 44

st_tv:
        #POSE SPR_SITTV, SITTV_X, SITTV_Y
        lda #6                  ; chair back/arm overlay (in front of him)
        sta fx_kind
        lda #15
        jmp set_timer_secs
en_tv:
        lda #4
        jsr mood_up
        jsr rnd                 ; about half the time he switches it off after
        and #1
        beq +
        lda #A_TVOFF
        sta p_pending
+       rts

; Leaning over the set to work the knob.
st_tvswitch:
        lda #PM_BENDSIDE
        sta p_mode
        lda #2
        jmp set_timer_secs
en_tvon:
        lda #1
        sta tv_on
        lda #SFX_CLACK
        jsr sfx_play
        lda #A_TV               ; now sit down and watch
        sta p_pending
        rts
en_tvoff:
        lda #0
        sta tv_on
        lda #SFX_CLACK
        jmp sfx_play
; Records: facing the stereo he bends to pick one from the shelf underneath,
; straightens up and puts it on. It plays for a few minutes whatever he does
; next (the tone arm shimmers, the panel lights dance); often he dances to it.
RECORD_FRAMES   = 9000          ; about 3 minutes
record_left:    .word 0         ; frames of music left (0 = not playing)
record_tune:    .byte 0
rec_t:          .byte 0

; A = height: his little hands working away at either side of him, bent
; over a shelf or drawer (the effect is cleared when the activity ends).
hands_rummage:
        sta fx_hands_y
        sec
        lda p_x
        sbc #7
        sta fx_hands_x
        lda p_x+1
        sbc #0
        sta fx_hands_x+1
        lda #7
        sta fx_kind
        rts

REC_CLOSE       = 4             ; he steps up this close to the stereo
st_record:
        lda #PM_BEND            ; rummaging through the records
        sta p_mode
        lda p_y
        sec
        sbc #REC_CLOSE
        sta p_y
        lda #51                 ; his hands in the record shelf
        jsr hands_rummage
        lda #0
        sta rec_t
        lda #4
        jmp set_timer_secs
tk_record:
        inc rec_t
        lda rec_t
        cmp #70                 ; this one: stand up with it
        bne +
        lda #PM_BACKSTAND
        sta p_mode
        lda #0
        sta fx_kind
        rts
+       cmp #110                ; on it goes
        bne +
        jmp record_start
+       bcs +
        and #15                 ; rummaging: sleeves rustle
        bne +
        lda #SFX_STEP
        jmp sfx_play
+       rts
en_record:
        lda p_y                 ; back out to the middle of the floor
        clc
        adc #REC_CLOSE
        sta p_y
        lda rec_t
        cmp #110
        bcc +                   ; (interrupted before it went on)
        lda #6
        jsr mood_up
        lda #3                  ; and two times in three, a dance
        jsr rnd_range
        beq +
        lda #A_DANCE
        sta p_pending
+       rts

record_start:
        lda #<RECORD_FRAMES
        sta record_left
        lda #>RECORD_FRAMES
        sta record_left+1
        lda #4                  ; one of his records
        jsr rnd_range
        tax
        lda record_tunes,x
        sta record_tune
        jsr tune_play
        lda #1                  ; the song plays through once
        sta tune_once
        rts
record_stop:
        lda record_left
        ora record_left+1
        beq +
        lda #0
        sta record_left
        sta record_left+1
        lda #TUNE_NONE
        jmp tune_play
+       rts
; every sim tick: the record runs down, or its song's over
record_tick:
        lda record_left
        ora record_left+1
        beq l_rk_out
        lda tune_id             ; the song's finished: the record stops
        bne +
        lda #0
        sta record_left
        sta record_left+1
        rts
+
        lda record_left
        bne +
        dec record_left+1
+       dec record_left
        lda record_left
        ora record_left+1
        bne l_rk_out
        lda #TUNE_NONE          ; the end of the side
        jmp tune_play
l_rk_out:
        rts

; Asked to stop the record: up to the stereo, click, quiet.
st_recstop:
        lda #PM_BACKSTAND
        sta p_mode
        lda #0
        sta rec_t
        lda #1
        jmp set_timer_secs
tk_recstop:
        inc rec_t
        lda rec_t
        cmp #30
        bne +
        jsr record_stop
        lda #SFX_TINK
        jsr sfx_play
        #SAY l_say_quiet
+       rts
l_say_quiet:    .null "There, all quiet."
say_norecord:   .null "There's no record on."

st_dance:
        lda #PM_DANCE
        sta p_mode
        lda record_left
        ora record_left+1
        bne +                   ; dancing to the record
        lda #TUNE_DANCE         ; (asked to dance with no record on: hum along)
        jsr tune_play
+       lda #8
        jmp set_timer_secs
en_dance:
        lda record_left
        ora record_left+1
        bne +
        lda #TUNE_NONE
        jsr tune_play
+       lda energy
        sec
        sbc #3
        bcs +
        lda #0
+       sta energy
        lda #5
        jmp mood_up
st_piano:
        jsr record_stop         ; can't hear himself play over it
        #POSE SPR_PIANO, POSE_PIANO_X, POSE_PIANO_Y
        lda #4                  ; one of his pieces
        jsr rnd_range
        tax
        lda piano_tunes,x
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
; Changing clothes at the bedroom closet: the door opens, he steps in behind
; it, changes (pyjamas in the evening, else today's shirt), steps out and
; shuts the door.
chg_t:          .byte 0
st_change:
        ldx #PATCH_CLOSET
        jsr patch_apply
        lda #SFX_DOOR
        jsr sfx_play
        lda #0
        sta chg_t
        lda #5
        jmp set_timer_secs
tk_change:
        inc chg_t
        lda chg_t
        cmp #20                 ; in he goes
        bne +
        lda #PM_HIDDEN
        sta p_mode
        rts
+       cmp #120                ; changed
        bne +
        jmp change_outfit
+       cmp #180                ; out again
        bne +
        lda #PM_FRONT
        sta p_mode
        rts
+       cmp #215                ; door shut
        bne +
        ldx #PATCH_CLOSET
        jmp patch_remove
+       rts
en_change:
        ldx #PATCH_CLOSET
        jsr patch_remove
        lda chg_t
        cmp #120
        bcs +
        jsr change_outfit       ; (cut short: still changed)
+       lda #PM_STAND
        sta p_mode
        rts

; Pyjamas from 6pm until he gets up, else day clothes in today's colour.
change_outfit:
        jsr wake_hour
        cmp clock_hour
        beq l_co_day
        bcs l_co_pj
        lda clock_hour
        cmp #18
        bcs l_co_pj
l_co_day:
        jsr shirt_pick
        lda #0
        bra +
l_co_pj:
        lda #1
+       sta outfit
        lda #1
        sta ui_dirty
        rts

; Today's shirt: a colour for each day of the week, into the day outfit.
shirt_pick:
        jsr day_of_week
        sta l_sp_n
        asl
        clc
        adc l_sp_n
        asl                     ; * 6
        tax
        ldy #0
-       lda shirt_rgb,x
        sta outfit_rgb,y
        cpy #3
        bcs +
        sta outfit_rgb+12,y     ; the (hidden) dots match the shirt
+       inx
        iny
        cpy #6
        bne -
        rts
l_sp_n: .byte 0
shirt_rgb:      ; shirt, shirt shade: Sunday .. Saturday
        .byte 34,170,170, 17,102,102        ; teal
        .byte 34,102,255, 17,51,170         ; blue
        .byte 221,51,51, 153,17,17          ; red
        .byte 51,170,68, 17,102,34          ; green
        .byte 238,204,51, 170,136,17        ; yellow
        .byte 136,68,204, 85,34,136         ; purple
        .byte 238,136,34, 170,85,17         ; orange
; typing: a key every 6 ticks, hands taking turns
tk_typing:
        lda p_anim
        and #7
        cmp #0
        bne +
        lda #SFX_TYPE
        jsr sfx_play
+       rts

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
dog_state:      .byte 0     ; 0 hidden, 1 walk, 2 rest, 3 eat, 4 beg
DOG_EAT_X       = 9         ; eating: sprite left edge, nose in the bowl
DOG_EAT_TIME    = 250       ; frames
dog_beg:        .byte 0     ; 1 = hungry: going to him to beg
dog_meals:      .byte 0     ; today: bit 0 morning, bit 1 evening
dog_timer:      .byte 0

dog_init:
        lda #0
        sta dog_state
        sta dog_beg
        sta dog_floor
        sta dog_goal_floor
        lda #DOG_Y
        sta dog_yb
        rts

; The dog about the house: dog_tx is where it's going on floor A. To another
; floor it heads for the stairs first, climbs them (state 5) along the same
; flights he uses, and carries on from there.
dog_floor:      .byte 0
dog_goal_floor: .byte 0
dog_yb:         .byte DOG_Y     ; its feet: the floor's line, or on the stairs
dog_final:      .word 0
dog_path:       .word 0
dog_sdir:       .byte 0         ; 1 up, 0 down
dog_seg:        .byte 0         ; 0 a front block of steps, 1 a side flight
dog_fy:         .byte DOG_Y, FLOOR1_Y + 4, FLOOR2_Y + 3
; the flights (x, feet y), from the foot / head: up from the ground floor,
; down to it, up from the middle floor, down to it
dog_up0:        .byte 177, 163, 166, 161, 136, 141, 128, FLOOR1_Y + 4, $FF
dog_down0:      .byte 136, 141, 166, 161, 177, 163, 177, DOG_Y, $FF
dog_up1:        .byte 141, 100, 152, 98, 183, 76, 190, FLOOR2_Y + 3, $FF
dog_down1:      .byte 183, 76, 152, 98, 141, 100, 141, FLOOR1_Y + 4, $FF

; keep dog_tx inside the house (30..290)
dog_clamp_tx:
        lda dog_tx+1
        bne +
        lda dog_tx
        cmp #30
        bcs l_dct_out
        lda #30
        sta dog_tx
        rts
+       lda dog_tx
        cmp #<290
        bcc l_dct_out
        lda #<290
        sta dog_tx
l_dct_out:
        rts

dog_route:
        sta dog_goal_floor
        lda dog_tx
        sta dog_final
        lda dog_tx+1
        sta dog_final+1
        lda #1
        sta dog_state
; dog_tx: the final spot if it's on that floor, else this floor's stairs
dog_next_leg:
        lda dog_floor
        cmp dog_goal_floor
        bne +
        lda dog_final
        sta dog_tx
        lda dog_final+1
        sta dog_tx+1
        rts
+       ldx #177                ; ground floor: up
        lda dog_floor
        beq l_dnl_x
        ldx #190                ; attic: down
        cmp #2
        beq l_dnl_x
        ldx #141                ; middle floor: up...
        lda dog_goal_floor
        cmp #2
        beq l_dnl_x
        ldx #128                ; ...or down
l_dnl_x:
        stx dog_tx
        lda #0
        sta dog_tx+1
        rts

dog_stairs_start:
        ldx #<dog_up0
        ldy #>dog_up0
        lda #1
        sta dog_sdir
        lda dog_floor
        beq l_dss_go            ; ground floor: up
        ldx #<dog_down1
        ldy #>dog_down1
        lda #0
        sta dog_sdir
        lda dog_floor
        cmp #2
        beq l_dss_go            ; attic: down
        ldx #<dog_up1           ; middle floor: up or down
        ldy #>dog_up1
        lda #1
        sta dog_sdir
        lda dog_goal_floor
        cmp #2
        beq l_dss_go
        ldx #<dog_down0
        ldy #>dog_down0
        lda #0
        sta dog_sdir
l_dss_go:
        stx dog_path
        sty dog_path+1
        lda #5
        sta dog_state
        rts

; state 5: a step every other frame towards the next point of the flight
dog_stairs:
        lda p_anim
        and #1
        bne l_dst_out
        lda dog_path
        sta ZPTR2
        lda dog_path+1
        sta ZPTR2+1
        ldy #0
        lda (ZPTR2),y
        cmp #$FF
        beq l_dst_end
        ldx #0                  ; straight up/down (a front block) or across?
        cmp dog_x
        beq +
        inx
+       stx dog_seg
        cmp dog_x               ; across
        beq l_dst_y
        bcc +
        inc dog_x
        lda #1
        sta dog_flip
        bra l_dst_y
+       dec dog_x
        lda #0
        sta dog_flip
l_dst_y:
        iny                     ; and up / down
        lda (ZPTR2),y
        cmp dog_yb
        beq l_dst_here
        bcc +
        inc dog_yb
        rts
+       dec dog_yb
        rts
l_dst_here:
        dey                     ; at this point? on to the next
        lda (ZPTR2),y
        cmp dog_x
        bne l_dst_out
        clc
        lda dog_path
        adc #2
        sta dog_path
        bcc l_dst_out
        inc dog_path+1
l_dst_out:
        rts
l_dst_end:                      ; off the stairs: on the new floor
        lda dog_sdir
        beq +
        inc dog_floor
        bra ++
+       dec dog_floor
+       ldx dog_floor
        lda dog_fy,x
        sta dog_yb
        lda #0
        sta dog_x+1
        jsr dog_next_leg
        lda #1
        sta dog_state
        rts

; C = 1 at the dog's mealtime (8-10am, 5-7pm) if it hasn't been fed then
; (and marks it).
dog_meal_due:
        lda clock_hour
        ldx #1
        cmp #8
        bcc l_dmd_no
        cmp #10
        bcc l_dmd_check
        ldx #2
        cmp #17
        bcc l_dmd_no
        cmp #19
        bcs l_dmd_no
l_dmd_check:
        txa
        and dog_meals
        bne l_dmd_no
        txa
        ora dog_meals
        sta dog_meals
        sec
        rts
l_dmd_no:
        clc
        rts

; Where to beg: beside him on the ground floor (whichever side the dog is
; on), else at the foot of the stairs.
dog_beg_target:
        jsr dog_beg_x
        lda p_floor
        jmp dog_route
dog_beg_x:
        lda dog_x
        cmp p_x
        lda dog_x+1
        sbc p_x+1
        bcc +
        clc                     ; dog to his right
        lda p_x
        adc #20
        sta dog_tx
        lda p_x+1
        adc #0
        sta dog_tx+1
        lda dog_tx+1            ; (not off the right of the house)
        beq l_dbt_out
        lda dog_tx
        cmp #<296
        bcc l_dbt_out
        lda #<296
        sta dog_tx
        rts
+       sec                     ; dog to his left
        lda p_x
        sbc #20
        sta dog_tx
        lda p_x+1
        sbc #0
        sta dog_tx+1
        bcs +
        lda #0
        sta dog_tx+1
+       lda dog_tx+1
        bne l_dbt_out
        lda dog_tx
        cmp #30
        bcs l_dbt_out
        lda #30
        sta dog_tx
l_dbt_out:
        rts

dog_arrive:
        lda #0
        sta dog_floor
        sta dog_goal_floor
        lda #DOG_Y
        sta dog_yb
        lda #<280
        sta dog_x
        lda #>280
        sta dog_x+1
        lda #2
        sta dog_state
        lda #50
        sta dog_timer
        jmp bark_play

dog_update:
        lda dog_lead            ; on the lead: just ahead of him
        beq l_dg_free
        jmp dog_on_lead
l_dg_free:
        lda dog_hold            ; waiting for him (the leash going on)
        beq +
        rts
+       lda dog_state
        bne +
        rts
+       cmp #1
        beq l_dg_walk
        cmp #5
        bne +
        jmp dog_stairs
+       cmp #4
        bne +
        ; begging: until the bowl's filled; every so often a bark, and
        ; after him if he's moved off
        lda bowl_full
        beq l_dg_begon
        lda #0
        sta dog_beg
        jmp l_dg_choose
l_dg_begon:
        dec dog_timer
        bne l_dg_out
        jsr bark_play
        jmp l_dg_choose
+
        ; resting or eating: count down (chomp, chomp)
        cmp #3
        bne +
        lda dog_timer
        and #15
        bne +
        lda #SFX_STEP
        jsr sfx_play
+       dec dog_timer
        bne l_dg_out
        lda dog_state
        cmp #3
        bne l_dg_choose
        lda #0
        sta bowl_full
        sta dog_hunger
l_dg_choose:
        ; hungry (or its mealtime) and nothing in the bowl: go and beg
        lda bowl_full
        bne l_dg_bowl
        lda dog_beg
        bne l_dg_begto
        jsr dog_meal_due
        bcs +
        lda dog_hunger
        cmp #60
        bcc l_dg_bowl
+       lda #1
        sta dog_beg
l_dg_begto:
        jsr dog_beg_target
        lda #1
        sta dog_state
        rts
l_dg_bowl:
        ; food in the bowl? (downstairs)
        lda bowl_full
        beq +
        lda #<30
        sta dog_tx
        lda #0
        sta dog_tx+1
        lda #0
        jmp dog_route
+       ; the fire's lit: often it goes and lies in front of it
        lda fire_time
        beq l_dgc_him
        jsr rnd
        and #1
        beq l_dgc_him
        lda #<262
        sta dog_tx
        lda #>262
        sta dog_tx+1
        lda #0
        jsr dog_route
        bra l_dg_go
l_dgc_him:
        ; mostly it keeps him company: somewhere near him, on his floor
        lda #3
        jsr rnd_range
        beq l_dgc_about
        lda #60
        jsr rnd_range
        sec
        sbc #30
        clc
        adc p_x
        sta dog_tx
        lda #0
        sta dog_tx+1
        lda p_x+1
        beq +
        lda #1
        sta dog_tx+1
+       jsr dog_clamp_tx
        lda p_floor
        jsr dog_route
        bra l_dg_go
l_dgc_about:
        ; or it potters about this floor
        lda #210
        jsr rnd_range
        clc
        adc #40
        sta dog_tx
        lda #0
        sta dog_tx+1
        lda dog_floor
        jsr dog_route
l_dg_go:
        lda #10
        jsr rnd_range
        bne l_dg_out
        jsr bark_play
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
        lda dog_floor           ; at the stairs, on the way to another floor
        cmp dog_goal_floor
        beq +
        jmp dog_stairs_start
+       lda dog_beg             ; at his feet: sit up and beg
        beq l_dg_nobeg
        lda bowl_full
        bne l_dg_nobeg
        lda #4
        sta dog_state
        lda #90
        sta dog_timer
        lda #0                  ; face him
        sta dog_flip
        lda p_floor
        cmp dog_floor
        bne +
        lda dog_x
        cmp p_x
        lda dog_x+1
        sbc p_x+1
        bcs +
        lda #1
        sta dog_flip
+       jmp bark_play
l_dg_nobeg:
        lda bowl_full
        beq +
        lda dog_x
        cmp #31
        bcs +
        lda #3
        sta dog_state
        lda #DOG_EAT_TIME
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
        cmp #4                  ; the knocking fist and the book stay put
        bcs l_fu_out
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
ACTORS          = 7         ; 5 = censor mosaic, 6 = the vacuum left standing
act_vis:        .fill ACTORS, 0
act_sprl:       .fill ACTORS, 0
act_sprh:       .fill ACTORS, 0
act_sprb:       .fill ACTORS, 0
act_xl2:        .fill ACTORS, 0
act_xh2:        .fill ACTORS, 0
act_y:          .fill ACTORS, 0
act_flip:       .fill ACTORS, 0
prev_valid:     .fill ACTORS, 0
act_masked:     .byte 1, 0, 0, 0, 0, 1, 1  ; him, his mosaic and the vacuum go behind furniture
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
PIANOHANDS_X = 139
PIANOHANDS_Y = 44
pianohands_l: .byte <SPR_PIANOHANDS0, <SPR_PIANOHANDS1, <SPR_PIANOHANDS2, <SPR_PIANOHANDS3
pianohands_h: .byte >SPR_PIANOHANDS0, >SPR_PIANOHANDS1, >SPR_PIANOHANDS2, >SPR_PIANOHANDS3
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
+       cmp #PM_BENDSIDE
        bne l_ab_notbendside
        #SETACT 0, SPR_BENDSIDE
        lda p_flip
        bne +
        sec                     ; facing left: the lean padding is on the left
        lda act_xl2+0
        sbc #5
        sta act_xl2+0
        lda act_xh2+0
        sbc #0
        sta act_xh2+0
+       jmp l_ab_person_done
l_ab_notbendside:
        cmp #PM_BEND
        bne l_ab_notbend
        ; back to you, bent down: same frame as the back view on the stairs
        #SETACT 0, SPR_BEND
        lda p_act
        cmp #A_FIRE
        bne l_ab_bend_still
        lda p_anim              ; laying the fire: arms move
        and #8
        beq l_ab_bend_still
        #SETACT 0, SPR_BEND2
l_ab_bend_still:
        sec
        lda p_x
        sbc #10
        sta act_xl2+0
        lda p_x+1
        sbc #0
        sta act_xh2+0
        lda p_y
        sec
        sbc #28
        sta act_y+0
        lda #0
        sta act_flip+0
        jmp l_ab_person_done
l_ab_notbend:
        cmp #PM_FRONT
        bne +
        #SETACT 0, SPR_FRONT
        lda mouth_open
        beq l_ab_front_shut     ; (named: an anonymous + here hijacked the
        #SETACT 0, SPR_FRONTTALK ;  "not front" branch above it)
l_ab_front_shut:
        lda drinking
        beq l_ab_front_nodrink  ; (named, never "+": see above)
        #SETACT 0, SPR_FRONTDRINK
l_ab_front_nodrink:
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
        ; facing you, stepping down: knees bend in turn, slight bob
        #SETACT 0, SPR_DOWNSTEP0
        lda p_y
        and #4
        beq +
        #SETACT 0, SPR_DOWNSTEP1
+       sec
        lda p_x
        sbc #9
        sta act_xl2+0
        lda p_x+1
        sbc #0
        sta act_xh2+0
        lda #0
        sta act_flip+0
        lda p_y
        and #2
        lsr
        clc
        adc act_y+0
        sta act_y+0
        jmp l_ab_person_done
l_ab_notdown:
        cmp #PM_BACKSTAND
        bne +
        #SETACT 0, SPR_BACKSTAND
        jmp l_ab_back_xy
+       cmp #PM_WASH
        bne l_ab_notwash
        ; at the sink, back to you, standing still (hands drawn as an effect)
        #SETACT 0, SPR_BACKSTAND
        jmp l_ab_back_xy
l_ab_notwash:
        cmp #PM_CLIMB
        bne +
        ; back view going up: knees bend in turn
        #SETACT 0, SPR_CLIMBSTEP0
        lda p_y
        and #4
        beq l_ab_cl1
        #SETACT 0, SPR_CLIMBSTEP1
l_ab_cl1:
l_ab_back_xy:
        sec
        lda p_x
        sbc #10
        sta act_xl2+0
        lda p_y
        sec
        sbc #28
        sta act_y+0
        lda #0
        sta act_flip+0
        jmp l_ab_person_done
+       cmp #PM_JUMP
        bne l_ab_dance
        ; jumping jacks facing you: arms down, out, up (with a hop), out...
        lda p_anim
        lsr
        lsr
        lsr
        and #3
        beq l_ab_jack0
        cmp #2
        beq l_ab_jack2
        #SETACT 0, SPR_JACK1
        bra l_ab_jack_xy
l_ab_jack2:
        #SETACT 0, SPR_JACK2
        dec act_y+0
        dec act_y+0
        bra l_ab_jack_xy
l_ab_jack0:
        #SETACT 0, SPR_JACK0
l_ab_jack_xy:
        sec
        lda p_x
        sbc #13
        sta act_xl2+0
        lda p_x+1
        sbc #0
        sta act_xh2+0
        lda #0
        sta act_flip+0
        jmp l_ab_person_done
l_ab_dance:
        ; dancing: alternate frames and bounce
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
        ; actor 5: his hands on the piano keys while he plays...
        lda #0
        sta act_vis+5
        lda p_act
        cmp #A_PIANO
        bne l_ab_nopiano
        lda p_mode
        cmp #PM_POSE
        bne l_ab_nopiano
        lda #1
        sta act_vis+5
        lda p_anim
        lsr
        lsr
        lsr
        and #3
        tax
        lda pianohands_l,x
        sta act_sprl+5
        lda pianohands_h,x
        sta act_sprh+5
        lda #`SPR_PIANOHANDS0
        sta act_sprb+5
        lda #<PIANOHANDS_X
        sta act_xl2+5
        lda #>PIANOHANDS_X
        sta act_xh2+5
        lda #PIANOHANDS_Y
        sta act_y+5
        lda #0
        sta act_flip+5
        jmp l_ab_nomosaic
l_ab_nopiano:
        ; ...or the video game on the computer screen while he plays
        lda p_act
        cmp #A_COMPUTER
        bne l_ab_novg
        lda p_mode
        cmp #PM_POSE
        bne l_ab_novg
        lda #1
        sta act_vis+5
        lda p_anim
        lsr
        lsr
        lsr
        and #15
        clc
        adc vg_game
        tax
        lda vg_l,x
        sta act_sprl+5
        lda vg_h,x
        sta act_sprh+5
        lda #`SPR_VGM0
        sta act_sprb+5
        lda #<VG_X
        sta act_xl2+5
        lda #>VG_X
        sta act_xh2+5
        lda #VG_Y
        sta act_y+5
        lda #0
        sta act_flip+5
        jmp l_ab_nomosaic
l_ab_novg:
        ; ...or the censor mosaic over his hips while he has nothing on
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
        lda dog_yb
        sec
        sbc #14
        sta act_y+1
        lda dog_state
        cmp #5
        bne l_ab_dog_notstairs
        jmp ab_dog_stairs
l_ab_dog_notstairs:
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
        lda dog_yb
        sec
        sbc #15
        sec
        sbc dog_up              ; (raised, heading out of the door)
        sta act_y+1
        bra l_ab_dog_done
l_ab_dog_rest:
        cmp #3
        bne l_ab_dog_noeat
        #SETACT 1, SPR_DOGEAT0  ; nose in the bowl, chewing
        lda p_anim
        and #8
        beq +
        #SETACT 1, SPR_DOGEAT1
+       lda #DOG_EAT_X          ; standing right at the bowl
        sta act_xl2+1
        lda #0
        sta act_xh2+1
        sta act_flip+1
        lda dog_yb
        sec
        sbc #14
        sta act_y+1
        bra l_ab_dog_done
l_ab_dog_noeat:
        cmp #4
        bne l_ab_dog_sit
        #SETACT 1, SPR_DOGBEG0  ; sitting up, paws bobbing, tail wagging
        lda p_anim
        and #8
        beq +
        #SETACT 1, SPR_DOGBEG1
+       lda dog_yb
        sec
        sbc #18
        sta act_y+1
        bra l_ab_dog_done
l_ab_dog_sit:
        #SETACT 1, SPR_DOG3
        lda dog_yb
        sec
        sbc #12
        sta act_y+1
l_ab_dog_done:
        ; --- effect ---
        lda #0
        sta act_vis+2
        sta act_flip+2
        ; walking the dog: the leash from his hand to its collar (behind the
        ; door with the dog when it goes out)
        lda #0
        sta act_masked+2
        lda dog_lead
        beq l_ab_noleash
        lda p_mode
        cmp #PM_HIDDEN
        beq l_ab_noleash
        cmp #PM_CLIMB
        beq l_ab_noleash
        #SETACT 2, SPR_LEASH
        lda #1
        sta act_vis+2
        sta act_masked+2
        lda p_flip              ; drawn for the dog on his right: mirror it
        eor #1                  ;  only when the dog is on his left
        sta act_flip+2
        lda p_y
        sec
        sbc #14
        sta act_y+2
        lda p_flip
        beq l_ab_leashl
        clc                     ; dog to his right
        lda p_x
        adc #4
        sta act_xl2+2
        lda p_x+1
        adc #0
        sta act_xh2+2
        jmp l_ab_fx_done
l_ab_leashl:
        sec                     ; dog to his left
        lda p_x
        sbc #24
        sta act_xl2+2
        lda p_x+1
        sbc #0
        sta act_xh2+2
        jmp l_ab_fx_done
l_ab_noleash:
        ; drinking: the cup tipped up at his lips
        lda drinking
        beq l_ab_notdrinking
        #SETACT 2, SPR_CUPTILT0
        lda p_anim
        and #32
        beq +
        #SETACT 2, SPR_CUPTILT1
+       clc
        lda act_xl2+0
        adc #10
        sta act_xl2+2
        lda act_xh2+0
        adc #0
        sta act_xh2+2
        lda act_y+0
        clc
        adc #5
        sta act_y+2
        lda #1
        sta act_vis+2
        jmp l_ab_fx_done
l_ab_notdrinking:
        ; something he's carrying (hidden when his back is to you)
        lda held
        beq l_ab_noheld
        lda p_mode
        cmp #PM_BACKSTAND
        beq l_ab_noheld
        cmp #PM_BEND
        beq l_ab_noheld
        cmp #PM_POSE
        beq l_ab_noheld
        cmp #PM_HIDDEN
        beq l_ab_noheld
        ldx held
        cpx #HELD_VAC
        bne +
        jmp ab_vacuum
+       lda held_l-1,x
        sta act_sprl+2
        lda held_h-1,x
        sta act_sprh+2
        lda #`SPR_HELDJAR
        sta act_sprb+2
        lda #1
        sta act_vis+2
        jmp l_abp_hands
l_ab_noheld:
        ; the delivery, while it's on the step, in his hands or being put away
        lda delivery
        beq l_ab_nopkg
        lda carrying
        bne l_ab_pkg
        lda p_state
        cmp #PS_ACT
        bne l_ab_nopkg
        lda p_act
        cmp #A_DELIVERY
        beq l_ab_pkg
        cmp #A_STOW
        bne l_ab_nopkg
l_ab_pkg:
        lda #1
        sta act_vis+2
        jmp ab_package
l_ab_nopkg:
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
        cmp #9
        bne l_ab_notcards
        #SETACT 2, SPR_TABLECARDS0
        lda p_anim
        and #64
        beq +
        #SETACT 2, SPR_TABLECARDS1
+       lda #<TABLECARDS_X
        sta act_xl2+2
        lda #>TABLECARDS_X
        sta act_xh2+2
        lda #TABLECARDS_Y
        sta act_y+2
        jmp l_ab_fx_done
l_ab_notcards:
        cmp #7
        bne l_ab_nothands
        #SETACT 2, SPR_HANDS0
        lda p_anim
        and #8
        beq +
        #SETACT 2, SPR_HANDS1
+       lda fx_hands_x
        sta act_xl2+2
        lda fx_hands_x+1
        sta act_xh2+2
        lda fx_hands_y
        sta act_y+2
        jmp l_ab_fx_done
l_ab_nothands:
        cmp #6
        bne l_ab_notchair
        #SETACT 2, SPR_CHAIRFRONT
        lda #<CHAIRFRONT_X
        sta act_xl2+2
        lda #>CHAIRFRONT_X
        sta act_xh2+2
        lda #CHAIRFRONT_Y
        sta act_y+2
        bra l_ab_fx_done
l_ab_notchair:
        cmp #5
        bne l_ab_notbook
        ; the book in his hands, open or turning a page
        #SETACT 2, SPR_BOOKOPEN
        lda book_page
        beq +
        #SETACT 2, SPR_BOOKTURN
+       lda #<BOOK_X
        sta act_xl2+2
        lda #>BOOK_X
        sta act_xh2+2
        lda #BOOK_Y
        sta act_y+2
        bra l_ab_fx_done
l_ab_notbook:
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
        lda dog_state
        cmp #3
        bne +
        lda dog_timer
        cmp #DOG_EAT_TIME / 2
        bcs +
        #SETACT 3, SPR_DOGFOOD2
+
        lda #10
        sta act_xl2+3
        lda #0
        sta act_xh2+3
        sta act_flip+3
        lda #187
        sta act_y+3
        ; --- the vacuum, if he's left it standing somewhere ---
        lda vac_parked
        sta act_vis+6
        beq l_ab_novac
        #SETACT 6, SPR_HELDVAC
        lda park_flip
        sta act_flip+6
        ldx park_floor
        lda floor_y,x
        sec
        sbc #12
        sta act_y+6
        lda park_flip
        bne +
        sec                     ; in front of where he stood, the way he faced
        lda park_x
        sbc #15
        sta act_xl2+6
        lda park_x+1
        sbc #0
        sta act_xh2+6
        rts
+       clc
        lda park_x
        adc #7
        sta act_xl2+6
        lda park_x+1
        adc #0
        sta act_xh2+6
l_ab_novac:
        rts

; The dog on the stairs: on a front-facing block of steps its walk with the
; head turning left and right every few steps; on a side flight tilted head
; up going up, head down going down.
dogtu_l:    .byte <SPR_DOGTU0, <SPR_DOGTU1
dogtu_h:    .byte >SPR_DOGTU0, >SPR_DOGTU1
dogtd_l:    .byte <SPR_DOGTD0, <SPR_DOGTD1
dogtd_h:    .byte >SPR_DOGTD0, >SPR_DOGTD1
ab_dog_stairs:
        lda dog_x               ; the step: from how far it has come
        clc
        adc dog_yb
        lsr
        lsr
        sta l_abds_step
        lda dog_seg
        bne l_abds_side
        ; the front steps: walking frames, head turning side to side
        lda l_abds_step
        and #3
        tax
        lda dogw_l,x
        sta act_sprl+1
        lda dogw_h,x
        sta act_sprh+1
        lda #`SPR_DOGW0
        sta act_sprb+1
        lda dog_yb
        lsr
        lsr
        lsr
        and #1
        sta act_flip+1
        lda dog_yb
        sec
        sbc #15
        sta act_y+1
        jmp l_ab_dog_done
l_abds_side:
        lda l_abds_step
        and #1
        tax
        lda dog_sdir
        beq +
        lda dogtu_l,x           ; going up: head up
        sta act_sprl+1
        lda dogtu_h,x
        sta act_sprh+1
        bra ++
+       lda dogtd_l,x           ; going down: head down
        sta act_sprl+1
        lda dogtd_h,x
        sta act_sprh+1
+       lda #`SPR_DOGTU0
        sta act_sprb+1
        lda dog_yb              ; (taller: feet line through its middle)
        sec
        sbc #19
        sta act_y+1
        jmp l_ab_dog_done
l_abds_step: .byte 0

; The vacuum cleaner, its head on the floor in front of him (the side he's
; facing); hidden on the stairs.
ab_vacuum:
        lda p_mode
        cmp #PM_CLIMB
        bne +
        jmp l_ab_fx_done
+       cmp #PM_DOWNSTEP
        bne +
        jmp l_ab_fx_done
+       #SETACT 2, SPR_HELDVAC
        lda #1
        sta act_vis+2
        lda p_y
        sec
        sbc #12
        sta act_y+2
        lda p_flip
        sta act_flip+2
        bne l_abv_right
        sec                     ; facing left: out in front, to the left
        lda p_x
        sbc #15
        sta act_xl2+2
        lda p_x+1
        sbc #0
        sta act_xh2+2
        jmp l_ab_fx_done
l_abv_right:
        clc
        lda p_x
        adc #7
        sta act_xl2+2
        lda p_x+1
        adc #0
        sta act_xh2+2
        jmp l_ab_fx_done

; The delivery: on the step, in his hands (in front of him, the side he's
; facing), or where he is putting it. Hidden while his back is to you on
; the stairs.
ab_package:
        ldx delivery
        lda pkg_l-1,x
        sta act_sprl+2
        lda pkg_h-1,x
        sta act_sprh+2
        lda #`SPR_PKGFOOD
        sta act_sprb+2
        lda p_act
        cmp #A_STOW
        bne l_abp_notstow
        lda p_state
        cmp #PS_ACT
        bne l_abp_notstow
        lda stow_px-1,x         ; being put away
        sta act_xl2+2
        lda #0
        sta act_xh2+2
        lda stow_py-1,x
        sta act_y+2
        jmp l_ab_fx_done
l_abp_notstow:
        lda carrying
        bne l_abp_hands
        ; on the doorstep, just outside his feet
        clc
        lda p_x
        adc #5
        sta act_xl2+2
        lda p_x+1
        adc #0
        sta act_xh2+2
        lda p_y
        sec
        sbc #6
        sta act_y+2
        jmp l_ab_fx_done
l_abp_hands:
        lda p_mode
        cmp #PM_CLIMB
        beq l_abp_hide
        cmp #PM_HIDDEN
        bne +
l_abp_hide:
        lda #0
        sta act_vis+2
        jmp l_ab_fx_done
+       lda p_y                 ; chest height, in front
        sec
        sbc #17
        sta act_y+2
        lda p_mode
        cmp #PM_DOWNSTEP
        beq l_abp_mid
        cmp #PM_FRONT
        beq l_abp_mid
        lda p_flip
        bne l_abp_right
        sec                     ; facing left
        lda p_x
        sbc #11
        sta act_xl2+2
        lda p_x+1
        sbc #0
        sta act_xh2+2
        jmp l_ab_fx_done
l_abp_right:
        clc
        lda p_x
        adc #4
        sta act_xl2+2
        lda p_x+1
        adc #0
        sta act_xh2+2
        jmp l_ab_fx_done
l_abp_mid:
        sec
        lda p_x
        sbc #4
        sta act_xl2+2
        lda p_x+1
        sbc #0
        sta act_xh2+2
        jmp l_ab_fx_done

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
        ldx #6
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
        lda act_masked,x
        cpx #0
        bne +
        lda #1
        ldy p_mode              ; seated/posed in place: that furniture is his own
        cpy #PM_POSE
        beq l_ard_nomask
        cpy #PM_BEND
        bne +
l_ard_nomask:
        lda #0
+       sta spr_mask
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
