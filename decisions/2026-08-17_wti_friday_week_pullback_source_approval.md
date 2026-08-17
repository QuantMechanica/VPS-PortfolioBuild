# WTI Exact-Week Pullback / Friday Bounce - Source Approval

Date: 2026-08-17

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if the tester and CPU
ceilings permit. This decision does not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch. The mission requires one genuinely new,
structural, low-frequency commodity edge outside the certified
XAU/SP500/NDX/XNG book, reputable-source criteria, `RISK_FIXED` backtests, and
no live or portfolio-gate mutation.

## Candidate Identity

- proposed slug: `wti-fri-weekfade`
- proposed strategy ID: `GORSKA-YANG-WTI-FRIWEEKFADE-2026_S01`
- source ID: `GORSKA-YANG-WTI-FRIWEEKFADE-2026`
- carrier: exact `XTIUSD.DWX`, D1, one position on magic slot 0
- decision clock: first executable tick of a genuine broker Friday
- price state: exact completed Monday-open through Thursday-close log return
- lifecycle: buy only after a strictly negative formation and flatten at the
  framework Friday hour-21 boundary

The deterministic registry process owns the EA ID. This record neither
reserves nor predicts an ID.

## Approved Source Basis

The bounded composite packet at
`strategy-seeds/sources/GORSKA-YANG-WTI-FRIWEEKFADE-2026/source.md` and both
governed parents were read completely before this decision:

1. Gorska and Krawiec (2015), "Calendar Effects in the Market of Crude Oil,"
   *Quantitative Methods in Economics* 16(4), through the complete repository
   extraction at `strategy-seeds/sources/GORSKA-WTI-CAL-2015/source.md`,
   supplies the positive WTI Friday direction.
2. Yang, Goncu, and Pantelous, "Momentum and Reversal in Commodity Futures,"
   SSRN 3069253, through the complete repository extraction at
   `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md`, supplies only
   the structural fixed-horizon commodity-reversal lineage.

Neither source tests the exact four-session/Friday conjunction, a one-session
Darwinex continuous-CFD trade, fixed risk, the ATR stop, or portfolio overlap.
No source performance or correlation result transfers.

## Locked Mechanic

On the first executable tick of each eligible broker Friday:

1. Repair malformed or stale owned exposure before entry-only gates.
2. Support only the governed native same-day or one uniform `+1` calendar-day
   energy D1 label convention.
3. Require current Friday and exact completed Thursday, Wednesday, Tuesday,
   and Monday sessions; never substitute a missing or earlier session.
4. Persist the Friday `yyyymmdd` attempt before every fallible gate and admit
   only the first observation within 180 minutes of the D1 session open.
5. Compute `ln(ThursdayClose / MondayOpen)` from completed bars only.
6. Buy WTI only when that value is strictly negative. Positive, exact-zero,
   invalid, late, or broken-calendar states consume Friday flat. Magnitude
   never changes size.
7. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, one frozen
   `3.0 * ATR(20,D1)` hard stop, a 1,500-point spread ceiling, and no target.
8. Close through framework Friday close at broker hour 21; use first-later-D1
   and three-calendar-day repairs only for stale exposure.
9. Never retry, scale in, pyramid, grid, martingale, hedge, or use external
   runtime data.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_AND_WORKING_PAPER_RISK`: named academic sources and
  complete governed extracts, with working-paper, translation, conjunction,
  multiple-testing, and decay risks explicit.
- R2 `PASS`: exact calendar, endpoints, strict sign, direction, attempt,
  grace, risk, stop, spread, and lifecycle are locked.
- R3 `PASS_WITH_SESSION_LABEL_RISK`: registered native `XTIUSD.DWX` D1 and MT5
  state supply every runtime field; label normalization remains falsifiable.
- R4 `PASS`: deterministic timestamp and return arithmetic only; no trained
  output, banned signal indicator, external feed, grid, martingale, scale-in,
  hedge, or pyramid.

## Non-Duplicate Decision

The canonical checker scanned 4,538 registry rows and 625 root card files. It
returned `CLEAN` with no exact or fuzzy identity. Manual family review fixes
the load-bearing boundaries:

- `QM5_12753` uses only a thresholded Thursday close-to-close decline; this
  candidate uses the unthresholded exact Monday-open through Thursday-close
  path, so the admitted Friday set is not nested in either direction;
- `QM5_20117` shorts a large Thursday surge;
- `QM5_12597` is unconditional Friday long;
- `QM5_20145` and `QM5_20172` use 252-D1 trend states;
- `QM5_41026` uses one first Friday and completed calendar-month endpoints;
- `QM5_41019` through `QM5_41022` form earlier/prior-week momentum and enter
  before Friday; and
- `QM5_12567` is a two-day XNG oscillator pullback.

Verdict:
`CLEAN_WTI_EXACT_MONDAY_THURSDAY_LOSS_FRIDAY_BOUNCE_AFTER_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately twenty to twenty-five completed positions
per full post-warm-up year before execution gates. Q02 retires on zero trades,
fewer than five positions per year, nonpositive governed economics, wrong
calendar identity or endpoints, current-Friday signal leakage, late/repeated
entry, wrong side, missing stop, wrong lifecycle, nondeterminism, or an
unusable energy-label convention. No weak result may be rescued by changing
the weekday, formation, sign, threshold, direction, stop, or hold.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. One target-only Q02 item may be
enqueued only below both governed capacity ceilings.

