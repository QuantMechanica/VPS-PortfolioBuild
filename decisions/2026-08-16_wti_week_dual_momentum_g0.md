# WTI Split-Week Dual-Segment Momentum - G0 Decision

Date: 2026-08-16

Decision: `APPROVED` for one bounded V5 Strategy Card, one branch-only
non-live build, strict Q01 validation, and one paced non-live Q02 enqueue.
This decision does not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch and durably recorded before extraction in
`decisions/2026-08-16_wti_week_dual_momentum_source_approval.md` at commit
`354986d94`.

## Candidate

- EA: `QM5_41022_wti-wdual-mom`, allocated by the deterministic registry
  command after source approval and semantic dedup review
- slug: `wti-wdual-mom`
- strategy ID: `MOP-ZHAO-WTI-WDUAL-MOM-2026_S01`
- source ID: `MOP-ZHAO-WTI-WDUAL-MOM-2026`
- host/slot 0: `XTIUSD.DWX`, D1, planned magic `410220000`
- driver: strict sign agreement between the prior completed broker week's
  disjoint Friday-to-Tuesday and Tuesday-to-Friday return segments
- lifecycle: next-Monday entry and framework Friday close

## Source Decision

The approved packet is
`strategy-seeds/sources/MOP-ZHAO-WTI-WDUAL-MOM-2026/source.md`. Moskowitz,
Ooi, and Pedersen (2012) supply the peer-reviewed own-return-sign
continuation family and WTI membership in their commodity-futures universe.
Zhao, Ding, Yu, and Kang (2026) supply bounded accessible weekly-commodity
continuation context; their full paper was inaccessible and their actual
investor-position decomposition is not replicated.

Neither source tests the two price-only split-week segments, strict agreement
state, exact Monday/Friday clock, continuous CFD, ATR stop, fixed-dollar risk,
or this portfolio. The sequence, endpoints, agreement, clock, normalization,
restart boundary, risk, stop, spread, and lifecycle are disclosed QM choices.
No source return, coefficient, significance, cost, density, WTI-only result,
CFD equivalence, decorrelation, or portfolio result transfers.

## Locked Rule

1. Admit a decision only on a broker-clock Monday and within 180 minutes of
   its executable D1 session open. Normalize only the governed prior-date
   energy label by one uniform `+1` calendar day; apply no other shift.
2. Persist the exact broker Monday `yyyymmdd` attempt before history, signal,
   news, spread, quote, ATR, sizing, or order gates and never retry the week.
3. Require the six newest completed normalized D1 bars, newest first, to be
   prior Friday, Thursday, Wednesday, Tuesday, Monday, and preceding Friday,
   exactly 3, 4, 5, 6, 7, and 10 calendar days before the decision Monday.
4. Compute
   `opening_return = log(PriorTuesdayClose / PrecedingFridayClose)` and
   `closing_return = log(PriorFridayClose / PriorTuesdayClose)` from positive
   finite completed closes. The current Monday bar enters neither return.
5. BUY only when both returns are strictly positive and SELL only when both
   are strictly negative. Exact zero, invalid history, or disagreement
   consumes the week flat. Signal magnitude never scales risk.
6. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
   `3.5 * ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.
7. Enable framework Friday close at broker hour 21. Close later-week or
   seven-day stale exposure and malformed ownership as repair paths.
8. Keep both news axes OFF. The framework kill switch and broker hard stop
   remain authoritative.

The exact weekday sequence, two disjoint completed-return intervals, strict
same-sign agreement, Monday decision clock, no-late-entry and no-retry rules,
fixed risk, stop, spread, and Friday lifecycle are load-bearing.

## Reputable-Source Criteria

- R1 `PASS_WITH_HORIZON_AND_ACCESS_RISK`: named peer-reviewed JFE paper, DOI,
  complete-paper evidence, durable retrieval hash, explicit WTI membership,
  bounded named 2026 weekly-commodity working-paper context, and disclosed
  full-text/access and split-week translation limits.
- R2 `PASS`: endpoints, weekday membership, agreement, clock, attempt, risk,
  stop, spread, and exits are fixed.
- R3 `PASS`: registered native `XTIUSD.DWX` D1 history supplies every runtime
  input; no investor-position or external feed is used.
- R4 `PASS`: deterministic native arithmetic only, without trained output,
  banned signal indicator, external runtime feed, grid, martingale, scale-in,
  or pyramid.

Both deterministic card linters returned `status: ok` for both canonical card
copies before this decision was written. The copies had identical SHA-256
`6725C3ED1AB11BB387F5C9BEA162B400D98BFD3BCF574F4550DCBF33FB2A6995`.

## Non-Duplicate Decision

The canonical pre-card checker scanned 4,509 registry rows and 605 root cards.
It returned no exact match and the expected fuzzy matches to the two adjacent
weekly segment EAs. Manual review separates:

- `QM5_41019_wti-wopen-mom`, which follows only the current week's opening
  segment from Wednesday to Friday;
- `QM5_41020_wti-wclose-mom`, which follows only the prior closing segment
  from Monday to Wednesday;
- `QM5_41021_wti-mdual-mom`, which uses a nested month/final-five agreement
  and a monthly boundary;
- `QM5_13049_xti-1w-mom-vol`, which uses a rolling magnitude threshold and
  realized-volatility rank rather than exact disjoint segment agreement;
- `QM5_21521_wti-flow-switch`, which uses tick-volume tails and can reverse
  the prior return; and
- weekly range/breakout and cumulative-RSI families, which use different
  information objects and clocks.

This candidate alone requires both completed prior-week segments to agree,
enters only the following Monday, and owns through Friday. Verdict:
`CLEAN_WTI_DISJOINT_SPLIT_WEEK_AGREEMENT_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Allocation And Kill Boundary

The atomic `farmctl reserve-ea-ids` command allocated `QM5_41022`; no ID was
inferred or hand-edited. Expected cadence is approximately 20-35 positions
per full post-warm-up year. Q02 must retire on zero trades, below five/year,
wrong weekday or endpoint reconstruction, current-bar leakage, late or
repeated entry, disagreement-side entry, wrong Friday lifecycle, invalid risk
mode, nondeterminism, or nonpositive governed economics. Q09 alone may
establish realized portfolio correlation.

## Safety Boundary

Create exactly one `XTIUSD.DWX` D1 backtest setfile with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. This decision excludes manual
backtests; live, demo, shadow, stress, and optimization setfiles; `T_Live`;
AutoTrading; deploy or T_Live manifests; portfolio-gate edits; portfolio
admission; and correlation waivers. Enqueue Q02 once, but do not dispatch or
control a tester when the factory resource ceiling is binding.
