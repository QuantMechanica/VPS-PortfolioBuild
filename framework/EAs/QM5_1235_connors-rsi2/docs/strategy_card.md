---
ea_id: QM5_1235
slug: connors-rsi2
type: strategy
source_id: manual-owner-request-connors-rsi2
sources:
  - "[[sources/connors-short-term-trading-strategies]]"
concepts:
  - "[[concepts/short-term-mean-reversion]]"
  - "[[concepts/rsi2]]"
  - "[[concepts/buy-the-dip]]"
indicators:
  - "[[indicators/rsi2]]"
  - "[[indicators/sma200]]"
  - "[[indicators/sma5]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
expected_trades_per_year_per_symbol: 35
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
period: D1
g0_approval_reasoning: "Connors RSI-2 is a widely published short-term mean-reversion rule set: trade D1 pullbacks in an uptrend using RSI(2), exit on short moving-average recovery. Deterministic, multi-asset testable, no ML."
---

# QM5_1235 Connors RSI-2 Mean Reversion

## Quelle
- Source: [[sources/connors-short-term-trading-strategies]]
- Primary reference: Larry Connors and Cesar Alvarez, "Short Term Trading Strategies That Work" / RSI(2) strategy family.
- Public implementation reference: https://stratbase.ai/en/blog/rsi-2-strategy-larry-connors
- The common rule family buys short-term oversold closes when price is above a long-term moving average and exits when the short-term bounce has normalised.

## Mechanik

D1 close-to-close mean-reversion strategy. Buy sharp pullbacks inside a long-term uptrend; optionally short overbought rallies inside a long-term downtrend for FX/CFD symmetry. Default P2 should test long-only first on indices/metals and long+short on FX/commodities.

### Entry
- Long setup on D1 close:
  - `Close > SMA(200)`.
  - `RSI(2) < EntryRSI_Long`, default `EntryRSI_Long=10`.
  - No open position for this symbol/magic.
  - Enter long at next D1 open.
- Short setup on D1 close, optional parameter `EnableShorts=true`:
  - `Close < SMA(200)`.
  - `RSI(2) > EntryRSI_Short`, default `EntryRSI_Short=90`.
  - No open position for this symbol/magic.
  - Enter short at next D1 open.
- If multiple symbols signal simultaneously, each symbol is independent; no cross-symbol ranking in the baseline card.

### Exit
- Long exit:
  - Exit at next D1 open after `Close > SMA(5)`.
  - Also exit if `RSI(2) > ExitRSI_Long`, default `ExitRSI_Long=70`.
- Short exit:
  - Exit at next D1 open after `Close < SMA(5)`.
  - Also exit if `RSI(2) < ExitRSI_Short`, default `ExitRSI_Short=30`.
- Time stop: exit after `MaxHoldBars=10` D1 bars if neither mean-reversion exit has triggered.

### Stop Loss
- Protective stop at `StopATR = 3.0 * ATR(14,D1)` from entry.
- Optional disaster stop at `MaxLossR = 1.5` of planned risk.
- No trailing stop in baseline; exits are signal/time based.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade using ATR stop distance.
- Live: `RISK_PERCENT = 0.25` per symbol.
- One position per symbol/magic; no averaging down, no martingale, no pyramiding.

### Zusatzliche Filter
- Minimum history: require `220` D1 bars before trading.
- Spread filter: skip entry if spread exceeds `2.0 * MedianSpread(60D, entry hour)`.
- Trend-quality filter: optional `SMA(200) slope over 20 bars > 0` for longs and `< 0` for shorts; default off for the first baseline test.
- News filter: for FX/metals/oil, skip entries on high-impact event days for the quote/base currency or commodity driver; indices skip central-bank decision days.

## Concepts
- [[concepts/short-term-mean-reversion]] - primary
- [[concepts/rsi2]] - primary
- [[concepts/buy-the-dip]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Connors/Alvarez RSI(2) rule family is widely published and easy to cite; public implementation references match the core SMA200 + RSI2 pullback structure. |
| R2 Mechanical | PASS | Fixed D1 indicators, threshold entries, moving-average/RSI/time exits, ATR stop, and fixed risk sizing. |
| R3 DWX-testbar | PASS | D1 OHLC data and RSI/SMA/ATR are available for all listed DWX symbols. |
| R4 No ML | PASS | No ML, no optimisation dependency, no portfolio optimiser, no martingale. |

## R3 - T6 Live-Promotion-Caveat
Baseline is multi-asset, but T6 approval should distinguish long-only index behavior from symmetric FX/commodity behavior. Do not promote the optional short side unless P phases validate it separately.

## Pipeline-Verlauf
- G0: 2026-05-18 - drafted from OWNER-requested Connors RSI-2 pickup, PENDING.

## Verwandte Strategien
- [[strategies/QM5_1139_qp-sp500-rsi35-rebound]] - broader RSI rebound cousin.

## Lessons Learned (wahrend Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Anderung `pipeline_phase` aktualisieren + `last_updated`.*
