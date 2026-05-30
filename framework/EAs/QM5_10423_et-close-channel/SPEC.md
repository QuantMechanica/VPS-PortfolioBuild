# QM5_10423_et-close-channel - Strategy Spec

**EA ID:** QM5_10423
**Slug:** et-close-channel
**Source:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe (see approved card source citation)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

This EA trades a close-only rolling channel breakout on H1 by default. It reads the last completed bar close and compares it with the highest and lowest closes from the prior completed channel window, excluding the signal bar. A long opens at the next bar when the completed close is above the upper close channel, and a short opens when it is below the lower close channel. Open positions exit when a completed close crosses the opposite close channel, then the EA waits one bar before any new entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_tf | PERIOD_H1 | H1, H4, D1 | Timeframe used for close-channel and ATR reads. |
| strategy_channel_lookback | 20 | 10-80 | Number of prior completed closes used for entry channel. |
| strategy_exit_lookback | 20 | 5-80 | Number of prior completed closes used for exit channel. |
| strategy_atr_period | 20 | 5-50 | ATR period for initial stop distance. |
| strategy_atr_stop_mult | 2.0 | 1.5-2.5 | ATR multiplier for initial stop. |
| strategy_use_channel_stop | true | true/false | If true, applies the optional channel stop constraint from the card. |
| strategy_wait_bars_after_exit | 1 | 0-5 | Bars to wait after a channel exit before allowing a fresh entry. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - primary liquid FX major in the card's portable R3 basket.
- GBPUSD.DWX - liquid FX major in the card's portable R3 basket.
- XAUUSD.DWX - liquid metal symbol in the card's portable R3 basket.
- SP500.DWX - S&P 500 custom symbol explicitly approved for backtest use.
- NDX.DWX - Nasdaq 100 index symbol in the card's portable R3 basket.

**Explicitly NOT for:**
- SPX500.DWX - not present in the DWX symbol matrix; SP500.DWX is the canonical S&P 500 custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 55 |
| Typical hold time | hours to days |
| Expected drawdown profile | Breakout systems can cluster losses during range-bound markets. |
| Regime preference | breakout / volatility expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Source type:** forum
**Pointer:** https://www.elitetrader.com/et/threads/amibroker-afl-coding-help.282591/
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10423_et-close-channel.md`

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
| v1 | 2026-05-25 | Initial build from card | ec257155-a5bb-41cd-a8c9-a9d45883f60c |
