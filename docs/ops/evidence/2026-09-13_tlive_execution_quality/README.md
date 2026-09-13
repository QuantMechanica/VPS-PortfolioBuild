# T_Live Live Execution-Quality Measurement (2026-09-13)

## Purpose
OWNER order 2026-09-13, point **"Live-Ausführungsqualität messen"**. A strictly
read-only measurement of realized execution quality on the Darwinex-Zero live
terminal **T_Live** (account `4000090541`), derived only from the terminal
journals and EA logs. No terminal was started, no MetaTrader5 API was used, no
file under `C:/QM/mt5/T_Live/**` was written. Evidence over claims: every number
below is reproducible from the CSVs and `manifest.json` in this directory.

## Line grammar matched
Message body is `parts[3]=='Trades'`, after the `'4000090541':` prefix.

- **Order done** (reference price for pending orders + placement latency):
  `order #<id> <buy|sell>[ <stop|limit>] <vol> / <vol> <SYMBOL> at <price|market> done in <ms> ms`
  Pending (stop/limit) `at <price>` = the trigger/request price **P**. Market
  entries and closes log `at market` -> **no reference price** (see limitations).
- **Deal / fill** (join key): `deal #<id> <buy|sell> <vol> <SYMBOL> at <price> done (based on order #<id>)`; fill price = **F**.
- **Cancel completed**: `cancel #<id> ... at market done in <ms> ms` (pending order withdrawn, never filled).
- **Rejection / failure**: `failed <market buy|market sell|modify|cancel order|cancel> ... [<reason>]`.

`requote` / `off quotes` / `rejected` phrasings were searched for across the whole
corpus and **do not occur**; the rejection statistics are the `failed ... [reason]`
lines plus completed cancels.

## Metric
For each pending fill joined to its order:
`slippage_points = (F − P)/point` for **buy**, `(P − F)/point` for **sell**
(positive = adverse). Slippage sample unit = one filled pending order
(partial fills volume-weighted, so a split fill cannot inflate the count).
Point size is **inferred per symbol from price decimals** (no digits/point/tick
column exists in `dwx_symbol_matrix.csv`): USDJPY 0.001, EUR/GBP/AUD-crosses
1e-5, XAUUSD 0.01, GDAXI/NDX/SP500 0.1.

## Coverage (manifest.json)
79 journal files (since 20260424), 25 EA logs, 24 Q08 streams.
328 `order ... done` lines, **248 deal lines**: 70 matched pending-with-reference
(slippage-measurable), 122 matched market/close (no reference), **56 unmatched**
(deal references an order with no client `order ... done` line — server-side
SL/TP exits). Sleeve ticket-joins: 259.

## Per-symbol (by_symbol.csv) — adverse points, pending fills only
| symbol | n_slip | mean | median | p95 | zero% | mean lat ms | power |
|---|---|---|---|---|---|---|---|
| USDJPY | 30 | 7.63 | 1.0 | 77.0 | 37% | 178 | **OK** |
| GDAXI | 15 | 9.0 | 8.0 | 48.0 | 13% | 91 | UNDERPOWERED |
| NDX | 10 | 9.2 | 5.5 | 26.0 | 10% | 307 | UNDERPOWERED |
| EURUSD | 8 | 0.75 | 1.0 | 2.0 | 38% | 94 | UNDERPOWERED |
| XAUUSD | 4 | 298.3 | 119.5 | 920.0 | 0% | 189 | UNDERPOWERED |
| AUDUSD | 3 | 4.33 | 5.0 | 8.0 | 33% | 84 | UNDERPOWERED |
| AUDCAD/GBPUSD/SP500 | 0 | — | — | — | — | — | UNDERPOWERED |

Only **USDJPY** meets the house 30-sample floor (`MINIMUM_SAMPLES_PER_SYMBOL`).
Every other symbol is marked UNDERPOWERED; no conclusions are drawn from them.
Latency on pending rows is **placement** latency, not fill latency.

## Per-sleeve (by_sleeve.csv) — sleeves with slippage samples
| ea_id | n_slip | mean adv pts | p95 | mean lat ms | bt mean\|net\|/trade | power |
|---|---|---|---|---|---|---|
| 13213 (USDJPY) | 30 | 7.63 | 77.0 | 178 | 932.16 | **OK** |
| 13301 (GDAXI) | 15 | 9.0 | 48.0 | 91 | — | UNDERPOWERED |
| 10440 (NDX) | 10 | 9.2 | 26.0 | 307 | — | UNDERPOWERED |
| 11421 (EURUSD) | 8 | 1.88 | 8.0 | 88 | 588.08 | UNDERPOWERED |
| 11708 (EURUSD) | 3 | 1.33 | 2.0 | 102 | 219.15 | UNDERPOWERED |
| 10403 (XAUUSD) | 4 | 298.25 | 920.0 | 189 | 519.78 | UNDERPOWERED |

## Drag verdict
**Execution drag (money impact / backtest mean |net| per trade) is NOT
COMPUTABLE** and is emitted as `NOT_COMPUTABLE_NO_TICK_VALUE` in every row.
`dwx_symbol_matrix.csv` carries no tick-value/contract-size column, and the only
per-symbol prices available (`venue_cost_model.json`
`reference_prices_indicative_2026_07`) are explicitly "indicative only". Per the
Hard Rule against invented values, slippage is reported **in points only**; no
material/immaterial (>10%) verdict can be issued without a tick-value source.
The tool accepts an optional `--tick-value-json {symbol: usd_per_point_per_lot}`
to enable money impact once an OWNER-sourced tick table exists; backtest mean
|net| per sleeve is already wired in from the sealed Q08 streams for that day.

## Rejections (rejections.csv)
36098 `failed_modify` (dominated by one SL/TP modify-retry storm — `[Invalid stops]`),
63 completed cancels, 8 `failed_cancel_order` (`Market closed` / near-market /
invalid), 4 `failed_market_sell` + 3 `failed_market_buy` (`Position doesn't exist`).
No entry order was rejected for price (no requote/off-quotes).

## Limitations
- **No requested-vs-quoted spread**: MT5 does not log the quote at market-order
  request time, so market-order slippage is unmeasurable (122 fills excluded).
- **Broker time**: all timestamps are broker-time (GMT+2/+3 NY-close), not UTC.
- **Pending-order semantics**: reference price = the stop/limit trigger, so
  measured slippage is trigger-to-fill (execution slip), not decision-to-fill.
- 56 unmatched deals are server-side SL/TP exits (no client `order ... done` line).
- Point sizes inferred from price decimals, not from a broker digits registry.

## Reproduce
```
cd C:/QM/repo
python -X utf8 tools/strategy_farm/portfolio/tlive_journal_execution_quality.py \
  --journal-dir "C:/QM/mt5/T_Live/MT5_Base/logs" \
  --ea-log-dir  "C:/QM/mt5/T_Live/MT5_Base/MQL5/Files/QM" \
  --stream-root "D:/QM/reports/portfolio/dxz_v2_20260913/streams_v2b/QM/q08_trades" \
  --out-dir     "docs/ops/evidence/2026-09-13_tlive_execution_quality" \
  --since 20260424
```
Tests: `python -X utf8 -m pytest tools/strategy_farm/tests/test_tlive_journal_execution_quality.py -q`
