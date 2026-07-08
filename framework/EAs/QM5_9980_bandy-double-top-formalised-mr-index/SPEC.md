# QM5_9980_bandy-double-top-formalised-mr-index - Strategy Spec

**EA ID:** QM5_9980
**Slug:** `bandy-double-top-formalised-mr-index`
**Source:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016`
**Author of this spec:** Codex
**Last revised:** 2026-07-08

---

## 1. Strategy Logic

This EA trades the bearish double-top chart pattern on D1 bars. It scans the most recent 60 completed bars for the two most recent confirmed 3-bar swing highs, requires those highs to be 10-50 bars apart and within 2 percent of each other, then finds the lowest low between them as the neckline. A short entry fires only after the latest completed close breaks below the neckline, the pattern height is at least 3 percent of the top price, and price is below its 200-day SMA. The stop is above the higher top with a 0.5 ATR buffer capped at 3.5 ATR from entry; the target is the measured pattern height projected down from entry, with a 20 D1-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_pivot_lookback_bars` | 3 | 1-7 | Bars on each side required to confirm a swing-high pivot. |
| `strategy_scan_bars` | 60 | 30-120 | Completed D1 bars scanned for the two most recent pivot highs. |
| `strategy_min_sep_bars` | 10 | 5-25 | Minimum spacing between the two tops. |
| `strategy_max_sep_bars` | 50 | 20-80 | Maximum spacing between the two tops. |
| `strategy_tolerance_pct` | 0.02 | 0.01-0.05 | Maximum relative difference between the two top prices. |
| `strategy_min_depth_pct` | 0.03 | 0.02-0.08 | Minimum neckline depth versus the higher top. |
| `strategy_regime_sma_period` | 200 | 100-300 | Bearish regime gate period; close must be below this SMA. |
| `strategy_atr_period` | 14 | 10-20 | ATR period used for stop buffer and cap. |
| `strategy_stop_buffer_atr` | 0.50 | 0.30-1.00 | ATR buffer above the higher top. |
| `strategy_stop_cap_atr` | 3.50 | 2.00-5.00 | Maximum stop distance from entry in ATR units. |
| `strategy_max_hold_bars` | 20 | 10-40 | D1 bars before time-stop exit. |
| `strategy_max_spread_points` | 0 | 0-10000 | Optional spread ceiling; 0 disables it to avoid DWX zero-spread false blocks. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - backtest-only US large-cap index port named in the approved card.
- `NDX.DWX` - live-routable US index proxy for the same chart-pattern substrate.
- `WS30.DWX` - live-routable US index proxy for broad equity index validation.
- `EURUSD.DWX` - liquid FX major to add instrument diversity beyond index/metal/energy sleeves.
- `GBPUSD.DWX` - liquid FX major with independent trend and reversal regimes.
- `USDJPY.DWX` - liquid FX major with different volatility and rate-sensitivity profile.
- `XAUUSD.DWX` - liquid metal CFD included by the card as a portable short-pattern venue.

**Explicitly NOT for:**
- `XNGUSD.DWX` - natural gas is not in the approved target list.
- `XTIUSD.DWX` - WTI is not in the approved target list for this card.
- `XBRUSD.DWX` - Brent is not in the approved target list for this card.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 6 |
| Typical hold time | days to a few weeks |
| Expected drawdown profile | Losses cluster in failed bearish-breakdown regimes and sharp recoveries above the pattern top. |
| Regime preference | bearish chart-pattern mean reversion / breakdown continuation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016`
**Source type:** book / approved internal extraction
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9980_bandy-double-top-formalised-mr-index.md`
**R1-R4 verdict (Q00):** all PASS per the approved card.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio, typically 0.3% - 0.5% |

ENV to mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-08 | Initial build from card | build task `d049129e-59a3-4ed1-9806-d04f8ed41233` |
