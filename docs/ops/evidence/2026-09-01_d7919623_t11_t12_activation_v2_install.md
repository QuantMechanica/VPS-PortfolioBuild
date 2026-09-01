# T11/T12 activation v2 — Orchestrator install handoff

- Task: `d7919623-bae4-445f-888c-00f2a3e058ca`
- Recorded: `2026-09-01T20:11:01Z`
- Branch: `agents/board-advisor`
- Review closed: `2026-09-01T19:45:40Z`, `APPROVED`
- Base validator commit: `a5554860e23e3f0760ab41473a69d00613ae96f9`
- Ramp-compatibility repair commit: `47c1200f55a59921367b157d822b8a1926ca623a`
- Verdict: `PASS_ACTIVATION_V2_INSTALLED_CANARIES_HELD`

## Outcome

The reviewed v2 activation receipt was atomically installed at
`D:\QM\strategy_farm\state\custom_history_isolation_activation.json`.
It validates with internal activation SHA-256
`ce4b39612cbc6c96d86d59d3329b6e503f935e0a325eb99117166a1080cfd661`
and exact runner set T1-T12. The installed file is byte-identical to the
reviewed candidate and has file SHA-256
`d9cf950130616a5cba3fab135a73a10637fe1b624f6950b523514ed2be670db5`.

This cycle did not ignite either canary. T11 and T12 remain in
`disabled_terminals.txt`; the inherited ramp remains at limit 10; direct gate
checks return `custom_history_ramp_hold` and `admission_allowed: false` for both
canaries. No terminal or worker process was started or stopped.

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

Root cause was a narrow contract mismatch. The v2 activation validator was
exact-set and hash-valid, but `validate_ramp()` still required the active
activation hash to equal the v1 ramp hash. The unchanged governed ramp receipt
is deliberately bound to the byte-identical v1 base activation, so every
worker failed before topology audit as soon as v2 became active.

Commit `47c1200f55` repairs only that seam:

1. A validated v2 activation may inherit its hash-bound v1 base ramp with the
   exact T1-T10 order and original governed limits.
2. A newly minted v2 ramp binds the v2 activation directly, requires the exact
   T1-T12 order, and admits governed limits 11 and 12 for a later staged
   canary ceremony.
3. Any unrelated activation hash, malformed terminal order, or invalid limit
   remains fail-closed.

## Immutable state and hash checks

| Item | Pre-install | Post-install | Result |
|---|---|---|---|
| Active activation file | `0089c8b613a1181ff4d2304a9b2d7102da5445e6f7e9970841739dd5533f3672` (v1) | `d9cf950130616a5cba3fab135a73a10637fe1b624f6950b523514ed2be670db5` (v2) | intended atomic replacement |
| Containment mode file | `9d0097cde040c5e519c3c0ba585b3c5f93d1a8ea7262b787f71863dfe99cd81a` | same | byte-untouched; remains enabled |
| Disabled-terminal file | `5af124b9494bf8c1391765fddb5462b963b61abbb973eebbdcb14d810c72aa3d` | same | byte-untouched; exact rows T11, T12 |
| Existing ramp file | `2c2bf6e8db6ddac3e0f9b7f49976d6c12117eb0b2559f95d6006015f41a284e0` | same | byte-untouched; limit 10 |
| Rollback receipt | `0089c8b613a1181ff4d2304a9b2d7102da5445e6f7e9970841739dd5533f3672` | same | v1 rollback remains restorable |

The containment state differs from the earlier review handoff because of the
failed attempt at 19:50Z. This cycle did not clear, rewrite, or weaken it. Its
current mode remains `enabled: true`, source `automatic_stop_condition`, mode
SHA-256 `fe5dbbb75a836f3ce68c4589e4632a9d6d337fe11306f5235f350740bab7dcc7`.

## Focused verification

```text
python -m pytest -q tools/strategy_farm/tests/test_custom_history_activation_v2.py tools/strategy_farm/tests/test_custom_history_variant_a.py tools/strategy_farm/tests/test_custom_history_copy_on_claim.py
30 passed in 6.95s
```

`python -m py_compile` passed for the gate and v2 test module. `git diff
--check` passed apart from informational LF/CRLF warnings.

Real-artifact verification after installation produced:

```text
ACTIVE_VALID qm.custom-history-isolation-activation/v2 ce4b39612cbc6c96d86d59d3329b6e503f935e0a325eb99117166a1080cfd661 T1,...,T12
RAMP_VALID 61c8c72ccb0cb8038ae6ece7b89aa68f602b1637d8bc6b6c866f38492139134e 10 T1,...,T10
T11_GATE status=PASS_ISOLATED reason=custom_history_ramp_hold admission_allowed=false
T12_GATE status=PASS_ISOLATED reason=custom_history_ramp_hold admission_allowed=false
NO_T11_T12_PROCESS_HITS
```

## Rollback

The v1 receipt at
`C:\QM\repo\docs\ops\evidence\2026-09-01_d7919623_custom_history_activation_v1_rollback.json`
remains byte-identical to the pre-install active receipt. An authorized rollback
can atomically restore it with `custom_history_gate.write_activation()` while
retaining T11/T12 in the disabled policy. No rollback was required after this
installation.
