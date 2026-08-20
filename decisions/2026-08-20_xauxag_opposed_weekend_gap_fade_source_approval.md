# XAU/XAG Opposed Weekend-Gap Fade - Source Approval

Date: 2026-08-20

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if tester and host-CPU
ceilings permit. This decision does not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch on 2026-08-20. The mission explicitly allows a
market-neutral `XAUUSD` / `XAGUSD` gold/silver-ratio basket, requires a new
non-duplicate structural low-frequency edge with reputable sources and
`RISK_FIXED` backtests, and forbids live and portfolio-gate mutation.

## Candidate Identity

- proposed slug: `xauxag-wgap-fade`
- proposed strategy ID:
  `BOROWSKI-SCHWEIKERT-XAUXAG-WGAPFADE-2026_S01`
- proposed source ID: `BOROWSKI-SCHWEIKERT-XAUXAG-WGAPFADE-2026`
- carrier: exact `XAUUSD.DWX` / `XAGUSD.DWX` D1 paired basket
- state: current synchronized Monday opens relative to immediately prior
  synchronized Friday closes have strictly opposite signed log gaps
- direction: fade both component gaps with an equal-notional ratio package
- lifecycle: one attempt per genuine broker Monday, first-later-D1 flat

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The bounded governed packets below were read completely before this approval:

1. `strategy-seeds/sources/BOROWSKI-LUKASIK-METALS-2017/source.md`, carrying a
   complete-paper review of the precious-metals Friday-close-to-Monday-open
   observation and different gold/silver weekend behavior.
2. `strategy-seeds/sources/LUCEY-TULLY-DOW-2006/source.md`, carrying a complete
   author-copy review of gold and silver Monday behavior and the binding weak,
   non-robust futures evidence.
3. `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`, carrying
   named peer-reviewed evidence for a state-dependent gold/silver long-run
   relationship.
4. The joined bounded lineage at
   `strategy-seeds/sources/BOROWSKI-SCHWEIKERT-XAUXAG-WGAPFADE-2026/source.md`,
   which locks the exact translation and adverse boundaries.

No source tests the opposed-gap fade on synchronized Darwinex CFDs. The
conjunction, two-sided mapping, equal-notional sizing, hard stops, and V5
lifecycle are disclosed QM choices. No efficacy, density, neutrality,
CFD-equivalence, or decorrelation result transfers.

## Locked Mechanic

1. Repair orphan, duplicate, same-side, wrong-symbol, wrong-magic, stopless,
   notional-invalid, or stale owned exposure before entry-only gates.
2. Require exact `XAUUSD.DWX` D1 host, `XAGUSD.DWX` companion, matching current
   and prior D1 timestamps, and locked backtest/news/Friday inputs.
3. On the first executable tick of a genuine broker Monday, no later than 180
   minutes after the synchronized D1 open, require the immediately prior
   completed synchronized D1 bars to be the preceding broker Friday.
4. Compute only
   `g_xau=ln(XAU_monday_open/XAU_friday_close)` and
   `g_xag=ln(XAG_monday_open/XAG_friday_close)`. Require positive finite
   prices, finite non-zero gaps, and strict sign opposition.
5. SELL XAU/BUY XAG when `g_xau>0` and `g_xag<0`; BUY XAU/SELL XAG when
   `g_xau<0` and `g_xag>0`. Equality, zero, same-sign gaps, missing Friday, or
   timestamp disagreement remains flat.
6. Once strict opposition exists, persist the broker-Monday date before
   spread, quote, ATR, sizing, news, or order gates. A rejected or failed
   attempt may not retry that Monday.
7. Target one-to-one absolute entry notional with at most 20 percent lot-step
   mismatch. Constrain combined broker-normalized stop risk to one
   `RISK_FIXED=1000` package; signal magnitude never scales risk.
8. Attach one frozen `3.0 * ATR(20,D1)` stop per leg, no target, and require
   XAU/XAG spreads at or below 1,500/500 points respectively.
9. Keep both news axes OFF and framework Friday close enabled at broker 21.
   Close the package at the first synchronized later D1 boundary or after four
   calendar days. Never retry, trail, partially close, scale in, grid,
   martingale, or pyramid.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: named peer-reviewed calendar and
  gold/silver relationship lineages support the clock and carrier, with the
  untested contrarian conjunction disclosed.
- R2 `PASS`: endpoints, strict opposition, side, attempt, aggregate risk,
  spread, and lifecycle are locked.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered native XAU and
  XAG D1 histories supply all runtime data; Q02 owns alignment and basis risk.
- R4 `PASS`: deterministic native arithmetic and V5 state only; no banned
  indicator, ML, external runtime data, adaptive fit, grid, martingale,
  scale-in, or pyramid.

## Non-Duplicate Decision

The canonical checker scanned 4,549 registry rows and 625 root cards and
returned `CLEAN`. Manual review distinguishes the fixed-direction weekend
package `QM5_20019`, unconditional Monday package `QM5_20095`, rolling ratio/
residual/tail systems `QM5_20157`, `QM5_20161`, `QM5_20263`, and `QM5_20268`,
five-session run exhaustion `QM5_20275`, and weekly/monthly flow systems
`QM5_41030`, `QM5_41039`, `QM5_41040`, and `QM5_41057`. None observes exactly
one synchronized Friday-to-Monday event, requires the two component gaps to
oppose, fades either direction, and exits at the next D1 boundary.

Verdict:
`CLEAN_XAUXAG_OPPOSED_WEEKEND_GAP_ONE_SESSION_FADE_AFTER_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is five to twenty completed packages per full post-warm-up
year. Q02 must retire below five per year, at zero trades or nonpositive
governed economics, or on any weekday, synchronization, strict-opposition,
direction, attempt, basket, risk, lifecycle, or determinism defect.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
after fresh exact-path tester and host-CPU checks are below their ceilings. At
the ceiling, stop before queue mutation and record a non-live handoff.
