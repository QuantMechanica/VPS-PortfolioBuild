# QM5_9166 Gemini build — mandatory Codex review

Date: 2026-08-23 UTC

Router task: `22c43872-4059-4777-97d5-1800c98bcfc7`

Source task: `a7124029-0e45-4137-be9e-49e31f685b6a` (`gemini`, build delivery only)

Reviewed artifact: `framework/EAs/QM5_9166_aa-vol-ma-timing/build_identity.json`

Verdict: **REQUEST_CHANGES — cross-sectional volatility selection and the approved 10-month signal are absent; do not promote to PIPELINE**

## Findings

### 1. Critical — the volatility-ranked high-quintile portfolio is not implemented

The approved strategy computes trailing 12-month realized volatility for every
instrument in the active basket, ranks that basket, and admits only the highest-
volatility quintile (subject to the minimum-universe fallback). The EA computes
realized volatility for `_Symbol` only and merely tests that the result is
positive. It never loads the other symbols, constructs a common snapshot,
ranks them, selects a quintile, or proves that the active universe has the card's
minimum membership.

As a result, every independently attached symbol whose moving-average condition
is true can enter. `Strategy_ExitSignal()` also cannot implement the mandatory
exit when a sleeve leaves the high-volatility quintile.

Required correction: create one deterministic, completed-month cross-sectional
snapshot for the availability-checked approved basket; calculate comparable
12-month volatility values; implement the documented quintile/minimum-universe
rule; seal membership for the rebalance month; and use that same membership for
both entry and exit.

### 2. Critical — a 210-daily-close SMA replaces the 10 month-end-close SMA

The card defines `SMA10M` as the average of the last 10 completed month-end
closes. The EA calculates `QM_SMA(... PERIOD_D1, strategy_sma_months * 21, 1)`,
which is a 210-session daily SMA. Daily observations weight months by their
number of sessions and include every within-month path, so this is not the fixed
monthly series and can change the signal.

Required correction: read the last 10 completed `MN1`/month-end closes exactly,
fail closed when any required observation is missing, and compare the just-
completed monthly close with that fixed average.

### 3. Critical — portfolio risk is multiplied rather than distributed

The card requires equal risk across active high-volatility sleeves and says the
P2 `RISK_FIXED=1000` budget is distributed across them. Each of the 13 generated
sets independently supplies `RISK_FIXED=1000`; there is no coordinator or active-
sleeve divisor. Three selected sleeves therefore request 3,000 units of fixed
risk rather than sharing 1,000, and the missing quintile gate can multiply that
further across the full cohort.

Required correction: bind sizing to the sealed active-sleeve count and prove
that aggregate requested risk remains the card budget while each selected sleeve
receives an equal share.

### 4. High — entry/exit state is consumed before trade action succeeds

`Strategy_EntrySignal()` assigns `g_last_entry_rebalance_key` before
`QM_TM_OpenPosition()` reports success. A broker, stress, governor, or risk
rejection therefore consumes the only monthly entry opportunity. Likewise,
`Strategy_ExitSignal()` assigns `g_last_exit_rebalance_key` before
`QM_TM_ClosePosition()` succeeds. One rejected close prevents another exit
attempt for the rest of the process lifetime in that month. Both keys are also
restart-volatile.

Required correction: advance durable rebalance/action state only from confirmed
trade evidence, while allowing risk-reducing close retries until the position is
actually flat.

### 5. High — entry filters can suppress exits and Friday close

The news decision and `Strategy_NoTradeFilter()` return before Friday-close and
strategy-exit handling. The latter includes chart timeframe, history, and spread
entry eligibility. News blackout, wide/invalid spread, missing ATR/history, or a
wrong chart timeframe can therefore leave an open position unmanaged. These are
not authorized exit conditions.

Required correction: fail initialization closed on a wrong chart timeframe and
keep framework/strategy risk reduction independent from all new-entry filters.
Apply news and spread eligibility only at entry admission.

### 6. Medium — the spread sample fails open when evidence is invalid

The 20-day median-spread concept is present, but the implementation permits an
entry when `ask <= bid`, current spread rounds to zero, or the median is zero or
unavailable. `CopyRates` also accepts any positive partial copy instead of
requiring all 20 observations. This converts incomplete/invalid evidence into a
pass.

Required correction: require exactly 20 valid completed-D1 spread observations,
positive bid/ask ordering, and a positive median before entry can pass.

## Checks that passed

- The canonical approved card exists with `g0_status: APPROVED`; its SHA-256 and
  the EA-local copy both equal
  `e1aa4986c448784f0bd9e1cfa7847b9e7bc02c862d1f335de6c3f1d0a02d9c9a`.
- EA registry row `9166 / aa-vol-ma-timing` is active.
- Thirteen active, symbol-specific magic rows and thirteen corresponding D1
  backtest setfiles exist.
- Every setfile uses `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- `python tools/strategy_farm/validate_build_guardrails.py framework/EAs/QM5_9166_aa-vol-ma-timing`
  returned `PASS`, checking 14 files with zero findings and enforcing
  `max_news_stale_hours=336`.
- MQ5 SHA-256 matches `build_identity.json`:
  `da6458795d657749428fdb2575afc3c0e6431cada360640ceeabe67a87dba4df`.
- EX5 SHA-256 matches `build_identity.json`:
  `24052fdfd2c26d73922f5fd103ad49ebef008bc0049adbda6b1efe173eba3f3f`.
- The per-symbol realized-volatility primitive uses 252 completed D1 log
  returns and annualizes their sample standard deviation. Monthly boundary
  detection, long/cash default, 3.0 x ATR(20,D1) catastrophic stop, direct
  first-on-tick MAE tracking, and request initialization are present.
- No ML, martingale, grid, or HFT mechanism is present.

These checks establish artifact consistency and baseline hardening only. They
do not establish the approved portfolio strategy and are not a pipeline verdict.

## Disposition

No source, binary, registry, setfile, task verdict, or trade stream was changed
by this review. `T_Live` and AutoTrading were not touched. The task remains in
`REVIEW` with `REQUEST_CHANGES`; corrected Gemini code requires a fresh
mandatory Codex review before any acceptance or enqueue.
