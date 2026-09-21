# QM5_41485_ny-preopen-range-breakout-jpy — Strategy Spec

**EA ID:** QM5_41485
**Slug:** `ny-preopen-range-breakout-jpy`
**Research lineage:** H-V4, `QM-RESEARCH-2026-0012` revision 2
**Parent:** `QM5_13213_balke-gmt3-range-breakout`
**Build status:** mechanical source package only; no compile, pipeline, FTMO, or live authorization
**Last revised:** 2026-09-21

This build task does not create or modify a Strategy Card, magic allocation,
compile row, registry row, pipeline verdict, FTMO set, or live configuration.

## 1. Strategy Logic

- Venue clock: Darwinex/DXZ NY-close server only. The economic 08:30 New York
  anchor is fixed at 15:30 server and the 16:00 New York flat is fixed at 23:00
  server. No FTMO set is permitted until the governed `QM_SessionClock` helper
  exists and passes stable-season and DST-divergence tests.
- Runtime: M30 chart. Entry evaluation runs only behind
  `QM_IsNewBar(_Symbol, PERIOD_M30)`; management and exits remain per tick.
- Grid: each 60-minute bar is aligned to server `:30` and reconstructed from
  two exact, completed M30 halves. The open is the first-half open, close is the
  second-half close, and high/low are the pair extrema. A missing required half
  rejects the day. ATR true range also requires the exact predecessor close.
- Range: C2 uses the two completed grid bars ending at 15:30 (13:30-15:30);
  C3 uses the three completed grid bars ending at 15:30 (12:30-15:30).
- Filter: simple ATR(14) on the same grid, last completed bar. Reject when the
  range width is below 0.4 ATR or above 2.5 ATR.
- Entry: at the first news-eligible M30 opportunity in `[15:30,16:30)`, submit
  both a buy stop at range high with SL at range low and a sell stop at range
  low with SL at range high; no TP. Both send results are retained. One
  accepted send causes fail-closed cancellation/flattening; a one-sided day
  may not trade. A persisted day key enforces one attempt and no re-entry.
- OCO: remove the peer on the entry deal transaction and reconcile again on
  every following tick. An incomplete one-order pair is also canceled.
- News: framework PRE30_POST30 with DXZ compliance; retry opportunities are
  15:30 and 16:00 only. No placement occurs at/after 16:30. A blackout gates
  placement only and never freezes open-position management.
- Trail: using the current SL each evaluation, begin after movement of at least
  1R and improve the SL to the lower (long) or higher (short) extreme of the
  two most recently completed `:30` grid bars.
- Flat: cancel pending orders and close positions on the first available tick
  at/after 23:00. Exposure surviving a feed gap is recognized by its prior
  server-day setup time and flattened on the first later tick. Friday close at
  21:00 remains the earlier framework guard.

## 2. Parameters

| Parameter | Frozen value | Contract |
|---|---:|---|
| `strategy_range_end_hour` | 15 | DXZ server hour; runtime-enforced |
| `strategy_range_end_minute` | 30 | DXZ server minute; runtime-enforced |
| `strategy_range_bars` | 2 or 3 | C2/C3 fixed arms only |
| `strategy_exit_hour` | 23 | first tick at/after this server hour |
| `strategy_exit_minute` | 0 | runtime-enforced |
| `strategy_grid_offset_minutes` | 30 | exact `:30` hourly grid |
| `strategy_news_retry_window_minutes` | 60 | half-open window ending 16:30 |
| `strategy_atr_period` | 14 | simple true-range mean |
| `strategy_min_range_atr_mult` | 0.4 | inclusive lower range-width bound |
| `strategy_max_range_atr_mult` | 2.5 | inclusive upper range-width bound |
| `strategy_trail_trigger_r` | 1.0 | uses current-SL distance |
| `strategy_range_scan_bars` | 36 | bounded M30-read budget |
| `qm_news_stale_max_hours` | 336 | fail-closed maximum; never weaken |

The scan budget covers all two-half grid bars plus the ATR predecessor close.
Framework risk/news/Friday/stress inputs retain the V5 contract.

## 3. Symbol Universe

The chart symbol drives execution; the MQ5 source contains no tradable symbol
literal. The build package contains these separate fixed backtest arms:

| slot | symbol | timeframe | arm | `strategy_range_bars` |
|---:|---|---|---|---:|
| 0 | `USDJPY.DWX` | M30 | C2 primary | 2 |
| 1 | `USDJPY.DWX` | M30 | C3 fallback | 3 |
| 2 | `EURUSD.DWX` | M30 | C3 secondary | 3 |

This is not an optimization range and does not authorize another symbol.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Chart and decision timeframe | `M30` |
| Synthetic grid | two exact M30 halves per `:30`-aligned 60-minute bar |
| Entry gate | one evaluation per completed M30 bar |
| Management / OCO / time exit | every tick |
| Multi-timeframe indicator reads | none |

## 5. Expected Behaviour

The mechanical expectation is at most one paired OCO attempt per server day,
at most one position per symbol/day, and flat exposure after the 23:00/Friday
guards. Missing M30 halves, an invalid ATR/range ratio, stale news data, a news
blackout through 16:30, or an asymmetric order send all fail closed.

No expectancy, trade-density, drawdown, replacement, additive book-capacity,
or FTMO-suitability claim follows from this build. Those claims remain governed
by the source's Q02/Q04/Q05/Q08 criteria and pipeline evidence. No parameter
search is authorized by this spec.

## 6. Source Citation

Authority is `QM-RESEARCH-2026-0012` revision 2 and Codex round-2
`APPROVE_BUILD` critique task `afb38e9a-eb76-4dab-b5e9-54efc87a260e`.

The task was assigned against source SHA-256
`84362c84bffcc748953b32254bd13902226b2671a011c7363ba03d6714881984`.
The canonical sealed source currently hashes to
`2120bd972a80cc0abf4024f9e6bdf96717c71599e46f7a5396e1439c5bd8bcb8`.
The sole byte-level delta is the manifest's `critic_receipt.json` hash; the
revision-2 mechanical and falsification text is unchanged.

The implementation is a bounded delta from
`framework/EAs/QM5_13213_balke-gmt3-range-breakout/`: the time/grid, runtime
gate, retry/OCO, and frozen-arm changes above are the H-V4 revision-2 contract.

## 7. Risk Model

| Context | `RISK_FIXED` | `RISK_PERCENT` | Authority |
|---|---:|---:|---|
| Backtest sets in this package | 1000 | 0 | build-only comparison convention |
| FTMO / live | not authorized | not authorized | requires later governed evidence and decision |

All three backtest sets use `ENV=backtest` semantics, fixed risk greater than
zero, percentage risk exactly zero, PRE30_POST30/DXZ news compliance, and stale
news maximum 336 hours. There is no martingale, grid, ML, scale-in, or live use.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-09-21 | H-V4 revision-2 mechanical build package |
