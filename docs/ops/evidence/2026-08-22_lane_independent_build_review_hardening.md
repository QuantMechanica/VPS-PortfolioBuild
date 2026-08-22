# Lane-independent build REVIEW hardening

Date: 2026-08-22  
Router task: `6a131ec6-e9f1-44f2-b161-d83edff08e0f`  
Disposition: implementation complete; leave in `REVIEW`

## Finding

Before this change, `agent_router.update_task` invoked the canonical
`_build_review_dispatch_gate` only when all three conditions were true:

```text
task_type == build_ea
assigned_agent == gemini
requested state == REVIEW
```

The defect was latent but real. A Codex-assigned `build_ea` row could claim a
producer PASS and transition to REVIEW without the router recomputing strict
hardening against the hash-bound canonical MQ5.

## Why the original condition was Gemini-only

Commit `43fea65f3` was an emergency prevention written at the Gemini defect's
discovery point. Its evidence and commit message explicitly describe the path
as "before a Gemini task is allowed to mint an independent Codex review." The
condition at the call site combined two different concerns:

1. every build must pass the defect-class gate before REVIEW; and
2. only a Gemini build mints an additional independent Codex `review_ea` row.

The second concern is legitimately Gemini-specific. The first is not. No
technical property of D3-D10, the MQ5 bytes, or `build_ea` makes those defects
lane-specific. The restriction was therefore a consequence of where the
emergency was found, not a substantive exemption for Codex.

## Artifact-shape check

Successful build identity packets use the same core fields regardless of
producer: `build_check_passed`, MQ5 path/hash, EX5 path/hash, and generated
setfiles. Codex hold packets can be incomplete by design when compilation was
not authorized or did not produce an EX5. Those packets normally declare
`build_check_passed=false` and remain a correct D1 refusal.

There was nevertheless an ordering problem for a false producer PASS: the old
gate validated both MQ5 and EX5 identity before it ran hardening. A Codex-style
packet with a real source defect but incomplete final binary identity would
stop at `D6_BUILD_IDENTITY_MISSING`, never reaching the substantive source
check.

The gate now validates and hashes the MQ5 first, recomputes canonical hardening
on those exact bytes, and only then validates EX5, clean-at-HEAD identity, and
setfiles. A defective source is therefore refused for
`D3_D10_BUILD_GATE_HARDENING_FAIL`; a clean source with an incomplete packet
still fails closed at D6. No D3-D10 predicate or threshold changed.

## Change

- The `update_task` gate condition is now exactly `build_ea` plus requested
  state `REVIEW`; it no longer inspects `assigned_agent`.
- Gemini-only creation of the independent `review_ea` task remains unchanged.
- Hash/path validation was factored into one helper to retain the existing D6
  codes and exact-byte comparison.
- Canonical MQ5 hardening now precedes final binary/setfile packet validation.
- The refusal continues to be recorded as `review_dispatch_refused`, and the
  task remains in its pre-transition state.

## Proof by producer lane

The existing Gemini negative fixture still claims PASS while omitting the MAE
hook. It is rejected with `D3_D10_BUILD_GATE_HARDENING_FAIL` and
`EA_Q08_MAE_HOOK_MISSING`.

The new Codex negative fixture makes the same false claim and deliberately
omits final EX5 identity, matching the relevant packet-shape concern. It is
also rejected with `D3_D10_BUILD_GATE_HARDENING_FAIL` and the MAE finding,
proving that D6 no longer hides the substantive defect.

The new Codex positive fixture binds committed MQ5/EX5/setfile bytes, passes
canonical hardening, and transitions to REVIEW. It does not mint a redundant
Codex review task.

Focused router tests:

```text
6 passed, 26 deselected in 36.45s
```

Complete router module:

```text
python -m pytest tools/strategy_farm/tests/test_agent_router.py -q --tb=short
................................                                         [100%]
32 passed in 315.43s (0:05:15)
```

Adjacent strict-hardening, state-exit, stale-release, and canonical-writer
suites:

```text
...............................................                          [100%]
47 passed in 486.63s (0:08:06)
```

Python byte compilation and `git diff --check` passed.

## Real clean-source control

The canonical analyzer was also run read-only against
`QM5_1612_aa-dsp-hplwma10`, commit `9fb5ad806`, MQ5 SHA-256
`b33a94addfe2c85ed3a8607aaeedd6a2c2305f1f045059857f5095eabefc824e`.
It returned zero failures and zero warnings across D2-D11, including the
complete 13-symbol registry/setfile matrix. This is a real-source control that
the scope change does not manufacture false hardening failures.

No EA was compiled, no registry or gate criterion was changed, and no
`T_Live`, terminal, AutoTrading, verdict, or trade-stream state was touched.
