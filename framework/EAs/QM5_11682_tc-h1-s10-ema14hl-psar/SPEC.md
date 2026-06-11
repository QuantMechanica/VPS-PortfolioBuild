# QM5_11682_tc-h1-s10-ema14hl-psar - Strategy Spec

**EA ID:** QM5_11682
**Slug:** `tc-h1-s10-ema14hl-psar`
**Source:** `6b5ab225-a2d3-54b1-ac8b-2b000a205468` (see `strategy-seeds/sources/6b5ab225-a2d3-54b1-ac8b-2b000a205468/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades Thomas Carter Strategy #10 on H1. A long signal occurs when the last closed H1 candle closes above EMA(14) applied to High and Parabolic SAR(0.02, 0.20) is below that candle's low. A short signal occurs when the last closed H1 candle closes below EMA(14) applied to Low and Parabolic SAR is above that candle's high. Entries are market orders on the next bar after confirmation; exits are the fixed 55-pip stop loss or 80-pip take profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_period` | 14 | integer > 0 | EMA channel period applied separately to High and Low prices. |
| `strategy_sar_step` | 0.02 | > 0.0 and < `strategy_sar_maximum` | Parabolic SAR acceleration step. |
| `strategy_sar_maximum` | 0.20 | > `strategy_sar_step` | Parabolic SAR maximum acceleration. |
| `strategy_stop_pips` | 55 | integer > 0 | Fixed stop-loss distance in pips. |
| `strategy_take_pips` | 80 | integer > 0 | Fixed take-profit distance in pips. |

Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card target symbol; H1 DWX data is available.
- `GBPUSD.DWX` - card target symbol; H1 DWX data is available.

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
| Trades / year / symbol | 20 |
| Typical hold time | Until 55-pip stop or 80-pip take profit; no separate hold-time exit specified in the card. |
| Expected drawdown profile | Fixed-risk breakout system; drawdown depends on whipsaws around the EMA high/low channel. |
| Regime preference | Breakout / trend continuation after price closes outside the EMA high-low channel. |
| Win rate target (qualitative) | Not specified in the card. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6b5ab225-a2d3-54b1-ac8b-2b000a205468`
**Source type:** book / self-published strategy collection
**Pointer:** Thomas Carter, "Forex Trading Strategy #10", in `376863900-20-Forex-Trading-Strategies-Collection.pdf`, pp. 22-23.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11682_tc-h1-s10-ema14hl-psar.md`

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
| v1 | 2026-06-11 | Initial build from card | aa991049-26a5-4985-b791-c8342a5e2340 |
