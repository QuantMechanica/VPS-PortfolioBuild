---
ea_id: QM5_10631
slug: et-ob-choch-retest
type: strategy
source_id: cf54ceef-f6e7-5fa0-ae03-98d3d4f8fe64
source_citation: "ninZa.co, A way to track the moves of big players, Elite Trader, 2024-06-27, https://www.elitetrader.com/et/threads/a-way-to-track-the-moves-of-big-players.380018/"
sources:
  - "[[sources/elite-trader-technical-analysis]]"
concepts:
  - "[[concepts/change-of-character]]"
  - "[[concepts/order-block]]"
  - "[[concepts/reversal]]"
indicators: []
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX, NDX.DWX]
period: M30
expected_trade_frequency: "ChoCh reversal plus imbalance plus OB retest is stricter than generic swing reversal; conservative estimate 35 trades/year/symbol."
expected_trades_per_year_per_symbol: 35
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; Elite Trader thread by ninZa.co with full URL — same source collection as 10630, each card has one source_id."
r2_mechanical: PASS
r2_reasoning: "Deterministic ChoCh rules: swing H/L trend sequence, ATR-bounded break threshold, FVG in impulse, OB 50% buy-limit, 2.0R TP or next swing, time exit."
r3_data_available: PASS
r3_reasoning: "All target symbols (EURUSD/GBPUSD/USDJPY/XAUUSD/NDX) are DWX OHLC-testable with no exchange-specific dependency."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed deterministic parameters, bounded SL, no ML/martingale/grid, one position per symbol/magic."
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 PASS linked Elite Trader source; R2 PASS deterministic ChoCh/imbalance/OB retest entries and explicit SL/TP/time exits with ~35 trades/year/symbol; R3 PASS OHLC M30 portable to DWX FX/metals/indices; R4 PASS fixed-rule no ML/grid/martingale."
---

# Elite Trader Order Block ChoCh Reversal Retest

## Quelle
- Source: [[sources/elite-trader-technical-analysis]]
- URL: https://www.elitetrader.com/et/threads/a-way-to-track-the-moves-of-big-players.380018/
- Author / institution: `ninZa.co` sponsor post.
- Date: 2024-06-27.
- Location: first post defines ChoCh as a shift in trend direction; in an uptrend, breaching a previous swing low suggests sellers gain control and price is poised for reversal. It also requires imbalance plus BoS or ChoCh for dependable order-block return signals.

## Mechanik

### Entry
- Evaluate on completed M30 bars.
- Define active trend by the last two confirmed swing highs/lows.
- Long reversal:
  - Prior trend is bearish: lower swing highs and lower swing lows.
  - ChoCh: close breaks above the previous confirmed swing high by at least `0.10 * ATR(14,M30)`.
  - The ChoCh impulse includes bullish imbalance: `low[0] > high[2]` within the impulse window.
  - Bullish reversal order block is the last bearish candle before the ChoCh impulse.
  - Place buy limit at the 50% level of the OB zone for 10 bars.
- Short reversal mirrors long from prior bullish trend after close below previous swing low and bearish imbalance.

### Exit
- TP1-equivalent single exit at `2.0R` or at the next opposing M30 swing, whichever is closer.
- Exit if price closes back through the original ChoCh level against the position.
- Time exit after 40 M30 bars.

### Stop Loss
- Long SL below OB low minus `0.20 * ATR(14,M30)`.
- Short SL above OB high plus `0.20 * ATR(14,M30)`.

### Position Sizing
- P2 baseline: fixed $1,000 risk.
- One active position per symbol/magic.

### Zusaetzliche Filter
- Skip if OB zone height > `1.4 * ATR(14,M30)`.
- Require ChoCh candle range >= `0.80 * ATR(14,M30)`.
- Do not trade if a same-direction ChoCh already triggered in the last 20 bars.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full Elite Trader URL plus institution/handle `ninZa.co`. |
| R2 Mechanical | PENDING | Source gives ChoCh, swing breach, imbalance, and OB return signal; card fixes exact swing, entry, SL, and exit rules. |
| R3 DWX-testbar | PASS | OHLC-only M30 rules are testable on DWX FX, metals, and index CFDs. |
| R4 No ML | PASS | Fixed deterministic parameters, bounded SL, no martingale/grid/ML. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX, NDX.DWX.

## Author Claims
- Source says ChoCh marks a trend-direction shift and, after a previous swing breach, sellers or buyers gain control.
- Source says imbalance plus BoS/ChoCh improves order-block return signals.

## Parameters To Test
- Swing width: 2, 3, 5.
- ChoCh break buffer: 0.05, 0.10, 0.20 ATR.
- OB entry level: 25%, 50%, 75%.
- Time exit: 24, 40, 56 M30 bars.

## Pipeline-Verlauf
- G0: PENDING.

