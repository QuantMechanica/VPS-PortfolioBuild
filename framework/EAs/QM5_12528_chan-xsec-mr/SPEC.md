# QM5_12528_chan-xsec-mr - Strategy Spec

**EA ID:** QM5_12528
**Slug:** `chan-xsec-mr`
**Source:** `cfeee113-154e-549a-9fba-501b7e3160c0` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA evaluates the declared DWX macro basket once per completed D1 bar. For each active symbol it computes the lookback return, subtracts the basket mean return, negates that relative return into a contrarian score, and normalizes the score by the sum of absolute scores. It buys the chart symbol when its normalized target weight is above the minimum weight and sells it when the target weight is below the negative minimum. Open positions are rechecked on every completed D1 bar and closed when the recalculated target weight falls below the same-side threshold or flips side.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_return_lookback_days` | 1 | 1-3 | D1 return lookback used in the cross-sectional score. |
| `strategy_min_basket_size` | 5 | 5-10 | Minimum active symbols required before weights are valid. |
| `strategy_min_abs_weight` | 0.05 | 0.03-0.08 | Minimum absolute normalized target weight for entry and same-side hold. |
| `strategy_atr_period` | 20 | 10-50 | D1 ATR period for the emergency stop. |
| `strategy_atr_sl_mult` | 3.0 | 2.0-4.0 | ATR multiple used for the emergency stop distance. |
| `strategy_spread_median_days` | 60 | 20-120 | Lookback for the card's 2x median spread entry filter. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - major FX leg from the approved macro basket.
- `GBPUSD.DWX` - major FX leg from the approved macro basket.
- `USDJPY.DWX` - major FX leg from the approved macro basket.
- `AUDUSD.DWX` - major FX leg from the approved macro basket.
- `USDCAD.DWX` - major FX leg from the approved macro basket.
- `NDX.DWX` - US index leg from the approved macro basket.
- `WS30.DWX` - US index leg from the approved macro basket.
- `XAUUSD.DWX` - metals leg from the approved macro basket.

**Explicitly NOT for:**
- Symbols outside the registered basket - the cross-sectional score needs the declared basket members and their registered magic slots.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_D1)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `120` |
| Typical hold time | daily rebalance, usually 1-5 days |
| Expected drawdown profile | synchronized basket trends can create clustered losses; ATR emergency stop bounds single-trade loss. |
| Regime preference | cross-sectional mean reversion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `cfeee113-154e-549a-9fba-501b7e3160c0`
**Source type:** `blog`
**Pointer:** Teddy Koker, "Backtesting a Cross-Sectional Mean Reversion Strategy in Python", published 2019-04-28, https://teddykoker.com/2019/04/backtesting-a-cross-sectional-mean-reversion-strategy-in-python/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12528_chan-xsec-mr.md`

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
| v1 | 2026-06-18 | Initial build from card | 70ee71bf-0551-4f31-85f8-ab15653d2241 |
