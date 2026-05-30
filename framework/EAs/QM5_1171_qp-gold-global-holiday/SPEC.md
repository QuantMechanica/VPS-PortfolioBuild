# QM5_1171 qp-gold-global-holiday

## Strategy

Quantpedia global gold holiday drift. The EA trades only `XAUUSD.DWX` on `D1`.

## Framework Alignment

- No-Trade: blocks wrong symbol, wrong timeframe, wrong magic slot, invalid parameters, and excessive spread.
- Entry: on the D1 bar that begins the configured D-1 or D-2 calendar window before Christmas, Eid al-Fitr, Diwali/Deepavali, or Lunar New Year.
- Management: no trailing, scaling, pyramiding, or break-even logic.
- Exit: closes after the last overlapping D+2 event window, with a 7 trading-day time stop fallback.
- Risk: V5 fixed-risk backtest default and percent-risk live default via setfiles.

## Data

The holiday calendar is deterministic and embedded from the approved card's event universe for 2021-2035. No live web/API calls are used.

## Scope

Build only. No backtests or pipeline phases were run.
