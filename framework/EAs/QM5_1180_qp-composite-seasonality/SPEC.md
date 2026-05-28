# QM5_1180 qp-composite-seasonality

## Scope
- V5 build for approved card `QM5_1180_qp-composite-seasonality`.
- Long-only `SP500.DWX` composite calendar strategy.
- No backtests or pipeline phases are part of this build.

## Strategy Mapping
- Entry: on the new D1 bar, evaluates the completed D1 close. Opens one aggregate long if any composite calendar signal is active and completed D1 close is above SMA(200).
- Calendar signals: turn-of-month, FOMC meeting window, option-expiration week, payday window.
- Exit: closes when the completed D1 bar has no active calendar signal, when close is below SMA(200), or after 10 completed D1 bars.
- Risk: baseline fixed-risk backtest via `RISK_FIXED=1000`; live set uses `RISK_PERCENT=0.25`.
- Stop: ATR(20) x 2.0 initial stop; P3 set disables ATR stop for calendar/SMA-only variant.

## Framework Alignment
- No-Trade: central V5 kill-switch/news/Friday-close plus symbol/timeframe/spread gates.
- Entry: `Strategy_EntrySignal`.
- Management: no trailing, break-even, pyramiding, or partial close.
- Close: `Strategy_ExitSignal`.
- Magic: `QM_MagicResolver` via `qm_ea_id=1180`, `qm_magic_slot_offset=0`.

## Live Caveat
`SP500.DWX` is a backtest-only proxy per the card. T6 promotion requires parallel validation on a broker-routable proxy such as `NDX.DWX` or `WS30.DWX` before AutoTrading enable.
