# QM5_1204_zarattini-vwap-ndx

## Intent

V5 implementation of the approved Zarattini-Aziz VWAP trend trading port to `NDX.DWX`.

## Card Mapping

- **No-trade:** Blocks symbols other than `NDX.DWX`, entries outside the configured US index cash session window, entries during the final flatten buffer, and entries when spread exceeds the configured point cap.
- **Entry:** On the configured signal timeframe, computes current-session VWAP from session start using tick volume by default. If flat after the minimum session warmup, opens long when the last closed bar closes above VWAP and short when it closes below VWAP.
- **Management:** No trailing or partial management is authorized by the card. The initial protective stop is set at entry.
- **Exit:** Closes long when the last closed bar is below session VWAP, closes short when the last closed bar is above session VWAP, and flattens all positions five minutes before configured session close.
- **Stop:** Initial SL uses `1.2 * M15 ATR(20)` by default.

## Scope Notes

- One symbol slot is used: slot `0` for `NDX.DWX`.
- P3 sweep dimensions are exposed through setfiles: signal timeframe, VWAP volume mode, and ATR stop multiplier.
- No backtests or pipeline phases are part of this build.
