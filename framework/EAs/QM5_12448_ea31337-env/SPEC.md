# QM5_12448_ea31337-env - Strategy Spec

**EA ID:** QM5_12448
**Slug:** `ea31337-env`
**Source:** `041e0d5c-bf76-501d-bee2-31c0f4a6e233` (see `strategy-seeds/sources/041e0d5c-bf76-501d-bee2-31c0f4a6e233/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA trades EA31337-style Envelopes reentry on closed H1 bars. A long setup requires the lowest low across the latest three closed bars to have traded below the lower envelope, the lower envelope to have risen by at least the source threshold over the three-bar window, and a four-bar reentry mask to confirm price has moved back into the lower half of the envelope. A short setup mirrors that logic above the upper envelope with the upper envelope falling by the threshold. Exits use fixed SL/TP from ATR risk, a 30-bar time stop, and early close on the opposite envelope reentry signal.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_env_period` | 20 | 2-500 | Envelopes moving-average period from the source default. |
| `strategy_env_deviation` | 0.1 | >0 | Envelopes deviation percent from the source default. |
| `strategy_env_method` | `MODE_SMA` | MT5 MA methods | Moving-average method; card states SMA. |
| `strategy_env_price` | `PRICE_CLOSE` | MT5 applied prices | Applied price; card states close price. |
| `strategy_signal_open_level` | 0.001 | >=0 | Percent-change threshold for envelope direction confirmation. |
| `strategy_signal_mask_bars` | 4 | 1-20 | Source four-signal confirmation window. |
| `strategy_atr_period` | 14 | 2-200 | ATR period for protective stop placement. |
| `strategy_atr_sl_mult` | 2.0 | >0 | ATR multiplier for SL, matching source price stop level 2. |
| `strategy_rr_take_profit` | 1.0 | >0 | Fixed TP as a multiple of SL risk. |
| `strategy_max_hold_bars` | 30 | 1-500 | Source `OrderCloseTime=-30` translated to 30 bars. |
| `strategy_max_spread_pips` | 4 | >=0 | Source maximum spread cap in pips. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid forex major.
- `GBPUSD.DWX` - card-listed liquid forex major.
- `USDJPY.DWX` - card-listed liquid forex major.
- `XAUUSD.DWX` - card-listed metal CFD with OHLC envelope portability.
- `GDAXI.DWX` - verified DWX DAX equivalent for the card's `DAX.DWX` label.

**Explicitly NOT for:**
- `DAX.DWX` - not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `100` |
| Expected trade frequency | `not specified in card frontmatter` |
| Typical hold time | `up to 30 H1 bars unless SL/TP or opposite signal exits first` |
| Expected drawdown profile | `not specified in card frontmatter` |
| Regime preference | `mean-reversion / envelope-reentry` |
| Win rate target (qualitative) | `not specified in card frontmatter` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `041e0d5c-bf76-501d-bee2-31c0f4a6e233`
**Source type:** `GitHub repository`
**Pointer:** `https://github.com/EA31337/Strategy-Envelopes/blob/master/Stg_Envelopes.mqh`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12448_ea31337-env.md`

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
| v1 | 2026-06-18 | Initial build from card | 6a68b605-1b36-413f-a464-4b5901eb61fe |
