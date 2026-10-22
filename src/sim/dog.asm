; sim/dog.asm -- The dog (part of the simulation; included after sim/sim.asm)
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
dog_called:     .byte 0     ; 1 = he's whistled for it
DOG_BEDSIDE_X   = 72        ; lying beside his bed (middle floor) while he sleeps
dog_begt:       .byte 0     ; frames spent begging
dog_gaveup:     .byte 0     ; 1 = begged in vain: waits by its bowl until fed
dog_meals:      .byte 0     ; today: bit 0 morning, bit 1 evening
dog_timer:      .byte 0

; a bark, one time in five
bark_now_and_then:
        lda #5
        jsr rnd_range
        bne +
        jmp bark_play
+       rts

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
dog_fy:         .byte DOG_Y, FLOOR1_Y, FLOOR2_Y      ; (upstairs: mid-room, like him)
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
        bne l_dg_notbeg         ; (named: the begging code has its own "+"s)
        ; begging: until the bowl's filled; every so often a bark, and
        ; after him if he's moved off
        lda bowl_full
        bne l_dg_begoff
        jsr person_sleeping     ; (he's gone to sleep: forget it)
        bcc l_dg_begon
l_dg_begoff:
        lda #0
        sta dog_beg
        jmp l_dg_choose
l_dg_begon:
        inc dog_begt            ; five seconds of it and it gives up
        lda dog_begt
        cmp #250
        bcc +
        lda #0
        sta dog_beg
        lda #1
        sta dog_gaveup
        jmp l_dg_choose
+       dec dog_timer
        bne l_dg_out
        jsr bark_now_and_then
        jmp l_dg_choose
l_dg_notbeg:
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
        sta dog_gaveup          ; (fed: it may beg again when it's hungry)
l_dg_choose:
        ; he's asleep: the dog keeps him company, lying quietly by his bed
        jsr person_sleeping
        bcc l_dgc_up
        lda #0                  ; (no begging till he's up)
        sta dog_beg
        lda #<DOG_BEDSIDE_X
        sta dog_tx
        lda #0
        sta dog_tx+1
        lda #1
        jmp dog_route
l_dgc_up:
        ; whistled for: down to him
        lda dog_called
        beq +
        jsr dog_beg_x           ; (beside him)
        lda #0
        jmp dog_route
+       ; hungry (or its mealtime) and nothing in the bowl: go and beg
        lda bowl_full
        bne l_dg_bowl
        lda dog_beg
        bne l_dg_begto
        lda dog_gaveup          ; given up: lie down by the bowl and wait
        beq +
        lda #<40
        sta dog_tx
        lda #0
        sta dog_tx+1
        lda #0
        jmp dog_route
+       jsr dog_meal_due
        bcs +
        lda dog_hunger
        cmp #60
        bcc l_dg_bowl
+       lda #1
        sta dog_beg
        lda #0
        sta dog_begt
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
+       jmp bark_now_and_then
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

