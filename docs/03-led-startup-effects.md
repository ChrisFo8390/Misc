# LED Startup Effects — Chamber, Toolheads & AFC Lanes

This guide covers the printer-wide LED "welcome" sequence that plays once at
startup, across three independently-wired LED groups:

- **Chamber** — 18-pixel strip, wired locally to the main board (`PB10`, no CAN bus involved)
- **Toolhead "logo" + "neb" LEDs** — 2 separate neopixel chains per toolhead (3 + 2 pixels), one pair per CAN toolboard (`EBB0`–`EBB4`)
- **AFC lane indicator** — 5-pixel strip on the EMU/MMU unit, wired to the Fly D5 board's `PA9` pin

All files referenced here live in [`config/`](../config/) (root-level printer
config) and [`config/AFC/`](../config/AFC/) in this repository.

## Table of contents

1. [Hardware overview](#1-hardware-overview)
2. [Startup wiring — which macro runs when](#2-startup-wiring--which-macro-runs-when)
3. [The chamber + toolhead sequence (`PRINTER_LED_WELCOME`)](#3-the-chamber--toolhead-sequence-printer_led_welcome)
4. [The AFC lane sequence (`AFC_LED_WELCOME`)](#4-the-afc-lane-sequence-afc_led_welcome)
5. [Manual toolhead testing without AFC's load hook](#5-manual-toolhead-testing-without-afcs-load-hook)
6. [Troubleshooting reference](#6-troubleshooting-reference)

---

## 1. Hardware overview

| Group | Pixels | Pin / bus | Config section |
|---|---|---|---|
| Chamber | 18 | `PB10` (main board, no CAN) | `[neopixel _Chamber]` in [`config/leds.cfg`](../config/leds.cfg) |
| Toolhead "logo" (×5) | 3 each | `EBBn:PD3` (CAN) | `[neopixel _logo_ledN]` in `config/leds.cfg` |
| Toolhead "neb" (×5) | 2 each | `EBBn:PB3` (CAN) | `[neopixel _neb_ledN]` in `config/leds.cfg` |
| AFC lane indicator | 5 | `fly:PA9` (Fly D5 board) | `[AFC_led AFC_Indicator]` in [`config/AFC/AFC_EMU.cfg`](../config/AFC/AFC_EMU.cfg) |

**Critical distinction that caused a real crash during development:** the
toolhead logo/neb LEDs sit on the same CAN bus as each toolboard's TMC UART
and ADC traffic. The chamber and AFC lane LEDs do not share a bus with
anything else. This directly shapes how the animations below are written —
see section 6.

**Also critical:** the AFC lane strip must be declared as `[AFC_led <name>]`,
not `[neopixel <name>]` — AFC's `led_index` option (used per-lane in
`AFC_EMU.cfg`) only resolves against an `AFC_led`-type object. Using
`[neopixel AFC_Indicator]` here causes a Klipper shutdown at startup with
`Cannot find [AFC_led AFC_Indicator] in config`.

Each toolhead's logo strip has 3 pixels, but only **index 2 and 3** are ever
managed by the pre-existing `_TOOLHEAD_LED` macro (sets them to static
white). **Index 1** is a separate, independently-colored pixel per toolhead
(its resting color comes from that strip's own `initial_RED/GREEN/BLUE/WHITE`
config values) — the welcome sequence below deliberately drives all three
logo pixels together, then hands indices 2+3 back to `_TOOLHEAD_LED` at the
end while restoring index 1 to its own configured color.

## 2. Startup wiring — which macro runs when

Two independent `delayed_gcode` blocks fire at boot, calling the two welcome
macros in sequence, plus the pre-existing toolchanger initialization:

```ini
# config/macros.cfg
[delayed_gcode start]
initial_duration: 2.0
gcode:
  PRINTER_LED_WELCOME
  INITIALIZE_TOOLCHANGER
  MR_NOTIFY TITLE="$printer_name" MESSAGE="Ready!"
```

```ini
# config/AFC/AFC.cfg
[delayed_gcode afc_welcome]
initial_duration: 2
gcode:
    AFC_LED_WELCOME
    PREP
```

`PRINTER_LED_WELCOME` (chamber + toolheads) and `AFC_LED_WELCOME` (lane
strip) are completely independent — neither touches the other's LEDs.

> **Do not duplicate this hook.** An earlier iteration accidentally had
> *two* separate startup hooks both driving the chamber/toolhead LEDs (one
> pre-existing in `macros.cfg`, one newly added in `AFC.cfg`) — they fired
> a fraction of a second apart and fought over the same LEDs, leaving the
> chamber stuck off. Fixed by consolidating into the single `start` hook
> shown above.

## 3. The chamber + toolhead sequence (`PRINTER_LED_WELCOME`)

Defined in [`config/leds.cfg`](../config/leds.cfg). Current design, in order:

1. **Everything off** — chamber and all 5 toolheads (all 3 logo pixels + both neb pixels each).
2. **T0 → T4, one at a time:** each toolhead fades directly from off into its
   static accent color (logo pixels 1/2/3 + neb together, 4 brightness
   steps over ~400ms) — the chamber fades to the *same* color at the *same
   time*, so the chamber visibly "follows" whichever toolhead is currently
   lighting up.
3. **0.5s pause**, then **everything off again** — a deliberate blackout
   right before the flash, to make the flash read as a distinct beat rather
   than blending into the last color.
4. **Single bright white flash** across chamber + all toolheads together.
5. **Restore:** logo index 1 and both neb pixels go back to their accent
   color (the flash had overwritten them to white); chamber settles to
   static white at 50% brightness; `_TOOLHEAD_LED` (pre-existing macro,
   unchanged) takes over logo indices 2+3 → static white.

Accent colors per toolhead (also reused for the lane strip, section 4):

| Toolhead | Color | RGB |
|---|---|---|
| T0 | Orange | `1.0, 0.65, 0.0` |
| T1 | Purple | `0.8, 0.0, 1.0` |
| T2 | Blue | `0.0, 0.0, 1.0` |
| T3 | White | `1.0, 1.0, 1.0` |
| T4 | Red | `1.0, 0.0, 0.0` |

**CAN bus safety rules baked into this macro** (see section 6 for why):

- Never more than **one** toolhead's CAN board is driven per animation step.
- Every multi-pixel update to a single `[neopixel ...]` object uses
  `TRANSMIT=0` on all but the last pixel, so each object only causes **one**
  physical transmission per update instead of one per pixel.

## 4. The AFC lane sequence (`AFC_LED_WELCOME`)

Defined in [`config/AFC/AFC_EMU.cfg`](../config/AFC/AFC_EMU.cfg). Kept
deliberately simple and visually consistent with section 3 — same "left to
right" motion as a plain build-up chase, but using the *same 5 accent
colors* as the matching toolheads (Lane 1 = T0's orange, Lane 2 = T1's
purple, etc.) instead of an independent rainbow palette:

1. Chase build-up, Lane 1 (pixel 1) → Lane 5 (pixel 5), each lighting up in
   its matching toolhead's accent color.
2. Fade to black together, in 4 steps.

Once this macro finishes, `PREP` runs immediately after (same
`delayed_gcode`), and AFC's own `led_ready` / `led_not_ready` state coloring
(configured in `AFC.cfg`, see the main AFC guide) takes over from there.

> An earlier version used a 12-color rainbow palette with a spinning
> "color-wheel" phase across all 5 lanes. It looked fine on its own, but no
> longer matched the toolhead/chamber sequence's fixed 5-color identity once
> that was added — replaced with the shared accent-color approach above for
> visual consistency across the whole machine.

## 5. Manual toolhead testing without AFC's load hook

For testing a toolhead's mechanics without triggering AFC's automatic
filament load, see [`config/TC_SELECT_TOOL.cfg`](../config/TC_SELECT_TOOL.cfg) —
a small macro wrapping klipper-toolchanger's native `SELECT_TOOL T=<n>`
command. Usage: `TC_SELECT_TOOL T=0`. See the comments in that file and the
troubleshooting table below for why this needed its own macro rather than
just calling `SELECT_TOOL` directly, and why enabling AFC's "Virtual Bypass"
doesn't work for this (it blocks the whole toolchange, not just the load
step).

## 6. Troubleshooting reference

| Symptom | Cause | Fix |
|---|---|---|
| `Cannot find [AFC_led AFC_Indicator] in config, make sure led_index in config is correct` → Klipper shutdown | Lane LED strip declared as `[neopixel AFC_Indicator]` instead of `[AFC_led AFC_Indicator]` | Use `[AFC_led <name>]` for any strip referenced by a lane's `led_index` |
| `klippy.serialhdl.error: Unable to obtain 'neopixel_result' response` → full Klipper shutdown, Moonraker disconnects | A welcome-effect animation re-colored all 5 toolheads' CAN-connected LEDs on every frame of a multi-step loop (e.g. a spinning rainbow), overloading the shared CAN bus alongside normal TMC/ADC traffic | Never touch more than one toolhead's CAN board per animation step; buffer multi-pixel updates to a single `[neopixel]` object with `TRANSMIT=0`/`TRANSMIT=1` instead of transmitting every pixel individually; keep any *rich, high-frame-rate* effect (e.g. a spinning color cycle) on the chamber strip only, since it isn't on the CAN bus |
| Enabling "Virtual Bypass" also stops the toolchanger from physically picking up a tool | AFC's bypass disables the whole toolchange path when a lane's filament is loaded in bypass, not just the load step | Use `TC_SELECT_TOOL T=<n>` (native `SELECT_TOOL`) instead of bypass, to pick up a toolhead without AFC's load hook |
| `SELECT_TOOL TOOL=0` → `configparser.Error: Unknown config object '0'` → Klipper shutdown | Wrong parameter name/format — klipper-toolchanger's own generated `T0`–`T4` macros use `SELECT_TOOL T=<n>`, not `TOOL=<n>` | Always use `T=<n>`, confirmed directly from klippy.log's own `SELECT_TOOL T=0` calls |
| Chamber LED stays off after startup even though it briefly lit up | Two separate startup hooks (old `[delayed_gcode start]` and a newly-added one) both drove the chamber LED a fraction of a second apart, overwriting each other | Consolidate into a single startup hook (section 2) |
