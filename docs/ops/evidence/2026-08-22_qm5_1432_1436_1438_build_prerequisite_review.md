# QM5_1432 and QM5_1436–QM5_1438 build prerequisite review — 2026-08-22

Tasks:

- `cab1d5d3-fc96-454e-af4d-70bab7da8ac7` — QM5_1432
- `b5f5f132-c07b-4df4-a7a1-5bf27e6fb471` — QM5_1436
- `05d72df0-f109-4bb8-8c3d-34930aeb91ec` — QM5_1437
- `10837ff7-e232-4b7f-991d-93f8c86b07c0` — QM5_1438

Verdict: **RECYCLE / BUILD NOT AUTHORIZED** for all four tasks.

The approved-card gate passes. Exact OWNER-approved cards exist in
`D:/QM/strategy_farm/artifacts/cards_approved/`; their `ea_id`, slug, and
`g0_status: APPROVED` match the four routed identities.

The deterministic allocation gates fail closed:

- `framework/registry/ea_id_registry.csv` has no actual EA ID rows for 1432,
  1436, 1437, or 1438.
- `framework/registry/magic_numbers.csv` has no allocations for those actual
  EA IDs.
- Matching names exist only under the different allocations 12198, 12199,
  12200, and 12201. All four rows are `retired` under the OWNER D1 disposition
  recorded in `docs/ops/evidence/2026-08-21_ea_id_disposition_963.csv` and
  cannot authorize the routed IDs.

Each existing EA directory contains only an `.mq5` non-trading skeleton: no
`.ex5`, `SPEC.md`, or governed setfiles. The sources return `false` from
`Strategy_EntrySignal`, default `RISK_PERCENT=0.5` with
`RISK_FIXED=1000`, omit the direct MAE hook, and pass a bare uninitialized
`QM_EntryRequest` to the entry hook. Those defects were not repaired because
the registry and magic gates fail before implementation is authorized.

No source, card, registry, magic, resolver, setfile, or binary was changed. No
compile or pipeline phase was launched. Upstream must allocate the exact EA IDs
and symbol-slot magic rows, or provide an explicit governed identity migration,
before these builds can proceed.
