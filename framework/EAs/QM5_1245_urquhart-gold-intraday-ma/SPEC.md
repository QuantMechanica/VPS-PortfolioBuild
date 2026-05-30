# QM5_1245 urquhart-gold-intraday-ma

## Scope

Build-only V5 EA for APPROVED Strategy Card `QM5_1245_urquhart-gold-intraday-ma`.

## Card Mapping

- Universe: `XAUUSD.DWX`.
- Timeframe: `M15`.
- Entry: on a closed M15 bar, go long when SMA(20) crosses above SMA(160), and go short when SMA(20) crosses below SMA(160).
- Session: entries are allowed only from 07:00 through before 22:00 broker time.
- Initial stop: hard stop at `2.0 * ATR(96)`.
- Trade management: optional P3 trailing stop is enabled by default; after unrealized profit reaches `+1R`, stop trails by `1.5 * ATR(96)`.
- Exit: opposite SMA(20)/SMA(160) cross, max hold of 48 M15 bars, framework Friday close, or broker stop.
- News: V5 news mode is exposed as `qm_news_mode`; default setfiles keep it off unless the deterministic news table workflow enables it.

## Symbols and Slots

| Slot | Symbol |
| ---: | --- |
| 0 | XAUUSD.DWX |

## Parameters

- `strategy_timeframe=PERIOD_M15`
- `strategy_fast_sma_period=20`
- `strategy_slow_sma_period=160`
- `strategy_atr_period=96`
- `strategy_initial_stop_atr=2.0`
- `strategy_use_trailing_stop=true`
- `strategy_trail_trigger_r=1.0`
- `strategy_trail_atr_mult=1.5`
- `strategy_max_hold_bars=48`
- `strategy_session_start_hour=7`
- `strategy_session_end_hour=22`

## Build Boundary

No backtests or pipeline phases are part of this build.
