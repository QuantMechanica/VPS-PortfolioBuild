# Gemini build preflight refusal: QM5_9205 and QM5_9204

Date: 2026-08-24 (Europe/Berlin)  
Lane: \gemini\ scheduled orchestration  
Checked at: 6-08-24T01:18:30Z\  
Canonical checkout baseline: \953ecc62dbee208b2184c478ff7aa0d07a7eed55\  
Outcome: \BUILD_BLOCKED_PRECONDITION
## Scope

| Priority | Router task | Card identity | EA registry | Magic rows | Canonical build files |
|---:|---|---|---|---:|---|
| 10 | \feb2af8-f725-4dbe-b15a-47c3e19d2ffd\ | \QM5_9205_mql5-stoch-side\ | exact active row | 0 | skeleton MQ5 only |
| 10 | \912be76d-68dc-4852-88fc-e7c80b04c03b\ | \QM5_9204_mql5-mfi-trend\ | exact active row | 0 | skeleton MQ5 only |

## Deterministic preflight findings

1. Both runtime cards exist under \D:/QM/strategy_farm/artifacts/cards_approved/\, declare the requested identity and slug, and have literal \g0_status: APPROVED\.
2. \C:/QM/repo/framework/registry/ea_id_registry.csv\ has one exact active row for each requested EA ID and slug (\9205\ / \mql5-stoch-side\, \9204\ / \mql5-mfi-trend\).
3. Exact filtering of \C:/QM/repo/framework/registry/magic_numbers.csv\ by EA ID returns zero rows for both 9205 and 9204. Both cards target \EURUSD.DWX\, \GBPUSD.DWX\, and \XAUUSD.DWX\, so the required symbol-slot magic number allocations are completely absent.
4. Each canonical EA directory contains only its \.mq5\ skeleton. Both sources still contain \TODO: Auto-generated skeleton\; neither directory contains an \.ex5\, \SPEC.md\, or \.set\ file.
5. The payload notes for both tasks indicate prior orchestration deprioritisation: egistry precondition missing (no_active_magic_rows); build is structurally guaranteed to refuse.\ Tracking task \8d1d903f-39cc-461f-ab90-7b932ce62fee\ governs upstream registry allocation.

The \qm-build-ea-from-card\ contract requires active, governed magic rows for every \(ea_id, symbol_slot)\ before implementation and requires stopping on any failed preflight gate.

## Focused verification

A read-only verification loaded both canonical CSV registries, matched IDs and slugs using exact string equality, inspected the approved cards and EA directories, and verified the refusal condition:

\\	ext
afeb2af8 / QM5_9205: card=APPROVED registry=9205/mql5-stoch-side/active magic=0 ex5=0 spec=false sets=0 skeleton_todo=true -> FAIL_MAGIC_PRECONDITION
912be76d / QM5_9204: card=APPROVED registry=9204/mql5-mfi-trend/active magic=0 ex5=0 spec=false sets=0 skeleton_todo=true -> FAIL_MAGIC_PRECONDITION
\
Approved-card SHA-256 values, in table order:

\\	ext
c1aa9d9d51b738a02d6d2721a0f2de66b6ee84ee6e6866ce4caccba008a0406e
a556cfb5f65931308863a538c38edda2c0310678bf0de30e86177b7375ed0dbf
\
Skeleton MQ5 SHA-256 values, in table order:

\\	ext
9f62cb7625021119d476a290d33e564c0349dfeb792cebe7ba4539bc126581d2
3238e13c9eb2327c729774c296921fdebc6d114d9f62700a967dacd425124138
\
## Boundary and required upstream action

No EA source, setfile, registry, resolver, framework, terminal, or pipeline state was mutated, and compile was intentionally not run. OWNER-governed intake must allocate complete magic rows for each requested EA in \magic_numbers.csv\ before a future build can proceed.

## Router disposition

Attempted update to \REVIEW\ fails closed with \D6_BUILD_IDENTITY_MISSING\ / \uild_identity_json_missing_review_dispatch_refused\ because \uild_ea\ review requires a hash-bound JSON build packet proving committed MQ5, EX5, setfiles, and strict-build PASS.

Neither packet can truthfully exist without magic allocations. Both tasks are therefore transitioned to \BLOCKED\ with this artifact and task-specific \PREBUILD_BLOCK\ verdicts.
