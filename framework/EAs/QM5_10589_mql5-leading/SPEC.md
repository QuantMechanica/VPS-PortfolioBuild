# QM5_10589_mql5-leading - Strategy Spec

**EA ID:** QM5_10589
**Slug:** `mql5-leading`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-30

---

## 1. Strategy Logic

The EA calculates the Leading indicator on the selected timeframe using the source formula: a net lead line derived from median price and a 0.5 EMA of median price. It opens long when the net lead line crosses above the EMA line on the latest closed bar, and opens short when the net lead line crosses below the EMA line. If an opposite cross appears while this EA already has a position, the position is closed and the opposite-side entry is submitted on that closed-bar signal. Each new trade uses an ATR(14) stop at 2.0 times ATR and a target at 1.5R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H4` | `PERIOD_M1`-`PERIOD_MN1` | Timeframe used for Leading line and ATR reads. |
| `strategy_calc_bars` | `160` | `8`-`500` | Closed bars used to warm up and calculate the Leading line recursion. |
| `strategy_leading_alpha1` | `0.25` | `>0.0` | First Leading indicator smoothing coefficient from the source default. |
| `strategy_leading_alpha2` | `0.33` | `0.0`-`1.0` | Second Leading indicator smoothing coefficient from the source default. |
| `strategy_atr_period` | `14` | `1`-`200` | ATR period for the hard stop. |
| `strategy_atr_sl_mult` | `2.0` | `>0.0` | ATR multiplier used for stop distance. |
| `strategy_reward_r_multiple` | `1.5` | `>0.0` | Profit target distance as a multiple of initial risk. |
| `strategy_max_spread_points` | `0` | `0`-`100000` | Optional spread block in points; `0` disables the extra spread filter. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `USDJPY.DWX` - card primary source test symbol and part of the approved FX basket.
- `EURUSD.DWX` - liquid DWX major FX pair suitable for OHLC line-crossover logic.
- `GBPJPY.DWX` - liquid DWX FX cross suitable for OHLC line-crossover logic.
- `XAUUSD.DWX` - approved DWX metal symbol in the card's portable basket.

**Explicitly NOT for:**
- `SP500.DWX` - not in this card's R3 approved P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `40` |
| Typical hold time | `hours to days` |
| Expected drawdown profile | `ATR-defined downside with one active position per symbol/magic` |
| Regime preference | `closed-bar line-crossover trend / momentum turns` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/12560`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10589_mql5-leading.md`

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
| v1 | 2026-05-30 | Initial build from card | bef09a38-5433-4302-8168-e0dc972c8f99 |
