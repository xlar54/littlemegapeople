;=======================================================================================
; LITTLE MEGA PEOPLE -- a MEGA65 tribute to Activision's Little Computer People
; (Amiga, 1987). 320x200 FCM, 256 colours, software sprites cut from the Amiga art.
;
; Boot order (see mega-simcity's notes on why it matters):
;   cld / cli, KERNAL-load every asset while the machine is still in its pristine
;   BASIC65 state, THEN sei, 40 MHz, FCM screen. The KERNAL is never called again.
;=======================================================================================

        .cpu "45gs02"
        .weak
AUTOTEST = 0                    ; 64tass -D AUTOTEST=<activity> for test builds
        .endweak
        ; All text is plain ASCII: the in-game font is ASCII-indexed.
        .enc "ascii"
        .cdef " ~", 32
        .include "platform.asm"
        .include "gen/assets.asm"

;=======================================================================================
; BASIC stub - BANK 0 : SYS 8210 ($2012)
;=======================================================================================
        * = $2001
        .word (+), 2026
        .byte $fe, $02, $30     ; BANK 0
        .byte ':'
        .byte $9e               ; SYS
        .text "8210"
        .byte 0
+       .word 0

        * = $2012

main_entry:
        cld
        cli
        ; keep BASIC's zero page so F7 can return to it
        ldx #$02
-       lda $00,x
        sta zp_save,x
        inx
        cpx #$40
        bne -
        tsx
        stx stack_save

        jsr boot_load
        sei
        jsr enable_40mhz
        jsr mult_init
        jsr screen_fcm_init
        jsr sound_init
        jsr pal_apply_all

        .if AUTOTEST == 0
        jsr title_run
        .else
        lda #'T'
        sta player_name
        lda #0
        sta player_name+1
        .endif

        ; the house
        jsr screen_off
        lda #ATTIC_WORK_BANK
        jsr image_from_attic
        jsr sim_init
        .if AUTOTEST != 0
        lda #AUTOTEST           ; test build: skip the arrival, go straight to it
        sta p_pending
        .weak
AUTOHOUR = 8
        .endweak
        lda #AUTOHOUR
        sta clock_hour
        lda #50
        sta clock_min
        .endif
        jsr lights_update
        jsr pal_apply_all
        jsr palette_animate
        lda #1
        sta ui_dirty
        jsr ui_tick
        jsr screen_on
        jsr key_flush

game_loop:
        jsr wait_frame
        jsr actors_render
        jsr palette_animate
        jsr ui_tick
        jsr sound_tick
        jsr input_tick
        lda quit_request
        bne game_quit
        ldx #1
        lda fast_forward
        beq +
        ldx #4
+       stx l_gl_n
-       jsr sim_tick
        dec l_gl_n
        bne -
        jsr actors_build
        inc frame_count
        bra game_loop
l_gl_n:  .byte 0

game_quit:
        jsr sound_init
        lda #0
        sta SID_VOLUME
        jsr screen_restore_basic
        ldx #$02
-       lda zp_save,x
        sta $00,x
        inx
        cpx #$40
        bne -
        ldx stack_save
        txs
        cli
        rts

zp_save:    .fill $40, 0
stack_save: .byte 0

enable_40mhz:
        lda #65
        sta $00
        lda #$47
        sta VIC4_KEY
        lda #$53
        sta VIC4_KEY
        lda #CPU_40MHZ_BIT
        tsb VIC3_CTRL
        lda #$80
        tsb VIC4_HOTREGS
        ; the speed switch can disturb the CIA port directions
        lda #$FF
        sta $DC02
        lda #$00
        sta $DC03
        rts

; Wait for the raster to reach line 251 (just below the picture).
wait_frame:
l_wf1:   lda VIC_RASTER          ; leave the trigger zone first
        cmp #251
        bcc l_wf2
        lda VIC_CTRL1
        bpl l_wf1
l_wf2:   lda VIC_CTRL1
        bmi l_wf2
        lda VIC_RASTER
        cmp #251
        bcc l_wf2
        rts

;=======================================================================================
; Boot loading: disk -> $50000 stage -> Attic. gfx stays at $50000.
;=======================================================================================
LOAD_FILE .macro name, nameend
        lda #<\name
        sta l_bl_name
        lda #>\name
        sta l_bl_name+1
        lda #\nameend - \name
        sta l_bl_len
        jsr boot_load_file
.endmacro

boot_load:
        jsr boot_banner
        #LOAD_FILE fn_bg, fn_bg_end
        ; stage -> attic work + pristine
        ldy #ATTIC_WORK_BANK
        jsr stage_to_attic
        ldy #ATTIC_PRISTINE_BANK
        jsr stage_to_attic
        #LOAD_FILE fn_title, fn_title_end
        ldy #ATTIC_TITLE_BANK
        jsr stage_to_attic
        #LOAD_FILE fn_gfx, fn_gfx_end
        rts

l_bl_name:  .word 0
l_bl_len:   .byte 0
l_bl_tries: .byte 0

boot_load_file:
        lda #3
        sta l_bl_tries
l_blf_try:
        lda #STAGE_BANK         ; data bank 5, filename bank 0
        ldx #$00
        jsr KERNAL_SETBNK
        lda #0
        ldx #8
        ldy #0
        jsr KERNAL_SETLFS
        lda l_bl_len
        ldx l_bl_name
        ldy l_bl_name+1
        jsr KERNAL_SETNAM
        lda #$40                ; raw load to X/Y (the PRG header lands too)
        ldx #$00
        ldy #$00
        jsr KERNAL_LOAD
        bcc l_blf_ok
        dec l_bl_tries
        bne l_blf_try
        inc $D020               ; visible hint that a load failed
l_blf_ok:
        lda #'.'
        jsr $FFD2
        rts

; Y = attic bank: copy the 64000-byte body at $50002 there.
stage_to_attic:
        sty dma_dst_bank
        lda #0
        sta dma_src_mb
        lda #ATTIC_MB
        sta dma_dst_mb
        lda #<2
        sta dma_src
        lda #0
        sta dma_src+1
        lda #STAGE_BANK
        sta dma_src_bank
        lda #0
        sta dma_dst
        sta dma_dst+1
        lda #<IMAGE_SIZE
        sta dma_len
        lda #>IMAGE_SIZE
        sta dma_len+1
        jmp dma_copy

boot_banner:
        ldx #0
-       lda l_bb_text,x
        beq +
        jsr $FFD2
        inx
        bne -
+       rts
l_bb_text:
        .byte 147, 13
        .text "LITTLE MEGA PEOPLE"
        .byte 13
        .text "MOVING IN"
        .byte 0

fn_bg:          .text "LMP-BG"
fn_bg_end:
fn_title:       .text "LMP-TITLE"
fn_title_end:
fn_gfx:         .text "LMP-GFX"
fn_gfx_end:

;=======================================================================================
; Modules
;=======================================================================================
        .include "render.asm"
        .include "ui.asm"
        .include "input.asm"
        .include "sim.asm"
        .include "letters.asm"
        .include "cards.asm"
        .include "poker.asm"
        .include "sound.asm"
        .include "title.asm"
        .include "gen/palette.asm"
        .include "gen/notes.asm"

        .cerror * > $A000, "program grew past $A000"
