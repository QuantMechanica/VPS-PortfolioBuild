# QM5_12405_stock-cycle12 — Strategy Spec

**EA ID:** QM5_12405
**Slug:** `stock-cycle12`
**Source:** `b7832a20-938e-5f24-b9d7-e0b2ab63b623` (see approved card source citation)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA evaluates once per completed month using D1 bars as the monthly-bar proxy. For each registered index CFD, it builds monthly closes and computes the one-month return that occurred 12 months ago. It ranks the verified basket by that old monthly return, buys the strongest symbol bucket, shorts the weakest symbol bucket, and closes positions at the next monthly rebalance when the symbol is no longer selected or changes side.

Stops are emergency ATR stops per leg: `3.0 * ATR(20, D1)`. A basket emergency stop closes all open legs from this EA if combined open drawdown exceeds `6R`.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_cycle_offset_months` | 12 | 11-13 | Month offset for the historical cycle-return signal. |
| `strategy_return_window_months` | 1 | 1-2 | Number of months in the old return window. |
| `strategy_bucket_size` | 1 | 1-2 for the verified five-symbol basket | Number of strongest and weakest symbols selected at rebalance. |
| `strategy_min_valid_symbols` | 5 | 2-5 | Minimum verified symbols with valid monthly history before trading. |
| `strategy_warmup_months` | 14 | 14+ | Required monthly close history before a symbol can be ranked. |
| `strategy_atr_period` | 20 | 5-100 | D1 ATR period for emergency stop placement. |
| `strategy_atr_sl_mult` | 3.0 | 0.5-10.0 | ATR multiple for each leg's emergency stop. |
| `strategy_basket_stop_r` | 6.0 | 0.0-20.0 | Combined open drawdown threshold in per-leg R units; 0 disables. |
| `strategy_spread_lookback_days` | 60 | 1-256 | D1 spread sample length for the median spread gate. |
| `strategy_spread_mult` | 2.0 | 0.0-10.0 | Blocks new entries only when non-zero spread exceeds this multiple of median spread. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — S&P 500 custom symbol, verified in the DWX matrix and required by the US large-cap basket.
- `NDX.DWX` — Nasdaq 100 index CFD, verified in the DWX matrix and part of the US large-cap basket.
- `WS30.DWX` — Dow 30 index CFD, verified in the DWX matrix and part of the US large-cap basket.
- `GDAXI.DWX` — verified DAX custom symbol used as the available DAX exposure because `GER40.DWX` and `DE30.DWX` are not in the matrix.
- `UK100.DWX` — FTSE 100 index CFD, verified in the DWX matrix and part of the global index basket.

**Explicitly NOT for:**
- `GER40.DWX` — not present in `framework/registry/dwx_symbol_matrix.csv`; mapped to `GDAXI.DWX`.
- `JP225.DWX` — not present in `framework/registry/dwx_symbol_matrix.csv`; no Nikkei substitute was registered.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none; D1 is used as a monthly proxy because MN1 is unavailable in the tester |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_D1)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `12` |
| Typical hold time | One monthly rebalance interval |
| Expected drawdown profile | Fragile seasonality/cycle rank with basket-level emergency stop at 6R |
| Regime preference | Seasonality and cross-sectional momentum |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b7832a20-938e-5f24-b9d7-e0b2ab63b623`
**Source type:** public GitHub / Quantpedia implementation
**Pointer:** `https://github.com/paperswithbacktest/awesome-systematic-trading/blob/main/static/strategies/12-month-cycle-in-cross-section-of-stocks-returns.py`
**R1–R4 verdict (Q00):** all R1–R4 PASS per `artifacts/cards_approved/QM5_12405_stock-cycle12.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-18 | Initial build from card | 0782ae03-427d-4eb5-a748-e269e138cfb3 |
