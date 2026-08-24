# QM5_9222 build preflight refusal

- Checked at: `2026-08-24T01:34:21Z`
- Router task: `cc5c1221-1289-4d5a-8a18-2d5d15bd63cd`
- Task type / priority: `build_ea` / `10`
- Requested EA: `QM5_9222_mql5-bwmfi-ma`
- Verdict: `BUILD_REFUSED_PRECONDITION`

## Deterministic preflight

| Gate | Evidence | Result |
|---|---|---|
| Approved card | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9222_mql5-bwmfi-ma.md` has `g0_status: APPROVED`, `ea_id: QM5_9222`, and `slug: mql5-bwmfi-ma` | PASS |
| EA registry | `framework/registry/ea_id_registry.csv` has zero rows with `ea_id=9222` | **FAIL** |
| Magic registry | `framework/registry/magic_numbers.csv` has zero rows with `ea_id=9222`; the card requires slots for `EURUSD.DWX`, `USDJPY.DWX`, and `GER40.DWX` | **FAIL** |
| Existing folder | `framework/EAs/QM5_9222_mql5-bwmfi-ma/` contains only `QM5_9222_mql5-bwmfi-ma.mq5` (4,082 bytes; SHA-256 `902559e6649b24f9c39f0a56badb5d4999a097a9237f6f843532e56b3a829846`) | Incomplete; no `.ex5`, setfiles, card copy, or `SPEC.md` |

## Disposition

The governed `qm-build-ea-from-card` contract requires a matching active EA registry row and active magic rows before the build step; it forbids the builder from allocating either. No EA source, registry, resolver, setfile, or pipeline artifact was changed, and no compile or pipeline phase was run.

The required `REVIEW` transition was attempted during this cycle and the canonical router refused it with `D6_BUILD_IDENTITY_MISSING` / `build_identity_json_missing_review_dispatch_refused`. A truthful review identity would require strict-build PASS evidence binding committed MQ5, EX5, and setfiles; those artifacts cannot exist before the upstream allocation gates pass. No build identity was fabricated. The terminal disposition for this cycle is therefore `BLOCKED`.

Required upstream action: register EA 9222 with slug `mql5-bwmfi-ma`, allocate active magic rows for every card symbol, regenerate `QM_MagicResolver.mqh`, and verify that regeneration retains the rows. Then recycle the build task.
