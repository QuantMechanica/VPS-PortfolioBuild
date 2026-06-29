---
ea_id: QM5_12611
slug: tsmom-12m-fx-sign-eurusd
type: strategy
source_id: e5a3f925-5a9e-513d-9e70-5c7c70fa0e59
sources:
  - "[[sources/aqr-moskowitz-ooi-pedersen-time-series-momentum-2012]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/trend-following]]"
indicators:
  - "[[indicators/lookback-return]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; MOP (2012) JFE peer-reviewed paper with direct URL satisfies lineage requirement."
r2_mechanical: PASS
r2_reasoning: "Fully mechanical: sign(close[0] vs close[252]) → direction; monthly rebalance trigger; no discretion."
r3_data_available: PASS
r3_reasoning: "EURUSD.DWX is a core live-tradable DWX FX instrument with full history available."
r4_ml_forbidden: PASS
r4_reasoning: "No ML; deterministic lookback comparison; 1 position per magic; no martingale or PnL-adaptive sizing."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 8
last_updated: 2026-06-29
g0_approval_reasoning: "R1 PASS single MOP/JFE source_id+URL; R2 PASS deterministic monthly 252D return-sign long/short with ATR stop, monthly/stop re-entry supports >=2 trades/yr; R3 PASS EURUSD.DWX; R4 PASS no ML/PnL-adaptive sizing/martingale."
expected_pf: 1.2
expected_dd_pct: 16.0
---

# TSMOM 12-Month Sign Momentum — EURUSD

## Quelle

- Source: [[sources/aqr-moskowitz-ooi-pedersen-time-series-momentum-2012]]
- Paper: Moskowitz, Ooi & Pedersen (2012). "Time series momentum." *Journal of Financial
  Economics*, 104(2), 228–250.
- URI: https://www.aqr.com/insights/research/journal-article/time-series-momentum
- SSRN: https://ssrn.com/abstract=2089463
- Key reference: Section II (Methodology) — the core TSMOM signal construction.

## Mechanik

The paper documents that the sign of an instrument's own past 12-month return predicts its
next-month return across all major asset classes. This card implements the binary sign version
on EURUSD D1 without volatility scaling (plain position, no vol normalization), making it the
simplest direct mechanization of the core MOP finding.

### Entry

On the first bar of each calendar month (monthly rebalance), compute the 12-month lookback
return:

```
lookback_bars = 252   // D1 bars ≈ 12 months
signal = close[0] > close[lookback_bars] ? +1 : -1
```

- If signal = +1 and no open long: close any open short, open long.
- If signal = -1 and no open short: close any open long, open short.
- If signal unchanged from current position direction: hold (no trade).

Open on next D1 open after signal computed at monthly bar close.

### Exit

Monthly rebalance only (hold until next monthly signal check). No intra-month exit unless:
- Stop Loss hit (see below).
- News-blackout forced close (framework standard).

### Stop Loss

ATR-based hard stop: SL = entry_price ± ATR(14) × 3.0 (D1 ATR).
The paper uses a vol-scaled approach; here the fixed-multiplier stop approximates that
without continuous resizing. Codex may adjust the multiplier in the P3 sweep.

### Position Sizing

`RISK_FIXED = $1000` for backtest baseline (per HR4 / P2 baseline convention).
Lot size: standard QM framework sizing from set file.
No dynamic vol scaling in this card (see QM5_12612 for the vol-scaled variant).

### Zusätzliche Filter

- **News filter**: standard QM news-blackout (do not open within news window; do not close
  during news window to avoid slippage — hold and let stop handle it).
- **Spread filter**: skip entry if spread > 3× median spread at entry bar.
- **Monthly trigger**: EA checks signal only on bar open when `Month(Time[0]) != Month(Time[1])`.

## Concepts

- [[concepts/time-series-momentum]] — primary: the paper's core contribution
- [[concepts/trend-following]] — secondary: TSMOM is trend-following on one's own history

## R1–R4 Bewertung

| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Named AQR authors (Moskowitz/Ooi/Pedersen), peer-reviewed JFE 2012, direct URL provided |
| R2 Mechanical | PASS | Fully mechanical: sign(close[0] vs close[252]) → direction; monthly rebalance; no discretion |
| R3 Data Available | PASS | EURUSD.DWX is a core DWX FX instrument, live-tradable at Darwinex |
| R4 ML Forbidden | PASS | No ML; deterministic lookback; 1 position per magic; no martingale |

## Pipeline-Verlauf

- G0: 2026-06-27, PENDING — drafted from MOP (2012), batch 1

## Verwandte Strategien

- [[strategies/QM5_12612_tsmom-12m-vol-scaled-ndx]] — same 12m signal, vol-scaled sizing on NDX
- [[strategies/QM5_12614_tsmom-6m-fx-basket-3pair]] — 6m variant on FX basket including EURUSD
- [[strategies/QM5_12615_tsmom-12m-cross-asset-basket]] — cross-asset basket including EURUSD slot

## Trade Frequency Note

Monthly rebalance means 12 signal checks/year. Direction flips when the 12-month trend reverses.
EURUSD is moderately trending; expect 6–10 actual trades/year. Low-freq Q04 track applies.

## Lessons Learned

*(populate during pipeline runs)*
