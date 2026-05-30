# QM5_1177 qp-vix80-sp500-premia

## Intent
Quantpedia / Bansal-Stivers high-VIX equity-premia timing strategy. The EA opens a long `SP500.DWX` position at the first D1 bar of a new month when the latest completed month-end VIX close is above a frozen high-VIX threshold.

## Framework Alignment
- No-Trade: blocks all symbols except `SP500.DWX`, all timeframes except `D1`, nonzero magic slots, invalid parameters, insufficient history, and optional max-spread breaches.
- Entry: on month turn, reads local `QM5_1177_vix_monthly.csv`; if VIX is above `strategy_vix_threshold`, opens one long position with ATR(20) * 2.5 initial stop.
- Management: no trailing or partial close; card only specifies initial ATR stop, safety stop, and scheduled monthly exit.
- Close: closes if loss reaches `strategy_safety_stop_pct` from entry, or at an eligible monthly rebalance after the configured holding window when the high-VIX signal is no longer active.

## Data Contract
`strategy_vix_csv_path` must point to a local or terminal-common CSV. Expected minimal columns: `date,vix_close`. Rows with invalid dates or non-positive VIX values are ignored. The EA never performs web or external API calls.

## Symbols and Slots
- slot 0: `SP500.DWX`, magic `11770000`

## Risk
- Backtest default: `RISK_FIXED=1000`, `RISK_PERCENT=0`
- Live template: `RISK_PERCENT=0.25`, `RISK_FIXED=0`

## Notes
`SP500.DWX` remains a T6 live-promotion caveat per the Strategy Card. Before live AutoTrading, parallel validation on a routable proxy such as `NDX.DWX` or `WS30.DWX` is required by the card.
