; acts/core.asm -- The activities themselves: start / every frame / end (part of the simulation; included after sim/sim.asm)
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

