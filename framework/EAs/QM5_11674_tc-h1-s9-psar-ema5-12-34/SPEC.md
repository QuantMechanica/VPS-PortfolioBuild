# QM5_11674_tc-h1-s9-psar-ema5-12-34 - Strategy Spec

**EA ID:** QM5_11674
**Slug:** `tc-h1-s9-psar-ema5-12-34`
**Source:** `6b5ab225-a2d3-54b1-ac8b-2b000a205468` (see `strategy-seeds/sources/6b5ab225-a2d3-54b1-ac8b-2b000a205468/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades Thomas Carter Strategy #9 on H1. A long signal occurs when EMA(5) is above EMA(12), EMA(12) is above EMA(34), and Parabolic SAR(0.10, 0.20) flips from above price to below price on the last closed H1 bar while remaining below EMA(5). A short signal mirrors the same rules with EMA(5) below EMA(12), EMA(12) below EMA(34), and Parabolic SAR flipping from below price to above price while remaining above EMA(5). Entries are market orders on the next bar after confirmation; exits are the fixed 30-pip stop loss or fixed 50-pip take profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_fast_period` | 5 | integer > 0 and < `strategy_ema_mid_period` | Fast EMA period used for the trend fan and SAR proximity check. |
| `strategy_ema_mid_period` | 12 | integer > `strategy_ema_fast_period` and < `strategy_ema_slow_period` | Middle EMA period used for trend fan ordering. |
| `strategy_ema_slow_period` | 34 | integer > `strategy_ema_mid_period` | Slow EMA period used for trend fan ordering. |
| `strategy_sar_step` | 0.10 | > 0.0 and < `strategy_sar_maximum` | Parabolic SAR acceleration step. |
| `strategy_sar_maximum` | 0.20 | > `strategy_sar_step` | Parabolic SAR maximum acceleration. |
| `strategy_stop_pips` | 30 | integer > 0 | Fixed stop-loss distance in pips. |
| `strategy_take_pips` | 50 | integer > 0 | Fixed take-profit distance in pips. |

Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - approved card target symbol; H1 DWX data is available.
- `GBPUSD.DWX` - approved card target symbol; H1 DWX data is available.

**Explicitly NOT for:**
- Other `.DWX` symbols - not listed in the approved card target universe for this EA.

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
| Trades / year / symbol | 25 |
| Typical hold time | Until 30-pip stop or 50-pip take profit; no separate hold-time exit specified in the card. |
| Expected drawdown profile | Fixed-risk trend-following system; drawdown is expected during H1 EMA fan whipsaws and PSAR false flips. |
| Regime preference | Trend-following. |
| Win rate target (qualitative) | Not specified in the card. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6b5ab225-a2d3-54b1-ac8b-2b000a205468`
**Source type:** book / self-published strategy collection
**Pointer:** Thomas Carter, "Forex Trading Strategy #9", in `376863900-20-Forex-Trading-Strategies-Collection.pdf`, pp. 20-21.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11674_tc-h1-s9-psar-ema5-12-34.md`

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
| v1 | 2026-06-11 | Initial build from card | 000a34ed-c00b-4017-838c-11d65c4380d9 |
