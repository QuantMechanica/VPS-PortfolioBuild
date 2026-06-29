---
ea_id: QM5_12780
slug: wti-52w-anchor
type: strategy
strategy_id: BIANCHI-COMM-52W-2016_S01
source_id: BIANCHI-COMM-52W-2016
source_citation: "Bianchi, R. J., Drew, M. E. and Fan, J. H. Commodities momentum: A behavioural perspective. Journal of Banking and Finance, 2016. DOI https://doi.org/10.1016/j.jbankfin.2016.06.010; SSRN https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2571725."
source_citations:
  - "Bianchi, R. J., Drew, M. E. and Fan, J. H. Commodities momentum: A behavioural perspective. Journal of Banking and Finance, 2016."
sources:
  - "[[sources/BIANCHI-COMM-52W-2016]]"
concepts:
  - "[[concepts/commodity-momentum]]"
  - "[[concepts/52-week-high-anchor]]"
indicators:
  - "[[indicators/rolling-high-low]]"
  - "[[indicators/rolling-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [n-period-max-continuation, anchor-momentum, atr-hard-stop, signal-reversal-exit, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [XTIUSD.DWX]
timeframes: [D1]
single_symbol_only: true
period: D1
expected_trade_frequency: "Monthly WTI 52-week high/low anchor package; estimate 4-10 entries/year when the anchor and 63-D1 confirmation agree."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-06-29
expected_pf: 1.08
expected_dd_pct: 18.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, enhancement_doctrine]
g0_approval_reasoning: "R1 PASS peer-reviewed commodity-momentum source; R2 PASS deterministic monthly 252-D1 anchor plus 63-D1 confirmation entry and time exit; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
---

# WTI 52-Week Anchor Momentum

Canonical card mirrors `strategy-seeds/cards/wti-52w-anchor_card.md`.

Summary: D1 `XTIUSD.DWX` 52-week high/low anchor momentum from the
Bianchi-Drew-Fan commodity momentum source. It buys near a 252-D1 closing high
with same-direction 63-D1 confirmation, sells near a 252-D1 closing low with
same-direction 63-D1 confirmation, uses a fixed ATR hard stop, and exits on
monthly rebalance or a max-hold guard. Runtime uses Darwinex OHLC, broker
calendar, spread, and ATR only.

## Hypothesis

WTI continuation should be stronger when price is anchored near its own
52-week closing high or low and a shorter 63-D1 return confirms the same
direction.

## Rules

Use a monthly closed-D1 rule: long near a 252-D1 closing high with 63-D1
positive confirmation, short near a 252-D1 closing low with 63-D1 negative
confirmation, and flatten on monthly rebalance or max hold.

## Risk

Backtests use RISK_FIXED 1000 with an ATR hard stop. Live risk, if ever
approved after Q10+, must use RISK_PERCENT through the portfolio process.

## Markets And Timeframe

- Symbol: XTIUSD.DWX.
- Period: D1.
- Expected trade frequency: approximately 4-10 trades/year.
- Runtime data: Darwinex MT5 D1 closes, broker calendar, spread, and ATR only.

## 4. Entry Rules

- Evaluate only on a new D1 bar.
- Entry is allowed only on the first D1 bar of a new broker-calendar month.
- Build a 252-bar anchor window from completed D1 closes.
- Long if `close_recent / high_252 >= strategy_anchor_long_min` and
  63-D1 return is at least `strategy_confirm_min_return_pct / 100`.
- Short if `close_recent / low_252 <= strategy_anchor_short_max` and 63-D1
  return is no more than negative `strategy_confirm_min_return_pct / 100`.

## 5. Exit Rules

- ATR hard stop at `strategy_atr_period * strategy_atr_sl_mult`.
- Exit on next monthly rebalance or after `strategy_max_hold_days`.
- V5 Friday close remains enabled.

## 6. Filters (No-Trade Module)

- Only `XTIUSD.DWX` on D1 and magic slot 0.
- Require valid lookbacks, available D1 history, available ATR, and spread no
  wider than `strategy_max_spread_points`.
- Framework news, kill-switch, and Friday-close guards remain active.

## 7. Trade Management Rules

- Symmetric long/short.
- No pyramiding, grid, martingale, partial close, or trailing stop in v1.
- One open position per magic/symbol.

## 8. Parameters To Test

- name: strategy_anchor_lookback_d1
  default: 252
- name: strategy_confirm_lookback_d1
  default: 63
- name: strategy_anchor_long_min
  default: 0.94
- name: strategy_anchor_short_max
  default: 1.08
- name: strategy_confirm_min_return_pct
  default: 2.0
- name: strategy_atr_period
  default: 20
- name: strategy_atr_sl_mult
  default: 3.25
- name: strategy_max_hold_days
  default: 31
- name: strategy_max_spread_points
  default: 1000

R1-R4: PASS/PASS/PASS/PASS. Q02 target: `XTIUSD.DWX`, D1, RISK_FIXED.

## Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
  trade_entry:
    used: true
  trade_management:
    used: true
  trade_close:
    used: true
hard_rules_at_risk:
  - friday_close
  - enhancement_doctrine
target_modules:
  - Strategy_NoTradeFilter
  - Strategy_EntrySignal
  - Strategy_ManageOpenPosition
  - Strategy_ExitSignal
  - Strategy_NewsFilterHook
```
