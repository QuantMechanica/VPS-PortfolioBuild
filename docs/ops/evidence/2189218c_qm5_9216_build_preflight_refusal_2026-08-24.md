# QM5_9216 build preflight refusal

- Checked at: `2026-08-24T01:34:21Z`
- Router task: `2189218c-3a65-4ca3-baba-5d63d0401d25`
- Task type / priority: `build_ea` / `10`
- Requested EA: `QM5_9216_mql5-bull-ema`
- Verdict: `BUILD_REFUSED_PRECONDITION`

## Deterministic preflight

| Gate | Evidence | Result |
|---|---|---|
| Approved card | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9216_mql5-bull-ema.md` has `g0_status: APPROVED`, `ea_id: QM5_9216`, and `slug: mql5-bull-ema` | PASS |
| EA registry | `framework/registry/ea_id_registry.csv` has one active row: `9216,mql5-bull-ema` | PASS |
| Magic registry | `framework/registry/magic_numbers.csv` has zero rows with `ea_id=9216`; the card requires slots for `EURUSD.DWX`, `GBPUSD.DWX`, and `XAUUSD.DWX` | **FAIL** |
| Existing folder | `framework/EAs/QM5_9216_mql5-bull-ema/` contains only `QM5_9216_mql5-bull-ema.mq5` (4,082 bytes; SHA-256 `09be1cdfd742f04e5e81bf1d375ba6c93e2c1e1d3f17e1b02eca6314a6ceede2`) | Incomplete; no `.ex5`, setfiles, card copy, or `SPEC.md` |

## Disposition

The governed `qm-build-ea-from-card` contract requires active magic rows before the build step and forbids the builder from allocating them. No EA source, registry, resolver, setfile, or pipeline artifact was changed, and no compile or pipeline phase was run.

The required `REVIEW` transition was attempted during this cycle and the canonical router refused it with `D6_BUILD_IDENTITY_MISSING` / `build_identity_json_missing_review_dispatch_refused`. A truthful review identity would require strict-build PASS evidence binding committed MQ5, EX5, and setfiles; those artifacts cannot exist before the upstream allocation gate passes. No build identity was fabricated. The terminal disposition for this cycle is therefore `BLOCKED`.

Required upstream action: allocate active magic rows for EA 9216 and every card symbol, regenerate `QM_MagicResolver.mqh`, and verify that regeneration retains the rows. Then recycle the build task.
