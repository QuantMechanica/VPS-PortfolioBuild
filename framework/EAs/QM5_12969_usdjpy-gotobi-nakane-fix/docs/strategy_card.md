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
expected_trade_frequency: "One trade per gotobi calendar day (5th/10th/15th/20th/25th/30th, weekday-shifted); ~65-72 trades/year."
expected_trades_per_year_per_symbol: 68
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Peer-reviewed (Ito & Yamada 2017, JJIE): the Tokyo 9:55 fix shows systematic pre-fix USDJPY appreciation on corporate settlement (gotobi) days driven by importer dollar demand - a structural flow anomaly, not price-pattern folklore. Widely traded by Japanese retail yet barely mechanized in western books."
r2_mechanical: PASS
r2_reasoning: "Entry: on gotobi weekdays (calendar day ends in 5 or 0; if weekend/holiday-shifted, next business day per Japanese convention) BUY USDJPY at 00:00 broker time corresponding to Tokyo morning open window; exit at the bar covering 9:55 JST (fix), hard time-based. All calendar+clock, zero indicators, closed-bar M30. Broker-time mapping documented per DXZ GMT+2/+3 convention (JST = broker+6/+7 - must be derived in code from the documented offset, never hardcoded ambiguous)."
r3_data_available: PASS
r3_reasoning: "USDJPY.DWX M30 fully covered; cheapest FX pair; intraday only = zero swap."
r4_ml_forbidden: PASS
r4_reasoning: "No indicators at all; pure calendar/clock; one position per magic; no grid/ML."
pipeline_phase: G0
last_updated: 2026-07-03
expected_pf: 1.25
expected_dd_pct: 12.0
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
5. One position per magic; RISK_FIXED backtest; news gate entries-only.

## Parameters

- entry_jst_hhmm = 0200, exit_jst_hhmm = 0955 (fixed by the anomaly, not tunable)
- holiday_volume_proxy_enabled = true

## G0 Build Coverage

- Source citation: 2017 Journal of the Japanese and International Economies paper on the Tokyo fixing/gotobi effect; one canonical source_id controls lineage.
- Entry: On gotobi business days, buy USDJPY.DWX at the M30 bar corresponding to the Tokyo morning entry window with DST-aware broker-time mapping.
- Exit: Close on the M30 bar containing the 09:55 JST Nakane fix.
- Stop: No fixed price stop in the anomaly definition; use the hard time exit plus V5 risk/kill controls, with no re-entry for the same gotobi day.
- Target symbols: USDJPY.DWX.
- Period: M30.
- Expected trade frequency: about 68 trades/year/symbol.
## Risks / Kill Criteria
BoJ intervention days produce outsized adverse moves (2022/2024 in-sample - good).
The anomaly weakened post-2016 per some studies - Q04 folds decide. Kill on pooled
net PF < 1.0; the time window is NOT tunable (anomaly-defined) - no sweep beyond the
optional holiday guard on/off.

