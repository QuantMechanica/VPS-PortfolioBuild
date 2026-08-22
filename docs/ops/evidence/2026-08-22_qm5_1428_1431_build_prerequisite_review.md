# QM5_1428–QM5_1431 build prerequisite review — 2026-08-22

Tasks:

- `a2d787e7-fe54-4d73-b58c-20bb04b6c880` — QM5_1428
- `ad739240-04c6-4d26-a618-f6d329bb0ea6` — QM5_1429
- `335ec1bf-dcac-4a58-977a-096af1426976` — QM5_1430
- `90ae9c0d-857d-432a-aca4-53237883390b` — QM5_1431

Verdict: **RECYCLE / BUILD NOT AUTHORIZED** for all four tasks.

The approved-card gate passes. The following OWNER-approved cards exist in the
runtime approved reservoir and each declares the routed identity with
`g0_status: APPROVED`:

- `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1428_wyckoff-phase-e-mark-up-continuation-h4.md`
- `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1429_wyckoff-phase-e-mark-down-continuation-h4.md`
- `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1430_andrews-pitchfork-parallel-line-h4.md`
- `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1431_williams-r-hidden-divergence-h4.md`

The deterministic allocation gates fail closed:

- `framework/registry/ea_id_registry.csv` has no rows whose actual `ea_id` is
  1428, 1429, 1430, or 1431.
- `framework/registry/magic_numbers.csv` has no rows for any of those four
  actual EA IDs.
- Similar names appear only under different allocations: 12193/12194 for
  QM5_1428 variants, 12195 for the QM5_1429 slug, 12196 for the QM5_1430 slug,
  and 12197 for the QM5_1431 slug. Every one is `retired` under the OWNER D1
  disposition recorded in
  `docs/ops/evidence/2026-08-21_ea_id_disposition_963.csv`. A retired,
  differently numbered row cannot authorize these routed IDs.

The existing EA directories contain only `.mq5` skeletons. They contain no
`.ex5`, `SPEC.md`, or governed setfiles. Each source still returns `false` from
`Strategy_EntrySignal`, defaults `RISK_PERCENT=0.5` alongside
`RISK_FIXED=1000`, omits the direct MAE hook, and passes a bare uninitialized
`QM_EntryRequest` to the entry hook. Those are additional build defects, but
they were not repaired because the registry and magic prerequisites fail
before implementation is authorized.

No source, card, registry, magic, setfile, resolver, or binary was changed. No
compile or pipeline row was launched. Upstream must allocate the exact EA IDs
and required symbol-slot magic rows (or issue a governed identity migration)
before these cards can be built.
