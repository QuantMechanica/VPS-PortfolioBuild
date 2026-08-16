# WTI First-Wednesday / Prior-Month Momentum - G0 Decision

Date: 2026-08-16

Decision: `APPROVED` for one bounded V5 Strategy Card, one branch-only
non-live build, strict Q01 validation, and one paced non-live Q02 enqueue.
This decision does not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch and durably recorded before extraction in
`decisions/2026-08-16_wti_first_wednesday_month_momentum_source_approval.md`
at commit `01d4b0d45`.

## Candidate

- EA: `QM5_41024_wti-1wed-mom1`, allocated by the deterministic registry
  command at commit `9ee451dab`
- slug: `wti-1wed-mom1`
- strategy ID: `LI-MOP-WTI-1WED-MOM1-2026_S01`
- source ID: `LI-MOP-WTI-1WED-MOM1-2026`
- host/slot 0: `XTIUSD.DWX`, D1, planned magic `410240000`
- driver: immediately completed broker-month WTI return sign sampled only on
  the next month's first genuine Wednesday
- lifecycle: one D1 interval with fixed-dollar risk and a frozen ATR stop

## Source Decision

The approved packet is
`strategy-seeds/sources/LI-MOP-WTI-1WED-MOM1-2026/source.md`. Li, Zhu, Wen,
and Nor (2022) supply the WTI Wednesday information clock. Moskowitz, Ooi,
and Pedersen (2012) supply instrument-own completed-return-sign continuation,
one-month formation lineage, and explicit WTI commodity membership.

Neither source tests the exact conjunction. The first-Wednesday-only clock,
symmetric direction, one-session hold, energy-label normalization,
continuous-CFD carrier, ATR stop, spread ceiling, and fixed cash risk are QM
translation choices. No source performance, coefficient, significance, cost,
density, CFD equivalence, decorrelation, or portfolio result transfers.

## Locked Rule

1. Admit a decision only on an `XTIUSD.DWX` D1 bar whose uniformly normalized
   label equals the broker date, is Wednesday, and is dated day 1-7. The
   immediately prior normalized D1 label must be Tuesday. Missing or holiday
   first Wednesdays do not shift.
2. Support only the governed native same-day label or one uniform `+1`
   calendar-day energy normalization. Require the first observed tick within
   180 minutes of the executable session open.
3. Persist the exact normalized broker `yyyymm` attempt before history,
   signal, news, spread, quote, ATR, sizing, or order gates and never retry or
   backfill the month.
4. Reconstruct the newest completed D1 closes in the immediately prior two
   normalized broker months. Require positive finite prices, strict timestamp
   order, and exact consecutive month keys. Current-month bars and the live
   bar enter neither endpoint.
5. Compute `log(PriorMonthEnd / PriorPriorMonthEnd)`. BUY only when strictly
   positive and SELL only when strictly negative. Exact zero or invalid state
   consumes the month flat; magnitude never scales risk.
6. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
   `3.0 * ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.
7. Close on the first following normalized D1 boundary, after five calendar
   days as a stale guard, or on malformed/duplicated exposure.
8. Keep both news axes OFF and framework Friday close enabled at broker hour
   21. The framework kill switch and broker hard stop remain authoritative.

The normalized first-Wednesday clock, completed-calendar-month endpoints,
strict sign/direction mapping, no-late-entry/no-retry rules, fixed risk, hard
stop, and one-D1 lifecycle are load-bearing. No parameter sweep is approved.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: two named-author peer-reviewed
  primary papers with DOI identity; complete MOP paper evidence and durable
  hash; explicit LI abstract/highlights boundary; untested conjunction and
  shortened hold disclosed.
- R2 `PASS`: normalized date, first-Wednesday predicate, endpoint months,
  return sign, direction, clock, attempt, risk, stop, spread, and exit are
  fixed.
- R3 `PASS`: registered native `XTIUSD.DWX` D1 history supplies every runtime
  input.
- R4 `PASS`: deterministic native arithmetic only, without trained output,
  banned signal indicator, external feed, grid, martingale, scale-in, or
  pyramid.

Both deterministic card linters returned `status: ok` for the canonical root
and approved copies. The copies are byte-identical with SHA-256
`1060C9FD4D1249CF1001E4D9BECBDCAD17D604A2024958BC6EE1E2E9AA1BB269`.
The governed composite source packet has SHA-256
`7B22DC5F38EFBC719784551870DCC4EF9BA09A04FA4590478E1945069BFDCB13`.

## Non-Duplicate Decision

The canonical pre-card checker scanned 4,511 registry rows and 607 root cards,
found no exact match, and raised no fuzzy match above threshold. Manual review
separates:

- `QM5_20154_wti-wed-trend`: every Wednesday, positive 252-D1 state, long only;
- `QM5_20170_wti-wed-bear`: every Wednesday, negative 252-D1 state, long only;
- `QM5_20022_wti-wed-long` and `QM5_12775_wti-wed-prem`: unconditional
  Wednesday longs;
- `QM5_20187_wti-tsmom1m`: month-boundary entry with a full-month hold;
- `QM5_41013_wti-mopen-mom`: current-month first-five-session formation and
  sixth-session entry; and
- `QM5_12567_cum-rsi2-commodity`: short-horizon oscillator pullback across
  commodity carriers.

Verdict:
`CLEAN_WTI_FIRST_WEDNESDAY_PRIOR_MONTH_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Allocation And Kill Boundary

The atomic `farmctl reserve-ea-ids` command allocated `QM5_41024`; the ID was
not inferred or hand-edited. Expected cadence is approximately ten to twelve
positions per full post-warm-up year. Q02 must retire on zero trades, below
five/year, a wrong/shifted Wednesday, wrong month endpoints, current-bar
leakage, late/repeated entry, sign/direction mismatch, wrong lifecycle,
invalid risk mode, nondeterminism, or nonpositive governed economics. Q09
alone may establish realized portfolio correlation.

## Safety Boundary

Create exactly one `XTIUSD.DWX` D1 backtest setfile with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. This decision excludes manual
backtests; live, demo, shadow, stress, and optimization setfiles; `T_Live`;
AutoTrading; deploy or T_Live manifests; portfolio-gate edits; portfolio
admission; and correlation waivers. Enqueue Q02 once, but do not dispatch or
control a tester when the factory resource ceiling is binding.
