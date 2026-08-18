---
source_id: CRABEL-CME-XAUXAG-WEEKNR7-2026
title: Gold/silver weekly NR7 close-ratio compression breakout
publisher: Traders Press / CME Group
source_type: governed_composite_lineage
status: cards_ready
approval_basis: OWNER commodity/energy portfolio mission 2026-08-18
created: 2026-08-18
created_by: Research+Development
parent_sources:
  - CRABEL-WTI-NR7-BRK-2026
  - CRABEL-WTI-WEEK-ORB-2026
  - CME-GSR-SPREAD-2025
strategy_ids:
  - CRABEL-CME-XAUXAG-WEEKNR7-2026_S01
---

# Gold/Silver Weekly NR7 Compression-Breakout Source Packet

## Approval And Complete-Read Scope

The OWNER mission dated 2026-08-18 directs one new structural, low-frequency
commodity card and explicitly permits a market-neutral `XAUUSD` / `XAGUSD`
basket. The following bounded governed packets were read completely for this
extraction:

1. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, which records CME
   Group's definition of the gold/silver ratio, its opposing-leg spread
   carrier, and the metals' overlapping but different monetary, safe-haven,
   and industrial drivers.
2. `strategy-seeds/sources/CRABEL-WTI-NR7-BRK-2026/source.md`, which records
   Toby Crabel's named 1990 Traders Press book and the NR7 volatility-
   contraction-to-range-expansion pattern.
3. `strategy-seeds/sources/CRABEL-WTI-WEEK-ORB-2026/source.md`, which records
   the governed low-frequency translation of Crabel-style range patterns to
   complete broker weeks and next-week breakouts.

The CME packet already supports a gold/silver ratio channel-continuation card.
The Crabel packets already support outright WTI daily and weekly breakouts.
None tests a weekly NR7 event on synchronized gold/silver close ratios, a
Darwinex CFD basket, equal-notional paired execution, or the V5 lifecycle
below. Their conjunction is an explicit QM hypothesis, not a transferred
performance claim.

## Findings Used

- CME defines gold divided by silver as an intermarket ratio and documents a
  spread carrier with two related metals whose economic drivers differ.
- Crabel's governed lineage treats the narrowest range among seven completed
  observations as a volatility-compression reference for a later breakout.
- The weekly governed lineage supports defining complete broker weeks before
  testing expansion in the next week.

No source return, profit factor, trade count, drawdown, hedge ratio, CFD basis,
market neutrality, or portfolio-correlation statistic transfers.

## Bounded Mechanization

`CRABEL-CME-XAUXAG-WEEKNR7-2026_S01` locks one D1 paired package:

- carrier: exact `XAUUSD.DWX` host and `XAGUSD.DWX` companion, D1, magic slots
  zero and one;
- ratio observation: synchronized completed D1 close ratio
  `r = ln(XAU_close) - ln(XAG_close)`;
- weekly sample: the most recent seven valid complete broker Monday-Friday
  weeks, each containing exactly one synchronized close for weekdays one
  through five; incomplete/holiday weeks may be skipped only among the six
  older comparison weeks;
- compression state: the immediately prior calendar week must itself be a
  valid complete week and its five-close ratio range must be strictly smaller
  than every one of the six older valid weekly ranges;
- decision clock: on the first executable D1 tick from Tuesday through Friday,
  use only the latest completed current-week close ratio;
- breakout: buy XAU and sell XAG above the prior compressed week's strict
  close-ratio maximum; sell XAU and buy XAG below its strict minimum; equality
  is flat;
- attempt: persist the current broker Monday week key before spread, quote,
  ATR, sizing, news, or order gates once a strict breakout is observed; never
  retry that week;
- package: target one-to-one absolute notional with at most 20 percent lot-step
  mismatch while keeping combined normalized hard-stop risk at or below one
  `RISK_FIXED=1000` budget;
- risk: frozen `3.0 * ATR(20,D1)` stop on each leg, no target, and 1,500-point
  spread ceiling per leg; and
- lifecycle: close both legs at broker Friday 21, on a later broker week, or
  after eight calendar days, with immediate orphan/malformed-package repair.

Both news axes are OFF, framework Friday close is ON, and the backtest contract
is `RISK_PERCENT=0`, `RISK_FIXED=1000`, `PORTFOLIO_WEIGHT=1`. There is no
parameter sweep.

## Non-Duplicate Boundary

The canonical pre-card checker scanned 4,547 EA-registry rows and 625 root
cards and returned `CLEAN` for slug `xauxag-week-nr7-brk`, strategy ID
`CRABEL-CME-XAUXAG-WEEKNR7-2026_S01`, and the declared mechanic. Manual family
review fixes the closest boundaries:

- `QM5_12724_cme-xauxag-brk` follows every 120-D1 ratio-channel break and
  exits on a 40-D1 opposite channel. It has no completed-week NR7 event,
  next-week-only window, or Friday-flat lifecycle.
- `QM5_20265_xauxag-fail-rv` fades a separate outside-then-inside 60-D1 ratio
  event. This candidate continues a strict break out of a compressed week.
- `QM5_20249_xauxag-vr-spread` computes a monthly robust variance-ratio
  statistic and persistence/reversal matrix. This candidate uses no return
  autocorrelation or significance statistic.
- `QM5_41040` and `QM5_41057` condition weekly ratio packages on overnight and
  session return flows and fade the completed week. This candidate ignores
  flow decomposition and follows next-week close expansion.
- `QM5_12533` supplies only the validated two-leg manifest/order recipe; its
  signal is an EURJPY/GBPJPY FX cointegration spread.

The exact carrier pair, completed-close ratio, complete-week grouping, strict
weekly NR7 state, next-week close break, continuation side, one weekly attempt,
equal-notional aggregate-risk package, and Friday-flat lifecycle are jointly
load-bearing. Verdict: `CLEAN_WEEKLY_RATIO_NR7_EXPANSION_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_PORT_RISK`: a named-author Traders Press trading
  book supplies the NR7/range-expansion lineage and CME Group supplies the
  traded ratio carrier; the cross-market conjunction is disclosed and
  untested.
- R2 `PASS`: weekly membership, sample size, strict range comparison, breakout
  boundary, direction, attempt, sizing, stops, spreads, and exit clock are
  fixed and deterministic.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: both registered DWX D1
  symbols provide every runtime observation; Q02 owns history alignment,
  execution, density, and CFD-basis falsification.
- R4 `PASS`: native timestamp, OHLC, logarithm, extrema, ATR risk plumbing,
  quote, position, deal, and terminal state only; no ML, banned signal,
  external runtime feed, adaptive fit, grid, martingale, scale-in, or pyramid.

## Kill And Safety Boundary

Expected cadence is approximately five to ten paired packages per full
post-warm-up year. Q02 must retire the unchanged identity on zero trades,
fewer than five completed packages per year, nonpositive governed economics,
wrong week membership, unsynchronized closes, a non-strict NR7 comparison,
wrong breakout side, repeated/late entry, malformed basket, invalid fixed-risk
mode, or nondeterminism. A weak result may not be rescued by changing the
seven-week sample, range definition, breakout clock, carrier, stop, or exit.

This packet authorizes no manual backtest, terminal control, live/demo/shadow/
stress/optimization preset, AutoTrading action, `T_Live` change, deploy or
T_Live manifest, portfolio-gate mutation, portfolio admission, decorrelation
claim, or correlation waiver.
