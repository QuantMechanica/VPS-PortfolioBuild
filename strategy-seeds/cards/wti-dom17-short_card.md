---
ea_id: QM5_20020
slug: wti-dom17-short
type: strategy
strategy_id: BOROWSKI-WTI-DOM17-2016_S01
source_id: BOROWSKI-WTI-DOM17-2016
status: APPROVED
created: 2026-07-20
created_by: Research+Development
last_updated: 2026-07-20
g0_status: APPROVED
g0_approval_reasoning: "OWNER commodity-sleeve mission: tier-B complete peer-reviewed source; exact WTI day-17 short/next-D1 flat falsification rule; registered XTIUSD D1 route; calendar/ATR only; repository-wide exact-mechanic search CLEAN."
source_citations:
  - type: academic_paper
    citation: "Borowski, K. (2016). Analysis of Selected Seasonality Effects in Markets of Future Contracts with the Following Underlying Instruments: Crude Oil, Brent Oil, Heating Oil, Gas Oil, Natural Gas, Feeder Cattle, Live Cattle, Lean Hogs and Lumber. Journal of Management and Financial Sciences, issue 26, 27-44."
    location: "Section 4.3, pp. 36-37; complete author copy https://www.researchgate.net/publication/303285422_ANALYSIS_OF_SELECTED_SEASONALITY_EF-_FECTS_IN_MARKETS_OF_FUTURE_CONTRACTS_WITH_THE_FOLLOWING_UNDERLYING_INSTRUMENTS_CRUDE_OIL_BRENT_OIL_HEATING_OIL_GAS_OIL_NATURAL_GAS_FEEDER_CATTLE_LIVE_CATTLE_LEAN_HOGS_AND_LUMBER"
    quality_tier: B
    role: primary
strategy_type_flags: [calendar-seasonality, day-of-month, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
period: D1
primary_target_symbols: [XTIUSD.DWX]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
expected_trade_frequency: "About 8-10 one-session packages/year; Q02 must verify at least five/year."
expected_trades_per_year_per_symbol: 9
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: TIER_B
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: PENDING_ENQUEUE
modules_used: [no_trade, trade_entry, trade_management, trade_close]
---

# WTI Calendar-Day-17 One-Session Fade

## Concept and evidence boundary

Borowski studies NYMEX crude-oil futures from 1983-03-30 through 2016-03-31. In
the paper's 31-way day-of-month search, the session dated the 17th has the
lowest crude-oil mean, `-0.7016%`. This card tests the literal recurring
calendar carrier on the Darwinex WTI CFD: short the D1 session dated exactly
the 17th and flatten at the next D1 bar.

This is a sparse falsification candidate, not a certification claim. The paper
reports significance for crude-oil dates 8 and 26, not date 17, and applies no
reported multiple-comparison correction. Day 17 is selected from the reported
extreme and may be noise. Futures/CFD basis, post-2016 decay, spread, gaps and
roll construction can erase it. Those facts are hard kill criteria, not
details to optimize away.

## Non-duplicate decision

Repository-wide searches found no WTI day-17 one-session short carrier. This
is not `QM5_12567` cumulative-RSI pullback logic; not WTI month, weekday,
turn-of-month, weekend, expiry, inventory, trend, reversal or spread logic;
and not `QM5_20017` XNG day-15 long. The signal is calendar state only. Any
realized correlation claim remains for the downstream portfolio gate, which
this work does not alter.

## Entry rules

- On a new `XTIUSD.DWX` D1 bar, act only when broker calendar day equals 17.
- If no tradable D1 bar is dated 17, skip the month; never shift the date.
- Allow one attempt per broker month, persisted across restart and consumed
  before news, spread, ATR, price or order checks.
- Require no same-magic position/deal, valid nonnegative spread no greater
  than 2500 points, and completed-bar `ATR(20)`.
- Sell one fixed-risk package with frozen stop `entry + 2.75 * ATR(20)` and no
  take-profit. Backtest mode is `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Exit and management rules

- Close at the first D1 bar after entry; retry throughout that bar if needed.
- Close after one calendar day as a stale guard.
- Friday close remains enabled at broker hour 21.
- No trailing stop, break-even, partial close, scale-in, grid, martingale,
  pyramiding, long leg, adaptive parameter or external runtime data.

## Locked parameters

| parameter | value |
|---|---:|
| `strategy_entry_day` | 17 |
| `strategy_atr_period` | 20 |
| `strategy_atr_sl_mult` | 2.75 |
| `strategy_max_hold_days` | 1 |
| `strategy_max_spread_points` | 2500 |

Q02 retires the candidate for fewer than five completed packages/year, zero
trades, shifted-date behavior, duplicate monthly attempts, risk-mode mismatch,
nondeterminism, or failure of governed net PF/DD criteria. No parameter sweep
is authorized for this baseline.

## Author claim

The paper states that crude oil's highest and lowest numbered-day means were
`0.0338%` on day 1 and `-0.7016%` on day 17 (Section 4.3). It separately lists
days 8 and 26 as significant mean differences. No stronger inference is made.

## Framework alignment

- no_trade: exact symbol/D1/slot and locked baseline validation.
- trade_entry: exact broker day 17, monthly attempt guard, short order and
  frozen ATR stop.
- trade_management: next-D1 and one-day stale closure before entry gates.
- trade_close: strategy close helper, framework Friday close and broker stop.

## Safety boundary

This mission-approved card authorizes one research/backtest build and Q02
enqueue only. It does not authorize a live setfile, AutoTrading, T_Live,
deployment manifests, portfolio admission or portfolio-gate changes.
