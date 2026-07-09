---
ea_id: QM5_9639
slug: ehlers-highpass-raw-h4
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
source_citation: "John Ehlers indicator discussion, ForexFactory John Ehlers Indicators, https://www.forexfactory.com/thread/post/15555134"
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/digital-filter]]"
  - "[[concepts/cycle-turning-point]]"
  - "[[concepts/ehlers-indicators]]"
indicators:
  - "[[indicators/ehlers-high-pass-filter]]"
  - "[[indicators/ema]]"
  - "[[indicators/atr]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
period: H4
expected_trade_frequency: "Medium; raw high-pass zero-crosses gated by EMA trend should produce roughly 35-80 trades/year/symbol."
expected_trades_per_year_per_symbol: 55
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id UUID present; ForexFactory Ehlers indicator thread URL with named mrtools community port lineage — one canonical source."
r2_mechanical: PASS
r2_reasoning: "Closed-form fixed-coefficient high-pass filter recurrence, EMA trend gate, ATR-bounded entry, swing-low SL, 1.7R TP, and time stop are all explicit."
r3_data_available: PASS
r3_reasoning: "H4 OHLC-derived median price, EMA, and ATR directly testable on DWX FX and XAUUSD."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed digital-filter coefficients and EMA period; no online learning or PnL-adaptive parameters; one position per magic-symbol; no martingale."
pipeline_phase: G0
last_updated: 2026-05-19
card_body_incomplete: true
card_body_missing: "source_citation"
g0_approval_reasoning: "R1 cites ForexFactory/Ehlers source URL; R2 has deterministic HP zero-cross entries, opposite-cross/TP/time exits and ATR swing stops with ~55 trades/year/symbol; R3 tests on DWX FX/XAU basket; R4 fixed rules, no ML or martingale."
---

# Ehlers Raw High-Pass Filter H4

## Quelle
- Source: [[sources/forexfactory-trading-systems]]
- Thread: "John Ehlers Indicators".
- Author / institution: John F. Ehlers digital-filter lineage; ForexFactory community ports by `mrtools` and related handles.
- URL (accessed 2026-05-19): https://www.forexfactory.com/thread/post/15555134

## Mechanik

### Entry
- Use completed H4 bars.
- Compute Ehlers high-pass filter on median price with fixed period `HPPeriod = 48`:
  - `alpha = (cos(0.707 * 2*pi / HPPeriod) + sin(0.707 * 2*pi / HPPeriod) - 1) / cos(0.707 * 2*pi / HPPeriod)`;
  - `HP[t] = (1 - alpha/2)^2 * (Price[t] - 2*Price[t+1] + Price[t+2]) + 2*(1-alpha)*HP[t+1] - (1-alpha)^2*HP[t+2]`.
- Long entry:
  - `HP` crosses up through zero on the last closed bar;
  - close is above EMA(100,H4);
  - `abs(HP[t]) <= 1.2 * ATR(14,H4)` to avoid late impulse entries.
- Short entry mirrors below zero and below EMA(100,H4).

### Exit
- Exit on opposite HP zero-cross.
- Primary TP: 1.7R.
- Time stop: 14 H4 bars.

### Stop Loss
- Long SL below the most recent 5-bar swing low minus `0.20 * ATR(14,H4)`.
- Short SL above the most recent 5-bar swing high plus `0.20 * ATR(14,H4)`.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default `RISK_PERCENT` after approval.

### Zusaetzliche Filter
- Do not stack with Roofing Filter logic; this card uses the raw high-pass output directly.
- One active position per magic-symbol.
- Standard QM spread/news/Friday-close filters.

## Concepts
- [[concepts/digital-filter]] - primary
- [[concepts/cycle-turning-point]] - secondary
- [[concepts/ehlers-indicators]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full ForexFactory Ehlers indicator URL plus named Ehlers publication lineage. |
| R2 Mechanical | PASS | Closed-form fixed-coefficient high-pass recurrence, EMA gate, stop, TP and exit are explicit. |
| R3 DWX-testbar | PASS | Uses OHLC-derived median price, EMA and ATR on DWX symbols. |
| R4 No ML | PASS | Fixed digital-filter coefficients; no online learning or adaptive parameters. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX. Not SP500-specific.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_1517_ehlers-roofing-filter-h4]] - high-pass plus low-pass roofing cascade; this card uses raw high-pass zero-cross only.
- [[strategies/QM5_1308_fisher-transform-zerocross-h1]] - rejected Fisher transform; this card avoids Fisher and uses linear digital filtering.
