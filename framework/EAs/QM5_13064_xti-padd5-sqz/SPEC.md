# QM5_13064_xti-padd5-sqz - Strategy Spec

**EA ID:** QM5_13064
**Slug:** `xti-padd5-sqz`
**Source:** `EIA-XTI-PADD5-SQZ-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-08

## 1. Strategy Logic

This EA implements a low-frequency WTI West Coast PADD 5 crude-stock squeeze
setup on `XTIUSD.DWX`. On each new D1 bar it inspects the previous completed
D1 bar, requiring that bar to be Thursday or Friday in broker time and inside
the May-October West Coast stockdraw pressure window. It consumes at most one
signal per broker-calendar month.

Entries require a compressed prior D1 context, a bullish ATR-sized WPSR proxy
reaction, upper-range close location, close above the prior context high, close
above a rising `SMA(80)`, fast-over-slow `SMA(80) > SMA(160)` trend
confirmation, and fixed single-symbol WTI scope. Positions use ATR hard stop,
ATR target, SMA trend-failure exit, seasonal invalidation, max-hold exit,
standard V5 news and Friday close handling, and no runtime external data.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_season_start_month` | 5 | 4-6 | First West Coast stockdraw squeeze month |
| `strategy_season_end_month` | 10 | 9-11 | Last West Coast stockdraw squeeze month |
| `strategy_report_start_dow` | 4 | 3-4 | First broker day-of-week for post-WPSR proxy window |
| `strategy_report_end_dow` | 5 | 4-5 | Last broker day-of-week for post-WPSR proxy window |
| `strategy_context_lookback` | 12 | 8-18 | Prior D1 bars used for breakout context |
| `strategy_compression_lookback` | 7 | 5-10 | Prior D1 bars used for compression check |
| `strategy_max_compression_atr` | 1.65 | 1.2-2.2 | Maximum compressed prior range in ATR units |
| `strategy_max_open_extension_atr` | 0.30 | 0.10-0.50 | Reject opens already far above context high |
| `strategy_sma_period` | 80 | 55-100 | Fast D1 trend filter period |
| `strategy_slow_sma_period` | 160 | 120-220 | Slow D1 trend filter period |
| `strategy_sma_slope_shift` | 8 | 4-12 | Completed D1 bars used for fast SMA slope confirmation |
| `strategy_atr_period` | 20 | 14-30 | ATR period for signal sizing and stop/target |
| `strategy_min_range_atr` | 0.55 | 0.40-0.85 | Minimum signal-bar range in ATR units |
| `strategy_min_body_atr` | 0.16 | 0.08-0.28 | Minimum bullish signal-bar body in ATR units |
| `strategy_min_close_location` | 0.66 | 0.56-0.80 | Minimum close location within signal-bar range |
| `strategy_breakout_buffer_atr` | 0.03 | 0.00-0.12 | Required close distance above context high |
| `strategy_atr_sl_mult` | 2.70 | 2.0-3.6 | ATR stop distance |
| `strategy_atr_tp_mult` | 2.45 | 1.8-3.4 | ATR target distance |
| `strategy_max_hold_days` | 7 | 4-11 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 3-6.
- Direction: long only.
- Typical hold: several D1 bars, capped by ATR target/stop, SMA trend-failure,
  stale-position, and seasonal invalidation guards.
- Regime preference: May-October West Coast/PADD 5 stockdraw squeeze windows,
  with Thursday/Friday lag after WPSR publication.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

U.S. Energy Information Administration West Coast PADD 5 crude stocks and WPSR:

- https://www.eia.gov/dnav/pet/hist/LeafHandler.ashx?f=W&n=PET&s=WCESTP51
- https://www.eia.gov/dnav/pet/pet_stoc_wstk_dcu_r50_w.htm
- https://www.eia.gov/petroleum/supply/weekly/

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
