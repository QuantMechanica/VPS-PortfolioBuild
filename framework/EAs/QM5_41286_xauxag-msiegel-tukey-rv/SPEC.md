# QM5_41286_xauxag-msiegel-tukey-rv - Strategy Spec

**EA ID:** QM5_41286

**Slug:** `xauxag-msiegel-tukey-rv`

**Strategy ID:** `AI-CODEX-XAUXAG-MSIEGEL-TUKEY-RV-20260902_S01`

**Source:** `AI-CODEX-XAUXAG-MSIEGEL-TUKEY-RV-20260902`

**Author of this spec:** Codex

**Last revised:** 2026-09-02

## 1. Strategy Logic

At the first synchronized executable D1 boundary of a broker month, consume
the month and reconstruct the latest exactly timestamp-matched XAU/XAG close
pair in each of seventeen consecutive completed broker months. For
chronological endpoints compute `q[i]=ln(XAU[i])-ln(XAG[i])` and the sixteen
adjacent changes `r[i]=q[i+1]-q[i]`. Current-month prices never enter the
signal.

The first eight changes are the old block and the last eight are the recent
block. Reject any pooled pair tied under
`1e-12*max(1,abs(left),abs(right))`. Sort all sixteen changes ascending and
assign rank positions zero through fifteen the locked Siegel-Tukey scores
`1,4,5,8,9,12,13,16,15,14,11,10,7,6,3,2`. The observed statistic is the sum
of scores occupied by recent-block changes.

Enumerate all `C(16,8)=12,870` recent-label assignments. The inclusive exact
lower-tail count is the number with score less than or equal to the observed
score. Qualify only when observed score is at most 68 and the tail count is at
most 6,698; runtime verifies those two boundaries agree. If the recent
cumulative ratio move `q[16]-q[8]` is positive, sell XAU and buy XAG. If it is
negative, buy XAU and sell XAG. A zero move is flat. Statistic magnitude never
changes risk.

An accepted package closes on the first synchronized tick in a later broker
month or after forty elapsed calendar days. Both legs use frozen
`3.5*ATR(20,D1)` hard stops, no target, and no same-month retry.

## 2. Locked Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_xag_symbol` | XAGUSD.DWX | exact companion leg |
| `strategy_endpoint_count` | 17 | completed synchronized endpoints |
| `strategy_return_count` | 16 | adjacent log-ratio changes |
| `strategy_block_size` | 8 | fixed old and recent block size |
| `strategy_assignment_count` | 12870 | full recent-label space |
| `strategy_score_max` | 68 | inclusive recent score ceiling |
| `strategy_tail_count_max` | 6698 | inclusive exact lower-tail cap |
| `strategy_relative_epsilon` | 1e-12 | pooled tie tolerance |
| `strategy_history_bars_d1` | 1200 | bounded endpoint scan |
| `strategy_entry_window_minutes` | 180 | month-boundary grace |
| `strategy_max_endpoint_gap_days` | 10 | newest endpoint age cap |
| `strategy_atr_period_d1` | 20 | closed-D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | hard-stop distance |
| `strategy_notional_ratio` | 1.0 | target XAU/XAG absolute notional ratio |
| `strategy_max_notional_mismatch_fraction` | 0.20 | rounded mismatch ceiling |
| `strategy_max_hold_days` | 40 | stale repair ceiling |
| `strategy_xau_max_spread_points` | 1500 | XAU entry spread cap |
| `strategy_xag_max_spread_points` | 500 | XAG entry spread cap |
| `strategy_deviation_points` | 20 | order deviation cap |

There is one locked Q02 baseline and no optimization surface.

## 3. Symbol And Execution Contract

- `XAUUSD.DWX`, D1 is host/traded slot 0, magic `412860000`.
- `XAGUSD.DWX`, D1 is companion/traded slot 1, magic `412860001`.
- `QM5_41286_XAU_XAG_ST_RV_D1` is the logical Q02 symbol hosted on XAU.
- Tester currency is USD, deposit is 100,000, and Q02 window is
  `2018.07.02` through `2024.12.31`.
- The two physical-symbol presets are component validation artifacts only;
  they must not create standalone Q02 work items.

Both current D1 bars must share timestamp and broker day. Every monthly
attempt is persisted before history, signal, spread, quote, ATR, sizing,
margin, or submission gates, so failure can never produce an intramonth retry.

## 4. Risk And Basket Integrity

Q02 is locked to `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The aggregate stop-risk budget is split in half. Each
leg is risk-sized from its final normalized stop, then only reduced to align
absolute USD notionals. Aggregate normalized risk may not exceed one budget
and notional mismatch may not exceed 20 percent.

Open XAU first and XAG second. If either submission fails, or if the result is
not exactly one opposed XAU/XAG pair with the expected magics, sides, stops,
and notional relationship, flatten every owned leg immediately. Zero or two
owned positions are the only valid steady states.

Both news axes and the legacy news mode are OFF. Friday close is OFF because
the full broker-month hold is part of the approved card. The kill switch,
broker stops, weekend guard, and disconnect handling remain authoritative.

## 5. Expected Behaviour And Failure Rules

The pre-data strict-rank allocation density is 6,698 qualifying states out of
12,870, or about 6.245 qualifying states per twelve monthly attempts. This is
an activity prior, not a p-value, return estimate, or decorrelation result.
Q02 must retire zero packages or any full scored post-warm-up year below five
packages.

Fail closed on any tie, invalid/nonconsecutive endpoint, timestamp mismatch,
nonfinite value, invalid score path, enumeration mismatch, tail/score-boundary
inequivalence, neutral recent move, wrong input, unresolved magic, bad
quote/metadata, excessive spread, invalid stop/volume/margin, orphan leg,
aggregate-risk overrun, notional mismatch, or lifecycle deviation.

## 6. Source And Non-Duplicate Boundary

The source of record is
`strategy-seeds/sources/AI-CODEX-XAUXAG-MSIEGEL-TUKEY-RV-20260902/source.md`;
source approval and G0 are recorded in the two 2026-09-02 decisions named by
the approved Strategy Card. External sources support only the gold/silver
carrier and classic scale-test score construction. The monthly blocks, exact
label tail, threshold, contrarian mapping, CFD execution, risk, and lifecycle
are governed QM synthesis.

This mechanic is not the twelve-observation Van der Waerden location score,
the twelve-observation Savage tail score, the thirteen-observation
Jonckheere-Terpstra ordering score, or the incumbent cumulative RSI2 logic.
Frozen fixtures in `docs/test_xauxag_msiegel_tukey_rv_reference.py` prove a
candidate-only state and a neighbor-only state.

The opposed equal-notional form is market-neutral-style, not a neutrality or
correlation claim. Q09 alone may establish realized portfolio overlap.

## 7. Framework Alignment

- `no_trade`: exact identity/host/period/inputs, persistent month consumption,
  synchronized history, strict ties, exact enumeration, and package state.
- `trade_entry`: direction, quotes/spreads, ATR stops, fixed-risk sizing,
  equal-notional reduction, and atomic two-leg submission/repair.
- `trade_management`: malformed-package repair, next-month exit, and 40-day
  stale exit.
- `trade_close`: V5 close helper, hard stops, and kill switch.

No live/demo/shadow/stress preset, deployment manifest, terminal control,
portfolio admission, or correlation waiver is authorized by this build.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-02 | Initial build from approved card | Governed magics `412860000` and `412860001` |
