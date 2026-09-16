---
ea_id: QM5_41479
slug: tail-pyramid-index-session-h1
type: strategy
source_id: QM-RESEARCH-2026-0007
source_type: internal_research
preregistration_sha256: f601ba6a43beeadb14104114a07988fe2d4445b4e9e1731cfebf7f6b8866cfcb
source_hash: 4e1299ecdcef4ca35803dd0b4bf4262c18b1ee9fcb15fe374fc83ac17311bf64
research_trial_count: 1
concepts:
  - "[[concepts/session-flat-intraday]]"
  - "[[concepts/positive-pyramiding]]"
indicators: [EMA, ATR]
target_symbols: [NDX.DWX, GDAXI.DWX, SP500.DWX]
period: H1
timeframe: H1
mechanism_flags: [positive_pyramiding]
risk_contract: ../../strategy-seeds/sources/QM-RESEARCH-2026-0007/risk_contract.json
expected_dd_pct: 2.0
expected_trade_frequency: "At most one basket per symbol per day: roughly 6-7 baskets per month per symbol, about 12-20 baskets per month across the three index symbols, with at least 8 active days per month."
expected_trades_per_year_per_symbol: 77
g0_status: APPROVED
review_status: REVIEW_PENDING
g0_approval_reasoning: "OWNER_DIRECT_SESSION_DELEGATION to Kimi, 2026-09-15/16 (interim strategy-engineering build of the fully mechanized QM-RESEARCH-2026-0007 H-PY card, TAIL_RISK Family A first candidate). Independent non-Kimi critique pending: claude disabled until 2026-09-17, codex on hold until 2026-09-19, agy quota-dead. Build-only authorization; no pipeline phase, no gate verdict, no live use. No registry row allocated for ea_id 41479; the central allocator runs later (as 41475-77 did)."
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-09-16
---

# H-PY: bounded positive pyramid on cash-session index trend (session-flat, H1)

## Source
- Source: [[sources/QM-RESEARCH-2026-0007]] — first TAIL_RISK programme candidate (Family A — bounded positive pyramiding), authored by Kimi (research role, offline) under the interim OWNER delegation 2026-09-15/16, per `docs/research/TAIL_RISK_PROGRAMME_2026-09-16.md` §4 and `tools/strategy_farm/config/tail_risk_families.v1.json`.
- Provenance: the base entry reuses the H-CW session-flat envelope ([[sources/QM-RESEARCH-2026-0002]], QM5_41475) — same cash-session opening-range breakout on NDX/GDAXI/SP500 H1, same shock/spread/news filter class, same flatten hour and breakers; H-PY layers the Family A pyramid on top. Pilot motivation (not proof): deterministic fire count of these exact rules on an NDX-class feed (2018-2020 in-sample) — 6.4 baskets/month, ~6.4 active days/month, raw PF(R) 1.26 at +0.12R/basket, level-2 reach 11.9%, level-3 reach 0%, 15% giveback-stopped before level 2 (computed output `h_py_pilot.json`, sha256 in the source manifest).
- Preregistration: `f601ba6a43beeadb14104114a07988fe2d4445b4e9e1731cfebf7f6b8866cfcb` (strategy-seeds/sources/QM-RESEARCH-2026-0007/preregistration.json, schema qm.research-preregistration/v1, version 1; mechanical spec sha256 526504f1...11e2a over H_PY_card.md).
- Offline statistical instruments were used in research only (directive sec41); every rule below is fully mechanical with no runtime model (directive sec42/sec51).
- Machine-readable risk contract: `risk_contract.json` (same directory as the source store; byte-identical to the fenced contract in H_PY_card.md; validated with `strategy_risk_contract.py`: `validate_contract=[]`, `is_unbounded=False`).

## Structural cause
Equity-index CFDs exhibit persistent intraday order flow during the cash-session overlap (deepest liquidity, tightest spread, strongest autocorrelated tape). When the session opening range breaks and the breakout holds above/below a short intraday EMA, the directional flow that funded the break frequently persists for several more hours — long enough to pay a trailed pyramid, and long enough that a giveback stop set at 50% of peak open basket profit monetizes the fat right tail of those sessions instead of donating it back at the close. The mechanism is convexity, not prediction: exposure concentrates only after the tape has already moved in favour (each add requires both an ATR-scaled open profit and a new favourable extreme), so the position is largest exactly when the session trend has confirmed itself, and the never-widening basket stop converts parabolic reversals into small realised givebacks rather than open-ended losses. Confining the whole construction to the cash window and forcing flat before the thin rollover removes the two tails that kill FTMO accounts — overnight gap and swap — which is precisely the tail a built-out basket fears most.

## Price signature
During the cash-session window price breaks the range of the first session bars and continues in the breakout direction while holding on the confirmed side of a short intraday EMA. Favourable closes stack: first +1.0x ATR of open profit with a new favourable extreme (level 2 fills), later +2.0x ATR with a second new extreme (level 3 fills). The signature ends in one of three shapes: a vertical extension whose giveback from the peak triggers the basket exit at +50% retained profit, a drift that the trailing stop later harvests, or a chop that stops the base leg at its ATR stop or runs into the session-flat flatten.

## Persistence
The effect rests on recurring cash-session inventory and index order flow rather than a one-off regime, so it is expected to persist; it is defended by hard session-flat exits, the never-widening basket stop, the giveback stop, and the daily loss breaker rather than by a fragile parameter. The pyramid parameters (add spacing, giveback fraction, level weights) are programme-fixed or range-bounded around the Family A contract, so the construction cannot drift into negative-pyramiding or martingale shapes without violating its own card.

## Expected mechanism
Convex capture of strong intraday trends. The base leg pays the discovery cost on every session that breaks out; the adds are paid for only by sessions whose trend persists (exposure concentrates where the tape has confirmed direction), and the giveback stop monetizes the right tail of those sessions at 50% of peak. Expectancy per basket should exceed expectancy of the flat base-leg version only if cash-session trends persist long enough to print a new favourable extreme after +1.0x ATR more often than they reverse violently through the giveback stop first.

## Mechanics

### Entry (base leg, level 1)
- Evaluate on completed H1 bars only, inside the entry window only, and only after the opening range has completed.
- Opening range: maximum high / minimum low of the first `breakout_window_bars` H1 bars of the session (UTC-anchored session start via QM_DSTAware).
- Long: the closed bar's close is above the opening-range high plus `breakout_buffer_atr` x ATR AND above EMA(`ema_period`). Short: close below the opening-range low minus the buffer AND below the EMA. Fills at the next bar's open.
- One basket per symbol per day; maximum `max_positions_total` concurrent baskets across the EA's symbol slots.

### Pyramid adds (levels 2 and 3)
- Adds evaluate on bar closes and fill at the next bar's open; one add per bar maximum; no add fills into the flatten-hour bar; no adds on Friday after `friday_cutoff_hour_utc`.
- Level 2 (size `level2_size_mult` x base): close shows open profit on the base leg >= `add2_trigger_atr` x ATR (ATR fixed at base-signal value) AND the bar prints a new favourable extreme versus every bar since the base entry.
- Level 3 (size `level3_size_mult` x base): close shows open profit >= `add3_trigger_atr` x ATR AND a second new favourable extreme prints after the level-2 fill.
- Hard bound: never more than 3 legs, never more than 2.25 base legs aggregate; the add logic fails closed at the bound.

### Exit
The whole basket exits together at whichever triggers first:
1. Session flat at `flatten_hour_utc` (exit at the open of the flatten-hour bar; no overnight hold).
2. Basket stop (intrabar touch of the never-widening basket stop).
3. Hard equity adverse bound: basket open P&L reaches `basket_adverse_bound_pct` of equity against the basket (-2R at the 0.25% default base risk).
4. Giveback stop: basket open P&L gives back `giveback_frac` of the peak open basket P&L (peak tracked from basket open on every bar close, refreshed before the test).
5. Time stop: `time_stop_bars` H1 bars after base entry.

### Stop loss
Level-1 reference stop `atr_stop_mult` x ATR from the base fill. After level 2 fills, the basket stop ratchets to the blended breakeven of the filled levels plus `be_buffer_atr` x ATR (breakeven plus costs); thereafter it trails `trail_atr_mult` x ATR behind the most favourable close since the level-2 fill. The basket stop only ever tightens — never widens — and no filled leg carries a wider individual stop than the current basket stop.

### Take profit
No fixed price target. Profit-taking is the giveback stop: the basket closes when open P&L falls to `giveback_frac` of the peak open basket P&L, retaining (1 - `giveback_frac`) of the best intraday run by construction. A fixed-R target would cap the right tail the pyramid exists to capture.

### Trailing logic (never-widening basket stop)
For a long basket (mirror for short): `basket_stop = max(previous basket_stop, blended_breakeven + be_buffer_atr x ATR, peak_close_since_L2 - trail_atr_mult x ATR)` on every bar close after level 2 fills; before level 2 fills it is the level-1 reference stop. The max-over-history ratchet makes never-widening structural, not discretionary.

### Giveback and basket-loss bounds
Peak open basket P&L (1R = `risk_per_trade_pct` of equity on the level-1 reference stop) is tracked from basket open and refreshed on every bar close before the giveback test, so a bar making a new peak cannot trigger the giveback against itself. The giveback stop arms only once the peak is strictly positive. The hard equity adverse bound is the Family A ruin bound: it flattens the basket regardless of price levels and is the emergency exit the joint-tail engine reads as `max_basket_loss_pct`.

### Position sizing
Level 1 risks `risk_per_trade_pct` of equity at its reference stop (RISK_FIXED in backtest, RISK_PERCENT live; family bound: never above 0.25%). Levels 2/3 size at `level2_size_mult` / `level3_size_mult` of base (Family A progression 1.0 / 0.75 / 0.5) — a fully built basket carries 2.25 base legs and at most 5% margin. One pyramid per symbol per day; at most `max_positions_total` concurrent baskets, so worst-case planned stop risk is bounded by the daily/weekly breakers even with every basket fully built. Family-contract fixed values: level weights, 2.25-leg aggregate, 5% margin cap, 3-level cap; the 0.5% adverse / 50% giveback bounds are upper bounds (the card may tighten, never widen).

### Session rules
- Base entries allowed only when the bar's UTC hour is in `[session_start_hour_utc, session_end_hour_utc]` (defaults 13 and 17 UTC) and the opening range has completed; mandatory flat once the UTC hour reaches `flatten_hour_utc` (default 20 UTC). Session hours are strategy inputs; broker-to-UTC mapping goes through the shared QM_DSTAware include (no hand-rolled DST).
- No new basket on Friday after `friday_cutoff_hour_utc` (default 17 UTC); adds also suspended after the Friday cutoff; no weekend carry.

### Filters
- Shock filter: skip the day when the first session bar's range exceeds `shock_atr_mult` (3.0) x ATR. The 13:00 bar median is ~2.8x ATR on the proxy feed, so the floor sits above the normal-open band and only extreme shock days are skipped (at 2.0, more than half of all sessions would be filtered).
- Spread filter: skip the entry when the current spread exceeds `spread_median_mult` x the 20-day median spread.
- News blackout: high-impact events (FOMC/NFP/CPI) inside `news_blackout_minutes` of an entry or an add block the fill (strategy hook over the live MT5 native calendar; fail-closed when the calendar is unavailable).
- Daily circuit breaker: stop trading for the day at `daily_stop_pct` (-1.0%) day P&L.
- Weekly circuit breaker: stop trading for the week at `weekly_stop_pct` (-2.0%) week P&L.
- No negative pyramiding, no martingale, no averaging into losers: adds require open profit and a new favourable extreme by construction.

## Deterministic risk contract (Family A — carried for programme uniformity)
Positive pyramiding is NOT tail-amplifying under STRATEGY_ELIGIBILITY_V2 §9, so no contract is required at intake; the complete Family A contract is carried anyway (programme uniformity + the joint-tail engine reads declared bounds from every sleeve). Machine copy: `risk_contract.json` in the source store.

| Field | Value |
|---|---|
| schema | qm.strategy-risk-contract/v1 |
| tail_amplifying | false (mechanism_flags: [positive_pyramiding]) |
| max_levels | 3 |
| sizing_progression | custom [1.0, 0.75, 0.5]; aggregate 2.25 initial legs |
| max_open_positions | 3 (per basket) |
| max_basket_exposure / max_gross_notional | 2.25 (initial-leg units) |
| max_margin_pct | 5.0 |
| max_basket_loss_pct | 0.5 (the equity adverse bound) |
| emergency_exit | equity_stop @ 0.5% adverse OR 50% giveback of peak open basket profit, whichever first; stops never widen |
| gap_sensitivity | SESSION-FLAT (no overnight/weekend by construction); sealed stress s01/s04/s05/s06/s08 pending |
| spread_slippage_sensitivity | NOT_EVALUATED (Q06 HARSH-class pending) |
| worst_historical_sequence / stress_sequence | EVIDENCE_MISSING / NOT_EVALUATED (governed pipeline) |
| session guarantee | mandatory flat by `flatten_hour_utc` (20 UTC); Friday cutoff 17 UTC; no weekend carry |
| portfolio breakers | daily -1.0%, weekly -2.0% (block new entries) |
| concurrent baskets | `max_positions_total` 1..3 (default 2) across the EA's symbol slots |

## Indicators and required data
Native MT5 price series, one EMA, one ATR, the instrument spread, and the live MT5 news calendar. No external feed.

## Timeframe
H1 for signals and basket management (an M15 execution variant, mirroring the H-CW card, is allowed); no D1 or higher signals.

## Symbols
NDX, GDAXI, SP500 index CFDs (symbols are inputs, never code literals; one input per symbol slot). No FX, no metals, no energy.

## Parameter ranges
- breakout_window_bars: 2 .. 4
- ema_period: 15 .. 30
- breakout_buffer_atr: 0.0 .. 0.05
- atr_period: 10 .. 20
- atr_stop_mult: 0.75 .. 1.25
- add2_trigger_atr: 1.0 .. 1.5
- add3_trigger_atr: 2.0 .. 3.0
- level2_size_mult: 0.75 .. 0.75
- level3_size_mult: 0.5 .. 0.5
- be_buffer_atr: 0.0 .. 0.1
- trail_atr_mult: 0.75 .. 1.25
- giveback_frac: 0.4 .. 0.5
- basket_adverse_bound_pct: 0.25 .. 0.5
- time_stop_bars: 4 .. 8
- risk_per_trade_pct: 0.20 .. 0.25
- daily_stop_pct: -1.0 .. -1.0
- weekly_stop_pct: -2.0 .. -2.0
- shock_atr_mult: 2.5 .. 3.5
- spread_median_mult: 1.25 .. 1.75
- session_start_hour_utc: 13 .. 14
- session_end_hour_utc: 16 .. 17
- flatten_hour_utc: 20 .. 21
- friday_cutoff_hour_utc: 17 .. 18
- max_positions_total: 1 .. 3
- news_blackout_minutes: 0 .. 120

| param | default |
|---|---|
| breakout_window_bars | 3 |
| ema_period | 20 |
| breakout_buffer_atr | 0.0 |
| atr_period | 14 |
| atr_stop_mult | 1.0 |
| add2_trigger_atr | 1.0 |
| add3_trigger_atr | 2.0 |
| level2_size_mult | 0.75 |
| level3_size_mult | 0.5 |
| be_buffer_atr | 0.05 |
| trail_atr_mult | 1.0 |
| giveback_frac | 0.5 |
| basket_adverse_bound_pct | 0.5 |
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
At most one basket per day per symbol by construction. The deterministic pilot fire count of these exact rules (NDX-class Dukascopy feed, 2018-2020 in-sample) recorded: 489 evaluated session days (154 shock-skipped at 3.0x), 187 gross signals, 185 taken baskets, 6.4 baskets/month and ~6.4 active days/month over 29 months; exits 73 base stops, 37 giveback stops, 75 session-flat flattens; level 2 filled in 11.9% of baskets, level 3 in 0% (the proxy feed never printed a second qualifying extreme — the level-3 leg is untested even at pilot level); raw outcome PF(R) 1.26 at +0.12R/basket, average peak open basket profit +0.77R, maximum +19.1R. These are honest pilot measurements for density calibration and feasibility only — IN-SAMPLE, ZERO-COST, SINGLE-FEED. Expect roughly 6-7 baskets per month per symbol, about 12-20 baskets per month across the three index symbols, with at least 8 active days per month — the same density order as the H-CW shell it reuses.

## Regime of failure
Trend exhaustion and clustered session reversals. Parabolic reversal immediately after level 3 prints converts the largest aggregate position at the worst prices — bounded by the breakeven-plus trail and the giveback stop, but repeated giveback exits are death by sequence. Correlated index symbols breaking out together concentrate the same-session giveback across baskets (NDX/GDAXI/SP500 share the cash-session factor). Choppy range sessions produce repeated small base-stop and giveback losses.

## Invalidation conditions
Refuted if, out of sample, the bounded pyramid does not beat its own flat base-leg baseline (H-CW shape) on expectancy or worst-day loss, or if the edge depends on a single symbol or single period. Refuted at programme level if the joint-tail protocol shows the family's worst days systematically coincide with the passive book's or the H-CW/H-MR sleeves' worst days (hidden common mode — the family is the tail carrier and must not join a multi-sleeve book).

## Falsification / kill criteria
Killed if:
1. Sealed OOS + Q06 HARSH-class evidence: expectancy after costs < +0.10R per basket or net profit factor < 1.20.
2. Simulated worst-day p95 of the built-out basket > 2.5% of equity at the 0.25% reference base risk, or Monte-Carlo P(hit the 4% effective daily-loss budget within 60 days) > 2%.
3. More than 50% of pyramids are stopped at the giveback stop before level 2 fills (the mechanism captures noise, not trends).
4. The giveback stop realizes more often than the profit-taking exits (trailing stop / session flat with positive basket P&L) across the sealed window with no regime explanation.
5. The joint-tail protocol (PORTFOLIO_TAIL_RISK_RESEARCH.md §4) fails against the H-CW/H-MR/passive-book streams — worst-day overlap beyond the independence baseline or materially positive lower-tail dependence — before any book claim.
6. H-CW-class gates: realized swap/rollover cost > 10% of gross P&L; more than half of the +-1-step parameter neighbourhood shows negative expectancy; any single month with < 8 active days.

## Q08/Q11 crisis and news risk
Session-flat exposure removes overnight gap risk — the tail a built-out basket fears most is removed by construction, not by stop placement. The shock and spread filters and the live news filter fail closed; adds are suspended inside the news blackout like entries. Q08 stress and Q11 full-history confirmation remain the judges before any book placement; the Family A stress set (s01 gap x1, s04 spread x2, s05 spread x3+slippage, s06 news shock, s08 combined worst) must be run sealed before any FTMO claim.

## FTMO fit
Zero overnight exposure (swap ~ 0, no gap-through-stop on a built-out basket), a hard 0.5% equity basket bound plus a -1.0% daily / -2.0% weekly breaker stack far inside the FTMO 5% daily and 10% total drawdown limits, and the high-impact news blackout keeps FOMC/NFP/CPI windows closed. The -10.26% demo breach was produced by overnight/swap tails on carried positions; the session-flat envelope is precisely the defence, and the bounded pyramid adds convex trend capture inside it rather than a new tail. As the aggressive family admitted to FTMO evaluation at programme stage (Family A is FTMO-primary per the programme), it stacks inside the 4% effective joint daily-loss budget with the passive book — but only after the joint-tail protocol clears it against the H-CW/H-MR streams.

## Concepts
- [[concepts/session-flat-intraday]] - primary
- [[concepts/positive-pyramiding]] - secondary

## R1-R4 assessment
| Criterion | Status | Rationale |
|-----------|--------|------------|
| R1 Source-Link | PASS | Internal research source QM-RESEARCH-2026-0007 with lineage, manifest-backed numeric provenance, and preregistration hash (f601ba6a...cfcb). Cross-vendor critic PENDING (REVIEW_PENDING). |
| R2 Mechanical | PASS | Opening-range breakout base leg, ATR/EMA-gated adds, never-widening ratchet basket stop, giveback stop, equity adverse bound, time stop, flatten hour, filters, and breakers are all explicit closed-bar rules. |
| R3 DWX-testbar | PASS | Uses only H1 OHLC-derived EMA/ATR, the instrument spread, and the native news calendar on DWX index symbols (NDX/GDAXI/SP500). |
| R4 No ML | PASS | Fixed mechanical parameters, no ML, no online adaptation, one basket per symbol per day, adds only at confirmed profit; no martingale/grid/negative pyramiding. |

## Framework Alignment
- Strategy_NoTradeFilter: H1-chart + slot + locked-configuration range guards only (never blocks exits).
- Strategy_EntrySignal: completed H1 bar opening-range breakout plus EMA-side confirmation; one basket per symbol per day; market order with the initial basket stop attached.
- Strategy_ManageOpenPosition: the core of this card — level 2/3 add triggers (ATR-scaled open profit + new favourable extreme), the never-widening basket-stop ratchet (blended breakeven-plus, then ATR trail), the peak-open-profit tracker, the giveback stop, and the hard equity adverse bound. Management runs on every bar close and can never be gated away by entry filters.
- Strategy_ExitSignal: basket stop (intrabar), giveback/adverse-bound exits (bar close), time stop after `time_stop_bars`, mandatory session-flat flatten at `flatten_hour_utc`.
- Session/shock/spread/breaker/capacity/news gates: evaluated in the new-bar entry path, mirroring the H-CW/H-MR integration so flatten exits and basket management can never be gated away.
- Strategy_NewsFilterHook: returns false (defers to the framework); the card's high-impact blackout is enforced in the new-bar entry path only (entries and adds).

## Pipeline history
- G0: 2026-09-16, APPROVED under OWNER_DIRECT_SESSION_DELEGATION to Kimi (review_status REVIEW_PENDING; independent non-Kimi critique gated: claude disabled until 2026-09-17, codex on hold until 2026-09-19, agy quota-dead). ea_id 41479 reserved by filename convention only — no registry row allocated; the central allocator runs later.

## Related strategies
- QM5_41475 cash-window-index-continuation-h1 (H-CW; the base entry envelope this card reuses — H-PY is the same signal with a bounded pyramid on top).
- QM-RESEARCH-2026-0006 H-MR cash-open index mean reversion (session sibling; same feed/pilot conventions, opposite side of the opening range).
- QM-RESEARCH-2026-0002 (H-CW parent campaign context).

## Lessons Learned
- TBD during pipeline run.
