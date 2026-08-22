# QM5_1511 build preflight — deterministic stop

- Router task: ddbb404-f6fe-46ee-9d1e-1589d07be3d9
- Task type / priority: uild_ea / 50
- Assigned agent: gemini
- Canonical checkout: C:/QM/repo
- Branch / inspected HEAD: gents/board-advisor / 27c80e525a924aeca56e5d7c136a3228d99284e6
- Verdict: REVIEW — BUILD_NOT_STARTED_REGISTRY_GATE_FAIL

## Governed preflight

| Gate | Evidence | Result |
|---|---|---|
| Approved Strategy Card | D:/QM/strategy_farm/artifacts/cards_approved/QM5_1511_connors-tps-time-price-score-h4.md declares a_id: QM5_1511, matching slug, and g0_status: APPROVED | PASS |
| Exact active EA registry identity | No row begins 1511, in ramework/registry/ea_id_registry.csv | FAIL |
| Magic registry | No row begins 1511, in ramework/registry/magic_numbers.csv | FAIL |
| Existing source | The canonical EA directory contains only auto-generated skeleton QM5_1511_connors-tps-time-price-score-h4.mq5 (SHA-256: 930b638eeff3724bd28b291dcfb932ddc839a67180a8c4a8f2e5da1fdbfecbc5); entry hook returns false | OBSERVED |

The only slug-related EA registry record is line 3116: a_id=12222, slug field QM5_1511_connors-tps-time-price-score-h4, status 
etired. It was retired at 2026-08-21T18:52:34+00:00 under the OWNER-approved D1 disposition recorded at docs/ops/evidence/2026-08-21_ea_id_disposition_963.csv.

Per qm-build-ea-from-card, an allocated active EA registry row and magic rows are mandatory before implementation. Gemini scope (gent_capabilities.json) explicitly forbids EA compilation and registry reservation. No source, registry, resolver, setfile, or binary was changed, and no compile or pipeline phase was run. The task requires governed identity/magic allocation or router disposition before a build can start.

## Focused verification

`	ext
rg '^(1511),' framework/registry/ea_id_registry.csv framework/registry/magic_numbers.csv
=> no matches

rg '^(12222),' framework/registry/ea_id_registry.csv
=> 12222,QM5_1511_connors-tps-time-price-score-h4,6e967762-b26d-59a3-b076-35c17f2e7c36,retired,DeepSeek,2026-05-26,2026-08-21T18:52:34+00:00,OWNER-approved D1 disposition; action=RETIRE only,docs/ops/evidence/2026-08-21_ea_id_disposition_963.csv
`
