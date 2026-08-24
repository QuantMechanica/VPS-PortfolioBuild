# QM5_9230 build preflight refusal

- Checked at: `2026-08-24T01:48:04Z`
- Router task: `3f4980fb-90b5-49c2-9b22-fc2938b43efb`
- Task type / priority: `build_ea` / `10`
- Requested EA: `QM5_9230_mql5-alligator-trend`
- Verdict: `BUILD_REFUSED_PRECONDITION`

## Deterministic preflight

| Gate | Evidence | Result |
|---|---|---|
| Approved card | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9230_mql5-alligator-trend.md` has `g0_status: APPROVED`, `ea_id: QM5_9230`, and `slug: mql5-alligator-trend` | PASS |
| EA registry | `framework/registry/ea_id_registry.csv` has one active row: `9230,mql5-alligator-trend` | PASS |
| Magic registry | `framework/registry/magic_numbers.csv` has zero rows with `ea_id=9230`; the card requires slots for `EURUSD.DWX`, `GBPUSD.DWX`, and `GER40.DWX` | **FAIL** |
| Existing folder | `framework/EAs/QM5_9230_mql5-alligator-trend/` contains only `QM5_9230_mql5-alligator-trend.mq5` (4,082 bytes; SHA-256 `0fa6c3b80be18689f1077ccc630ab5e048b81ebd81ef1e71d75555688f97de84`) | Incomplete; no `.ex5`, setfiles, card copy, or `SPEC.md` |

## Disposition

The governed `qm-build-ea-from-card` contract requires active magic rows before the build step and forbids the builder from allocating them. No EA source, registry, resolver, setfile, or pipeline artifact was changed, and no compile or pipeline phase was run.

Required upstream action: allocate active magic rows for EA 9230 and every card symbol, regenerate `QM_MagicResolver.mqh`, and verify that regeneration retains the rows. Then recycle the build task.
