---
ea_id: QM5_21502
slug: xau-weekly-tsmom
type: strategy
source_id: 28681f5d-aa78-584e-9698-750d1402e485
sources:
  - "[[sources/zhao-ding-yu-kang-2026]]"
concepts:
  - "[[concepts/short-term-time-series-momentum]]"
  - "[[concepts/commodity-momentum]]"
indicators:
  - "[[indicators/lookback-return]]"
  - "[[indicators/atr-stop]]"
strategy_type_flags: [time-series-momentum, weekly-rebalance, single-symbol, atr-hard-stop, both-direction]
target_symbols: [XAUUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_21502_XAU_WEEKLY_TSMOM_D1
period: D1
expected_trade_frequency: "Weekly (5 D1 bars) trailing-return sign evaluated every completed D1 bar; new trade only on a sign flip or from flat. Estimate 25-35 flips/year on XAUUSD."
expected_trades_per_year_per_symbol: 30
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Zhao, Ding, Yu & Kang (SSRN 6425598, 2026), 'Momentum and Reversal on the Short-Term Horizon: Evidence from Commodity Markets', named authors, working paper with investor-position data across the commodity futures cross-section; anonymous-author rule is moot here but source is dated/attributed per R1 (author track record not required, link provided)."
r2_mechanical: PASS
r2_reasoning: "Deterministic sign(trailing 5-bar D1 return) rule; hold-until-flip logic; ATR hard stop; no discretion."
r3_data_available: PASS
r3_reasoning: "XAUUSD.DWX is a native DWX D1 instrument; only OHLC price data is used. The paper's actual signal decomposes returns using investors' position (COT-like) data, which QM does not have as a runtime feed (excluded macro-feed class) -- this card is a disclosed price-only mechanical proxy of the paper's 'residual return positively predicts next-week return' finding, not a replication of the flow/residual decomposition."
r4_ml_forbidden: PASS
r4_reasoning: "No ML, no adaptive/PnL-dependent parameters, no grid/martingale; deterministic price-only sign rule."
pipeline_phase: G0
last_updated: 2026-08-13
expected_pf: 1.12
expected_dd_pct: 24.0
risk_class: medium
ml_required: false
g0_approval_reasoning: "R1 PASS single SSRN source lineage; R2 PASS deterministic 5-bar return-sign entry with flip/time/ATR exits and plausible about 30/year joint cadence; R3 PASS native XAUUSD.DWX price-only proxy with no COT or external runtime feed; R4 PASS deterministic ML-free one-position logic."
---

# XAUUSD Weekly Time-Series Momentum (Short-Horizon Price Proxy)

## Source

- Source: [[sources/zhao-ding-yu-kang-2026]]
- Citation: Shen Zhao, Yiyi Ding, Jianfeng Yu, Wenjin Kang (2026). "Momentum and
  Reversal on the Short-Term Horizon: Evidence from Commodity Markets." SSRN
  Working Paper, abstract_id=6425598.
  https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6425598
- Key finding: using investors' position data, the paper decomposes weekly
  commodity futures returns into a flow component (speculators' net trading)
  and a residual component. The residual component **positively** predicts
  next-week return (short-term momentum); the flow component predicts
  **negatively** (short-term reversal). Both effects hold "across the entire
  cross-section of sample commodities." The paper explicitly contrasts this
  with the textbook view that short horizons show only reversal.

## Edge / Thesis And Disclosed Porting Gap

The paper's actual signal requires decomposing weekly returns via investor
position (COT-style) data, which is on the QM excluded-macro-feed list (no
runtime COT/positioning feed exists; a "supply a CSV of position data" input
does not exist at run time). **This card does not implement that
decomposition.** It implements the simplest mechanical, price-only proxy of
the paper's headline result -- that short-horizon (weekly) momentum exists
and is positive on average across commodities -- using nothing but native
XAUUSD.DWX D1 closes: sign of the trailing 1-week (5 completed D1 bars)
return predicts the next week's direction.

This is a disclosed falsification of the *residual*-momentum claim using raw
return instead of the paper's flow-purged residual return. If XAUUSD's raw
weekly return has enough of the residual signal embedded (i.e., flow noise
does not dominate), the sign rule should show a positive edge; if flow noise
dominates, it will show near-zero or negative edge, which is itself an
informative falsification. No performance number, t-stat, or magnitude from
the paper is imported into `expected_pf`/`expected_dd_pct` above -- both are
generic mission-baseline priors.

## Markets And Timeframe

- Target symbol: `XAUUSD.DWX` only.
- Period: D1 (weekly signal is built from 5 completed D1 bars).
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: native MT5 D1 OHLC on XAUUSD only; no external feed, no
  position/COT data, no ML model.

## Entry Rules

- Evaluate only on a new completed D1 bar.
- Every 5 completed D1 bars (a "broker week" counter, not calendar-Sunday
  dependent), compute:
  `weekly_ret = (Close[0] - Close[5]) / Close[5]` using completed bars only.
- `signal = +1` if `weekly_ret > 0`; `signal = -1` if `weekly_ret < 0`; if
  `weekly_ret == 0` (exact tie), carry forward the previous signal (stay
  flat if no previous signal).
- If `signal == +1` and not already long: close any open short, open long.
- If `signal == -1` and not already short: close any open long, open short.
- If `signal` matches the currently held position direction: hold (no new
  trade this evaluation).
- No entry if XAUUSD spread exceeds `strategy_max_spread_points`.
- No entry if fewer than 6 completed D1 bars of history are available.

## Exit Rules

- Signal-flip exit: closing the losing-direction position and opening the
  new-direction position happens atomically at the weekly re-evaluation (see
  Entry Rules).
- Stop loss: fixed hard SL at `strategy_atr_sl_mult` x `ATR(strategy_atr_period,
  D1)` from entry.
- Max-hold exit: close after `strategy_max_hold_bars` completed D1 bars
  (default 15, i.e. 3 re-evaluation cycles) even if the signal has not
  flipped, to bound single-position tenure.
- Friday close remains enabled by the V5 framework.
- No trailing stop, no take-profit, no partial close in v1.

## Filters

- Only trade `XAUUSD.DWX` on D1.
- Framework news, kill-switch, magic, and Friday-close guards remain active.
- Spread cap via `strategy_max_spread_points`.

## Trade Management Rules

- Both long and short.
- One open position per magic.
- No pyramiding, gridding, martingale, or scale-in.
- No partial close.

## Parameters To Test

- name: strategy_lookback_bars
  default: 5
  sweep_range: [3, 5, 8, 10]
- name: strategy_atr_period
  default: 14
  sweep_range: [10, 14, 20]
- name: strategy_atr_sl_mult
  default: 2.5
  sweep_range: [2.0, 2.5, 3.0, 3.5]
- name: strategy_max_hold_bars
  default: 15
  sweep_range: [10, 15, 21]
- name: strategy_max_spread_points
  default: 300
  sweep_range: [150, 300, 500]

## Dedup Assessment

| Card | Overlap? | Verdict |
|---|---|---|
| QM5_1101_qp-comm-mom12 | 12-month commodity momentum, monthly rebalance | DIFFERENT HORIZON -- this card is 5-bar (weekly), not 12-month; different signal cadence entirely |
| QM5_12616_tsmom-9m-commodity-xtiusd (rejected as dup-of-approved) | 9-month lookback, XTI, monthly trigger | Different instrument, different (18x longer) lookback, different symbol |
| QM5_12622_comm-reversal-12m-contrarian-xauusd (rejected, freq) | 12-month contrarian threshold fade on XAUUSD | Opposite mechanism (contrarian threshold vs continuous momentum) and 12x longer horizon |
| QM5_DRAFT_miffre-comm-week-xmom (cards_review, un-idd draft) | Weekly cross-sectional rank across XTI/XBR/XNG/XCU, long-winner/short-loser | DIFFERENT MECHANISM -- that card ranks 4 symbols against each other (cross-sectional); this card uses XAUUSD's own trailing return sign only (time-series/absolute momentum), no ranking, different symbol universe |

No existing card uses a 1-week (5-bar) time-series momentum sign rule on
XAUUSD. This directly and minimally operationalizes the paper's short-horizon
finding.

## Low-Correlation Argument

- Distinct horizon from the existing 3/9/12-month TSMOM family (QM5_1101,
  QM5_12613/12615/12616 lineage) -- an order of magnitude shorter lookback,
  so signal turnover and regime sensitivity differ materially.
- Time-series (absolute, single-symbol) construction is orthogonal to the
  cross-sectional rank-and-rotate style used by the Miffre-Rallis draft.
- No RSI/MR, no basket, no spread.

## Net-Cost Check

XAUUSD commission ~$0.4-$6.7/round-trip. ~30 trades/year at weekly holding
periods (multi-day average tenure via hold-until-flip) keeps turnover
moderate; gross should stay close to net given the strategy is not
scalp-frequency.

## Initial Risk Profile

- expected_pf: 1.12
- expected_dd_pct: 24
- expected_trade_frequency: approximately 25-35 trades/year.
- risk_class: medium.
- gridding: false.
- scalping: false.
- ml_required: false.

## Framework Alignment

- no_trade: D1 XAUUSD.DWX guard, 5-bar history guard, spread cap.
- trade_entry: sign(trailing 5-bar D1 return) with hold-until-flip logic.
- trade_management: ATR hard stop, max-hold time stop.
- trade_close: signal-flip close/reopen, ATR stop, time stop, framework
  Friday close.

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-13 | APPROVED | `D:\QM\strategy_farm\artifacts\cards_approved\QM5_21502_xau-weekly-tsmom.md` |
