# Gemini build preflight refusal: QM5_9721

Date: 2026-08-24 (Europe/Berlin)
Lane: \gemini\ scheduled orchestration
Checked at: 6-08-24T03:07:30ZCanonical checkout baseline: cdd70562e8417c8d9df73950fb16f296316279Outcome: \BUILD_BLOCKED_PRECONDITION
## Scope

| Priority | Router task | Card identity | EA registry | Magic rows | Canonical build files |
|---:|---|---|---|---:|---|
| 10 | \9ca8f81d-782e-495f-97f0-8f205dbd45fc\ | \QM5_9721_ff-dance-ema-touch-h1\ | exact active row | 0 | skeleton MQ5 only |

## Deterministic preflight findings

1. The runtime card exists under \D:/QM/strategy_farm/artifacts/cards_approved/QM5_9721_ff-dance-ema-touch-h1.md\, declares the requested identity and slug, and has literal \g0_status: APPROVED\. Target symbols are \[EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, EURJPY.DWX]\, period \H1\.
2. \C:/QM/repo/framework/registry/ea_id_registry.csv\ has one exact active row for EA ID 9721 and slug \f-dance-ema-touch-h1\.
3. Exact filtering of \C:/QM/repo/framework/registry/magic_numbers.csv\ by EA ID returns zero rows for 9721. The required symbol-slot magic number allocations are completely absent.
4. The canonical EA directory contains only its \.mq5\ skeleton with \// TODO: Auto-generated skeleton\; no \.ex5\, \SPEC.md\, or \.set\ file exists.
5. The payload note indicates prior orchestration deprioritisation: egistry precondition missing (no_active_magic_rows); build is structurally guaranteed to refuse.\ Tracking task \8d1d903f-39cc-461f-ab90-7b932ce62fee\ governs upstream registry allocation.

## Boundary and required upstream action

No EA source, setfile, registry, resolver, framework, terminal, or pipeline state was mutated, and compile was intentionally not run. The governed registry writer must allocate active magic rows for EA 9721 in \magic_numbers.csv\ before build can proceed.

## Router disposition

Attempted update to \REVIEW\ fails closed with \D6_BUILD_IDENTITY_MISSING\ because \uild_ea\ review requires a hash-bound JSON build packet. The task is transitioned to \BLOCKED\ with this artifact.
