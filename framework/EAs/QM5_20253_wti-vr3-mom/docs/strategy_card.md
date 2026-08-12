---
card_schema_version: 2
type: strategy
strategy_id: MEHLITZ-AUER-MEM-2024_XTI_R3Q4_S02
variant_id: MEHLITZ-AUER-MEM-2024_XTI_R3Q4_S02
source_id: MEHLITZ-AUER-WTI-R3Q4-2026
ea_id: QM5_20253
slug: wti-vr3-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20253_wti-vr3-mom_card.md
execution_contract_status: DRAFT
created: 2026-08-06
created_by: Research+Development
last_updated: 2026-08-06
g0_status: APPROVED
source_authors: "Julia S. Mehlitz; Benjamin R. Auer"
source_citation: "Mehlitz, J. S. and Auer, B. R. (2024), Memory-enhanced momentum in commodity futures markets, The European Journal of Finance 30(8), 773-802, DOI 10.1080/1351847X.2023.2220118."
source_citations:
  - type: peer_reviewed_paper
    citation: "Mehlitz, Julia S. and Auer, Benjamin R. (2024). Memory-enhanced momentum in commodity futures markets. The European Journal of Finance 30(8), 773-802."
    location: "Sections 3.3.1-3.3.2 and Appendix C; DOI https://doi.org/10.1080/1351847X.2023.2220118; complete open precursor review recorded in strategy-seeds/sources/MEHLITZ-AUER-MEM-2024/source.md"
    quality_tier: A
    role: primary
strategy_mechanic: monthly-wti-three-month-return-sign-times-q4-heteroskedastic-robust-variance-ratio-memory-state
sources:
  - "[[sources/MEHLITZ-AUER-WTI-R3Q4-2026]]"
  - "[[sources/MEHLITZ-AUER-MEM-2024]]"
concepts:
  - "[[concepts/memory-enhanced-momentum]]"
  - "[[concepts/variance-ratio]]"
  - "[[concepts/wti-structural-trend-reversal]]"
indicators:
  - "[[indicators/lo-mackinlay-variance-ratio]]"
  - "[[indicators/three-month-log-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-momentum-reversal, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 202530000
period: D1
timeframe: D1
expected_trade_frequency: "Estimated five to nine completed WTI positions per full post-warm-up year; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 7
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: ENQUEUED
review_focus: "Falsify the published WTI R3-q4 memory state as a crude-oil return stream distinct from the certified XAU/SP500/NDX/XNG book; only Q09 may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [completed_month_reconstruction, three_month_return, q4_variance_ratio, heteroskedastic_robust_variance, fixed_significance_threshold, memory_direction_matrix, restart_attempt_state, risk_mode, friday_close_exception, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-06_qm5_20253_wti_vr3_mom_g0.md: tier-A peer-reviewed complete-read source with explicit WTI and R3-q4 membership; locked 33 month ends, 32 returns, three-month rank, q4 lag/VR/robust weights, two-sided 10% threshold, continuation/reversal matrix, persisted monthly attempt, ATR stop, rollover, and stale exit; registered XTIUSD.DWX D1 route; deterministic native arithmetic only. Dedup scanned 4,310 registry rows and 427 cards, found no exact collision, and the expected R1-q2 source sibling was manually resolved."
---

# QM5_20253 WTI R3-q4 Memory-Enhanced Momentum

## Hypothesis

WTI's completed three-month direction may persist only when the latest 32
monthly returns exhibit statistically significant q4 persistence. In a
significant anti-persistent state, the same three-month move may instead
reverse. Applying the source-declared R3-q4 state to WTI may produce a slow
crude-oil stream whose carrier differs from the certified index, gold, and
natural-gas book.

This is a falsifiable source port, not a profitability or decorrelation claim.
Q02 owns density and baseline economics. Q09 alone may measure book overlap.

## Source Traceability And Claim Boundary

The governed packet is
strategy-seeds/sources/MEHLITZ-AUER-WTI-R3Q4-2026/source.md. Its completely
reviewed parent records Mehlitz and Auer's peer-reviewed article and complete
open precursor chapter. The source explicitly includes WTI, pairs a
three-month ranking return with q=4, estimates the robust variance-ratio state
over 32 monthly observations, uses a fixed two-sided 10% threshold, and maps
persistence to continuation and anti-persistence to reversal.

The source does not test Darwinex continuous CFDs, D1-derived broker month
ends, fixed cash risk, ATR stops, spread caps, the attempt ledger, or the QM
portfolio. No source PF, return, Sharpe, drawdown, trade-count, WTI-constituent,
neutrality, or correlation statistic transfers.

## Non-Duplicate Decision

The deterministic pre-allocation checker found no exact collision and one
expected fuzzy source sibling, QM5_13134. Manual review fixes the boundary:

- QM5_13134 is R1-q2: one-month return sign, lag-one autocorrelation,
  VR(2)=1+rho(1), and one robust term.
- QM5_20253 is R3-q4: three-month return sign, autocorrelation lags one through
  three, VR weights 1.5/1.0/0.5, and robust weights 2.25/1.0/0.25.
- Plain WTI three-month momentum has no memory estimator, fixed significance
  gate, or anti-persistence reversal.
- Existing q2 WTI composites retain the one-month q2 state and add unrelated
  calendar or return-sign filters.

The ranking horizon, q order, lag set, variance-ratio weights, robust weights,
and resulting direction path are jointly load-bearing. No current EA
implements the WTI R3-q4 specification.

## Rules

At a genuine broker-month transition, reconstruct 33 consecutive completed
month-end closes from completed XTIUSD.DWX D1 bars and form the latest 32
chronological monthly log returns. Compute the locked q4 robust variance ratio,
the completed three-month ranking return, and the source direction matrix.
An actionable state may enter once in that broker month. An insignificant or
invalid state consumes the month flat.

## 4. Entry Rules

1. Run only on the first processed D1 bar whose current broker-month key
   differs from the previous completed D1 bar's key.
2. Use exactly 33 consecutive completed month-end closes and exactly 32
   chronological monthly log returns.
3. Let d[t] be return t minus the 32-return mean and S be the sum of d[t]^2.
4. For lags k=1,2,3, compute rho(k) from lagged cross products divided by S and
   delta(k) from lagged products of squared deviations divided by S squared.
5. Compute VR(4)=1+1.5*rho(1)+rho(2)+0.5*rho(3).
6. Compute theta(4)=2.25*delta(1)+delta(2)+0.25*delta(3), then
   z=(VR(4)-1)/sqrt(theta(4)).
7. Require abs(z)>1.64485362695147.
8. Compute R3 as the sum of the latest three monthly log returns.
9. Enter BUY when sign(R3)*sign(z) is positive and SELL when it is negative.
10. Remain flat on zero R3, insignificant memory, incomplete history,
    nonconsecutive month ends, zero variance, zero robust variance, invalid
    arithmetic, excessive spread, invalid ATR, an open managed position, or a
    current-month entry already recorded.
11. Attach a frozen 3.0*ATR(20,D1) hard stop and no take-profit.
12. Size through the V5 stop-risk path with RISK_FIXED=1000,
    RISK_PERCENT=0, and PORTFOLIO_WEIGHT=1 in Q02.

## 5. Exit Rules

- Close on the first processed XTI D1 bar of the next broker month before
  considering the new formation.
- Close after 35 calendar days as a stale-position guard.
- The broker hard stop remains authoritative between D1 bars.
- A stop-out or rejected attempt does not permit same-month re-entry.
- Friday close is disabled only to preserve the source's month-to-month hold.
- There is no take-profit, trailing stop, break-even move, or discretionary
  close.

## 6. Filters (No-Trade Module)

- Fail closed unless the host is exactly XTIUSD.DWX, D1, slot 0, EA 20253.
- Lock the source sample to 32 returns, ranking horizon three months, q=4, and
  the fixed 1.64485362695147 threshold.
- Require the bounded D1 history buffer, positive finite closes, consecutive
  monthly keys, valid return arithmetic, positive robust variance, valid ATR,
  and spread no greater than 1500 points.
- Framework kill switch and two-axis entry-news checks remain authoritative.
  Entry-news checks never block month-transition or stale exits.

## 7. Trade Management Rules

- Exactly one XTI position is permitted for magic 202530000.
- Month-transition and stale exits run before the entry news gate.
- Entry history and terminal global attempt state prevent restart retries.
- No scale-in, pyramiding, grid, martingale, partial close, trailing stop,
  adaptive parameters, optimizer-selected runtime state, external data, or
  PnL feedback is allowed.

## Parameters To Test

| parameter | default | authorized range | role |
|---|---:|---|---|
| strategy_vr_window_months | 32 | [32] | source test window |
| strategy_rank_months | 3 | [3] | source R3 horizon |
| strategy_vr_q | 4 | [4] | source q4 order |
| strategy_significance_z | 1.64485362695147 | [1.64485362695147] | fixed two-sided 10% gate |
| strategy_history_bars_d1 | 1200 | [900, 1200, 1600] | month-end reconstruction buffer only |
| strategy_atr_period_d1 | 20 | [20] | hard-stop ATR |
| strategy_atr_sl_mult | 3.0 | [3.0] | frozen stop distance |
| strategy_max_hold_days | 35 | [35] | stale guard |
| strategy_max_spread_points | 1500 | [1500] | entry spread cap |

The ranking horizon, q, sample, threshold, direction matrix, cadence, and
same-month attempt policy are locked. Any change requires a new card and full
pipeline run.

## Risk

Q02 uses one XTIUSD.DWX D1 backtest setfile with RISK_FIXED=1000,
RISK_PERCENT=0, and PORTFOLIO_WEIGHT=1. There is no live setfile. WTI gaps,
continuous-CFD roll/financing, a 33-month warm-up, sparse significant states,
single-carrier concentration, and portfolio correlation are explicit kill
risks.

Retire below five completed trades per full post-warm-up year, on zero trades,
wrong month-end reconstruction, wrong R3 or q4 arithmetic, nondeterminism,
risk-mode mismatch, unacceptable baseline economics, or any later unchanged
gate failure. Do not relax the source rule to rescue a failure.

## Strategy Allowability Check

- [x] R1 reputable: peer-reviewed journal article with DOI and a completely
  reviewed open precursor; WTI and R3-q4 are source-declared.
- [x] R2 mechanical: sample, formula, weights, threshold, direction, cadence,
  stop, sizing, exits, and attempt state are deterministic.
- [x] R3 testable: registered native XTIUSD.DWX D1 history supplies all
  runtime inputs.
- [x] R4 compliant: deterministic price/calendar arithmetic only; no trained
  model, banned signal indicator, external feed, grid, martingale, pyramiding,
  or adaptive fitting.
- [x] Expected activity is at or above the five-trade Q02 floor, subject to
  deterministic retirement if the observed count is lower.

## Framework Alignment

- no_trade: exact identity, source parameter locks, history, arithmetic,
  spread, ATR, position, and attempt guards.
- trade_entry: monthly R3-q4 direction and frozen ATR stop through framework
  fixed-risk sizing.
- trade_management: next-month reset, stale close, and restart-safe attempt
  state.
- trade_close: framework close helper and broker-side hard stop.

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-06 | APPROVED | decisions/2026-08-06_qm5_20253_wti_vr3_mom_g0.md |
| Q01 Build Validation | 2026-08-06 | PASS | strict compile and framework build evidence in `docs/ops/evidence/2026-08-06_qm5_20253_wti_vr3_mom_q01_cpu_stop.md` |
| Q02 Baseline Screening | 2026-08-06 | ENQUEUED_ACTIVE | guarded apply was skipped at the CPU ceiling; subsequent readback found one active Q02 item on T10, documented in `docs/ops/evidence/2026-08-06_qm5_20253_wti_vr3_mom_q01_cpu_stop.md` |
