---
ea_id: QM5_1221
slug: carver-kurtsrv
type: strategy
source_id: 2a380bee-1ec4-50d1-a348-b10fac642c7a
sources:
  - "[[sources/rob-carver-blog]]"
concepts:
  - "[[concepts/kurtosis]]"
  - "[[concepts/skew-premium]]"
  - "[[concepts/relative-value]]"
indicators:
  - "[[indicators/rolling-kurtosis]]"
  - "[[indicators/rolling-skew]]"
  - "[[indicators/atr-stop]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-19
expected_trades_per_year_per_symbol: 20
g0_approval_reasoning: "Carver qoppac 2020 kurtS_rv higher-moment RV rule (qoppac URL + pysystemtrade factors.py GitHub) R1-R4 all PASS: rolling kurtosis+skew conditioning deterministic, bounded forecast cap [-20,+20], fixed lookbacks 180/45, FX+index DWX universe portable, no ML"
---

# QM5_1221 Carver Relative-Value Kurtosis-Conditioned Skew

## Quelle
- Source: [[sources/rob-carver-blog]]
- Primary URL: qoppac blog post "Skew and kurtosis as trading rules"
- Code URL: pst-group/pysystemtrade `systems/provided/rules/factors.py`
- Author: Rob Carver. The 2020 post defines `kurtS_rv` as kurtosis conditioned on skew, demeaned against the current asset-class average; its allocation summary gives `kurtS_rv` the largest higher-moment bucket weight, while Carver later says he is less comfortable with kurtosis complexity.

## Mechanik

Relative-value higher-moment rule. It measures each symbol's excess kurtosis relative to its asset class and only keeps the signal direction when relative skew has the same sign condition, aiming to trade tail-shape differences inside comparable DWX groups.

Suggested DWX universe for P2: FX majors group (EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX, USDCHF.DWX) and index group (GER40.DWX, NDX.DWX, WS30.DWX, UK100.DWX, FRA40.DWX).

### Entry
- On each closed D1 bar for every symbol in its asset group:
  - `r_i = log(Close_i / Close_i[-1])`.
  - `kurt_i = ExcessKurtosis(r_i, Lookback)`.
  - `skew_i = Skewness(r_i, Lookback)`.
  - `rv_kurt_i = kurt_i - average(kurt_j for valid symbols in same group)`.
  - `rv_skew_i = skew_i - average(skew_j for valid symbols in same group)`.
  - `conditioned_factor_i = (rv_kurt_i / RobustVol(rv_kurt_i)) * sign(rv_skew_i)`.
  - `forecast_i = EMA(conditioned_factor_i, Smooth) * ForecastScalar`.
  - cap forecast to `[-20,+20]`.
- LONG if `forecast_i > +EntryForecast`.
- SHORT if `forecast_i < -EntryForecast`.
- Default variant: `Lookback=180`, `Smooth=45`, `EntryForecast=2`.
- P3 sweep Carver variants: `Lookback/Smooth in {180/45, 365/90}`.

### Exit
- Close LONG when forecast falls below `0`.
- Close SHORT when forecast rises above `0`.
- Exit immediately if the asset group has fewer than `4` valid symbols.

### Stop Loss
- Emergency stop: `3.0 * ATR(20, D1)`.
- Optional P3 variants: `2.5`, `3.0`, `3.5` ATR.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.5%`.
- Size from emergency stop distance. One position per symbol/magic.
- Cross-sectional slot cap: at most `2` long and `2` short positions per asset group.

### Zusätzliche Filter
- Require at least `Lookback + 252` bars before trading.
- Do not trade a group unless at least `4` symbols have valid return windows.
- Spread cap: skip new entries when spread exceeds `2 * MedianSpread(20D)`.
- Rebalance once per D1 bar; no intraday re-entry loops.

## Concepts
- [[concepts/kurtosis]] - primary
- [[concepts/skew-premium]] - primary
- [[concepts/relative-value]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Named author, exact qoppac URL, and linked open-source generic factor-rule implementation. |
| R2 Mechanical | PASS | Rolling kurtosis, rolling skew, relative-value demeaning, conditioning sign, smoothing, and exits are deterministic. |
| R3 DWX-testbar | PASS | Uses daily close returns and same-asset DWX group averages; portable to FX and index baskets. |
| R4 No ML | PASS | Fixed lookbacks and group slots, one position per magic, no ML, no adaptive equity/PnL parameters. |

## R3 - T6 Live-Promotion-Caveat
N/A - proposed universe uses broker-routable DWX symbols only. SP500.DWX is not required.

## Pipeline-Verlauf
- G0: 2026-05-18 - drafted from Rob Carver blog third batch, PENDING.

## Verwandte Strategien
- [[strategies/QM5_1212_carver-kurtsabs]] - absolute kurtosis-conditioned skew version.
- [[strategies/QM5_1211_carver-skewrv]] - relative-value pure skew cousin.

## Lessons Learned (wahrend Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Anderung `pipeline_phase` aktualisieren + `last_updated`.*
