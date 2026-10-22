;=======================================================================================
; His activities: one line each. #ACT numbers them in order (A_xxx), and
; appends each column to its table -- where he goes (floor, x), the way he
; faces when he gets there (0 left, 1 right), what runs at the start, every
; frame, and at the end, and the status line ("Larry" + text).
; To add one: a line at the end (and its st_/tk_/en_ routines and nm_ text).
;=======================================================================================
act_n           .var 0
ACT             .segment id, floor, x, face, start, tick, end, name
\id             = act_n
act_n           := act_n + 1
                .section s_act_floor
                .byte \floor
                .send s_act_floor
                .section s_act_xl
                .byte <(\x)
                .send s_act_xl
                .section s_act_xh
                .byte >(\x)
                .send s_act_xh
                .section s_act_face
                .byte \face
                .send s_act_face
                .section s_act_start
                .word \start
                .send s_act_start
                .section s_act_tick
                .word \tick
                .send s_act_tick
                .section s_act_end
                .word \end
                .send s_act_end
                .section s_act_names
                .word \name
                .send s_act_names
                .endsegment

;              name,       floor, x,   face, start,        tick,         end,          status

        #ACT A_NONE,      0,   0, 0, st_none,      tk_none,      en_none,      nm_none
        #ACT A_FRIDGE,    0,  52, 0, st_fridge,    tk_none,      en_fridge,    nm_fridge
        #ACT A_MEAL,      0, 122, 1, st_meal,      tk_meal,      en_meal,      nm_meal
        #ACT A_DRINK,     0, 138, 1, st_drink,     tk_drink,     en_drink,     nm_drink
        #ACT A_FEEDDOG,   0,  28, 0, st_feeddog,   tk_feeddog,   en_feeddog,   nm_feeddog
        #ACT A_PHONE,     0, 226, 0, st_phone,     tk_phone,     en_phone,     nm_phone
        #ACT A_READ,      1, 252, 1, st_read,      tk_none,      en_read,      nm_read
        #ACT A_FIRE,      0, 268, 1, st_fire,      tk_none,      en_fire,      nm_fire
        #ACT A_GOOUT,     0, 268, 1, st_goout,     tk_goout,     en_goout,     nm_goout
        #ACT A_SLEEP,     1,  40, 0, st_sleep,     tk_sleep,     en_sleep,     nm_sleep
        #ACT A_EXERCISE,  1, 113, 0, st_exercise,  tk_none,      en_exercise,  nm_exercise
        #ACT A_BRUSH,     1, 170, 0, st_brush,     tk_brush,     en_brush,     nm_brush
        #ACT A_WC,        1, 196, 1, st_wc,        tk_wc,        en_wc,        nm_wc
        #ACT A_BATH,      1, 222, 1, st_bath,      tk_bath,      en_bath,      nm_bath
        #ACT A_COMPUTER,  1, 278, 1, st_computer,  tk_computer,  en_computer,  nm_computer
        #ACT A_LETTER,    2, 228, 1, st_letter,    tk_typing,    en_letter,    nm_letter
        #ACT A_TV,        2, 108, 0, st_tv,        tk_none,      en_tv,        nm_tv
        #ACT A_RECORD,    2,  73, 0, st_record,    tk_record,    en_record,    nm_record
        #ACT A_DANCE,     2,  76, 0, st_dance,     tk_none,      en_dance,     nm_dance
        #ACT A_PIANO,     2, 154, 0, st_piano,     tk_piano,     en_piano,     nm_piano
        #ACT A_CHANGE,    1,  83, 0, st_change,    tk_change,    en_change,    nm_change
        #ACT A_POOL,      0, 122, 1, st_pool,      tk_pool,      en_pool,      nm_pool
        #ACT A_CARDS,     0, 122, 1, st_cards,     tk_none,      en_cards,     nm_cards
        #ACT A_KNOCK,     0, 160, 0, st_knock,     tk_knock,     en_knock,     nm_knock
        #ACT A_IDLE,      0,   0, 0, st_idle,      tk_none,      en_none,      nm_none
        #ACT A_PETDOG,    0,   0, 0, st_petdog,    tk_petdog,      en_petdog,    nm_petdog
        #ACT A_ARRIVE,    0, 300, 0, st_arrive,    tk_arrive,    en_arrive,    nm_arrive
        #ACT A_READCHAIR, 0, 226, 0, st_readchair, tk_readchair, en_readchair, nm_readchair  ; reading in the armchair (after the bookshelf)
        #ACT A_FILES,     2, 266, 1, st_files,     tk_files,     en_files,     nm_files      ; looking through the filing cabinet
        #ACT A_CHAT,      0,   0, 0, st_chat,      tk_none,      en_chat,      nm_chat       ; comes to the front and talks to you
        #ACT A_TVON,      2,  62, 0, st_tvswitch,  tk_none,      en_tvon,      nm_tv         ; walks to the attic TV and switches it on
        #ACT A_TVOFF,     2,  62, 0, st_tvswitch,  tk_none,      en_tvoff,     nm_tvoff      ; ...and off again
        #ACT A_WASH,      1, 177, 0, st_wash,      tk_none,      en_wash,      nm_wash       ; washes his hands at the bathroom sink
        #ACT A_DELIVERY,  0, 294, 1, st_delivery,  tk_delivery,  en_delivery,  nm_delivery   ; answers the door and picks up a delivery
        #ACT A_STOW,      0,   0, 0, st_stow,      tk_stow,      en_stow,      nm_stow       ; puts the delivery away
        #ACT A_GETFOOD,   0,  78, 0, st_getfood,   tk_getfood,   en_getfood,   nm_getfood    ; cooking: a jar from the food cupboard
        #ACT A_PREP,      0,  58, 0, st_prep,      tk_prep,      en_prep,      nm_prep       ;   ...preparing it at the counter
        #ACT A_STOVEON,   0,  28, 0, st_stoveon,   tk_stoveon,   en_stoveon,   nm_cook       ;   ...the pot onto the stove
        #ACT A_STOVEOFF,  0,  28, 0, st_stoveoff,  tk_stoveoff,  en_stoveoff,  nm_stoveoff   ;   ...and off again when it's done
        #ACT A_SERVE,     0,  58, 0, st_serve,     tk_prep,      en_serve,     nm_serve      ;   ...dishing up at the counter (then A_MEAL)
        #ACT A_FRIDGEGET, 0,  52, 0, st_fridgeget, tk_fridgeget, en_fridgeget, nm_getfood    ;   ...sometimes something from the fridge too
        #ACT A_DOGFOOD,   0,  56, 0, st_dogfood,   tk_dogfood,   en_dogfood,   nm_feeddog    ; a can from the dog-food cupboard (then A_FEEDDOG)
        #ACT A_GETCUP,    0,  82, 0, st_getcup,    tk_getcup,    en_getcup,    nm_drink      ; a cup from beside the sink (then A_DRINK)
        #ACT A_CUPSINK,   0,  82, 0, st_cupsink,   tk_cupsink,   en_none,      nm_drink      ; the cup back in the sink
        #ACT A_ASKWATER,  0,   0, 0, st_askwater,  tk_none,      en_none,      nm_askwater   ; the bottle's dry: asks you for water
        #ACT A_VACGET,    2, 186, 0, st_vacget,    tk_vacget,    en_vacget,    nm_vacuum     ; (rare) the vacuum from the attic closet...
        #ACT A_VACATTIC,  2, 186, 0, st_vacsweep,  tk_vacsweep,  en_vacsweep,  nm_vacuum     ;   ...vacuums the attic
        #ACT A_VACMID,    1, 141, 0, st_vacsweep,  tk_vacsweep,  en_vacsweep,  nm_vacuum     ;   ...and the middle floor
        #ACT A_VACPUT,    2, 186, 0, st_vacput,    tk_vacput,    en_vacput,    nm_vacuum     ;   ...and puts it away
        #ACT A_VACGROUND, 0, 177, 0, st_vacsweep,  tk_vacsweep,  en_vacsweep,  nm_vacuum     ;   ...and the ground floor
        #ACT A_LEASH,     0,   0, 1, st_leash,     tk_leash,     en_leash,     nm_dogwalk    ; walking the dog: the leash on...
        #ACT A_WALKOUT,   0, 268, 1, st_walkout,   tk_walkout,   en_walkout,   nm_dogwalk    ;   ...out of the front door and back
        #ACT A_UNLEASH,   0, 268, 1, st_unleash,   tk_leash,     en_unleash,   nm_dogwalk    ;   ...and the leash off
        #ACT A_RECSTOP,   2,  73, 0, st_recstop,   tk_recstop,   en_none,      nm_recstop    ; stops the record (when asked)
        #ACT A_VACPICK,   0,   0, 0, st_vacpick,   tk_vacpick,   en_vacpick,   nm_vacuum     ; back to the vacuum he left, picks it up
        #ACT A_DISHES,    0,  82, 0, st_dishes,    tk_none,      en_dishes,    nm_dishes     ; washes up at the kitchen sink after eating
        #ACT A_PHONECALL, 0, 226, 0, st_phonecall, tk_phonecall, en_phone,     nm_phonecall  ; rings someone up himself
        #ACT A_WHISTLE,   0,   0, 0, st_whistle,   tk_whistle,   en_whistle,   nm_whistle    ; whistles the dog down for its walk (or a game)
        #ACT A_GREET,     0, 268, 1, st_greet,     tk_greet,     en_greet,     nm_greet      ; lets his friend in at the front door
        #ACT A_SEEOFF,    0, 268, 1, st_seeoff,    tk_seeoff,    en_seeoff,    nm_seeoff     ; sees him out again
        #ACT A_CARDSF,    0, 122, 1, st_cardsf,    tk_none,      en_cardsf,    nm_cardsf     ; plays cards with him at the kitchen table
        #ACT A_WATCHVG,   1, 250, 1, st_watchvg,   tk_watchvg,   en_none,      nm_watchvg    ; watches him at the video game (their turns)
        #ACT A_INTRO,     0, 248, 0, st_intro,     tk_intro,     en_intro,     nm_intro      ; introduces his friend to you (the first visit)
        #ACT A_RELAX,     0, 226, 0, st_relax,     tk_relax,     en_relax,     nm_relax      ; sits back in the armchair, hands behind his head

        #ACT A_CALLFRIEND, 0, 226, 0, st_callfriend, tk_phonecall, en_phone,    nm_callfriend ; rings Joey to come over (when you ask)

        #ACT A_FETCH,     0, 230, 0, st_fetch,     tk_fetch,     en_fetch,     nm_fetch      ; plays fetch with the dog

        #ACT A_PINGPONG,  2, 195, 1, st_pingpong,  tk_pingpong,  en_pingpong,  nm_pingpong   ; ping pong with Joey at the attic desk

        #ACT A_PHONEIN,   0, 226, 0, st_phonein,   tk_phonein,   en_phone,     nm_phone      ; the phone rings on its own: he answers it

        #ACT A_PAPERGET,  0, 294, 1, st_paperget,  tk_paperget,  en_paperget,  nm_paperget   ; the morning paper off the front step...
        #ACT A_PAPERREAD, 0, 226, 0, st_paperread, tk_paperread, en_paperread, nm_paperread  ;   ...read in the armchair, the news out loud

A_COUNT         = act_n
