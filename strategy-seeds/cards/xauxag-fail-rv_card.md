---
copy_of: strategy-seeds/cards/approved/QM5_20265_xauxag-fail-rv_card.md
card_schema_version: 2
type: strategy
strategy_id: SCHWEIKERT-CME-XAUXAG-FAILRV-2026_S02
variant_id: SCHWEIKERT-CME-XAUXAG-FAILRV-2026_S02
source_id: SCHWEIKERT-CME-XAUXAG-FAIL-2026
ea_id: QM5_20265
slug: xauxag-fail-rv
status: APPROVED
g0_status: APPROVED
source_author: "Karsten Schweikert; OlaOluwa S. Yaya; Xuan Vinh Vo; Hammed A. Olayinka; CME Group"
strategy_mechanic: synchronized-d1-gold-silver-log-ratio-sixty-day-failed-channel-break-strict-reentry-reversion-basket
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
period: D1
pipeline_phase: Q01
q01_status: NOT_RUN
q02_status: NOT_ENQUEUED
last_updated: 2026-08-07
---

# QM5_20265 XAU/XAG Failed-Break Reversion

Canonical approved card:
`strategy-seeds/cards/approved/QM5_20265_xauxag-fail-rv_card.md`.

## Hypothesis

A completed gold/silver log-ratio break that fails to remain outside a range
fixed before the event may converge. The EA waits for a separate completed D1
bar strictly back inside the old range before opening an opposite-leg package.

## Rules

Use sixty synchronized completed ratios at shifts 3..62 for the frozen range.
Require shift 2 outside and shift 1 strictly inside. Fade an upside failure by
selling XAU and buying XAG; fade a downside failure with the opposite sides.
Exit through the newest twenty-ratio mean, after thirty days, or on invalid
package/state. The canonical card locks alignment, sides, shared fixed-risk
budget, ATR stops, spread caps, and no-retry event contract.

## Risk

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1` for
one logical basket. No live artifact, portfolio mutation, neutrality claim, or
correlation waiver is authorized.

## Pipeline Status

G0 is approved under the durable OWNER mission decision. Q01 is not yet run
and Q02 is not enqueued.
