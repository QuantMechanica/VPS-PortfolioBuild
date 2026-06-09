# QM5_10223_tv-bb-wd-break - Strategy Spec

**EA ID:** QM5_10223
**Slug:** `tv-bb-wd-break`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

Long-only Bollinger breakout on the selected signal timeframe, default H4. The EA enters when the last closed bar closes strictly above the upper Bollinger Band, closes above EMA55, closes above the bar two closes earlier, has total wick length at least 10 times its real body, and its upper shadow is no more than 3 times its lower shadow. Entries are blocked during configured weak calendar windows or frozen quarter-month buckets, and exits trigger when the last closed bar closes below the lower Bollinger Band or enters a configured forced-exit seasonality bucket.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_H4` | H4 or D1 intended | Timeframe used for BB, EMA, ATR, wick/body, and close-vs-close[2] rules. |
| `strategy_bb_period` | 20 | >1 | Bollinger Band lookback period. |
| `strategy_bb_deviation` | 2.0 | >0 | Bollinger Band standard-deviation multiplier. |
| `strategy_trend_ema_period` | 55 | >1 | Trend EMA period; close must be above it. |
| `strategy_atr_period` | 14 | >0 | ATR period for the initial stop. |
| `strategy_atr_stop_mult` | 0.20 | >0 | Baseline ATR stop multiplier from the card. |
| `strategy_cooldown_bars` | 1 | >=0 | Minimum signal bars between entries after an accepted signal. |
| `strategy_min_wick_body_x` | 10.0 | >0 | Minimum total wick length divided by real body. |
| `strategy_upper_lower_max_x` | 3.0 | >0 | Maximum upper-shadow to lower-shadow ratio. |
| `strategy_time_filter_enabled` | false | true/false | Enables optional broker-hour entry blocking. |
| `strategy_trade_start_hour` | 0 | 0-23 | Inclusive broker start hour when time filter is enabled. |
| `strategy_trade_end_hour` | 24 | 0-24 | Exclusive broker end hour when time filter is enabled. |
| `strategy_max_spread_points` | 0.0 | >=0 | Optional spread cap in points; 0 disables it. |
| `strategy_seasonal_windows_enabled` | false | true/false | Enables fixed date-window entry blocks and exits. |
| `strategy_bad_start_month` | 5 | 1-12 | Start month for the fixed weak-season window. |
| `strategy_bad_start_day` | 1 | 1-31 | Start day for the fixed weak-season window. |
| `strategy_bad_end_month` | 10 | 1-12 | End month for the fixed weak-season window. |
| `strategy_bad_end_day` | 31 | 1-31 | End day for the fixed weak-season window. |
| `strategy_qmonth_matrix_enabled` | false | true/false | Enables frozen quarter-month bucket lists. |
| `strategy_block_qmonths` | `""` | CSV of `MQ` buckets | Entry-block buckets, encoded as month*10+quarter, e.g. `52` for May days 8-14. |
| `strategy_exit_qmonths` | `""` | CSV of `MQ` buckets | Forced-exit buckets, encoded as month*10+quarter. |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Nasdaq 100 index exposure from the approved card basket.
- `GDAXI.DWX` - DAX 40 proxy; used because `GER40.DWX` is not in the DWX matrix.
- `WS30.DWX` - Dow 30 index exposure from the approved card basket.
- `SP500.DWX` - S&P 500 custom symbol; valid for backtest, with live-promotion caveat.
- `XAUUSD.DWX` - Gold CFD exposure from the approved card basket.

**Explicitly NOT for:**
- Symbols outside the registered list above - no implicit universe expansion.
- `GER40.DWX` - unavailable in `dwx_symbol_matrix.csv`; ported to `GDAXI.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none by default; `strategy_signal_tf` can be set to D1 |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 45 |
| Expected trade frequency | about 45 breakout entries per symbol per year |
| Typical hold time | multi-bar, from H4 to several days depending on BB exit or ATR stop |
| Expected drawdown profile | bounded by RISK_FIXED and the tight 0.2 ATR baseline stop |
| Regime preference | volatility-expansion breakout with positive trend filter |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView script
**Pointer:** `https://www.tradingview.com/script/JygL0tF0/` and `artifacts/cards_approved/QM5_10223_tv-bb-wd-break.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10223_tv-bb-wd-break.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-09 | Initial build from card | 8008811d-cab7-4ec4-a36e-f4c24e21a71c |
| v1-refresh | 2026-06-10 | Rebuilt in place from approved card | 8008811d-cab7-4ec4-a36e-f4c24e21a71c |
