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
AUTOFRIEND = 0                  ; 1: his friend rings in a few seconds, stays 3 min
        .endweak
        ; All text is plain ASCII: the in-game font is ASCII-indexed.
        .enc "ascii"
        .cdef " ~", 32
        .include "platform.asm"
        .include "gen/assets.asm"

;=======================================================================================
; BASIC stub - BANK 0 : SYS 8210 ($2012)
;=======================================================================================
; Two parts: the program proper ($2001-$BFFF, the PRG that's RUN) and a
; high part at $C000-$CFFF, assembled from the same source but written to its
; own file (LMP-HI) and copied into place at boot; $C000 is RAM once the
; character ROM is mapped out ($D030 bit 5).
        * = $2001
        .dsection lo
        .cerror * > $C000, "program grew past $C000"
        * = $C000
        .dsection hi
hi_end:
        .cerror * > $D000, "high part grew past $D000"

        .section lo
        .word (+), 2026
        .byte $fe, $02, $30     ; BANK 0
        .byte ':'
        .byte $9e               ; SYS
        .text "8210"
        .byte 0
+       .word 0
        .fill $2012 - *, 0

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
        lda $D030               ; character ROM out of $C000: RAM there (the
        sta d030_save           ;  high part)
        and #%11011111
        sta $D030
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
        jsr rtc_read            ; (the real date, as the title page would set)
        lda #AUTOTEST           ; test build: skip the arrival, go straight to it
        sta p_pending
        jsr dog_arrive          ; (the dog comes in with him)
        .weak
AUTOHOUR = 8
        .endweak
        lda #AUTOHOUR
        sta clock_hour
        .if AUTOFRIEND == 5     ; (already in, up in the attic)
        lda #FRS_VISIT
        sta fr_state
        lda #2
        sta FR(p_floor)
        lda #200
        sta FR(p_x)
        lda #FLOOR2_Y
        sta FR(p_y)
        lda #PM_STAND
        sta FR(p_mode)
        lda #5
        sta fr_stay
        lda #<6000              ; (and a record playing)
        sta record_left
        lda #>6000
        sta record_left+1
        .elsif AUTOFRIEND != 0
        lda #FRS_COMING
        sta fr_state
        lda #<1400
        sta fr_t
        lda #>1400
        sta fr_t+1
        .endif
        .weak
AUTODLV = 1                     ; with AUTOTEST=A_DELIVERY: what's on the step
        .endweak
        .if AUTOTEST == A_DELIVERY
        lda #AUTODLV
        sta delivery
        .endif
        .weak
AUTOFLOOR = 0
        .endweak
        .if AUTOFLOOR == 2      ; start in the attic, by the stairs
        lda #2
        sta p_floor
        lda #190
        sta p_x
        lda #0
        sta p_x+1
        lda #FLOOR2_Y
        sta p_y
        .endif
        .weak
AUTOMIN = 50
        .endweak
        lda #AUTOMIN
        sta clock_min
        jsr clock_hands
        .weak
AUTOFOOD = 255                  ; test builds: food / hunger / health to start
AUTOHUNGER = 255                ;  with (255 = leave as normal)
AUTOHEALTH = 255
AUTODOGFOOD = 255
AUTOTRIP = 255
AUTOPLEA = 0
AUTODOGUP = 0
        .endweak
        .if AUTODOGUP != 0      ; (the dog starts upstairs, by the bed)
        lda #1
        sta dog_floor
        sta dog_goal_floor
        lda #FLOOR1_Y + 4
        sta dog_yb
        lda #80
        sta dog_x
        lda #0
        sta dog_x+1
        .endif
        .if AUTOPLEA != 0
        lda #1
        sta sleep_plea
        .endif
        .if AUTOTRIP != 255
        lda #AUTOTRIP
        sta night_trip
        .endif
        .if AUTODOGFOOD != 255
        lda #AUTODOGFOOD
        sta dogfood
        .endif
        .if AUTOFOOD != 255
        lda #AUTOFOOD
        sta food
        .endif
        .if AUTOHUNGER != 255
        lda #AUTOHUNGER
        sta hunger
        .endif
        .if AUTOHEALTH != 255
        lda #AUTOHEALTH
        sta health
        .endif
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
        jsr lip_sync
        jsr actors_build
        inc frame_count
        bra game_loop
l_gl_n:  .byte 0

game_quit:
        jsr sound_init
        lda #0
        sta SID_VOLUME
        jsr screen_restore_basic
        lda d030_save           ; (BASIC's ROM mapping back)
        sta $D030
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
d030_save:  .byte 0

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
        ; digital sounds: stage -> Attic (played via a chip-RAM buffer)
        #LOAD_FILE fn_sounds, fn_sounds_end
        ldy #ATTIC_SOUNDS_BANK
        jsr stage_to_sounds
        #LOAD_FILE fn_sounds2, fn_sounds2_end
        ldy #ATTIC_SOUNDS_BANK + 1
        jsr stage_to_sounds
        ; cell patches: stage -> Attic (DMA'd into the house image)
        #LOAD_FILE fn_patches, fn_patches_end
        jsr stage_to_patches
        #LOAD_FILE fn_hi, fn_hi_end
        jsr stage_to_hi
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
fn_sounds:      .text "LMP-SOUNDS"
fn_sounds_end:
fn_sounds2:     .text "LMP-SOUNDS2"
fn_sounds2_end:
fn_patches:     .text "LMP-PATCHES"
fn_patches_end:
fn_hi:          .text "LMP-HI"
fn_hi_end:

; copy the program's high part from the stage ($50002) to $C000 (bank 0 RAM,
; under the character ROM until that's mapped out)
stage_to_hi:
        lda #0
        sta dma_src_mb
        sta dma_dst_mb
        sta dma_dst_bank
        lda #<2
        sta dma_src
        lda #0
        sta dma_src+1
        lda #STAGE_BANK
        sta dma_src_bank
        lda #<$C000
        sta dma_dst
        lda #>$C000
        sta dma_dst+1
        lda #<(hi_end - $C000)
        sta dma_len
        lda #>(hi_end - $C000)
        sta dma_len+1
        jmp dma_copy

; copy the cell patches from the stage ($50002) to Attic ($8040000)
stage_to_patches:
        lda #0
        sta dma_src_mb
        lda #ATTIC_PATCH_MB
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
        lda #ATTIC_PATCH_BANK
        sta dma_dst_bank
        lda #<PATCHES_SIZE
        sta dma_len
        lda #>PATCHES_SIZE
        sta dma_len+1
        jmp dma_copy

; copy the sound bank from the stage ($50002) to Attic ($8030000)
; Y = Attic bank: copy a sound bank (a whole 64K) from the stage ($50002)
stage_to_sounds:
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
        lda #<$FFF0
        sta dma_len
        lda #>$FFF0
        sta dma_len+1
        jmp dma_copy

;=======================================================================================
; Modules
;=======================================================================================
        .include "render.asm"
        .include "ui.asm"
        .include "input.asm"
        .include "sim.asm"
        .include "friend.asm"
        .include "letters.asm"
        .include "poker.asm"
        .include "sound.asm"
        .include "gen/palette.asm"
        .include "gen/notes.asm"
        .send lo

        .section hi             ; ($C000: the title page, the card table)
        .include "title.asm"
        .include "cards.asm"
        .send hi
