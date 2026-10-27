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

SPEED_MAX       = 9         ; time speeds: 0 real time, 1-9 x2 .. x512

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
PM_PONG         = 13        ; side view, a ping pong paddle in his hand
PM_SIPDOWN      = 14        ; side view, a glass of water held in front of him...
PM_SIPUP        = 15        ;  ...and tipped up at his lips

; Activities: A_xxx, numbered by #ACT in sim/activities.asm. Requests (what you
; can ask him to do) are activity ids:
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
REQ_DOGWALK     = A_LEASH
REQ_DANCE       = A_DANCE
REQ_PIANO       = A_PIANO
REQ_CHANGE      = A_CHANGE
REQ_POOL        = A_POOL
REQ_CARDS       = A_CARDS
REQ_PETDOG      = A_PETDOG
REQ_FILES       = A_FILES
REQ_INVITE      = A_CALLFRIEND
REQ_FETCH       = A_FETCH
REQ_VACSTOP     = A_VACPUT
REQ_STOP        = A_IDLE
REQ_PINGPONG    = A_PINGPONG
REQ_HELLO       = $80
REQ_HOWAREYOU   = $81
REQ_THANKS      = $82

;---------------------------------------------------------------------------------------
; State
;---------------------------------------------------------------------------------------
frame_count:    .byte 0
fast_forward:   .byte 0     ; the time speed: 0 real time, n = x2^n
sp_count:       .word 0     ; sim ticks into this game minute (sped up)
quit_request:   .byte 0
rnd_seed:       .word $ACE1

date_month:     .byte 1     ; set from the RTC on the title screen
date_day:       .byte 1
date_year:      .byte 87    ; two digits
clock_hour:     .byte 8
clock_min:      .byte 0
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
l_lt_used:      .fill TOPIC_COUNT, 0   ; letter topics written (kept here: the
                                       ;  letters overlay is reloaded fresh)
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
; if the RTC isn't ticking, by counting 50 frames a second). Sped up (+/-,
; F5), a game minute every speed_ticks sim ticks instead: x2 .. x512 the
; real pace (and from x16 the sim runs 2, from x128 4 ticks a frame).
speed_ticks:    .word 3000, 1500, 750, 375, 375, 188, 94, 94, 47, 23
speed_steps:    .byte 1, 1, 1, 1, 2, 2, 2, 4, 4, 4     ; sim ticks per frame
speed_names:    .word l_spn1, l_spn2, l_spn3, l_spn4, l_spn5, l_spn6
                .word l_spn7, l_spn8, l_spn9
l_spn1:         .null "  x2"
l_spn2:         .null "  x4"
l_spn3:         .null "  x8"
l_spn4:         .null " x16"
l_spn5:         .null " x32"
l_spn6:         .null " x64"
l_spn7:         .null "x128"
l_spn8:         .null "x256"
l_spn9:         .null "x512"
; A = the new speed (0 .. SPEED_MAX)
speed_set:
        sta fast_forward
        lda #0
        sta sp_count
        sta sp_count+1
        lda #1
        sta ui_dirty
        rts
sim_tick:
        lda fast_forward
        beq l_st_real
        inc sp_count
        bne +
        inc sp_count+1
+       lda fast_forward
        asl
        tax
        lda sp_count+1
        cmp speed_ticks+1,x
        bcc l_st_go
        bne +
        lda sp_count
        cmp speed_ticks,x
        bcc l_st_go
+       lda #0
        sta sp_count
        sta sp_count+1
        jsr game_minute
        bra l_st_go
l_st_real:
        jsr realtime_tick
l_st_go:
        jsr alarm_tick
        jsr record_tick
        jsr cook_tick
        jsr phone_ring_tick
        jsr person_update
        jsr friend_update
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
        jsr friend_minute
        jsr phone_minute
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
        ; up in the night for the bathroom (now and then)
        lda night_trip
        cmp clock_hour
        bne +
        lda #0
        sta night_trip
        jsr person_sleeping
        bcc +
        jsr act_end             ; (quietly: no grumbling, no TV)
        lda #PS_IDLE
        sta p_state
        lda #0
        sta dress_todo
        lda #1
        sta night_wc
+       ; the alarm clock: rings at his getting-up time if he's asleep
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
        lda #0                  ; one night in ten: up for the bathroom
        sta night_trip          ;  at 1, 2, 3 or 4 o'clock
        lda #10
        jsr rnd_range
        bne +
        lda #4
        jsr rnd_range
        clc
        adc #1
        sta night_trip
+       lda #0
        sta vac_done
        sta dog_walks
        sta meals_done
        sta showered
        sta paper_done
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

