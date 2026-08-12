---
ea_id: QM5_11194
slug: ft-hour
type: strategy
source_id: 1580128f-e465-5454-bb97-a7572a6cfd6d
source_citation: "Masoud Azizi (@Mablue), HourBasedStrategy.py, freqtrade-strategies, GitHub, https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/HourBasedStrategy.py"
sources:
  - "[[sources/freqtrade-strategies]]"
concepts:
  - "[[concepts/session-timing]]"
  - "[[concepts/time-of-day-edge]]"
  - "[[concepts/roi-exit]]"
indicators:
  - "[[indicators/hour-of-day]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, GER40.DWX]
period: H1
expected_trade_frequency: "Source comments show 51-158 trades over 100-day crypto tests; conservative DWX estimate is 60-120 trades/year/symbol after spread/news filters."
expected_trades_per_year_per_symbol: 80
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-23
g0_approval_reasoning: "R1 GitHub source cited; R2 H1 hour-window entry plus ROI/time exits mechanical with plausible 60-120 trades/year/symbol; R3 portable to DWX FX/metals/indices; R4 fixed rules no ML/grid/martingale."
---

# Freqtrade Hour Window Strategy

## Quelle

- Source: [[sources/freqtrade-strategies]]
- Citation: Masoud Azizi (@Mablue), "HourBasedStrategy.py", freqtrade-strategies, GitHub, 2026 URL https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/HourBasedStrategy.py.
- Author / handle: `@Mablue (Masoud Azizi)`.
- Source location: `user_data/strategies/HourBasedStrategy.py`.
- Repository commit inspected: `dbd5b0b21cfbf5ee80588d37458ace2467b7f8a4`.

## Mechanik

### Entry

- Work on H1 closed bars.
- Compute broker-hour of the closed candle.
- Long entry:
  - Source default buy window: hour between 4 and 24.
  - Enter long at next bar open when no position is open.

### Exit

- Source signal exit:
  - Sell-hour parameters are `sell_hour_min = 22`, `sell_hour_max = 21`; treat this as a wraparound window for implementation review rather than an empty pandas `between()` result.
- Source ROI ladder: 52.8% immediately, 11.3% after 169 minutes, 8.9% after 528 minutes, 0% after 1837 minutes.
- Friday Close enforced by V5 defaults.

### Stop Loss

- Source stoploss: -10%.
- MT5 baseline: `QM_StopATR(14, 2.0)` with P3 sweep.

### Position Sizing

- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter

- One active position per symbol/magic.
- Skip high-impact news window.
- Spread <= 8% of planned stop distance.
- Use a fixed timezone mapping and document broker-time conversion in implementation.

## Concepts

- [[concepts/session-timing]] - primary
- [[concepts/time-of-day-edge]] - primary
- [[concepts/roi-exit]] - secondary

## R1-R4 Bewertung

| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full GitHub URL plus author handle/name in source comments. |
| R2 Mechanical | PASS | Hour window entry, time-window exit, ROI ladder, and stoploss are deterministic. |
| R3 DWX-testbar | PASS | Time-of-day/session logic is testable on DWX FX, metals, and index CFDs. |
| R4 No ML | PASS | Fixed hyperopt constants; no ML, adaptive parameters, grid, or martingale. |

## R3

Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, GER40.DWX. Crypto source is ported as a session-timing edge; implementation must pin broker-hour handling.

## Parameters To Test

```yaml
- name: buy_hour_min
  default: 4
  sweep_range: [2, 4, 6]
- name: buy_hour_max
  default: 24
  sweep_range: [18, 21, 24]
- name: sell_hour_min
  default: 22
  sweep_range: [18, 22, 23]
- name: sell_hour_max
  default: 21
  sweep_range: [6, 12, 21]
- name: atr_stop_mult
  default: 2.0
  sweep_range: [1.5, 2.0, 2.5]
```

## Author Claims

```text
"In this strategy we try to find the best hours to buy and sell in a day.(in hourly timeframe)" (HourBasedStrategy.py)
"Because of that you should just use 1h timeframe on this strategy." (HourBasedStrategy.py)
Source comments report 51, 113, 158, and 65-trade 100-day crypto examples with optimized hour windows.
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
    notes: "News blackout, spread guard, broker-hour normalization."
  trade_entry:
    used: true
    notes: "Enter during fixed buy-hour window."
  trade_management:
    used: true
    notes: "V5 risk stop plus source ROI ladder."
  trade_close:
    used: true
    notes: "Sell-hour window plus Friday close and ROI/stop exits."
hard_rules_at_risk:
  - broker_time_dst
  - friday_close
at_risk_explanation: |
  Session edges are sensitive to broker-time/DST mapping and require deterministic conversion.
```

## Pipeline-Verlauf

- G0: 2026-05-23, PENDING.

## Lessons Learned

- TBD during pipeline run.
