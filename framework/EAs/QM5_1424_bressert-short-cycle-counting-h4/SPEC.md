# QM5_1424_bressert-short-cycle-counting-h4 - Strategy Spec

**EA ID:** QM5_1424
**Slug:** bressert-short-cycle-counting-h4
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-07-07

---

## 1. Strategy Logic

This EA sells a projected H4 cycle crest. It finds significant Williams 5-bar high pivots over the last 800 H4 bars, requires at least six pivots, requires the crest-to-crest median cycle to be between 20 and 120 H4 bars, and rejects cycles whose IQR/median exceeds 0.40.

Entry is a market sell on the bar after the closed H4 reversal bar, only when bars since the last significant crest are inside 0.75-1.30x the median cycle, the rally from the post-crest low is at least 1.5 ATR, the rally retracement is 38.2%-78.6%, the current bar is a local cycle high, and the D1 SMA(100) slope is flat or falling within the allowed tolerance. The initial stop is the signal high plus 0.5 ATR, capped at 2.5 ATR from entry; the take profit is 0.80x the prior cycle amplitude below entry. The EA partially closes 50% at halfway to target and moves the stop to break-even; it exits on time stop or if the first eight H4 bars close above the failure level.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_cycle_window_bars | 800 | 100+ | H4 lookback for significant crest history. |
| strategy_atr_period | 14 | 1+ | ATR period used for pivot significance, stop buffer, spread gate, and D1 macro slope scaling. |
| strategy_pivot_side_bars | 2 | fixed 2 | Williams 5-bar high-pivot side length. |
| strategy_pivot_swing_window | 20 | 1+ | Half-window used to find the local low around each high pivot. |
| strategy_pivot_atr_mult | 2.5 | 0+ | Minimum high-pivot amplitude versus ATR. |
| strategy_min_pivots | 6 | 2+ | Minimum significant high pivots required for cycle statistics. |
| strategy_iqr_max_ratio | 0.40 | 0+ | Maximum IQR/median cycle dispersion. |
| strategy_cycle_min_bars | 20 | 1+ | Minimum median cycle length in H4 bars. |
| strategy_cycle_max_bars | 120 | 1+ | Maximum median cycle length in H4 bars. |
| strategy_projection_min_mult | 0.75 | 0+ | Lower bound of bars-since-last-crest divided by median cycle. |
| strategy_projection_max_mult | 1.30 | 0+ | Upper bound of bars-since-last-crest divided by median cycle. |
| strategy_rally_atr_mult | 1.5 | 0+ | Required rally from post-crest low in ATR units. |
| strategy_retrace_min | 0.382 | 0-1 | Minimum rally retracement fraction. |
| strategy_retrace_max | 0.786 | 0-1 | Maximum rally retracement fraction. |
| strategy_local_high_cycle_frac | 0.20 | 0+ | Fraction of median cycle used for local-high confirmation. |
| strategy_tp_amplitude_mult | 0.80 | 0+ | Prior-cycle amplitude fraction projected downward for TP. |
| strategy_partial_close_fraction | 0.50 | 0-1 | Fraction of open volume to close at partial target. |
| strategy_partial_move_fraction | 0.50 | 0-1 | Fraction of entry-to-TP move that triggers partial close. |
| strategy_time_exit_cycle_mult | 1.50 | 0+ | Cycle multiple used for the timing hard exit. |
| strategy_time_exit_max_bars | 60 | 1+ | Maximum H4 bars held. |
| strategy_failure_first_bars | 8 | 0+ | Number of initial H4 bars where pattern-failure exit applies. |
| strategy_sl_atr_mult | 0.5 | 0+ | ATR buffer above signal high for initial SL and failure level. |
| strategy_sl_max_atr_mult | 2.5 | 0+ | Maximum initial SL distance from entry in ATR units. |
| strategy_spread_atr_mult | 0.25 | 0+ | Blocks entry only when positive spread exceeds this ATR fraction. |
| strategy_macro_sma_period | 100 | 1+ | D1 SMA period for macro-bias gate. |
| strategy_macro_slope_bars | 20 | 1+ | D1 bars used to measure SMA slope. |
| strategy_macro_slope_atr_mult | 0.03 | 0+ | Allowed upward D1 SMA slope per bar in ATR units. |
| strategy_news_blackout_h4_bars | 2 | 0+ | High-impact news blackout on each side, expressed in H4 bars. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - standard FX major with H4 history and no volume dependency.
- GBPUSD.DWX - standard FX major with H4 history and no volume dependency.
- USDJPY.DWX - standard FX major with H4 history and no volume dependency.
- USDCHF.DWX - standard FX major with H4 history and no volume dependency.
- USDCAD.DWX - standard FX major with H4 history and no volume dependency.
- AUDUSD.DWX - standard FX major with H4 history and no volume dependency.
- NZDUSD.DWX - standard FX major with H4 history and no volume dependency.
- XAUUSD.DWX - card-listed gold CFD with H4 price structure and no volume gate.
- XTIUSD.DWX - card's oil CFD target mapped to the available DWX crude symbol.
- NDX.DWX - card-listed DWX index CFD.
- WS30.DWX - card-listed DWX index CFD.
- GDAXI.DWX - card-listed DAX DWX index CFD.
- UK100.DWX - card-listed FTSE DWX index CFD.

**Explicitly NOT for:**
- SPX500.DWX, SPY.DWX, ES.DWX - unavailable or non-canonical S&P aliases in the DWX matrix.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no tester tick data.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | D1 SMA(100) and D1 ATR(14) for macro-bias slope gate |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the framework entry path |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | Up to min(1.50 x median cycle, 60 H4 bars), with median cycle constrained to 20-120 H4 bars |
| Expected drawdown profile | ATR-capped short mean-reversion drawdowns, reduced by D1 flat-or-falling macro-bias filter |
| Regime preference | Mean-reversion after projected H4 cycle crests |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum/book lineage
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1424_bressert-short-cycle-counting-h4.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_1424_bressert-short-cycle-counting-h4.md`

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
| v1 | 2026-07-07 | Initial build from card | 6cba1cd2-447f-4523-afc7-3c7a81bbb7be |
