---
ea_id: QM5_11659
slug: pp-triangle
type: strategy
source_id: 72f9fcfa-6c75-5544-80c4-31e15c9817ab
sources:
  - "[[sources/github-topic-algorithmic-trading-python]]"
concepts:
  - "[[concepts/chart-pattern]]"
  - "[[concepts/breakout]]"
indicators:
  - "[[indicators/ohlc-pattern]]"
period: H4
target_symbols: [EURUSD, GBPUSD, XAUUSD, GER40, NDX]
source_citation: "Keith Orange / keithorange, PatternPy, tradingpatterns/tradingpatterns.py detect_triangle_pattern, https://github.com/keithorange/PatternPy/blob/main/tradingpatterns/tradingpatterns.py"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: Single source_id links to keithorange/PatternPy GitHub repo with named author and exact file URL, satisfying one-source lineage.
r2_mechanical: PASS
r2_reasoning: Rolling high/low window with directional close conditions, time-exit, and ATR emergency stop are fully deterministic rules Codex can implement.
r3_data_available: PASS
r3_reasoning: OHLC-only pattern logic is portable to all listed DWX targets (EURUSD, GBPUSD, XAUUSD, GER40, NDX).
r4_ml_forbidden: PASS
r4_reasoning: Deterministic non-ML rule; one position per magic; no grid or martingale.
pipeline_phase: G0
expected_trades_per_year_per_symbol: 40
last_updated: 2026-05-24
card_body_incomplete: true
card_body_missing: "source_citation"
g0_approval_reasoning: "R1 single PatternPy GitHub source_id/citation; R2 deterministic H4 rolling triangle entries/exits with plausible >2 trades/year; R3 OHLC-only portable to DWX FX/metals/indices; R4 deterministic non-ML one-position rule."
---

# PatternPy Triangle Pattern Continuation

## Quelle
- Source citation: Keith Orange / `keithorange`, `PatternPy`, `tradingpatterns/tradingpatterns.py`, function `detect_triangle_pattern`, https://github.com/keithorange/PatternPy/blob/main/tradingpatterns/tradingpatterns.py
- Source URL accessed 2026-05-24: https://github.com/keithorange/PatternPy/blob/main/tradingpatterns/tradingpatterns.py
- Source: [[sources/github-topic-algorithmic-trading-python]]
- Topic URL: https://github.com/topics/algorithmic-trading?l=python
- Repository: https://github.com/keithorange/PatternPy
- README: https://github.com/keithorange/PatternPy/blob/main/README.md
- Source claim: README lists Ascending and Descending Triangles and describes the pattern as tension before directional resolution.

## Mechanik

### Entry
- Timeframe: H4 seed; P3 may test H1/H4/D1.
- Calculate rolling high max and rolling low min with `window = 3`.
- Long entry: source detector labels `Ascending Triangle` when rolling high is at/above prior high, rolling low is at/below prior low, and close rises versus prior close.
- Short entry: source detector labels `Descending Triangle` when rolling high is at/below prior high, rolling low is at/above prior low, and close falls versus prior close.
- Enter at next bar open after pattern label.

### Exit
- Exit long on `Descending Triangle`, or when close falls below the entry bar low, or after 12 H4 bars.
- Exit short on `Ascending Triangle`, or when close rises above the entry bar high, or after 12 H4 bars.
- Close on ATR emergency stop.

### Stop Loss
- Source has no stop. V5 build seeds ATR(14) emergency stop at 2.0x ATR.

### Position Sizing
- V5 baseline fixed $1,000 risk per backtest trade.

### Zusaetzliche Filter
- Closed-bar only; one position per magic.
- Target symbols: EURUSD, GBPUSD, XAUUSD, GER40, NDX.

## Concepts
- [[concepts/chart-pattern]] - source pattern labels are deterministic OHLC masks.
- [[concepts/breakout]] - ascending triangles trade long continuation; descending triangles trade short continuation.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Source-Link | PASS | Single GitHub source lineage with named owner and exact file URL. |
| R2 Mechanical | PASS | Fixed rolling-window and close-direction conditions define all entries. |
| R3 Data Available | PASS | OHLC-only; portable to DWX FX, metals, and index CFDs. |
| R4 ML Forbidden | PASS | Deterministic non-ML rule, one position per magic, no grid or martingale. |

## Pipeline-Verlauf
- G0: 2026-05-24, PENDING, drafted from GitHub Python topic resume batch.

## Verwandte Strategien
- [[strategies/QM5_11660_pp-wedge]] - same source, rolling high/low trend pattern.

## Lessons Learned
- The detector's raw labels are broad; P3 should test stricter confirmation such as close beyond the pattern bar high/low.
