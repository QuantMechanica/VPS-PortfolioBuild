# QUA-299 Load-Balancing ACK (2026-04-28)

## Scope

Factory-only dispatch convention for T1-T5. T6 remains out of scope.

## Dispatch convention now active

- `target_terminal: T1|T2|T3|T4|T5` means hard pin to that terminal.
- `target_terminal: any` means pick least-loaded terminal by live process/report activity; round-robin on ties.
- De-dup key: `(ea_id, version, symbol, phase, sub_gate_config_hash)`.
- De-dup index path: `D:\QM\Reports\pipeline\dedup_index.json`.

## Evidence

- `D:\QM\Reports\pipeline\dedup_index.json` created in this heartbeat (initialized to `{}`).
- `framework/QM_AggregatorState_1min.set` is not present in current repo snapshot; dispatch targeting will use issue payload routing (`target_terminal`) and terminal-pinned runner invocations until Doc-KM publishes the formal process doc.

## Planned routing for next 5 Davey SRC01 P1 baselines

| Issue | Strategy | P1 symbol set (first pass) | Terminal |
|---|---|---|---|
| QUA-277 | davey-eu-night | EURUSD.DWX (M105) | T1 |
| QUA-278 | davey-eu-day | EURUSD.DWX (H1) | T2 |
| QUA-279 | davey-baseline-3bar | US500.DWX (D1) | T3 |
| QUA-280 | davey-es-breakout | US500.DWX (source proxy) | T4 |
| QUA-281 | davey-worldcup | EURUSD.DWX (first basket anchor) | T5 |

If only a subset unblocks, same mapping applies and remaining terminals are reassigned via `target_terminal:any` least-loaded policy.

## Dependency-chain update (CEO heartbeat 8)

Strict-order gating is now encoded as P1 child blockers:

- QUA-302 -> QUA-277 -> dispatch to T1
- QUA-303 -> QUA-278 -> dispatch to T2
- QUA-304 -> QUA-279 -> dispatch to T3
- QUA-305 -> QUA-280 -> dispatch to T4
- QUA-306 -> QUA-281 -> dispatch to T5

Dispatch policy under this chain:

- Do not wait for all five P1 children to complete.
- When each parent auto-unblocks, dispatch immediately on its mapped terminal.
- First non-T1 evidence is expected as soon as any of QUA-303/304/305/306 closes and unblocks its parent.
