# WTI Month-Boundary Dual-Horizon Momentum - G0 Decision

Date: 2026-08-16

Decision: `APPROVED` for one bounded V5 Strategy Card, one branch-only
non-live build, strict Q01 validation, and one paced non-live Q02 enqueue.
This decision does not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch and durably recorded before extraction in
`decisions/2026-08-16_wti_month_dual_momentum_source_approval.md` at commit
`c147775f2`.

## Candidate

- EA: `QM5_41021_wti-mdual-mom`, allocated by the deterministic registry
  command after source approval and semantic dedup review
- slug: `wti-mdual-mom`
- strategy ID: `MOP-WTI-MDUAL-MOM-2026_S01`
- source ID: `MOP-WTI-MDUAL-MOM-2026`
- host/slot 0: `XTIUSD.DWX`, D1, planned magic `410210000`
- driver: strict sign agreement between the immediately completed broker-
  month return and its final five completed close-to-close intervals
- lifecycle: first-new-month entry and first-tick-of-sixth-current-month-bar
  exit

## Source Decision

The approved packet is
`strategy-seeds/sources/MOP-WTI-MDUAL-MOM-2026/source.md`. Moskowitz, Ooi,
and Pedersen (2012) supply the own-return-sign continuation family and WTI's
membership in their commodity-futures universe. They do not test this nested
agreement state or executable CFD package.

The one-month and final-five endpoints, strict agreement-flat state, exact
month-boundary clock, energy-label normalization, five-minute restart
boundary, five-session exit, CFD mapping, ATR stop, and fixed-dollar risk are
QM translation choices. No source return, coefficient, significance, cost,
density, CFD equivalence, decorrelation, or portfolio result transfers.

## Locked Rule

1. Admit a decision only on the first `XTIUSD.DWX` D1 bar of a new broker
   month and within five minutes of its executable open. Normalize only the
   governed prior-date energy label by one uniform +1 calendar day; apply no
   other shift.
2. Persist the exact broker `yyyymm` attempt before history, signal, news,
   spread, quote, ATR, sizing, or order gates and never retry the month.
3. Reconstruct consecutive immediately prior and prior-prior broker-month-end
   closes and compute
   `log(prior_month_end / prior_prior_month_end)`.
4. Require the six newest completed D1 bars to belong to the prior broker
   month and compute
   `log(prior_month_end / prior_month_close_6)` across its final five
   close-to-close intervals. The current bar enters neither return.
5. BUY only when both returns are strictly positive and SELL only when both
   are strictly negative. Exact zero, invalid history, or disagreement
   consumes the month flat. Signal magnitude never scales risk.
6. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
   `3.5 * ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.
7. Close at the first tick of the sixth D1 bar in the entry month, on a
   premature month change, after twelve calendar days, or on malformed
   exposure.
8. Keep Friday close and both news axes OFF for the fixed five-session hold.
   The framework kill switch and broker hard stop remain authoritative.

The two completed-return endpoint sets, strict same-sign agreement, exact
entry clock, no-late-entry and no-retry rules, fixed risk, stop, spread, and
five-session lifecycle are load-bearing.

## Reputable-Source Criteria

- R1 `PASS_WITH_HORIZON_TRANSLATION_RISK`: peer-reviewed JFE paper, DOI,
  complete-paper evidence, durable retrieval hash, explicit WTI membership,
  and disclosed untested short-segment agreement translation.
- R2 `PASS`: endpoints, month membership, agreement, clock, attempt, risk,
  stop, spread, and exit are fixed.
- R3 `PASS`: registered native `XTIUSD.DWX` D1 history supplies every runtime
  input.
- R4 `PASS`: deterministic native arithmetic only, without trained output,
  banned signal indicator, external feed, grid, martingale, scale-in, or
  pyramid.

Both deterministic card linters returned `status: ok` for both canonical card
copies before this decision was written. The copies had identical SHA-256
`C38A494B510218DE03EFAD6109217E088DFE415817F9C3B8D8BF9A0598999F88`.

## Non-Duplicate Decision

The canonical pre-card checker scanned 4,508 registry rows and 604 root cards
and returned `CLEAN`, with no exact or fuzzy match. Manual review separates:

- `QM5_41016_wti-mclose-mom`, which follows the final-five sign alone;
- `QM5_20187_wti-tsmom1m`, which follows the completed-month sign alone and
  owns the full next month;
- `QM5_20056_wti-dual-mom` and `QM5_12711`, which compare medium/long monthly
  horizons and hold monthly packages;
- `QM5_20244_wti-trend-sign`, which uses twelve-month return/sign breadth;
- `QM5_13049_xti-1w-mom-vol`, which uses a rolling five-day magnitude and
  volatility-rank gate; and
- `QM5_41013_wti-mopen-mom`, which forms inside the new month and enters only
  when this candidate is already due to flatten.

Verdict:
`CLEAN_WTI_MONTH_AND_CLOSING_SEGMENT_AGREEMENT_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Allocation And Kill Boundary

The atomic `farmctl reserve-ea-ids` command allocated `QM5_41021`; no ID was
inferred or hand-edited. Expected cadence is approximately six to ten
positions per full post-warm-up year. Q02 must retire on zero trades, below
five/year, wrong month or endpoint reconstruction, current-bar leakage, late
or repeated entry, disagreement-side entry, wrong hold length, invalid risk
mode, nondeterminism, or nonpositive governed economics. Q09 alone may
establish realized portfolio correlation.

## Safety Boundary

Create exactly one `XTIUSD.DWX` D1 backtest setfile with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. This decision excludes manual
backtests; live, demo, shadow, stress, and optimization setfiles; `T_Live`;
AutoTrading; deploy or T_Live manifests; portfolio-gate edits; portfolio
admission; and correlation waivers. Enqueue Q02 once, but do not dispatch or
control a tester when the factory resource ceiling is binding.
