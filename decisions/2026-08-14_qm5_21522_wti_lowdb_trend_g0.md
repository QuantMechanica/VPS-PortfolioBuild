# QM5_21522 WTI Low-Downside-Beta Trend — G0 Decision

Date: 2026-08-14

Decision: `APPROVED` for one bounded V5 Strategy Card, one branch-only
non-live build, strict Q01 validation, and one paced non-live Q02 handoff if
the factory CPU ceiling permits.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on
the `agents/board-advisor` branch and durably recorded before allocation in
`decisions/2026-08-14_wti_lowdb_trend_source_approval.md` at commit
`41586b233`.

## Candidate

- EA: `QM5_21522_wti-lowdb-trend`
- Strategy ID: `MOP-HOLLSTEIN-WTI-LOWDB-2026_S01`
- Source ID: `MOP-HOLLSTEIN-WTI-LOWDB-2026`
- traded symbol/slot/magic: `XTIUSD.DWX` / 0 / `215220000`
- read-only factor: `SP500.DWX`
- driver: exact twelve-completed-month WTI return-sign trend admitted only
  when WTI's SP500 downside beta in the recent 252-return block is strictly
  lower than in the preceding disjoint 252-return block
- lifecycle: one consumed monthly attempt, frozen `3.5 * ATR(20,D1)` hard
  stop, monthly renewal, forty-day stale guard, and 1,500-point spread cap

## Source Decision

The approved composite packet is
`strategy-seeds/sources/MOP-HOLLSTEIN-WTI-LOWDB-2026/source.md`. It is bound to
complete governed reads of:

- Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics*
  104(2), 228-250, for twelve-month own-return-sign momentum, monthly cadence,
  and explicit WTI membership; and
- Hollstein, Prokopczuk, and Tharann (2021), *Quarterly Journal of Finance*
  11(4), article 2150017, for the conditional DownBeta definition, monthly
  cadence, low-beta orientation, explicit WTI membership, and adverse null
  evidence.

The DownBeta paper reports an insignificant, unstable characteristic and
calls it mostly unpriced. That is binding adverse evidence. The gate is a
falsifiable attempt to suppress equity-downside overlap in an independently
sourced WTI trend; it is not claimed as a standalone premium.

Neither source tests the exact conjunction, two time-series beta blocks, raw
SP500 CFD proxy, risk-free-zero substitution, fixed-dollar sizing, hard stop,
spread ceiling, or QM book. No source return, significance, drawdown, density,
cost, CFD equivalence, decorrelation, or portfolio result transfers.

## Locked Rule

At the first processed WTI D1 bar after each genuine broker-month transition:

1. Run lifecycle repair and close prior-month owned exposure before entry-only
   gates. Persist the new broker month as attempted before all fallible gates.
2. Reconstruct thirteen consecutive completed WTI broker-month endpoints and
   calculate `trend_12m = ln(C_latest / C_12_months_older)`.
3. Load exactly 505 synchronized completed WTI and SP500 D1 closes, form 504
   chronological simple-return pairs, and split them into preceding returns
   `0..251` and recent returns `252..503`.
4. For each block independently, compute the mean of all 252 SP500 returns,
   retain only rows with `r_SP500 < mean_SP500`, and require at least 100 rows
   plus positive finite SP500 sample variance.
5. Estimate `r_WTI = alpha + beta_down * r_SP500 + error` by intercept OLS on
   the retained rows. Require finite preceding and recent slopes.
6. Admit only when
   `beta_down_recent < beta_down_preceding - 1e-12`.
7. Buy on strictly positive admitted `trend_12m`, sell on strictly negative
   admitted `trend_12m`, and consume a beta-gate failure or trend tie flat.
8. Open at most one WTI position with `RISK_FIXED=1000`, a frozen
   `3.5 * ATR(20,D1)` stop, no take-profit, and the fixed spread cap. Close
   before monthly replacement or after forty days. Friday close and both news
   axes are OFF.

`SP500.DWX` is read-only and may never receive a magic, order, position, or
package-PnL role. Simple returns, block-local means, strict down-day selection,
sample variance, block offsets, falling-beta direction, trend horizon, fixed
risk, stop, hold, and no-retry policy are locked.

## Reputable-Source Criteria

- R1 `PASS_WITH_ADVERSE_EVIDENCE`: two named peer-reviewed sources with DOI
  lineage, complete governed reads, explicit WTI membership, and the DownBeta
  null retained.
- R2 `PASS`: exact month endpoints, synchronized daily support, disjoint block
  offsets, conditional OLS, strict gate, trend direction, lifecycle, risk,
  stop, and stale guard are deterministic.
- R3 `PASS_FOR_DISCLOSED_PROXY`: registered WTI/SP500 D1 data supply every
  runtime input; CRSP excess-return and risk-free fidelity are unavailable.
- R4 `PASS`: native arithmetic only, without trained output, prohibited signal
  indicator, external runtime feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,394 EA-registry rows and 490
root cards and returned `CLEAN` with no fuzzy neighbor. Manual review confirms:

- `QM5_13203_energy-downbeta` estimates one concurrent XTI/XNG cross-sectional
  rank and trades an opposite-leg basket. This candidate compares two disjoint
  WTI beta histories, uses beta only as a gate, and trades a one-leg trend.
- `QM5_21516_wti-decoup-trend` uses weak absolute 63-D1 WTI/XNG correlation,
  not SP500 down-day conditional OLS or two 252-return blocks.
- Pure WTI time-series momentum is unconditional. WTI volatility-beta,
  jump-beta, tail, moment, calendar, event, breakout, reversal, and robust-
  location systems use different information objects.
- `QM5_12567` is a short-horizon, long-only XNG cumulative-RSI pullback and
  shares neither instrument, factor state, direction map, nor clock.

The synchronized WTI/SP500 histories, block-local market means, strict
down-day subsets, two intercept OLS slopes, falling-beta eligibility, separate
twelve-month trend direction, WTI-only topology, and consumed monthly attempt
are jointly load-bearing. Verdict:
`CLEAN_WTI_FALLING_DOWNSIDE_BETA_GATED_TWELVE_MONTH_TREND`.

## Allocation And Kill Boundary

The atomic allocator reserved `QM5_21522` on 2026-08-14. Expected cadence is
approximately five to seven completed positions per full post-warm-up year;
Q02 must retire below five/year or on nonpositive governed economics. Q09
alone may establish realized correlation with XAU, SP500, NDX, and XNG.

Fail on wrong month mapping, close or return count, timestamp mismatch,
overlapping returns, pooled means, non-strict down days, population variance,
fewer than 100 selected rows, singular OLS, reversed beta gate, trend-free
entry, same-month retry, SP500 order, missing stop, invalid risk mode, stale
hold, or nondeterminism. No failed result may change a locked rule or carrier.

## Safety Boundary

Create exactly one `XTIUSD.DWX` D1 backtest setfile with
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. This decision
excludes manual backtests; live, demo, shadow, stress, and optimization
setfiles; `T_Live`; AutoTrading; deploy or T_Live manifests; portfolio-gate
edits; portfolio admission; and correlation waivers. If the paced factory CPU
ceiling is binding before enqueue, stop without starting, stopping, reserving,
reaping, or reprioritizing a terminal.
