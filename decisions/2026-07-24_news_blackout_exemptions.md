# 2026-07-24 — News-blackout exemption classes (ESC-05) — RATIFIED

Status: **RATIFIED by OWNER 2026-07-24** (chat "alles freigegeben" + vault checkbox;
record: decisions/2026-07-24_owner_approvals_audit_package.md). Matrix cells for
12778/13117/13128 re-graded PASS_EXEMPT; annex added to Vault 01 Identity/Hard Rules.

## Proposed rule

The mandatory-news-blackout charter item applies to all live sleeves EXCEPT two
narrowly-defined, documented exemption classes:

1. **Basket/relative-value sleeves** (currently 12778 audusd-eurjpy-cointegration,
   13117 eurgbp-audjpy): market-neutral-ish spread constructions where a one-leg
   news halt would break the hedge rather than reduce risk. Exemption condition:
   the sleeve's Q-gate evidence was produced with news OFF (config-consistent),
   and the per-EA 3% daily-loss kill + book DD guard remain active.
2. **Event-anchored sleeves whose alpha IS the pre-event window** (currently 13128
   pre-fomc-drift): the strategy's own exit closes the position BEFORE the event
   statement (13128: exit broker-hour 20, statement ~20:00-20:30 window starts
   after; source-documented at :17,:328) — an active qm blackout gate would block
   that exit. Exemption conditions: (i) strategy-level flat-before-event invariant
   documented in SPEC, (ii) the event calendar carries a fail-closed validity
   horizon (13128: `g_event_calendar_valid_through_key=20261231`, in HEAD since
   2b7e73b83; reaches the live binary with the 26.07 rebuild), (iii) per-EA
   daily-loss kill + book DD guard active.

Every exempted sleeve gets one line in the vault Hard-Rules annex naming the class,
the rationale, and the compensating controls. New exemptions require OWNER sign-off
at Q12.

## Why (a) over (b) ("enable the filters")

Enabling the qm news axes on these three sleeves would (1) invalidate their gate
evidence (all Q02–Q10 runs were config-consistent with news OFF — re-running the
full cascade is the only honest alternative), (2) for 13128 actively break the
flat-before-event invariant by blocking the pre-statement exit, (3) for the baskets
introduce one-legged hedge states. The compliance matrix keeps the FAIL grade until
this draft is ratified; after ratification those cells become PASS_EXEMPT with a
pointer to this decision.

## Alternative (b), for completeness

Order news filters enabled: requires full cascade re-gate for 12778/13117 and a
redesign of 13128's exit interaction with the blackout gate. Not recommended.
