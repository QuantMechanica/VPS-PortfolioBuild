# QM5_11459_blade-macd-stoch-divergence-h1 - Strategy Spec

**EA ID:** QM5_11459
**Slug:** blade-macd-stoch-divergence-h1
**Source:** ea67ad76-751d-576b-a28a-4efb99691dad (see approved card source lineage)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades H1 reversal signals when price and MACD histogram diverge and Stochastic confirms an exit from an extreme zone. A short signal requires the current closed bar to form a lower MACD histogram peak while price makes a higher high against a prior local MACD peak in the last 20 bars, with Stochastic K crossing down through 80 within the signal window. A long signal mirrors this logic with a higher MACD trough, lower price low, and Stochastic K crossing up through 20. Positions use the card's structural stop with a 5 pip buffer and 80 pip cap, a 2.0 ATR(14) target, and close early when the MACD histogram turns against the open trade direction.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_macd_fast | 12 | 1-100 | Fast MACD EMA period. |
| strategy_macd_slow | 26 | fast+1-200 | Slow MACD EMA period. |
| strategy_macd_signal | 9 | 1-100 | MACD signal smoothing period. |
| strategy_stoch_k | 9 | 1-100 | Stochastic K period. |
| strategy_stoch_d | 3 | 1-50 | Stochastic D period. |
| strategy_stoch_slowing | 3 | 1-50 | Stochastic slowing period. |
| strategy_div_lookback | 20 | 3-100 | Lookback window for the prior MACD peak or trough. |
| strategy_signal_window | 2 | 1-10 | Maximum bars between divergence and Stochastic confirmation. |
| strategy_stoch_overbought | 80.0 | 50-100 | Overbought threshold for bearish setups. |
| strategy_stoch_oversold | 20.0 | 0-50 | Oversold threshold for bullish setups. |
| strategy_confirm_candle | true | true/false | Requires the confirmation bar to close in the trade direction. |
| strategy_atr_period | 14 | 1-100 | ATR period for the profit target. |
| strategy_atr_tp_mult | 2.0 | 0.1-10.0 | ATR multiple used for the take-profit distance. |
| strategy_sl_buffer_pips | 5 | 1-50 | Stop buffer beyond the signal bar high or low. |
| strategy_max_sl_pips | 80 | 1-500 | Maximum stop distance allowed for P2. |
| strategy_spread_cap_pips | 20 | 1-100 | No-trade spread cap. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-stated H1 DWX major FX target.
- GBPUSD.DWX - card-stated H1 DWX major FX target.
- USDJPY.DWX - card-stated H1 DWX major FX target.
- AUDUSD.DWX - card-stated H1 DWX major FX target.
- USDCAD.DWX - card-stated H1 DWX major FX target.

**Explicitly NOT for:**
- Indices and commodities - the approved card specifies H1 FX majors, not index or commodity contracts.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Typical hold time | Not specified in frontmatter; expected hours to days from H1 ATR target plus MACD histogram exit. |
| Expected drawdown profile | Not specified in frontmatter; fixed-risk reversal system with 80 pip P2 stop cap. |
| Regime preference | Reversal / mean-reversion after momentum divergence. |
| Win rate target (qualitative) | Not specified in frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ea67ad76-751d-576b-a28a-4efb99691dad
**Source type:** online/self-published strategy source
**Pointer:** D:\QM\strategy_farm\artifacts\cards_approved\QM5_11459_blade-macd-stoch-divergence-h1.md
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11459_blade-macd-stoch-divergence-h1.md`

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
| v1 | 2026-06-11 | Initial build from card | 1bb0be36-7e5c-47e1-88eb-bf68b2098818 |
