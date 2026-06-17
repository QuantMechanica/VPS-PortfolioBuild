# QM5_12391_comm-skew - Strategy Spec

**EA ID:** QM5_12391
**Slug:** comm-skew
**Source:** b7832a20-938e-5f24-b9d7-e0b2ab63b623 (see approved card citation)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA runs a monthly commodity cross-section on D1 data. On the first tradable D1 bar of each calendar month it computes sample skewness from the latest 252 daily log returns for XAUUSD.DWX, XAGUSD.DWX, XTIUSD.DWX, and XNGUSD.DWX. It goes long the commodity with the lowest skewness and short the commodity with the highest skewness, provided all four symbols have enough D1 history. Existing legs are reviewed on each monthly rebalance and closed when the chart symbol is no longer selected for its current side.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_return_lookback_d1 | 252 | 20-512 | Number of D1 returns used for skewness ranking. |
| strategy_min_warmup_d1 | 260 | >= lookback + 1 | Minimum D1 bars requested before a symbol is eligible. |
| strategy_atr_period_d1 | 20 | > 0 | ATR period for the emergency stop. |
| strategy_atr_sl_mult | 3.0 | > 0 | ATR multiple used for each leg's emergency stop. |
| strategy_spread_lookback_d1 | 60 | >= 0 | D1 bars used to estimate median modeled spread. |
| strategy_spread_median_mult | 2.0 | >= 0 | Entry is skipped when current spread is above this multiple of median spread. |
| strategy_legs_per_side | 1 | 1-2 | Number of lowest-skew symbols to buy and highest-skew symbols to short. |

---

## 3. Symbol Universe

**Designed for:**
- XAUUSD.DWX - gold commodity CFD in the approved DWX port universe.
- XAGUSD.DWX - silver commodity CFD in the approved DWX port universe.
- XTIUSD.DWX - crude oil commodity CFD in the approved DWX port universe.
- XNGUSD.DWX - natural gas commodity CFD in the approved DWX port universe.

**Explicitly NOT for:**
- Index `.DWX` symbols - the card is a commodity cross-section, not an equity-index ranker.
- Forex `.DWX` symbols - the card ranks commodities by return skewness, not currencies.
- Commodity symbols outside `dwx_symbol_matrix.csv` - unregistered symbols cannot be backtested by this framework.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none; all strategy calculations use D1 data |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework D1 setfile |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | About one calendar month between rebalances |
| Expected drawdown profile | Commodity dispersion edge can be unstable with only four CFDs and may draw down during commodity trend shocks |
| Regime preference | Cross-sectional commodity skewness-premium regime |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b7832a20-938e-5f24-b9d7-e0b2ab63b623
**Source type:** public GitHub implementation / Quantpedia-derived strategy reference
**Pointer:** https://github.com/paperswithbacktest/awesome-systematic-trading/blob/main/static/strategies/skewness-effect-in-commodities.py
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_12391_comm-skew.md`

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
| v1 | 2026-06-18 | Initial build from card | aaa8df78-e294-4569-8336-acf4c1638c41 |
