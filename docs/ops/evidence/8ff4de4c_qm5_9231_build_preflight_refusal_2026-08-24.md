# QM5_9231 build preflight refusal

- Checked at: `2026-08-24T01:48:04Z`
- Router task: `8ff4de4c-7e6e-4a65-ad2f-7a8bf5788c68`
- Task type / priority: `build_ea` / `10`
- Requested EA: `QM5_9231_mql5-ad-price`
- Verdict: `BUILD_REFUSED_PRECONDITION`

## Deterministic preflight

| Gate | Evidence | Result |
|---|---|---|
| Approved card | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9231_mql5-ad-price.md` has `g0_status: APPROVED`, `ea_id: QM5_9231`, and `slug: mql5-ad-price` | PASS |
| EA registry | `framework/registry/ea_id_registry.csv` has one active row: `9231,mql5-ad-price` | PASS |
| Magic registry | `framework/registry/magic_numbers.csv` has zero rows with `ea_id=9231`; the card requires slots for `EURUSD.DWX`, `GBPUSD.DWX`, and `XAUUSD.DWX` | **FAIL** |
| Existing folder | `framework/EAs/QM5_9231_mql5-ad-price/` contains only `QM5_9231_mql5-ad-price.mq5` (4,082 bytes; SHA-256 `b6af385194656c7c63486d7217f3a1821ad2e32d58e7ed71ab79f9774e34c415`) | Incomplete; no `.ex5`, setfiles, card copy, or `SPEC.md` |

## Disposition

The governed `qm-build-ea-from-card` contract requires active magic rows before the build step and forbids the builder from allocating them. No EA source, registry, resolver, setfile, or pipeline artifact was changed, and no compile or pipeline phase was run.

The required `REVIEW` transition was attempted during this cycle and the canonical router refused it with `D6_BUILD_IDENTITY_MISSING` / `build_identity_json_missing_review_dispatch_refused`. A truthful review identity would require strict-build PASS evidence binding committed MQ5, EX5, and setfiles; those artifacts cannot exist before the upstream allocation gate passes. No build identity was fabricated. The terminal disposition for this cycle is therefore `BLOCKED`.

Required upstream action: allocate active magic rows for EA 9231 and every card symbol, regenerate `QM_MagicResolver.mqh`, and verify that regeneration retains the rows. Then recycle the build task.
