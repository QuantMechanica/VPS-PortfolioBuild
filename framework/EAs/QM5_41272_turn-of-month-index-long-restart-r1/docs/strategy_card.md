---
ea_id: QM5_41272
slug: turn-of-month-index-long-restart-r1
type: strategy
source_id: fx_edge_army_A3_2026-07-16_restart_recovery_9a55
source_citation: "Faithful new-identity recovery of OWNER-approved QM5_20004 card; authority task 2e0bc944-0f47-47e2-b6c2-e7b83db89147 (OWNER 2026-09-01). Original sources: McConnell & Xu (2008), DOI 10.2469/faj.v64.n2.11; Lakonishok & Smidt (1988)."
sources:
  - "D:/QM/strategy_farm/artifacts/cards_approved/QM5_20004_turn-of-month-index-long.md"
  - "docs/ops/evidence/2026-09-01_f91d364b_july_strategy_cards_phase1_audit.md"
concepts: [turn-of-month-calendar-flow, long-only-index-overlay, restart-safe-trading-day-exit]
indicators: [trading-day-counter, sma-trend-filter, atr-stop]
target_symbols: [NDX.DWX]
logical_symbol: QM5_41272_NDX_TURN_OF_MONTH_D1
period: D1
expected_trade_frequency: "Approximately 12 long events/year on NDX.DWX."
expected_trades_per_year_per_symbol: 12
g0_status: APPROVED
g0_approval_authority: "OWNER task 2e0bc944-0f47-47e2-b6c2-e7b83db89147, 2026-09-01"
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-09-01
supersedes_runtime_identity: QM5_20004
new_identity_reason: "Sealed doctrine: corrected executable identity restarts at Q02; old Q04-Q06 evidence remains historical and is never rebound."
---

# Turn-of-month index long — restart-safe recovery

This card authorizes a faithful, NDX-only port of the approved
`QM5_20004_turn-of-month-index-long` mechanics into the fresh registry identity
`QM5_41272`. It does not authorize a threshold, universe, economic, selection,
or pipeline-gate change. The old identity and all of its evidence remain
untouched.

## Entry

On the new-month calendar edge observed from the index D1 stream, enter one
long NDX.DWX position at the first available price. When the optional trend
filter is enabled, require the prior D1 close to be at or above SMA(50).
Permit at most one owned position. Default trend SMA period remains 50.

## Exit and restart invariant

Exit after `strategy_exit_day_n=3` completed trading-day transitions from the
position's actual open time. The counter is based on NDX.DWX D1 bar history,
not elapsed calendar days.

On every initialization with an inherited owned position, read
`POSITION_TIME`, locate the D1 bar containing that timestamp, and reconstruct
the number of completed D1 trading-day transitions up to the current D1 bar.
Never adopt today's day key as if the inherited position opened today. A
terminal/EA restart therefore cannot extend the authorized holding period.

## Stop, sizing, and controls

- Initial protective stop: 3.0 × ATR(20), unchanged.
- No fixed take profit; the calendar exit is authoritative.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Mandatory DXZ high-impact news blackout, stale-news ceiling 336 hours.
- Friday close remains enabled at broker hour 21.
- No ML, HFT, martingale, grid, averaging, or live authorization.

## Review boundary

Build and compile are allowed under the OWNER recovery task. Q02 enqueue is
allowed only after independent Orchestrator build review. No historical row or
verdict may be overwritten or rebound to the new binary.
