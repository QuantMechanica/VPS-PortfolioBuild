# Factory runtime activation — exact ten-worker policy source

Date: 2026-07-31

Router task: `9746d4d4-3cfc-407d-8f9d-6b9c33b46dc8`

OWNER authorization: ten factory workers, T1–T10, `disabled_terminals=[]`

Mode: source and test update only; **no Factory cycle and no decision mint**

## Result

The runtime-activation policy source, JSON template/schema, Factory_ON exact
cohort checks, and tests now require:

- `disabled_terminals = []`;
- `expected_worker_count = 10`;
- `expected_terminals = [T1, T2, T3, T4, T5, T6, T7, T8, T9, T10]`.

Validator semantics remain fail-closed. A nine-worker/T5-quarantine decision,
a non-empty disabled set, a missing expected terminal, a duplicate worker, or
a worker in the wrong session is rejected.

`D:\QM\strategy_farm\state\disabled_terminals.txt` was already absent and was
not created or touched. `Factory_ON.ps1` now interprets absence as the exact
empty disabled set, hashes that canonical empty byte sequence, and revalidates
the same identity under the mutation lock before launch and hold release. A
present policy containing T5 fails the exact-set gate.

## Source design

- `factory_runtime_activation.py` is the policy authority used by the fresh
  runtime-decision validator. Its exact expected dictionary remains hard
  validated; only the expected cohort changed.
- `factory_runtime_activation.v1.template.json` and its schema carry the same
  exact ten-worker constants.
- `Factory_ON.ps1` derives T1–T10 from the empty disabled set and demands an
  exact ten-worker cohort before mutation, for ALREADY_ON, after launch, and in
  the post-start health gate.
- The July 30 preparation decision remains byte-for-byte unchanged historical
  evidence. Its prior nine-worker/T5-quarantine metadata is validated against
  a separate preparation-only constant; it is not reused as the current
  runtime policy.
- `build_runtime_activation_decision.py` required no source change: it already
  copies `worker_policy` from the template and self-validates the candidate.
  A focused assertion now proves the built candidate inherits the exact new
  policy rather than a duplicated hard-coded value.
- `start_terminal_workers.py` required no source change: its existing absent
  or empty cap-file behavior already enables all installed T1–T10 terminals.
- `factory_restart_health.ps1` required no source change: it validates the
  exact caller-supplied terminal set and derives its expected count from that
  set.

## Runtime-decision-bound files changed

Exactly two of the 12 `SOURCE_BINDING_PATHS` files changed. The Sunday
runtime-decision rebind must bind their new commit identities:

| Binding role | Relative path | Commit-blob SHA-256 | Git blob |
|---|---|---|---|
| `factory_on` | `tools/strategy_farm/Factory_ON.ps1` | `d464ce548ee364b42218da489e69c1f8b768dcb0fbd548fe69b8cd4582e1bb16` | `85bd0a82bf43f00bde43b910ef747ee43db42a51` |
| `runtime_activation_validator` | `tools/strategy_farm/factory_runtime_activation.py` | `382bc54436bafb72067bace8a27eeb24be964ef55a9971494a38e94c33735e8d` | `78fbca9c9b9de7249c093e3c968cfdb539bf2842` |

Supporting contract/test files changed but are not members of the 12-source
binding map:

- `factory_runtime_activation.v1.template.json`;
- `factory_runtime_activation.v1.schema.json`;
- `test_factory_runtime_activation.py`;
- `test_build_runtime_activation_decision.py`;
- `test_factory_restart_post_start_health.py`.

Source commit: `81317fa4c` (`ops: authorize exact ten-worker factory policy`).

## Verification

- Runtime activation validator: `16 passed`.
- Decision builder: `6 passed`.
- Factory restart/health policy: `17 passed`.
- Supplemental Factory ON/OFF, lock, restore, quiescence, and live-scope
  regressions: `57 passed`.
- `Factory_ON.ps1` PowerShell parse: PASS.
- Template and schema strict JSON parse: PASS.
- Absent-file empty-policy and present-T5 rejection harness: PASS.

No Factory_OFF/Factory_ON invocation, runtime/preparation decision artifact,
scheduled task, flag, database row, worker process, terminal, T_Live,
AutoTrading state, or pipeline verdict was created or changed. A fresh
OWNER-bound runtime decision remains mandatory before the next Factory ON.
