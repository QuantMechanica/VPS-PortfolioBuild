---
ea_id: QM5_12376
slug: tmom-fut-contr
type: strategy
source_id: 72f9fcfa-6c75-5544-80c4-31e15c9817ab
source_citation: "ThewindMom/151-trading-strategies, src/strategies/futures/contrarian.py, https://github.com/ThewindMom/151-trading-strategies/blob/main/src/strategies/futures/contrarian.py"
sources:
  - "[[sources/github-topic-algorithmic-trading-python]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/cross-sectional-contrarian]]"
indicators:
  - "[[indicators/relative-return]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX, GER40.DWX, NDX.DWX, WS30.DWX]
period: W1
expected_trade_frequency: "Weekly 4-week relative-return contrarian rotation; conservative estimate 20 completed trades/year/symbol."
expected_trades_per_year_per_symbol: 20
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id 72f9fcfa present, linking to exact public GitHub file contrarian.py in ThewindMom/151-trading-strategies."
r2_mechanical: PASS
r2_reasoning: "Fixed 4-week relative-return computation, ascending rank, top_n long/short buckets, and weekly rebalance exit are fully mechanical."
r3_data_available: PASS
r3_reasoning: "Weekly close returns computable from DWX FX, metals, and index CFD history; futures source ports cleanly to CFD basket."
r4_ml_forbidden: PASS
r4_reasoning: "Deterministic arithmetic ranking on price returns; no ML, no PnL-adaptive parameters, one position per symbol/magic."
pipeline_phase: G0
last_updated: 2026-05-26
strategy_type_flags: [mean-reversion, cross-sectional-ranking, weekly-system, signal-reversal-exit, atr-hard-stop, long-short]
card_body_incomplete: true
card_body_missing: "source_citation"
g0_approval_reasoning: "R1 single source_id and exact GitHub file; R2 weekly 4-week relative-return long/short rebalance supports basket cadence; R3 ports to DWX FX/metals/indices; R4 deterministic no-ML one-position-per-magic."
---

# ThewindMom Futures Relative Contrarian

## Quelle
- Source: [[sources/github-topic-algorithmic-trading-python]]
- Topic URL: https://github.com/topics/algorithmic-trading?l=python
- Repository: https://github.com/ThewindMom/151-trading-strategies
- README: https://github.com/ThewindMom/151-trading-strategies/blob/main/README.md
- Primary file: https://github.com/ThewindMom/151-trading-strategies/blob/main/src/strategies/futures/contrarian.py
- Source citation: 2026 GitHub URL https://github.com/ThewindMom/151-trading-strategies/blob/main/src/strategies/futures/contrarian.py
- Author / institution: GitHub handle `ThewindMom`.
- Source location: `Strategy 10.3: Contrarian`.

## Mechanik

### Entry
- Evaluate once per completed W1 bar.
- Source defaults: `lookback = 4`, `top_n = 3`.
- Compute each symbol's compounded return over the last 4 weekly returns.
- Compute benchmark compounded return over the same 4 weeks.
- Compute `relative_return = symbol_cum_return - benchmark_cum_return`.
- Sort symbols by relative return ascending.
- Enter/hold long on the `top_n` lowest relative-return symbols.
- Enter/hold short on the `top_n` highest relative-return symbols.

### Exit
- Close or reverse when the symbol is no longer in its prior long or short bucket at the next weekly rebalance.
- If the configured basket is too small for both sides, reduce `top_n` so long and short buckets do not overlap.

### Stop Loss
- Source does not define a protective stop.
- P2 baseline: `2.0 * ATR(14)` hard stop from entry, computed on D1 bars.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: `RISK_PERCENT = 0.25`.
- One open position per symbol/magic.

### Zusaetzliche Filter
- Minimum warmup: 8 W1 bars.
- Default benchmark: equal-weight average of configured basket returns; SP500.DWX can be tested as an index-specific benchmark.
- Optional P3 gate: require absolute z-score >= `0.5` before entry.

## Concepts
- [[concepts/mean-reversion]] - source buys recent relative losers and shorts recent relative winners.
- [[concepts/cross-sectional-contrarian]] - ranking is computed across a futures-style basket.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Source-Link | PASS | Single source_id with public GitHub topic, repository owner, README, and exact source file URL. |
| R2 Mechanical | PASS | Fixed lookback, benchmark-relative return, ranking, and top_n buckets define deterministic long/short state. |
| R3 DWX-testbar | PASS | Weekly returns can be computed from DWX FX, metals, and index CFD closes; futures source is ported to CFD basket. |
| R4 No ML | PASS | Deterministic arithmetic ranking; no ML, online learning, grid, martingale, or multiple positions per magic. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX, GER40.DWX, NDX.DWX, WS30.DWX. SP500.DWX is optional backtest-only. Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Source labels the rule "Strategy 10.3: Contrarian".
- Source description says "Weekly mean-reversion relative to market index."
- Source returns `positions`, `long_assets`, `short_assets`, and `market_return`.

## Parameters To Test
- Weekly lookback: `2`, `4`, `8`.
- Top_n: `1`, `2`, `3`.
- Z-score gate: `0.0`, `0.5`, `1.0`.
- Stop: `1.5`, `2.0`, `2.5 * ATR(14)`.

## Initial Risk Profile
Weekly cross-sectional reversal. Main risks are correlated baskets, overlapping long/short buckets in small universes, and regime periods where relative winners continue to trend.

## Pipeline-Verlauf
- G0: 2026-05-26, PENDING, drafted from `ThewindMom/151-trading-strategies`.

## Lessons Learned
- TBD during pipeline run.
