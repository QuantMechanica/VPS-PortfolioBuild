# QM5_11293_ema5-13-fib-cross-h1 - Strategy Spec

**EA ID:** QM5_11293
**Slug:** ema5-13-fib-cross-h1
**Source:** e78a9f1f-4e6a-563c-a080-915133d6ed28
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

This EA trades an H1 EMA(5) and EMA(13) crossover. A long entry is allowed when EMA(5) crosses above EMA(13) on the last closed H1 bar, the EMA separation is greater than one pip, and the ATR-buffered stop below EMA(13) is no more than 100 pips from the market entry. A short entry uses the mirrored cross below EMA(13), one-pip separation, and ATR-buffered stop above EMA(13). Open positions close when EMA(5) moves back to the opposite side of EMA(13), or by the initial stop loss.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_signal_tf | PERIOD_H1 | M1-MN1 | Timeframe used for EMA and ATR reads. |
| strategy_fast_ema_period | 5 | integer > 0 and less than slow EMA | Fast EMA period from the card. |
| strategy_slow_ema_period | 13 | integer > fast EMA | Slow EMA period from the card. |
| strategy_atr_period | 14 | integer > 0 | ATR period used for the P2 stop buffer. |
| strategy_atr_sl_mult | 1.5 | double > 0 | ATR multiplier applied beyond EMA(13) for the initial stop. |
| strategy_min_separation_pips | 1.0 | double >= 0 | Minimum EMA separation at the closed signal bar. |
| strategy_max_gap_pips | 100.0 | double > 0 | Maximum allowed distance from entry to initial stop. |
| strategy_max_spread_pips | 20.0 | double >= 0 | Spread cap; 0 disables this strategy-level spread filter. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed major FX pair with DWX H1 data.
- GBPUSD.DWX - card-listed major FX pair with DWX H1 data.
- USDJPY.DWX - card-listed major FX pair with DWX H1 data.
- AUDUSD.DWX - card-listed major FX pair with DWX H1 data.
- EURJPY.DWX - card-listed major FX cross with DWX H1 data.

**Explicitly NOT for:**
- Non-DWX symbols - outside the registered V5 backtest universe for this build.
- Symbols not listed in the card R3 basket - no Q00 portability approval in this strategy card.

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
| Trades / year / symbol | 150 |
| Expected trade frequency | not specified in frontmatter; card describes active H1 EMA-cross cadence |
| Typical hold time | not specified in frontmatter; exits on reverse EMA relationship |
| Expected drawdown profile | trend-following whipsaw risk in ranging FX markets |
| Regime preference | trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** e78a9f1f-4e6a-563c-a080-915133d6ed28
**Source type:** archived PDF / website strategy
**Pointer:** `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\180982373-5-EMA-and-13-EMA-Fibonacci-Numbers-Trading-System-Forex-Strategies-Forex-Resources-Forex-Trading-Free-Forex-Trading-Signals-and-FX-Forecast.pdf`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11293_ema5-13-fib-cross-h1.md`

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
| v1 | 2026-06-08 | Initial build from card | 688258e5-6b39-4a10-b373-2ba5285fd60f |
