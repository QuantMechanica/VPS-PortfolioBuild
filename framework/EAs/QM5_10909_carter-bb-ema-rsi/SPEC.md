# QM5_10909_carter-bb-ema-rsi — Strategy Spec

**EA ID:** QM5_10909
**Slug:** `carter-bb-ema-rsi`
**Source:** `6facee24-8a58-5bbf-88e9-38d44291db50` (see `strategy-seeds/sources/6facee24-8a58-5bbf-88e9-38d44291db50/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA trades the H1 Carter Bollinger middle-line breakout on EURUSD.DWX and GBPUSD.DWX. It opens long when EMA(3) crosses above the Bollinger Bands(20,3) middle line, MACD(6,17,1) crosses above zero, and RSI(14) crosses above 50 within the same three-bar signal window, with the last closed bar still confirming the long state. It opens short on the mirrored downside crosses. The take-profit is the closer of the relevant Bollinger outer band from the signal bar or 50 pips, while the stop is 5 pips beyond the nearer valid swing extreme or outer Bollinger band; an open trade exits early if EMA(3) crosses back through the Bollinger middle line.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `InpBBPeriod` | 20 | `> 0` | Bollinger Bands period. |
| `InpBBDeviation` | 3.0 | `> 0` | Bollinger Bands standard-deviation multiplier. |
| `InpEMAPeriod` | 3 | `> 0` | Fast EMA period that crosses the Bollinger middle line. |
| `InpMACDFast` | 6 | `> 0` | MACD fast EMA period. |
| `InpMACDSlow` | 17 | `> 0` | MACD slow EMA period. |
| `InpMACDSignal` | 1 | `> 0` | MACD signal period used by the MT5 MACD reader. |
| `InpRSIPeriod` | 14 | `> 0` | RSI period. |
| `InpRSIMidline` | 50.0 | `0-100` | RSI cross threshold. |
| `InpSignalWindowBars` | 3 | `> 0` | Number of closed bars in which the EMA, MACD, and RSI crosses must occur. |
| `InpTPFixedPips` | 50 | `> 0` | Fixed take-profit candidate in pips. |
| `InpSLBufferPips` | 5 | `> 0` | Stop buffer beyond the selected stop reference. |
| `InpStructLookback` | 10 | `> 0` | Lookback bars for swing high/low stop reference. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — source strategy explicitly targets EURUSD and the DWX matrix contains the symbol.
- `GBPUSD.DWX` — source strategy explicitly targets GBPUSD and the DWX matrix contains the symbol.

**Explicitly NOT for:**
- `SP500.DWX` — the card is a forex H1 strategy, not an equity-index strategy.
- `NDX.DWX` — the card is a forex H1 strategy, not an equity-index strategy.
- `WS30.DWX` — the card is a forex H1 strategy, not an equity-index strategy.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `40` |
| Typical hold time | hours to a few days |
| Expected drawdown profile | moderate trend-breakout drawdown with false-cross losses in ranging markets |
| Regime preference | breakout / trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6facee24-8a58-5bbf-88e9-38d44291db50`
**Source type:** book
**Pointer:** `G:/My Drive/QuantMechanica/Ebook/PDF resources/20 Forex Trading Strategies - Thomas Carter.pdf`, Thomas Carter, *20 Forex Trading Strategies (1 Hour Time Frame)*, 2014, Strategy #8, pages 18-19.
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10909_carter-bb-ema-rsi.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-18 | Initial build from card | a585db48-fe51-4985-92a7-9c27e29a508f |
