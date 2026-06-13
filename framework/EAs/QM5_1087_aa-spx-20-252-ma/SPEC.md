# QM5_1087_aa-spx-20-252-ma - Strategy Spec

**EA ID:** QM5_1087
**Slug:** aa-spx-20-252-ma
**Source:** ede348b4-0fa7-5be1-baa8-09e9089b67b7
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA evaluates the close of each D1 bar. It computes the 20-day simple moving average of closes and the 252-day simple moving average of closes. When SMA(20) is above SMA(252), the EA holds one long position; when SMA(20) is below or equal to SMA(252), it closes the long position and remains flat. The card does not define a signal stop, so entries use the V5 ATR stop for risk sizing and account-level risk controls.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_fast_sma_days | 20 | 1-252 | Fast daily SMA period used for the risk-on side of the rule. |
| strategy_slow_sma_days | 252 | 20-500 | Slow daily SMA period used for the risk-off comparison. |
| strategy_min_daily_bars | 252 | 252-500 | Minimum daily warmup period before signals are allowed. |
| strategy_atr_period | 14 | 1-100 | D1 ATR period for the default stop distance. |
| strategy_atr_sl_mult | 1.5 | 0.1-10.0 | ATR multiple used for the default stop loss. |
| strategy_max_spread_points | 0 | 0-100000 | Optional spread block; 0 disables the spread cap. |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - Original S&P 500 rule, available as a backtest-only custom symbol.
- NDX.DWX - Liquid US large-cap index port.
- WS30.DWX - Liquid US large-cap index port.
- GDAXI.DWX - Liquid European index port for global index saturation.
- XAUUSD.DWX - Liquid commodity CFD port named in the card's R3 basket.
- XTIUSD.DWX - Liquid commodity CFD port named in the card's R3 basket.
- EURUSD.DWX - Liquid FX major port from the card's R3 major-FX wording.
- GBPUSD.DWX - Liquid FX major port from the card's R3 major-FX wording.
- AUDUSD.DWX - Liquid FX major port from the card's R3 major-FX wording.
- NZDUSD.DWX - Liquid FX major port from the card's R3 major-FX wording.
- USDJPY.DWX - Liquid FX major port from the card's R3 major-FX wording.
- USDCAD.DWX - Liquid FX major port from the card's R3 major-FX wording.
- USDCHF.DWX - Liquid FX major port from the card's R3 major-FX wording.

**Explicitly NOT for:**
- SPX500.DWX - Not present in the DWX symbol matrix.
- SPY.DWX - Not present in the DWX symbol matrix.
- ES.DWX - Not present in the DWX symbol matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Expected trade frequency | Not specified in card frontmatter; inferred roughly monthly from 12 trades/year. |
| Typical hold time | Not specified in card frontmatter; inferred days to weeks from D1 SMA regime switching. |
| Expected drawdown profile | Downside-protection profile: long exposure during positive SMA regime, cash/flat during negative regime. |
| Regime preference | Not specified in card frontmatter; inferred trend-following / market-timing. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ede348b4-0fa7-5be1-baa8-09e9089b67b7
**Source type:** blog
**Pointer:** Wesley Gray, PhD, "A Simulation Study on Simple Moving Average Rules", 2014-07-28, https://alphaarchitect.com/a-simulation-study-on-simple-moving-average-rules/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_1087_aa-spx-20-252-ma.md`

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
| v1 | 2026-06-13 | Initial build from card | 498ee2ee-f3d1-4251-ad95-87e289c376fb |
