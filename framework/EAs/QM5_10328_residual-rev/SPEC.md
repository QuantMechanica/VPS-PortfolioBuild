# QM5_10328_residual-rev - Strategy Spec

**EA ID:** QM5_10328
**Slug:** `residual-rev`
**Source:** `fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9` (see SSRN abstract 4731947)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

On each M30 bar in the liquid U.S./Europe overlap session, the EA measures the just-closed bar return for the chart index and the median return of the registered index basket. It estimates a rolling same-slot beta over the prior 20 trading days, computes `symbol_return - beta * basket_median_return`, and trades a reversal when that residual is large relative to ATR. A negative residual opens a long, a positive residual opens a short, and only the basket member with the largest qualifying absolute residual is allowed to trade. Positions use a 0.75 ATR stop and close by time stop after the next M30 bar.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_M30` | M30 expected | Signal and trade timeframe. |
| `strategy_session_start_hhmm` | `1530` | 0000-2359 | Start of the cash-session window in broker time. |
| `strategy_session_end_hhmm` | `2200` | 0000-2359 | End of the cash-session window in broker time. |
| `strategy_slot_minutes` | `30` | >0 | Slot length for entry and time stop. |
| `strategy_same_slot_bars_per_day` | `48` | >0 | M30 shift spacing used for same-slot prior-day samples. |
| `strategy_beta_days` | `20` | >=12 | Prior same-slot observations requested for beta. |
| `strategy_min_beta_observations` | `12` | 1-20 | Minimum valid observations before a signal is valid. |
| `strategy_min_basket_symbols` | `3` | 3-4 | Minimum valid basket symbols for median return. |
| `strategy_atr_period` | `14` | >0 | ATR period on M30. |
| `strategy_residual_atr_mult` | `0.35` | >0 | Residual trigger threshold as ATR/close return multiple. |
| `strategy_stop_atr_mult` | `0.75` | >0 | Stop distance in ATR multiples. |
| `strategy_spread_lookback_days` | `20` | >=12 | Same-slot spread samples for percentile filter. |
| `strategy_spread_percentile` | `80.0` | 0-100 | Maximum allowed current spread percentile. |
| `strategy_basket_warmup_bars` | `1800` | >0 | Bars preloaded for basket symbols in MT5 tester. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 custom symbol, matching the card's U.S. index basket.
- `NDX.DWX` - Nasdaq 100 index CFD, part of the U.S. large-cap basket.
- `WS30.DWX` - Dow 30 index CFD, part of the U.S. large-cap basket.
- `GDAXI.DWX` - DAX proxy available in `dwx_symbol_matrix.csv`; used for the card's unavailable `GER40.DWX`.

**Explicitly NOT for:**
- `GER40.DWX` - Card-stated name is not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the available DAX symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `150` |
| Typical hold time | One M30 bar |
| Expected drawdown profile | Intraday mean-reversion losses cluster during persistent index shocks. |
| Regime preference | Intraday residual mean-reversion / liquidity-provision regime |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9`
**Source type:** `paper`
**Pointer:** `https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4731947`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10328_residual-rev.md`

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
| v1 | 2026-06-12 | Initial build from card | c9da8748-6479-4a90-b781-ac5409463444 |
