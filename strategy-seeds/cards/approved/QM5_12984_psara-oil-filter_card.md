---
ea_id: QM5_12984
slug: psara-oil-filter
type: strategy
source_id: PSARADELLIS-OIL-FILTER-2019
sources:
  - "Psaradellis, Laws, Pantelous, and Sermpinis (2019), The European Journal of Finance"
  - "https://doi.org/10.1080/1351847X.2018.1552172"
  - "https://ssrn.com/abstract=2832600"
concepts:
  - "trend-following"
  - "filter-rule"
  - "crude-oil"
indicators:
  - "percent-filter"
  - "ATR safety stop"
g0_status: APPROVED
expected_trades_per_year_per_symbol: 6
expected_pf: 1.12
expected_dd_pct: 22
r1_track_record: PASS
r1_reasoning: "Named academic authors, peer-reviewed European Journal of Finance publication, and SSRN/RePEc metadata for crude-oil daily technical-rule testing."
r2_mechanical: PASS
r2_reasoning: "Closed-bar percentage filter rule with fixed threshold, deterministic stop-and-reverse state, ATR safety stop, and no discretionary inputs."
r3_data_available: PASS
r3_reasoning: "Source studies WTI crude oil daily prices; QM port uses registered DWX crude-oil CFD XTIUSD.DWX on D1."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed OHLC/ATR rules only; no ML, adaptive optimization, grid, martingale, or multi-position averaging."
pipeline_phase: Q02_QUEUED
last_updated: 2026-07-03
g0_approval_reasoning: "Psaradellis et al. 2019 crude-oil technical-rule paper covers daily WTI filter rules; this card mechanizes the filter-rule family only, distinct from QM5_1226's Psaradellis channel-breakout implementation."
---

# Psaradellis WTI Percent Filter

## Source
- Primary paper: Ioannis Psaradellis, Jason Laws, Athanasios A. Pantelous, and Georgios Sermpinis, "Performance of technical trading rules: evidence from the crude oil market", The European Journal of Finance, 25(17), 1793-1815, 2019.
- DOI: https://doi.org/10.1080/1351847X.2018.1552172.
- Public metadata: https://ideas.repec.org/a/taf/eurjfi/v25y2019i17p1793-1815.html and https://ssrn.com/abstract=2832600.
- The source applies the Sullivan, Timmermann, and White technical-rule universe to daily WTI crude oil and USO, including the filter-rule family. QM5_1226 already covers this source's channel-breakout family; this card covers the crude-oil filter-rule family.

## Mechanic

### Entry
1. Trade `XTIUSD.DWX` on D1 only.
2. Maintain a running trough and peak of closed D1 closes since the last directional signal.
3. Open LONG when the latest closed D1 close rises at least `strategy_filter_pct` percent above the running trough.
4. Open SHORT when the latest closed D1 close falls at least `strategy_filter_pct` percent below the running peak.

### Exit
- Stop-and-reverse on the opposite percent-filter signal.
- Use an ATR safety stop at entry as a catastrophic loss cap.
- No fixed take-profit; the source family is directional filter-rule timing.

### Position Sizing
- Q02 baseline: `RISK_FIXED = 1000`.
- No live allocation is defined by this card.

### Filters
- `XTIUSD.DWX` only, `D1` only, magic slot 0 only.
- Spread cap is wide and defensive because the DWX backtest feed can model zero spread.
- V5 news, stress, Friday-close, kill-switch, and risk controls remain central framework controls.

## Parameters
| param | default | range | meaning |
|---|---:|---|---|
| `strategy_filter_pct` | 7.5 | 5.0-12.5 | Percent move from the tracked extreme required for a new signal |
| `strategy_atr_period` | 20 | 14-30 | ATR lookback for the safety stop |
| `strategy_sl_atr_mult` | 3.0 | 2.0-4.0 | ATR multiple for the safety stop |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## R1-R4
| criterion | status | reasoning |
|---|---|---|
| R1 Track Record | PASS | Peer-reviewed crude-oil technical-rule study with named authors and public DOI/SSRN metadata. |
| R2 Mechanical | PASS | Fixed closed-bar percent-filter state machine with ATR safety stop. |
| R3 Data Available | PASS | Source WTI daily market maps to `XTIUSD.DWX` D1. |
| R4 ML Forbidden | PASS | No ML, online learning, grid, martingale, or PnL-adaptive parameter mutation. |

## Duplicate Check
- `QM5_1226_psaradellis-oil-channel` implements the same paper's channel-breakout family, not filter rules.
- `QM5_11578_neely-weller-pct-filter-rule-d1` is an FX-only Neely/Weller filter card with FX magic rows; it is not a WTI crude-oil source port and is not registered on `XTIUSD.DWX`.
- This card is a single-symbol WTI crude-oil sleeve intended to add energy exposure rather than index, metal, or XNG exposure.

## Pipeline
- G0: APPROVED by card criteria on 2026-07-03.
- Q01: implemented as `framework/EAs/QM5_12984_psara-oil-filter`.
- Q02: queued after compile.
