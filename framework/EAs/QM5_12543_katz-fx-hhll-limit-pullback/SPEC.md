# QM5_12543_katz-fx-hhll-limit-pullback - Strategy Spec

**EA ID:** QM5_12543
**Slug:** katz-fx-hhll-limit-pullback
**Source:** katz-encyclopedia-2000-ch5
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA trades daily FX breakouts using a 40-bar Donchian-style channel. A long signal occurs when the last closed D1 candle closes above the highest high of the prior 40 bars; the EA then places a buy limit at the old channel high for up to 5 D1 bars. A short signal mirrors the rule below the prior 40-bar low with a sell limit at the old channel low. Open trades use a 1.0 x ATR(50) stop, a 4.0 x ATR(50) target, a 10-bar time exit, and an opposite-breakout exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_channel_bars | 40 | 2+ | Prior D1 bars used to define the HHLL channel boundary. |
| strategy_atr_period | 50 | 2+ | D1 ATR period for stop and target distance. |
| strategy_stop_atr_mult | 1.0 | >0 | ATR multiple subtracted from long entry or added to short entry for SL. |
| strategy_target_atr_mult | 4.0 | >0 | ATR multiple added to long entry or subtracted from short entry for TP. |
| strategy_limit_valid_bars | 5 | 1+ | Number of D1 bars the pullback limit order remains valid. |
| strategy_max_hold_bars | 10 | 1+ | Maximum D1 bars to hold a filled trade before strategy exit. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Major liquid FX pair in the card's currencies-only universe.
- GBPUSD.DWX - Major liquid FX pair in the card's currencies-only universe.
- USDJPY.DWX - Major liquid FX pair in the card's currencies-only universe.
- AUDUSD.DWX - Major liquid FX pair in the card's currencies-only universe.
- NZDUSD.DWX - Major liquid FX pair in the card's currencies-only universe.
- USDCAD.DWX - Major liquid FX pair in the card's currencies-only universe.
- USDCHF.DWX - Major liquid FX pair in the card's currencies-only universe.
- EURJPY.DWX - Liquid FX cross in the card's currencies-only universe.
- GBPJPY.DWX - Liquid FX cross in the card's currencies-only universe.

**Explicitly NOT for:**
- Index, commodity, crypto, and equity CFD symbols - the card restricts the tested edge to currencies only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 15 |
| Typical hold time | Up to 10 D1 bars |
| Expected drawdown profile | Around 12% expected drawdown from card frontmatter |
| Regime preference | Breakout / trend-following with pullback entry |
| Win rate target (qualitative) | Medium-low, with payoff skew from 4.0 x ATR target versus 1.0 x ATR stop |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** katz-encyclopedia-2000-ch5
**Source type:** book / OWNER library
**Pointer:** `D:/QM/strategy_farm/source_cache/katz_encyclopedia_2000.txt`, Katz & McCormick (2000), Ch. 5 pp. 83-121 and standard-exit spec pp. 96-97
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12543_katz-fx-hhll-limit-pullback.md`

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
| v1 | 2026-06-12 | Initial build from card | 88243b40-3e7b-4335-866a-371e87d99355 |
