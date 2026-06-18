# QM5_1097_unger-gold-intraday-bias — Strategy Spec

**EA ID:** QM5_1097
**Slug:** `unger-gold-intraday-bias`
**Source:** `eb97a148-0af9-5b9c-878c-25fb5dfa34f9` (see `sources/unger-robbins-cup`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA trades a fixed intraday bias on XAUUSD.DWX. On M15 execution bars, it checks the opening minute of two configured H1 broker-time slots: the default long slot is 08:00 and the default short slot is 14:00. It enters one market trade in the configured slot direction if H1 ATR is at least 60% of its 60-day same-slot median and the current spread is not wider than 2x its 20-day median. The stop is 1.0x ATR(14,H1), there is no take-profit, and any open position is closed after the same H1 slot has elapsed.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_long_slot_hour` | 8 | 0-23 | Broker-hour slot that opens a long trade. |
| `strategy_short_slot_hour` | 14 | 0-23 | Broker-hour slot that opens a short trade. |
| `strategy_slot_hold_minutes` | 60 | 1-240 | Maximum holding time; default closes at the end of the same H1 slot. |
| `strategy_atr_period` | 14 | >0 | H1 ATR period for stop and volatility filter. |
| `strategy_atr_sl_mult` | 1.0 | >0 | ATR multiple used for the hard stop. |
| `strategy_atr_median_days` | 60 | 1-120 | Prior-day same-slot H1 ATR samples used for the median volatility filter. |
| `strategy_min_atr_median_mult` | 0.60 | >0 | Minimum current ATR as a multiple of the ATR median. |
| `strategy_spread_median_days` | 20 | 1-64 | Prior D1 bars used for the median spread filter. |
| `strategy_spread_max_median_mult` | 2.0 | >0 | Maximum current spread as a multiple of median spread; zero-spread tester data is allowed. |
| `strategy_friday_last_entry_hour` | 18 | 0-23 | No new slot trades on Friday at or after this broker hour. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` — the card names gold explicitly, and XAUUSD.DWX is present in the DWX symbol matrix as the routable metal symbol.

**Explicitly NOT for:**
- Other `.DWX` symbols — the approved card does not authorize cross-symbol expansion beyond gold.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `H1` ATR for volatility filter and stop sizing; D1 spread history for spread median |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `50` |
| Typical hold time | `1 hour` |
| Expected drawdown profile | Intraday event concentration with bounded ATR stop and no overnight intent. |
| Regime preference | Intraday bias / seasonality with sufficient H1 volatility. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `eb97a148-0af9-5b9c-878c-25fb5dfa34f9`
**Source type:** `article / book`
**Pointer:** `https://ungeracademy.com/posts/bias-systems-trading-seasonal-market-patterns` and `artifacts/cards_approved/QM5_1097_unger-gold-intraday-bias.md`
**R1–R4 verdict (Q00):** all R1–R4 PASS per `artifacts/cards_approved/QM5_1097_unger-gold-intraday-bias.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-18 | Initial build from card | 60e1529a-a001-4c3f-934c-735e9dcf51a3 |
