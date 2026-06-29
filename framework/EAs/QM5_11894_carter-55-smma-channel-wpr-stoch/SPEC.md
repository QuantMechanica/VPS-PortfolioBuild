# QM5_11894_carter-55-smma-channel-wpr-stoch - Strategy Spec

**EA ID:** QM5_11894
**Slug:** carter-55-smma-channel-wpr-stoch
**Source:** 9b7e5f31-2d68-5aa4-b914-d7e2f5c1a8b6 (see approved Strategy Card)
**Author of this spec:** Codex
**Last revised:** 2026-06-29

---

## 1. Strategy Logic

This EA trades H1 close-confirmed breakouts beyond a 55-period smoothed moving average channel. The upper channel is SMMA(55) on high prices and the lower channel is SMMA(55) on low prices. A long entry requires the just-closed H1 bar to close above the upper channel, Williams %R(55) to have crossed above -25 within the last three closed bars, and Stochastic(5,3,5) main to be above signal. Shorts mirror the logic below the lower channel with a Williams %R cross below -75 and Stochastic main below signal.

Exits are broker SL/TP, channel re-entry, hard timeout, and framework Friday close. Initial stop is the last 10 H1 bars' structure extreme plus a 2-pip buffer, and the take profit is set at 2.0R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_smma_period | 55 | >= 1 | Smoothed moving average period used for the high/low channel. |
| strategy_wpr_period | 55 | >= 1 | Williams %R lookback period. |
| strategy_wpr_upper_level | -25.0 | -100 to 0 | Long confirmation threshold crossed upward. |
| strategy_wpr_lower_level | -75.0 | -100 to 0 | Short confirmation threshold crossed downward. |
| strategy_wpr_cross_lookback | 3 | >= 1 | Number of closed H1 bars allowed for the Williams %R cross event. |
| strategy_stoch_k | 5 | >= 1 | Stochastic K period. |
| strategy_stoch_d | 3 | >= 1 | Stochastic D period. |
| strategy_stoch_slowing | 5 | >= 1 | Stochastic slowing parameter. |
| strategy_structure_lookback | 10 | >= 1 | Closed H1 bars used for the initial structure stop. |
| strategy_structure_buffer_pips | 2 | >= 1 | Pip buffer beyond the structure stop. |
| strategy_target_rr | 2.0 | > 0 | Take-profit multiple of initial risk. |
| strategy_timeout_bars | 120 | >= 1 | Maximum hold time in H1 bars before strategy exit. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card target forex major and primary Carter test market.
- GBPUSD.DWX - Card target forex major and primary Carter test market.
- USDJPY.DWX - Card target forex major with direct DWX availability.
- USDCAD.DWX - Card target forex major with direct DWX availability.
- USDCHF.DWX - Card target forex major with direct DWX availability.
- AUDUSD.DWX - Card target forex major with direct DWX availability.
- NZDUSD.DWX - Card target forex major with direct DWX availability.
- EURJPY.DWX - Card target forex cross with direct DWX availability.
- GBPJPY.DWX - Card target forex cross with direct DWX availability.
- AUDJPY.DWX - Card target forex cross with direct DWX availability.

**Explicitly NOT for:**
- Non-forex `.DWX` symbols - The card defines a forex majors and crosses universe, not indices, metals, crypto, or commodities.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) via framework OnTick entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 50 |
| Typical hold time | Not explicit in frontmatter; bounded by card timeout at 120 H1 bars, approximately 5 trading days. |
| Expected drawdown profile | Breakout strategy with whipsaw risk during range-bound channel re-entries. |
| Regime preference | channel breakout with oscillator confirmation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 9b7e5f31-2d68-5aa4-b914-d7e2f5c1a8b6
**Source type:** book
**Pointer:** Thomas Carter, "20 Forex Trading Strategies Collection (1 Hour Time Frame)" Kindle 2014, Strategy #5 pages 12-13; approved card at `artifacts/cards_approved/QM5_11894_carter-55-smma-channel-wpr-stoch.md`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11894_carter-55-smma-channel-wpr-stoch.md`

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
| v1 | 2026-06-18 | Initial build from card | f3e82abc-5640-44f7-a480-e0e34603af62 |
| v1.1 | 2026-06-29 | Q02 infra repair | Made all backtest setfiles explicit with card strategy defaults before re-enqueueing the deferred FX symbols blocked by prior ex5_missing preflights. |
