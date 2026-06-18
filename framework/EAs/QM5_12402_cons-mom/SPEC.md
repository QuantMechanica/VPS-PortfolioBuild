# QM5_12402_cons-mom - Strategy Spec

**EA ID:** QM5_12402
**Slug:** cons-mom
**Source:** b7832a20-938e-5f24-b9d7-e0b2ab63b623 (see approved card source citation)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA trades a reduced DWX equity-index basket using consistent cross-sectional momentum. On each new calendar month, it computes two D1 return windows for every valid basket symbol: a recent six-month proxy and a six-month proxy ending one month earlier. A symbol is long when it is in the top bucket for both ranks, short when it is in the bottom bucket for both ranks, and otherwise flat. Open positions are held for six months before a rebalance exit can close them if the symbol is no longer selected or has flipped side.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_recent_window_d1 | 126 | 105-147 | D1 bars for the t-6 to t return proxy. |
| strategy_skip_window_d1 | 126 | 105-147 | D1 bars for the t-7 to t-1 return proxy. |
| strategy_skip_days | 21 | 15-30 | One-month D1 skip between formation windows. |
| strategy_bucket_size | 1 | 1-3 | Number of top and bottom ranked symbols eligible for selection. |
| strategy_hold_months | 6 | 1-6 | Minimum holding period before rebalance exit. |
| strategy_min_valid_symbols | 5 | 5 | Valid symbols required after DWX matrix validation. |
| strategy_min_warmup_d1 | 160 | 160+ | Minimum D1 history required before ranking. |
| strategy_atr_period | 20 | 10-40 | ATR period for emergency stop placement. |
| strategy_atr_sl_mult | 3.0 | 1.0-5.0 | Emergency stop multiple of ATR(20,D1). |
| strategy_basket_stop_r | 6.0 | 1.0-10.0 | Basket emergency close threshold in R units. |
| strategy_spread_median_days | 60 | 20-90 | D1 spread sample length for spread filter. |
| strategy_spread_median_multiple | 2.0 | 1.0-4.0 | Max current spread versus median spread. |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - S&P 500 index proxy from the card's US large-cap basket; backtest-only at T6 gate.
- NDX.DWX - Nasdaq 100 index proxy from the card's US large-cap basket.
- WS30.DWX - Dow 30 index proxy from the card's US large-cap basket.
- GDAXI.DWX - Matrix-canonical DAX index proxy for the card's GER40.DWX label.
- UK100.DWX - FTSE 100 index proxy from the card's global index basket.

**Explicitly NOT for:**
- GER40.DWX - not present in `dwx_symbol_matrix.csv`; mapped to GDAXI.DWX.
- JP225.DWX - not present in `dwx_symbol_matrix.csv`; no Japan index row registered.
- JPN225.DWX - not present in `dwx_symbol_matrix.csv`; no Japan index row registered.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework D1 chart |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 2 |
| Typical hold time | six months |
| Expected drawdown profile | Concentrated reduced-basket momentum drawdowns, bounded by ATR leg stops and basket 6R emergency stop. |
| Regime preference | Cross-sectional momentum in liquid equity-index trends. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b7832a20-938e-5f24-b9d7-e0b2ab63b623
**Source type:** public implementation / catalog source
**Pointer:** https://github.com/paperswithbacktest/awesome-systematic-trading/blob/main/static/strategies/consistent-momentum-strategy.py
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_12402_cons-mom.md`

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
| v1 | 2026-06-18 | Initial build from card | f8eea69c-2560-4d52-8952-5438595f204a |
