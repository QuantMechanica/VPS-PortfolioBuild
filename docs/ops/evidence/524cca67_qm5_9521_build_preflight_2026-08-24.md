# QM5_9521 build preflight — deterministic refusal

- Router task: `524cca67-50b7-409a-a13c-7860dc61148d`
- Task type / priority: `build_ea` / `10`
- Assigned agent: `codex`
- EA / expected slug: `9521` / `mql5-hidden-smash`
- Checked at: `2026-08-24T03:05:13Z`
- Canonical checkout baseline: `7b4be32285fcfcfbb809552976f7c879e10974f2`
- Verdict: `REVIEW — BUILD REFUSED AT PRE-FLIGHT`

## Deterministic evidence

The approved card and canonical registries were inspected with exact `ea_id`
matching.

| Gate | Result |
|---|---|
| Approved Strategy Card | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9521_mql5-hidden-smash.md` declares `ea_id: QM5_9521`, `slug: mql5-hidden-smash`, and `g0_status: APPROVED` |
| `ea_id_registry.csv` | exactly `1` row — active, slug `mql5-hidden-smash` |
| `magic_numbers.csv` | exactly `0` rows for `ea_id=9521` — **FAIL** |
| Required symbol slots | card targets `GER40.DWX`, `XAUUSD.DWX`, `EURUSD.DWX`, and `GBPUSD.DWX`; none is allocated |
| Canonical EA directory | `framework/EAs/QM5_9521_mql5-hidden-smash/` exists and contains only `QM5_9521_mql5-hidden-smash.mq5`; no `.ex5`, `SPEC.md`, or setfiles |

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
