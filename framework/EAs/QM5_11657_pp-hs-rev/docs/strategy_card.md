---
ea_id: QM5_11657
slug: pp-hs-rev
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
source_citation: "Keith Orange / keithorange, PatternPy, tradingpatterns/tradingpatterns.py detect_head_shoulder, https://github.com/keithorange/PatternPy/blob/main/tradingpatterns/tradingpatterns.py"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 24
last_updated: 2026-05-24
g0_approval_reasoning: "R1 PASS single PatternPy source_id/link; R2 PASS deterministic H4 head-and-shoulders entries/exits with plausible >=2 trades/year/symbol; R3 PASS OHLC-only portable to DWX FX/metals/indices; R4 PASS deterministic no ML/martingale/multi-position."
---

# PatternPy Head-and-Shoulders Reversal

## Quelle
- Source citation: 2026 URL, Keith Orange / `keithorange`, `PatternPy`, `tradingpatterns/tradingpatterns.py`, function `detect_head_shoulder`, https://github.com/keithorange/PatternPy/blob/main/tradingpatterns/tradingpatterns.py
- Source: [[sources/github-topic-algorithmic-trading-python]]
- Topic URL: https://github.com/topics/algorithmic-trading?l=python
- Repository: https://github.com/keithorange/PatternPy
- README: https://github.com/keithorange/PatternPy/blob/main/README.md
- Source claim: PatternPy identifies Head & Shoulders and inverse Head & Shoulders patterns from OHLCV data and creates a `head_shoulder_pattern` column.

## Mechanik

### Entry
- Timeframe: H4 seed; P3 may test H1/H4/D1.
- Calculate rolling `High` maximum and rolling `Low` minimum with `window = 3`.
- Short entry: source detector labels `Head and Shoulder`.
- Long entry: source detector labels `Inverse Head and Shoulder`.
- Enter at the next bar open after the completed pattern label.
- One open position per magic; ignore same-direction labels while in position.

### Exit
- Exit short on an `Inverse Head and Shoulder` label, or after 12 H4 bars, whichever comes first.
- Exit long on a `Head and Shoulder` label, or after 12 H4 bars, whichever comes first.
- Close immediately on ATR emergency stop.

### Stop Loss
- Source is a detector library and does not define stops. V5 build should add ATR(14) emergency stop, seed 2.0x ATR, and sweep in P3.

### Position Sizing
- V5 baseline: fixed $1,000 risk per trade in backtest; live default RISK_PERCENT after approval.

### Zusaetzliche Filter
- Require the pattern label to be based on closed bars only.
- Do not use the future-looking `shift(-1)` part until that next bar has closed; implementation must delay signal one bar to avoid lookahead.
- Target symbols: EURUSD, GBPUSD, XAUUSD, GER40, NDX. The rule uses OHLC only.

## Concepts
- [[concepts/chart-pattern]] - rolling local high/low relationships create a named chart pattern signal.
- [[concepts/reversal]] - Head & Shoulders is bearish; inverse Head & Shoulders is bullish.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Source-Link | PASS | Single GitHub source lineage with topic URL, repository URL, named owner, README, and exact source file URL. |
| R2 Mechanical | PASS | Fixed rolling-window OHLC conditions create deterministic labels; V5 supplies bounded exits/stops. |
| R3 Data Available | PASS | Uses High/Low/Close/Open data available on DWX FX, metals, and index CFDs. |
| R4 ML Forbidden | PASS | No ML, online learning, adaptive PnL parameters, grid, martingale, or multi-position behavior. |

## Pipeline-Verlauf
- G0: 2026-05-24, PENDING, drafted from GitHub Python topic resume batch.

## Verwandte Strategien
- [[strategies/QM5_11661_pp-double-tb]] - same PatternPy source, double-top/bottom reversal detector.

## Lessons Learned
- PatternPy detector code uses `shift(-1)` for pattern confirmation; EA implementation must confirm on the following closed bar.
