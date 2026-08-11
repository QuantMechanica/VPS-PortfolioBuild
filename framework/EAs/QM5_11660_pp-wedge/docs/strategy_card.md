---
ea_id: QM5_11660
slug: pp-wedge
type: strategy
source_id: 72f9fcfa-6c75-5544-80c4-31e15c9817ab
sources:
  - "[[sources/github-topic-algorithmic-trading-python]]"
concepts:
  - "[[concepts/chart-pattern]]"
  - "[[concepts/trend-following]]"
indicators:
  - "[[indicators/ohlc-pattern]]"
period: H4
target_symbols: [EURUSD, GBPUSD, XAUUSD, GER40, NDX]
source_citation: "Keith Orange / keithorange, PatternPy, tradingpatterns/tradingpatterns.py detect_wedge, https://github.com/keithorange/PatternPy/blob/main/tradingpatterns/tradingpatterns.py"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 32
last_updated: 2026-05-24
g0_approval_reasoning: "R1 single PatternPy GitHub source_id/citation; R2 deterministic H4 rolling wedge entries/exits with plausible >2 trades/year; R3 OHLC-only portable to DWX FX/metals/indices; R4 deterministic non-ML one-position rule."
---

# PatternPy Wedge Directional Pattern

## Quelle

- Source citation: Keith Orange / `keithorange`, `PatternPy`, `tradingpatterns/tradingpatterns.py`, function `detect_wedge`, https://github.com/keithorange/PatternPy/blob/main/tradingpatterns/tradingpatterns.py
- Source URL accessed 2026-05-24: https://github.com/keithorange/PatternPy/blob/main/tradingpatterns/tradingpatterns.py
- Source: [[sources/github-topic-algorithmic-trading-python]]
- Topic URL: https://github.com/topics/algorithmic-trading?l=python
- Repository: https://github.com/keithorange/PatternPy
- README: https://github.com/keithorange/PatternPy/blob/main/README.md
- Source claim: README lists Wedges as converging trendline patterns where price can move directionally after resolution.

## Mechanik

### Entry

- Timeframe: H4 seed; P3 may test H1/H4/D1.
- Calculate rolling high max, rolling low min, rolling high trend, and rolling low trend with `window = 3`.
- Long entry: source detector labels `Wedge Up` where rolling high/low envelope is rising and both rolling high and low trends are positive.
- Short entry: source detector labels `Wedge Down` where rolling high/low envelope is falling and both rolling high and low trends are negative.
- Enter at next bar open after the completed label.

### Exit

- Exit long on `Wedge Down`, close below prior bar low, or 12 H4 bars in trade.
- Exit short on `Wedge Up`, close above prior bar high, or 12 H4 bars in trade.
- Close on ATR emergency stop.

### Stop Loss

- Source has no stop. V5 build should seed 2.0x ATR(14) emergency stop and sweep.

### Position Sizing

- V5 baseline fixed $1,000 risk per backtest trade.

### Zusaetzliche Filter

- Closed bars only.
- One position per magic.
- Target symbols: EURUSD, GBPUSD, XAUUSD, GER40, NDX.

## Concepts

- [[concepts/chart-pattern]] - wedge labels come from rolling high/low and slope-style trend tests.
- [[concepts/trend-following]] - trade in the direction of the wedge label's high/low trend.

## R1-R4 Bewertung

| Kriterium | Status | Begruendung |
|---|---|---|
| R1 Source-Link | PASS | Single GitHub source, named owner, repository README, topic URL, and exact source file URL. |
| R2 Mechanical | PASS | Source code defines deterministic masks using rolling highs/lows and trend signs. |
| R3 Data Available | PASS | Uses only OHLC fields available on DWX instruments. |
| R4 ML Forbidden | PASS | Fixed non-ML arithmetic detector; no online learning, grid, martingale, or multi-position behavior. |

## Pipeline-Verlauf

- G0: 2026-05-24, PENDING, drafted from GitHub Python topic resume batch.

## Verwandte Strategien

- [[strategies/QM5_11659_pp-triangle]] - same PatternPy source, triangle detector.

## Lessons Learned

- Wedge labels may be frequent with `window=3`; P3 should include window 5/8 variants if G0 approves.
