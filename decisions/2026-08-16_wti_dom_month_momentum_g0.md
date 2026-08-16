# WTI Day-of-Month / Prior-Month Momentum - G0 Decision

Date: 2026-08-16

Decision: `APPROVED` for one bounded V5 Strategy Card, one branch-only
non-live build, strict Q01 validation, and one paced non-live Q02 enqueue.
This decision does not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch and durably recorded before extraction in
`decisions/2026-08-16_wti_dom_month_momentum_source_approval.md` at commit
`600106d4e`.

## Candidate

- EA: `QM5_41025_wti-dom-mom1`, allocated by the deterministic registry
  command at commit `5e1571bf1`
- slug: `wti-dom-mom1`
- strategy ID: `BOROWSKI-MOP-WTI-DOMMOM1-2026_S01`
- source ID: `BOROWSKI-MOP-WTI-DOMMOM1-2026`
- host/slot 0: `XTIUSD.DWX`, D1, planned magic `410250000`
- driver: Borowski's exact day-8 long/day-26 short WTI directions admitted
  only when the immediately completed calendar-month return agrees
- lifecycle: one D1 interval with fixed-dollar risk and a frozen ATR stop

## Source Decision

The approved packet is
`strategy-seeds/sources/BOROWSKI-MOP-WTI-DOMMOM1-2026/source.md`. Borowski
(2016), *Journal of Management and Financial Sciences* 26, supplies the
positive WTI day-8 and negative day-26 cells. Moskowitz, Ooi, and Pedersen
(2012), *Journal of Financial Economics* 104(2), supply instrument-own
completed-return-sign direction, the one-month commodity formation family,
and explicit WTI membership.

Neither source tests the exact conjunction. The normalized Darwinex date
mapping, immediately completed calendar-month endpoint convention,
180-minute entry boundary, one-D1 hold, continuous-CFD carrier, ATR stop,
spread ceiling, and fixed cash risk are QM translations. Borowski's multiple
testing and post-2016 decay are explicit. No source performance, cost, density,
CFD equivalence, decorrelation, or portfolio result transfers.

## Locked Rule

1. Admit a decision only on an `XTIUSD.DWX` D1 bar whose uniformly normalized
   energy label equals the broker date and is dated exactly day 8 or day 26.
   Missing dates do not shift.
2. Support only the governed native same-day label or one uniform `+1`
   calendar-day energy normalization. Require the first observed tick within
   180 minutes of the executable D1 session open.
3. Persist the exact normalized `yyyymmdd` attempt before history, signal,
   news, spread, quote, ATR, sizing, or order gates and never retry or backfill
   the date.
4. Reconstruct the newest completed D1 closes in the two normalized broker
   months immediately before the decision month. Require positive finite
   prices, strict timestamp order, and exact consecutive month keys. Current-
   month bars and the live bar enter neither endpoint.
5. Compute `log(PriorMonthEnd / PriorPriorMonthEnd)`. On exact day 8, BUY only
   when strictly positive. On exact day 26, SELL only when strictly negative.
   Exact zero, invalid history, or a disagreeing sign consumes the date flat;
   magnitude never scales risk.
6. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
   `2.75 * ATR(20,D1)` hard stop, no target, and a 2,500-point spread ceiling.
7. Close on the first following normalized D1 boundary, after five calendar
   days as a stale guard, or on malformed/duplicated exposure.
8. Keep both news axes OFF and framework Friday close enabled at broker hour
   21. The framework kill switch and broker hard stop remain authoritative.

The exact day pair, completed-calendar-month endpoints, agreement direction,
no-shift/no-late-entry/no-retry rules, fixed risk, hard stop, and one-D1
lifecycle are load-bearing. No parameter sweep is approved.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_AND_MULTIPLE_TESTING_RISK`: two named-author,
  peer-reviewed complete-read lineages, exact WTI table cells, JFE DOI and
  durable retrieval hash, explicit WTI membership, and disclosed untested
  conjunction/multiple-testing risk.
- R2 `PASS`: normalized date, endpoint months, return sign, direction, clock,
  attempt, risk, stop, spread, and exit are fixed.
- R3 `PASS`: registered native `XTIUSD.DWX` D1 history and its directly
  measured session offset supply every runtime input.
- R4 `PASS`: deterministic native arithmetic only, without trained output,
  banned signal indicator, external feed, grid, martingale, scale-in, or
  pyramid.

Both deterministic card linters returned `status: ok` for the canonical root
and approved copies. The copies are byte-identical. The exact hashes are
recorded by the extraction commit and can be reproduced with `Get-FileHash`.

## Non-Duplicate Decision

The canonical pre-card checker scanned 4,512 registry rows and 608 root cards,
found no exact match, and raised only `wti-dom-ctrreg` for manual review.
Manual review separates:

- `QM5_41017_wti-dom-ctrreg`: exact day 8/day 26, but opposing completed
  252-D1 state;
- `QM5_20215_wti-dom-trend`: day 1/day 26 with agreeing completed 252-D1
  state;
- `QM5_20036` and `QM5_20027`: unconditional exact-date source parents;
- `QM5_20187_wti-tsmom1m`: month-boundary entry and full-month lifecycle; and
- `QM5_12567_cum-rsi2-commodity`: two-day oscillator pullback across
  commodity carriers.

Verdict:
`CLEAN_WTI_DAY8_DAY26_PRIOR_MONTH_AGREEMENT_AFTER_FAMILY_REVIEW`.

## Allocation And Kill Boundary

The atomic `farmctl reserve-ea-ids` command allocated `QM5_41025`; the ID was
not inferred or hand-edited. Expected cadence is approximately eight to ten
positions per full post-warm-up year. Q02 must retire on zero trades, below
five/year, wrong or shifted dates, wrong month endpoints, current-bar leakage,
late/repeated entry, sign/direction mismatch, wrong lifecycle, invalid risk
mode, nondeterminism, or nonpositive governed economics. Q09 alone may
establish realized portfolio correlation.

## Safety Boundary

Create exactly one `XTIUSD.DWX` D1 backtest setfile with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. This decision excludes manual
backtests; live, demo, shadow, stress, and optimization setfiles; `T_Live`;
AutoTrading; deploy or T_Live manifests; portfolio-gate edits; portfolio
admission; and correlation waivers. Enqueue Q02 once, but do not dispatch or
control a tester when the factory resource ceiling is binding.
