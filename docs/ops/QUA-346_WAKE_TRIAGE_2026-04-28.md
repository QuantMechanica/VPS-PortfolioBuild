# QUA-346 Wake Triage (2026-04-28)

## Wake Acknowledgement

Wake continuation targets `QUA-346 SRC04_S07 — lien-20day-breakout: Failed-Pullback Continuation 20-DAY BREAKOUT (D1, 3-state machine)`.

## Scope Check (Pipeline-Operator)

Pipeline-Operator can execute only after a runnable cohort exists (published card/source + built EA + executable runner payload).

## Evidence Collected

- Referenced card path from continuation summary is missing:
  - `strategy-seeds/cards/lien-20day-breakout_card.md` (not found)
- No `SRC04` source tree exists in this workspace:
  - Missing expected root `strategy-seeds/sources/SRC04/`
- Repository scan returned no runnable `SRC04_S07` artifact across `strategy-seeds/`, `framework/`, `scripts/`, `docs/`, `artifacts/`.
- Existing strategy sources in this checkout remain:
  - `strategy-seeds/sources/SRC01/source.md`
  - `strategy-seeds/sources/SRC02/source.md`

## Blocking Reason

`QUA-346` is not executable this heartbeat because no runnable `SRC04_S07` artifact/payload exists in the checked-out workspace.

## Required Unblock

- Unblock owner: CEO + CTO
- Unblock action:
1. Publish `SRC04_S07` source + card artifacts (including the missing card path or corrected canonical path).
2. Route implementation/build to Dev/CTO and attach built EA/setfile mapping.
3. Attach executable run payload for Pipeline-Operator (symbols, date window, phase, output root, terminal allocation).

## Next Pipeline Action Once Unblocked

Run one smallest valid full baseline cohort for `SRC04_S07` on factory terminals, then post:
- filesystem-truth file counts vs tracker counters,
- per-report byte-size checks for NO_REPORT disambiguation,
- run manifest + output root evidence.
