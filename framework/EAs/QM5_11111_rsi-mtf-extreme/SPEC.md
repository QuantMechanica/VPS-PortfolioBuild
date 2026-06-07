# QM5_11111_rsi-mtf-extreme - Strategy Spec

**EA ID:** QM5_11111
**Slug:** rsi-mtf-extreme
**Source:** 0693c604-4f96-56ef-be79-15efe9f48b86
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates completed H1 bars and reads RSI(14) on H1, H4, and D1. A long entry is allowed after the prior H1 RSI was at or below 30 while H4 and D1 are also at or below 30, then the latest closed H1 RSI turns up while H4 and D1 remain at or below 35. A short entry mirrors this: the prior H1 RSI is at or above 70 with H4 and D1 at or above 70, then H1 RSI turns down while H4 and D1 remain at or above 65. Longs exit when H1 RSI closes above 50, an opposite short setup appears, or 30 H1 bars elapse; shorts exit on the inverse rules.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_rsi_period | 14 | >= 2 | RSI period used on H1, H4, and D1 closes. |
| strategy_setup_low | 30.0 | 0-100 | Oversold setup threshold for long entries and short exits. |
| strategy_setup_high | 70.0 | 0-100 | Overbought setup threshold for short entries and long exits. |
| strategy_long_remain_max | 35.0 | 0-100 | Maximum H4/D1 RSI allowed while a long trigger fires. |
| strategy_short_remain_min | 65.0 | 0-100 | Minimum H4/D1 RSI required while a short trigger fires. |
| strategy_exit_midline | 50.0 | 0-100 | H1 RSI midline exit threshold. |
| strategy_atr_period | 14 | >= 1 | ATR period for the hard stop. |
| strategy_atr_sl_mult | 2.0 | > 0 | ATR multiplier for the hard stop. |
| strategy_max_hold_h1_bars | 30 | >= 0 | Safety time stop measured in H1 bars; zero disables it. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed liquid major forex pair with DWX OHLC data.
- GBPUSD.DWX - card-listed liquid major forex pair with DWX OHLC data.
- USDJPY.DWX - card-listed liquid major forex pair with DWX OHLC data.
- XAUUSD.DWX - card-listed liquid gold symbol with DWX OHLC data.

**Explicitly NOT for:**
- Symbols outside the card R3 basket - not approved for this initial P2 baseline.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | H1, H4, D1 RSI |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 24 |
| Typical hold time | Up to 30 H1 bars by card safety stop. |
| Expected drawdown profile | ATR-stopped RSI extreme reversal; losses bounded by 2.0 * ATR(14) hard stop. |
| Regime preference | Mean-reversion after multi-timeframe RSI extreme alignment. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 0693c604-4f96-56ef-be79-15efe9f48b86
**Source type:** GitHub repository and MQL5 indicator source
**Pointer:** https://github.com/EarnForex/RSI-Multi-Timeframe; MQL5/Indicators/MQLTA MT5 RSI Multi-Timeframe.mq5
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11111_rsi-mtf-extreme.md`

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
| v1 | 2026-06-07 | Initial build from card | 36903439-acba-4f73-9e4d-3754485cc832 |
