---
ea_id: QM5_20022
slug: wti-wed-long
type: strategy
strategy_id: LI-WTI-DOW-2022_S01
source_id: LI-WTI-DOW-2022
status: APPROVED
created: 2026-07-21
created_by: Research+Development
last_updated: 2026-07-21
g0_status: APPROVED
g0_approval_reasoning: "OWNER commodity-sleeve mission delegates one concrete source-backed build: R1 peer-reviewed Energy Economics primary source; R2 exact Wednesday-long/next-D1-flat rule; R3 registered XTIUSD D1 route; R4 calendar/ATR only; exact mechanic dedup CLEAN."
source_citation: "Li, W., Zhu, Q., Wen, F. & Nor, N.M. (2022). The evolution of day-of-the-week and the implications in crude oil market. Energy Economics 106, 105817."
source_citations:
  - type: academic_paper
    citation: "Li, Wenhui; Zhu, Qi; Wen, Fenghua; Mohd Nor, Normaziah (2022). The evolution of day-of-the-week and the implications in crude oil market. Energy Economics 106, 105817."
    location: "Abstract and highlights; DOI https://doi.org/10.1016/j.eneco.2022.105817; bibliographic index https://www.econbiz.de/10013202138"
    quality_tier: A
    role: primary
sources: ["[[sources/LI-WTI-DOW-2022]]"]
concepts: ["[[concepts/wti-calendar-seasonality]]", "[[concepts/inventory-schedule-weekday]]"]
indicators: ["[[indicators/atr]]"]
strategy_type_flags: [calendar-seasonality, day-of-week, long-only, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
period: D1
primary_target_symbols: [XTIUSD.DWX]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
expected_trade_frequency: "About 45-52 WTI one-session packages/year; Q02 must verify at least five completed packages/year."
expected_trades_per_year_per_symbol: 48
expected_pf: 1.02
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: QUEUED
q02_work_item_id: 319e25f2-f50a-4c93-9d51-123100c5cb22
review_focus: "Adds a scheduled energy-information weekday driver; falsify costs, session mapping, post-2021 decay and realized book correlation without changing the portfolio gate."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, risk_mode_dual, cfd_source_basis, calendar_mapping, portfolio_correlation]
---

# WTI Wednesday One-Session Long

## Hypothesis and source boundary

Li, Zhu, Wen and Nor report an abnormal positive Wednesday return in WTI over
2007-05-14 through 2021-05-14 and associate its timing with the scheduled
inventory-information shock. They also find that crude-oil weekday efficiency
changes over time. The paper supports one sparse Wednesday carrier, not a
claim that the anomaly remains profitable.

The source is the sole alpha lineage. ATR, spread, news, fixed-risk and restart
controls are QM plumbing. No inaccessible coefficient or p-value is invented.

## Non-duplicate decision

Repository-wide card/EA searches found no unconditional `XTIUSD.DWX`
Wednesday-long, next-D1-flat carrier. Nearby EAs are materially different:

- `QM5_12567` uses cumulative RSI pullback logic.
- `QM5_20008` and `QM5_20014` use monthly channel breakouts.
- `QM5_20015` is a multi-month Halloween/winter hold.
- `QM5_20016` is an XTI/XNG Monday reversal basket.
- `QM5_20020` and `QM5_20021` use numbered-day/month-half shorts.
- energy inventory EAs condition on event timestamps or surprise state.

This is a scheduled energy-information calendar driver, not a metal/index
price-indicator port. Different mechanics do not prove low correlation; that
remains a downstream kill test.

## Entry rules

- On a genuine new `XTIUSD.DWX` D1 bar, require broker `day_of_week == 3`
  (Wednesday, Sunday=0).
- Consume the day's attempt before news, spread, ATR, price or order checks;
  never retry or shift a blocked Wednesday signal.
- Require D1 host, slot 0, no same-magic position/entry, and spread at most
  2500 points.
- BUY once with a frozen hard stop `2.75 * ATR(20)` from the prior completed
  D1 bar and no take-profit.

## Exit and management rules

- Flatten at the first D1 bar following entry, before new-entry news gates.
- Retry the close throughout that bar; also close after one calendar day as a
  stale guard.
- Framework Friday close remains enabled at broker hour 21.
- No trailing, break-even, partial close, scale, pyramid, grid, martingale,
  short leg, discretionary exit or external runtime data.

## Parameters to test

| parameter | locked value | role |
|---|---:|---|
| `strategy_entry_dow` | 3 | broker Wednesday |
| `strategy_atr_period` | 20 | completed D1 ATR stop estimate |
| `strategy_atr_sl_mult` | 2.75 | frozen hard-stop distance |
| `strategy_max_hold_days` | 1 | stale close guard |
| `strategy_max_spread_points` | 2500 | entry spread cap |

No parameter sweep is authorized.

## Risk and kill criteria

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Retire for fewer than five completed packages/year,
wrong-day entries, duplicate attempts, invalid risk mode, nondeterminism, or
failure of governed PF/DD criteria. Later gates must reject the sleeve if its
realized return stream does not diversify the book.

Primary risks are post-publication decay, time-varying efficiency, inventory
holiday rescheduling, broker-day versus NYMEX-settlement mismatch, continuous
futures/CFD basis, gaps and financing.

## Framework alignment

- no_trade: exact symbol/D1/slot and locked parameters.
- trade_entry: restart-safe Wednesday attempt, BUY and frozen ATR stop.
- trade_management: next-D1 and stale closure before entry-news gating.
- trade_close: framework close API, Friday close and broker hard stop.

## Pipeline history

| version | date | reason | phase | verdict |
|---|---|---|---|---|
| v1 | 2026-07-21 | initial source-backed WTI Wednesday build | G0 | APPROVED |
| v1-q02 | 2026-07-21 | strict compile PASS and priority enqueue | Q02 | PENDING 319e25f2-f50a-4c93-9d51-123100c5cb22 |

## Safety boundary

This card authorizes one research/backtest build and Q02 enqueue only. It does
not authorize a live setfile, AutoTrading, T_Live, deploy/T_Live manifests,
portfolio admission, or any portfolio-gate change.
