# Framework-input pin batch repair — Wave 1 review

Date: 2026-09-06  
Router task: `0b971b15-c37f-4ea6-8304-f61d76433862`  
State: REVIEW; no compile enqueue and no worker reload

## Result

- Repaired all 70 `PLAIN_REBUILD` sources named by the canonical census.
- Removed `qm_rng_seed`, `qm_news_*`, and `qm_friday_close_*` comparisons only
  from `Strategy_NoTradeFilter`.
- Replaced stress-probability equality pins with the finite inclusive `0..1`
  range check. EA identity, magic-slot, strategy, and fixed-risk guards remain.
- Added all 70 `.mq5` paths to `.gitattributes` as `-text`; the repaired source
  bytes are LF and their SHA-256 values are sealed by the authority evidence.
- Confirmed one approved card, one active matching EA registry identity, and at
  least one formula-correct active magic row for every EA.
- Exclusions: none.

## Immutable authority

`2026-09-06_framework_input_pin_wave1_authority.json` contains 70 exact
per-EA source hashes, approved-card hashes, registry/magic preflight results,
and 81 existing `COMPILE_EA` predecessor rows. Eleven EAs had no compile row;
their exact authorities therefore carry an empty predecessor set while still
binding the task ID, EA identity, repaired source hash, approved card, active
registry/magic state, and this immutable evidence file.

The authority file SHA-256 is
`962910ee790946efe0133f0cd876ab2d4fe7dbd5a1675cdcaa1c7215b327f03f`.
`compile_work_items.py` loads registrations only when that exact hash and the
70-row fail-closed schema contract match.

## Verification

- Canonical `EA_FRAMEWORK_INPUT_PINNED` predicate on the 70 repaired sources:
  `0` findings.
- Focused tests:
  `python -m pytest tools/strategy_farm/tests/test_compile_backlog_authorities.py tools/strategy_farm/tests/test_framework_input_pin_predicate.py -q`
  — `226 passed`.
- Real CLI dry runs: 70/70 `ELIGIBLE`, 70/70
  `source_repair_authorized=true`, `mode=dry_run`, and `enqueued_count=0`.
  Complete receipts are in
  `2026-09-06_framework_input_pin_wave1_dry_run.json`.

No historical verdict or work-item row was modified. Wave 2 remains outside
this task and requires its separately routed REVIEW after Wave 1 integration.
