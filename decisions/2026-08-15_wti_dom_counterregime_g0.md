# WTI Day-of-Month Counter-Regime — G0 Decision

Date: 2026-08-15

Decision: `APPROVED` for one bounded V5 Strategy Card, one branch-only
non-live build, strict Q01 validation, and one paced non-live Q02 enqueue.
This decision does not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch and durably recorded before extraction in
`decisions/2026-08-15_wti_dom_counterregime_source_approval.md` at commit
`22b4896d1`.

## Candidate

- EA: `QM5_41017_wti-dom-ctrreg`, allocated after semantic G0 review by the
  deterministic registry command
- slug: `wti-dom-ctrreg`
- strategy ID: `BOROWSKI-MOP-WTI-DOMCOUNTER-2026_S01`
- source ID: `BOROWSKI-MOP-WTI-DOMCOUNTER-2026`
- host/traded slot 0: `XTIUSD.DWX`, D1
- planned magic: slot 0 `410170000`
- driver: Borowski's exact WTI day-8 long/day-26 short directions admitted
  only when the completed 252-D1 return has the opposite sign
- lifecycle: exact-date attempt, at most one position, next-D1 exit

## Source Decision

The approved packet is
`strategy-seeds/sources/BOROWSKI-MOP-WTI-DOMCOUNTER-2026/source.md`. It binds
the complete governed Borowski (2016) and Moskowitz, Ooi, and Pedersen (2012)
lineages without importing a public-page proxy.

Borowski supplies the positive day-8 and negative day-26 WTI table directions.
Moskowitz, Ooi, and Pedersen supply the completed own-return sign as a slow
state. Neither paper tests the opposing-state conjunction, Darwinex broker
dates, continuous CFDs, fixed risk, stops, costs, or the QM book. The calendar
paper's multiple-cell search and post-2016 decay risk remain explicit.

## Locked Rule

1. Admit decisions only on actual `XTIUSD.DWX` D1 bars dated exactly 8 or 26
   and first observed within five minutes of their opening timestamp. Never
   shift a missing weekend or holiday date.
2. Persist the exact `yyyymmdd` attempt before every fallible gate and never
   retry the date.
3. Compute `log(Close[1] / Close[253])` from exactly 253 positive finite
   completed D1 closes; current-bar OHLC is forbidden from the state.
4. BUY on exact day 8 only when the completed return is negative. SELL on
   exact day 26 only when it is positive. Other signs, exact zero, or invalid
   history consume the date flat.
5. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
   `2.75 * ATR(20,D1)` hard stop, no target, and a 2,500-point spread ceiling.
   Signal magnitude never scales risk.
6. Close at the first following D1 boundary, after one calendar day, or on
   malformed exposure. Friday close stays enabled at broker hour 21.
7. Keep both news axes and legacy news mode OFF; use only native MT5 data and
   framework state.

The exact dates, no-shift rule, source directions, opposing completed-return
state, attempt, risk, stop, spread, and one-session lifecycle are locked.

## Reputable-Source Criteria

- R1 `PASS_WITH_MULTIPLE_TESTING_RISK`: two named-author peer-reviewed
  complete-read lineages, exact WTI table locations, JFE DOI and retrieval
  hash, and a disclosed untested conjunction.
- R2 `PASS`: dates, completed endpoints, strict sign map, attempt state,
  direction, risk, stop, spread, and exit are fixed.
- R3 `PASS`: registered native XTI D1 history supplies all runtime inputs.
- R4 `PASS`: deterministic native arithmetic only, without trained output,
  banned signal indicators, external feeds, grid, martingale, scale-in, or
  pyramid.

Both deterministic card linters returned `status: ok` before this decision.

## Non-Duplicate Decision

The canonical pre-card checker scanned 4,504 registry rows and 600 root cards,
finding no exact or fuzzy match. Manual review separates:

- `QM5_20036_wti-dom8-long` and `QM5_20027_wti-dom26-short`, which are
  unconditional single-arm calendar parents;
- `QM5_20215_wti-dom-trend`, which uses day 1 for its long arm and requires
  trend agreement on both arms; its shared day-26 state is mutually exclusive
  with this candidate;
- `QM5_12603_wti-tsmom12m`, which has a monthly clock and no exact-date
  one-session object; and
- `QM5_12567_cum-rsi2-commodity`, which is a two-day oscillator pullback.

Verdict:
`CLEAN_WTI_EXACT_DAY8_DAY26_COUNTER_REGIME_CALENDAR_AFTER_MANUAL_REVIEW`.

## Allocation And Kill Boundary

The deterministic registry command allocated `QM5_41017` from the global
next-ID sequence; no ID was inferred or hand-edited. Expected cadence is
approximately six to ten completed positions per full post-warm-up year. Q02
must retire on zero trades, below five/year, wrong or shifted dates,
non-opposing state, current-bar leakage, repeated attempts, invalid risk mode,
or nonpositive governed economics. Q09 alone may establish realized book
correlation.

## Safety Boundary

Create exactly one `XTIUSD.DWX` D1 backtest setfile with
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. This decision
excludes manual backtests; live, demo, shadow, stress, and optimization
setfiles; `T_Live`; AutoTrading; deploy or T_Live manifests; portfolio-gate
edits; portfolio admission; and correlation waivers. Enqueue Q02 once, but do
not dispatch or control a tester when the factory resource ceiling is binding.
