---
ea_id: QM5_11411
slug: wilder-parabolic-sar-reversal-d1
type: strategy
source_id: 0ab0a479-4a09-5ecc-bb90-6a37148fa78b
sources:
  - "[[sources/wilder-new-concepts-technical-trading-systems]]"
concepts:
  - "[[concepts/parabolic-sar]]"
  - "[[concepts/stop-and-reverse]]"
  - "[[concepts/trend-following]]"
  - "[[concepts/acceleration-factor]]"
indicators:
  - "[[indicators/psar]]"
  - "[[indicators/adx]]"
period: D1
source_citation: "J. Welles Wilder Jr., New Concepts in Technical Trading Systems (Trend Research, 1978), Section II: Parabolic Time/Price System, local PDF: C:\\Users\\Administrator\\Dropbox\\Finanzen\\Forex\\###  Forex to read\\53093880-Welles-Wilder-New-Concepts-in-Technical-Trading-Systems.pdf"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-23
expected_trades_per_year_per_symbol: 30
g0_approval_reasoning: "R1 single Wilder source_id/local PDF; R2 mechanical PSAR stop-and-reverse with plausible multi-flip annual cadence >2 trades/year/symbol; R3 DWX FX D1 testable; R4 deterministic no ML and one active position."
---

# QM5_11411 Wilder — Parabolic SAR Reversal (D1)

## Quelle
- Source: "New Concepts in Technical Trading Systems" by J. Welles Wilder Jr. (1978), Section II
- Source citation: 1978 URL/local PDF record: J. Welles Wilder Jr., "New Concepts in Technical Trading Systems"; local PDF listed below.
- File: `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\53093880-Welles-Wilder-New-Concepts-in-Technical-Trading-Systems.pdf`
- R1: PASS — J. Welles Wilder Jr., creator of RSI, ATR, ADX, PSAR.

## Mechanik

**Concept**: Always-in-market stop-and-reverse system. The SAR accelerates as price moves favorably — starting slowly and accelerating as the trade matures. When price crosses the SAR, exit the current trade and enter in the opposite direction.

### Parabolic SAR Formula
```
SAR_tomorrow = SAR_today + AF × (EP − SAR_today)
```
- **AF (Acceleration Factor)**: Start = 0.02; increment += 0.02 each day a new EP is made; max = 0.20.
- **EP (Extreme Price)**: Highest High reached while in Long; Lowest Low reached while in Short.
- **Constraint**: SAR cannot fall within today's or yesterday's price range.
  - Long trade: if calculated SAR > today's Low or yesterday's Low → use the lower of the two lows.
  - Short trade: if calculated SAR < today's High or yesterday's High → use the higher of the two highs.
- Initial SAR on entry = previous SIP (Significant Point = most recent opposite-direction swing high/low).

### Entry

**LONG** (PSAR flips bullish):
1. SAR was above price (short trade active) on previous bar.
2. Today: `SAR[i] < Low[i]` (SAR has moved below price → reversal confirmed).
3. Enter BUY at open of bar i+1 (next bar open).
4. Initial SL = SAR value at entry (accelerating upward each day price makes new lows in a short trade).

**SHORT** (PSAR flips bearish):
1. SAR was below price (long trade active) on previous bar.
2. Today: `SAR[i] > High[i]` (SAR above price → reversal).
3. Enter SELL at open of bar i+1.

**MT5 implementation**: Use `iSAR(NULL, PERIOD_D1, 0.02, 0.20, i)`. A flip is detected when `iSAR(0,0,1) < Close[1]` (SAR below price yesterday) AND `iSAR(0,0,0)` is now above price; or vice versa. The native MT5 iSAR already implements the full formula.

### Exit
- **Reversal**: Exit and reverse when SAR crosses price in opposite direction.
- **ADX filter (optional)**: If `+DI14 > −DI14`, take Long trades only; if `−DI14 > +DI14`, Short only. Skip trades in the wrong direction when using the filter.

### Stop Loss
- Initial SL = SAR value at entry.
- Trailing: the SAR itself acts as the trailing stop (it advances each bar).
- P2 cap: 100 pips (D1 bars).

### Position Sizing
- `RISK_FIXED = $1000` for P2.
- `RISK_PERCENT = 0.5%` for live.

### Zusätzliche Filter
- Timeframe: D1
- Instruments: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX
- Spread cap: 25 pips
- Always-in-market: no idle period; always either long or short

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | J. Welles Wilder Jr., pioneer quantitative analyst, named author. |
| R2 Mechanical | PASS | SAR formula fully arithmetic; MT5 native iSAR implements it exactly. Flip detection is a price comparison. |
| R3 Data Available | PASS | D1 DWX FX; iSAR is MT5-native. |
| R4 No ML | PASS | Fixed AF parameters. |

G0 APPROVE eligible.

## Pipeline-Verlauf
- G0: 2026-05-23 — drafted from Wilder New Concepts, Section II

## Implementation Notes for Codex (P1)
- `sar_val = iSAR(NULL, PERIOD_D1, 0.02, 0.20, i)` — returns the SAR for bar i
- Long flip: `sar_val[1] > Close[1]` (SAR above price = short) AND `sar_val[0] < Close[0]` (SAR below price = flipped long)
- Short flip: mirror
- Always-in-market: close existing position on flip bar, open new in opposite direction
- P3 sweeps: AF_step (0.01/0.02/0.03), AF_max (0.15/0.20/0.25), with/without ADX filter

## Verwandte Strategien
- Related: QM5_11412 (wilder-volatility-system-atr-sar-d1) — same always-in-market concept, ATR-based stop instead of parabolic
- Related: QM5_11413 (wilder-directional-movement-di14-cross-d1) — Wilder DI cross; +DI/−DI used as optional filter here

## Lessons Learned
- *(populated as pipeline progresses)*
