# Risk-Freeze baseline refresh — fail-closed abort

Date: 2026-08-31  
Task: `ad560149-a2e3-43b5-9981-f6253226e3e4`  
Authority: `OWNER-DEC-RISK-FREEZE-BASELINE-REFRESH=YES`  
Verdict: **ABORTED WITHOUT WRITE — verification ambiguity**

## Outcome first

The local Risk-Freeze baseline was **not** re-armed. The bound plan requires
every current roster, risk, and provenance check to pass before the only
permitted write. The canonical deployed-repair verifier returned `FAIL` for
two of the ten source bindings, so `risk_freeze.py arm --force` was never run.

The existing freeze remains `ACTIVE` and reports `held=false` against its old
baseline, with the expected ten repaired preset-byte drifts still visible.
This task did not normalize those drifts away.

## Read-only checks

`verify_tlive_preset_repair.py --require-deployed` passed eight entries and
failed these two:

| EA | Current verifier findings |
|---|---|
| `QM5_12989_grimes-nested-pb-v2` | repo source SHA mismatch; repo-source `build_hash` mismatch; T_Live target matches neither the now-current repo source nor the pre-deploy SHA |
| `QM5_13128_pre-fomc-drift-ndx` | repo source SHA mismatch; repo-source `build_hash` mismatch; T_Live target matches neither the now-current repo source nor the pre-deploy SHA |

The explanation is later source evolution, not evidence that T_Live changed:
both source files were changed by commit
`1ccbdd4ab0e79177aaafce3ab1c8638e210cf4a8` on 2026-08-27. A separate
read-only historical check against repair commit
`e09749e60b070be2635b322f7aa3971a531aa7ff` found **10/10 PASS** for all four
immutable deploy bindings:

- historical source bytes equal the repair-manifest source SHA;
- T_Live target bytes equal the deploy-receipt target SHA;
- the T_Live companion binary equals the manifest build SHA;
- the deployed preset's `build_hash` header equals that companion binary.

That historical proof explains the two current-source failures, but it does
not turn the canonical current verifier's `FAIL` into a `PASS`. The plan says
to abort on ambiguity, not to replace a failed precondition with an ad-hoc
interpretation.

The complete current roster itself is coherent:

| Measurement | Result |
|---|---:|
| Presets | 24 |
| Unique companion binaries | 21 |
| Total `RISK_PERCENT` | 9.7499 |
| Non-zero `RISK_FIXED` presets | 0 |
| Preset inventory SHA-256 | `94ae0c1ae159b46aeb8d94a5037794e22d9e380f40b59b253909eae422aaace1` |
| Binary inventory SHA-256 | `fd61dc7a69667a2fa89ed3dd8963c888c554bacc0a07849511e3e39edacde357` |
| Combined inventory SHA-256 | `a92520c5a34c6aca82607a08a52d53449106c3e4cfb122f1cc8b2af248413bcc` |

A second ambiguity also remains in the write surface: the freeze state says
companion binaries are frozen, but `risk_freeze.measure()` stores preset
hashes only and `diff_against_baseline()` compares preset values/bytes only.
Re-arming through that command would not create a continuously verified binary
baseline. This task did not silently extend the schema or verifier while
executing an OWNER-bound operational plan.

## No-write proof

The measurements below were identical before and after the aborted refresh:

| Object | Before | After |
|---|---|---|
| `D:/QM/reports/state/live_risk_freeze.json` | `82695ac67a7342c5f9443d4625fc849c83a9358937e5a5736f6f20d68ced13e5` | same |
| 24-preset inventory | `94ae0c1ae159b46aeb8d94a5037794e22d9e380f40b59b253909eae422aaace1` | same |
| 21-binary inventory | `fd61dc7a69667a2fa89ed3dd8963c888c554bacc0a07849511e3e39edacde357` | same |
| Combined preset/binary inventory | `a92520c5a34c6aca82607a08a52d53449106c3e4cfb122f1cc8b2af248413bcc` | same |
| `terminal64.exe` binary | `86c563c8c113e4af8802dc91241ecd51fc06caf92cc86fc40026dd8046e526ed` | same |
| T_Live process | PID 19016, created 2026-08-23 10:28:59 +02:00 | same |

No T_Live preset, binary, chart, process, or configuration command was
executed. AutoTrading was not touched. The only writes from this task are this
canonical evidence document and its Git commit.

## Required follow-up before retry

Use a reviewed verification contract that authenticates deployed bytes against
the immutable deploy commit/receipt after repo sources evolve, and extend the
Risk-Freeze measurement/verifier to seal and continuously compare companion
binary hashes. Then re-run the full 10-binding and 24-roster preflight. Until
those checks produce an unambiguous PASS, the old baseline must remain intact.
