; sim/actors.asm -- Drawing the actors (part of the simulation; included after sim/sim.asm)
;---------------------------------------------------------------------------------------
; Actor renderer: erase last frame's sprites, draw this frame's.
; Actor 0 = person, 1 = dog, 2 = effect, 3 = dog bowl food, 4 = sleeping head.
;---------------------------------------------------------------------------------------
ACTORS          = 12        ; 5 = censor mosaic, 6 = the vacuum left standing, 7 his friend, 8 his chair, 9 his plate, 10 his game, 11 the ball
act_vis:        .fill ACTORS, 0
act_sprl:       .fill ACTORS, 0
act_sprh:       .fill ACTORS, 0
act_sprb:       .fill ACTORS, 0
act_xl2:        .fill ACTORS, 0
act_xh2:        .fill ACTORS, 0
act_y:          .fill ACTORS, 0
act_flip:       .fill ACTORS, 0
prev_valid:     .fill ACTORS, 0
act_masked:     .byte 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0  ; him, his mosaic, the vacuum, his friend go behind furniture
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
; carrying something: the same, the arm bent out in front to it
walkc_sprl: .byte <SPR_WALKC0, <SPR_WALKC1, <SPR_WALKC2, <SPR_WALKC3
walkc_sprh: .byte >SPR_WALKC0, >SPR_WALKC1, >SPR_WALKC2, >SPR_WALKC3
carry_now:  .byte 0         ; 1 = whoever's being drawn is carrying something
bounce:    .byte 0, 1, 3, 4, 5, 4, 3, 1

actors_build:
        lda #0
        sta act_vis+4
        jsr friend_sprite       ; (his friend: the same, on his state)
        jsr ball_sprite         ; (the dog's ball)
        jsr phone_sprite        ; (the phone, ringing)
        jsr paper_step_sprite   ; (the morning paper on the step)
        ldx #0                  ; (Larry carrying something -- a delivery, or
        lda held                ;  what he's holding, not the vacuum: that's
        beq +                   ;  pushed)
        cmp #HELD_VAC
        beq ++
        inx
        bra ++
+       lda delivery
        beq +
        lda carrying
        beq +
        inx
+       stx carry_now
        jsr person_sprite
        jmp l_ab_after_person

; The person (Larry, or his friend swapped in) into actor 0.
person_sprite:
        lda #0
        sta act_vis+0
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
        lda carry_now
        bne l_ab_walkc
        lda walk_sprl,x
        sta act_sprl+0
        lda walk_sprh,x
        sta act_sprh+0
        jmp l_ab_person_done
l_ab_walkc:
        lda walkc_sprl,x
        sta act_sprl+0
        lda walkc_sprh,x
        sta act_sprh+0
        jmp l_ab_person_done
+       cmp #PM_STAND
        bne +
        #SETACT 0, SPR_STAND
        lda carry_now
        beq l_ab_stand_done
        #SETACT 0, SPR_STANDC
l_ab_stand_done:
        jmp l_ab_person_done
+       cmp #PM_PONG
        bne +
        jmp pong_person_sprite
+       cmp #PM_SIPDOWN
        beq +
        cmp #PM_SIPUP
        bne ++
+       jmp sip_person_sprite
+       cmp #PM_BENDSIDE
        bne l_ab_notbendside
        #SETACT 0, SPR_BENDSIDE
        lda p_flip
        bne l_ab_bs_stroke
        sec                     ; facing left: the lean padding is on the left
        lda act_xl2+0
        sbc #5
        sta act_xl2+0
        lda act_xh2+0
        sbc #0
        sta act_xh2+0
l_ab_bs_stroke:
        lda p_act               ; petting the dog: his arm down to it, the
        cmp #A_PETDOG           ;  hand stroking (8px of padding on the left)
        bne l_ab_bs_done
        #SETACT 0, SPR_PETSIDE0
        lda pet_wig
        beq +
        #SETACT 0, SPR_PETSIDE1
+       sec
        lda act_xl2+0
        sbc #8
        sta act_xl2+0
        lda act_xh2+0
        sbc #0
        sta act_xh2+0
l_ab_bs_done:
        jmp l_ab_person_done
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
        rts
l_ab_after_person:
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
        ldx dog_petted          ; being petted (and not eating): sat up for it
        beq l_ab_dog_free
        cmp #3
        bne l_ab_dog_beg
l_ab_dog_free:
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
l_ab_dog_beg:
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
        ; the book in his hands, open or turning a page (or the paper)
        lda paper_on
        bne l_ab_paper
        #SETACT 2, SPR_BOOKOPEN
        lda book_page
        beq l_ab_book_at
        #SETACT 2, SPR_BOOKTURN
        bra l_ab_book_at
l_ab_paper:
        #SETACT 2, SPR_PAPEROPEN
        lda book_page
        beq l_ab_book_at
        #SETACT 2, SPR_PAPERTURN
l_ab_book_at:
        lda #<BOOK_X
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
; head turning left and right every few steps; on a side flight walking,
; facing the way it's going, a tread at a time.
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
        ; a side flight: walking, facing the way it's going, its feet going
        ; up (or down) a tread at a time
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
        and #$FC                ; (4px treads)
        sec
        sbc #15
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
        ; draw back to front: bowl, vacuum, sleeping head, person, hands /
        ; screen, effect -- and the dog over all of them
        ldx #3
        jsr l_ar_draw
        ldx #6
        jsr l_ar_draw
        ldx #4
        jsr l_ar_draw
        ldx #8
        jsr l_ar_draw
        jsr fr_in_front         ; (his friend: in front on the stairs if he
        bcs l_ar_frfront        ;  got onto them first)
        ldx #7
        jsr l_ar_draw
        ldx #9
        jsr l_ar_draw
        ldx #10
        jsr l_ar_draw
        ldx #0
        jsr l_ar_draw
        bra l_ar_rest
l_ar_frfront:
        ldx #0
        jsr l_ar_draw
        ldx #7
        jsr l_ar_draw
        ldx #9
        jsr l_ar_draw
        ldx #10
        jsr l_ar_draw
l_ar_rest:
        ldx #5
        jsr l_ar_draw
        ldx #2
        jsr l_ar_draw
        ldx #1
        jsr l_ar_draw
        ldx #11                 ; (the ball: in its mouth)
        jsr l_ar_draw
        lda p_act               ; (petting the dog: his hand on top of it)
        cmp #A_PETDOG
        bne l_ar_out
        lda p_mode
        cmp #PM_BENDSIDE
        bne l_ar_out
        ldx #0
        jmp l_ar_draw
l_ar_out:
        rts

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
        lda #0                  ; (his friend: in his own colours)
        cpx #7
        bne +
        lda #1
+       sta spr_remap
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

