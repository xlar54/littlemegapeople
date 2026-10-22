; sim/person.asm -- His body: walking, the stairs (part of the simulation; included after sim/sim.asm)
;---------------------------------------------------------------------------------------
; Body: the per-tick state machine
;---------------------------------------------------------------------------------------
; His walking pace: a step on 230 ticks in 256 (about 90%) when he's well,
; 154 in 256 (about 60%) when he's sick. C = 1: step this tick.
walk_acc:       .byte 0
walk_pace:
        lda #230
        ldx health
        cpx #40
        bcs +
        lda #154
+       clc
        adc walk_acc
        sta walk_acc
        rts
l_pu_rest:
        rts

person_update:
        inc p_anim
        lda p_state
        cmp #PS_IDLE
        beq person_choose
        cmp #PS_WALK
        bne +
        jsr walk_pace
        bcc l_pu_rest
        jmp person_walk
+       cmp #PS_CLIMB
        bne +
        jsr walk_pace
        bcc l_pu_rest
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
        jsr fr_ai_filter        ; (his friend's here: cards with him, not you)
+       jsr fetch_filter        ; (fetch: only if the dog's up for it; whistled
        cmp #A_LEASH            ;  down first if it's upstairs)
        ; (the dog's not downstairs for its walk: whistle it down)
        bne +
        ldx #1                  ; (a walk under way, however it began)
        stx walk_stage
        ldx dog_floor
        bne l_pc_whistle
        ldx dog_state
        cpx #5
        bne +
l_pc_whistle:
        lda #A_WHISTLE
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
+       cpx #A_WHISTLE          ; on the ground floor, where he is (or
        bne +                   ;  near the foot of the stairs)
        lda #0
        sta goal_floor
        lda p_x
        sta goal_x
        lda p_x+1
        sta goal_x+1
        lda p_floor
        beq l_pc_wh
        lda #<200
        sta goal_x
        lda #>200
        sta goal_x+1
l_pc_wh:
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
        bcc l_pc_leashmin       ; (not off the left of the house: the dog
        bne +                   ;  by its bowl, say)
        lda goal_x
        cmp #WALK_MIN_X
        bcs +
l_pc_leashmin:
        lda #WALK_MIN_X
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
        lda dog_x               ; (close beside it, to reach down to it)
        clc
        adc #12
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
; goal_floor. (Never further left than WALK_MIN_X: off past the stove is
; off the screen.)
WALK_MIN_X      = 16
set_walk_target:
        lda p_floor
        cmp goal_floor
        bne +
        lda goal_x
        sta p_tx
        lda goal_x+1
        sta p_tx+1
        bne l_swt_out
        lda p_tx
        cmp #WALK_MIN_X
        bcs l_swt_out
        lda #WALK_MIN_X
        sta p_tx
l_swt_out:
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
        lda p_x+1               ; (never on past the stove, off the screen,
        bne +                   ;  whatever sent him: he's there)
        lda p_x
        cmp #WALK_MIN_X + 1
        bcs +
        sta p_tx
        lda #0
        sta p_tx+1
        rts
+       lda p_x
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
        lda p_pending           ; (asked for something on the stairs: that
        beq +                   ;  next, not on to what he was going to do)
        lda #PS_IDLE
        sta p_state
        rts
+       jsr set_walk_target
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

