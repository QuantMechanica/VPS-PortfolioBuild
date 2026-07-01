---
ea_id: QM5_12623
slug: comm-mom-rev-interaction-xauusd
type: strategy
source_id: 05abad87-420d-5a51-8a9b-3c35ad795385
sources:
  - "[[sources/yang-goncu-pantelous-momentum-reversal-commodity-futures-2018]]"
concepts:
  - "[[concepts/momentum-reversal-interaction]]"
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/short-term-reversal]]"
  - "[[concepts/commodity-momentum]]"
indicators:
  - "[[indicators/n-day-return]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id (05abad87) referencing Yang-Goncu-Pantelous Quantitative Finance 2018 Section 3.3 with DOI URL; no secondary sources."
r2_mechanical: PASS
r2_reasoning: "Two-condition monthly gate (sign of 63-bar return + 20-bar confirmation with ±1% dead-band); ATR stop; monthly exit; fully deterministic, no discretion."
r3_data_available: PASS
r3_reasoning: "XAUUSD.DWX is a live-tradable Darwinex instrument with history covering both the 63-bar and 20-bar lookback windows."
r4_ml_forbidden: PASS
r4_reasoning: "No ML; both return lookbacks are price-history only; single position per magic number; no martingale."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 9
last_updated: 2026-06-29
g0_approval_reasoning: "R1 PASS single source_id with DOI; R2 PASS deterministic monthly 3M momentum plus 4W confirmation gate with ATR/monthly exits and plausible 3-9 trades/yr; R3 PASS XAUUSD.DWX; R4 PASS deterministic no ML one-position."
expected_pf: 1.2
expected_dd_pct: 15.0
---

# Momentum-Reversal Interaction Filter — XAUUSD

## Quelle

- Source: [[sources/yang-goncu-pantelous-momentum-reversal-commodity-futures-2018]]
- Paper: Yang, L., Goncu, A., & Pantelous, A. A. (2018). "Momentum and Reversal Strategies
  in Chinese Commodity Futures Markets." *Quantitative Finance*, 18(8), 1373–1389.
- URI: https://doi.org/10.1080/14697688.2018.1436534
- Key reference: Section 3.3 and Table 5 — "Interaction of Momentum and Reversal." The paper
  decomposes momentum winners/losers by their short-term (4-week) pre-formation return: momentum
  trades where the short-term return CONFIRMS the medium-term momentum direction significantly
  outperform momentum trades where the short-term return CONTRADICTS the medium-term signal.
  The confirmation filter adds ~1–2% annualised return and reduces maximum drawdown. The key
  finding: when a commodity shows strong 3-month momentum BUT has reversed in the last 4 weeks
  (the reversal signal is active), the subsequent momentum performance is substantially weaker.

## Mechanik

This card implements the interaction filter from Section 3.3: take the standard 3-month TSMOM
signal on XAUUSD ONLY when the 4-week return is consistent with (not fighting against) the
momentum direction. When the 4-week return contradicts the 3-month momentum signal, skip the
trade — the short-term reversal is masking a momentum slowdown.

This is a FILTER on the momentum signal, not a standalone strategy. It reduces trade frequency
(~12 → ~9 trades/year) but improves per-trade edge by excluding the weakest momentum setups.

The mechanism: if gold has been trending up for 3 months (momentum long signal) but has FALLEN
in the last 4 weeks (short-term reversal active), this suggests the momentum is losing conviction.
The reversal episode is a warning sign. Skip the momentum trade; re-evaluate next month.

### Entry

Monthly evaluation (first D1 bar of each calendar month):

```
// 3-month momentum signal (from Yang et al. Table 3 / MOP framework)
lookback_mom = 63           // D1 bars ≈ 3 months
ret_3m = (Close[0] - Close[lookback_mom]) / Close[lookback_mom]

// 4-week reversal check
lookback_rev = 20           // D1 bars ≈ 4 weeks
ret_4w = (Close[0] - Close[lookback_rev]) / Close[lookback_rev]

// Momentum signal
mom_long  = (ret_3m > 0)
mom_short = (ret_3m < 0)

// Reversal filter: 4-week return must CONFIRM momentum direction (not contradict)
rev_confirms_long  = (ret_4w >= -0.01)   // 4-week return is flat or positive for a long signal
rev_confirms_short = (ret_4w <= +0.01)   // 4-week return is flat or negative for a short signal

if mom_long and rev_confirms_long and no open long:
    close any open short
    open long

if mom_short and rev_confirms_short and no open short:
    close any open long
    open short

// If momentum signal is present but reversal contradicts it → SKIP this month's trade
// (hold existing position if any; do not enter new)
```

The ±1% dead-band on the reversal check avoids hypersensitivity to tiny 4-week moves.
Codex calibrates the dead-band in P3 sweep.

### Exit

Monthly rebalance: re-evaluate signal at next month's first bar and update position.
If signal flips or disappears, close position at next monthly open.

Hard SL: entry_price ± ATR(14, D1) × 2.5 (same as the pure 3m gold momentum card QM5_12613).
The filter doesn't change the per-trade risk management, only the entry selection.

### Stop Loss

ATR-based: SL = entry_price ± ATR(14, D1) × 2.5.
Inherits from the 3-month momentum card structure. The interaction-filtered momentum trades
are expected to have better directional stability than pure momentum trades (paper finding),
which justifies retaining the standard stop without widening.

### Position Sizing

RISK_FIXED = $1000 for backtest baseline.
Standard QM ATR-derived lot sizing: lot = RISK_FIXED / (ATR(14) × point_value × lots_per_point).

### Zusätzliche Filter

- **Monthly trigger**: `Month(Time[0]) != Month(Time[1])` on D1 bars.
- **News filter**: standard QM news-blackout. XAUUSD is sensitive to NFP and FOMC; skip entry
  if high-impact event is within ±24h of monthly evaluation bar.
- **Spread filter**: skip if spread > 3× median spread.

## Concepts

- [[concepts/momentum-reversal-interaction]] — primary; reversal filter applied to momentum (Section 3.3)
- [[concepts/time-series-momentum]] — secondary; 3-month own-past-return momentum signal
- [[concepts/short-term-reversal]] — tertiary; 4-week return as confirmation gate
- [[concepts/commodity-momentum]] — context

## R1–R4 Bewertung

| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Named authors, peer-reviewed Quantitative Finance, DOI URL; Section 3.3 interaction explicitly cited |
| R2 Mechanical | PASS | Fully mechanical: two-condition gate (3m momentum + 4w confirmation); monthly trigger; no discretion |
| R3 Data Available | PASS | XAUUSD.DWX is live-tradable at Darwinex; history 2017–2025 available |
| R4 ML Forbidden | PASS | No ML; deterministic conditions; 1 position per magic; no martingale |

## Pipeline-Verlauf

- G0: 2026-06-27, PENDING — drafted from Yang-Goncu-Pantelous (2018) Section 3.3 interaction filter

## Verwandte Strategien

- [[strategies/QM5_12613_tsmom-3m-commodity-xauusd]] — the underlying 3m momentum strategy (unfiltered baseline)
- [[strategies/QM5_12619_comm-reversal-4wk-xauusd]] — the reversal strategy this card's filter is based on
- [[strategies/QM5_12622_comm-reversal-12m-contrarian-xauusd]] — long-term reversal on same instrument

## Trade Frequency Note

The interaction filter REDUCES trade frequency relative to pure 3-month TSMOM. Unfiltered 3m
TSMOM: ~12 trades/year. After filtering months where 4-week return contradicts momentum (expected
to occur ~25% of the time), the filtered strategy yields ~9 trades/year. This is above the
standard minimum floor and should support Q04 fold analysis over the 8-year backtest window.

The trade-off is intentional: fewer but higher-quality trades per the paper's finding in Table 5.

## Commission Note

DXZ commission for XAUUSD: ~$0.4–$6.7/trade (low, per QM cost model 2026-06-26). 9 trades/year
× ~$4 = ~$36/year — negligible. The monthly rebalancing cadence is more cost-efficient than
the 4-week reversal cards.

## Comparison With Baseline (QM5_12613)

| Metric | Pure 3m TSMOM (QM5_12613) | Filtered (QM5_12623) |
|--------|--------------------------|----------------------|
| Trades/year | ~12 | ~9 |
| Expected edge source | TSMOM signal | TSMOM × reversal confirmation |
| Per-trade quality | Lower (includes weak setups) | Higher (excludes reversal-headwind months) |
| Paper evidence | MOP (2012) Table 2 | Yang et al. (2018) Table 5 Section 3.3 |

The pipeline will determine whether the reduction in trade count costs more than the improvement
in per-trade quality. Both cards are valid and complementary — results will inform which is superior
on DWX commodities.

## Lessons Learned

*(populate during pipeline runs)*
