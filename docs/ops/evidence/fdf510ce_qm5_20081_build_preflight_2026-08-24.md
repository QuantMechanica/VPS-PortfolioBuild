# QM5_20081 build preflight — deterministic refusal

- Router task: `fdf510ce-db61-46f3-a1da-dad1559c0a73`
- Task type / priority / agent: `build_ea` / `10` / `codex`
- EA: `QM5_20081_renko-triple-block-flip-h1`
- Checked at: `2026-08-24T04:05:13Z`
- Canonical checkout: `C:/QM/repo`, branch `agents/board-advisor`, baseline `46e7be1d3db9297ff40c53c6d977ff975c11bace`
- Verdict: `BLOCKED — BUILD REFUSED AT PRE-FLIGHT`

## Deterministic evidence

The canonical CSV registries were loaded with `Import-Csv` and filtered by exact `ea_id` equality.

| Gate | Result |
|---|---|
| Approved card | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_20081_renko-triple-block-flip-h1.md`; SHA-256 `D0C01743377A5BC821B8D1D5B1C012EB813573178527809BCE3D515CB7E121EB`; `g0_status: APPROVED`; slug match PASS |
| EA registry | one active row for `20081,renko-triple-block-flip-h1` — PASS |
| EA directory | canonical directory and tracked `.mq5` skeleton exist — PASS |
| Magic registry | zero rows for exact `ea_id=20081`; therefore zero active rows — **FAIL** |

Registry snapshots used: `ea_id_registry.csv` SHA-256 `4A0ABB97B79DF767FCB1571AADBF9D3DC349C22088B9980C6BEB50072B530A4F`; `magic_numbers.csv` SHA-256 `1A30B5DF1986A641CB0F3BB6BE57D643CC003DCB3EC77ACA17C4636CCF930B1E`.

The `qm-build-ea-from-card` contract requires active magic rows for every `(ea_id, symbol_slot)` used and requires an immediate stop when pre-flight fails. The skill also forbids Development from allocating those rows. No source, registry, resolver, setfile, terminal, compile, or pipeline mutation was attempted.

A requested `REVIEW` transition using this evidence was deterministically refused by the canonical router as `D6_BUILD_IDENTITY_MISSING`: build tasks can enter REVIEW only with a JSON packet proving strict-build PASS and hash-binding committed `.mq5`, `.ex5`, and setfiles. Those artifacts do not exist and must not be fabricated. The truthful router disposition is therefore `BLOCKED` pending the upstream registry action.

## Required upstream action

The OWNER-governed registry writer must allocate the card-required active magic rows for EA 20081, regenerate `QM_MagicResolver.mqh`, verify that no rows were dropped, and then reroute a fresh build attempt. This pre-flight establishes no pipeline verdict.
