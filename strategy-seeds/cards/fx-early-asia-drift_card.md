---
strategy_id: CODEX-FTMO-H1-RESEARCH-2026-07-10_S01
source_id: CODEX-FTMO-H1-RESEARCH-2026-07-10
ea_id: QM5_13124
slug: fx-early-asia-drift
status: REJECTED
created: 2026-07-10
created_by: Research
last_updated: 2026-07-10
g0_status: APPROVED
approved: 2026-07-10
approved_by: "OWNER-delegated CEO + Quality-Business + CTO decision to Codex"
ea_id_allocated_by: "OWNER-delegated CEO + CTO decision to Codex"
g0_approval_reasoning: "R1 PASS reproducible own-data anomaly study; R2 PASS fixed UTC entry, one-hour hold, and ATR stop; R3 PASS native DWX H1 and M1 real-tick history on T1-T5; R4 PASS no ML/grid/martingale. The candidate remains research-only until strict Q02-Q10 evidence passes."
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
source_citations:
  - type: own_data_research
    citation: "Codex FTMO H1 intraday hypothesis screen, 2026-07-10. Darwinex custom-symbol H1 exports; DEV 2018-2021, validation 2022-2023, final diagnostic 2024-2026."
    location: "D:/QM/mt5/T_Export/MQL5/Files and artifacts/ftmo_h1_intraday_research_2026-07-10.json"
    quality_tier: B
    role: primary
sources:
  - "[[sources/CODEX-FTMO-H1-RESEARCH-2026-07-10]]"
concepts:
  - "[[concepts/fx-early-asia-drift]]"
indicators: [ATR]
strategy_type_flags: [intraday-session-pattern, time-stop, multi-symbol]
target_symbols: [EURGBP.DWX, GBPUSD.DWX, EURAUD.DWX, AUDJPY.DWX, NZDUSD.DWX]
primary_target_symbols: [EURGBP.DWX, GBPUSD.DWX, EURAUD.DWX, AUDJPY.DWX]
markets: [forex]
single_symbol_only: true
period: H1
timeframes: [H1]
expected_trade_frequency: "At most one trade per UTC business day and symbol, approximately 240-260 trades/year/symbol."
expected_trades_per_year_per_symbol: 250
expected_pf: TBD
expected_dd_pct: TBD
risk_class: high
ml_required: false
pipeline_phase: PRE_Q02_REJECTED_TIMEBASE
research_verdict: RETIRED_BROKER_WALLCLOCK_ROLLOVER_ARTIFACT
review_focus: "Whether the early-Asia H1 drift survives real bid/ask ticks, FTMO FX commission, spread widening, and fixed-risk ATR stops."
modules_used: [no_trade, trade_entry, trade_close]
hard_rules_at_risk: [model4_every_real_tick, fx_commission, spread_at_entry, risk_mode_dual, kill_switch_coverage]
---

# FX Early-Asia Drift

## Hypothesis

A fixed positive drift appears during the first one or two UTC hours of the
early Asian FX session. The discovery screen separated 2018-2021 development,
2022-2023 validation, and 2024-2026 diagnostic samples. The following locked
long-only carriers retained the same sign in all available splits:

| symbol | entry UTC | exit UTC | discovery note |
|---|---:|---:|---|
| EURGBP.DWX | 00:00 | 01:00 | strongest three-split risk-normalized result; history ends 2024 |
| GBPUSD.DWX | 00:00 | 01:00 | positive in all three splits through April 2026 |
| EURAUD.DWX | 00:00 | 01:00 | positive in all three splits through 2025 |
| AUDJPY.DWX | 01:00 | 02:00 | positive in all three splits through 2025 |
| NZDUSD.DWX | 00:00 | 01:00 | secondary carrier; history ends 2024 |

The pre-Q02 timebase audit found that the MQL-exported epoch values encode
broker wallclock. Treating those values as UTC moved broker midnight into the
purported early-Asia window. The apparent effect was therefore a rollover-bar
artifact, not the stated UTC-session anomaly. No real-tick run is authorized.

## Rules

```text
- Trade H1 only and enforce the registered symbol/slot binding.
- At the first tick no more than 120 seconds after the locked UTC hour, BUY.
- Permit at most one entry per UTC date and symbol.
- Stop at 1.25 times the prior closed H1 ATR(20); no take profit.
- Skip the entry if the current spread exceeds 5% of that ATR.
- Close after 60 minutes. News and entry-spread gates may never block exits.
- Do not retry a rejected or stopped entry on the same UTC date.
```

## Locked Parameters

| parameter | value | authorized range |
|---|---:|---|
| direction | long | [long] |
| entry hour UTC | symbol table | [symbol table] |
| hold minutes | 60 | [60] |
| ATR period | 20 | [20] |
| stop ATR multiple | 1.25 | [1.25] |
| max spread / ATR | 0.05 | [0.05] |
| max entry delay seconds | 120 | [120] |

No parameter rescue is authorized. A failed primary carrier is retired; a
surviving carrier must then pass walk-forward, stress, multi-seed, Davey, and
full-history confirmation before it can enter an FTMO simulation.

## Risk And Allowability

- Fixed-risk baseline uses USD 1,000 per trade only for candidate screening.
- Multiple sleeves can overlap; portfolio deployment sizing is deferred to the
  joint-equity FTMO model and may not be inferred from single-EA drawdown.
- No grid, martingale, averaging, pyramiding, trailing stop, partial close,
  adaptive rule, external runtime feed, or ML.
- All tests use model 4 real ticks and current-binary evidence on T1-T5 only.
- This card is a research authorization, not a challenge deployment approval.

## Pipeline Status

| Phase | Date | Verdict | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-07-10 | APPROVED | this card |
| Q01 Build Validation | 2026-07-10 | PASS | `framework/build/compile/20260710_202527/QM5_13124_fx-early-asia-drift.compile.log` |
| Pre-Q02 Timebase Audit | 2026-07-10 | REJECTED | broker-wallclock versus UTC reconstruction check |
| Q02 Baseline Screening | 2026-07-10 | NOT RUN | invalid discovery premise |
| Q04 Walk-Forward | TBD | TBD | TBD |
| Q05-Q10 Robustness | TBD | TBD | TBD |

## Lessons Captured

- MQL `datetime` values exported as integers must be interpreted as encoded
  broker wallclock for this dataset before reconstructing UTC.
- Exclude the NY 17:00 rollover neighborhood from bar-only FX anomaly screens.
- The corrected 2,848-rule screen produced zero simple H1 rules that passed
  both 2018-2021 development and 2022-2023 validation after costs.
