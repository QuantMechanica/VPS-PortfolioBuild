# QM5_1182 qp-ecb-d0-dax-short

## Strategy

Quantpedia ECB announcement-day DAX fade. On embedded ECB press-conference dates, the EA opens a short `GER40.DWX` position at the configured cash-session open proxy and exits at the same-day cash-session close proxy.

## Framework Alignment

- No-Trade: V5 kill switch, news, Friday-close, M15 timeframe, symbol, spread, D1 history, optional gap, and no-open-1181-position gates.
- Entry: short-only `GER40.DWX` when today is an embedded ECB D0 date and broker time is inside the open-to-close window.
- Management: no trailing, partial, or break-even logic.
- Close: same-day configured cash-session close, with next-day safety exit if intraday close mapping is missed after entry.
- Risk: `RISK_FIXED=1000` for backtest sets; `RISK_PERCENT=0.25` for live set.
- Magic: `ea_id=1182`, slot `0`, `GER40.DWX`, magic `11820000`.

## Calendar

The ECB press-conference calendar is embedded in the EA for deterministic backtests and live operation without web/API calls. Broker-session mapping is represented by configurable broker-time cash-open and cash-close inputs.

## Build Boundary

No backtests or pipeline phases are part of this build. The checked-in EA folder contains only build artifacts, setfiles, this spec, and the approved strategy-card copy.
