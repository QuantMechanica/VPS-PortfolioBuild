---
ea_id: QM5_11205
slug: ft-adx-smas
type: strategy
source_id: 1580128f-e465-5454-bb97-a7572a6cfd6d
source_citation: "Gert Wohlgemuth, AdxSmas.py, freqtrade-strategies, GitHub, https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/berlinguyinca/AdxSmas.py"
sources:
  - "[[sources/freqtrade-strategies]]"
concepts:
  - "[[concepts/sma-crossover]]"
  - "[[concepts/trend-filter]]"
indicators:
  - "[[indicators/adx]]"
  - "[[indicators/sma]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
period: H1
expected_trade_frequency: "H1 SMA3/SMA6 crossover gated by ADX; conservative estimate 60-120 trades/year/symbol."
expected_trades_per_year_per_symbol: 80
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-23
g0_approval_reasoning: "R1 GitHub source link cited; R2 deterministic H1 SMA3/SMA6 crossover with ADX gate and mechanical exits/stops, plausible 60-120 trades/year/symbol; R3 OHLC indicators portable to DWX FX/metals; R4 fixed non-ML one-position rules."
---

# Freqtrade ADX SMA Crossover

## Quelle
- Source: [[sources/freqtrade-strategies]]
- Citation: 2026 GitHub URL, Gert Wohlgemuth, "AdxSmas.py", freqtrade-strategies, https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/berlinguyinca/AdxSmas.py.
- Author / handle: `Gert Wohlgemuth`.
- Source location: `user_data/strategies/berlinguyinca/AdxSmas.py`.
- Repository commit inspected: `dbd5b0b21cfbf5ee80588d37458ace2467b7f8a4`.

## Mechanik

### Entry
- Work on H1 closed bars.
- Compute ADX(14), SMA(3), and SMA(6).
- Long entry:
  - ADX(14) > 25.
  - SMA(3) crosses above SMA(6).
- Enter long at next bar open.

### Exit
- Source signal exit:
  - ADX(14) < 25.
  - SMA(6) crosses above SMA(3).
- Source ROI: 10% immediate target.
- Friday Close enforced by V5 defaults.

### Stop Loss
- Source stoploss: -25%.
- MT5 baseline: `QM_StopATR(14, 2.5)` with P3 sweep.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- One active position per symbol/magic.
- Skip high-impact news window.
- Spread <= 10% of planned stop distance.
- Require SMA and ADX warmup before signals.

## Concepts
- [[concepts/sma-crossover]] - primary
- [[concepts/trend-filter]] - ADX gate

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full GitHub URL and source author are cited. |
| R2 Mechanical | PASS | SMA crossover, ADX gate, ROI, and stoploss are deterministic. |
| R3 DWX-testbar | PASS | OHLC-derived indicators are available on DWX FX/metals/indices. |
| R4 No ML | PASS | Fixed indicator rules; no ML, adaptive parameters, grid, or martingale. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX.

## Parameters To Test
```yaml
- name: sma_fast
  default: 3
  sweep_range: [3, 5, 8]
- name: sma_slow
  default: 6
  sweep_range: [6, 10, 14]
- name: adx_threshold
  default: 25
  sweep_range: [20, 25, 30]
- name: atr_stop_mult
  default: 2.5
  sweep_range: [2.0, 2.5, 3.0]
```

## Author Claims
```text
"author@: Gert Wohlgemuth" (AdxSmas.py)
"converted from: https://github.com/sthewissen/Mynt/blob/master/src/Mynt.Core/Strategies/AdxSmas.cs" (AdxSmas.py)
"Optimal timeframe for the strategy" = "1h" (AdxSmas.py)
```

## Initial Risk Profile
```yaml
expected_pf: TBD
expected_dd_pct: TBD
expected_trade_frequency: 80/year
risk_class: medium
gridding: false
scalping: false
ml_required: false
```

## Framework Alignment
```yaml
modules_used:
  no_trade:
    used: true
    notes: "News blackout, spread guard, and indicator warmup."
  trade_entry:
    used: true
    notes: "Fast SMA crosses above slow SMA while ADX is above threshold."
  trade_management:
    used: true
    notes: "V5 risk stop plus source ROI target."
  trade_close:
    used: true
    notes: "Slow SMA crosses above fast SMA after ADX falls below threshold."
hard_rules_at_risk:
  - friday_close
at_risk_explanation: |
  H1 crossover trades may hold over Friday close; forced flat remains compatible with the source logic.
```

## Pipeline-Verlauf
- G0: 2026-05-23, PENDING.

## Lessons Learned
- TBD during pipeline run.
