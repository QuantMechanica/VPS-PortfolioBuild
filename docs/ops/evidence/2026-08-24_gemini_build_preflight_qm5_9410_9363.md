# Gemini build preflight refusal: QM5_9410 and QM5_9363

Date: 2026-08-24 (Europe/Berlin)
Lane: \gemini\ scheduled orchestration
Checked at: 6-08-24T03:06:00ZCanonical checkout baseline: b4be32285fcfcfbb809552976f7c879e10974f2Outcome: \BUILD_BLOCKED_PRECONDITION
## Scope

| Priority | Router task | Card identity | EA registry | Magic rows | Canonical build files |
|---:|---|---|---|---:|---|
| 10 | \8a0f2cf4-afe3-4e13-80c8-9f39929de4f0\ | \QM5_9410_mql5-boom-crash\ | exact active row | 0 | skeleton MQ5 only |
| 10 | Ƽ88097-51f8-4a90-a7d5-0ca254d89b15\ | \QM5_9363_mql5-ichi-spanb-bounce\ | exact active row | 0 | skeleton MQ5 only |

## Deterministic preflight findings

1. Both runtime cards exist under \D:/QM/strategy_farm/artifacts/cards_approved/\, declare the requested identity and slug, and have literal \g0_status: APPROVED\.
   - \QM5_9410_mql5-boom-crash.md\: target symbols \[EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, NDX.DWX]\, period \M15\.
   - \QM5_9363_mql5-ichi-spanb-bounce.md\: target symbols \[GBPUSD.DWX, EURUSD.DWX, USDJPY.DWX, XAUUSD.DWX]\, period \M30\.
2. \C:/QM/repo/framework/registry/ea_id_registry.csv\ has one exact active row for each requested EA ID and slug (\9410\ / \mql5-boom-crash\, \9363\ / \mql5-ichi-spanb-bounce\).
3. Exact filtering of \C:/QM/repo/framework/registry/magic_numbers.csv\ by EA ID returns zero rows for both 9410 and 9363. Both cards require active magic number allocations for each target symbol slot, but none exist.
4. Each canonical EA directory contains only its \.mq5\ skeleton. Both sources still contain \// TODO: Auto-generated skeleton\; neither directory contains an \.ex5\, \SPEC.md\, or \.set\ file.
5. The payload notes for both tasks indicate prior orchestration deprioritisation: egistry precondition missing (no_active_magic_rows); build is structurally guaranteed to refuse.\ Tracking task \8d1d903f-39cc-461f-ab90-7b932ce62fee\ governs upstream registry allocation.

The \qm-build-ea-from-card\ contract requires active, governed magic rows for every \(ea_id, symbol_slot)\ before implementation and requires stopping on any failed preflight gate.

## Focused verification

A read-only verification loaded both canonical CSV registries, matched IDs and slugs using exact string equality, inspected the approved cards and EA directories, and verified the refusal condition:

\\	ext
8a0f2cf4 / QM5_9410: card=APPROVED registry=9410/mql5-boom-crash/active magic=0 ex5=0 spec=false sets=0 skeleton_todo=true -> FAIL_MAGIC_PRECONDITION
67488097 / QM5_9363: card=APPROVED registry=9363/mql5-ichi-spanb-bounce/active magic=0 ex5=0 spec=false sets=0 skeleton_todo=true -> FAIL_MAGIC_PRECONDITION
\
Approved-card SHA-256 values:
\\	ext
9410: 1d5d14aaa4ae667ab58d25741eab902e08486466c7541c6dcb6754188c329797
9363: b63658e3431e06adb4dcfbf2a8e86f1c32c769ff8da9d3eb30fff14985e5292c
\
Skeleton MQ5 SHA-256 values:
\\	ext
9410: 70a8c5f379b7b8581e4f1d04c36bcc8797605e7b06228c734a3d878499f7e5cc
9363: 0dfc5f228857fc9db5dc4509850072d96ae54618f478016a8f0315cac6c0ac89
\
## Boundary and required upstream action

No EA source, setfile, registry, resolver, framework, terminal, or pipeline state was mutated, and compile was intentionally not run. OWNER-governed intake must allocate complete magic rows for each requested EA in \magic_numbers.csv\ before a future build can proceed.

## Router disposition

Attempted update to \REVIEW\ fails closed with \D6_BUILD_IDENTITY_MISSING\ / \uild_identity_json_missing_review_dispatch_refused\ because \uild_ea\ review requires a hash-bound JSON build packet proving committed MQ5, EX5, setfiles, and strict-build PASS.

Neither packet can truthfully exist without magic allocations. Both tasks are therefore transitioned to \BLOCKED\ with this artifact and task-specific \PREBUILD_BLOCK\ verdicts.
