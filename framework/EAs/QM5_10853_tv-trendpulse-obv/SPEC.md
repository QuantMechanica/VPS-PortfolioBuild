# QM5_10853_tv-trendpulse-obv - Strategy Spec

**EA ID:** QM5_10853
**Slug:** `tv-trendpulse-obv`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

Long when the last closed bar crosses above the upper Trend Pulse channel band. The channel midline is a cascaded EMA of close, and the upper band is that midline plus a cascaded EMA of true range multiplied by the range factor. The breakout must also have OBV above its EMA and the close above the regime EMA. Exit when a closed bar is below the channel midline or below the regime EMA; the initial protective stop is ATR(14) times the configured multiplier.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_channel_period` | 34 | 20-50 | Cascaded EMA period for the Trend Pulse midline and filtered range. |
| `strategy_range_factor` | 2.0 | 1.5-2.5 | Multiplier applied to filtered true range for the upper channel band. |
| `strategy_regime_ema_period` | 200 | 100-200 | Broader bullish regime EMA filter. |
| `strategy_obv_ema_period` | 34 | 20-50 | EMA period applied to the tick-volume OBV line. |
| `strategy_atr_period` | 14 | fixed | ATR period for the initial stop. |
| `strategy_atr_sl_mult` | 2.0 | 1.5-2.5 | ATR multiplier for initial stop distance. |
| `strategy_max_spread_stop_frac` | 0.15 | fixed | Blocks entries when spread exceeds 15% of ATR stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - card-listed US index basket member with DWX tick-volume data.
- `WS30.DWX` - card-listed US index basket member with DWX tick-volume data.
- `GDAXI.DWX` - DWX matrix DAX custom symbol used for the card's `GER40.DWX` target.
- `XAUUSD.DWX` - card-listed liquid metal CFD with DWX tick-volume data.
- `EURUSD.DWX` - card-listed major FX symbol with DWX tick-volume data.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; mapped to `GDAXI.DWX`.
- `SP500.DWX` - mentioned only as a possible later test target, not part of the card's primary P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4`, `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `30` |
| Typical hold time | `days` |
| Expected drawdown profile | `low-to-medium cadence long-only breakout with ATR-defined loss per trade` |
| Regime preference | `trend / breakout / volume-confirmed` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** `TradingView open-source strategy`
**Pointer:** `https://www.tradingview.com/script/yyrhhzLE-Trend-Pulse-OBV/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10853_tv-trendpulse-obv.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-06 | Initial build from card | 6c1b2bc0-6df7-4c56-8593-0f11402dcc6c |
