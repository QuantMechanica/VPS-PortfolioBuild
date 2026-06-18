# QM5_1092_qp-fx-value-ppp - Strategy Spec

**EA ID:** QM5_1092
**Slug:** qp-fx-value-ppp
**Source:** 7ede58dd-d184-5099-9d48-7a65de230853 (see `strategy-seeds/sources/7ede58dd-d184-5099-9d48-7a65de230853/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA implements the Quantpedia currency value factor as a scheduled PPP-deviation rebalance. On each D1 quarterly rebalance window by default, it computes `spot_usd_per_currency / ppp_fair_value - 1` for the seven approved non-USD currencies, ranks them, buys the three most undervalued currencies against USD, and sells the three most overvalued currencies against USD. Positions are closed at the next scheduled rebalance, while the broker hard stop is placed at 5.0 times ATR(20).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_rebalance_months | 3 | 1 or 3 | Monthly variant or quarterly default rebalance cadence. |
| strategy_rebalance_window_days | 7 | 1-10 | Calendar-day window at the start of a rebalance month. |
| strategy_bucket_size | 3 | 1-3 | Count of undervalued currencies to buy and overvalued currencies to sell. |
| strategy_atr_period | 20 | >= 1 | ATR period used by the hard stop. |
| strategy_atr_sl_mult | 5.0 | > 0 | ATR multiple for the hard stop. |
| strategy_max_spread_points | 30 | >= 0 | Current-spread cap in points; zero disables the cap. |
| strategy_stale_days_monthly | 45 | >= 0 | Maximum age for PPP inputs in monthly mode. |
| strategy_stale_days_quarterly | 120 | >= 0 | Maximum age for PPP inputs in quarterly mode. |
| strategy_ppp_observation_yyyymmdd | 20231231 | YYYYMMDD | Observation date for deterministic PPP fair-value inputs. |
| strategy_ppp_eur_usd | 1.5000 | > 0 | PPP fair value, USD per EUR. |
| strategy_ppp_gbp_usd | 1.4000 | > 0 | PPP fair value, USD per GBP. |
| strategy_ppp_jpy_usd | 0.0075 | > 0 | PPP fair value, USD per JPY. |
| strategy_ppp_aud_usd | 0.7500 | > 0 | PPP fair value, USD per AUD. |
| strategy_ppp_cad_usd | 0.8000 | > 0 | PPP fair value, USD per CAD. |
| strategy_ppp_chf_usd | 1.1000 | > 0 | PPP fair value, USD per CHF. |
| strategy_ppp_nzd_usd | 0.6800 | > 0 | PPP fair value, USD per NZD. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - EUR value exposure against USD from the card universe.
- GBPUSD.DWX - GBP value exposure against USD from the card universe.
- USDJPY.DWX - JPY value exposure translated through the USD-base quote.
- AUDUSD.DWX - AUD value exposure against USD from the card universe.
- USDCAD.DWX - CAD value exposure translated through the USD-base quote.
- USDCHF.DWX - CHF value exposure translated through the USD-base quote.
- NZDUSD.DWX - NZD value exposure against USD from the card universe.

**Explicitly NOT for:**
- Non-FX `.DWX` symbols - the PPP rank is defined only for the seven FX pairs above.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 0-4, depending on rank bucket membership |
| Typical hold time | one to three months |
| Expected drawdown profile | slow-moving macro factor with wide ATR stop |
| Regime preference | currency value mean reversion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 7ede58dd-d184-5099-9d48-7a65de230853
**Source type:** Quantpedia strategy encyclopedia / academic paper lineage
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1092_qp-fx-value-ppp.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1092_qp-fx-value-ppp.md`

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
| v1 | 2026-06-18 | Initial build from card | 0f5ce0ea-d465-4c57-8578-548025792d60 |
