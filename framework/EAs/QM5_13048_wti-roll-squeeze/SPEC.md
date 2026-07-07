# QM5_13048_wti-roll-squeeze - Strategy Spec

**EA ID:** QM5_13048
**Slug:** `wti-roll-squeeze`
**Source:** `CFTC-ETF-ROLL-WTI-2014`
**Author of this spec:** Codex
**Last revised:** 2026-07-08

## 1. Strategy Logic

This EA implements a low-frequency WTI ETF-roll-window compression breakout on
`XTIUSD.DWX`. On each new D1 bar it inspects the previous completed D1 bar. If
that bar falls inside the configured early-month roll window, the EA checks
whether the preceding D1 range was compressed and whether the signal bar closed
outside that range.

A long setup requires an upside close above the pre-signal channel. A short
setup requires a downside close below it. Positions use an ATR hard stop, ATR
target, SMA failure exit, exit-window guard, month-change guard, max-hold exit,
standard V5 news handling, and Friday close. Runtime uses broker D1 OHLC and
calendar state only.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_roll_start_trading_day` | 5 | 4-6 | First broker D1 trading day in the roll-window signal gate |
| `strategy_roll_end_trading_day` | 9 | 8-10 | Last broker D1 trading day in the roll-window signal gate |
| `strategy_exit_last_trading_day` | 12 | 10-14 | Last broker D1 trading day positions may remain open |
| `strategy_compression_lookback` | 8 | 6-12 | Pre-signal D1 bars used for compression channel |
| `strategy_atr_period` | 20 | 14-30 | ATR period for signal sizing and stop/target |
| `strategy_max_compression_atr` | 1.05 | 0.80-1.35 | Maximum channel width in ATR-scaled sqrt(N) units |
| `strategy_min_signal_range_atr` | 0.45 | 0.30-0.70 | Minimum signal-bar range in ATR units |
| `strategy_min_body_ratio` | 0.25 | 0.15-0.40 | Minimum signal-bar body as fraction of range |
| `strategy_min_break_atr` | 0.05 | 0.00-0.15 | Minimum close-through beyond channel in ATR units |
| `strategy_long_min_close_location` | 0.62 | 0.55-0.72 | Minimum close location for long breakout |
| `strategy_short_max_close_location` | 0.38 | 0.28-0.45 | Maximum close location for short breakout |
| `strategy_exit_sma_period` | 20 | 14-30 | SMA failure exit period |
| `strategy_atr_sl_mult` | 2.75 | 2.25-3.50 | ATR stop distance |
| `strategy_atr_tp_mult` | 3.25 | 2.50-4.50 | ATR target distance |
| `strategy_max_hold_days` | 6 | 4-9 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 4-9.
- Direction: symmetric long/short.
- Typical hold: several D1 bars, capped by ATR target/stop, exit window, and
  max-hold exit.
- Regime preference: early-month CFTC ETF-roll windows where pre-window D1
  compression resolves into a closed-bar breakout.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

Official CFTC Office of the Chief Economist paper:

- https://www.cftc.gov/sites/default/files/idc/groups/public/@economicanalysis/documents/file/oce_predatorysunshine0314.pdf

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.

## Evidence

- Build result: `artifacts/qm5_13048_build_result.json`.
- Q02 enqueue: `artifacts/qm5_13048_q02_enqueue_20260708.json`.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-08 | Mission-directed WTI ETF-roll compression breakout build | Enqueue to Q02 |
