---
ea_id: QM5_12969
slug: usdjpy-gotobi-nakane-fix
type: strategy
source_id: CEO-ANOMALY-SLATE-2026-07-03
source_citation: "Ito, T. & Yamada, M. (2017). Puzzles in the Tokyo fixing in the forex market. Journal of the Japanese and International Economies 44 (documents systematic USDJPY appreciation into the 9:55 JST Nakane fix on corporate settlement days and reversal after); BOJ/academic coverage of the gotobi settlement convention (dates ending 5/0)."
sources:
  - "[[sources/CEO-ANOMALY-SLATE-2026-07-03]]"
concepts:
  - "[[concepts/tokyo-fix-nakane]]"
  - "[[concepts/gotobi-settlement-days]]"
indicators: []
strategy_type_flags: [calendar-session, fix-anomaly, intraday, long-then-flat, deterministic-clock, no-indicators]
target_symbols: [USDJPY.DWX]
single_symbol_only: true
period: M30
expected_trade_frequency: "Observed executable frequency on the bound 2017-2022 Q02: 213 trades / 6 years = 35.5 trades/year. Nominal gotobi opportunities remain approximately 65-72/year, but calendar mapping and guards reduce executed frequency."
expected_trades_per_year_per_symbol: 36
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Peer-reviewed (Ito & Yamada 2017, JJIE): the Tokyo 9:55 fix shows systematic pre-fix USDJPY appreciation on corporate settlement (gotobi) days driven by importer dollar demand - a structural flow anomaly, not price-pattern folklore. Widely traded by Japanese retail yet barely mechanized in western books."
r2_mechanical: PASS
r2_reasoning: "Entry: on gotobi weekdays (calendar day ends in 5 or 0; if weekend/holiday-shifted, next business day per Japanese convention) BUY USDJPY at 00:00 broker time corresponding to Tokyo morning open window; exit at the bar covering 9:55 JST (fix), hard time-based. All calendar+clock, zero indicators, closed-bar M30. Broker-time mapping documented per DXZ GMT+2/+3 convention (JST = broker+6/+7 - must be derived in code from the documented offset, never hardcoded ambiguous)."
r3_data_available: PASS
r3_reasoning: "USDJPY.DWX M30 is fully covered. The 02:00-09:55 JST holding interval maps across broker rollover in the tested server-time convention, so the strategy is swap-bearing despite being same-JST-day. Current FTMO commission and swap must be reconciled for every release."
r4_ml_forbidden: PASS
r4_reasoning: "No indicators at all; pure calendar/clock; one position per magic; no grid/ML."
pipeline_phase: G0
last_updated: 2026-07-17
expected_pf: 1.25
expected_dd_pct: 12.0
q03_axis_name: strategy_risk_stop_pips
q03_axis_type: int
q03_axis_values: [60, 90, 120, 150, 180, 240, 360]
q03_axis_authorization: "OWNER 2026-07-17: sole authorized Q03 axis; entry/exit clocks, holiday proxy, spread guard and portfolio weight remain locked."
g0_approval_reasoning: "R1 Ito/Yamada Tokyo-fix source; R2 gotobi/JST clock entry-exit mechanical; R3 USDJPY.DWX M30; R4 no indicators/ML, one position; DST mapping required."
---

# USDJPY Gotobi Nakane-Fix Drift (Tokyo 9:55 fix flow anomaly)

## Edge / Thesis

Japanese importers settle USD invoices on gotobi days (calendar days ending in 5/0).
Banks source the dollars ahead of the 9:55 JST Nakane fix, creating systematic USDJPY
buying pressure Tokyo-morning on those days, documented to reverse post-fix (Ito &
Yamada 2017). The flow is structural (payment convention), recurring, and clock-precise -
the ideal mechanical shape: no indicators, only calendar and clock.

## Mechanics (deterministic)

1. Gotobi day determination: calendar day of month in {5,10,15,20,25,30}; if it falls on
   Sat/Sun (or Jan 1-3), the settlement rolls FORWARD to the next business day (Japanese
   convention) - that business day is the trading day. Implement via QM_CalendarPeriodKey
   D1 keys (corset-compliant, no raw iTime).
2. Entry: BUY USDJPY at the first M30 bar of the Tokyo window (02:00 JST equivalent in
   broker time; exact offset from the documented DXZ broker-time model, DST-aware).
3. Exit: close the position on the M30 bar containing 09:55 JST (the fix). Hard time exit.
4. Optional guard (input, default on): skip if the day is a Japanese bank holiday
   (approximated: no Tokyo-session tick volume in the first hour - deterministic proxy).
5. Catastrophic stop: 120 pips is the approved baseline required by the V5 fixed-risk
   sizing path. It is not the anomaly's intended exit. Q03 may vary only this stop over
   [60, 90, 120, 150, 180, 240, 360] and must select the plateau median.
6. One position per magic; RISK_FIXED backtest; news gate entries-only.

## Parameters

- `strategy_entry_jst_hhmm = 0200` - locked; source-defined, not tunable.
- `strategy_exit_jst_hhmm = 0955` - locked; source-defined, not tunable.
- `strategy_holiday_volume_proxy_enabled = true` - locked during Q03.
- `strategy_risk_stop_pips = 120` - approved baseline and sole authorized Q03 axis:
  `[60, 90, 120, 150, 180, 240, 360]`.
- `strategy_max_spread_points = 0` - locked during Q03.
- `PORTFOLIO_WEIGHT = 1.0` - locked during Q03.

## G0 Build Coverage

- Source citation: 2017 Journal of the Japanese and International Economies paper on the Tokyo fixing/gotobi effect; one canonical source_id controls lineage.
- Entry: On gotobi business days, buy USDJPY.DWX at the M30 bar corresponding to the Tokyo morning entry window with DST-aware broker-time mapping.
- Exit: Close on the M30 bar containing the 09:55 JST Nakane fix.
- Stop: The anomaly-defined exit is the hard time exit. A 120-pip catastrophic stop is the approved V5 sizing baseline; only its OWNER-authorized Q03 lattice may vary, with no same-day re-entry.
- Target symbols: USDJPY.DWX.
- Period: M30.
- Expected executable trade frequency: 35.5 observed trades/year (213 trades over 2017-2022); planning value 36. Nominal gotobi opportunities remain approximately 65-72/year.
- Rollover/cost contract: the same-JST-day position crosses broker rollover. The 2026-07-17 FTMO recost observed 321 rollover units and +$465.61 swap across 213 long trades; swap sign and magnitude are snapshot-dependent and must be refreshed.
## Risks / Kill Criteria
BoJ intervention days produce outsized adverse moves (2022/2024 in-sample - good).
The anomaly weakened post-2016 per some studies - Q04 folds decide. Kill on pooled
net PF < 1.0. The anomaly-defined entry and exit clocks are never tunable, and the
holiday proxy remains locked on. Under OWNER authorization dated 2026-07-17, the sole
Q03 axis is the catastrophic stop distance [60, 90, 120, 150, 180, 240, 360]. Q03 is a
native Model-4 plateau test; the selected median must subsequently pass current FTMO
commission and swap reconciliation.
