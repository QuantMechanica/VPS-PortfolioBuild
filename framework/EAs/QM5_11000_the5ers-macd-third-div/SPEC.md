# QM5_11000_the5ers-macd-third-div - Strategy Spec

**EA ID:** QM5_11000
**Slug:** `the5ers-macd-third-div`
**Source:** `1d445184-7c47-57da-9856-a123682a932d` (see `sources/the5ers-blog`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA trades a D1 reversal setup after three confirmed MACD divergences. It finds swing highs and lows using three bars on each side, then sells when the last three swing highs rise while MACD main values fall, or buys when the last three swing lows fall while MACD main values rise. The latest swing must be confirmed by either price closing beyond the post-swing bar or MACD main being on the reversal side of the signal line. Exits use a 2.0R target, a MACD main/signal momentum cross against the position, or a 20 D1-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_timeframe` | `PERIOD_D1` | D1 for baseline | Base timeframe for swing, MACD, ATR, and hold-time logic. |
| `strategy_macd_fast` | `3` | `>=1` and `< slow` | MACD fast EMA period from the source. |
| `strategy_macd_slow` | `9` | `> fast` | MACD slow EMA period from the source. |
| `strategy_macd_signal` | `7` | `>=1` | MACD signal period from the source. |
| `strategy_swing_left` | `3` | `>=1` | Older-side bars required to confirm a swing point. |
| `strategy_swing_right` | `3` | `>=1` | Newer-side bars required to confirm a swing point. |
| `strategy_swing_min_span_bars` | `15` | `>=1` | Minimum D1 bars between oldest and newest divergence swing. |
| `strategy_swing_max_span_bars` | `120` | `>= min span` | Maximum D1 bars between oldest and newest divergence swing. |
| `strategy_atr_period` | `14` | `>=1` | ATR period used for stop placement and volatility filter. |
| `strategy_sl_atr_mult` | `0.5` | `>0` | ATR buffer beyond the latest divergence swing for SL. |
| `strategy_tp_rr` | `2.0` | `>0` | Take-profit reward/risk multiple. |
| `strategy_atr_percentile_bars` | `250` | `>=50` preferred | Lookback used to reject bottom-volatility ATR regimes. |
| `strategy_atr_percentile_min` | `0.15` | `0.0-1.0` | Minimum ATR percentile allowed for new entries. |
| `strategy_max_hold_bars` | `20` | `>=1` | Maximum D1 bars to hold before time-stop exit. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Major FX pair named by the card and available in the DWX matrix.
- `GBPUSD.DWX` - Major FX pair named by the card and available in the DWX matrix.
- `USDJPY.DWX` - Major FX pair named by the card and available in the DWX matrix.
- `XAUUSD.DWX` - Liquid gold CFD named by the card and available in the DWX matrix.
- `GDAXI.DWX` - DWX matrix DAX proxy used for the card's `GER40.DWX` target.

**Explicitly NOT for:**
- `GER40.DWX` - Card-stated name is not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered DAX equivalent.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `8` |
| Typical hold time | Up to 20 D1 bars, with earlier exits on MACD reversal or 2.0R target. |
| Expected drawdown profile | Sparse reversal entries with catastrophic SL at the divergence swing plus ATR buffer. |
| Regime preference | Reversal after stretched price action with confirmed MACD divergence. |
| Win rate target (qualitative) | Medium; card emphasizes rare but powerful third-divergence reversals. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1d445184-7c47-57da-9856-a123682a932d`
**Source type:** blog
**Pointer:** `https://the5ers.com/macd-divergence-trading-strategy/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11000_the5ers-macd-third-div.md`

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
| v1 | 2026-06-18 | Initial build from card | e32f0844-2e10-4db0-aaf5-acc9ebf497c9 |
