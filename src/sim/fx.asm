; sim/fx.asm -- Floating effects (part of the simulation; included after sim/sim.asm)
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
; Hearts rising over the dog's head (sat up, being petted), again and again
; till cleared.
fx_heart_on_dog:
        sec
        lda dog_x
        sbc #2
        tax
        lda dog_x+1
        sbc #0
        pha
        lda dog_yb
        sec
        sbc #26
        tay
        lda #3
        sec
        jsr l_fx_set
        pla
        sta fx_x+1
        rts
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

