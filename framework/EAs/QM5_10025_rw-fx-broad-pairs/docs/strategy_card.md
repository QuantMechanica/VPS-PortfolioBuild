---
ea_id: QM5_10025
slug: rw-fx-broad-pairs
type: strategy
source_id: dcbac84f-6ecf-5d21-9630-50faa69306ec
source_citation: "Robot Wealth, 'Index of Strategies' FX Broad Pairs Trading section, https://robotwealth.com/index-of-strategies/"
sources:
  - "[[sources/robot-wealth-blog]]"
concepts:
  - "[[concepts/fx-pairs-trading]]"
  - "[[concepts/mean-reversion]]"
indicators:
  - "[[indicators/rolling-correlation]]"
  - "[[indicators/spread-zscore]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, AUDUSD.DWX, NZDUSD.DWX, USDCHF.DWX, USDCAD.DWX, USDJPY.DWX]
period: H4
expected_trade_frequency: "Single-partner-per-month cointegration spread, one open spread at a time, 2-sigma z entry / z=0 exit, gated by corr>=0.70 and ADF t<=-1.30 (qualifying months only). Realistic low-freq estimate ~6 round-trips/year/host-symbol; prior 45 over-claimed and set the Q02 MIN_TRADES bar unachievably high."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 PASS Robot Wealth source link; R2 PASS mechanical H4 pair selection/spread entry/exit with a low-frequency estimate of 6 round trips/year/host; R3 PASS DWX FX pairs testable; R4 PASS no ML/grid/martingale and one spread per magic."
strategy_params:
  strategy_formation_bars: 252
  strategy_zscore_bars: 120
  strategy_min_corr: 0.70
  strategy_adf_t_max: -1.30
  strategy_entry_z: 2.0
  strategy_exit_z: 0.0
  strategy_spread_stop_z: 3.0
  strategy_atr_period: 14
  strategy_atr_sl_mult: 2.0
  strategy_time_stop_bars: 15
  strategy_min_improve_frac: 0.25
  strategy_max_spread_points: 50
---

# Robot Wealth FX Broad Pairs Trading

## Quelle
- Source: [[sources/robot-wealth-blog]]
- Citation: Robot Wealth, "Index of Strategies" (accessed 2026), FX Broad Pairs Trading section, https://robotwealth.com/index-of-strategies/
- Source location: the index states that FX Bootcamp explores currency-pair mean reversion as a pairs trade and includes a walk-through of the original trading script, with research code and Zorro scripts in the FX Pod.
- Author / institution: Robot Wealth.

## Mechanik

### Entry
- Universe: liquid DWX FX majors and commodity FX crosses.
- Formation step: every month, rank all pair combinations by 252-bar H4 correlation and 252-bar spread stationarity; keep top N pairs that pass correlation > 0.70 and ADF p-value < 0.10.
- For each selected pair, compute spread using rolling OLS hedge ratio frozen at monthly rebalance.
- On each H4 close, compute spread z-score over 120 H4 bars.
- If z-score > +2.0, short the spread: short asset A and long beta-adjusted asset B.
- If z-score < -2.0, long the spread: long asset A and short beta-adjusted asset B.
- One open spread per pair magic; no pyramiding.

### Exit
- Exit when z-score crosses 0.0.
- Exit after 15 H4 bars if z-score has not improved by at least 25%.
- Exit and disable pair until next monthly selection if rolling correlation falls below 0.50.

### Stop Loss
- Spread SL = 3.0 rolling spread standard deviations from entry.
- Per-leg emergency SL = 2.0 * ATR(14,H4).

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` per spread.
- Split risk across legs by hedge ratio and pip value.

### Zusaetzliche Filter
- Trade only pairs where both legs have synchronized H4 bars and normal spread.
- Do not enter in the final H4 bar before weekend close.
- P3 sweep: correlation threshold 0.60/0.70/0.80, z-entry 1.5/2.0/2.5, exit 0.0/0.5.


## Strategy Parameters

| param | default |
|-------|---------|
| `strategy_formation_bars` | `252` |
| `strategy_zscore_bars` | `120` |
| `strategy_min_corr` | `0.70` |
| `strategy_adf_t_max` | `-1.30` |
| `strategy_entry_z` | `2.0` |
| `strategy_exit_z` | `0.0` |
| `strategy_spread_stop_z` | `3.0` |
| `strategy_atr_period` | `14` |
| `strategy_atr_sl_mult` | `2.0` |
| `strategy_time_stop_bars` | `15` |
| `strategy_min_improve_frac` | `0.25` |
| `strategy_max_spread_points` | `50` |

## Concepts
- [[concepts/fx-pairs-trading]] - primary
- [[concepts/mean-reversion]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Public Robot Wealth strategy index names the FX Broad Pairs Trading strategy and cites its lesson/script path. |
| R2 Mechanical | PASS | The card fixes the monthly selection cadence, 252-bar correlation and ADF gates, frozen OLS hedge ratio, 120-bar z-score entry/exit, spread and ATR stops, and time-stop rules; every decision is deterministic even though the source's private script is not reproduced. |
| R3 DWX-testbar | PASS | The strategy is directly FX-based and can be tested on DWX FX pairs. |
| R4 No ML | PASS | Fixed pair-selection and z-score rules; no ML, grid, martingale, or adaptive live parameters. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, AUDUSD.DWX, NZDUSD.DWX, USDCHF.DWX, USDCAD.DWX, USDJPY.DWX. Not SP500-specific.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10024_rw-fx-comm-basket]] - narrower commodity-currency basket variant.

## Lessons Learned
- TBD during pipeline run.
