# QM5_10361_et-range-offset - Strategy Spec

**EA ID:** QM5_10361
**Slug:** et-range-offset
**Source:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

On each new D1 bar, the EA measures the highest high and lowest low over the recent four closed bars and anchors two stop orders around the current bar open. If the last close is less than or equal to the prior close, the long stop is placed at open plus 0.5 times the recent range and the short stop at open minus 1.0 times the recent range; otherwise the long side uses 1.0 times the range and the short side uses 0.5 times the range. The EA skips entries when the range is too narrow versus spread or too wide versus ATR(50), places both stop orders for the next bar, cancels the opposite pending stop when one side fills, and moves the stop to breakeven after a 3 ATR favorable closed-bar excursion.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_atr_period | 50 | 20-80 | ATR lookback for range filter, stop distance, and breakeven trigger. |
| strategy_range_len_low | 4 | 3-8 | Closed-bar lookback for the lowest low side of the recent range. |
| strategy_range_len_high | 4 | 3-8 | Closed-bar lookback for the highest high side of the recent range. |
| strategy_down_long_mult | 0.50 | 0.50-0.75 | Long stop range multiplier after a down or equal close. |
| strategy_down_short_mult | 1.00 | 1.00-1.25 | Short stop range multiplier after a down or equal close. |
| strategy_up_long_mult | 1.00 | 1.00-1.25 | Long stop range multiplier after an up close. |
| strategy_up_short_mult | 0.50 | 0.50-0.75 | Short stop range multiplier after an up close. |
| strategy_stop_atr_mult | 3.00 | 2.00-4.00 | ATR multiple used for the initial protective stop. |
| strategy_range_atr_max | 2.50 | 1.00-4.00 | Maximum recent range as a multiple of ATR before skipping entry. |
| strategy_breakeven_atr_mult | 3.00 | 2.00-4.00 | Favorable excursion in ATRs required before moving SL to entry. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed liquid FX pair with daily OHLC history.
- GBPUSD.DWX - card-listed liquid FX pair with daily OHLC history.
- XAUUSD.DWX - card-listed liquid metal CFD with daily OHLC history.
- GDAXI.DWX - matrix-verified DAX equivalent for the card's GER40 target.
- NDX.DWX - card-listed liquid US index CFD with daily OHLC history.

**Explicitly NOT for:**
- GER40.DWX - card target name is not present in `framework/registry/dwx_symbol_matrix.csv`; GDAXI.DWX is used instead.
- Non-DWX symbols - registry and backtest artifacts must use canonical `.DWX` names.

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
| Trades / year / symbol | 55 |
| Typical hold time | days |
| Expected drawdown profile | Daily breakout false stop-outs during low-quality range expansion. |
| Regime preference | volatility-expansion breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Source type:** forum
**Pointer:** Elite Trader thread cited by the approved card.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10361_et-range-offset.md`

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
| v1 | 2026-06-13 | Initial build from card | 0fa21288-6140-423d-acb3-5b177c13bacd |
