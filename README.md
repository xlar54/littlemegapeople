Little Mega People
==================

A MEGA65 tribute to Activision's *Little Computer People* (1985), built from the
look of the 1987 **Amiga** version. A little man (and his dog) move into the house
inside your computer. He lives his own life — eating, sleeping, playing the piano,
watching TV, typing you letters — and you can talk to him, send him things, and
play cards with him. Neglect him and he gets lonely, knocks on the inside of the
screen, or gets sick and turns green.

The display is FCM (Full Colour Mode) at **320x200 in 256 colours**: every pixel
is a palette index, and the house is a pixel-for-pixel rebuild of the Amiga
screen in the Amiga's colours.

Build and run
-------------

```
build.bat            assemble src\main.asm (64tass) and pack target\littlemegapeople.d81 (c1541)
build.bat assets     regenerate the art first (python tools\build_assets.py), then build
run.bat              build and launch in Xemu (C:\Emulation\Mega65\xmega65.exe)
```

The D81 holds the program (`LITTLEMEGAPEOPLE`, first on the disk so autoboot /
`RUN"*"` picks it up) and three data files: `LMP-BG` (the house), `LMP-TITLE`
(the guestbook) and `LMP-GFX` (font, sprites, prop patches).

Playing
-------

Sign the **guestbook**: type your name, the time of day (`HHMM`) and `A`/`P` for
AM/PM, then RETURN. He arrives through the front door with his dog.

**Talk to him** by typing and pressing RETURN. Say *please* — he is far more
willing when you are polite, and in a good mood. Things to ask: *play the
piano, watch TV, read a book, eat, drink, dance, put on a record, exercise,
take a bath, brush your teeth, write a letter, play cards / poker, feed the dog,
pet the dog, light a fire, use the phone, play solitaire, change clothes, go to
bed, go out*. You can also just say *hello*, *how are you* or *thank you*.

| Key      | Effect                                              |
|----------|-----------------------------------------------------|
| CTRL-F   | send groceries (food supply +3)                     |
| CTRL-W   | top up his water bottle                             |
| CTRL-D   | send dog food                                       |
| CTRL-B   | send a book (he goes to read it)                    |
| CTRL-R   | send a record (he puts it on and dances)            |
| CTRL-P   | pet him (best while he sits in his armchair)        |
| CTRL-C   | phone him                                           |
| CTRL-A   | ring his alarm clock (wakes him — grumpily at night)|
| F1       | help                                                |
| F5       | fast-forward time (x4)                              |
| F7       | quit to BASIC                                       |

The top bar shows what he is saying or doing, and the time, food, water, dog
food and his mood.

**Cards.** At the attic desk he plays *Poker* (five-card draw: `1`-`5` mark
cards to swap, RETURN draws) or *Twenty-One* (`H` hit, `S` stand). He likes to
win; if you win too often he sulks.

**Letters.** Every so often he sits at the typewriter and writes to you — about
the dog, running out of water or food, a gift you sent, or that he hasn't heard
from you in a while.

**Knocking.** If you ignore him for long enough he walks to the front, turns to
face you and taps on the inside of the glass (*tink tink tink*), then talks to
you. If he asks you to play poker, answer *yes*.

Life in the house
-----------------

* **Needs:** hunger, thirst, energy, mood and health. He eats from the fridge,
  drinks from the water cooler and sleeps at night (lights go down, pyjamas on).
  Starve him or let the water run dry and his health falls — he turns green and
  spends more time in bed. Supplies only come from you.
* **Routines:** gets dressed in the morning (closet in the attic), brushes his
  teeth after meals, lights the fire in the evening, sometimes goes out.
* **The house:** the clock drives the sky colour through the day; the fire,
  TV, computer monitor and water bottle are animated through their own palette
  entries; the fridge, closet, front door and fireplace swap in cell patches.
* **Stairs:** he climbs the front-facing step blocks in back view and walks the
  side-on flights sideways, feet on the treads.
* **The dog** trots around the ground floor, follows him, naps, barks, and
  eats from its bowl when it's been fed.

Architecture
------------

`src/main.asm` boots: it KERNAL-loads the three data files while the machine is
still in its pristine BASIC65 state (stage at `$50000`, DMA up to Attic RAM),
then `sei`, 40 MHz, FCM screen, title, and the frame loop:

```
wait for raster 251 -> erase/draw actors -> palette animation -> top bar
-> sound -> keyboard -> simulation tick(s) -> build next frame's actors
```

| File | What it does |
|------|--------------|
| `platform.asm` | registers, memory map, palette slots, key codes |
| `render.asm`   | DMA helpers, FCM setup, palette + night dimming, software sprite blitter, cell patches, 8x8 text, windows |
| `sim.asm`      | clock, needs, the brain (`ai_choose`), requests, gifts, activities, stairs, dog, effects, actor renderer |
| `ui.asm`       | string builder, speech/status bar, help and text windows |
| `input.asm`    | `$D610` keyboard queue, typed line, CTRL gifts, keyword parser |
| `letters.asm`  | letters chosen from the state of the house |
| `cards.asm`, `poker.asm` | Twenty-One and five-card draw |
| `sound.asm`    | SID tunes (Für Elise on the piano, a boogie record) and effects |
| `title.asm`    | the guestbook title with the shimmering logo |
| `gen/*.asm`    | generated: palette, sprite/patch addresses, SID note table |

**Memory:** program `$2001`-`$9FFF`; FCM screen RAM `$16000`; char data `$40000`
(1000 unique cells x 64 bytes); `LMP-GFX` stays at `$50000`; Attic holds the
working house image (`$8000000`), a pristine copy for undoing patches
(`$8010000`) and the title (`$8020000`).

**Software sprites:** FCM is one byte per pixel, so sprites are drawn straight
into char data with transparency (index 0), mirrored on the fly. Each frame the
cells each actor touched are restored from the Attic house image by DMA, then
all actors are redrawn — during vertical blank, so there is no flicker.

**Palette:** 1-17 the Amiga house colours; 18-24 animated props (sky, TV,
monitor, water bottle, flames); 25-31 the person (skin turns green when sick,
clothes switch to pyjamas); 32-47 UI; 64-143 the guestbook and logo gradient.
Entries 1-31 are dimmed together at night.

Art pipeline
------------

`tools/build_assets.py` (Python 3 + Pillow) builds everything in `assets/` and
`src/gen/` from Amiga screenshots in `art/source/`:

1. Each screenshot (2x/4x/6x captures) is sampled back to native 320x200 and
   snapped to the Amiga's 17-colour palette, then aligned to a reference frame.
2. A per-pixel majority vote across all frames gives the empty house (the man,
   dog and opened props vote themselves out).
3. Each pose (piano, armchair, eating, brushing teeth, climbing, computer...)
   is the difference between a frame and the empty house, flood-filled from the
   outside so wall-coloured pixels inside him are kept; clothes, skin and hair
   are remapped to the person's palette slots.
4. The walk cycle (with bending knees), the front-facing and desk poses, and
   the knocking fist are drawn on top of the extracted art.
5. Prop states (open fridge, open closet, open front door, lit fire) become
   cell-aligned patches.
6. The guestbook gets the new logo, rendered antialiased into a 64-entry
   gradient. The 8x8 font comes from the C128 character ROM.

`art/preview_*.png` show the generated house, title and sprite sheet.

Building a test disk that skips the title and goes straight to an activity:
`64tass --cbm-prg -B -a -D AUTOTEST=<activity number> src/main.asm ...`
(activity numbers are the `A_*` constants in `sim.asm`).

Credits
-------

*Little Computer People* © 1985 Activision, designed by David Crane and Rich Gold;
Amiga version 1987. This is an unofficial fan tribute for the
MEGA65. His voice on the phone is sampled from the Amiga original (a gameplay
recording on YouTube) and played through MEGA65 audio DMA. Reference
screenshots of the Amiga version came from dazeland.com,
mastertronic.co.uk and habr.com; gameplay details from ST-News' review and the
C64 original. Code patterns (FCM setup, DMA, boot loading) follow the author's
mega-simcity and fcmlib projects.

Note: this is a 45GS02 target. `STZ` stores the Z register (not zero) on this
CPU; use `LDA #0 / STA`. Labels are case-insensitive in 64tass, and `_`-prefixed
labels are cheap locals — shared variables here use an `l_` prefix instead.
