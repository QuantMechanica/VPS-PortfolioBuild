---
ea_id: QM5_12617
slug: tsmom-12m-fx-usdjpy
type: strategy
source_id: e5a3f925-5a9e-513d-9e70-5c7c70fa0e59
sources:
  - "[[sources/aqr-moskowitz-ooi-pedersen-time-series-momentum-2012]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/trend-following]]"
  - "[[concepts/carry-currency-momentum]]"
indicators:
  - "[[indicators/lookback-return]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; Moskowitz, Ooi & Pedersen (2012) JFE is a named, peer-reviewed AQR paper with URL — lineage unambiguous."
r2_mechanical: PASS
r2_reasoning: "Entry is fully deterministic: sign(close[0] vs close[252]) monthly on D1; ATR stop and RISK_FIXED sizing leave no discretionary gaps."
r3_data_available: PASS
r3_reasoning: "USDJPY.DWX is a core Darwinex FX pair with live-tradable history 2017–2025; no porting required."
r4_ml_forbidden: PASS
r4_reasoning: "Pure lookback-return sign signal; no ML, no PnL-adaptive sizing, no martingale; one position per magic number."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 8
last_updated: 2026-06-29
g0_approval_reasoning: "R1 PASS single MOP/JFE source_id+URL; R2 PASS deterministic monthly 252D USDJPY return-sign long/short with ATR stop and >=2 trades/yr cadence; R3 PASS USDJPY.DWX price-only no macro feed; R4 PASS no ML/PnL-adaptive sizing/martingale."
expected_pf: 1.2
expected_dd_pct: 16.0
---

# TSMOM 12-Month Sign Momentum — USDJPY

## Quelle

- Source: [[sources/aqr-moskowitz-ooi-pedersen-time-series-momentum-2012]]
- Paper: Moskowitz, Ooi & Pedersen (2012). "Time series momentum." *Journal of Financial
  Economics*, 104(2), 228–250.
- URI: https://www.aqr.com/insights/research/journal-article/time-series-momentum
- Key reference: Table 1 — TSMOM returns for individual currency futures (JPY futures are in
  the paper's 6-currency universe; all show positive average returns at 12-month lookback).
  Section III.A — momentum sorted by asset class; FX currencies significant (t > 3).

## Mechanik

The paper's FX universe includes JPY futures alongside EUR, GBP, CHF, AUD, CAD. All six show
significant 12-month TSMOM. USDJPY is the DWX equivalent of JPY futures (inverted: shorting
JPY futures = long USDJPY; buying JPY futures = short USDJPY — handled by the sign logic).

**Why USDJPY is distinct from EURUSD (QM5_12611):** USDJPY is the primary risk-off and
carry-trade currency. Its trend dynamics differ from EUR/USD dollar directionality:
- During risk-off periods, JPY strengthens (USDJPY falls) regardless of EUR direction.
- BOJ policy divergence from Fed creates multi-year carry flows (2012–2015 Abenomics,
  2022–2024 rate divergence rally).
- USDJPY shows multi-month momentum that is less correlated with EURUSD momentum,
  providing diversification benefit when used alongside the EURUSD card.

This card implements the 12-month sign signal on USDJPY without volatility scaling, matching
the simplest mechanization in QM5_12611 applied to a structurally distinct FX pair.

### Entry

On the first bar of each calendar month (monthly rebalance):

```
lookback_bars = 252    // D1 bars ≈ 12 months
signal = close[0] > close[lookback_bars] ? +1 : -1
```

- If signal = +1 (USDJPY 12m higher = USD uptrend / JPY downtrend): open long if not already long.
- If signal = -1 (USDJPY 12m lower = USD downtrend / JPY uptrend): open short if not already short.
- If signal unchanged: hold.

Enter at next D1 open after signal computed at monthly close.

### Exit

Monthly rebalance only. Hard SL applies intra-month.

### Stop Loss

ATR-based hard stop: SL = entry_price ± ATR(14, D1) × 3.0.
USDJPY can have sharp intraday moves on BOJ intervention (50–300 pip spikes); the 3.0× ATR
stop provides reasonable protection while accommodating normal volatility. Codex may widen
to 3.5× in P3 sweep to avoid BOJ-spike stop-outs that reverse quickly.

### Position Sizing

RISK_FIXED = $1000 for backtest baseline.
Standard QM ATR-derived lot sizing. No vol scaling (sign-only version).

### Zusätzliche Filter

- **Monthly trigger**: `Month(Time[0]) != Month(Time[1])` on USDJPY D1.
- **News filter**: standard QM news-blackout. USDJPY is particularly sensitive to:
  - BOJ rate decisions and forward guidance (can gap ±200 pips)
  - US NFP, CPI, FOMC — do not open within news window.
- **Spread filter**: skip entry if spread > 3× median spread.
- **BOJ intervention awareness**: No special filter (intervention is not forecastable), but the
  wider stop helps survive intraday spike-and-reverse. The 12-month signal is long-period enough
  to be unaffected by 1-day intervention reversals.

## Concepts

- [[concepts/time-series-momentum]] — primary; 12-month lookback on FX, same signal as QM5_12611
- [[concepts/carry-currency-momentum]] — secondary; USDJPY carry/risk-off dynamics differ from EURUSD
- [[concepts/trend-following]] — tertiary

## R1–R4 Bewertung

| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Named AQR authors, JFE 2012, URL; Table 1 JPY-equivalent currency in paper's 12m TSMOM universe |
| R2 Mechanical | PASS | Fully mechanical: sign(close[0] vs close[252]) → direction; monthly trigger; no discretion |
| R3 Data Available | PASS | USDJPY.DWX is a core DWX FX instrument, live-tradable at Darwinex; history 2017–2025 |
| R4 ML Forbidden | PASS | No ML; deterministic lookback; 1 position per magic; no martingale |

## Pipeline-Verlauf

- G0: 2026-06-27, PENDING — drafted from MOP (2012) Table 1 / Section III.A FX universe, batch 2

## Verwandte Strategien

- [[strategies/QM5_12611_tsmom-12m-fx-sign-eurusd]] — same signal, same horizon, different FX pair
- [[strategies/QM5_12614_tsmom-6m-fx-basket-3pair]] — USDJPY is Slot 3 in the 6m FX basket

## Trade Frequency Note

Monthly rebalance with 12-month lookback: 12 signal checks/year. USDJPY has historically shown
multi-year trends (Abenomics 2012–2015, rate-divergence 2022–2023) interrupted by sharp risk-off
reversals. Expect 6–10 direction changes/year at the 12-month check frequency. Low-freq Q04 track.

## Commission Note

DXZ FX commission ~$45/trade (high, per QM cost model 2026-06-26). Same structural headwind as
QM5_12611 (EURUSD). USDJPY carries similar commission cost. Q04 net profitability gate is the
correct filter; card still valid at G0 given the paper's gross edge evidence.

## Lessons Learned

*(populate during pipeline runs)*
