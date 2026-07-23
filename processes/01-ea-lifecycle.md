---
title: EA Lifecycle
owner: OWNER
last-updated: 2026-07-22
---

# 01 — EA Lifecycle

The lifecycle separates research authorization, implementation, empirical testing,
and live promotion. OWNER is the only human approval authority. Worker names are
assignments, not gates.

## States

```text
source_authorized
  -> card_draft
  -> g0_status: APPROVED | CHANGES_REQUIRED | REJECTED
  -> build
  -> build_pass
  -> deterministic_test_phases
  -> killed | portfolio_candidate
  -> OWNER_live_decision
  -> deployed | archived
```

## Contracts

| State change | Required evidence | Decider |
|---|---|---|
| Source → card | Identified OWNER-authorized source and citations | OWNER authorization |
| Card → build | R1-R4 record and `g0_status: APPROVED` | OWNER |
| Build → tests | Source, binary, registry, setfiles, compile result, and deployment hashes agree | Deterministic build checks |
| Test phase → next phase | Exact artifact-bound report satisfies the phase thresholds | Deterministic phase runner |
| Candidate → T6/live | Complete phase evidence, execution contract, signed deploy manifest | OWNER |

`status: DRAFT` is descriptive metadata and does not override an OWNER-recorded
`g0_status: APPROVED`. G0 authorizes falsification on T1-T5; it is not evidence of
profitability and never authorizes T6/live.

## Invariants

- EA ID and magic rows are allocated through the deterministic registries before
  implementation.
- Every build compiles with the prescribed warning policy and uses the framework
  entry, risk, cost, logging, and trade-management contracts.
- Every test result records the exact source/binary/setfile hashes, symbol,
  timeframe, actual date interval, model, costs, and terminal used.
- Infrastructure failure is not a strategy failure. Zero trades is investigated
  under [02-zt-recovery.md](02-zt-recovery.md).
- Negative evidence is retained. A failed candidate is archived, not relabeled.
- No worker toggles AutoTrading.

## Exit

An EA exits as `killed`, `portfolio_candidate`, `deployed`, or `archived`, with a
version-bound evidence trail. Any code or contract change after a validated build
follows [14-ea-enhancement-loop.md](14-ea-enhancement-loop.md) and reruns the required
phases.
