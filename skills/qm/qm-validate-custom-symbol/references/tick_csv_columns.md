# Tick Data Manager CSV — Expected Column Order

Reference for QA comparison between TDM exports and live MT5 bar data.

## M15 / H1 bar export columns

```
Date,Time,Open,High,Low,Close,Volume
```

- `Date`: `YYYY.MM.DD` in **broker_time** (NY-Close)
- `Time`: `HH:MM` in **broker_time**
- `Volume`: tick volume (not real volume — Darwinex is non-ECN tick volume)

## Tick-level export columns

```
Date,Time,Bid,Ask,Volume
```

- `Time` resolution depends on TDM settings — default is millisecond (`HH:MM:SS.fff`)

## Comparison rules

- Always compare `broker_time` to `broker_time` — never mix `broker_time` and `local_time` in a single comparison frame
- For the daily-open candle, expected timestamp is **Sunday 22:00 UTC** during US-DST and **Sunday 23:00 UTC** outside US-DST (because broker server-time = NY-Close)
- Friday close = Friday 21:00 broker time → same UTC translation rules

## See also

- `docs/ops/TICK_DATA_MANAGER_DARWINEX_TIME.md`
