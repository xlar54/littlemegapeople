;=======================================================================================
; Rendering: DMA helpers, FCM screen setup, palette, software sprites, cell patches,
; 8x8 text glyphs and windows.
;
; FCM layout reminder: the screen is 40x25 cells, each cell a unique 64-byte char
; at CHAR_DATA + cell*64 (row-major cells). Pixel (x, y) lives at
;     CHAR_DATA + (y>>3)*2560 + (x>>3)*64 + (y&7)*8 + (x&7)
; (y>>3)*2560 is just ((y>>3)*10) << 8, which row10 gives as a high byte.
;
; F018B inline DMA list format used throughout (follows `sta $D707`):
;     $80 src_mb, $81 dst_mb, $00          enhanced options: source/dest megabyte
;     cmd (0 copy, 3 fill), count.w, src.w, src_bank, dst.w, dst_bank, $00, modulo.w
; For a fill the low byte of src is the fill value.
;=======================================================================================

;---------------------------------------------------------------------------------------
; Generic DMA copy / fill. Callers set the dma_* fields (self-modified list).
;---------------------------------------------------------------------------------------
dma_copy:
        lda #$00
        sta $D707
        .byte $80
dma_src_mb:
        .byte $00
        .byte $81
dma_dst_mb:
        .byte $00
        .byte $00
        .byte $00
dma_len:
        .word 0
dma_src:
        .word 0
dma_src_bank:
        .byte 0
dma_dst:
        .word 0
dma_dst_bank:
        .byte 0
        .byte $00
        .word $0000
        rts

dma_fill:
        lda #$00
        sta $D707
        .byte $81
dmf_dst_mb:
        .byte $00
        .byte $00
        .byte $03
dmf_len:
        .word 0
dmf_value:
        .word 0
        .byte 0
dmf_dst:
        .word 0
dmf_dst_bank:
        .byte 0
        .byte $00
        .word $0000
        rts

; Copy a whole 64000-byte image from Attic bank A to char data.
; A = attic bank ($00 work, $01 pristine, $02 title).
image_from_attic:
        sta dma_src_bank
        lda #ATTIC_MB
        sta dma_src_mb
        lda #0
        sta dma_dst_mb
        sta dma_src
        sta dma_src+1
        sta dma_dst
        sta dma_dst+1
        lda #`CHAR_DATA
        sta dma_dst_bank
        lda #<IMAGE_SIZE
        sta dma_len
        lda #>IMAGE_SIZE
        sta dma_len+1
        jmp dma_copy

; Copy Attic bank X -> Attic bank Y (whole image).
attic_to_attic:
        stx dma_src_bank
        sty dma_dst_bank
        lda #ATTIC_MB
        sta dma_src_mb
        sta dma_dst_mb
        lda #0
        sta dma_src
        sta dma_src+1
        sta dma_dst
        sta dma_dst+1
        lda #<IMAGE_SIZE
        sta dma_len
        lda #>IMAGE_SIZE
        sta dma_len+1
        jmp dma_copy

;---------------------------------------------------------------------------------------
; Screen mode. Derived from mega-simcity/m65-fcm: FCM 40x25 at H320.
;---------------------------------------------------------------------------------------
screen_fcm_init:
        lda #$47
        sta VIC4_KEY
        lda #$53
        sta VIC4_KEY
        lda #$80
        trb VIC4_HOTREGS
        lda VIC_CTRL1
        and #%11101111          ; blank while we reprogram
        sta VIC_CTRL1

        lda #%00000111          ; CHR16 + FCLRLO + FCLRHI
        sta VIC4_CTRL
        lda VIC3_CTRL
        and #%01011111          ; H320, no attribute bit yet
        ora #%00100000          ; attribute mode
        sta VIC3_CTRL

        lda #<(COLS * 2)
        sta VIC4_LINESTPLSB
        lda #>(COLS * 2)
        sta VIC4_LINESTPMSB
        lda #COLS
        sta VIC4_CHRCOUNT
        lda #ROWS
        sta VIC4_DISPROWS
        lda #$50
        sta VIC4_TEXTXPOS
        lda #0
        sta VIC4_TEXTXPOS+1
        lda #$69
        sta VIC4_TEXTYPOS

        lda #<SCREEN_RAM
        sta VIC4_SCRNPTRLSB
        lda #>SCREEN_RAM
        sta VIC4_SCRNPTRMSB
        lda #`SCREEN_RAM
        sta VIC4_SCRBPTRBNK
        lda #0
        sta VIC4_SCRNPTRMB
        sta VIC4_COLPTRLSB
        sta VIC4_COLPTRMSB
        lda #$00
        sta VIC4_CHARPTRLSB
        lda #$D8
        sta VIC4_CHARPTRMSB
        lda #$02
        sta VIC4_CHARPTRBNK
        lda #0
        sta VIC4_CHARPTRMB

        jsr screen_fill_codes
        ; colour RAM: all zero (no NCM bit, no attributes) -- 2 bytes per cell
        lda #$FF
        sta dmf_dst_mb
        lda #<2000
        sta dmf_len
        lda #>2000
        sta dmf_len+1
        lda #0
        sta dmf_value
        sta dmf_dst
        sta dmf_dst+1
        lda #$08
        sta dmf_dst_bank
        jsr dma_fill

        lda #0
        sta BORDERCOL
        sta BACKCOL
        sta SPRITE_ENABLE
        rts

screen_on:
        lda VIC_CTRL1
        ora #%00010000
        sta VIC_CTRL1
        rts

screen_off:
        lda VIC_CTRL1
        and #%11101111
        sta VIC_CTRL1
        rts

; Screen RAM: cell n shows char CHAR_CODE_BASE + n.
screen_fill_codes:
        lda #<SCREEN_RAM
        sta ZDST
        lda #>SCREEN_RAM
        sta ZDST+1
        lda #`SCREEN_RAM
        sta ZDST+2
        lda #0
        sta ZDST+3
        lda #<CHAR_CODE_BASE
        sta ZTMP
        lda #>CHAR_CODE_BASE
        sta ZTMP+1
        lda #<1000
        sta ZTMP+2
        lda #>1000
        sta ZTMP+3
l_sfc_loop:
        ldz #0
        lda ZTMP
        sta [ZDST],z
        inz
        lda ZTMP+1
        sta [ZDST],z
        inw ZTMP
        clc
        lda ZDST
        adc #2
        sta ZDST
        bcc +
        inc ZDST+1
+       lda ZTMP+2
        bne +
        dec ZTMP+3
+       dec ZTMP+2
        lda ZTMP+2
        ora ZTMP+3
        bne l_sfc_loop
        rts

; Back to the BASIC text screen (Q to quit).
screen_restore_basic:
        lda #$47
        sta VIC4_KEY
        lda #$53
        sta VIC4_KEY
        lda #$80
        tsb VIC4_HOTREGS
        lda #0
        sta VIC4_CTRL
        lda VIC3_CTRL
        ora #%10000000
        and #%11011111
        sta VIC3_CTRL
        lda #80
        sta VIC4_LINESTPLSB
        sta VIC4_CHRCOUNT
        lda #0
        sta VIC4_LINESTPMSB
        sta VIC4_SCRNPTRLSB
        sta VIC4_SCRBPTRBNK
        sta VIC4_SCRNPTRMB
        lda #$08
        sta VIC4_SCRNPTRMSB
        lda #$00
        sta VIC4_CHARPTRLSB
        lda #$D0
        sta VIC4_CHARPTRMSB
        lda #$02
        sta VIC4_CHARPTRBNK
        lda #25
        sta VIC4_DISPROWS
        lda #$68
        sta VIC4_TEXTYPOS
        ; default 16-colour palette
        ldx #15
-       lda l_srb_r,x
        sta PALREG_R,x
        lda l_srb_g,x
        sta PALREG_G,x
        lda l_srb_b,x
        sta PALREG_B,x
        dex
        bpl -
        lda #6
        sta BORDERCOL
        sta BACKCOL
        jsr screen_on
        rts
l_srb_r: .byte $00,$0F,$0F,$00,$0F,$00,$00,$0F,$0F,$0A,$0F,$05,$08,$09,$09,$0B
l_srb_g: .byte $00,$0F,$00,$0F,$00,$0F,$00,$0F,$06,$04,$07,$05,$08,$0F,$09,$0B
l_srb_b: .byte $00,$0F,$00,$0F,$0F,$00,$0F,$00,$00,$00,$07,$05,$08,$09,$0F,$0B

;---------------------------------------------------------------------------------------
; Palette. pal_r/g/b (gen/palette.asm) hold raw 8-bit values. Entries 1..31 are
; scaled by pal_dim (255 = full brightness) so the house can go dark at night.
;---------------------------------------------------------------------------------------
pal_dim:
        .byte 255

mult_init:
        lda #0
        sta MULTINA+1
        sta MULTINA+2
        sta MULTINA+3
        sta MULTINB+1
        sta MULTINB+2
        sta MULTINB+3
        rts

; A = value -> A = value * pal_dim / 256 (rounded up so 255 stays ~255)
pal_scale:
        sta MULTINA
        lda pal_dim
        sta MULTINB
        lda MULTOUT+1
        rts

pal_apply_all:
        ldx #0
l_paa:
        jsr pal_dimmed
        bcc l_paa_full
        lda pal_r,x
        jsr pal_scale
        tay
        lda nib_swap,y
        sta PALREG_R,x
        lda pal_g,x
        jsr pal_scale
        tay
        lda nib_swap,y
        sta PALREG_G,x
        lda pal_b,x
        jsr pal_scale
        tay
        lda nib_swap,y
        sta PALREG_B,x
        bra l_paa_next
l_paa_full:
        ldy pal_r,x
        lda nib_swap,y
        sta PALREG_R,x
        ldy pal_g,x
        lda nib_swap,y
        sta PALREG_G,x
        ldy pal_b,x
        lda nib_swap,y
        sta PALREG_B,x
l_paa_next:
        inx
        bne l_paa
        rts

; C = 1 if palette entry X dims with the house lights (1..31 and the dots)
pal_dimmed:
        cpx #0
        beq l_pd_no
        cpx #C_DIM_LAST+1
        bcc l_pd_yes
        cpx #C_DOTS_SHIRT
        bcc l_pd_no
        cpx #C_DIM2_LAST+1
        bcc l_pd_yes
l_pd_no:
        clc
        rts
l_pd_yes:
        sec
        rts

; Set one palette entry: X = index, A = red, pe_g, pe_b. Dimmed per pal_dimmed.
pe_g:   .byte 0
pe_b:   .byte 0
pal_set:
        pha
        jsr pal_dimmed
        pla
        bcc l_ps_raw
        jsr pal_scale
        tay
        lda nib_swap,y
        sta PALREG_R,x
        lda pe_g
        jsr pal_scale
        tay
        lda nib_swap,y
        sta PALREG_G,x
        lda pe_b
        jsr pal_scale
        tay
        lda nib_swap,y
        sta PALREG_B,x
        rts
l_ps_raw:
        tay
        lda nib_swap,y
        sta PALREG_R,x
        ldy pe_g
        lda nib_swap,y
        sta PALREG_G,x
        ldy pe_b
        lda nib_swap,y
        sta PALREG_B,x
        rts

; Set palette entry X from a 3-byte RGB table entry at ZPTR + Y*3.
pal_set_from:
        sty ZTMP
        tya
        asl
        clc
        adc ZTMP
        tay
        lda (ZPTR),y
        pha
        iny
        lda (ZPTR),y
        sta pe_g
        iny
        lda (ZPTR),y
        sta pe_b
        pla
        jmp pal_set

;---------------------------------------------------------------------------------------
; Cell offsets. cell_off: X = column, Y = row -> co_lo/co_hi = (row*40+col)*64.
;---------------------------------------------------------------------------------------
row10:
        .byte range(0, 250, 10)

co_lo:  .byte 0
co_hi:  .byte 0
cell_off:
        txa
        and #3
        lsr
        ror
        ror                     ; (col & 3) << 6
        sta co_lo
        txa
        lsr
        lsr
        clc
        adc row10,y
        sta co_hi
        rts

; A = number of cells -> dma_len = A*64
cells_len:
        pha
        and #3
        lsr
        ror
        ror
        sta dma_len
        pla
        lsr
        lsr
        sta dma_len+1
        rts

;---------------------------------------------------------------------------------------
; Restore a cell rectangle (inclusive) from the Attic working image.
;---------------------------------------------------------------------------------------
rc_x0:  .byte 0
rc_y0:  .byte 0
rc_x1:  .byte 0
rc_y1:  .byte 0
l_rc_row: .byte 0

restore_cells:
        ; never trust the rectangle: clamp to the screen, refuse inverted ones
        lda rc_x1
        cmp #COLS
        bcc +
        lda #COLS - 1
        sta rc_x1
+       lda rc_y1
        cmp #ROWS
        bcc +
        lda #ROWS - 1
        sta rc_y1
+       lda rc_x1
        cmp rc_x0
        bcs +
        rts
+       lda rc_y1
        cmp rc_y0
        bcs +
        rts
+       lda #ATTIC_MB
        sta dma_src_mb
        lda #ATTIC_WORK_BANK
        sta dma_src_bank
        lda #0
        sta dma_dst_mb
        lda #`CHAR_DATA
        sta dma_dst_bank
        sec
        lda rc_x1
        sbc rc_x0
        clc
        adc #1
        jsr cells_len
        lda rc_y0
        sta l_rc_row
l_rc_loop:
        ldx rc_x0
        ldy l_rc_row
        jsr cell_off
        lda co_lo
        sta dma_src
        sta dma_dst
        lda co_hi
        sta dma_src+1
        sta dma_dst+1
        jsr dma_copy
        lda l_rc_row
        cmp rc_y1
        beq l_rc_done
        inc l_rc_row
        bra l_rc_loop
l_rc_done:
        rts

; Fill a cell rectangle (rc_*) with colour A in char data.
fill_cells:
        sta dmf_value
        lda #0
        sta dmf_dst_mb
        lda #`CHAR_DATA
        sta dmf_dst_bank
        sec
        lda rc_x1
        sbc rc_x0
        clc
        adc #1
        jsr cells_len
        lda dma_len
        sta dmf_len
        lda dma_len+1
        sta dmf_len+1
        lda rc_y0
        sta l_rc_row
l_fc_loop:
        ldx rc_x0
        ldy l_rc_row
        jsr cell_off
        lda co_lo
        sta dmf_dst
        lda co_hi
        sta dmf_dst+1
        jsr dma_fill
        lda l_rc_row
        cmp rc_y1
        beq l_fc_done
        inc l_rc_row
        bra l_fc_loop
l_fc_done:
        rts

;---------------------------------------------------------------------------------------
; Patches: cell-aligned prop images (fridge open, fire lit ...). Applying one
; writes it into the Attic working image and the screen; removing one copies the
; pristine cells back. X = patch id.
;---------------------------------------------------------------------------------------
PATCH_DOOR      = 0
PATCH_FRIDGE    = 1
PATCH_CLOSET    = 2
PATCH_FIRE      = 3
PATCH_CURTAIN1  = 4         ; shower curtain a third, two thirds, fully drawn
PATCH_CURTAIN2  = 5
PATCH_CURTAIN3  = 6
PATCH_DRAWER1   = 7         ; filing cabinet drawer half / fully out
PATCH_DRAWER2   = 8
PATCH_PHONE     = 9         ; handset lifted off the phone
PATCH_WC        = 10        ; bathroom WC door open
PATCH_CUPBOARD  = 11        ; food cupboard open with 0..4 jars (11..15)
PATCH_DOGCAB    = 16        ; dog-food cupboard open with 0..4 cans (16..20)

patch_cx:  .byte PATCH_DOOR_OPEN_CX, PATCH_FRIDGE_OPEN_CX, PATCH_CLOSET_OPEN_CX, PATCH_FIRE_LIT_CX, PATCH_CURTAIN_1_CX, PATCH_CURTAIN_2_CX, PATCH_CURTAIN_3_CX, PATCH_DRAWER_1_CX, PATCH_DRAWER_2_CX, PATCH_PHONE_OFF_CX, PATCH_WC_OPEN_CX, PATCH_CUPBOARD_0_CX, PATCH_CUPBOARD_1_CX, PATCH_CUPBOARD_2_CX, PATCH_CUPBOARD_3_CX, PATCH_CUPBOARD_4_CX, PATCH_DOGCAB_0_CX, PATCH_DOGCAB_1_CX, PATCH_DOGCAB_2_CX, PATCH_DOGCAB_3_CX, PATCH_DOGCAB_4_CX
patch_cy:  .byte PATCH_DOOR_OPEN_CY, PATCH_FRIDGE_OPEN_CY, PATCH_CLOSET_OPEN_CY, PATCH_FIRE_LIT_CY, PATCH_CURTAIN_1_CY, PATCH_CURTAIN_2_CY, PATCH_CURTAIN_3_CY, PATCH_DRAWER_1_CY, PATCH_DRAWER_2_CY, PATCH_PHONE_OFF_CY, PATCH_WC_OPEN_CY, PATCH_CUPBOARD_0_CY, PATCH_CUPBOARD_1_CY, PATCH_CUPBOARD_2_CY, PATCH_CUPBOARD_3_CY, PATCH_CUPBOARD_4_CY, PATCH_DOGCAB_0_CY, PATCH_DOGCAB_1_CY, PATCH_DOGCAB_2_CY, PATCH_DOGCAB_3_CY, PATCH_DOGCAB_4_CY
patch_cw:  .byte PATCH_DOOR_OPEN_CW, PATCH_FRIDGE_OPEN_CW, PATCH_CLOSET_OPEN_CW, PATCH_FIRE_LIT_CW, PATCH_CURTAIN_1_CW, PATCH_CURTAIN_2_CW, PATCH_CURTAIN_3_CW, PATCH_DRAWER_1_CW, PATCH_DRAWER_2_CW, PATCH_PHONE_OFF_CW, PATCH_WC_OPEN_CW, PATCH_CUPBOARD_0_CW, PATCH_CUPBOARD_1_CW, PATCH_CUPBOARD_2_CW, PATCH_CUPBOARD_3_CW, PATCH_CUPBOARD_4_CW, PATCH_DOGCAB_0_CW, PATCH_DOGCAB_1_CW, PATCH_DOGCAB_2_CW, PATCH_DOGCAB_3_CW, PATCH_DOGCAB_4_CW
patch_ch:  .byte PATCH_DOOR_OPEN_CH, PATCH_FRIDGE_OPEN_CH, PATCH_CLOSET_OPEN_CH, PATCH_FIRE_LIT_CH, PATCH_CURTAIN_1_CH, PATCH_CURTAIN_2_CH, PATCH_CURTAIN_3_CH, PATCH_DRAWER_1_CH, PATCH_DRAWER_2_CH, PATCH_PHONE_OFF_CH, PATCH_WC_OPEN_CH, PATCH_CUPBOARD_0_CH, PATCH_CUPBOARD_1_CH, PATCH_CUPBOARD_2_CH, PATCH_CUPBOARD_3_CH, PATCH_CUPBOARD_4_CH, PATCH_DOGCAB_0_CH, PATCH_DOGCAB_1_CH, PATCH_DOGCAB_2_CH, PATCH_DOGCAB_3_CH, PATCH_DOGCAB_4_CH
patch_lo:  .byte <PATCH_DOOR_OPEN, <PATCH_FRIDGE_OPEN, <PATCH_CLOSET_OPEN, <PATCH_FIRE_LIT, <PATCH_CURTAIN_1, <PATCH_CURTAIN_2, <PATCH_CURTAIN_3, <PATCH_DRAWER_1, <PATCH_DRAWER_2, <PATCH_PHONE_OFF, <PATCH_WC_OPEN, <PATCH_CUPBOARD_0, <PATCH_CUPBOARD_1, <PATCH_CUPBOARD_2, <PATCH_CUPBOARD_3, <PATCH_CUPBOARD_4, <PATCH_DOGCAB_0, <PATCH_DOGCAB_1, <PATCH_DOGCAB_2, <PATCH_DOGCAB_3, <PATCH_DOGCAB_4
patch_hi:  .byte >PATCH_DOOR_OPEN, >PATCH_FRIDGE_OPEN, >PATCH_CLOSET_OPEN, >PATCH_FIRE_LIT, >PATCH_CURTAIN_1, >PATCH_CURTAIN_2, >PATCH_CURTAIN_3, >PATCH_DRAWER_1, >PATCH_DRAWER_2, >PATCH_PHONE_OFF, >PATCH_WC_OPEN, >PATCH_CUPBOARD_0, >PATCH_CUPBOARD_1, >PATCH_CUPBOARD_2, >PATCH_CUPBOARD_3, >PATCH_CUPBOARD_4, >PATCH_DOGCAB_0, >PATCH_DOGCAB_1, >PATCH_DOGCAB_2, >PATCH_DOGCAB_3, >PATCH_DOGCAB_4
patch_bk:  .byte `PATCH_DOOR_OPEN, `PATCH_FRIDGE_OPEN, `PATCH_CLOSET_OPEN, `PATCH_FIRE_LIT, `PATCH_CURTAIN_1, `PATCH_CURTAIN_2, `PATCH_CURTAIN_3, `PATCH_DRAWER_1, `PATCH_DRAWER_2, `PATCH_PHONE_OFF, `PATCH_WC_OPEN, `PATCH_CUPBOARD_0, `PATCH_CUPBOARD_1, `PATCH_CUPBOARD_2, `PATCH_CUPBOARD_3, `PATCH_CUPBOARD_4, `PATCH_DOGCAB_0, `PATCH_DOGCAB_1, `PATCH_DOGCAB_2, `PATCH_DOGCAB_3, `PATCH_DOGCAB_4
patch_state: .fill 21, 0

l_pa_id:   .byte 0
l_pa_row:  .byte 0
l_pa_src:  .byte 0, 0, 0
l_pa_len:  .word 0

patch_apply:
        lda patch_state,x
        bne l_pa_out
        lda #1
        sta patch_state,x
        stx l_pa_id
        lda patch_lo,x
        sta l_pa_src
        lda patch_hi,x
        sta l_pa_src+1
        lda patch_bk,x
        sta l_pa_src+2
        lda patch_cw,x
        jsr cells_len
        lda dma_len
        sta l_pa_len
        lda dma_len+1
        sta l_pa_len+1
        lda #0
        sta l_pa_row
l_pa_loop:
        ldx l_pa_id
        lda patch_cy,x
        clc
        adc l_pa_row
        tay
        lda patch_cx,x
        tax
        jsr cell_off
        ; source (bank 5) -> attic work
        lda #0
        sta dma_src_mb
        lda #ATTIC_MB
        sta dma_dst_mb
        lda l_pa_src
        sta dma_src
        lda l_pa_src+1
        sta dma_src+1
        lda l_pa_src+2
        sta dma_src_bank
        lda co_lo
        sta dma_dst
        lda co_hi
        sta dma_dst+1
        lda #ATTIC_WORK_BANK
        sta dma_dst_bank
        jsr dma_copy
        ; source -> screen
        lda #0
        sta dma_dst_mb
        lda #`CHAR_DATA
        sta dma_dst_bank
        jsr dma_copy
        ; next source row
        clc
        lda l_pa_src
        adc l_pa_len
        sta l_pa_src
        lda l_pa_src+1
        adc l_pa_len+1
        sta l_pa_src+1
        lda l_pa_src+2
        adc #0
        sta l_pa_src+2
        inc l_pa_row
        ldx l_pa_id
        lda l_pa_row
        cmp patch_ch,x
        bne l_pa_loop
l_pa_out:
        rts

patch_remove:
        lda patch_state,x
        beq l_pr_out
        lda #0
        sta patch_state,x
        stx l_pa_id
        lda patch_cw,x
        jsr cells_len
        lda #0
        sta l_pa_row
l_pr_loop:
        ldx l_pa_id
        lda patch_cy,x
        clc
        adc l_pa_row
        tay
        lda patch_cx,x
        tax
        jsr cell_off
        lda #ATTIC_MB
        sta dma_src_mb
        sta dma_dst_mb
        lda #ATTIC_PRISTINE_BANK
        sta dma_src_bank
        lda #ATTIC_WORK_BANK
        sta dma_dst_bank
        lda co_lo
        sta dma_src
        sta dma_dst
        lda co_hi
        sta dma_src+1
        sta dma_dst+1
        jsr dma_copy
        lda #0
        sta dma_dst_mb
        lda #`CHAR_DATA
        sta dma_dst_bank
        lda #ATTIC_WORK_BANK
        sta dma_src_bank
        jsr dma_copy
        inc l_pa_row
        ldx l_pa_id
        lda l_pa_row
        cmp patch_ch,x
        bne l_pr_loop
l_pr_out:
        rts

;---------------------------------------------------------------------------------------
; Software sprites. Format in bank 5: w, h, then w*h palette indices (0 = clear).
; In:  spr_addr (24-bit), spr_x (word), spr_y, spr_flip (0 = as stored, 1 = mirror)
; Out: spr_cx0/cy0/cx1/cy1 = the cell rectangle touched.
;---------------------------------------------------------------------------------------
spr_addr:  .byte 0, 0, 0
spr_x:     .word 0
spr_y:     .byte 0
spr_flip:  .byte 0
spr_mask:  .byte 0      ; 1 = furniture in the foreground mask hides this sprite
spr_cx0:   .byte 0
spr_cy0:   .byte 0
spr_cx1:   .byte 0
spr_cy1:   .byte 0
l_ds_w:     .byte 0
l_ds_vw:    .byte 0     ; visible width after right-edge clipping
l_ds_h:     .byte 0
l_ds_yy:    .byte 0
l_ds_sub:   .byte 0
l_ds_x64lo: .byte 0
l_ds_x64hi: .byte 0
l_ds_tmp:   .word 0
rowbuf:    .fill 40, 0
l_ds_mb:   .byte 0      ; foreground mask bits for the current cell row
l_ds_pix:  .byte 0
bitmask:   .byte $80, $40, $20, $10, $08, $04, $02, $01

; ZMASK = GFX_MASK + (char-data offset in ZDST) / 8, and load that mask byte.
mask_point:
        lda ZDST+1
        sta ZMASK+1
        lda ZDST
        lsr ZMASK+1
        ror
        lsr ZMASK+1
        ror
        lsr ZMASK+1
        ror
        clc
        adc #<GFX_MASK
        sta ZMASK
        lda ZMASK+1
        adc #>GFX_MASK
        sta ZMASK+1
        lda #`GFX_MASK
        adc #0
        sta ZMASK+2
        lda #0
        sta ZMASK+3
        phz
        ldz #0
        lda [ZMASK],z
        sta l_ds_mb
        plz
        rts

draw_sprite:
        lda spr_addr
        sta ZSRC
        lda spr_addr+1
        sta ZSRC+1
        lda spr_addr+2
        sta ZSRC+2
        lda #0
        sta ZSRC+3
        ldz #0
        lda [ZSRC],z
        sta l_ds_w
        inz
        lda [ZSRC],z
        sta l_ds_h
        ; never trust a header: a bad sprite pointer must not overrun rowbuf
        lda l_ds_w
        beq l_ds_bad
        cmp #41
        bcs l_ds_bad
        lda l_ds_h
        beq l_ds_bad
        cmp #65
        bcc l_ds_hdr_ok
l_ds_bad:
        ldz #0
        sec
        rts
l_ds_hdr_ok:
        clc
        lda ZSRC
        adc #2
        sta ZSRC
        bcc +
        inw ZSRC+1
+
        ; Off screen (x >= 320 or y >= 200 -- which is also how a slightly
        ; negative position looks)? Draw nothing; C = 1 tells the caller there
        ; is no rectangle to restore. Without this a wrapped rectangle became a
        ; multi-KB restore DMA that ran past char RAM into the font and sprites.
        lda spr_x+1
        beq l_ds_xok
        cmp #1
        bne l_ds_off
        lda spr_x
        cmp #64
        bcs l_ds_off
l_ds_xok:
        lda spr_y
        cmp #200
        bcc l_ds_on
l_ds_off:
        sec
        rts
l_ds_on:
        ; visible width: clip at the right edge so x + vw <= 320
        sec
        lda #<320
        sbc spr_x
        sta l_ds_tmp
        lda #>320
        sbc spr_x+1
        sta l_ds_tmp+1
        lda l_ds_w
        sta l_ds_vw
        lda l_ds_tmp+1
        bne +
        lda l_ds_tmp
        cmp l_ds_w
        bcs +
        sta l_ds_vw
+
        ; cell rectangle
        lda spr_x+1
        lsr
        lda spr_x
        ror
        lsr
        lsr
        sta spr_cx0
        clc
        lda spr_x
        adc l_ds_vw
        sta l_ds_tmp
        lda spr_x+1
        adc #0
        sta l_ds_tmp+1
        lda l_ds_tmp
        bne +
        dec l_ds_tmp+1
+       dec l_ds_tmp
        lda l_ds_tmp+1
        lsr
        lda l_ds_tmp
        ror
        lsr
        lsr
        sta spr_cx1
        lda spr_y
        lsr
        lsr
        lsr
        sta spr_cy0
        ; bottom row, clamped to the screen (rows below 200 are not drawn)
        clc
        lda spr_y
        adc l_ds_h
        bcs l_ds_ybot
        sec
        sbc #1
        cmp #200
        bcc +
l_ds_ybot:
        lda #199
+       lsr
        lsr
        lsr
        sta spr_cy1
        ; column offset of cx0 in bytes, and sub-cell start
        lda spr_cx0
        and #3
        lsr
        ror
        ror
        sta l_ds_x64lo
        lda spr_cx0
        lsr
        lsr
        sta l_ds_x64hi
        lda spr_x
        and #7
        sta l_ds_sub
        lda spr_y
        sta l_ds_yy

l_ds_row:
        ; --- fetch one source row into rowbuf (mirrored if flipped) ---
        ldz #0
        lda spr_flip
        bne l_ds_flip
        ldy #0
l_ds_c:  lda [ZSRC],z
        sta rowbuf,y
        inz
        iny
        cpy l_ds_w
        bne l_ds_c
        bra l_ds_have
l_ds_flip:
        ldy l_ds_w
        dey
l_ds_f:  lda [ZSRC],z
        sta rowbuf,y
        inz
        dey
        bpl l_ds_f
l_ds_have:
        clc
        lda ZSRC
        adc l_ds_w
        sta ZSRC
        bcc +
        inw ZSRC+1
+
        ; --- destination address of the first pixel in this row ---
        lda l_ds_yy
        cmp #200
        bcs l_ds_next            ; clip rows below the screen
        lsr
        lsr
        lsr
        tax
        lda l_ds_yy
        and #7
        asl
        asl
        asl
        clc
        adc l_ds_x64lo
        sta ZDST
        lda row10,x
        adc l_ds_x64hi
        sta ZDST+1
        lda #`CHAR_DATA
        sta ZDST+2
        lda #0
        sta ZDST+3
        lda spr_mask
        beq +
        jsr mask_point          ; ZMASK -> this cell row's mask byte
+       ldy #0
        ldz l_ds_sub
l_ds_px:
        lda rowbuf,y
        beq l_ds_skip
        ldx spr_mask
        beq l_ds_put
        sta l_ds_pix            ; furniture in front? leave the background
        tza
        tax
        lda bitmask,x
        and l_ds_mb
        bne l_ds_skip
        lda l_ds_pix
l_ds_put:
        sta [ZDST],z
l_ds_skip:
        inz
        cpz #8
        bne l_ds_nx
        ldz #0
        clc
        lda ZDST
        adc #64
        sta ZDST
        bcc +
        inc ZDST+1
+       lda spr_mask
        beq l_ds_nx
        clc                     ; next cell: mask byte is 8 further on
        lda ZMASK
        adc #8
        sta ZMASK
        bcc +
        inw ZMASK+1
+       phz
        ldz #0
        lda [ZMASK],z
        sta l_ds_mb
        plz
l_ds_nx:
        iny
        cpy l_ds_vw
        bne l_ds_px
l_ds_next:
        inc l_ds_yy
        dec l_ds_h
        bne l_ds_row
        ldz #0
        clc
        rts

;---------------------------------------------------------------------------------------
; Text. draw_glyph: A = ASCII code, X = column, Y = row; colours txt_fg / txt_bg.
;---------------------------------------------------------------------------------------
txt_fg:   .byte C_TEXT
txt_bg:   .byte C_BAR
l_dg_bits: .byte 0
l_dg_row:  .byte 0

draw_glyph:
        and #$7F
        sta ZSRC
        lda #0
        sta ZSRC+1
        asl ZSRC
        rol ZSRC+1
        asl ZSRC
        rol ZSRC+1
        asl ZSRC
        rol ZSRC+1
        clc
        lda ZSRC
        adc #<GFX_FONT
        sta ZSRC
        lda ZSRC+1
        adc #>GFX_FONT
        sta ZSRC+1
        lda #`GFX_FONT
        sta ZSRC+2
        lda #0
        sta ZSRC+3
        jsr cell_off
        lda co_lo
        sta ZDST
        lda co_hi
        sta ZDST+1
        lda #`CHAR_DATA
        sta ZDST+2
        lda #0
        sta ZDST+3
        lda #0
        sta l_dg_row
l_dg_r:
        ldz l_dg_row
        lda [ZSRC],z
        sta l_dg_bits
        lda l_dg_row
        asl
        asl
        asl
        taz
        ldx #8
l_dg_b:
        asl l_dg_bits
        lda txt_bg
        bcc +
        lda txt_fg
+       sta [ZDST],z
        inz
        dex
        bne l_dg_b
        inc l_dg_row
        lda l_dg_row
        cmp #8
        bne l_dg_r
        ldz #0
        rts

; Print zero-terminated string at ZPTR to (X = col, Y = row). Stops at col 40.
pr_col: .byte 0
pr_row: .byte 0
print_str:
        stx pr_col
        sty pr_row
        ldy #0
l_ps_loop:
        lda (ZPTR),y
        beq l_ps_done
        phy
        ldx pr_col
        ldy pr_row
        jsr draw_glyph
        ply
        iny
        inc pr_col
        lda pr_col
        cmp #COLS
        bcc l_ps_loop
l_ps_done:
        rts

; Print A spaces from (X, Y).
print_spaces:
        sta ZTMP+3
        stx pr_col
        sty pr_row
l_psp:   lda ZTMP+3
        beq l_psp_done
        lda #' '
        ldx pr_col
        ldy pr_row
        jsr draw_glyph
        inc pr_col
        dec ZTMP+3
        bra l_psp
l_psp_done:
        rts

;---------------------------------------------------------------------------------------
; Windows: a paper rectangle (rc_*) with a 1px ink border inset 2px.
;---------------------------------------------------------------------------------------
l_w_c:   .byte 0
win_border_col: .byte C_INK

draw_window:
        jsr fill_cells
        ; top and bottom border lines (pixel row 2 of the top cells, 5 of bottom)
        lda rc_x0
        sta l_w_c
l_dw_h:
        ldx l_w_c
        ldy rc_y0
        jsr cell_off
        lda #2*8
        jsr l_dw_hline_cell
        ldx l_w_c
        ldy rc_y1
        jsr cell_off
        lda #5*8
        jsr l_dw_hline_cell
        lda l_w_c
        cmp rc_x1
        beq l_dw_v0
        inc l_w_c
        bra l_dw_h
l_dw_v0:
        lda rc_y0
        sta l_w_c
l_dw_v:
        ldx rc_x0
        ldy l_w_c
        jsr cell_off
        lda #2
        jsr l_dw_vline_cell
        ldx rc_x1
        ldy l_w_c
        jsr cell_off
        lda #5
        jsr l_dw_vline_cell
        lda l_w_c
        cmp rc_y1
        beq l_dw_done
        inc l_w_c
        bra l_dw_v
l_dw_done:
        rts

l_dw_ptr:
        pha
        lda co_lo
        sta ZDST
        lda co_hi
        sta ZDST+1
        lda #`CHAR_DATA
        sta ZDST+2
        lda #0
        sta ZDST+3
        pla
        rts

; A = byte offset of the pixel row within the cell; draws 8 pixels, clipped to
; the inset (2px) on the window's outer columns.
l_dw_hline_cell:
        jsr l_dw_ptr
        taz
        ldx #8
        lda win_border_col
-       sta [ZDST],z
        inz
        dex
        bne -
        ldz #0
        rts

; A = pixel column within the cell; draws 8 pixels down.
l_dw_vline_cell:
        jsr l_dw_ptr
        taz
        ldx #8
-       lda win_border_col
        sta [ZDST],z
        tza
        clc
        adc #8
        taz
        dex
        bne -
        ldz #0
        rts
