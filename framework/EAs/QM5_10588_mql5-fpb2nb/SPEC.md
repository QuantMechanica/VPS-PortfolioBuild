# QM5_10588_mql5-fpb2nb - Strategy Spec

**EA ID:** QM5_10588
**Slug:** mql5-fpb2nb
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA mechanises the ForexProfitBoost_2nb trend color change on a closed H6 bar. The source indicator colors the bullish state blue when its fast EMA is above its slow SMA, and the bearish state pink when the fast EMA is below the slow SMA; Bollinger Bands are part of the indicator display calculation and are read for indicator parity. The EA opens long when the latest closed bar changes from pink to blue, opens short when it changes from blue to pink, and closes any opposite open position on the same color-change bar. Initial risk is an ATR(14) stop at 2.0x ATR and a 1.5R target.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_signal_tf | PERIOD_H6 | MT5 timeframe enum | Timeframe used for the closed-bar ForexProfitBoost signal. |
| strategy_fast_ema_period | 7 | 2+ | Fast EMA period from the source indicator. |
| strategy_slow_sma_period | 21 | 2+ | Slow SMA period from the source indicator. |
| strategy_bb_period | 15 | 2+ | Bollinger period retained from the source indicator display calculation. |
| strategy_bb_deviation | 1.0 | > 0 | Bollinger deviation retained from the source indicator display calculation. |
| strategy_atr_period | 14 | 1+ | ATR period for the P2 baseline hard stop. |
| strategy_atr_sl_mult | 2.0 | > 0 | Stop distance in ATR multiples. |
| strategy_reward_r_multiple | 1.5 | > 0 | Take-profit distance as a multiple of initial risk. |
| strategy_max_spread_points | 0 | 0+ | Optional spread block in points; 0 disables the strategy-specific spread cap. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- USDJPY.DWX - source test was USDJPY H6 and the R3 basket explicitly includes it.
- EURUSD.DWX - liquid DWX FX major from the card's R3 basket.
- GBPJPY.DWX - liquid DWX FX cross from the card's R3 basket.
- XAUUSD.DWX - liquid DWX metal from the card's R3 basket.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - they are not valid DWX backtest targets.
- Single-stock or sector ETF symbols - the card only authorizes FX and XAUUSD portability.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H6 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through framework OnTick gating |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 35 |
| Typical hold time | One or more H6 bars until opposite color change, SL, TP, news exit, kill-switch, or Friday close. |
| Expected drawdown profile | Trend-following profile with false signals expected in flat markets. |
| Regime preference | Trending FX and metal regimes. |
| Win rate target (qualitative) | Medium |
| Expected trade frequency | Closed-bar trend color changes on H6 should be moderate; conservative estimate is 20-50 trades/year/symbol. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** https://www.mql5.com/en/code/12711
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10588_mql5-fpb2nb.md`

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
| v1 | 2026-05-31 | Initial build from card | 23377f8b-c470-49d7-9079-6c4db8b47b3b |
