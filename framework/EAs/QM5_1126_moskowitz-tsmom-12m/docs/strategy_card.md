---
ea_id: QM5_1126
slug: moskowitz-tsmom-12m
type: strategy
source_id: afab7a6f-c3c8-51ae-a609-f376744beb8e
sources:
  - "[[sources/ssrn-financial-economics-network]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/time-series-momentum]]"
indicators:
  - "[[indicators/rolling-return]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "Moskowitz/Ooi/Pedersen TSMOM JFE 2012 (SSRN 1299701) trailing-12mo-return sign -> long/short monthly rebalance cornerstone TSMOM paper ~5000 cites R1-R4 all PASS: R1 JFE peer-reviewed + AQR commercial deployment; R2 r12 sign + 0.5% threshold + monthly rebalance deterministic Codex-implementable; R3 "
---

# QM5_1126 Moskowitz-Ooi-Pedersen Time-Series Momentum (12m TSMOM)

## Quelle
- Primary: SSRN 1299701 — "Time Series Momentum" by Tobias J. Moskowitz,
  Yao Hua Ooi, Lasse H. Pedersen. Journal of Financial Economics 104(2),
  May 2012 (working paper Aug 2008).
  URL: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=1299701
- Reported result: across 58 liquid futures (equity indices, bonds, FX,
  commodities) from 1965-2009, the sign of the **prior 12-month excess
  return** is a positive predictor of the next month's return for the
  *same instrument*. A diversified TSMOM portfolio earns ~1.6 Sharpe before
  costs (volatility-targeted). Effect is distinct from cross-sectional
  momentum (which ranks instruments against each other) — each instrument
  is evaluated against its own history.
- Lineage: Asness/Moskowitz/Pedersen "Value and Momentum Everywhere" (2013),
  Hurst-Ooi-Pedersen "A Century of Evidence on Trend-Following" (SSRN 2993026),
  AQR TSMOM fund family.

## Mechanik

### Entry
- **Monthly** rebalance on the first trading day of the calendar month.
- For each tradeable instrument independently:
  - Compute the trailing 12-month return `r12 = close[t-21] / close[t-252] - 1`
    (252 D1 bars ≈ 12 months; offset by 1 month per paper convention).
  - If `r12 > 0` → go **long** that instrument at month-open.
  - If `r12 < 0` → go **short** that instrument at month-open.
  - If `|r12| < threshold (e.g., 0.5%)` → flat (avoids noise around zero).

### Exit
- Hold until the next monthly rebalance day.
- At that rebalance: re-evaluate `r12`; flip / hold / close as the signal dictates.

### Stop Loss
Paper has no explicit per-position SL (it uses volatility targeting at
portfolio level). V5 overlay: per-position ATR(D1,14) * 3 hard stop AND
portfolio MAX_DD 20 % trip (HR3/5 mandatory).

### Position Sizing
V5 standard: `RISK_FIXED = $1,000` per instrument per cycle for P2 baseline,
`RISK_PERCENT` for live (HR4). The paper's constant-volatility-targeting (40%
annualised per instrument) is *not* used at G0 — it's a P3 sweep variant
because it requires online vol estimation that drifts close to "adaptive".
Baseline uses fixed risk.

### Zusätzliche Filter
- Skip rebalance if the instrument has no D1 data for the full 252-bar lookback.
- Optional regime overlay (P3): require trailing 252d realized vol below some
  ceiling (avoid trading during vol-shock months). Baseline excludes.
- V5 mandatory: news filter, MAX_DD trip.

## Concepts
- [[concepts/time-series-momentum]] -- primary (distinct from cross-sectional)
- [[concepts/trend-following]] -- structural family

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Moskowitz/Ooi/Pedersen JFE 2012, ~5000 citations, cornerstone TSMOM reference. Replicated by Hurst-Ooi-Pedersen on 137-year sample. AQR runs commercial TSMOM funds on this signal. Strongest R1 of batch 2 |
| R2 Mechanical | PASS | One number per instrument per month (sign of 252-bar return). Zero discretion |
| R3 Data Available | PASS | DXZ universe: 4+ major-currency-pair FX + 4 liquid indices (GDAXI, NDX, UK100, WS30) + SP500.DWX (backtest-only). 8-9 instrument basket comfortably supports paper's diversification logic, though smaller than the 58-futures original. P2 starts with single-symbol (likely GDAXI or EURUSD); P3 expands to multi-symbol portfolio |
| R4 ML Forbidden | PASS | Pure threshold rule on rolling-return sign. No ML, no adaptive params. Volatility-targeting variant (P3) uses realized-vol formula, still closed-form, no learning |

## Pipeline-Verlauf
- G0: 2026-05-17 — drafted from SSRN FEN batch 2 (autonomous wake), PENDING

## Verwandte Strategien
- Distinct from: QM5_1112 (qp-country-momentum) which is **cross-sectional**
  ranking of country indices against each other. TSMOM evaluates each
  instrument against its own history.
- Sibling: QM5_1111 (qp-fx-momentum-12m) — same 12m horizon, but TSMOM uses
  absolute sign (long-or-short on own history), not cross-sectional rank.
- Adjacent: existing trend-following EAs (Williams Vol-BO QM5_1020, Donchian,
  MA crossover). Different timescale (monthly rebalance, 12m signal) vs
  intraday/daily trend-followers.

## Lessons Learned (während Pipeline-Lauf)
- *(populated as pipeline progresses)*

## Implementation Notes for Codex (P1)
- DWX symbol: **GDAXI.DWX primary** for P2 baseline (most D1 history). Expand to
  NDX.DWX, UK100.DWX, WS30.DWX, EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX,
  XAUUSD.DWX in P3 multi-symbol sweep.
- Timeframe: D1.
- "Monthly rebalance" — use the broker's first trading session of each new
  calendar month (not generic Mon-Fri rule; handles holiday-shifted opens).
- "12-month return" — `Close[bar_first_of_this_month-1] /
  Close[bar_first_of_this_month-1-252] - 1`. Use D1 close prices, not OHLC4.
- Magic per symbol per HR4 — multi-symbol EA needs distinct magic slots.
- P3 sweep variants: 6m / 12m / 24m lookback; threshold 0 / 0.5% / 1%;
  vol-targeting on/off; long-only vs long-short.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung pipeline_phase aktualisieren + last_updated. Bei FAIL: pipeline_phase: DEAD + Lessons-Learned-Eintrag.*
