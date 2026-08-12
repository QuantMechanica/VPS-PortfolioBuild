---
strategy_id: BURAKOV-WTI-HALLOWEEN-2018_S02
source_id: BURAKOV-WTI-HALLOWEEN-2018
ea_id: QM5_20046
slug: wti-halloween-ls
status: APPROVED
created: 2026-07-22
created_by: Research+Development
last_updated: 2026-07-22
g0_status: APPROVED
source_citations:
  - type: academic_paper
    citation: "Burakov, D., Freidin, M. and Solovyev, Y. (2018). The Halloween Effect on Energy Markets: An Empirical Study. International Journal of Energy Economics and Policy 8(2), 121-126."
    location: "Section 3 alternative-one definition and Tables 2-3 West Texas row; https://www.econjournals.com/index.php/ijeep/article/view/6092"
    quality_tier: B
    role: primary
strategy_type_flags: [calendar-seasonality, monthly-renewal, symmetric-long-short, atr-hard-stop, time-stop]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
expected_trades_per_year_per_symbol: 12
pipeline_phase: Q02
review_focus: "Adds a two-sided WTI calendar return driver; Q02 must falsify costs, CFD basis and the summer short leg before any decorrelation claim."
r1_track_record: TIER_B
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
g0_approval_reasoning: "OWNER commodity-sleeve mission: tier-B peer-reviewed full-source lineage; fixed WTI six/six monthly long-short calendar regime; registered XTIUSD.DWX D1; deterministic ATR/risk controls with no ML or banned indicators; distinct from long-only QM5_20015."
expected_pf: 1.01
expected_dd_pct: 35.0
---

# WTI Symmetric Halloween Regime

## Hypothesis and source boundary

Burakov, Freidin and Solovyev test the conventional Halloween partition in energy futures. This card translates that fixed calendar partition to one monthly-renewed WTI CFD position: long November through April and short May through October. The source is lineage, not a performance guarantee; futures/CFD basis, financing, gaps and post-sample decay remain kill risks.

## Rules

- On the first tradable `XTIUSD.DWX` D1 bar of each broker month, close the prior package before considering entry.
- BUY in broker months 11, 12, 1, 2, 3 and 4; SELL in months 5 through 10.
- Consume one persisted attempt per broker month before spread, ATR, news or order checks; never re-enter after a stop in the same month.
- Attach a frozen completed-bar `ATR(20) * 4.0` hard stop; close stale exposure after 35 calendar days.
- Require slot 0, D1, spread no greater than 1500 points, and valid native MT5 metadata.
- Disable Friday close because the source regime necessarily spans weekends. Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- No price filter, oscillator, ML, external feed, grid, martingale, pyramiding, live setfile or portfolio-gate change.

## Entry Rules

- At the first tradable D1 bar of a new broker month, BUY during November-April and SELL during May-October.
- Require the persisted monthly-attempt, spread, completed ATR, risk-mode and framework guards described above.

## Exit Rules

- Close the prior package at the first tradable D1 bar of the next broker month before renewal.
- Close after 35 calendar days as a stale guard or at the frozen broker-side ATR hard stop.

## Non-duplicate decision

`QM5_20015` is long-only November-May and flat otherwise. This card is a symmetric six/six regime whose May-October short carrier is load-bearing. It is also not the one-session weekday/day-of-month WTI family, not RSI logic, and not an XNG port.

## Expected frequency and kill criteria

Expected density is 12 monthly packages/year. Retire below five completed packages/year, on zero trades, wrong month direction, duplicate monthly attempts, nondeterminism, risk-mode mismatch, or governed net-economics failure. Do not optimize the month partition or invert a weak result.

## Framework alignment

- no_trade: exact symbol/D1/slot, locked constants, spread and monthly-attempt guards.
- trade_entry: calendar-selected BUY/SELL with a frozen ATR stop.
- trade_management: month-boundary renewal and 35-day stale close.
- trade_close: framework strategy close and broker hard stop.

## Safety boundary

This OWNER commodity-sleeve mission authorizes the card, research build and Q02 enqueue only. No `T_Live`, AutoTrading, deploy/T_Live manifest, live preset, portfolio admission or portfolio-gate edit is authorized.

## Pipeline status

- Q01: PASS — strict compile 0 errors/0 warnings; build check 0 failures/0 warnings.
- Q02: QUEUED — work item `68028ce6-8a03-4bc9-bef0-14387da6742d`.
