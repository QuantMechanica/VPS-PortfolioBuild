# QM5_10794_tv-atr-st — Strategy Spec

**EA ID:** QM5_10794
**Slug:** `tv-atr-st`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (TradingView "ATR SuperTrend Strategy", author `unodeitanti0`)
**Author of this spec:** Codex
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

Dual-SuperTrend trend-following EA. A fast SuperTrend (ST1) on the chart
timeframe provides the trigger; a slower SuperTrend (ST2) on a higher timeframe
provides the directional bias. Both bands are computed from the standard
ATR-based SuperTrend recursion on closed bars.

Go LONG when ST1 flips from bearish to bullish on the just-closed bar AND ST2 is
already bullish, subject to optional filters: ADX above a minimum, RSI not
overbought, price within a maximum ATR-distance of the ST1 line, and an optional
EMA directional filter. SHORT is the mirror (ST1 flips bearish, ST2 bearish, RSI
not oversold). Only one position per symbol/magic.

Exit at the ATR initial stop (ATR(14)×2.0 from entry), a fixed R-multiple take
profit (default 2.0R), an optional breakeven shift at +1R, or an opposite ST1
flip. Friday-close flat is handled by the framework.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `st1_atr_period` | 10 | 5-30 | ST1 (trigger) ATR period |
| `st1_atr_mult` | 2.0 | 1.0-5.0 | ST1 ATR multiplier |
| `st2_timeframe` | PERIOD_H4 | H1/H4 | ST2 confirmation timeframe |
| `st2_atr_period` | 10 | 5-30 | ST2 (confirmation) ATR period |
| `st2_atr_mult` | 3.0 | 1.0-5.0 | ST2 ATR multiplier |
| `sl_atr_period` | 14 | 5-30 | Initial-stop ATR period |
| `sl_atr_mult` | 2.0 | 1.0-5.0 | Initial-stop ATR multiplier |
| `tp_r_mult` | 2.0 | 1.0-5.0 | Take-profit as R multiple of stop |
| `be_enabled` | false | bool | Move SL to breakeven after +be_r_mult R |
| `be_r_mult` | 1.0 | 0.5-3.0 | Breakeven trigger in R |
| `adx_min` | 0.0 | 0-40 | ADX minimum (0 = off) |
| `adx_period` | 14 | 5-30 | ADX period |
| `rsi_period` | 14 | 5-30 | RSI period |
| `rsi_overbought` | 70.0 | 50-100 | Block LONG if RSI ≥ this |
| `rsi_oversold` | 30.0 | 0-50 | Block SHORT if RSI ≤ this |
| `max_dist_atr` | 0.0 | 0-5 | Max distance from ST1 line in ATR units (0 = off) |
| `use_ema_filter` | false | bool | Require price above/below EMA |
| `ema_filter_period` | 200 | 20-400 | EMA filter period |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep-liquidity FX major, clean SuperTrend trends.
- `GBPUSD.DWX` — volatile FX major, frequent trend impulses.
- `USDJPY.DWX` — trending FX major.
- `XAUUSD.DWX` — gold; strong persistent trends suit dual-ST. (card said `XAUUSD`; ported to canonical `XAUUSD.DWX`)
- `GDAXI.DWX` — DAX 40; card said `GER40.DWX` which is not in the matrix, ported to the canonical DAX custom symbol `GDAXI.DWX`.
- `NDX.DWX` — Nasdaq 100; live-tradable index, strong trends.
- `WS30.DWX` — Dow 30; live-tradable index.

**Explicitly NOT for:**
- `SP500.DWX` — backtest-only (not broker-routable); not registered for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | ST2 SuperTrend on `H4` (default), advanced on its own new-bar cadence |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~80` |
| Typical hold time | `hours to a few days` |
| Expected drawdown profile | `trend-following: choppy-market chop, recovered by trend legs` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `low/medium (asymmetric R payoff)` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** `forum` (TradingView protected-source script)
**Pointer:** `https://www.tradingview.com/script/rkC2DHrJ/` (author `unodeitanti0`)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10794_tv-atr-st.md`

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
| v1 | 2026-06-05 | Initial build from card | a7ba8012-3cef-4319-bfc9-43a1ffb4f440 |
