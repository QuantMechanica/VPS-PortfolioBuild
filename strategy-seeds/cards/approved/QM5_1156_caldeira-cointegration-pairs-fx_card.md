---
ea_id: QM5_1156
slug: caldeira-cointegration-pairs-fx
type: strategy
source_id: afab7a6f-c3c8-51ae-a609-f376744beb8e
source_citation: "Caldeira and Moura (2013), Selection of a Portfolio of Pairs Based on Cointegration: A Statistical Arbitrage Strategy, SSRN 2196391 / Journal of International Financial Markets, Institutions and Money."
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCHF.DWX, AUDUSD.DWX, NZDUSD.DWX]
period: D1
execution_period: M30
expected_trade_frequency: "D1 spread decisions with M30 execution; bounded by one package per pair and a 30-D1-bar time stop."
expected_trades_per_year_per_symbol: 100
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "The approved source is SSRN 2196391 and its peer-reviewed journal publication; the method has named academic authors and durable publication lineage."
r2_mechanical: PASS
r2_reasoning: "The rolling OLS residual, fixed z-score thresholds, weekly refresh, divergence stop, and time stop are deterministic."
r3_data_available: PASS
r3_reasoning: "All six declared G10 USD crosses are registered .DWX symbols with D1 history."
r4_ml_forbidden: PASS
r4_reasoning: "Closed-form OLS and fixed statistical tests are structural calculations; no learned predictor or PnL-adaptive rule is used."
pipeline_phase: Q02_PENDING
last_updated: 2026-08-11
approval_recovery:
  source_path: "D:/QM/strategy_farm/artifacts/cards_approved/QM5_1156_caldeira-cointegration-pairs-fx.md"
  source_sha256: "39E6EB1D3959F10BFA9DA11A973B55153934DCFB95240577522BA4E0F3508A58"
  note: "Schema-normalized repository recovery of the pre-existing OWNER-approved farm Card; approval and mechanics are unchanged."
---

# QM5_1156 Caldeira-Moura Cointegration Pairs (FX Port)

## Hypothesis

Two FX rates that share a long-run equilibrium can temporarily diverge while
their residual remains mean reverting. A two-leg, approximately
market-neutral package should capture convergence without taking an outright
directional USD view. The source supplies the structural cointegration and
spread-trading method; pair selection and all performance claims remain
separate empirical questions.

The active Q02 fallback is the already-built slot-12 package
`USDCHF.DWX` / `AUDUSD.DWX`. It is not a new Card or a new relationship claim:
the frozen 66-pair scan already maps this pair to this explicit slot. The scan
records adverse DEV/OOS evidence, so Q02 is a one-shot cadence/economics gate,
not an invitation to tune or rescue the pair.

## Rules

### Formation and signal

- Universe: the six registered G10 USD crosses in `target_symbols`.
- Enumerate the 15 deterministic pair slots in source order.
- On the weekly closed-D1 refresh, estimate a 60-D1-bar OLS residual for the
  selected pair and apply the fixed residual-stationarity proxy implemented by
  the EA.
- Standardize the residual over 60 completed D1 bars.
- Enter long spread below `z = -2.0`; enter short spread above `z = +2.0`.
- Open both legs as one package. Partial entry or an orphaned package is
  flattened; there is no naked-leg continuation.

### Exit and safety

- Close both legs when `abs(z) < 0.5`.
- Close both legs when `abs(z) > 4.0`.
- Close after 30 D1 bars regardless of residual state.
- Close or suppress entry when the fixed weekly cointegration gate no longer
  qualifies.
- Allow at most one position per pair magic and at most four packages across
  the approved universe.

### Active Q02 binding

- Pair slot: `12`.
- Host: `USDCHF.DWX`, M30 tester host with D1 signal history.
- Companion: `AUDUSD.DWX`.
- Logical symbol: `QM5_1156_USDCHF_AUDUSD_COINTEGRATION_M30`.
- No parameter refit, extra filter, or alternate beta is authorized after a
  cadence or economic failure.

## Risk

- Backtest mode is `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Package sizing splits risk through the estimated hedge weights.
- Each leg receives the authorized `3 * ATR(14,D1)` catastrophic stop.
- No grid, martingale, averaging down, or learned sizing is allowed.
- Live files and live deployment are outside this Card recovery and Q02
  handoff.

## Parameters To Test

```yaml
- name: strategy_formation_days
  default: 60
  sweep_range: [30, 60, 90]
- name: strategy_entry_z
  default: 2.0
  sweep_range: [1.5, 2.0, 2.5]
- name: strategy_exit_abs_z
  default: 0.5
  sweep_range: [0.0, 0.5, 1.0]
- name: strategy_stop_abs_z
  default: 4.0
  sweep_range: [4.0]
- name: strategy_max_hold_days
  default: 30
  sweep_range: [30]
```

Q02 uses only the defaults above. Parameter sweeps require the normal later
gate and do not authorize post-failure rescue.

## Source

- Primary: Caldeira, J. F. and Moura, G. V. (2013), *Selection of a
  Portfolio of Pairs Based on Cointegration: A Statistical Arbitrage
  Strategy*, SSRN 2196391 and the peer-reviewed journal publication.
- Durable URL: `https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2196391`.
- Method lineage: Engle-Granger cointegration, rolling residual formation,
  fixed spread z-score entries/exits, and cost-aware statistical arbitrage.
- Port boundary: the paper establishes the method, not profitability for the
  `USDCHF.DWX` / `AUDUSD.DWX` pair.

## Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "Framework safety, news, Friday-close, history, and package-state gates."
  trade_entry:
    used: true
    notes: "Open the two-leg package at the fixed residual z threshold."
  trade_management:
    used: true
    notes: "Maintain package integrity and enforce the divergence/time stops."
  trade_close:
    used: true
    notes: "Flatten both legs at mean reversion, stationarity loss, or a hard stop."
hard_rules_at_risk:
  - one_position_per_magic_symbol
  - magic_schema
  - friday_close
at_risk_explanation: |
  Both legs share the pair-slot package identity. The logical basket manifest
  and fixed-risk setfile must remain bound to slot 12 for this Q02 run.
```

## Pipeline History

| Version | Date | Reason | Stage | Verdict |
|---|---|---|---|---|
| v1 | 2026-05-18 | OWNER-approved farm Card | G0 | APPROVED |
| v1-recovery | 2026-08-11 | Canonical schema recovery; no mechanic change | G0 | APPROVED |
| v1-slot12 | 2026-08-11 | Strict compile and build checks for the slot-12 logical package | Q01 | PASS |
| v1-slot12-q02 | 2026-08-11 | Exact logical-basket work item 415cd6d3-560c-46d8-a9f9-ee4a5b399100 enqueued | Q02 | PENDING |
