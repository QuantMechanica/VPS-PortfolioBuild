---
card_schema_version: 2
type: strategy
strategy_id: SUENAGA-PAPAILIAS-XNG-SEASRSM-2026_S01
variant_id: SUENAGA-PAPAILIAS-XNG-SEASRSM-2026_S01
source_id: SUENAGA-PAPAILIAS-XNG-SEASRSM-2026
ea_id: QM5_20242
slug: xng-rsm-window
status: APPROVED
g0_status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20242_xng-rsm-window_card.md
execution_contract_status: DRAFT
created: 2026-08-06
created_by: Research+Development
last_updated: 2026-08-06
source_citation: "Suenaga, Smith, and Williams (2008), Journal of Futures Markets 28(5), 438-463; Papailias, Liu, and Thomakos (2021), Journal of Banking & Finance 124, 106063."
source_citations:
  - type: peer_reviewed_paper
    citation: "Suenaga, H., Smith, A., and Williams, J. C. (2008). Volatility Dynamics of NYMEX Natural Gas Futures Prices. Journal of Futures Markets 28(5), 438-463."
    location: "DOI 10.1002/fut.20317; complete governed packet strategy-seeds/sources/SUENAGA-XNG-SEASVOL-2008/source.md"
    quality_tier: A
    role: physical_volatility_windows
  - type: peer_reviewed_paper
    citation: "Papailias, F., Liu, J., and Thomakos, D. D. (2021). Return Signal Momentum. Journal of Banking & Finance 124, 106063."
    location: "DOI 10.1016/j.jbankfin.2021.106063; complete governed packet strategy-seeds/sources/PAPAILIAS-RSM-2021/source.md"
    quality_tier: A
    role: monthly_return_sign_direction
strategy_mechanic: monthly-xng-source-volatility-window-gated-twelve-completed-month-return-sign-probability-momentum
strategy_type_flags: [commodity, energy, natural-gas, seasonal-volatility-window, return-sign-momentum, monthly-rebalance, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, natural_gas]
timeframes: [D1]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: XNGUSD.DWX
symbol: XNGUSD.DWX
symbol_slot: 0
magic: 202420000
period: D1
timeframe: D1
expected_trade_frequency: "Eight eligible monthly XNG packages/year after warm-up; Q02 must prove or retire density."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PASS
q02_status: NOT_ENQUEUED_CPU_CEILING
review_focus: "Falsify XNG RSM0.4 only in peer-reviewed natural-gas volatility windows; Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [consecutive_completed_months, binary_sign_definition, fixed_probability_threshold, source_window_gate, monthly_attempt_state, risk_mode_dual, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission plus decisions/2026-08-06_qm5_20242_xng_rsm_window_g0.md; R1-R4 PASS; deterministic dedup CLEAN before allocation and manual parent review clean."
---

# QM5_20242 XNG Seasonal Return-Sign Momentum Window

The complete canonical execution card is
`strategy-seeds/cards/xng-rsm-window_card.md`; every rule below is locked to
that approved contract.

## Hypothesis

Apply the source-defined twelve-month XNG return-sign momentum state only in
the two peer-reviewed natural-gas physical volatility windows. This may create
a slower XNG driver than the incumbent two-day RSI pullback. Profitability and
portfolio decorrelation remain unproven.

## Source And Non-Duplicate Boundary

The complete source record is
`strategy-seeds/sources/SUENAGA-PAPAILIAS-XNG-SEASRSM-2026/source.md`.
Suenaga et al. provide May-September and November-January volatility timing;
Papailias et al. provide twelve binary completed-month signs and fixed
`q=0.40` direction. Neither paper tests the intersection or CFD carrier.

The deterministic checker returned CLEAN before allocation. `QM5_13116`
trades RSM0.4 year-round; `QM5_20052` uses the same windows but a single
126-D1 magnitude return; `QM5_12567` is a long-only two-day oscillator
pullback. Both source states and the monthly lifecycle are load-bearing.

## Rules

On the first processed `XNGUSD.DWX` D1 bar of each broker month, close the
prior package, persist the current month as consumed, and remain flat outside
May-September and November-January. Inside the window, reconstruct thirteen
consecutive completed month-end closes, count the twelve non-negative monthly
returns, and calculate `P = positive_count / 12`. Buy for `P >= 0.40`; sell
otherwise. Use one position, a frozen `3.5 * ATR(20,D1)` hard stop, no target,
next-month rollover, and a forty-day stale exit.

## 4. Entry Rules

- Exact EA ID `20242`, `XNGUSD.DWX` D1, magic slot 0, and locked inputs.
- Lifecycle exits precede entry; evaluate only at a real month transition.
- Consume the month before season, history, signal, spread, quote, news, stop,
  sizing, or order gates; never retry within that month.
- Require no owned position or same-month entry deal.
- Require the decision month in May-September or November-January.
- Require thirteen consecutive completed broker-month endpoints, with the
  newest endpoint immediately before the decision month.
- Count equality as non-negative. Buy at probability `>=0.40`, else sell.
- Require spread in `[0,3000]`, valid quote and ATR, and a normalized hard stop.

## 5. Exit Rules

- Close before every new-month decision and immediately off-window.
- Close after forty calendar days, or on wrong symbol/direction.
- Broker stop and framework kill switch remain authoritative.
- Friday close is disabled; no target, trail, partial, scale, grid, martingale,
  pyramid, or intramonth reversal is permitted.

## 6. Filters (No-Trade Module)

Fail closed on wrong identity, timeframe, slot, input, month, attempt state,
history, endpoint continuity, sign arithmetic, spread, quote, ATR, stop,
position, or deal state. News temporal/compliance/legacy modes are OFF. Runtime
uses native MT5 price, calendar, and execution data only; no POTS/GARCH,
weather, storage, EIA release, futures curve, file, API, trained output, or
portfolio state is permitted.

## 7. Trade Management Rules

Maintain one owned XNG position and one consumed attempt per broker month.
Preserve the original server stop. Close older-month, off-window, wrong-side,
wrong-symbol, or stale exposure before entry gates. Persistent attempt state
plus position/deal history prevents restart re-entry.

## Parameters To Test

| parameter | default | authorized values |
|---|---:|---|
| `strategy_lookback_months` | 12 | [12] |
| `strategy_positive_threshold` | 0.40 | [0.40] |
| `strategy_summer_first_month` | 5 | [5] |
| `strategy_summer_last_month` | 9 | [9] |
| `strategy_winter_first_month` | 11 | [11] |
| `strategy_winter_last_month` | 1 | [1] |
| `strategy_history_bars` | 500 | [500] |
| `strategy_atr_period` | 20 | [20] |
| `strategy_atr_sl_mult` | 3.5 | [3.5] |
| `strategy_max_hold_days` | 40 | [40] |
| `strategy_max_spread_points` | 3000 | [3000] |

## Framework Alignment

- no_trade: exact host, identity, fixed-input, news, and Friday guards.
- trade_entry: source window, completed-month sign probability, fixed-risk
  order, and hard stop.
- trade_management: monthly, off-window, wrong-state, and stale exits.
- trade_close: broker stop, kill switch, and framework close helper.

## Risk

Q02 uses only `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Natural-gas gaps, CFD basis, financing, persistent long
bias, season-gate sparsity, and correlation with the existing XNG sleeve are
binding risks. Retire below five packages/year, on nonpositive economics, or
on later Q09 correlation rejection. No parameter rescue or waiver is allowed.

No live/demo/shadow setfile, `T_Live`, AutoTrading, deploy manifest,
portfolio manifest, portfolio gate, or correlation waiver is authorized.
