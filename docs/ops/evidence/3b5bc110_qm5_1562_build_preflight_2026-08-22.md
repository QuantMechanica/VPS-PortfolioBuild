# QM5_1562 build preflight — deterministic stop

- Router task: `3b5bc110-929d-4322-bdd8-994211b6a017`
- Task type / priority: `build_ea` / `50`
- Canonical checkout: `C:/QM/repo`
- Branch / inspected HEAD: `agents/board-advisor` / `e12f4a5a87d0be39a1907c9a1b1cc2f088ca7ace`
- Verdict: `REVIEW — BUILD_NOT_STARTED_REGISTRY_IDENTITY_MISMATCH`

## Governed preflight

| Gate | Evidence | Result |
|---|---|---|
| Approved Strategy Card | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1562_demark-td-range-projection-h4.md` declares `ea_id: QM5_1562`, folder slug, and `g0_status: APPROVED` | PASS |
| Exact EA ID/slug identity | Registry ID `1562` is active as `aa-comm-spot-rev`, not the card/folder slug `demark-td-range-projection-h4` | FAIL |
| Slug uniqueness | The requested card slug is already active under `ea_id=1551` | FAIL |
| Magic registry | No row begins `1562,` in `framework/registry/magic_numbers.csv` | FAIL |
| Existing source | The canonical EA directory has an `.mq5` skeleton; it does not substitute for exact governed identity | OBSERVED |

Per `qm-build-ea-from-card`, card slug, EA folder slug, and the allocated EA
registry slug must match exactly. Reusing active ID 1562 would overwrite the
identity allocated to `aa-comm-spot-rev`, while the requested DeMark slug is
already allocated to ID 1551. No source, registry, resolver, setfile, or binary
was changed, and no compile or pipeline phase was run. OWNER-governed identity
and router disposition are required before build.

## Focused verification

```text
rg '^(1562),' framework/registry/ea_id_registry.csv framework/registry/magic_numbers.csv
=> ea registry: 1562,aa-comm-spot-rev,...,active,...
=> magic registry: no matches

rg 'demark-td-range-projection-h4' framework/registry/ea_id_registry.csv
=> 1551,demark-td-range-projection-h4,...,active,...
=> 12234,QM5_1547_demark-td-range-projection-h4,...,retired,...
```
