---
ea_id: QM5_12966
slug: gdaxi-weekly-oversold-swing
type: strategy
source_id: CEO-SURVIVOR-PORT-12915-2026-07-03
source_citation: "Survivor port of QM5_12915 sp500-weekly-oversold-swing (Q02 PASS -> Q04 PASS_LOWFREQ -> Q05 PASS -> Q06 PASS same-night 2026-07-02/03, evidence D:/QM/reports/work_items). Family basis: Connors & Alvarez (2009), Short Term Trading Strategies That Work; Zakamulin (2014), J. Asset Management (200-day filter)."
sources:
  - "[[sources/CEO-SURVIVOR-PORT-12915-2026-07-03]]"
concepts:
  - "[[concepts/index-mean-reversion]]"
  - "[[concepts/survivor-port]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/lowest-low]]"
strategy_type_flags: [mean-reversion, trend-filtered, swing, multi-day-hold, long-only, low-frequency, survivor-port]
target_symbols: [GDAXI.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Deep multi-day pullbacks within secular uptrend; ~6-12 setups/year, 5-15 trading-day holds."
expected_trades_per_year_per_symbol: 9
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Identical-mechanic parent QM5_12915 cleared Q02/Q04/Q05/Q06 on SP500 within one night; family evidence: cum-rsi2 index MR is a live book sleeve (11132). Port follows the 12567 survivor-port pattern that produced a book sleeve."
r2_mechanical: PASS
r2_reasoning: "Entry: close > SMA(200) AND close = lowest close of last 10 D1 bars. Exit: close > SMA(10) OR 15-trading-day time stop. Parameters IDENTICAL to parent (no re-optimization - port purity)."
r3_data_available: PASS
r3_reasoning: "GDAXI.DWX D1 fully covered; index commission ~$4.4/rt, gross~net."
r4_ml_forbidden: PASS
r4_reasoning: "No ML/grid/martingale; fixed parameters; one position per magic."
pipeline_phase: G0
last_updated: 2026-07-03
expected_pf: 1.30
expected_dd_pct: 15.0
g0_approval_reasoning: "R1 survivor parent 12915 plus Connors/Zakamulin; R2 locked 200/10/10/15 D1 port; R3 GDAXI.DWX matrix; R4 deterministic long-only, no ML/grid."
---

# GDAXI Weekly-Horizon Oversold Swing (survivor port of QM5_12915)

## Edge / Thesis

Identical mechanic to QM5_12915 (which cleared Q02->Q06 in one night on SP500):
deep multi-day liquidation clusters inside a secular uptrend mean-revert at swing
horizon. DAX offers a different session anchor (European cash hours), different
macro drivers (EUR rates, exporters) and a cheap-commission venue. Port purity:
parameters unchanged from parent - the pipeline judges the port, not a re-fit.

## Mechanics (deterministic, closed D1 bars)

1. Regime: close > SMA(200).
2. Entry (long only): today's close is the lowest close of the last 10 D1 bars.
3. Exit: close > SMA(10) OR 15 trading days elapsed.
4. One position per magic; RISK_FIXED backtest; news gate entries-only; weekend
   hold allowed, Friday close DISABLED (swing class).

## Parameters (locked to parent)

- sma_regime = 200, entry_lookback_low = 10, sma_exit = 10, time_stop_days = 15

## G0 Build Coverage

- Source citation: 2009 Connors & Alvarez plus 2014 Journal timing-filter evidence; survivor-port lineage from QM5_12915 is the controlling source.
- Entry: On closed D1 bars, buy GDAXI.DWX when close > SMA(200) and the close is the lowest close of the last 10 D1 bars.
- Exit: Close when D1 close > SMA(10) or after 15 trading days, whichever comes first.
- Stop: No fixed price stop in the source mechanic; the 15-trading-day time stop plus V5 risk/kill controls bound the backtest implementation.
- Target symbols: GDAXI.DWX.
- Period: D1.
- Expected trade frequency: about 9 trades/year/symbol.

## Risks / Kill Criteria

DAX bear transitions whipsaw the 200-SMA filter; Q04 folds include 2018/2022.
Kill on pooled Q04 net PF < 1.0. No parameter changes - a failing port dies as a port.
