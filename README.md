Little Mega People
==================

A MEGA65 tribute to Activision's *Little Computer People* (1985), built from the
look of the 1987 **Amiga** version. A little man (and his dog) move into the house
inside your computer. He lives his own life — eating, sleeping, playing the piano,
watching TV, reading the morning paper, typing you letters, playing fetch with the
dog — and his friend Joey drops by for cards, music, video games and ping pong.
You can talk to him, send him things, phone him and play cards with him. Neglect
him and he gets lonely, knocks on the inside of the screen, or gets sick and turns
green.

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
`RUN"*"` picks it up) and its data files: `LMP-BG` (the house), `LMP-TITLE` (the
guestbook), `LMP-GFX` (font and sprites), `LMP-PATCHES` (prop patches),
`LMP-SOUNDS` / `LMP-SOUNDS2` (sampled sounds), `LMP-TEXT` (the game's text),
`LMP-HI` (the program's `$C000` part) and the overlays `LMP-CARDS` and
`LMP-LETTERS`.

Playing
-------

Sign the **guestbook**: type your name, the time of day (`HHMM`) and `A`/`P` for
AM/PM, then RETURN. He arrives through the front door with his dog.

**Talk to him** by typing and pressing RETURN. Say *please* — he is far more
willing when you are polite, and in a good mood. Things to ask: *play the
piano, watch TV, read a book, eat, drink, dance, put on a record, exercise,
take a bath, brush your teeth, write a letter, play cards / poker, feed the dog,
pet the dog, play ball / fetch, walk the dog, light a fire, use the phone, play
solitaire, change clothes, go to bed, go out, invite Joey* (or *call a friend*),
and with Joey over, *play ping pong*. *Stop* makes him stop whatever he's doing
(*stop the record*, *stop vacuuming* for those). You can also just say *hello*,
*how are you* or *thank you*.

| Key      | Effect                                              |
|----------|-----------------------------------------------------|
| CTRL-F   | deliver groceries (food supply +3)                  |
| CTRL-W   | fill his water cooler bottle right up               |
| CTRL-D   | deliver dog food                                    |
| CTRL-B   | deliver a book (he shelves it, then reads it)       |
| CTRL-R   | deliver a record (he puts it on and dances)         |
| CTRL-C   | phone him (it rings till he gets to it)             |
| CTRL-A   | ring his alarm clock (wakes him — grumpily at night)|
| CTRL-T   | set the clock: type a time (`7am`, `9:30pm`, `21:15`) |
| + / -    | time twice as fast / half as fast (x2 .. x512), with nothing typed |
| F1       | help                                                |
| F5       | flat-out time (x512), or back to real time          |
| F7       | quit to BASIC                                       |

The top bar shows what he is saying or doing, and the time, food, water, dog
food and his mood — and the time speed, when it's sped up.

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

* **Needs:** hunger, thirst, energy, mood and health. He cooks three meals a
  day (or snacks from the fridge), drinks a glass of water at the cooler — two
  sips, then the glass to the sink (its level drops; a dry bottle makes him
  glum, and he'll ask you for more) — and sleeps at night (lights go down, pyjamas on):
  bed at 9pm, up at 7 — or 11pm and 8 at the weekend, when Friday and Saturday
  evenings often mean TV. He may take an afternoon nap when tired.
  Starve him or let the water run dry and his health falls — he turns green and
  spends more time in bed. Supplies only come from you.
* **Routines:** up in his pyjamas: the toilet (and every three hours after),
  breakfast, a shower, then dressed at the bedroom closet — a different colour
  shirt each day of the week — before the dog's morning walk; pyjamas again at
  bedtime. Some time before eleven he fetches the paper off the front step and
  reads the day's news out loud in the armchair. He brushes his teeth after
  meals, walks the dog three times a day, lights the fire in the evening,
  vacuums now and then, sometimes goes out.
* **The phone:** he rings people himself every few hours (now and then it's
  Joey, who comes over), and a few calls a day come in — the handset jumps on
  its cradle till he answers: Joey, his mom, telemarketers, wrong numbers.
* **Time:** the clock runs in real time, set from and paced by the MEGA65's
  real-time clock, and the day of the week follows the date; `+`/`-` speed it
  up (the people speed up too from x16) and CTRL-T sets it.
* **The house:** the clock drives the sky colour through the day; the fire,
  TV, computer monitor and water bottle are animated through their own palette
  entries; doors, drawers, cupboards, the fireplace, the phone's handset, the
  typewriter's carriage (it travels along each line, then the return and the
  bell's ding) and the attic desk cleared for ping pong swap in cell patches.
  Whatever he carries — groceries, a book, the paper, a glass — he holds out in
  front of him.
* **Stairs:** he climbs the front-facing step blocks in back view and walks the
  side-on flights sideways, feet on the treads.
* **The dog** trots around the house, follows him, naps, barks, begs at
  mealtimes and eats from its bowl when it's been fed. He pets it, plays fetch
  with it (the ball bounces and rolls, the dog races after it and brings it
  back), and whistles it down from upstairs for a game or a walk.
* **Joey,** his friend, drops by now and then (or when you ask him to invite
  him): Larry lets him in, they chat, play cards, dance to records, take turns
  at video games, watch TV and play ping pong at the attic desk; Joey helps
  himself to a snack or a drink and uses the bathroom, and lets himself out
  with a goodbye.

Architecture
------------

`src/main.asm` boots: it KERNAL-loads the data files while the machine is
still in its pristine BASIC65 state (stage at `$50000`, DMA up to Attic RAM),
then `sei`, 40 MHz, FCM screen, title, and the frame loop:

```
wait for raster 251 -> erase/draw actors -> palette animation -> top bar
-> sound -> keyboard -> simulation tick(s) -> build next frame's actors
```

| Folder / file | What it holds |
|---------------|---------------|
| `main.asm`, `platform.asm` | boot, frame loop, the file layout; registers, memory map, palette slots, key codes |
| `engine/` | the machine: `render` (DMA, FCM, palette and night dimming, sprite blitter, cell patches, text, far-text fetch), `ui` (speech/status bar, windows), `input` (keyboard, typed line, keyword parser), `sound` (SID tunes, sampled sounds) |
| `sim/` | Larry and the house: `activities` (one `#ACT` line per activity: where, facing, start/tick/end, status text), `sim` (state, clock, needs), `lights`, `brain` (`ai_choose`), `requests` (what you ask, gifts, CTRL keys), `person` (walking, stairs), `dog`, `fx`, `actors` (drawing) |
| `acts/` | the activities themselves, room by room: `core`, `kitchen`, `living`, `middle`, `chores`, `dogwalk`, `upstairs`, `attic`, `cards` |
| `friend/` | Joey, his visiting friend: `visit`, `talk`, `seat`, `jobs`, `door`, `draw`, `pingpong` |
| `overlays/` | run one at a time in the `$C000` window: `title` (the guestbook), `cards` + `poker`, `letters` |
| `gen/` | generated by `tools/build_assets.py`: palette, sprite/patch/sound addresses, SID note table |

**Memory:** program `$2001`-`$BFFF`; the overlay window `$C000`-`$CFFF` (RAM
once the character ROM is mapped out); FCM screen RAM `$16000`; sound play
buffer `$18000`; char data `$40000` (1000 unique cells x 64 bytes); `LMP-GFX`
stays at `$50000`. Attic holds the working house image (`$8000000`), a pristine
copy for undoing patches (`$8010000`), the title (`$8020000`), the sampled
sounds (`$8030000`-), the cell patches (`$8100000`), the game's text
(`$8110000`, fetched as needed) and the overlays (`$8120000`). Bank 1
`$10000`-`$11FFF` and `$1F700`-`$1F7FF` are the KERNAL/DOS's: never touched.

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
(activity numbers: the order of the `#ACT` lines in `sim/activities.asm`, from 0).
More `-D` options for test builds: `AUTOHOUR=<0-23>` (the start time),
`AUTODOGUP=1` / `2` (the dog starts on the middle floor / far end of the attic),
`AUTOPHONE=1` (the phone rings in a minute; `2`-`7` picks the caller),
`AUTOFRIEND=<n>` (Joey: `1` rings in a few seconds, `5` already in the attic with
a record on, `10` beside Larry and straight to ping pong, `11` about to go home,
`12` off for a drink), plus `AUTOFOOD`, `AUTOHUNGER`, `AUTOHEALTH`,
`AUTODOGFOOD`.

Credits
-------

*Little Computer People* © 1985 Activision, designed by David Crane and Rich Gold;
Amiga version 1987. This is an unofficial fan tribute for the
MEGA65. His voice on the phone is sampled from the Amiga original (a gameplay
recording on YouTube) and played through MEGA65 audio DMA; the toilet flush is
"Flushing the toilet" by gradha (public domain, Wikimedia Commons) and the
doorbell is "Sound Effect - Door Bell" (CC0, Wikimedia Commons); the dog's
bark is cut from "Barking of a dog" by Amada44 (CC BY-SA 3.0, Wikimedia
Commons), pitched up for a little dog; the alarm clock is cut from "Alarm
clock - 01" by Mathieu Kappler (CC BY-SA 4.0, Wikimedia Commons); his
dog-call whistle is synthesised for the game. Digital
sounds live in Attic RAM and are DMA'd into a chip-RAM buffer to play. Reference
screenshots of the Amiga version came from dazeland.com,
mastertronic.co.uk and habr.com; gameplay details from ST-News' review and the
C64 original. Code patterns (FCM setup, DMA, boot loading) follow the author's
mega-simcity and fcmlib projects.

Note: this is a 45GS02 target. `STZ` stores the Z register (not zero) on this
CPU; use `LDA #0 / STA`. Labels are case-insensitive in 64tass, and `_`-prefixed
labels are cheap locals — shared variables here use an `l_` prefix instead.
