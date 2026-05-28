---
ea_id: QM5_1233
slug: ict-silver-bullet
type: strategy
source_id: fa90d4d7-7a46-5439-9ff6-96ee841913b3
sources:
  - "[[sources/babypips-ict-silver-bullet]]"
concepts:
  - "[[concepts/liquidity-sweep]]"
  - "[[concepts/fair-value-gap]]"
  - "[[concepts/intraday-reversal]]"
indicators:
  - "[[indicators/session-window]]"
  - "[[indicators/swing-high-low]]"
  - "[[indicators/fair-value-gap]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
expected_trades_per_year_per_symbol: 120
universe:
  - EURUSD
  - GBPUSD
  - USDJPY
  - AUDUSD
  - USDCAD
  - NZDUSD
  - XAUUSD
  - XTIUSD
  - NDX
  - WS30
  - GDAXI
  - UK100
period: M5
g0_approval_reasoning: "ICT Silver Bullet source gives a fixed 10:00-11:00 New York window, liquidity sweep, FVG entry, and target liquidity. Card converts the discretionary concepts into deterministic swing/FVG/stop/target rules for MT5; no ML or martingale."
---

# QM5_1233 ICT Silver Bullet - NY AM Liquidity Sweep

## Quelle
- Source: [[sources/babypips-ict-silver-bullet]]
- Primary URL: [source-url-redacted-for-build-check]
- Supplement: [source-url-redacted-for-build-check]
- Supplement: [source-url-redacted-for-build-check]
- The public descriptions agree on the core setup: trade only during the 10:00-11:00 New York window, wait for a liquidity sweep, then use a Fair Value Gap entry and target an opposing liquidity level.

## Mechanik

Intraday liquidity-sweep reversal / continuation setup. The EA trades one setup per symbol per New York AM window. M5 is the execution period; H1 is used only to define the reference liquidity range.

### Entry
- Time filter:
  - Convert broker time to New York time using the documented DXZ broker DST model.
  - Arm only from `10:00:00` to `10:59:59` New York time.
  - Cancel all unfilled orders at `11:00:00` New York time.
- Reference range:
  - At 10:00, record the previous completed H1 candle high and low.
  - Also record the highest high and lowest low from `09:00-09:59` New York time on M5.
  - `BuySideLiquidity = max(prev_H1_high, 09:00-09:59_high)`.
  - `SellSideLiquidity = min(prev_H1_low, 09:00-09:59_low)`.
- Short setup:
  - During 10:00-11:00, price must trade above `BuySideLiquidity` by at least `SweepBufferPoints`.
  - Within the next `MaxDisplacementBars=3` M5 bars, close must return below `BuySideLiquidity`.
  - A bearish FVG must form on M5: `High[bar+2] < Low[bar]` in the displacement leg.
  - Place a sell limit at the midpoint of the bearish FVG.
- Long setup:
  - During 10:00-11:00, price must trade below `SellSideLiquidity` by at least `SweepBufferPoints`.
  - Within the next `MaxDisplacementBars=3` M5 bars, close must return above `SellSideLiquidity`.
  - A bullish FVG must form on M5: `Low[bar+2] > High[bar]` in the displacement leg.
  - Place a buy limit at the midpoint of the bullish FVG.
- One fill per symbol per session; no pyramiding and no opposite-direction retry after a filled trade.

### Exit
- Primary target:
  - Long target is the nearest unswept M5 swing high from the `09:00-10:00` range.
  - Short target is the nearest unswept M5 swing low from the `09:00-10:00` range.
- If the opposing liquidity target gives less than `MinRewardRisk=1.5`, use fixed `TakeProfitRR=2.0`.
- Time exit: close any open position at `11:55` New York time.
- Signal invalidation: if price closes beyond the stop side before limit entry fills, cancel the order.

### Stop Loss
- Short stop: `max(sweep_high, FVG_high) + StopBufferPoints`.
- Long stop: `min(sweep_low, FVG_low) - StopBufferPoints`.
- Reject setup if stop distance is below `MinStopPoints` or above `MaxStopATR = 1.5 * ATR(14,M5)`.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.25` per symbol; one position per magic.
- Position size is derived from entry to stop distance.

### Zusatzliche Filter
- Spread filter: skip if `Spread > 2.5 * MedianSpread(20 sessions, same hour)`.
- Volatility filter: skip if current M5 ATR(14) is below `0.5 * MedianATR(20 sessions, same hour)`.
- News filter: skip high-impact USD, EUR, GBP, JPY, CAD, AUD, NZD, oil, gold, and index-related releases from `09:55-11:05` New York time.
- Session quality: skip if the 09:00-10:00 range is less than `0.35 * ATR(14,H1)`.

## Concepts
- [[concepts/liquidity-sweep]] - primary
- [[concepts/fair-value-gap]] - primary
- [[concepts/intraday-reversal]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Named public ICT Silver Bullet source and corroborating public summaries. |
| R2 Mechanical | PASS | Fixed session, objective sweep, displacement, FVG, limit, stop, target, and time exit rules. |
| R3 DWX-testbar | PASS | Uses M5/H1 OHLC plus spreads on DWX-tradeable FX, metals, oil, and index symbols. |
| R4 No ML | PASS | No ML, no adaptive model, no martingale, one trade per symbol per window. |

## R3 - T6 Live-Promotion-Caveat
Use only broker-routable DWX symbols for T6. Index symbol naming must map through the registry (`NDX.DWX`, `WS30.DWX`, `GDAXI.DWX`, `UK100.DWX`) before deployment.

## Pipeline-Verlauf
- G0: 2026-05-18 - drafted from OWNER-requested ICT Silver Bullet source, PENDING.

## Verwandte Strategien
- [[strategies/QM5_1234_ict-golden-bullet]] - same ICT mechanism in the 13:00-14:00 New York window.

## Lessons Learned (wahrend Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Anderung `pipeline_phase` aktualisieren + `last_updated`.*

