---
ea_id: QM5_11661
slug: pp-double-tb
type: strategy
source_id: 72f9fcfa-6c75-5544-80c4-31e15c9817ab
sources:
  - "[[sources/github-topic-algorithmic-trading-python]]"
concepts:
  - "[[concepts/chart-pattern]]"
  - "[[concepts/reversal]]"
indicators:
  - "[[indicators/ohlc-pattern]]"
period: H4
target_symbols: [EURUSD, GBPUSD, XAUUSD, GER40, NDX]
source_citation: "Keith Orange / keithorange, PatternPy, tradingpatterns/tradingpatterns.py detect_double_top_bottom, retrieved 2026-05-24 from https://github.com/keithorange/PatternPy/blob/main/tradingpatterns/tradingpatterns.py"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 20
last_updated: 2026-05-23
g0_approval_reasoning: "R1 single source_id GitHub PatternPy; R2 deterministic rolling double top/bottom entries with exits and plausible H4 cadence >=2/y/sym; R3 OHLC portable to DWX FX/metals/indices; R4 deterministic non-ML one-position."
---

# PatternPy Double Top and Bottom Reversal

## Quelle
- Source citation: Keith Orange / `keithorange`, `PatternPy`, `tradingpatterns/tradingpatterns.py`, function `detect_double_top_bottom`, retrieved 2026-05-24 from https://github.com/keithorange/PatternPy/blob/main/tradingpatterns/tradingpatterns.py
- Source: [[sources/github-topic-algorithmic-trading-python]]
- Topic URL: https://github.com/topics/algorithmic-trading?l=python
- Repository: https://github.com/keithorange/PatternPy
- README: https://github.com/keithorange/PatternPy/blob/main/README.md
- Source claim: README lists Double Top & Bottom as a recognised pattern where price retests a level and then reverses.

## Mechanik

### Entry
- Timeframe: H4 seed; P3 may test H1/H4/D1.
- Calculate rolling high max and rolling low min with `window = 3`.
- Use source `threshold = 0.05` to require the neighbouring bars' high-low range to be within 5% of their average price.
- Short entry: source detector labels `Double Top`.
- Long entry: source detector labels `Double Bottom`.
- Enter at next bar open after the completed pattern label.

### Exit
- Exit short on `Double Bottom`, or after 12 H4 bars, or if close breaks above the pattern high.
- Exit long on `Double Top`, or after 12 H4 bars, or if close breaks below the pattern low.
- Close on ATR emergency stop.

### Stop Loss
- Source has no protective stop. V5 build should seed 2.0x ATR(14) and sweep.

### Position Sizing
- V5 baseline fixed $1,000 risk per backtest trade.

### Zusaetzliche Filter
- Delay signal until the bar required by `shift(-1)` has closed to avoid lookahead.
- Closed-bar only; one position per magic.
- Target symbols: EURUSD, GBPUSD, XAUUSD, GER40, NDX.

## Concepts
- [[concepts/chart-pattern]] - source labels double tops/bottoms from rolling highs/lows plus range threshold.
- [[concepts/reversal]] - double tops are short signals; double bottoms are long signals.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Source-Link | PASS | Single GitHub source lineage with named owner, repository URL, README, topic URL, and exact source file URL. |
| R2 Mechanical | PASS | Source code supplies fixed rolling-window and threshold conditions; V5 supplies bounded exits. |
| R3 Data Available | PASS | Uses OHLC fields available on DWX FX, metals, and index CFDs. |
| R4 ML Forbidden | PASS | Deterministic non-ML rule; no learning, grid, martingale, or multi-position behavior. |

## Pipeline-Verlauf
- G0: 2026-05-24, PENDING, drafted from GitHub Python topic resume batch.

## Verwandte Strategien
- [[strategies/QM5_11657_pp-hs-rev]] - same PatternPy source, Head-and-Shoulders reversal.

## Lessons Learned
- Source threshold is percentage-like and broad; P3 should test lower tolerances if trade frequency is too high.
