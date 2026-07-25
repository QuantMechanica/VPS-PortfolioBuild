# STR-120 — Codex independent mechanization spec

## 1. Scope and source boundary

- Strategy: London opening-range breakout using the final three pre-London H1 candles.
- Source read: `00_source.md`, especially source posts #1, #13, #17, #24, #28-29, #46, #49, #64, #68, #81, #90, #105, #115, and #119.
- Ledger row: `STR-120` in `SOURCE_LEDGER.csv`.
- This is an independent, source-faithful specification. Qualitative author discretion is not silently converted into a filter.

## 2. Cohort, timeframe, and clock

- Execution timeframe: `H1`.
- Original six-pair source cohort: `EURGBP.DWX`, `EURUSD.DWX`, `GBPJPY.DWX`, `GBPUSD.DWX`, `USDCHF.DWX`, and `USDJPY.DWX`.
- Latest author-retained primary cohort: `EURGBP.DWX`, `EURUSD.DWX`, `GBPJPY.DWX`, and `GBPUSD.DWX`; the author later dropped `USDCHF` and `USDJPY` for weaker London-open behavior.
- The four-pair and six-pair cohorts are separate, bounded projections and must not be pooled in one verdict.
- Session anchor: 08:00 Europe/London civil time. Convert broker time to UTC with `QM_BrokerToUTC`, then resolve the UK civil clock with the approved `QM_DSTAware` pattern. Do not hard-code one broker-hour offset.
- Broker data convention: DarwinexZero New-York-close feed, GMT+2/GMT+3 as applicable.

## 3. Numbered mechanized closed-bar rules

1. At each Europe/London trading date, identify the London-open instant at 08:00 UK civil time.
2. Load exactly the three completed `H1` bars immediately before that instant. Their open times are London-open minus three, two, and one hours.
3. Set `range_high` to the maximum high, including wicks, and `range_low` to the minimum low, including wicks, across those three bars.
4. If all three complete bars are not available, or `range_high <= range_low`, block the date and emit setup/data-missing evidence.
5. Beginning with the first `H1` bar that opens at London open, evaluate only newly completed bars.
6. A long signal is the first eligible bar with `close > range_high`. A short signal is the first eligible bar with `close < range_low`. A wick outside followed by a close inside or exactly on the border is not a signal.
7. Enter at market on the first tradable tick after that signal bar closes. Do not place breakout pending orders.
8. For a long, set the initial stop at `range_low`; for a short, set it at `range_high`.
9. Calculate initial risk from the actual fill to that opposite range border. Reject the trade if the stop geometry or normalized volume is invalid.
10. Set take profit at exactly `1.5R` from the actual fill: `fill + 1.5 * risk_distance` for a long and `fill - 1.5 * risk_distance` for a short.
11. The first qualifying close consumes the date even if a framework gate rejects the order. Do not chase a later already-broken bar.
12. Allow at most one filled trade per symbol/magic/UK date. After a stop, target, rejection, or discretionary time exit, do not re-enter or reverse that date.
13. If neither stop nor target has executed, close the position at the configured US-close cutoff. Do not open a new position at or after that cutoff.
14. Use the framework's mandatory high-impact news blackout, stale-calendar fail-closed behavior, Friday close, daily-loss guard, and portfolio drawdown guard.
15. Do not trail the stop, move to break-even, partially close, stack entries, grid, martingale, or add an indicator filter in the primary specification.

## 4. Inputs

| Input | Primary value | Status |
|---|---:|---|
| `strategy_london_open_local_hhmm` | `0800` | Source-fixed UK civil time |
| `strategy_range_bars` | `3` | Source-fixed |
| `strategy_reward_r` | `1.5` | Source-fixed |
| `strategy_us_flat_et_hhmm` | unset / required | FLAG-120-01 |
| `strategy_min_close_buffer_pips` | `0.0` | Primary literal close-outside rule |
| `strategy_max_range_pips` | `0.0` (disabled) | No source threshold |
| `strategy_max_range_atr_mult` | `0.0` (disabled) | No source threshold |
| `strategy_cohort` | `AUTHOR_RETAINED_4` | Bounded primary projection |
| `RISK_FIXED` | `> 0` in backtests | House-required |
| `RISK_PERCENT` | `0` in backtests; `> 0` and `<= 1.0` live | House-required |
| `qm_news_stale_max_hours` | `<= 336` | Guardrail; never weaken |

`strategy_us_flat_et_hhmm` must be resolved before build approval. Until then, initialization must fail closed or the strategy must remain research-only; a developer must not invent a daily FX "US close."

## 5. Five-hook sketch

### `Strategy_NoTradeFilter`

- Validate symbol cohort, H1 bar freshness, UK-date conversion, the exact three-bar range, one-trade-per-date state, risk inputs, and the configured US-close cutoff.
- Return no-trade for missing session data, stale news data, an intersecting mandatory blackout, an already-consumed date, or an unresolved cutoff.
- Do not apply the author's qualitative "ridiculous range," "choppy," wick-length, or "strong breakout" judgment.

### `Strategy_EntrySignal`

- Run once per new completed H1 bar between London open and the US cutoff.
- On the first strict close beyond a range border, create one market request in that direction with the opposite border as stop and a `1.5R` target.
- Mark the date consumed when that first signal is handed to the framework; do not defer or retry the signal on later bars.

### `Strategy_ManageOpenPosition`

- Preserve the original stop and target.
- Perform no break-even, trailing, partial-close, or mid-range-stop mutation.
- Continue framework MAE tracking and risk-kill handling.

### `Strategy_ExitSignal`

- Return true at the configured US-close cutoff if a position remains open.
- Otherwise let the server-side stop and target govern, plus mandatory framework Friday/risk exits.

### `Strategy_NewsFilterHook`

- Apply the fail-closed framework blackout to high-impact events for both currencies in the traded pair.
- A signal whose entry time falls inside the blackout is skipped for that date; it is not re-armed after the event.

## 6. Interpretation flags

- **FLAG-120-01 — exact US-close cutoff unresolved.** The source says "just before the US market closes" but supplies no unambiguous ET/UTC time or market definition. No value may be invented; reconciliation/OWNER must select the exact civil-time cutoff.
- **FLAG-120-02 — "clearly/strongly" outside is discretionary.** Later posts describe rejecting a close only slightly beyond the border or accompanied by a long wick. No numeric buffer is supplied. The primary mechanical rule is therefore strict `close > high` / `close < low`; any buffered-close variant needs a predeclared value and a separate verdict.
- **FLAG-120-03 — large Asian range is discretionary.** The author sometimes skips a "ridiculous" or very large pre-open range but provides no pip/ATR threshold. The primary rule has no range-size filter. A future threshold is a labeled variant, never an inferred default.
- **FLAG-120-04 — mid-range stop is an ad-hoc deviation.** Post #64 reports sometimes moving the stop to the middle of the range after a large breakout, while posts #1 and #68 define the opposite border. The primary rule retains the opposite-border stop.
- **FLAG-120-05 — cohort changed in-thread.** Six pairs were initially traded; the author later retained four EUR/GBP pairs. Test the retained four as primary and the original six only as a separately labeled cohort.
- **FLAG-120-06 — missed/rejected entry behavior is unstated.** The conservative interpretation consumes the date on the first qualifying close so the EA cannot chase price after an operational or news-gate rejection.

## 7. Risk, policy, and evaluation notes

- Source risk moved from 1-2% to 1%; the live implementation is capped at `<=1%` total risk per magic by house policy.
- Backtests use `RISK_FIXED > 0` and `RISK_PERCENT = 0`.
- One position per magic; each registered symbol has its own deterministic magic. No stacking.
- Mandatory news blackout is compatible with the author's later NFP avoidance, but the exact framework blackout is a house safety overlay.
- No commission, swap, slippage, or DST constants are invented. Q-phase evidence must include actual modeled costs.
- The ledger records overlap with `QM5_20045`; STR-120's defining deltas are close-confirmed H1 market entry, a three-bar range, opposite-border stop, `1.5R` target, and daily US-close flattening. Deduplication remains a downstream review decision.
