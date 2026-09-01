# T11/T12 activation v2 — Orchestrator attempt and safe rollback

- Task: `d7919623-bae4-445f-888c-00f2a3e058ca`
- Recorded: `2026-09-01T20:19:08Z`
- Branch: `agents/board-advisor`
- Review closed: `2026-09-01T19:45:40Z`, `APPROVED`
- Base validator commit: `a5554860e23e3f0760ab41473a69d00613ae96f9`
- Ramp-compatibility repair commit: `47c1200f55a59921367b157d822b8a1926ca623a`
- Verdict: `SAFE_DEFER_V2_VALIDATED_RUNTIME_RELOAD_REQUIRED_V1_RESTORED`

## Outcome

The reviewed v2 activation receipt was atomically installed for verification.
It validates in a fresh process with internal activation SHA-256
`ce4b39612cbc6c96d86d59d3329b6e503f935e0a325eb99117166a1080cfd661`
and exact runner set T1-T12. The temporary installed file was byte-identical to the
reviewed candidate and has file SHA-256
`d9cf950130616a5cba3fab135a73a10637fe1b624f6950b523514ed2be670db5`.

The final health pass proved that resident T1-T10 worker processes still held
the pre-repair Python module in memory. They continued to reject the v1 ramp
against v2 and automatically refreshed fail-closed containment. Restarting or
reloading those workers is outside this task's authority. The authorized,
byte-identical v1 rollback receipt was therefore atomically restored. Final
active state is v1, internal activation SHA-256
`61c8c72ccb0cb8038ae6ece7b89aa68f602b1637d8bc6b6c866f38492139134e`,
with its original limit-10 ramp valid again.

This cycle did not ignite either canary. T11 and T12 remain in
`disabled_terminals.txt`. No terminal or worker process was started or stopped,
and containment was never cleared or weakened.

## Fail-closed compatibility defect found during ceremony

The first live preflight found that an earlier post-review attempt had already
failed closed and rolled back before this cycle:

- containment had automatically engaged at `2026-09-01T19:50:26.065283Z`
  with reason `custom_history_gate_exception:CustomHistoryGateError`;
- the v1 activation and the T11/T12 disabled-policy rows had been restored at
  `2026-09-01T19:50:44Z`;
- `terminal_worker_T11.log` recorded PID 23604 starting at 19:45Z, then
  `ramp activation binding mismatch`, followed by the v1
  `terminal_not_in_activation` hold after rollback;
- no T11/T12 process was present when this cycle inspected or completed the
  installation.

The code-level root cause was a narrow contract mismatch. The v2 activation validator was
exact-set and hash-valid, but `validate_ramp()` still required the active
activation hash to equal the v1 ramp hash. The unchanged governed ramp receipt
is deliberately bound to the byte-identical v1 base activation, so every
worker failed before topology audit as soon as v2 became active.

The second operational constraint, observed only after installation, is module
lifetime: the resident workers imported the old validator before commit
`47c1200f55`. A fresh interpreter accepts the inherited base ramp, but an
already-running interpreter cannot see that repair without an authorized worker
reload. Its repeated `ramp activation binding mismatch` messages are the reason
for the safe rollback, not a hash or exact-set failure in the candidate.

Commit `47c1200f55` repairs only that seam:

1. A validated v2 activation may inherit its hash-bound v1 base ramp with the
   exact T1-T10 order and original governed limits.
2. A newly minted v2 ramp binds the v2 activation directly, requires the exact
   T1-T12 order, and admits governed limits 11 and 12 for a later staged
   canary ceremony.
3. Any unrelated activation hash, malformed terminal order, or invalid limit
   remains fail-closed.

## Immutable state and hash checks

| Item | Pre-install | Temporary install | Final state |
|---|---|---|---|
| Active activation file | `0089c8b613a1181ff4d2304a9b2d7102da5445e6f7e9970841739dd5533f3672` (v1) | `d9cf950130616a5cba3fab135a73a10637fe1b624f6950b523514ed2be670db5` (v2) | `0089c8b613a1181ff4d2304a9b2d7102da5445e6f7e9970841739dd5533f3672` (v1 restored) |
| Containment mode | enabled | enabled; automatically refreshed by old workers | enabled; never manually edited or cleared |
| Disabled-terminal file | `5af124b9494bf8c1391765fddb5462b963b61abbb973eebbdcb14d810c72aa3d` | same | same; exact rows T11, T12 |
| Existing ramp file | `2c2bf6e8db6ddac3e0f9b7f49976d6c12117eb0b2559f95d6006015f41a284e0` | same | same; v1-bound limit 10 valid |
| Rollback receipt | `0089c8b613a1181ff4d2304a9b2d7102da5445e6f7e9970841739dd5533f3672` | unchanged | successfully restored byte-for-byte |

The containment state differs from the earlier review handoff because of the
failed attempts. This cycle did not clear, rewrite, or weaken it. At
`2026-09-01T20:18:47.854185Z` it remained `enabled: true`, source
`automatic_stop_condition`, reason
`custom_history_gate_exception:CustomHistoryGateError`. Its hash changed only
through automatic stop-condition refreshes by resident workers.

## Focused verification

```text
python -m pytest -q tools/strategy_farm/tests/test_custom_history_activation_v2.py tools/strategy_farm/tests/test_custom_history_variant_a.py tools/strategy_farm/tests/test_custom_history_copy_on_claim.py
30 passed in 6.95s
```

`python -m py_compile` passed for the gate and v2 test module. `git diff
--check` passed apart from informational LF/CRLF warnings.

Fresh-process real-artifact verification during the temporary installation produced:

```text
ACTIVE_VALID qm.custom-history-isolation-activation/v2 ce4b39612cbc6c96d86d59d3329b6e503f935e0a325eb99117166a1080cfd661 T1,...,T12
RAMP_VALID 61c8c72ccb0cb8038ae6ece7b89aa68f602b1637d8bc6b6c866f38492139134e 10 T1,...,T10
T11_GATE status=PASS_ISOLATED reason=custom_history_ramp_hold admission_allowed=false
T12_GATE status=PASS_ISOLATED reason=custom_history_ramp_hold admission_allowed=false
NO_T11_T12_PROCESS_HITS
```

Resident-worker log verification then produced repeated:

```text
CustomHistoryGateError('ramp activation binding mismatch')
```

Final rollback verification produced:

```text
ACTIVE_VALID qm.custom-history-isolation-activation/v1 61c8c72ccb0cb8038ae6ece7b89aa68f602b1637d8bc6b6c866f38492139134e
RAMP_VALID 61c8c72ccb0cb8038ae6ece7b89aa68f602b1637d8bc6b6c866f38492139134e 10
```

## Rollback and next boundary

The v1 receipt at
`C:\QM\repo\docs\ops\evidence\2026-09-01_d7919623_custom_history_activation_v1_rollback.json`
remains byte-identical to the pre-install active receipt. It was atomically
restored with `custom_history_gate.write_activation()` while retaining T11/T12
in the disabled policy.

V2 must not be reinstalled until review accepts commit `47c1200f55` and an
OWNER-authorized stopped/reload ceremony can ensure every resident worker loads
that code (or a separately reviewed bridge-ramp design is supplied). The later
canary sequence remains ramp 11, then ramp 12; this handoff authorizes neither
worker reload nor canary ignition.
