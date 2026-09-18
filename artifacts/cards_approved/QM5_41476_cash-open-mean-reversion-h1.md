---
ea_id: QM5_41476
slug: cash-open-mean-reversion-h1
type: strategy
source_id: QM-RESEARCH-2026-0006
source_type: internal_research
preregistration_sha256: 8129b0fc617229c40f7898c64a79072ff93019eb08fc7fa7faef69987b140d2d
source_hash: bafb38da8bfbce3b25a4b4355703eb98253d2548792c9fd7b780e10d28caf8b2
research_trial_count: 1
concepts:
  - "[[concepts/session-flat-intraday]]"
  - "[[concepts/failed-breakout-mean-reversion]]"
indicators: [EMA, ATR]
target_symbols: [NDX.DWX, GDAXI.DWX, SP500.DWX]
period: H1
timeframe: H1
expected_dd_pct: 2.0
expected_trade_frequency: "At most one entry per symbol per day: roughly 2-5 trades per month per symbol, about 6-15 trades per month across the three index symbols, with at least 3 active days per month per symbol."
expected_trades_per_year_per_symbol: 35
g0_status: APPROVED
review_status: REVIEW_PENDING
g0_approval_reasoning: "source_hash rebind after non-Kimi critic seal 2026-09-18 (Fable critic wave, OWNER-DEC-FABLE-FULL-EXECUTIVE-AUTHORITY-20260917); mechanics unchanged; R-gate frontmatter re-synced to the card body"
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-09-18
card_sha256: 9f91cbc6663a029be8d700aee00bd98a22436a73b128d57caa3abfa9fc8de800
---

# H-MR: Cash-open index mean reversion (session-flat, H1)

## Source
- Source: [[sources/QM-RESEARCH-2026-0006]] — failed-breakout complement to QM-RESEARCH-2026-0002 (H-CW), authored by Kimi (research role, offline) under the interim OWNER strategy-engineering delegation 2026-09-15/16.
- Provenance: the same cash-session opening-range structure that anchors H-CW continuation also anchors reversion when the first impulse over-extends and fails; H-MR mechanizes the failed-breakout side. Pilot motivation (not proof): deterministic fire count of these exact rules on an NDX-class feed (2018-2020 in-sample) — 2.9 trades/month, ~4.7 active days/month, raw PF(R) 1.12 at +0.02R/trade, 30% midpoint-target hit rate (computed output `h_mr_fire_count.json`, sha256 in the source manifest).
- Preregistration: `8129b0fc617229c40f7898c64a79072ff93019eb08fc7fa7faef69987b140d2d` (strategy-seeds/sources/QM-RESEARCH-2026-0006/preregistration.json, schema qm.research-preregistration/v1, version 1; mechanical spec sha256 f722f2df...4b17 over H_MR_card.md).
- Offline statistical instruments were used in research only (directive sec41); every rule below is fully mechanical with no runtime model (directive sec42/sec51).

## Structural cause
Equity-index CFDs at the cash open frequently over-extend on the first impulse (opening-auction inventory imbalance / stop runs). When no fresh initiative flow follows, the over-extension fails and price reverts toward the opening-auction reference — the opening-range midpoint — within the session. Trading only the failed-breakout side, inside the cash window, and forcing flat before the thin rollover removes the overnight gap and swap tails while an H1 timeframe keeps per-trade expectancy high enough that moderate density clears the challenge's min-trading-day and progression requirements without scalp-class noise.

## Price signature
During the cash-session window a single H1 bar pierces the opening-range extreme by a small ATR-scaled buffer and then closes back inside the range — a failed breakdown (long side) or failed breakout (short side) — while the close sits on the stretched side of a short intraday EMA. The failed move reverts toward the opening-range midpoint and the position is closed before session end.

## Persistence
The effect rests on recurring opening-auction mechanics (daily inventory reset, cash-open stop runs) rather than a one-off regime, so it is expected to persist; it is defended by hard session-flat exits and a daily loss breaker rather than by a fragile parameter. It complements H-CW by construction: H-MR is exposed exactly on session days where the opening-range breakout fails, so the pair diversifies the same window across breakout outcomes.

**Distinct from QM5_10140 (tv-london-session-break) — evidence-based delta, not a duplicate fingerprint:** 10140 is a London-session *continuation* system — it enters on a confirmed break of the Asian range in the breakout direction and holds with the move. H-MR is the opposite conditioning on the same opening-range reference: it requires a *failed* break (a pierce of the range extreme that closes back inside within the same H1 bar) and enters in the reversion direction toward the range midpoint, with a mandatory same-session flat. The two can trade the same symbol on the same day with opposite positions only in the rare simultaneous-fill case, which the one-entry-per-day and session-flat guards bound; their return streams are conditioned on disjoint outcome classes of the opening auction (continuation vs failure), not on shared signal logic.

## Mechanics

### Entry
- Evaluate on completed H1 bars only, inside the entry window only, and only after the opening range has completed.
- Opening range: maximum high / minimum low of the first `opening_range_bars` H1 bars of the session (UTC-anchored session start via QM_DSTAware).
- Long (failed breakdown): the closed bar's low is below the opening-range low minus `breakout_buffer_atr` x ATR AND the close is back inside the range (strictly above the range low AND strictly below the range high) AND the close is below the EMA(ema_period). Reward/risk at the market entry price must be at least `min_target_r` (see Take profit).
- Short (failed breakout): the closed bar's high is above the opening-range high plus `breakout_buffer_atr` x ATR AND the close is back inside the range AND the close is above the EMA(ema_period). Same reward/risk eligibility.
- One entry per symbol per day. Maximum `max_positions_total` open positions across the EA's symbol slots at once.

### Exit
- Exit at the profit target (opening-range midpoint), at the stop, at a time-stop of `time_stop_bars` H1 bars after entry, or at the mandatory session-flat time `flatten_hour_utc` — whichever comes first. No overnight hold, no weekend carry.

### Stop loss
- Hard stop beyond the failed-breakout extreme plus an ATR buffer: long stop = signal bar low minus `atr_stop_mult` (1.0) x ATR(atr_period); short stop = signal bar high plus `atr_stop_mult` x ATR, computed from the ATR at signal time.

### Take profit
- Fixed price target at the opening-range midpoint: (range high + range low) / 2, computed once when the opening range completes. The midpoint is the mechanizable opening-auction reference and the natural reversion magnet; a session tick-volume VWAP proxy is rejected (.DWX index CFD volume modelling is not validated). `min_target_r` (0.5) is a minimum reward:risk entry eligibility floor — trades whose midpoint reward is less than `min_target_r` times the stop risk are skipped — not a TP multiple.

### Trailing logic
- Optional break-even move once price has travelled one ATR in favour; bounded and finite, never widening the stop.

### Position sizing
- Risk a fixed fraction `risk_per_trade_pct` of equity per trade (RISK_FIXED in backtest, RISK_PERCENT live); lot size derived deterministically from the stop distance. No martingale, no averaging, no grid.

### Session rules
- Entries allowed only when the bar's UTC hour is in `[session_start_hour_utc, session_end_hour_utc]` (defaults 13 and 17 UTC) and at least `opening_range_bars` session bars have closed; mandatory flat once the UTC hour reaches `flatten_hour_utc` (default 20 UTC). Session hours are strategy inputs; the EA maps broker time to UTC through the shared QM_DSTAware include (no hand-rolled DST).
- No new position on Friday after `friday_cutoff_hour_utc` (default 17 UTC).

### Filters
- Shock filter: skip the day when the first session bar's range exceeds `shock_atr_mult` (3.0) times ATR(atr_period). The cash-open bar is naturally wide (pilot median ~2.0x ATR on the proxy feed), so the floor sits above the normal-open band and only extreme shock days are skipped.
- Spread filter: skip the entry when the current spread exceeds `spread_median_mult` times the 20-day median spread.
- News blackout: high-impact events (FOMC/NFP/CPI) inside `news_blackout_minutes` of entry block the trade (strategy hook over the live MT5 native calendar; fail-closed when the calendar is unavailable).
- Daily circuit breaker: stop trading for the day at `daily_stop_pct` (-1.0%) day P&L.
- Weekly circuit breaker: stop trading for the week at `weekly_stop_pct` (-2.0%) week P&L.

## Deterministic risk contract
| Field | Value |
|---|---|
| max_positions_total | 1..3 (default 2) across all symbol slots of this EA |
| risk_per_trade_pct | 0.20 .. 0.50 (live RISK_PERCENT; backtest RISK_FIXED) |
| daily_stop_pct | -1.0 (hard day breaker, blocks new entries) |
| weekly_stop_pct | -2.0 (hard week breaker, blocks new entries) |
| session-flat guarantee | mandatory flat by `flatten_hour_utc` (default 20 UTC); Friday cutoff 17 UTC for new entries; no weekend carry |
| tail-amplifying mechanics | none — no martingale, no averaging, no grid, one entry per symbol per day |

## Indicators and required data
Native MT5 price series, one EMA, one ATR, the instrument spread, and the live MT5 news calendar. No external feed.

## Timeframe
H1 for signals (an M15 execution variant, mirroring the H-CW card, is allowed); no D1 or higher signals.

## Symbols
Target symbols: NDX.DWX, GDAXI.DWX, SP500.DWX (factory custom-symbol names; live charts use the bare broker names via the slot inputs).
NDX, GDAXI, SP500 index CFDs (symbols are inputs, never code literals; one input per symbol slot). No FX, no metals, no energy.

## Parameter ranges
- opening_range_bars: 2 .. 4
- ema_period: 15 .. 30
- breakout_buffer_atr: 0.0 .. 0.05
- atr_period: 10 .. 20
- atr_stop_mult: 0.5 .. 1.5
- min_target_r: 0.4 .. 0.8
- time_stop_bars: 4 .. 8
- risk_per_trade_pct: 0.20 .. 0.50
- daily_stop_pct: -1.0 .. -1.0
- weekly_stop_pct: -2.0 .. -2.0
- shock_atr_mult: 2.5 .. 4.0
- spread_median_mult: 1.25 .. 1.75
- session_start_hour_utc: 13 .. 14
- session_end_hour_utc: 16 .. 17
- flatten_hour_utc: 20 .. 21
- friday_cutoff_hour_utc: 17 .. 18
- max_positions_total: 1 .. 3
- news_blackout_minutes: 0 .. 120

| param | default |
|---|---|
| opening_range_bars | 3 |
| ema_period | 20 |
| breakout_buffer_atr | 0.025 |
| atr_period | 14 |
| atr_stop_mult | 1.0 |
| min_target_r | 0.5 |
| time_stop_bars | 6 |
| risk_per_trade_pct | 0.25 |
| daily_stop_pct | -1.0 |
| weekly_stop_pct | -2.0 |
| shock_atr_mult | 3.0 |
| spread_median_mult | 1.5 |
| session_start_hour_utc | 13 |
| session_end_hour_utc | 17 |
| flatten_hour_utc | 20 |
| friday_cutoff_hour_utc | 17 |
| max_positions_total | 2 |
| news_blackout_minutes | 60 |

## Expected frequency
At most one signal per day per symbol by construction. Pilot fire count of the exact rules (NDX-class feed, 2018-2020 in-sample): 2.9 trades/month, ~4.7 active days/month, 135 gross signals / 82 taken trades over 28 months — so roughly 2-5 trades per month per symbol, about 6-15 trades per month across the three index symbols, with at least 3 active days per month per symbol. The pilot's raw outcome (PF(R) 1.12, +0.02R/trade, 30% midpoint hit rate) is feasibility-level motivation only and below the preregistered success bar; the governed pipeline on farm .DWX data is the judge.

## Invalidation conditions
Refuted if, out of sample, session-flat cash-open mean reversion does not reduce worst-day loss or breach probability relative to the swing baseline (and to the H-CW continuation sibling), or if the edge depends on a single symbol or single period.

## Falsification / kill criteria
Killed if: OOS holdout net profit factor < 1.20 after costs or expectancy < +0.10R/trade; Monte-Carlo P(hit -5% daily limit within 60d) > 2% or simulated worst-day p95 > 2.5% of equity at 0.25% risk; realized swap/rollover cost > 10% of gross P&L; more than half of the +-1-step parameter neighbourhood shows negative expectancy; any single month has < 3 active days on a traded symbol; or the strategy does not reduce worst-day loss or breach probability relative to the swing baseline out of sample.

## Q08/Q11 crisis and news risk
Session-flat exposure removes overnight gap risk; the shock and spread filters and the live news filter fail closed. Q08 stress and Q11 full-history confirmation remain the judges before any book placement.

## FTMO fit
Zero overnight exposure (swap ~ 0, no gap-through-stop), a hard daily loss breaker, and a high-hit-rate midpoint target with moderate density target the probability of completing the challenge rather than standalone profit factor. The daily breaker (-1.0%) and weekly breaker (-2.0%) sit far inside the FTMO 5% daily and 10% total drawdown limits, and the high-impact news blackout keeps FOMC/NFP/CPI windows closed. As the failed-breakout complement of H-CW it diversifies the same FTMO-friendly window across breakout outcomes rather than doubling the continuation exposure.

## Concepts
- [[concepts/session-flat-intraday]] - primary
- [[concepts/failed-breakout-mean-reversion]] - secondary

## R1-R4 assessment
| Criterion | Status | Rationale |
|-----------|--------|------------|
| R1 Source-Link | PASS | Internal research source QM-RESEARCH-2026-0006 with lineage, manifest-backed numeric provenance, and preregistration hash (8129b0f...d2d). Cross-vendor critic PENDING (REVIEW_PENDING). |
| R2 Mechanical | PASS | Opening range, single-bar pierce-and-reclaim entry, EMA stretch, midpoint target, min-R eligibility, ATR stop, time stop, flatten hour, filters, and breakers are all explicit closed-bar rules. |
| R3 DWX-testbar | PASS | Uses only H1 OHLC-derived EMA/ATR, the instrument spread, and the native news calendar on DWX index symbols (NDX/GDAXI/SP500). |
| R4 No ML | PASS | Fixed mechanical parameters, no ML, no online adaptation, one entry per symbol per day, no martingale/grid/averaging. |

## Framework Alignment
- Strategy_NoTradeFilter: H1-chart + slot + locked-configuration range guards only (never blocks exits).
- Strategy_EntrySignal: completed H1 bar pierce-and-reclaim of the opening range plus EMA-side stretch; min_target_r reward:risk eligibility at market price; one entry per symbol per day; market order with SL/TP attached.
- Strategy_ManageOpenPosition: optional break-even move after +1.0 ATR in favour; never widens the stop.
- Strategy_ExitSignal: time-stop after `time_stop_bars` H1 bars; mandatory session-flat flatten at `flatten_hour_utc`.
- Session/shock/spread/breaker/capacity/news gates: evaluated in the new-bar entry path (HmrNoTradeFilter static part + HmrEntrySignal dynamic part), mirroring the H-CW integration so the flatten exit and break-even management can never be gated away.
- Strategy_NewsFilterHook: returns false (defers to the framework); the card's high-impact blackout is enforced in the new-bar entry path only.

## Pipeline history
- G0: 2026-09-16, APPROVED under OWNER_DIRECT_SESSION_DELEGATION to Kimi (review_status REVIEW_PENDING; independent non-Kimi critique gated: claude disabled until 2026-09-17, codex on hold until 2026-09-19, agy quota-dead).

## Related strategies
- QM5_41475 cash-window-index-continuation-h1 (H-CW continuation sibling; same session shell, opposite breakout side).
- QM-RESEARCH-2026-0002 (parent campaign context).

## Lessons Learned
- TBD during pipeline run.
