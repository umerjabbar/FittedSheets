# Testing the changes

Run the **FittedSheetsDemos** app. Most fixes harden existing behavior and are exercised by the
existing demos; the new/changed user-facing behaviors have dedicated demos (in the **Modal Sheet
Demos** list). The console prints `Changed to <size> with a height of <h>`, `should dismiss`, and
`did dismiss` for every sheet (via `addSheetEventLogging`), so watch Xcode's console while testing.

## New demos (Modal Sheet Demos list)

| Demo | Tests | What to look for |
|---|---|---|
| **Pass-through overlay (window)** | #41 window-attach `presentOverWindow` | Tap the buttons showing through the dimmed area — they still respond; the sheet stays interactive. |
| **Liquid Glass background (iOS 26+)** | opt-in `useLiquidGlassBackground` | On iOS 26+ the background is a glass material (UIBlurEffect below). |
| **Status bar style forwarding (#25)** | `modalPresentationCapturesStatusBarAppearance` | Status bar text turns **white** while the sheet is up (child returns `.lightContent`). |
| **panGestureShouldBegin blocks drag (#6)** | closure consulted without a child scroll view | The sheet **can't be dragged**; console logs "panGestureShouldBegin consulted". Tap outside to dismiss. |
| **Nav delegate preserved (#14)** | forwarding proxy | Console logs **"APP nav delegate: didShow …"** — your own nav delegate keeps firing; pushing resizes the sheet. |

## Changes covered by existing demos / actions

| Change | How to test |
|---|---|
| **iOS 15 min + modernization** (deprecated windows/keyWindow, iOS 13 guards, Compatible shim) | The app builds & runs with zero library warnings; behavior unchanged. |
| **viewIsAppearing sizing (correct heights)** | Any `.percent`/`.intrinsic` demo — console `Changed to … height` shows real values (no `0.0`) on first present. |
| **Rotation recompute (#3)** | Open any sheet, **rotate the simulator** (⌘←/⌘→) — the sheet re-sizes and stays on screen. |
| **Keyboard avoidance (#4/#8/#13/#26)** | **Keyboard** demo — focus the field; the sheet lifts and the curve matches the keyboard. |
| **Nearest-detent snap + hysteresis (#28)** | **Resizing** / **Max Min Height** (multi-detent) — a tiny drag settles back; a flick moves one detent. |
| **Interruptible snap (#27)** | Any multi-detent sheet — flick to a detent, then **grab again mid-animation**; it continues smoothly, no jump. |
| **shouldDismiss once (#5)** | **Only close with button** — pull to dismiss; `should dismiss` logs once, sheet doesn't strand. |
| **Scroll arbitration / adjustedContentInset (#7)** | **ScrollView** / **Scroll in navigation** — scroll to top then keep dragging to move the sheet. |
| **Nav intrinsic height (#16)** | **Navigation** / **Intrinsic in navigation** — sheet fits the pushed content width-correctly. |
| **Rubber band + NaN guard (#29/#40)** | **Rubber Band** — pull past max; bounces without glitches. |
| **Dark-mode grip + colors (#49/#53)** | **Color** demo in **dark mode** (Appearance) — grip stays visible; colors adapt. |
| **Corner curve (#…)** | **Corner Curve** demo. |
| **Max width side-gutter pass-through (#41)** | **Max Width** — with `allowGestureThroughOverlay`, the dimmed side gutters also pass touches through. |

## Notes

- Edge-case robustness fixes (negative-height clamp #21, division-by-zero guards, `isWindowAttached`
  reset, `sizeChanged`-on-interrupt) have no "normal" visible behavior — they prevent crashes/glitches
  in the scenarios above rather than adding UI.
- VoiceOver items (#12/#52 escape + modal isolation) require enabling VoiceOver to test.
