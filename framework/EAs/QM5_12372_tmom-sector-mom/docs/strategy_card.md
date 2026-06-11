---
ea_id: QM5_12372
slug: tmom-sector-mom
type: strategy
source_id: 72f9fcfa-6c75-5544-80c4-31e15c9817ab
source_citation: "ThewindMom/151-trading-strategies, src/strategies/etfs/sector_momentum.py, https://github.com/ThewindMom/151-trading-strategies/blob/main/src/strategies/etfs/sector_momentum.py"
sources:
  - "[[sources/github-topic-algorithmic-trading-python]]"
concepts:
  - "[[concepts/cross-sectional-momentum]]"
  - "[[concepts/sector-rotation]]"
indicators:
  - "[[indicators/cumulative-return]]"
target_symbols: [GER40.DWX, NDX.DWX, WS30.DWX, SP500.DWX]
period: D1
expected_trade_frequency: "D1/weekly basket rotation from a 12-return lookback; conservative estimate 12 completed trades/year/symbol."
expected_trades_per_year_per_symbol: 12
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-26
strategy_type_flags: [cross-sectional-momentum, rotation, ranking-entry, signal-reversal-exit, atr-hard-stop, long-only]
g0_approval_reasoning: "R1 PASS single source_id/citation to exact GitHub strategy file; R2 PASS deterministic D1/weekly basket ranking entries/exits with defensible basket rotation cadence; R3 PASS DWX index basket testable with SP500.DWX backtest-only caveat; R4 PASS deterministic non-ML one-position rules."
---

# ThewindMom Sector Momentum

## Quelle
- Source: [[sources/github-topic-algorithmic-trading-python]]
- Topic URL: https://github.com/topics/algorithmic-trading?l=python
- Repository: https://github.com/ThewindMom/151-trading-strategies
- README: https://github.com/ThewindMom/151-trading-strategies/blob/main/README.md
- Primary file: https://github.com/ThewindMom/151-trading-strategies/blob/main/src/strategies/etfs/sector_momentum.py
- Source citation: ThewindMom/151-trading-strategies GitHub repository, Strategy 4.1 sector_momentum.py, URL https://github.com/ThewindMom/151-trading-strategies/blob/main/src/strategies/etfs/sector_momentum.py, accessed 2026.
- Author / institution: GitHub handle `ThewindMom`; repository implements non-options strategies from "151 Trading Strategies".
- Source location: `Strategy 4.1: Sector Momentum`.

## Mechanik

### Entry
- Evaluate after each completed D1 bar, with rotation execution weekly by default.
- Source defaults: `lookback = 12`, `top_n = 3`.
- For each symbol in the configured basket, compute cumulative return over the last `lookback` return observations: `prod(1 + r) - 1`.
- Rank all symbols by cumulative return descending.
- Enter/hold long only on symbols ranked in the top `top_n`.

### Exit
- Close any long when the symbol falls out of the top `top_n`.
- No short side is used; source assigns zero weight to non-top sectors.

### Stop Loss
- Source does not define a protective stop.
- P2 baseline: `2.0 * ATR(14)` hard stop from entry.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: `RISK_PERCENT = 0.25`.
- One open position per symbol/magic; basket ranking is computed read-only across the configured universe.

### Zusaetzliche Filter
- Minimum warmup: `lookback + 5` completed return observations.
- Optional P3 gate: require top symbol cumulative return > 0 to avoid forced long exposure in falling baskets.

## Concepts
- [[concepts/cross-sectional-momentum]] - source overweights the highest cumulative-return sectors.
- [[concepts/sector-rotation]] - source allocates equally across the top-ranked symbols.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Source-Link | PASS | Single source_id with public GitHub topic, repository owner, README, and exact source file URL. |
| R2 Mechanical | PASS | Fixed lookback, cumulative-return formula, ranking, and top_n allocation define deterministic entries and exits. |
| R3 DWX-testbar | PASS | Port to a DWX index basket; ranking uses close-to-close returns available from MT5 history. |
| R4 No ML | PASS | Deterministic ranking rule; no ML, online learning, grid, martingale, or multiple positions per magic. |

## R3
Primary P2 basket: GER40.DWX, NDX.DWX, WS30.DWX, SP500.DWX. SP500.DWX is backtest-only. Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Source labels the rule "Strategy 4.1: Sector Momentum".
- Source description says "Overweighting outperforming sectors via ETFs."
- Source returns `weights`, `momentum_scores`, and `top_sectors`.

## Parameters To Test
- Lookback return observations: `6`, `12`, `24`.
- Top_n: `1`, `2`, `3`.
- Optional positive-momentum gate: on/off.
- Stop: `1.5`, `2.0`, `2.5 * ATR(14)`.

## Initial Risk Profile
Cross-sectional rotation. Main risks are high correlation among index CFDs, delayed basket rebalancing, and weak live portability if only SP500.DWX survives.

## Pipeline-Verlauf
- G0: 2026-05-26, PENDING, drafted from `ThewindMom/151-trading-strategies`.

## Lessons Learned
- TBD during pipeline run.
