# QM5_10635_et-consol-break - Strategy Spec

**EA ID:** QM5_10635
**Slug:** et-consol-break
**Source:** cf54ceef-f6e7-5fa0-ae03-98d3d4f8fe64 (see `strategy-seeds/sources/cf54ceef-f6e7-5fa0-ae03-98d3d4f8fe64/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA trades M5 consolidation breakouts after the session has been open for at least 30 minutes and before the final 90 minutes of the session. A long signal requires the last closed M5 bar to break above the prior session high by 0.10 ATR(14), with the two prior bars compressed to 0.60 ATR or less and closing inside the previous 30-minute range. Short signals mirror the rule below the prior session low, require tick volume at least 1.20 times the 20-bar average, place the stop beyond the consolidation range by 0.10 ATR, and target 1.6R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_timeframe | PERIOD_M5 | M5 intended | Signal timeframe from the card. |
| strategy_atr_period | 14 | >=1 | ATR period used for compression, buffer, and overextension checks. |
| strategy_consolidation_bars | 2 | 2-4 | Number of compressed bars immediately before breakout. |
| strategy_prior_range_bars | 6 | >=1 | M5 bars used for the prior 30-minute range. |
| strategy_range_atr_mult | 0.60 | 0.40-0.80 | Maximum consolidation bar range as ATR multiple. |
| strategy_breakout_atr_mult | 0.10 | 0.05-0.20 | Breakout and stop buffer as ATR multiple. |
| strategy_volume_mult | 1.20 | 1.0-1.5 | Required tick-volume multiple versus SMA. |
| strategy_volume_sma_bars | 20 | >=1 | Tick-volume SMA lookback. |
| strategy_tp_rr | 1.60 | 1.2-2.0 | Primary take-profit in R multiples. |
| strategy_time_exit_bars | 18 | >=1 | Maximum holding time in M5 bars. |
| strategy_max_session_move_atr | 2.50 | >0 | Skip entries after an overextended session move. |
| strategy_spread_stop_fraction | 0.20 | 0-1 | Maximum spread as fraction of stop distance. |
| strategy_session_open_hhmm | 0 | 0000-2359 | Broker-time session open used for extremes. |
| strategy_session_close_hhmm | 2359 | 0000-2359 | Broker-time session close used for entry and exit gating. |
| strategy_start_after_minutes | 30 | >=0 | Delay after session open before entries are allowed. |
| strategy_stop_before_close_min | 90 | >=0 | No new entries this many minutes before session close. |
| strategy_pending_expiry_bars | 1 | >=1 | Stop-order expiry in signal bars if price is not through the trigger. |
| strategy_history_bars | 360 | >=40 | Bounded bar window for session/range/volume scans. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- NDX.DWX - Nasdaq 100 intraday index CFD fits the card's liquid breakout basket.
- SP500.DWX - S&P 500 custom symbol is available for backtest-only index breakout validation.
- GDAXI.DWX - DAX custom symbol is the matrix-verified DWX port for the card's GER40 target.
- XAUUSD.DWX - Gold CFD has intraday OHLC and tick volume for consolidation breakouts.

**Explicitly NOT for:**
- GER40.DWX - Card target name is not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- SPX500.DWX - Not a canonical DWX symbol; use `SP500.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | Up to 18 M5 bars, about 90 minutes |
| Expected drawdown profile | Stop is beyond the consolidation range; false breakouts should be bounded by fixed 1R losses. |
| Regime preference | Intraday volatility-expansion breakout after compression |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** cf54ceef-f6e7-5fa0-ae03-98d3d4f8fe64
**Source type:** forum
**Pointer:** https://www.elitetrader.com/et/threads/breakouts-breakdowns-how-do-u-trade-them.3813/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10635_et-consol-break.md`

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
| v1 | 2026-06-13 | Initial build from card | 9f9ff214-8bbc-4ce1-a50e-033cb9867cbc |
