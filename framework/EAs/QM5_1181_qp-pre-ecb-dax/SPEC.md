# QM5_1181 qp-pre-ecb-dax

## Strategy

Quantpedia Pre-ECB DAX Drift. On confirmed ECB press-conference windows, the EA opens a long `GER40.DWX` position immediately after the `D-2` daily close and exits immediately after the `D-1` daily close, before the announcement day.

## Framework Alignment

- No-Trade: V5 kill switch, news, Friday-close, D1 timeframe, symbol, spread, and D1 history gates.
- Entry: long-only `GER40.DWX` when the next trading day is an embedded ECB press-conference date.
- Management: no trailing, partial, or break-even logic.
- Close: event-window exit on `D0` daily open, with a time-stop safety fallback.
- Risk: `RISK_FIXED=1000` for backtest sets; `RISK_PERCENT=0.25` for live set.
- Magic: `ea_id=1181`, slot `0`, `GER40.DWX`, magic `11810000`.

## Calendar

The ECB press-conference calendar is embedded in the EA for deterministic backtests and live operation without web/API calls. The 2026 entries were checked against ECB monetary-policy statement dates published on the ECB site.

## Build Boundary

No backtests or pipeline phases are part of this build. The checked-in EA folder contains only build artifacts, setfiles, this spec, and the approved strategy-card copy.
