---
copy_of: strategy-seeds/cards/xau-xag-qc_card.md
strategy_id: SCHWEIKERT-QC-2018_XAU_XAG_S01
source_id: SCHWEIKERT-QC-2018
ea_id: QM5_13205
slug: xau-xag-qc
status: APPROVED
g0_status: APPROVED
created: 2026-07-12
created_by: Research
last_updated: 2026-07-12
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
logical_symbol: QM5_13205_XAU_XAG_QC_D1
period: D1
expected_trades_per_year_per_symbol: 8
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
---

# Approved Card Copy - QM5_13205_xau-xag-qc

The canonical approved card is
`strategy-seeds/cards/xau-xag-qc_card.md`. Approval covers exactly one logical
XAU/XAG D1 basket: a monthly fit on 504 synchronized completed log-price pairs,
with the newest completed pair held out; exact constrained simple quantile
regressions at 10%, 50%, and 90% via asymmetric check loss and sorted
pairwise-slope breakpoints; weekly tail-envelope decisions; a QM-defined
positive upper-minus-lower beta-span guard; conditional-median and 70-day
exits; beta-target dollar notionals jointly scaled to one RISK_FIXED stop-loss
budget; frozen ATR hard stops; restart-safe weekly suppression; and orphan
cleanup.

Restart safety is part of the approval: the current-month model is rebuilt
from its original first-host-bar anchor, and the broker-week attempt key is
persisted before order submission so a full two-leg rejection cannot be
retried after reinitialization.

Approval foregrounds that Schweikert (2018) does not publish a forecasting or
trading rule, rejects important constant-vector specifications, finds some
daily/futures upper-quantile rejection, and warns that constant-coefficient
spread arbitrage is risky. Logs, the rolling window, chosen quantiles,
beta-span threshold, monthly/weekly cadence, envelope entry, median exit, and
risk rules are QM mechanizations and binding Q02 kill risks.

Replacing asymmetric check-loss coefficients with OLS, a fixed beta, z-score,
raw ratio, channel, stochastic, Kalman, or return-spread logic is outside this
approval and collides with existing builds. Live artifacts, portfolio
admission, and portfolio-gate changes are not approved.

## Q01/Q02 handoff

Q01 passed strict compilation with zero errors/warnings, the full build check
with zero failures/warnings, SPEC/card/guardrail/basket-scope validation, and
an independent semantic re-audit. On 2026-07-12, `farmctl record-build`
enqueued one logical Q02 item, `be5ffa78-fdfb-4718-af89-5f7fc7e8dee3`,
pending at attempt 0 and unclaimed. No tester or backtest was launched.
