# QM5_11852_bb50-234-meanturn-m1 - Strategy Spec

**EA ID:** QM5_11852
**Slug:** `bb50-234-meanturn-m1`
**Source:** `f0aafe89-74a4-54d6-a2ec-9d555e7b2eb3`
**Author of this spec:** Codex
**Last revised:** 2026-07-01

---

## 1. Strategy Logic

The EA trades a closed-bar Bollinger Band mean-reversion setup on JPY FX pairs. A sell signal requires the prior closed bar to be extended beyond the BB(50, 2.34) upper band and at least halfway toward the BB(50, 3.0) upper band, followed by the latest closed bar moving back inside the inner band; buy signals mirror the lower bands. Stops are set at 1.0 ATR(14) from entry and take profit targets the BB midline/SMA50, with a minimum 1R target when the midline is too close. Entries are limited to the UTC session window from 07:00 to 13:00 by default.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_bb_period` | 50 | 20-100 | Bollinger period used for all bands and the midline target. |
| `strategy_bb_dev_inner` | 2.34 | 1.5-3.0 | Inner band deviation used for extension and retrace confirmation. |
| `strategy_bb_dev_outer` | 3.0 | 2.0-4.0 | Outer band deviation used to require deeper overextension. |
| `strategy_atr_period` | 14 | 5-50 | ATR period for hard stop calculation. |
| `strategy_sl_atr_mult` | 1.0 | 0.5-3.0 | Stop distance as a multiple of ATR. |
| `strategy_min_rr` | 1.0 | 0.5-3.0 | Minimum reward-to-risk target when the SMA50 target is too close. |
| `strategy_session_enabled` | true | true/false | Enables the UTC session filter. |
| `strategy_session_start_utc` | 7 | 0-23 | Start hour for the permitted UTC trading window. |
| `strategy_session_end_utc` | 13 | 0-23 | End hour for the permitted UTC trading window. |
| `strategy_spread_pct_of_stop` | 25.0 | 0-100 | Blocks only genuinely wide spread when spread exceeds this percentage of stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `GBPJPY.DWX` - source pair and highest-priority JPY cross for the BB scalp.
- `EURJPY.DWX` - liquid JPY cross with the same volatility/reversion structure.
- `USDJPY.DWX` - liquid JPY major used as the lower-volatility validation proxy.

**Explicitly NOT for:**
- `XAUUSD.DWX` - metal volatility and session behavior are outside the card scope.
- `SP500.DWX` - index microstructure does not match the source FX scalping setup.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 600 |
| Typical hold time | minutes; time stop concept is 5 M1 bars, with SL/TP usually deciding first |
| Expected drawdown profile | tight ATR stops with frequent small mean-reversion losses during trend bursts |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium to high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `f0aafe89-74a4-54d6-a2ec-9d555e7b2eb3`
**Source type:** forum/PDF
**Pointer:** Chelo via Rita Lasker / Green Forex Group, "Great GBP/JPY 1M Scalping Strategy"; `http://www.ritalasker.com`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11852_bb50-234-meanturn-m1.md`

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
| v1 | 2026-07-01 | Initial build from card | build task 4527a4da-3e46-4498-b7d2-33faeac40da6 |
