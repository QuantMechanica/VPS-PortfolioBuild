# QM5_1595 build preflight — deterministic stop

- Router task: `123a5ce6-5595-4f74-8ee9-3d591a168ad9`
- Task type / priority: `build_ea` / `50`
- Canonical checkout: `C:/QM/repo`
- Branch / inspected HEAD: `agents/board-advisor` / `609d87b9f05fd9a0f00b49ae4bf9a2b16d44e433`
- Verdict: `BLOCKED — BUILD_NOT_STARTED_REGISTRY_GATE_FAIL`

## Governed preflight

| Gate | Evidence | Result |
|---|---|---|
| Approved Strategy Card | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1595_sperandeo-2b-pivot-h4.md` declares `ea_id: QM5_1595`, matching slug, and `g0_status: APPROVED` | PASS |
| Exact active EA registry identity | No row begins `1595,` in `framework/registry/ea_id_registry.csv` | FAIL |
| Magic registry | No row begins `1595,` in `framework/registry/magic_numbers.csv` | FAIL |
| Existing source | The canonical EA directory contains only `QM5_1595_sperandeo-2b-pivot-h4.mq5` (skeleton stub, SHA-256 `dd2c28ab596d03486a149b0c4f4b1f1abbe0a5479c7330c2b28e84f14c3a407d`); no `.ex5`, `SPEC.md`, or setfiles exist | OBSERVED |

The only slug-related EA registry record is line 3138: `ea_id=12244`, slug
field `QM5_1595_sperandeo-2b-pivot-h4`, status `retired`. It was
retired at `2026-08-21T18:52:34+00:00` under the OWNER-approved D1 disposition
at `docs/ops/evidence/2026-08-21_ea_id_disposition_963.csv`.

Per `qm-build-ea-from-card`, an allocated active EA registry row and magic rows
are mandatory before implementation. No source, registry, resolver, setfile,
or binary was changed, and no compile or pipeline phase was run. Governed
identity/magic allocation or router disposition is required before build.

## Focused verification

```text
rg '^(1595),' framework/registry/ea_id_registry.csv framework/registry/magic_numbers.csv
=> no matches

rg '^(12244),' framework/registry/ea_id_registry.csv
=> 12244,QM5_1595_sperandeo-2b-pivot-h4,6e967762-b26d-59a3-b076-35c17f2e7c36,retired,DeepSeek,2026-05-26,2026-08-21T18:52:34+00:00,OWNER-approved D1 disposition; action=RETIRE only,docs/ops/evidence/2026-08-21_ea_id_disposition_963.csv
```
