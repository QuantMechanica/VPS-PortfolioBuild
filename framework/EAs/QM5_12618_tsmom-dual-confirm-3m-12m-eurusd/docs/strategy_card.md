---
ea_id: QM5_12618
slug: tsmom-dual-confirm-3m-12m-eurusd
type: strategy
source_id: e5a3f925-5a9e-513d-9e70-5c7c70fa0e59
sources:
  - "[[sources/aqr-moskowitz-ooi-pedersen-time-series-momentum-2012]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/multi-horizon-confirmation]]"
  - "[[concepts/trend-following]]"
indicators:
  - "[[indicators/lookback-return]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; MOP (2012) JFE paper with URL; dual-confirm is a direct mechanical extension of the paper's Table 2 multi-horizon evidence."
r2_mechanical: PASS
r2_reasoning: "Fully mechanical: signal_3m AND signal_12m both agree → direction; else flat; monthly trigger; no discretion."
r3_data_available: PASS
r3_reasoning: "EURUSD.DWX is a core live-tradable DWX FX instrument with full history available."
r4_ml_forbidden: PASS
r4_reasoning: "No ML; two deterministic lookback comparisons; 1 position per magic; no martingale or PnL-adaptive sizing."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 6
last_updated: 2026-06-29
g0_approval_reasoning: "R1 one AQR/JFE source_id+URL; R2 monthly 3m+12m deterministic entries/exits with conservative low-freq cadence >=2/yr; R3 EURUSD.DWX testable; R4 deterministic no-ML one-position."
expected_pf: 1.2
expected_dd_pct: 18.0
---

# TSMOM Dual-Confirm (3m AND 12m) — EURUSD

## Quelle

- Source: [[sources/aqr-moskowitz-ooi-pedersen-time-series-momentum-2012]]
- Paper: Moskowitz, Ooi & Pedersen (2012). "Time series momentum." *Journal of Financial
  Economics*, 104(2), 228–250.
- URI: https://www.aqr.com/insights/research/journal-article/time-series-momentum
- Key reference: Table 2 — all lookback horizons (1, 3, 6, 9, 12m) show significant positive
  TSMOM, AND the signals are positively correlated across horizons (both short and long horizons
  agree during strong trends). The dual-confirm design is motivated by the paper's observation
  that the signal is persistent across horizons — when they disagree, the market is in transition
  and risk/reward is poorer.

## Mechanik

The paper finds that TSMOM is significant at every tested lookback horizon. The 3m and 12m
signals are both positive in trending regimes and tend to disagree during trend transitions
and choppy consolidation periods. This card exploits that observation: it ONLY enters when the
3-month and 12-month lookback signals BOTH point in the same direction.

This is a selective sub-set of the single-horizon cards (QM5_12611 takes every 12m signal;
this card takes only the 12m signals confirmed by 3m agreement). The trade-off is fewer trades
at higher directional conviction.

**Distinct from QM5_12611 (12m EURUSD):** QM5_12611 is always in the market; QM5_12618 can be
flat when 3m and 12m disagree. This creates meaningfully different equity curve shape and drawdown
profile during choppy markets.

### Entry

On the first bar of each calendar month (monthly rebalance):

```
lookback_3m  = 63     // D1 bars ≈ 3 months
lookback_12m = 252    // D1 bars ≈ 12 months

signal_3m  = close[0] > close[lookback_3m]  ? +1 : -1
signal_12m = close[0] > close[lookback_12m] ? +1 : -1
```

Signal logic:
- If signal_3m = +1 AND signal_12m = +1 → LONG entry (or hold if already long)
- If signal_3m = -1 AND signal_12m = -1 → SHORT entry (or hold if already short)
- If signal_3m ≠ signal_12m (disagreement) → FLAT: close any open position, do not open new one

When entering: open on next D1 open after monthly close.
When moving from position to flat: close at next D1 open.
When moving from flat to position: open at next D1 open.

### Exit

Monthly rebalance only (check agreement on first bar of each month). No intra-month flip.
Hard SL and news-blackout close apply intra-month as standard.

### Stop Loss

ATR-based hard stop: SL = entry_price ± ATR(14, D1) × 3.0.
Same convention as QM5_12611 (12m EURUSD) for direct comparison in P2 reporting.

### Position Sizing

RISK_FIXED = $1000 for backtest baseline.
Standard QM ATR-derived lot sizing. No vol scaling (sign-based entry only).

### Zusätzliche Filter

- **Monthly trigger**: `Month(Time[0]) != Month(Time[1])` on EURUSD D1.
- **News filter**: standard QM news-blackout. Do not open within news window; do not close during
  news window.
- **Spread filter**: skip entry if spread > 3× median spread.
- **Flat state tracking**: EA must track flat state explicitly (not just long/short) so it can
  distinguish "holding flat because of disagreement" from "holding position because of agreement".
  Codex uses a persistent variable (e.g. `int g_state: -1=short, 0=flat, +1=long`).

## Concepts

- [[concepts/time-series-momentum]] — primary; 3m and 12m lookbacks from Table 2
- [[concepts/multi-horizon-confirmation]] — secondary; the AND-logic of two lookback windows
- [[concepts/trend-following]] — tertiary

## R1–R4 Bewertung

| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Named AQR authors, JFE 2012, URL; Table 2 cross-horizon correlation observation cited; dual-confirm is a direct mechanical extension of the paper's multi-horizon evidence |
| R2 Mechanical | PASS | Fully mechanical: (signal_3m AND signal_12m agree) → direction; else flat; monthly trigger; no discretion |
| R3 Data Available | PASS | EURUSD.DWX is a core DWX FX instrument, live-tradable at Darwinex |
| R4 ML Forbidden | PASS | No ML; two deterministic lookbacks; 1 position per magic; no martingale |

## Pipeline-Verlauf

- G0: 2026-06-27, PENDING — drafted from MOP (2012) Table 2 cross-horizon evidence, batch 2

## Verwandte Strategien

- [[strategies/QM5_12611_tsmom-12m-fx-sign-eurusd]] — same instrument, 12m-only signal (always in market vs this card's flatting)
- [[strategies/QM5_12613_tsmom-3m-commodity-xauusd]] — 3m signal applied to different instrument

## Trade Frequency Note

Monthly rebalance. Dual-confirm requirement means the EA is flat when 3m and 12m disagree.
Historically EURUSD exhibits extended disagreement periods (e.g. trend turning points). Conservative
estimate: 50–60% of months will have agreement → ~6–8 trades/year (each trade = 1 open + 1 close
or 1 direction-reverse). Low-freq Q04 track applies; Q04 low-freq pooled test (DL-076) designed
for this pattern.

## Commission Note

DXZ FX commission ~$45/trade (high). Fewer trades than QM5_12611 (by design — flat during
disagreement), so annual commission cost is lower per round-trip than the always-in card. But
the reduced trade count also means fewer data points for Q04 fold analysis; this is the correct
tension for Q04 to resolve. Conservative expected_trades_per_year_per_symbol = 6.

## Lessons Learned

*(populate during pipeline runs)*
