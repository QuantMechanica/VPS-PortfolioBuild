---
ea_id: QM5_12807
slug: xng-52w-anchor
type: strategy
strategy_id: BIANCHI-COMM-52W-2016_S02
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
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
markets: [XNGUSD.DWX]
timeframes: [D1]
single_symbol_only: true
period: D1
expected_trade_frequency: "Monthly natural gas 52-week high/low anchor package; estimate 4-10 entries/year when the anchor and 63-D1 confirmation agree."
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
expected_dd_pct: 22.0
risk_class: high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, enhancement_doctrine]
g0_approval_reasoning: "R1 PASS peer-reviewed commodity-momentum source; R2 PASS deterministic monthly 252-D1 anchor plus 63-D1 confirmation entry and time exit; R3 PASS XNGUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
---

# Natural Gas 52-Week Anchor Momentum

Canonical approved card:
`strategy-seeds/cards/approved/QM5_12807_xng-52w-anchor_card.md`.

Summary: D1 `XNGUSD.DWX` 52-week high/low anchor momentum from the
Bianchi-Drew-Fan commodity momentum source. It buys near a 252-D1 closing high
with same-direction 63-D1 confirmation, sells near a 252-D1 closing low with
same-direction 63-D1 confirmation, uses a fixed ATR hard stop, and exits on
monthly rebalance or a max-hold guard. Runtime uses Darwinex OHLC, broker
calendar, spread, and ATR only.

## Hypothesis

Natural-gas continuation should be stronger when price is anchored near its own
52-week closing high or low and a shorter 63-D1 return confirms the same
direction.

## Rules

Monthly D1 rule: long near a 252-D1 closing high with positive 63-D1
confirmation, short near a 252-D1 closing low with negative 63-D1 confirmation,
then flatten on monthly rebalance or max hold.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XNGUSD.DWX` D1
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process.

## 4. Entry Rules

- Monthly D1 only.
- Long if `close_recent / high_252 >= strategy_anchor_long_min` and 63-D1
  return is positive beyond the threshold.
- Short if `close_recent / low_252 <= strategy_anchor_short_max` and 63-D1
  return is negative beyond the threshold.

## 5. Exit Rules

- ATR hard stop.
- Monthly rebalance exit.
- Max-hold exit.

## 6. Filters (No-Trade Module)

- `XNGUSD.DWX` D1 only.
- Magic slot 0 only.
- Warmup, ATR, spread, news, kill-switch, and Friday-close checks.

## 7. Trade Management Rules

- One position per magic/symbol.
- No grid, martingale, pyramid, partial close, or trailing stop.

