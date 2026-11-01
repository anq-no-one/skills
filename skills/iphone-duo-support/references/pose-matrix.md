# Device Hub pose matrix

Run this on the **iPhone Duo** simulator in Device Hub (Xcode 27.1). Controls open, close, fold, and rotate the phone. Canvas Previews: **Display** group for the alternative display.

First Simulator launch can take several minutes (27.1 notes). StandBy and most app extensions are unavailable in this runtime.

## Must-run poses (every touched screen)

| # | Pose | What you are proving |
|---|---|---|
| 1 | Closed, outer display | Compact-width layout, vertical system bars, outer camera occlusion, no hinge division |
| 2 | Open, inner portrait | Regular × regular, horizontal bars, full inner canvas, fold inactive |
| 3 | Open, inner landscape | Vertical bars on the side, content still reachable opposite the bar |
| 4 | Partially folded (book / tabletop) | Division region active; controls and text not sitting in the fold |
| 5 | Rotate in **each** of 1–4 | Scene geometry changes; no stuck chrome from the previous pose |
| 6 | Inner Split View ~50/50 | Mandatory multitasking; asymmetric safe area; bars on the outer edge of *this* app |
| 7 | Sheets, popovers, pause overlay | System moves them off the fold; custom sheets follow `presentationPlacement` |
| 8 | Walk the main flow end to end, opening and closing the phone on the way | State and hierarchy survive display changes (HIG: same functionality in every pose) |

Skip 6 only when Device Hub cannot split yet — say so in the PR.

## Camera extras (hardware)

Simulator has no camera. On a Duo device:

| # | Case | What you are proving |
|---|---|---|
| 9 | QR scanner on outer vs inner | Preview + decode still work; occlusion when inner camera wakes |
| 10 | Front still capture | Virtual front camera handoff closed ↔ open |
| 11 | Live preview from the front camera | Direction flip; chrome not covering the fold |
| 12 | Rear capture + optional outer accessory | Accessory appears only while capture is live and the phone is open; vanishes on fold |

## Pass / fail

Fail the pose if any of these is true:

- Primary control (close, pause, next, tab) is under the fold, under a vertical bar, or under an occlusion.
- Layout is letterboxed / pillarboxed on a display that should be filled (games/video: prefer aspect change; if you must pad, fill the pad).
- A toolbar action that exists on a slab iPhone is gone with no overflow menu entry.
- Opening or closing the phone resets navigation or in-progress state.
- Fullscreen video controls collide with vertical bars and you did not opt that screen out.

Screenshot the failing pose. Fix against size class / reserved regions, then re-run the whole matrix for that surface — pose bugs cluster.
