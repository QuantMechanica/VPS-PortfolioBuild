---
copy_of: strategy-seeds/cards/approved/QM5_20268_xauxag-qtail-rv_card.md
card_schema_version: 2
type: strategy
strategy_id: SCHWEIKERT-CME-XAUXAG-QTAILRV-2026_S03
variant_id: SCHWEIKERT-CME-XAUXAG-QTAILRV-2026_S03
source_id: SCHWEIKERT-CME-XAUXAG-QTAIL-2026
ea_id: QM5_20268
slug: xauxag-qtail-rv
status: APPROVED
g0_status: APPROVED
source_author: "Karsten Schweikert; OlaOluwa S. Yaya; Xuan Vinh Vo; Hammed A. Olayinka; CME Group"
strategy_mechanic: synchronized-d1-gold-silver-log-ratio-frozen-126-empirical-decile-central-to-two-tail-reversion-basket
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
period: D1
pipeline_phase: Q02
q01_status: PASS
q02_status: ENQUEUED
q02_work_item_id: 2b803c41-5ef5-4cf4-8b20-ce51681287bc
last_updated: 2026-08-09
---

# QM5_20268 XAU/XAG Empirical-Quantile Tail Reversion

Canonical approved card:
`strategy-seeds/cards/approved/QM5_20268_xauxag-qtail-rv_card.md`.

## Hypothesis

A gold/silver log-ratio excursion that persists beyond a frozen empirical
outer decile for two completed sessions may converge. A distribution-free
order statistic avoids assuming a Gaussian ratio or estimating a scale.

## Rules

Use 126 synchronized pre-event D1 ratios for fixed nearest-rank deciles.
Require one central completed ratio followed by two completed ratios beyond
the same tail. Fade with opposite XAU/XAG legs; exit through a rolling
twenty-one-ratio median, on invalid package/state, or after thirty-five days.
The canonical card locks exact shifts, indexes, sides, shared fixed-risk
budget, ATR stops, spread caps, and consumed-attempt contract.

## Risk

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1` for one logical basket. No live artifact, portfolio
mutation, neutrality claim, or correlation waiver is authorized.

## Pipeline Status

G0 is approved under the durable OWNER mission decision. The deterministic V5
basket build and strict compile passed Q01; one logical-basket Q02 item is
enqueued under `2b803c41-5ef5-4cf4-8b20-ce51681287bc`.
