;=======================================================================================
; Little Mega People -- hardware registers, memory map, shared constants.
;
; Memory map
;   $0002-$00FF   zero page (ours once boot loading is done; KERNAL is not used
;                 after boot and IRQs stay disabled)
;   $2001-$9FFF   program (BASIC stub + code + tables), guarded at assemble time
;   $16000        FCM screen RAM: 1000 cells x 2 bytes (16-bit char codes)
;   $40000        FCM char data: 1000 cells x 64 bytes, cell n = row n/40, col n%40
;   $50000        gfx.prg (font, sprites, patches); also the boot load stage
;   $8000000      Attic: working house image (patches applied)
;   $8010000      Attic: pristine house image (for undoing patches)
;   $8020000      Attic: guestbook title image
;
; Palette (see tools/build_assets.py, which owns the colour values)
;   0             transparent / black       1..17  Amiga house colours
;   18..24        animated props            25..30 the person (skin/hair/clothes)
;   32..47        UI                        64..143 title page and logo
;=======================================================================================

; --- VIC ---------------------------------------------------------------------------
BORDERCOL               = $D020
BACKCOL                 = $D021
VIC_CTRL1               = $D011
VIC_RASTER              = $D012
VIC4_KEY                = $D02F
VIC3_CTRL               = $D031
VIC4_TEXTXPOS           = $D04C
VIC4_TEXTYPOS           = $D04E
VIC4_CTRL               = $D054
VIC4_LINESTPLSB         = $D058
VIC4_LINESTPMSB         = $D059
VIC4_HOTREGS            = $D05D
VIC4_CHRCOUNT           = $D05E
VIC4_SCRNPTRLSB         = $D060
VIC4_SCRNPTRMSB         = $D061
VIC4_SCRBPTRBNK         = $D062
VIC4_SCRNPTRMB          = $D063
VIC4_COLPTRLSB          = $D064
VIC4_COLPTRMSB          = $D065
VIC4_CHARPTRLSB         = $D068
VIC4_CHARPTRMSB         = $D069
VIC4_CHARPTRBNK         = $D06A
VIC4_CHARPTRMB          = $D06B
VIC4_DISPROWS           = $D07B
SPRITE_ENABLE           = $D015
PALREG_R                   = $D100
PALREG_G                   = $D200
PALREG_B                   = $D300
CPU_40MHZ_BIT           = $40

; --- misc I/O ----------------------------------------------------------------------
KEYQUEUE                = $D610     ; ASCII of next key; any write dequeues it
KEYMODS                 = $D611     ; bit 2 = CTRL
KEYMOD_CTRL             = $04
MULTINA                 = $D770
MULTINB                 = $D774
MULTOUT                 = $D778
SID                     = $D400
SID_VOLUME              = $D418

; --- KERNAL (boot only) ------------------------------------------------------------
KERNAL_SETBNK           = $FF6B
KERNAL_SETLFS           = $FFBA
KERNAL_SETNAM           = $FFBD
KERNAL_LOAD             = $FFD5

; --- memory ------------------------------------------------------------------------
SCREEN_RAM              = $16000
CHAR_DATA               = $40000
CHAR_CODE_BASE          = CHAR_DATA / 64
STAGE_BANK              = $05       ; boot loads land at $50000
ATTIC_MB                = $80
ATTIC_WORK_BANK         = $00       ; $8000000
ATTIC_PRISTINE_BANK     = $01       ; $8010000
ATTIC_TITLE_BANK        = $02       ; $8020000
IMAGE_SIZE              = 64000

; --- screen geometry ---------------------------------------------------------------
COLS                    = 40
ROWS                    = 25
CELL_ROW_BYTES          = COLS * 64 ; 2560

; --- palette slots -----------------------------------------------------------------
C_BLACK                 = 10        ; Amiga black
C_WHITE                 = 4
C_SKY                   = 18
C_TVSCR                 = 19
C_MONITOR               = 20
C_BOTTLE                = 21
C_FIRE_A                = 22
C_FIRE_B                = 23
C_FIRE_C                = 24
C_SKIN                  = 25
C_HAIR                  = 26
C_SHIRT                 = 27
C_SHIRT2                = 28
C_PANTS                 = 29
C_SHOES                 = 30
C_PANTS2                = 31
C_DIM_LAST              = 31        ; 1..31 dim with the house lights
C_BAR                   = 32
C_TEXT                  = 33
C_SPEECH                = 34
C_UIWHITE               = 35
C_GREEN                 = 36
C_YELLOW                = 37
C_RED                   = 38
C_PAPER                 = 39
C_INK                   = 40
C_CARDRED               = 41
C_CARDBLACK             = 42
C_CARDBACK              = 43
C_FELT                  = 44
C_DKGREY                = 45
C_HILITE                = 46
C_PAPER2                = 47
C_PAGE                  = 68        ; guestbook page brown
C_PAGETEXT              = 70        ; guestbook orange ink
C_PAGEDARK              = 65

; --- key codes ---------------------------------------------------------------------
KEY_RETURN              = $0D
KEY_DEL                 = $14
KEY_ESC                 = $1B
KEY_F1                  = $F1
KEY_F3                  = $F3
KEY_F5                  = $F5
KEY_F7                  = $F7

; --- zero page ---------------------------------------------------------------------
ZDST                    = $10       ; 32-bit pointer (destination)
ZSRC                    = $14       ; 32-bit pointer (source)
ZPTR                    = $18       ; 16-bit pointer (bank-0 data, strings)
ZPTR2                   = $1A       ; 16-bit pointer
ZTMP                    = $1C       ; 4 scratch bytes
ZMASK                   = $20       ; 32-bit pointer into the foreground mask
