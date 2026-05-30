---
ea_id: QM5_10465
slug: mql5-rsi-cloud
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/oscillator-reversal]]"
indicators:
  - "[[indicators/rsi]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 70
last_updated: 2026-05-21
g0_approval_reasoning: "R1 source URL/title present; R2 deterministic RSI cloud zone-exit entries and opposite-signal exits with ATR SL/2R TP, cadence 70 trades/year/symbol; R3 OHLC indicator testable on DWX symbols; R4 no ML/grid/martingale and one-position-per-magic."
---

# MQL5 RSI Dual Cloud Zone Reversal

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- Page / Timestamp: MQL5 CodeBase, "RSI Dual Cloud EA - expert for MetaTrader 5", author Vladimir Karputov, published 2022-05-26, https://www.mql5.com/en/code/39497

## Mechanik

### Entry
- Baseline symbols: liquid DWX FX majors, XAUUSD.DWX, and index CFDs.
- Timeframe: H1 baseline; M30/H4 variants can be swept.
- The source defines RSI Dual Cloud zones from fast and slow RSI lines.
- Long setup:
  - Fast/slow RSI cloud forms below the configured DOWN level.
  - The selected signal mode is "leaving the zone" on a closed bar.
  - Enter long at market on the next bar.
- Short setup:
  - Fast/slow RSI cloud forms above the configured UP level.
  - The selected signal mode is "leaving the zone" on a closed bar.
  - Enter short at market on the next bar.

### Exit
- Close on opposite qualifying RSI-cloud signal.
- Fixed protective TP = 2R.

### Stop Loss
- Source supports fixed point SL/TP and profitable-position trailing.
- V5 baseline: fixed SL = 1.5 x ATR(14), no trailing.

### Position Sizing
- V5 baseline: fixed-risk $1,000 per backtest trade.
- Live sizing deferred to V5 risk conventions.

### Zusätzliche Filter
- Use source "Positions: Only one" behavior; V5 enforces one-position-per-magic.
- Disable multiple simultaneous positions and minimum-step stacking.
- V5 default spread guard.

## Concepts (was ist das für eine Strategie)
- [[concepts/mean-reversion]] - primary
- [[concepts/oscillator-reversal]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Verifiable MQL5 CodeBase page with title, named author, publish date, and URL. |
| R2 Mechanical | PASS | Source defines RSI zone states, four signal types, SL/TP, trade direction controls, and one-position mode; baseline fixes one signal type. |
| R3 Data Available | PASS | RSI uses OHLC close history available on DWX symbols. |
| R4 ML Forbidden | PASS | No ML or online adaptation; multi-position source options are disabled for V5. |

## Pipeline-Verlauf
- G0: Pending batch review.

## Verwandte Strategien
- [[strategies/QM5_10462_mql5-wpr-cloud]] - prior oscillator cloud/zone reversal card.

## Lessons Learned (während Pipeline-Lauf)
- TBD

---

*Research note: expected cadence is conservative for H1 RSI zone exits across liquid DWX symbols.*

