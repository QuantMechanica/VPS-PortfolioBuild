---
copy_of: strategy-seeds/cards/approved/QM5_20268_xauxag-qtail-rv_card.md
strategy_id: SCHWEIKERT-CME-XAUXAG-QTAILRV-2026_S03
source_id: SCHWEIKERT-CME-XAUXAG-QTAIL-2026
ea_id: QM5_20268
slug: xauxag-qtail-rv
status: APPROVED
g0_status: APPROVED
pipeline_phase: Q02
q01_status: PASS
q02_status: ENQUEUED
q02_work_item_id: 2b803c41-5ef5-4cf4-8b20-ce51681287bc
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
logical_symbol: QM5_20268_XAU_XAG_QTAILRV_D1
period: D1
---

# Build-Time Card Reference

Canonical approved rules:
`strategy-seeds/cards/approved/QM5_20268_xauxag-qtail-rv_card.md`.

## Hypothesis

A synchronized gold/silver log-ratio move that persists beyond a frozen
empirical outer decile for two completed sessions may converge. This is a
distribution-free relative-value hypothesis, not a neutrality claim.

## Rules

The build must retain the exact synchronized 129-completed-bar contract; the
frozen 126-ratio sample at shifts 4..129; zero-based order-statistic indexes
12, 62/63, and 113; the separate central-plus-two-tail event; inverse XAU/XAG
sides; one aggregate fixed-risk stop budget; rolling 21-ratio median exit;
thirty-five-day stale exit; and restart-safe two-leg lifecycle repair.

## Risk

Backtests use one package budget with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`; each leg receives half after independent ATR-stop
normalization. No live artifact or portfolio mutation is authorized.

The source supports a state-dependent relationship and relative-value carrier,
not this rule's efficacy, neutrality, or portfolio decorrelation. No live or
portfolio artifact is authorized.
