# Generic task-bound compile repair successor — 2026-09-02

Task: `68f97015-c892-4690-80ed-1ccb3b573a40`.

`farmctl enqueue-compile --repair-successor-of <failed-id> [--apply]` now provides the canonical append-only path for a source repair after a terminal `COMPILE_FAIL`/`BUILD_CHECK_FAIL`. Dry-run is the default. It fail-closes unless the predecessor is a terminal compile failure, its recorded MQ5 hash is valid, the current source hash differs, its exact build task remains the sole open task for the same canonical EA identity, and no supersession already exists.

Apply appends a held successor, removes stale compile-result/EX5 identity from the copied payload, binds the current MQ5 hash and original build task, and records a canonical `work_item_supersedes` edge. The failed row is never edited. Worker recheck recognizes only this authenticated row/edge/source-delta lineage and still performs ordinary compile/build checks.

## First use: QM5_41306

- immutable failed row: `4b5fe8c0-a322-49a1-a6ee-4a036a630800` (`COMPILE_FAIL`, `EA_INDICATOR_BUFFER_UNBOUNDED`)
- old MQ5 SHA-256: `7339f8945d81059ac42210ad3d7b67fbc49f95f3714e91bbd4d36ce5557deaf2`
- repaired MQ5 SHA-256: `69377f4f307851473c194158a1cb980482313c8120f95a1b2835ce5020e92b3f`
- bound build task: `118915f8-0275-492c-8eeb-f71e49ce515e`
- new held successor: `8620da55-f687-4ebd-9922-5fc831834628`

Dry-run classified the request eligible before apply. Apply returned `ok=true`; the successor remains activation-held for the normal reviewed worker rollout and was not manually executed.

Verification: `python -m pytest tools/strategy_farm/tests/test_compile_work_items.py -q` → **66 passed**; Python compilation passed. The new test proves no-source-delta refusal, immutable predecessor preservation, held successor creation, compile-result removal, new source binding, and the supersession edge.
