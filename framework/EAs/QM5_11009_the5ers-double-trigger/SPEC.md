# QM5_11009_the5ers-double-trigger - Strategy Spec

**EA ID:** QM5_11009
**Slug:** the5ers-double-trigger
**Source:** 1d445184-7c47-57da-9856-a123682a932d (see `strategy-seeds/sources/1d445184-7c47-57da-9856-a123682a932d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA trades H1 double-top and double-bottom reversals. A double top requires two confirmed swing highs 5 to 60 bars apart within 0.50 ATR of each other, an intervening confirmed swing low at least 1.0 ATR below both highs, price above a rising EMA(100), and a closed H1 candle breaking below the intervening swing low by 0.20 ATR with a body at least 40% of its range. A double bottom mirrors the same logic below a falling EMA(100), using two swing lows and an intervening swing high. Stops sit 0.35 ATR beyond the paired extreme, targets use 1.8R, and discretionary exits occur when price closes back beyond the trigger line or after 48 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_fractal_side | 3 | 1-10 | Swing confirmation bars on each side of the center bar. |
| strategy_ema_period | 100 | 10-300 | EMA period for prior-trend filtering. |
| strategy_ema_slope_bars | 30 | 1-100 | Bars used to confirm EMA slope direction. |
| strategy_atr_period | 14 | 2-100 | ATR period for pattern tolerance, trigger break, and stop buffer. |
| strategy_pair_min_bars | 5 | 1-60 | Minimum bars between the two tops or bottoms. |
| strategy_pair_max_bars | 60 | 5-200 | Maximum bars between the two tops or bottoms. |
| strategy_top_tol_atr | 0.50 | 0.10-2.00 | Maximum ATR-normalized difference between the two extremes. |
| strategy_trigger_sep_atr | 1.00 | 0.10-5.00 | Minimum ATR-normalized distance from both extremes to the trigger line. |
| strategy_break_atr | 0.20 | 0.00-2.00 | Required close-through distance beyond the trigger line. |
| strategy_sl_buffer_atr | 0.35 | 0.00-2.00 | Stop buffer beyond the paired extreme. |
| strategy_tp_rr | 1.80 | 0.50-5.00 | Take-profit multiple of initial stop distance. |
| strategy_break_body_frac | 0.40 | 0.00-1.00 | Minimum break candle body as a fraction of candle range. |
| strategy_max_hold_bars | 48 | 1-240 | Maximum holding period in H1 bars. |
| strategy_scan_bars | 80 | 20-250 | Closed-bar window scanned for confirmed swing structures. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - The source context is forex reversal trading and this pair has H1 OHLC, EMA, ATR, and swing data in DWX.
- GBPUSD.DWX - Portable major FX pair with the same H1 reversal structure and DWX data coverage.
- USDJPY.DWX - Portable major FX pair with H1 OHLC, EMA, ATR, and swing data in DWX.
- XAUUSD.DWX - Card-approved metal target with H1 OHLC, EMA, ATR, and swing data in DWX.
- GDAXI.DWX - DAX proxy used because the card-stated GER40.DWX is absent from `dwx_symbol_matrix.csv`.

**Explicitly NOT for:**
- GER40.DWX - Card-stated name is not present in `framework/registry/dwx_symbol_matrix.csv`; GDAXI.DWX is the registered DAX equivalent.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 |
| Typical hold time | Up to 48 H1 bars |
| Expected drawdown profile | Reversal strategy with defined 1R stop and 1.8R target; losses cluster during persistent trends. |
| Regime preference | Reversal after trend exhaustion and trigger-line breakout confirmation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1d445184-7c47-57da-9856-a123682a932d
**Source type:** article
**Pointer:** https://the5ers.com/five-powerful-reversal-patterns-every-trader-must-know/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11009_the5ers-double-trigger.md`

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
| v1 | 2026-06-18 | Initial build from card | 674783fe-a86f-44a7-8e82-9196fca58551 |
