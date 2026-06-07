---
ea_id: QM5_11051
slug: pst-volatten-break
type: strategy
source_id: 352af9de-f372-5cf2-9a86-681a26224597
source_citation: "Rob Carver / pst-group, pysystemtrade rob_system breakout rules and volatility attenuation, https://github.com/robcarver17/pysystemtrade/blob/master/systems/provided/rob_system/config.yaml"
sources:
  - "[[sources/pysystemtrade]]"
concepts:
  - "[[concepts/breakout]]"
  - "[[concepts/volatility-regime]]"
  - "[[concepts/forecast-combination]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/rolling-volatility]]"
g0_status: APPROVED
expected_trades_per_year_per_symbol: 45
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
strategy_type_flags: [breakout, trend-following, volatility-filter, forecast-combination, signal-reversal-exit, symmetric-long-short]
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, NDX.DWX, WS30.DWX, XAUUSD.DWX, XTIUSD.DWX]
g0_approval_reasoning: "R1 public pysystemtrade source URLs; R2 fixed daily breakout/vol-attenuation entry and reversal exit with plausible multi-trade cadence; R3 OHLC rules portable to DWX; R4 fixed no-ML one-position rules."
---

# QM5_11051 pysystemtrade Vol-Attenuated Breakout Stack

## Quelle
- Source: [[sources/pysystemtrade]]
- Primary URL: https://github.com/robcarver17/pysystemtrade/blob/master/systems/provided/rob_system/config.yaml
- Accessed 2026-05-22, URL: https://github.com/robcarver17/pysystemtrade/blob/master/systems/provided/rob_system/config.yaml
- Formula URL: https://github.com/robcarver17/pysystemtrade/blob/master/systems/provided/rules/breakout.py
- Attenuation URL: https://github.com/robcarver17/pysystemtrade/blob/master/systems/provided/attenuate_vol/vol_attenuation_forecast_scale_cap.py
- Author / institution: Rob Carver / pst-group.
- Location: `rob_system/config.yaml` breakout rules and `use_attenuation`; attenuation class `volAttenForecastScaleCap`.

## Mechanik

Multi-horizon rolling-range breakout forecast with Carver's volatility attenuation overlay. This is narrower than the full `rob_system` ensemble: it only trades the breakout family listed in `use_attenuation`.

### Entry
- Evaluate once per completed D1 bar.
- For each lookback `N in {10,20,40,80,160,320}`:
  - `roll_max = Highest(close, N)`, with at least half the lookback populated.
  - `roll_min = Lowest(close, N)`.
  - `roll_mean = (roll_max + roll_min) / 2`.
  - `raw_breakout_N = 40 * ((close - roll_mean) / (roll_max - roll_min))`.
  - Smooth with `EMA(raw_breakout_N, max(N/4, 1))`.
  - Multiply by the source forecast scalar for that horizon: `0.6031`, `0.6743`, `0.7037`, `0.7263`, `0.7388`, `0.7366`.
- Compute volatility attenuation:
  - `daily_pct_vol = rolling daily percentage volatility`.
  - `normalised_vol = daily_pct_vol / SMA(daily_pct_vol, 2500)`.
  - `vol_quantile = percentile rank of normalised_vol`.
  - `attenuation = EMA(2 - 1.5 * vol_quantile, 10)`.
- Apply attenuation to each breakout component and cap to `[-20,+20]`.
- Combined forecast = equal-weight average of valid breakout components.
- Enter long when `combined_forecast >= +5`.
- Enter short when `combined_forecast <= -5`.

### Exit
- Close long when `combined_forecast <= +1`.
- Close short when `combined_forecast >= -1`.
- Flip only after opposite entry threshold on a later D1 close.

### Stop Loss
- Emergency stop: `3.0 * ATR(20, D1)`.
- Primary source close remains forecast reversal.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.25`.
- One open position per symbol/magic.

### Zusaetzliche Filter
- Minimum warmup: 320 D1 bars for breakout; 2500 D1 bars preferred for full volatility percentile, with source-like fallback attenuation `1.0` until enough history exists.
- Skip new entries when spread exceeds `2 * MedianSpread(60D)`.
- Do not trade if `roll_max == roll_min`.

## Concepts
- [[concepts/breakout]] - primary
- [[concepts/volatility-regime]] - primary
- [[concepts/forecast-combination]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Source-Link | PASS | Public GitHub URLs for config, breakout formula, and attenuation formula; named author/project owner. |
| R2 Mechanical | PASS | Rolling range, smoothing, volatility quantile attenuation, cap, thresholds, and exits are deterministic. |
| R3 DWX-testbar | PASS | Uses only D1 OHLC/spread-derived data; portable to DWX FX, index CFDs, XAUUSD, and oil CFD. |
| R4 No ML | PASS | Fixed horizons/scalars/thresholds; percentile attenuation is a deterministic state filter, not online learning. |

## R3
SP500.DWX is optional for backtest-only equity-index coverage. If it is the only survivor, live T6 promotion requires parallel validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- README says pysystemtrade implements systems "according to the framework outlined in his book Systematic Trading".
- The breakout function documents a rolling high/low breakout forecast and says the output has "a nice natural scaling".

## Parameters To Test
- Entry forecast: `3`, `5`, `8`.
- Component set: `{20,40,80,160}` vs all six source lookbacks.
- Attenuation on vs off.
- Stop: `2.5`, `3.0`, `3.5 * ATR(20)`.

## Initial Risk Profile
Trend breakout with reduced exposure in high-volatility regimes. Main risks are whipsaws after false breakouts and long warmup requirements for the attenuation percentile.

## Pipeline-Verlauf
- G0: 2026-05-22 - drafted from pysystemtrade source, PENDING.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Aenderung `pipeline_phase` aktualisieren + `last_updated`.*
