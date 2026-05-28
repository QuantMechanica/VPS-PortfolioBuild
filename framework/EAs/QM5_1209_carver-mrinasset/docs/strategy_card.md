---
ea_id: QM5_1209
slug: carver-mrinasset
type: strategy
source_id: 2a380bee-1ec4-50d1-a348-b10fac642c7a
sources:
  - "[[sources/rob-carver-blog]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/cross-sectional]]"
  - "[[concepts/relative-value]]"
indicators:
  - "[[indicators/normalised-return]]"
  - "[[indicators/ewma]]"
  - "[[indicators/atr-stop]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
expected_trades_per_year_per_symbol: 60
g0_approval_reasoning: "carver-mrinasset Rob Carver qoppac 2017 within-asset disequilibrium + 2021 live-system positive handcrafted weight on mrinasset160; R1 PASS named-author + 2017+2021 qoppac.blogspot.com URLs; R2 PASS formulaic norm_ret/EMA/cross-sectional-median/D_x/forecast cap +/-20 entry-forecast=2 max-slots=2 / f"
---

# QM5_1209 Carver Within-Asset Mean Reversion

## Quelle
- Source: [[sources/rob-carver-blog]]
- Primary URL: https://qoppac.blogspot.com/2017/06/some-more-trading-rules.html
- Supplemental URL: https://qoppac.blogspot.com/2021/12/my-trading-system.html
- Author: Rob Carver. The 2017 post defines the within-asset disequilibrium formula; the 2021 live-system post lists `mrinasset160` and gives it a positive handcrafted allocation despite weak standalone performance.

## Mechanik

Cross-sectional mean-reversion rule inside one asset class. If an instrument outperforms the asset-class normalised price over a medium horizon, the strategy shorts the outperformer; if it underperforms, the strategy goes long, expecting the idiosyncratic move to revert while the shared asset-class trend is stripped out.

Suggested DWX groups for P2: equity-index group `{GER40.DWX, NDX.DWX, WS30.DWX}` and FX-major group `{EURUSD.DWX, GBPUSD.DWX, AUDUSD.DWX, USDJPY.DWX, USDCHF.DWX, USDCAD.DWX}`.

### Entry
- On each closed D1 bar for each asset-class group:
  - For each instrument `x`, compute `norm_ret_x = clamp((Close_t - Close_(t-1)) / StdDev(ret_x, 25), -6, +6)`.
  - `N_x = cumulative_sum(norm_ret_x)`.
  - `N_A = median(N_x across instruments in group)`.
  - `D_x = (N_x[t] - N_x[t-Horizon]) - (N_A[t] - N_A[t-Horizon])`.
  - `forecast_x = -EMA(D_x, Span)`.
  - normalise forecast by rolling cross-sectional dispersion and cap to `[-20,+20]`.
- LONG instrument `x` if `forecast_x > +EntryForecast`.
- SHORT instrument `x` if `forecast_x < -EntryForecast`.
- Default variant: `Horizon=160` D1 bars, `Span=40`, `EntryForecast=2`.
- Only trade top `MaxSlotsPerGroup=2` absolute forecasts per group to keep exposure bounded.

### Exit
- Close LONG when forecast falls below `0`.
- Close SHORT when forecast rises above `0`.
- Re-rank once per D1 bar; if a position is no longer in the top `MaxSlotsPerGroup`, close at next bar open.

### Stop Loss
- Emergency stop: `2.5 * ATR(20, D1)`.
- Structural-break guard: close and block new entries for that symbol for `20` bars if adverse move exceeds `3.5 * ATR(20)`.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.5%`.
- Equal risk per open slot. One position per symbol/magic.

### Zusätzliche Filter
- Require at least `Horizon + Span + 25` bars for every instrument in the group.
- Skip group if fewer than three instruments have valid data.
- Spread cap: skip new entries when spread exceeds `2 * MedianSpread(20D)`.
- News filter hook for high-impact events.

## Concepts
- [[concepts/mean-reversion]] — primary
- [[concepts/cross-sectional]] — primary
- [[concepts/relative-value]] — secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Named author and exact qoppac URLs; source gives the disequilibrium formula and 2021 live weight. |
| R2 Mechanical | PASS | Directional entry and exit are formulaic; defaults fill position-slot and stop details. |
| R3 DWX-testbar | PASS | Uses only OHLC-derived normalised returns within DWX index or FX groups. |
| R4 No ML | PASS | Fixed horizon/span, bounded slots, one position per symbol/magic, no adaptive equity/PnL logic. |

## R3 — T6 Live-Promotion-Caveat
N/A — proposed universe uses broker-routable DWX symbols only. SP500.DWX is not required.

## Pipeline-Verlauf
- G0: 2026-05-18 — drafted from Rob Carver blog second batch, PENDING.

## Verwandte Strategien
- [[strategies/QM5_1069_carver-assettrend]] — uses the asset-class aggregate for trend rather than idiosyncratic reversion.
- [[strategies/QM5_1208_carver-normmom]] — uses the same normalised-price construction for trend following.

## Lessons Learned (während Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`.*
