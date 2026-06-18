# QM5_12399_stock-newhigh — Strategy Spec

**EA ID:** QM5_12399
**Slug:** `stock-newhigh`
**Source:** `b7832a20-938e-5f24-b9d7-e0b2ab63b623`
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA trades a long-only D1 breakout. On each closed D1 bar, it compares the latest close with the highest close over the configured prior D1 lookback window. If the latest close is greater than or equal to that prior high, and the warmup, ATR, and spread checks are valid, it opens one long position with a 1.0 x ATR(10) stop. While a position is open, the stop is advanced upward once per closed D1 bar to `Close - ATR(10)`.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_new_high_lookback` | 520 | 252-520+ | Prior D1 closes used to define the breakout high. |
| `strategy_min_warmup_bars` | 520 | 520+ | Minimum D1 bars required before entries are allowed. |
| `strategy_atr_period` | 10 | 10-20 | ATR lookback for the initial and trailing stop. |
| `strategy_atr_mult` | 1.0 | 1.0-2.0 | ATR multiplier for the stop distance. |
| `strategy_spread_median_days` | 60 | 1+ | D1 spread window used by the card's median-spread cap. |
| `strategy_spread_cap_mult` | 2.0 | 1.0+ | Maximum current spread as a multiple of the 60D median spread. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — S&P 500 custom symbol matching the card's US large-cap index port.
- `NDX.DWX` — Nasdaq 100 index CFD for US large-cap trend exposure.
- `WS30.DWX` — Dow 30 index CFD for US large-cap trend exposure.
- `GDAXI.DWX` — DAX custom symbol used as the available DWX equivalent for card-stated `GER40.DWX`.
- `XAUUSD.DWX` — gold commodity CFD from the card's approved portable universe.
- `XTIUSD.DWX` — crude oil commodity CFD from the card's approved portable universe.

**Explicitly NOT for:**
- `GER40.DWX` — not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is registered instead.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` — unavailable S&P variants; `SP500.DWX` is the canonical custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the framework skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `8` |
| Typical hold time | multi-day to multi-week trend-following holds |
| Expected drawdown profile | Long flat periods and whipsaws after extended breakouts. |
| Regime preference | breakout / trend-following |
| Win rate target (qualitative) | low to medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b7832a20-938e-5f24-b9d7-e0b2ab63b623`
**Source type:** public implementation / catalog source
**Pointer:** `https://github.com/paperswithbacktest/awesome-systematic-trading/blob/main/static/strategies/trend-following-effect-in-stocks.py`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12399_stock-newhigh.md`

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
| v1 | 2026-06-18 | Initial build from card | 41c947c6-28a8-433d-8576-48e345948dcd |
