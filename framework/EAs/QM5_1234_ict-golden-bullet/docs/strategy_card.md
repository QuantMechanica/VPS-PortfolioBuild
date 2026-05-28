---
ea_id: QM5_1234
slug: ict-golden-bullet
type: strategy
source_id: fa90d4d7-7a46-5439-9ff6-96ee841913b3
sources:
  - "[[sources/babypips-ict-silver-bullet]]"
concepts:
  - "[[concepts/liquidity-sweep]]"
  - "[[concepts/fair-value-gap]]"
  - "[[concepts/ny-pm-session]]"
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
expected_trades_per_year_per_symbol: 100
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
g0_approval_reasoning: "ICT Golden Bullet is the same liquidity-sweep/FVG playbook shifted to the 13:00-14:00 New York afternoon window. Rules are deterministic and MT5-testable across the DWX multi-asset universe; no ML or martingale."
---

# QM5_1234 ICT Golden Bullet - NY PM Liquidity Sweep

## Quelle
- Source: [[sources/babypips-ict-silver-bullet]]
- Primary URL: https://www.babypips.com/learn/forex/ict-silver-bullet
- Supplement: https://www.fluxcharts.com/articles/trading-strategies/ict-strategies/ict-silver-bullet
- Supplement: https://fairvaluehub.de/en/blog/ict-silver-bullet-en
- Public ICT summaries describe the Bullet family as fixed New York session windows built around liquidity sweeps, displacement, Fair Value Gaps, and liquidity targets. This card isolates the 13:00-14:00 New York PM variant for independent testing.

## Mechanik

Afternoon session variant of the ICT Bullet model. It is separated from the 10:00 Silver Bullet because the volatility regime, spreads, and session participants differ after the New York lunch period.

### Entry
- Time filter:
  - Convert broker time to New York time using the documented DXZ broker DST model.
  - Arm only from `13:00:00` to `13:59:59` New York time.
  - Cancel all unfilled orders at `14:00:00` New York time.
- Reference range:
  - At 13:00, record the previous completed H1 candle high and low.
  - Also record the highest high and lowest low from `12:00-12:59` New York time on M5.
  - `BuySideLiquidity = max(prev_H1_high, 12:00-12:59_high)`.
  - `SellSideLiquidity = min(prev_H1_low, 12:00-12:59_low)`.
- Short setup:
  - During 13:00-14:00, price must trade above `BuySideLiquidity` by at least `SweepBufferPoints`.
  - Within the next `MaxDisplacementBars=3` M5 bars, close must return below `BuySideLiquidity`.
  - A bearish FVG must form on M5: `High[bar+2] < Low[bar]` in the displacement leg.
  - Place a sell limit at the midpoint of the bearish FVG.
- Long setup:
  - During 13:00-14:00, price must trade below `SellSideLiquidity` by at least `SweepBufferPoints`.
  - Within the next `MaxDisplacementBars=3` M5 bars, close must return above `SellSideLiquidity`.
  - A bullish FVG must form on M5: `Low[bar+2] > High[bar]` in the displacement leg.
  - Place a buy limit at the midpoint of the bullish FVG.
- One setup attempt per direction; after one order is placed, no new setup for that symbol that day.

### Exit
- Primary target:
  - Long target is the nearest unswept M5 swing high from `12:00-13:00`.
  - Short target is the nearest unswept M5 swing low from `12:00-13:00`.
- If target reward is below `MinRewardRisk=1.5`, use fixed `TakeProfitRR=2.0`.
- Time exit: close any open position at `14:55` New York time.
- Cancel pending order if price closes beyond the stop side before fill.

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
- News filter: skip high-impact releases from `12:55-14:05` New York time.
- Session quality: skip if `12:00-13:00` range is less than `0.30 * ATR(14,H1)`.

## Concepts
- [[concepts/liquidity-sweep]] - primary
- [[concepts/fair-value-gap]] - primary
- [[concepts/ny-pm-session]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Uses the OWNER-requested ICT Bullet source plus public corroborating summaries of the session-window/FVG mechanism. |
| R2 Mechanical | PASS | Fixed session, objective sweep, displacement, FVG, limit, stop, target, and time exit rules. |
| R3 DWX-testbar | PASS | Uses M5/H1 OHLC plus spreads on DWX-tradeable FX, metals, oil, and index symbols. |
| R4 No ML | PASS | No ML, no adaptive model, no martingale, one trade per symbol per window. |

## R3 - T6 Live-Promotion-Caveat
Use only broker-routable DWX symbols for T6. Afternoon index liquidity differs by symbol; T6 promotion requires symbol-specific spread/slippage evidence from P phases.

## Pipeline-Verlauf
- G0: 2026-05-18 - drafted from OWNER-requested ICT Bullet source, PENDING.

## Verwandte Strategien
- [[strategies/QM5_1233_ict-silver-bullet]] - same rules in the 10:00-11:00 New York window.

## Lessons Learned (wahrend Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Anderung `pipeline_phase` aktualisieren + `last_updated`.*
