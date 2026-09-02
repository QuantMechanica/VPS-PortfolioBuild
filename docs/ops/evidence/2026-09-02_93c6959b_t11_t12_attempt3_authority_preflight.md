# T11/T12 attempt 3 — complete authority preflight and audit binding

- Task: `93c6959b-d051-47bf-b799-3bb1011d5b5f`
- Date: 2026-09-02
- Branch: `agents/board-advisor`
- Verdict: `PASS_REVIEW_READY_NO_LIVE_INSTALL`

## Outcome

Attempt 2 failed after a valid v2 activation and inherited limit-10 ramp because
the runtime file audit classified rows against the immutable archive manifest's
T1-T10 runner set.  A T12 private archive row therefore produced
`UNAUTHORIZED_RUNNER_TERMINAL`, and the worker correctly engaged containment.

The fix is append-only.  The original signed manifest and its OWNER approval
remain byte-identical.  A new content-addressed runner-audit authority binds the
original manifest, the byte-identical v1 activation, the existing OWNER T11/T12
extension, the exact T1-T12 runner set, the exact protected-root set, and the
Orchestrator countersign for factory-only staged ignition.  It explicitly does
not authorize live trading.

The v2 activation now requires that authority.  The runtime passes its validated
T1-T12 set to the file-inventory evaluator instead of letting the evaluator
silently fall back to the manifest's historical T1-T10 set.  With no extension,
the evaluator still treats the original manifest as the sole authority.

## Complete dependent-authority enumeration

| Authority or dependency | Runtime check | Attempt-3 preflight treatment |
|---|---|---|
| Active v1 activation bytes | `load_activation()` validates schema, activation hash, manifest, OWNER receipt, dual audits, and ACL evidence | Must be the candidate's byte-identical v1 base, including file hash |
| Candidate v2 activation | `validate_activation()` requires enabled/fail-closed mode, exact T1-T12, exact roots, and all transitive bindings | Fully validated before any write |
| Original archive manifest and OWNER approval | `load_manifest(..., require_owner_approval=True)` remains exact T1-T10 and binds the immutable file table | Original path, file hash, content hash, OWNER approval, and runner set are checked; file is never rewritten |
| OWNER T11/T12 extension | v2 validation checks exact task, directive, decision register, +7% measured condition, T1-T12, and internal/file hashes | Revalidated through both activation and new audit authority |
| Two original cutover audits | v2 validation requires distinct full-hash `PASS_ISOLATED` receipts for T1-T10 plus bound ACL evidence | Revalidated transitively; they remain historical base audits, not the extension authority |
| T11/T12 inert provisioning audits | v2 validation checks exact two terminals, disabled/inert facts, manifest hash, receipt/file hashes, and no activation/start | Revalidated transitively |
| New signed runner-audit authority | Runtime `_runtime_audit_runner_terminals()` resolves the exact T1-T12 set consumed by the file audit | Exact receipt/file/internal hashes, old-byte bindings, OWNER authority, Orchestrator countersign, extension set, roots, and no-live scope are checked |
| Protected roots | Activation binds the complete governed set; runtime excludes T11/T12 `Bases` only from the *foreign-root* comparison because those paths are already pairwise-audited runner roots | Both bound-root and runtime foreign-root sets must equal their exact governed sets |
| Install ramp | `load_ramp()` validates hash, activation binding, order, limit, and reason | Current inherited v1 limit-10 ramp must validate against v2 and must continue to hold T11/T12 |
| Rollback mode | If present, `load_rollback_mode()` requires candidate-activation, rollback receipt, OWNER receipt, and global-containment bindings; then the worker uses only the serialized rollback branch | Validated if present; absence is hash-bound as an explicit state fact. It was absent in this review snapshot |
| Containment mode | `custom_history_lease.load_mode()` validates its self-hash; when enabled it serializes claims. Worker exceptions or non-benign audit findings may create a new automatic receipt | Receipt is parsed, validated, and file-hash-bound. Existing containment does not substitute for another authority |
| Disabled-terminal policy | `farmctl.worker_policy_terminals()` removes listed terminals from the T1-T12 worker cohort | T11 and T12 must both remain disabled during activation installation |
| Post-ignition ramp | Later `load_ramp()` controls staged admission | Candidate must directly bind v2, use exact T1-T12 order, and have limit 12 |
| Topology evaluator | `evaluate_inventory()` compares the explicit runtime cohort pairwise and against foreign protected roots | Exact runtime runner and foreign-root sets are preflighted |
| Variant-A file evaluator | `evaluate_variant_a_file_inventory()` checks manifest equality, terminal completeness, private inode isolation, link counts, hashes, and runner authorization | Receives the same validated runner authority used by the worker gate; regression covers the exact T12 trip |
| Master repair and copy-on-claim | Both bind archive content to the original manifest; they do not independently grant a terminal admission | Covered as integrity consumers of the validated manifest, not terminal authorities |
| Worker containment trigger | `terminal_worker._custom_history_gate()` engages containment on exceptions or non-benign findings | The authority seam is eliminated before the first worker call; genuine later topology/content failures remain fail-closed |

The exhaustive source trace is in `custom_history_gate.py` at
`validate_rollback_mode`, `validate_ramp`, `validate_runner_audit_authority`,
`validate_activation`, `preflight_activation_install`,
`validate_activation_install_preflight`, `write_activation`,
`_runtime_protected_roots`, `_runtime_audit_runner_terminals`, and
`run_worker_gate`; in `mt5_history_isolation.py` at
`evaluate_variant_a_file_inventory` and `audit_history_isolation`; in
`custom_history_lease.py` at `validate_mode_receipt`, `load_mode`, and
`acquire_lease`; and in `terminal_worker.py` at `_custom_history_gate` and
`_custom_history_gate_fail_is_emergency`.

## Preflight guarantee

`custom_history_activation_preflight.py` is read-only.  It emits a self-hashed
receipt only after all authorities above validate.  A v2 call to
`write_activation()` now refuses without that receipt.  Immediately before the
atomic activation write, it regenerates the complete preflight body and requires
byte-for-byte equality with the receipt.  Any change to active activation, ramp,
rollback-mode presence/content, containment, disabled policy, runner authority,
or limit-12 ramp causes refusal and requires a new preflight.

Within that hash-bound unchanged snapshot, PASS guarantees that the first
post-install worker gate cannot self-trip from an authority-set mismatch: the
activation and the file evaluator consume the same signed T1-T12 set.  This is
not a waiver of real fail-closed conditions.  A later filesystem alias, missing
archive, corrupt content, ACL drift, or other state change can and must still
engage containment.

## Hash-bound review artifacts

| Artifact | File SHA-256 | Internal identity |
|---|---|---|
| `2026-09-02_93c6959b_t11_t12_runner_audit_authority.json` | `bbb19485daab855f52e549050e999cd494fb1a9b45bba5891da33859369d8430` | authority `1860d50587b729b2f5abddb6b22337dc494999194a232a8366c43df797308ea1` |
| `2026-09-02_93c6959b_custom_history_activation_v2_attempt3_candidate.json` | `119dde432b85434b5c9d940de904c33e3c0a5e5c10e2d6e724e22938576175ba` | activation `58799bfdddb5c5eed8f8d5912601e66b0fe5eca682b15ddbedd7e7f5f638760d` |
| `2026-09-02_93c6959b_custom_history_ramp_limit12_candidate.json` | `ebc83871f01b4420f51d117c256d713d73a753226861a87d9fe3441ea3acc365` | ramp `7c557264c6538fa463d8d4a45de654bc02de9492abfc7e6ca64e84a99038f6c8` |
| `2026-09-02_93c6959b_activation_attempt3_preflight_review_receipt.json` | `713e318bc39fa69797aa340f281a2dafa44c494c6befa2c7f75c796f8898072d` | preflight `f64f64371bbf29b45836f9a268245a88b5b896cf02530b9b849a3868a9861e70` |

Preserved old authority:

- original manifest content identity:
  `fe0dd0fdd90dc26b806044c82fd0d7c35af889a96cbd4d79dece9cfdac3aab06`;
- original manifest file SHA-256:
  `6e82b478a09a642a189f0da17edb6f83c35fe32a587b398c3250ed056919c634`;
- active/base v1 activation identity:
  `61c8c72ccb0cb8038ae6ece7b89aa68f602b1637d8bc6b6c866f38492139134e`;
- active/base v1 file SHA-256:
  `0089c8b613a1181ff4d2304a9b2d7102da5445e6f7e9970841739dd5533f3672`.

## Focused verification

```text
python -m pytest -q tools/strategy_farm/tests/test_custom_history_activation_v2.py
11 passed in 34.34s

python -m pytest -q tools/strategy_farm/tests/test_custom_history_variant_a.py tools/strategy_farm/tests/test_custom_history_copy_on_claim.py tools/strategy_farm/tests/test_mt5_history_isolation.py
50 passed in 8.13s
```

The regression constructs a valid private `ticks/XNGUSD.DWX/202001.tkc` row
for T12.  Under the original manifest-only authority it reproduces
`UNAUTHORIZED_RUNNER_TERMINAL`; under the bound T1-T12 extension, the exact
same inventory is `PASS_ISOLATED`.  Separate tests prove that a v2 write without
preflight is refused and that changing `disabled_terminals.txt` after preflight
invalidates the write.

`python -m py_compile` passed for both production modules, the read-only CLI,
and the focused test module.  `git diff --check` passed (only informational
LF/CRLF warnings).

## Preserved live state and next boundary

No activation, ramp, rollback, containment, disabled-terminal, worker, terminal,
T_Live, or AutoTrading state was written by this ticket.  The active activation
remained v1 with file SHA-256
`0089c8b613a1181ff4d2304a9b2d7102da5445e6f7e9970841739dd5533f3672`;
T11/T12 remained disabled.  At review preflight, containment was already
engaged by the separate reason
`custom_history_copy_on_claim_failure:CustomHistoryCopyOnClaimError`, mode
`c116a941abc4afb424f90243486a5c6b450099777dd4cf21f43f438230355ef6`.
It was not released or weakened here.

Attempt 3 is a separate reviewed operational ceremony.  It must rerun the
preflight immediately before the write, keep the initial limit-10 hold, use
fresh workers, and only then perform the separately authorized staged T11/T12
ignition.  The limit-12 candidate is for the post-ignition step, not the initial
activation write.
