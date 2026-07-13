---
strategy_id: CODEX-FTMO-H1-RESEARCH-2026-07-10_S02
source_id: CODEX-FTMO-H1-RESEARCH-2026-07-10
ea_id: QM5_13125
slug: xau-usclose-ovnt
status: REJECTED
created: 2026-07-10
created_by: Research
last_updated: 2026-07-10
g0_status: APPROVED
approved: 2026-07-10
approved_by: "OWNER-delegated CEO + Quality-Business + CTO decision to Codex"
ea_id_allocated_by: "OWNER-delegated CEO + CTO decision to Codex"
g0_approval_reasoning: "R1 PASS reproducible own-data anomaly study; R2 PASS fixed broker-clock entry/exit and prior D1 ATR stop; R3 PASS XAUUSD.DWX H1/M1 native history on T1-T5; R4 PASS no ML/grid/martingale. Promotion requires current-binary real-tick evidence."
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
source_citations:
  - type: own_data_research
    citation: "Codex FTMO H1 structural-session study, 2026-07-10. Darwinex XAUUSD.DWX H1 export; development 2017-2021, validation 2022-2023, holdout 2024-2025."
    location: "D:/QM/mt5/T_Export/MQL5/Files/XAUUSD.DWX_H1.csv and artifacts/ftmo_h1_intraday_research_2026-07-10.json"
    quality_tier: B
    role: primary
sources:
  - "[[sources/CODEX-FTMO-H1-RESEARCH-2026-07-10]]"
concepts:
  - "[[concepts/xau-us-close-overnight-drift]]"
indicators: [ATR]
strategy_type_flags: [overnight-session-pattern, time-stop, long-only]
target_symbols: [XAUUSD.DWX]
primary_target_symbols: [XAUUSD.DWX]
markets: [metals]
single_symbol_only: true
period: H1
timeframes: [H1]
expected_trade_frequency: "One Monday-through-Thursday overnight trade; approximately 195-205 trades/year."
expected_trades_per_year_per_symbol: 200
expected_pf: TBD
expected_dd_pct: TBD
risk_class: medium
ml_required: false
pipeline_phase: Q02_FAIL_FTMO_CARRY
research_verdict: RETIRED_CURRENT_FTMO_SWAP_ERASES_EDGE
review_focus: "Survival of the broker 23:00-to-16:00 XAU drift under native ticks, spread, commission, gaps, D1 ATR stops, and FTMO daily-loss anchoring."
modules_used: [no_trade, trade_entry, trade_close]
hard_rules_at_risk: [model4_every_real_tick, overnight_gap, daily_loss_anchor, risk_mode_dual, kill_switch_coverage]
---

# XAU US-Close Overnight Drift

## Hypothesis

XAUUSD retains a positive return from the post-US-close broker hour to the next
day's pre-US-open hour. The locked H1 proxy enters at broker 23:00 and exits at
broker 16:00. Friday entries are excluded to match the framework Friday-close
contract and to avoid weekend gap exposure.

With a conservative 8-basis-point round-trip deduction and a prior D1 ATR(14)
stop, the bar-level risk-normalized screen produced:

| sample | trades | PF | annualized Sharpe |
|---|---:|---:|---:|
| DEV through 2021 | 843 | 1.210 | 1.146 |
| validation 2022-2023 | 396 | 1.166 | 0.906 |
| holdout 2024-2025 | 397 | 1.704 | 3.304 |

The screen is only a hypothesis gate. H1 bars cannot resolve entry spread,
intrabar stop ordering, slippage, or FTMO account constraints.

## Rules

```text
- XAUUSD.DWX H1 only, registered slot 0.
- Monday through Thursday, BUY at the first tick no more than 120 seconds
  after 23:00 broker time.
- Attach a stop one prior closed D1 ATR(14) below entry; no take profit.
- Permit one entry per broker date and do not retry after rejection or stop.
- Skip entry when spread exceeds 2% of the prior D1 ATR.
- Close at the first tick at or after 16:00 on the following broker date.
- Friday close, kill switch, and emergency maximum hold remain authoritative.
- News and entry filters may never block the time exit.
```

## Locked Parameters

| parameter | value | authorized range |
|---|---:|---|
| entry broker time | 23:00 | [23:00] |
| exit broker time | 16:00 next date | [16:00] |
| eligible entry weekdays | Mon-Thu | [Mon-Thu] |
| ATR timeframe / period | D1 / 14 | [D1 / 14] |
| stop ATR multiple | 1.00 | [1.00] |
| max spread / ATR | 0.02 | [0.02] |
| max entry delay | 120 seconds | [120] |
| emergency maximum hold | 72 hours | [72 hours] |

No parameter sweep or rescue is authorized before the locked baseline has
passed the full validation sequence.

## Risk And Allowability

- Q02 fixed risk is USD 1,000 per trade for comparability, not deployment size.
- The position spans the FTMO midnight anchor; joint-equity simulation must
  assign floating P/L to the correct CE(S)T day before any book decision.
- No grid, martingale, scale-in, averaging, pyramiding, TP, trailing stop,
  break-even, partial close, adaptive parameter, external feed, or ML.
- This is research authorization only, not FTMO deployment approval.

## Pipeline Status

| Phase | Date | Verdict | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-07-10 | APPROVED | this card |
| Q01 Build Validation | 2026-07-10 | PASS | `framework/build/compile/20260710_205251/QM5_13125_xau-usclose-ovnt.compile.log` |
| Q02 Baseline Screening | 2026-07-10 | FAIL | `artifacts/ftmo_xau_usclose_overnight_q02_costed_2026-07-10.json` |
| Q04 Walk-Forward | 2026-07-10 | NOT RUN | Q02 hard stop |
| Q05-Q10 Robustness | 2026-07-10 | NOT RUN | Q02 hard stop |

## Retirement Decision

The native custom-symbol reports contain spread but zero commission and zero
swap. Their pooled 2019-2025 PF of 1.293 is therefore not an FTMO result. Deal
reconciliation against the 2026-07-10 FTMO XAU/USD specification (0.0014%
commission per side and -75.93 points long swap, Wednesday triple rollover)
reduces the pooled PF to 0.971 and net profit to -USD 6,978.62. The locked
strategy is retired without parameter rescue.
