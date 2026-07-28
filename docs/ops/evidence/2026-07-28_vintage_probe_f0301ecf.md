# QM5_9936 `f0301ecf` governed-probe execution

Date: 2026-07-28  
Router task: `c93b27af-3e6a-4944-881e-6cb923527fca`

## Verdict

**NOT EXECUTED — the two historical binaries cannot currently be staged as
distinct governed work items without mutating the canonical QM5_9936 deployment
path.**

No causal commit is named. The 72 shifted exits remain real but their causal
boundary remains **NOT ESTABLISHED**.

## Checks performed

The requested boundary is valid:

- tested commit: `f0301ecf78a989730b3b4338a161cd4210417912`
- parent: `c0918247cfe554f9727be9e810524ec4b557cb15`
- commit date: `2026-07-27T10:40:51+02:00`

`farmctl work-items --ea QM5_9936` returned 22 rows and no pending or active
historical-probe item. The most recent governed standalone row remains
`588af557-300f-4e25-82a4-81974b04380a`, already done against the current
canonical binary.

The local controller exposes governed enqueueing by EA/set identity, while the
terminal worker resolves the binary from that canonical identity. There is no
task-scoped parameter for an immutable EX5 path or expected EX5 SHA-256 at
enqueue time. Compiling `f0301ecf^` and `f0301ecf` serially is possible in
separate checkouts, but submitting them both as `QM5_9936` would require copying
each result over the canonical EA deployment path. With the factory active,
that creates a race between enqueue, claim, and binary replacement; the work
item could run the wrong arm even if a pre-enqueue hash were recorded.

The alternative of inventing synthetic EA IDs/labels is not evidence-equivalent:
it changes the governed identity and may change path- and magic-dependent
behavior. It is therefore not used.

## Required unblock

Add one governed, immutable probe input to the work-item contract:

1. a task-scoped EX5 staging path plus required SHA-256, copied atomically to
   the claimed terminal only after the work item is claimed; or
2. a registered pair of probe EA identities whose sources, includes, set,
   calendar seed, model, and magic are proven equivalent to QM5_9936 except for
   the Git boundary.

The worker must verify the staged EX5 SHA-256 immediately before and after the
run and persist both values in `summary.json`. Once that exists, enqueue the
parent arm first, wait for completion, then compile and enqueue the child arm.
Use the same dense window, current calendar seed, setfile, Model 4, and terminal
harness. Do not regenerate sleeve streams before the comparison.

## Guardrails observed

No EA, include, setfile, calendar seed, archived stream, terminal, AutoTrading
state, or work-item row was changed. No terminal process was started. No
Factory_OFF/Factory_ON operation was run. T5 and T_Live were not touched.
