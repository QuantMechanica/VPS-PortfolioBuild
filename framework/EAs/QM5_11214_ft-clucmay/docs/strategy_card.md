---
ea_id: QM5_11214
slug: ft-clucmay
type: strategy
source_id: 1580128f-e465-5454-bb97-a7572a6cfd6d
source_citation: "ClucMay72018.py, freqtrade-strategies, GitHub, https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/berlinguyinca/ClucMay72018.py"
sources:
  - "[[sources/freqtrade-strategies]]"
concepts:
  - "[[concepts/bollinger-mean-reversion]]"
  - "[[concepts/volume-filter]]"
  - "[[concepts/ema-trend-filter]]"
indicators:
  - "[[indicators/bollinger-bands]]"
  - "[[indicators/ema]]"
  - "[[indicators/rsi]]"
  - "[[indicators/macd]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
period: M5
expected_trade_frequency: "M5 below-EMA lower-Bollinger mean-reversion with volume cap; conservative estimate 70-150 trades/year/symbol."
expected_trades_per_year_per_symbol: 100
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-07-23
g0_rejection_reason: "SUPERSEDED: source-only rejection recovered under OWNER R1 policy on 2026-07-23; original retained in cards_rejected."
status: APPROVED
r1_reasoning: "Existing attribution retained; R1 is informational and non-gating under OWNER policy 2026-07-23."
card_body_incomplete: false
card_body_missing: ""
legacy_contract_repair: false
g0_recovery_reason: "Source-only rejection recovered; audited card body documents R2-R4 PASS."
g0_recovery_origin: "D:/QM/strategy_farm/artifacts/cards_rejected/QM5_11214_ft-clucmay.md"
g0_approval_reasoning: "OWNER 2026-07-23 retroactive source-only recovery; body audit documents R2-R4 PASS and original rejection is retained."
---

# Freqtrade ClucMay Bollinger Volume Reversal

## Source
- Source: [[sources/freqtrade-strategies]]
- Citation: "ClucMay72018.py", freqtrade-strategies, GitHub, URL https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/berlinguyinca/ClucMay72018.py.
- Author / handle: Gert Wohlgemuth, from source docstring.
- Source location: `user_data/strategies/berlinguyinca/ClucMay72018.py`.
- Repository commit inspected: `dbd5b0b21cfbf5ee80588d37458ace2467b7f8a4`.

## Mechanics

### Entry
- Work on M5 closed bars.
- Compute RSI(5), EMA(5) of RSI, MACD, ADX, Bollinger Bands(20, 2) on typical price, and EMA(50) of close. The source names EMA(50) as `ema100`.
- Long entry requires:
  - Close < EMA(50).
  - Close < 0.985 * lower Bollinger band.
  - Volume < prior rolling mean volume(30) * 20.
- Enter long at next bar open.

### Exit
- Source signal exit:
  - Close > Bollinger middle band.
- Source ROI: 1% immediate target.
- Friday Close enforced by V5 defaults.

### Stop Loss
- Source stoploss: -5%.
- MT5 baseline: `QM_StopATR(14, 1.5)` capped by source -5%.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Additional filters
- One active position per symbol/magic.
- Skip high-impact news window.
- Spread <= 6% of planned stop distance.
- Require Bollinger, EMA, and 30-bar volume warmup.
- Map Freqtrade exchange volume to MT5 tick volume for the volume cap.

## Concepts
- [[concepts/bollinger-mean-reversion]] - primary
- [[concepts/volume-filter]] - extreme-volume avoidance
- [[concepts/ema-trend-filter]] - below-EMA setup condition

## R1-R4 assessment
| Criterion | Status | Rationale |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full GitHub URL and source author are cited. |
| R2 Mechanical | PASS | Bollinger/EMA/volume entry, middle-band exit, ROI, and stop are deterministic. |
| R3 DWX-testbar | PASS | OHLC indicators are available; volume cap maps to MT5 tick volume. |
| R4 No ML | PASS | Fixed indicator rules; no ML, adaptive parameters, grid, or martingale. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX. Volume filter semantics are a porting risk and should be tested with and without the volume cap.

## Parameters To Test
```yaml
- name: bb_period
  default: 20
  sweep_range: [20, 30, 40]
- name: bb_lower_mult
  default: 0.985
  sweep_range: [0.975, 0.985, 0.995]
- name: ema_period
  default: 50
  sweep_range: [50, 100, 150]
- name: volume_mean_mult
  default: 20
  sweep_range: [5, 10, 20]
- name: roi_target
  default: 0.01
  sweep_range: [0.006, 0.01, 0.015]
```

## Author Claims
```text
"author@: Gert Wohlgemuth" (ClucMay72018.py)
"Optimal timeframe for the strategy" = "5m" (ClucMay72018.py)
```

## Initial Risk Profile
```yaml
expected_pf: TBD
expected_dd_pct: TBD
expected_trade_frequency: 100/year
risk_class: high
gridding: false
scalping: true
ml_required: false
```

## Framework Alignment
```yaml
modules_used:
  no_trade:
    used: true
    notes: "News blackout, spread guard, warmup, and tick-volume availability."
  trade_entry:
    used: true
    notes: "Close below EMA50 and deeply below lower Bollinger with volume cap."
  trade_management:
    used: true
    notes: "Source ROI/stop plus V5 ATR stop normalization."
  trade_close:
    used: true
    notes: "Middle Bollinger recovery, ROI, stop, and Friday close."
hard_rules_at_risk:
  - scalping_p5b_latency
  - friday_close
at_risk_explanation: |
  M5 cadence requires latency/noise validation. Friday close remains compatible.
```

## Pipeline history
- G0: 2026-05-23, PENDING.

## Lessons Learned
- TBD during pipeline run.
