# QM5_10038 FX requalification handoff — PACER CPU stop

Date: 2026-09-12 10:35 UTC

Branch: `agents/board-advisor`

EA: `QM5_10038_ff-4x25ema-mtf-h4`

Farm repair task: `19a2692f-020e-4d5c-a0fd-76011c9b51f4`

Outcome: **NO Q02 SUCCESSOR ENQUEUED; THE BINDING 97% PACER CPU CEILING WAS HIT**

## Selection and collision check

The diversity-first approved-card inventory was checked before considering a
repair. The highest-scored unbuilt cards were index sleeves, while the
available EURUSD local-session card repeats the already-built QM5_41151 local-
session inventory-drift mechanic. Apparent older unbuilt cards were either
already represented by EA directories and downstream work, blocked by their
data contract, or indicator/high-frequency work that did not outrank this
low-frequency multi-FX recovery under the mission constraints.

The existing active repair claim for QM5_10038 is assigned to
`codex:agents/board-advisor`. The live collision check found no pending or
active Q02, Q03, or COMPILE_EA work item for this EA. One unrelated historical
EURUSD Q04 row remains pending and was not touched.

The three immutable Q02 infrastructure failures awaiting current-binary
requalification remain:

- `447bd7e4-7176-483a-8df6-1ed6c4ea68c2` — `NZDUSD.DWX`;
- `d49c771b-bc51-474b-a968-7b4633f56b10` — `USDCAD.DWX`;
- `50ffaa26-5159-4804-accf-cdd1f92a997a` — `USDCHF.DWX`.

All three failed with `ONINIT_FAILED;INCOMPLETE_RUNS` against the old EX5
SHA-256 `61833c537bb10b731ea9c63717ccea8b720d91cf8c671fa469d2ebe06a313891`,
which predates their registered magic slots. The current governed artifact
identities remain:

- MQ5 SHA-256: `a2ab7f4f493be1528312f7b649febf7da0e61cebb504a60d0ec280c652fbbb66`;
- EX5 SHA-256: `bbd1786046941d20cb33f618bf1143c537058aad14f900ede5dcb6428fa1b0b3`;
- current-binary Q02 proof: work item
  `5599a328-80cf-465d-bcf1-b4fbfc54843a`, `AUDUSD.DWX`, `PASS`.

## Binding CPU stop

Immediately before any contemplated append-only Q02 mutation, five one-second
whole-host CPU samples were taken:

`98.83%, 99.03%, 88.40%, 88.97%, 95.51%`

Average: `94.15%`. Maximum: `99.03%`. The maximum exceeded the binding
`97%` ceiling, so the operation stopped.

No `requalify-q02 --apply`, enqueue-compile command, compile, smoke test,
dispatcher tick, tester launch, terminal stop, or farm DB mutation was run.
Because no source was written and no compile enqueue was contemplated after
the CPU stop, the PACER source-pin command was not required or run in this
turn. The prior durable handoff records its zero-finding audit and three
eligible dry runs; those checks must be repeated when capacity is available.

## Next bounded action

On a later paced turn, first confirm the same repair claim and absence of
Q02/Q03/COMPILE_EA successors, then require a fresh five-sample CPU maximum
below 97%. Re-run the absolute-path framework-input-pin audit and all three
`requalify-q02 --dry-run` validations. If each remains eligible with zero
parameter changes, append exactly one current-binary Q02 successor for each
failed identity and complete the repair task.

No T_Live path or process, AutoTrading setting, portfolio gate, deploy
manifest, strategy parameter, setfile, registry row, or certification verdict
was touched.
