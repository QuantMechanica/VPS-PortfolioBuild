---
ea_id: QM5_41477
slug: fx-session-mean-reversion-m15
type: strategy
source_id: QM-RESEARCH-2026-0005
source_type: internal_research
source_artifact: QM-RESEARCH://2026-0005
source_hash: ba89005b9ed4c93f46681a7504dec9adde3b4abd2bde944f7e2a7048a10b7f8c
source_author: Kimi
source_model: kimi-code/kimi-for-coding
research_trial_count: 1
preregistration_sha256: c408f534bc8825783d44487dd51def684227955988b680fbd4228d4578027475
concepts:
  - "[[concepts/session-flat-intraday]]"
  - "[[concepts/mean-reversion]]"
indicators: [EMA, ATR]
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX]
period: M15
timeframe: M15
expected_dd_pct: 2.0
expected_trade_frequency: "Bounded by one entry per symbol per session window (2 windows/day) and the max_trades_per_day cap: roughly 18-28 trades per month per symbol, about 55-85 trades per month across the three FX symbols, with at least 15 active days per month."
expected_trades_per_year_per_symbol: 280
g0_status: APPROVED
review_status: REVIEW_PENDING
g0_approval_reasoning: "OWNER_DIRECT_SESSION_DELEGATION to Kimi, 2026-09-16 (interim strategy-engineering build of the fully mechanized QM-RESEARCH-2026-0004 H-FXMR card, sibling of QM5_41475 H-CW). Independent non-Kimi critique pending: claude disabled until 2026-09-17, codex on hold until 2026-09-19, agy quota-dead. Build-only authorization; no pipeline phase, no gate verdict, no live use."
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-09-16
---

# H-FXMR: FX session mean reversion (session-flat, M15)

## Source
- Source: [[sources/QM-RESEARCH-2026-0005]] — second FTMO-gap candidate in the QM-RESEARCH-2026-0002 series (OWNER master directive 2026-09-15, continuous book evolution / FTMO acceleration; interim OWNER_DIRECT_SESSION_DELEGATION to Kimi 2026-09-16).
- Provenance: the deterministic universe map of the farm's exercised universe (14,939 ea_id x symbol pairs) shows the whole high-density FTMO-fit class at 128 pairs (0.86%), every FX cell at 0 FTMO incumbents, and session-specified FX intraday/scalp mean-reversion coverage of 8 pairs — the FTMO book's high-density, short-holding, low-swap FX sleeve is empty white space.
- Preregistration: `c408f534bc8825783d44487dd51def684227955988b680fbd4228d4578027475` (strategy-seeds/sources/QM-RESEARCH-2026-0005/preregistration.json, schema qm.research-preregistration/v1, version 1; mechanical spec = H_FXMR_card.md, sha256 9d1c56c2...8583).
- No offline statistical instrument was used in research for this candidate; every rule below is fully mechanical with no runtime model (directive sec42/sec51).

## Structural cause
Major FX pairs are the deepest, tightest-spread instruments the farm trades, and their intraday flow exhibits short-horizon overextension-reversion: during the London and New York sessions, runs of consecutive same-direction M15 bars push price away from a short EMA faster than session information flow sustains, and the close back through the EMA marks the inventory-clearing snap. Confining entries to the two liquid session windows, bounding holding minutes, and forcing flat before each session close removes the overnight gap and swap tails (swap ~ 0 for session-flat FX) while M15 density clears the challenge's activity and progression requirements.

## Price signature
During a session window, price prints `stretch_bars` or more consecutive same-direction M15 closes (or closes stretched beyond `stretch_atr_mult` x ATR from a short EMA), then the next completed bar closes back through the EMA in the opposite direction — the reversion entry. The trade targets a fixed multiple of the stop distance, stops beyond the stretch extreme, and is closed by time-stop or session-flat if neither level is hit.

## Persistence
The effect rests on recurring session inventory cycles (London fix flow, New York cross flow) rather than a one-off regime; it is defended by hard session-flat exits, a per-day trade cap and a daily loss breaker rather than by a fragile parameter.

## Mechanics

### Entry
- Evaluate on completed M15 bars only, inside a session entry window only (London `london_start_hour_utc`..`london_end_hour_utc` or New York `ny_start_hour_utc`..`ny_end_hour_utc`, defaults 07-11 / 12-16 UTC).
- Long: close of the just-closed M15 bar (shift 1) is above the `ema_period` EMA while the prior closed bar (shift 2) was at or below its EMA (close back through the EMA upward), AND bar 2 was stretched down: the run of consecutive down-closing bars ending at bar 2 has length >= `stretch_bars`, OR bar 2 closed more than `stretch_atr_mult` x ATR below its EMA.
- Short: mirrored — close1 below the EMA with bar 2 at or above its EMA, and bar 2 stretched up (consecutive up-closes run >= `stretch_bars` or close2 more than `stretch_atr_mult` x ATR above its EMA).
- One entry per symbol per session window; at most `max_trades_per_day` entries per symbol per UTC day; at most `max_positions_total` open positions across the EA family.

### Exit
- Exit at the profit target (`target_r` x stop distance), at the stop, at a time-stop of `time_stop_bars` M15 bars after entry, at the mandatory session-flat minute (`london_flat_min_utc` for the London window, `ny_flat_min_utc` for the New York window; nothing held between windows), or at the daily-flat backstop — whichever comes first. No overnight hold, no weekend carry.

### Stop loss
- Hard stop at the stretch extreme of the entry's stretch window (lowest low of the last `stretch_bars` stretch bars for a long, highest high for a short) buffered by `stop_buffer_atr` x ATR(`atr_period`) at signal. If the resulting stop distance exceeds `max_stop_atr` x ATR the trade is skipped (poor reversion R:R).

### Take profit
- Fixed reward-to-risk at `target_r` (1.0-1.5, default 1.25) times the stop distance. The band is chosen because session mean-reversion edge decays quickly after the EMA reclaim; a moderate fixed R keeps expectancy positive while density — not the per-trade R multiple — drives challenge progression.

### Trailing logic
- None. The stop is placed once beyond the stretch extreme and never widened; break-even moves are intentionally absent (the extreme is the thesis invalidation point).

### Position sizing
- Risk a fixed fraction `risk_per_trade_pct` (0.20-0.50) of equity per trade (RISK_FIXED in backtest, RISK_PERCENT live); lot size derived deterministically from the stop distance. No martingale, no averaging, no grid, no pyramiding.

### Session rules
- Entries allowed only when the bar's UTC time is inside one of the two windows (defaults London 07:00-11:00, New York 12:00-16:00 UTC); the first `skip_first_minutes` (default 15) after a window opens are skipped. Session times are strategy inputs in UTC; the EA maps broker time to UTC through the shared QM_DSTAware include (no hand-rolled DST).
- Mandatory flat by `london_flat_min_utc` (default 690 = 11:30) for London positions and `ny_flat_min_utc` (default 990 = 16:30) for New York positions; no position is held between windows.
- No new position on Friday after `friday_cutoff_min_utc` (default 840 = 14:00 UTC).

### Filters
- Shock filter: skip the window when its first M15 bar's range exceeds `shock_atr_mult` (1.5-2.5, default 2.0) times ATR(`atr_period`).
- Spread filter: skip the entry when the current spread exceeds `spread_median_mult` (1.25-1.75, default 1.5) times the 20-day median spread.
- News blackout: high-impact events for the pair's currencies inside `news_blackout_minutes` (0-120, default 30) of entry block the trade (strategy hook over the live MT5 native calendar; fail-closed when the calendar is unavailable).
- Daily circuit breaker: stop trading for the day at `daily_stop_pct` (-1.0%) day P&L.
- Weekly circuit breaker: stop trading for the week at `weekly_stop_pct` (-2.0%) week P&L.
- Density caps: at most `max_trades_per_day` (2-6, default 4) entries per symbol per UTC day; one entry per symbol per session window.

## Deterministic risk contract
| Field | Value |
|---|---|
| max_positions_total | 2..4 (default 3) across all symbol slots of this EA |
| risk_per_trade_pct | 0.20 .. 0.50 (live RISK_PERCENT; backtest RISK_FIXED) |
| daily_stop_pct | -1.0 (hard day breaker, blocks new entries) |
| weekly_stop_pct | -2.0 (hard week breaker, blocks new entries) |
| session-flat guarantee | mandatory flat by `london_flat_min_utc` (11:30) / `ny_flat_min_utc` (16:30); nothing held between windows; Friday cutoff 14:00 UTC for new entries; no weekend carry |
| density caps | <= `max_trades_per_day` (4) entries per symbol per UTC day; one entry per symbol per session window |
| tail-amplifying mechanics | none — no martingale, no averaging, no grid, no pyramiding, bounded holding minutes |

## Indicators and required data
Native MT5 price series, one EMA, one ATR, the instrument spread, and the live MT5 news calendar. No external feed.

## Timeframe
M15 for signals and execution; no D1 or higher signals.

## Symbols
EURUSD, GBPUSD, USDJPY FX majors (symbols are inputs, never code literals; one input per symbol slot, `.DWX` in research/backtest). No indices, metals, energy.

## Parameter ranges
- stretch_bars: 2 .. 4
- ema_period: 10 .. 20
- stretch_atr_mult: 0.5 .. 1.5
- atr_period: 10 .. 20
- stop_buffer_atr: 0.1 .. 0.5
- max_stop_atr: 1.5 .. 2.5
- target_r: 1.0 .. 1.5
- time_stop_bars: 8 .. 16
- risk_per_trade_pct: 0.20 .. 0.50
- daily_stop_pct: -1.0 .. -1.0
- weekly_stop_pct: -2.0 .. -2.0
- shock_atr_mult: 1.5 .. 2.5
- spread_median_mult: 1.25 .. 1.75
- london_start_hour_utc: 7 .. 8
- london_end_hour_utc: 10 .. 12
- ny_start_hour_utc: 12 .. 13
- ny_end_hour_utc: 15 .. 16
- london_flat_min_utc: 660 .. 720
- ny_flat_min_utc: 960 .. 1020
- friday_cutoff_min_utc: 780 .. 900
- skip_first_minutes: 0 .. 30
- max_positions_total: 2 .. 4
- max_trades_per_day: 2 .. 6
- news_blackout_minutes: 0 .. 120

## Expected frequency
Bounded by one entry per symbol per session window (max 2 windows/day) and the per-day cap: roughly 18-28 trades per month per symbol, about 55-85 trades per month across the three FX symbols, with at least 15 active days per month — the high-density FTMO-fit cell the universe map shows as uncovered, well above the Q02 >=5 trades/yr floor, capped below the scalp class by the per-day trade cap.

## Invalidation conditions
Refuted if, out of sample, session-flat FX mean reversion does not reduce worst-day loss or breach probability relative to the FX swing baseline, or if the edge depends on a single symbol, a single session window, or a single parameter island.

## Falsification / kill criteria
Killed if: OOS holdout net profit factor < 1.20 after costs or expectancy < +0.10R/trade; Monte-Carlo P(hit -5% daily limit within 60d) > 2% or simulated worst-day p95 > 2.5% of equity at 0.25% risk; realized swap/rollover cost > 10% of gross P&L; more than half of the +-1-step parameter neighbourhood shows negative expectancy; any single month has < 10 active days; the per-day trade cap must be raised above 6 to clear the activity floor; or the edge rests on a single symbol or session window.

## Q08/Q11 crisis and news risk
Session-flat exposure removes overnight gap risk; the shock and spread filters and the fail-closed news blackout keep event windows closed. Q08 stress and Q11 full-history confirmation remain the judges before any book placement.

## FTMO fit
Zero overnight exposure (swap ~ 0, no gap-through-stop), a hard daily loss breaker at -1.0% (one fifth of the FTMO 5% daily loss limit) and a weekly breaker at -2.0% (one fifth of the 10% total drawdown limit), bounded holding minutes, and a high but capped density target the probability of completing the challenge rather than standalone profit factor. The session-flat flatten and the fail-closed news blackout keep the event windows the 5%/10% limits protect closed — the opposite shape to the D1 gold/FX swing pocket whose overnight/swap tail produced the -10.26% demo breach.

## Concepts
- [[concepts/session-flat-intraday]] - primary
- [[concepts/mean-reversion]] - secondary

## R1-R4 assessment
| Criterion | Status | Rationale |
|-----------|--------|------------|
| R1 Source-Link | PASS | Internal research source QM-RESEARCH-2026-0005 with lineage, source_hash binding (ba89005b...7f8c), and preregistration hash (c408f534...7475); durable artifact resolvable at strategy-seeds/sources/QM-RESEARCH-2026-0005/. Non-Kimi critic receipt PENDING (REVIEW_PENDING gate). |
| R2 Mechanical | PASS | Session windows, stretch definition, EMA reclaim, stretch-extreme ATR-buffered stop, fixed R target, time stop, session-flat minutes, density caps, filters, and breakers are all explicit closed-bar rules. |
| R3 DWX-testbar | PASS | Uses only M15 OHLC-derived EMA/ATR, the instrument spread, and the native news calendar on DWX FX symbols (EURUSD/GBPUSD/USDJPY). |
| R4 No ML | PASS | No ML used in research for this candidate; fixed mechanical parameters, no runtime model, one entry per symbol per session window, no martingale/grid/averaging. |

## Framework Alignment
- Strategy_NoTradeFilter: M15 timeframe gate, static locked-configuration guards only; never blocks exits.
- Strategy_EntrySignal: completed M15 bar EMA reclaim after an N-bar/ATR stretch, inside a UTC session window, after skip-first-minutes; one entry per symbol per session window; market order with SL/TP attached.
- Strategy_ManageOpenPosition: no trailing (card: none); hook kept as a no-op delegate.
- Strategy_ExitSignal: time-stop after `time_stop_bars` M15 bars; mandatory session-flat flatten (per-window flat minute); lunch-gap and end-of-day flat backstops. Runs ungated per tick.
- Strategy_NewsFilterHook: high-impact news blackout of `news_blackout_minutes` around entry (fail-closed), evaluated in the new-bar entry path only; framework 2-axis filter stays at OFF/DXZ defaults.

## Pipeline history
- G0: 2026-09-16, APPROVED under OWNER_DIRECT_SESSION_DELEGATION to Kimi (review_status REVIEW_PENDING; independent non-Kimi critique gated: claude disabled until 2026-09-17, codex on hold until 2026-09-19, agy quota-dead).

## Related strategies
- QM5_41475 cash-window-index-continuation-h1 (H-CW sibling; QM-RESEARCH-2026-0002).

## Lessons Learned
- TBD during pipeline run.
