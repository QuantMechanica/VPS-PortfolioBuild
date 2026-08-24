# QM5_9516 build preflight — deterministic refusal

- Router task: `3ff472a0-8f53-4558-ae66-459a29c77da2`
- Task type / priority: `build_ea` / `10`
- Assigned agent: `codex`
- EA / expected slug: `9516` / `mql5-l1-ma`
- Checked at: `2026-08-24T03:05:13Z`
- Canonical checkout baseline: `7b4be32285fcfcfbb809552976f7c879e10974f2`
- Verdict: `REVIEW — BUILD REFUSED AT PRE-FLIGHT`

## Deterministic evidence

The approved card and canonical registries were inspected with exact `ea_id`
matching.

| Gate | Result |
|---|---|
| Approved Strategy Card | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9516_mql5-l1-ma.md` declares `ea_id: QM5_9516`, `slug: mql5-l1-ma`, and `g0_status: APPROVED` |
| `ea_id_registry.csv` | exactly `1` row — active, slug `mql5-l1-ma` |
| `magic_numbers.csv` | exactly `0` rows for `ea_id=9516` — **FAIL** |
| Required symbol slots | card targets `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, and `GER40.DWX`; none is allocated |
| Canonical EA directory | `framework/EAs/QM5_9516_mql5-l1-ma/` exists and contains only `QM5_9516_mql5-l1-ma.mq5`; no `.ex5`, `SPEC.md`, or setfiles |

The `qm-build-ea-from-card` contract requires active magic rows for every target
symbol slot before implementation and requires an immediate stop when any
preflight gate fails. The task payload's 2026-08-22 deprioritisation identified
the same `no_active_magic_rows` condition and named tracking task
`8d1d903f-39cc-461f-ab90-7b932ce62fee`. The EA identity has since been restored,
but the magic-allocation half of that prerequisite remains incomplete.

No EA source, registry, resolver, setfile, framework, terminal, or pipeline
mutation was attempted. No compile or pipeline verdict is claimed.

## Required upstream action

The governed registry allocator must allocate active magic rows for all four
card symbol slots, regenerate the magic resolver, and verify that no rows are
dropped. After that prerequisite is durable, route a fresh build attempt.
