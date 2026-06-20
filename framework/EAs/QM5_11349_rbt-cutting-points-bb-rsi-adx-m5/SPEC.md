# QM5_11349_rbt-cutting-points-bb-rsi-adx-m5 - Strategy Spec

**EA ID:** QM5_11349
**Slug:** `rbt-cutting-points-bb-rsi-adx-m5`
**Source:** `ed246754-1f4d-5bed-8dd3-3b5cbf1b420d` (see approved Strategy Card)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades an M5 counter-trend Bollinger Band recapture. A long setup starts when the prior signal bar touches or pierces the BB(20,2) lower band while RSI(14) is below 30 and ADX(14) is below 30; it buys after the next closed bar finishes back above the lower band. A short setup mirrors this at the upper band with RSI(14) above 70 and a close back below the upper band. The stop is 3 pips beyond the touched band, capped at 15 pips from entry, and the take-profit is the BB(20,2) middle band.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 20 | 2-200 | Bollinger Band period. |
| `strategy_bb_deviation` | 2.0 | 0.5-5.0 | Bollinger Band standard-deviation multiplier. |
| `strategy_rsi_period` | 14 | 2-100 | RSI lookback used on the band-touch bar. |
| `strategy_rsi_oversold` | 30.0 | 1-50 | Maximum RSI for long reversal setup. |
| `strategy_rsi_overbought` | 70.0 | 50-99 | Minimum RSI for short reversal setup. |
| `strategy_adx_period` | 14 | 2-100 | ADX lookback used on the band-touch bar. |
| `strategy_adx_max` | 30.0 | 1-60 | Maximum ADX allowed; higher values imply trend and block entry. |
| `strategy_sl_buffer_pips` | 3 | 1-20 | Stop buffer beyond the touched Bollinger Band. |
| `strategy_max_sl_pips` | 15 | 1-100 | Maximum allowed entry-to-stop distance. |
| `strategy_spread_cap_pips` | 2 | 1-20 | Maximum live spread before blocking a new entry. |
| `strategy_session_start_utc` | 13 | 0-23 | UTC hour at which the London plus NY trading window opens. |
| `strategy_session_end_utc` | 22 | 1-24 | UTC hour at which the trading window closes. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed liquid major FX pair with M5 DWX history.
- `GBPUSD.DWX` - Card-listed liquid major FX pair with M5 DWX history.
- `AUDUSD.DWX` - Card-listed liquid major FX pair with M5 DWX history.
- `USDCAD.DWX` - Card-listed liquid major FX pair with M5 DWX history.

**Explicitly NOT for:**
- Index, metals, energy, and non-card FX symbols - not part of the approved R3 symbol basket for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `300` |
| Typical hold time | Intraday M5 scalp; minutes to a few hours |
| Expected drawdown profile | Mean-reversion scalp with capped 15-pip entry-to-stop distance |
| Regime preference | Mean-revert / range-bound, explicitly ADX-filtered |
| Win rate target (qualitative) | medium-high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ed246754-1f4d-5bed-8dd3-3b5cbf1b420d`
**Source type:** institutional PDF archive
**Pointer:** `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\362359657-Robo-forex-strategy.pdf`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11349_rbt-cutting-points-bb-rsi-adx-m5.md`

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
| v1 | 2026-06-20 | Initial build from card | 64ae77ad-b65a-4fae-874a-6484d5bbb9ba |
