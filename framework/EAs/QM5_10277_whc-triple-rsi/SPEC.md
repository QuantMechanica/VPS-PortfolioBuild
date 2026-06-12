# QM5_10277_whc-triple-rsi - Strategy Spec

**EA ID:** QM5_10277
**Slug:** whc-triple-rsi
**Source:** 1b906e79-c619-5a61-90db-ee19ac95a19f (see GitHub repository `whchien/ai-trader`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA trades long-only on D1 bars. It opens a buy position when RSI(120) is above 55, RSI(60) is below 75, each of the last three closed RSI(20) values is above 55, and the latest closed RSI(20) is more than 2% above the RSI(20) value from two closed bars earlier. It exits only after the position has been held for more than 60 calendar days and the latest closed D1 close is below SMA(60). The source has no fixed take profit; this V5 build adds the card-required catastrophic stop at 2.0 * ATR(14).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_rsi_fast_period | 20 | 1+ | Fast RSI period used for the three-bar state and growth check. |
| strategy_rsi_mid_period | 60 | 1+ | Middle RSI period that must remain below the ceiling. |
| strategy_rsi_slow_period | 120 | 1+ | Slow RSI period that defines the trend floor. |
| strategy_rsi_trend_floor | 55.0 | 0-100 | Minimum slow RSI and fast RSI threshold for long setup. |
| strategy_rsi_mid_ceiling | 75.0 | 0-100 | Maximum middle RSI threshold for long setup. |
| strategy_fast_rsi_growth_min | 0.02 | 0+ | Minimum RSI(20) percentage growth versus two closed bars earlier. |
| strategy_sma_exit_period | 60 | 1+ | SMA period for the trend/time exit. |
| strategy_min_hold_days | 60 | 0+ | Minimum calendar days before the SMA exit can close a trade. |
| strategy_atr_period | 14 | 1+ | ATR period for the catastrophic stop. |
| strategy_atr_sl_mult | 2.0 | >0 | ATR multiplier for the catastrophic stop. |

---

## 3. Symbol Universe

**Designed for:**
- NDX.DWX - Nasdaq 100 daily trend persistence substrate named in the approved card.
- WS30.DWX - Dow 30 daily trend persistence substrate named in the approved card.
- SP500.DWX - S&P 500 daily trend persistence substrate named in the approved card; backtest-only caveat applies.
- XAUUSD.DWX - Metal daily trend persistence substrate named in the approved card.
- EURUSD.DWX - Major FX daily OHLC substrate covered by the card's "major FX" wording.
- GBPUSD.DWX - Major FX daily OHLC substrate covered by the card's "major FX" wording.
- USDJPY.DWX - Major FX daily OHLC substrate covered by the card's "major FX" wording.
- AUDUSD.DWX - Major FX daily OHLC substrate covered by the card's "major FX" wording.
- USDCAD.DWX - Major FX daily OHLC substrate covered by the card's "major FX" wording.
- USDCHF.DWX - Major FX daily OHLC substrate covered by the card's "major FX" wording.
- NZDUSD.DWX - Major FX daily OHLC substrate covered by the card's "major FX" wording.

**Explicitly NOT for:**
- Sector ETF proxies - the card names broad indices, XAUUSD, and major FX only.
- Non-matrix symbols - DWX symbol matrix membership is required before registration.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default framework entry gate) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 4 |
| Typical hold time | More than 60 calendar days before strategy exit is allowed |
| Expected drawdown profile | Not specified in card frontmatter; ATR stop limits catastrophic loss while source relies on trend/time exit |
| Regime preference | Trend persistence |
| Win rate target (qualitative) | Not specified in card frontmatter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1b906e79-c619-5a61-90db-ee19ac95a19f
**Source type:** GitHub repository
**Pointer:** https://github.com/whchien/ai-trader/blob/main/ai_trader/backtesting/strategies/classic/rsi.py
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10277_whc-triple-rsi.md`

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
| v1 | 2026-06-12 | Initial build from card | 0530879f-8124-432f-8bf7-923a37688efd |
