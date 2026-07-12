---
copy_of: strategy-seeds/cards/energy-downbeta_card.md
strategy_id: HOLLSTEIN-DOWNBETA-2021_XTI_XNG_S01
source_id: HOLLSTEIN-DOWNBETA-2021
ea_id: QM5_13203
slug: energy-downbeta
status: APPROVED
g0_status: APPROVED
created: 2026-07-12
created_by: Research
last_updated: 2026-07-12
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
factor_symbols: [SP500.DWX]
read_only_symbols: [SP500.DWX]
logical_symbol: QM5_13203_XTI_XNG_DOWNBETA_D1
period: D1
expected_trades_per_year_per_symbol: 12
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
---

# Approved Card Copy - QM5_13203_energy-downbeta

The canonical approved card is
`strategy-seeds/cards/energy-downbeta_card.md`. Approval covers exactly 252
synchronized completed XTI/XNG/SP500 D1 returns; read-only SP500.DWX as the
market proxy; an observation mask retaining each SP500 return strictly below
the arithmetic mean of all 252 SP500 returns; intercept OLS with at least 100
qualifying observations; no lags,
shrinkage, or mid-month refit; lower downside beta long and higher downside
beta short; equal `RISK_FIXED` halves; frozen ATR hard stops; next-month and
stale exits; same-month deal-history guard; and orphan cleanup.

Approval foregrounds that the source calls downside beta unpriced, all
relevant full-sample portfolio-count returns are insignificant, the
Fama-MacBeth slope is null, and source subperiods are unstable. The
low-minus-high direction is only the reversal of the source's insignificant
negative high-minus-low sign and is a strict Q02 falsification, not inherited
evidence.

Approval preserves raw-return/risk-free-zero and SP500-for-CRSP substitutions,
the backtest-only read-only factor, factor-history overlap, two-CFD narrowing,
continuous-CFD basis, gaps, legging, and costs as binding Q02 kill risks.
SP500.DWX must never receive an order or traded magic. Live artifacts,
portfolio admission, and portfolio-gate changes are not approved. Q01 build
validation and Q02 enqueue remain pending.
