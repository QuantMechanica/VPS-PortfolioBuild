# T11 research-canary launch path — readiness hand-back

Task: `63398c6b-d8e1-458b-a8fb-08cb4ab83d7e` (P90).

**Verdict:** `REVIEW — DEVIATION_NO_GOVERNED_S3_LAUNCH`.

## Completed prerequisite

`D:/QM/mt5/T11/Bases/symbols.custom.dat` was absent.  It was created only after
the two independent authenticated fleet copies agreed, and was verified after
copy.  Neither source was modified.

| Source | SHA-256 | Bytes |
|---|---|---:|
| `D:/QM/mt5/T1/Bases/symbols.custom.dat` | `6be56cd376afac7fb69bb6b30f24781f1d21e96b34bddc5b6c7e1e4f7ac09d65` | 20,480 |
| `D:/QM/mt5/T10/Bases/symbols.custom.dat` | `6be56cd376afac7fb69bb6b30f24781f1d21e96b34bddc5b6c7e1e4f7ac09d65` | 20,480 |
| `D:/QM/mt5/T11/Bases/symbols.custom.dat` after copy | `6be56cd376afac7fb69bb6b30f24781f1d21e96b34bddc5b6c7e1e4f7ac09d65` | 20,480 |

The existing `custom_history_contract.load_manifest` and
`custom_history_copy_on_claim._verified_private_identity` verifier passed the
T11-private `USDJPY.DWX` 2017–2025 archive projection: 108 files,
1,152,847,891 bytes, signed manifest
`fe0dd0fdd90dc26b806044c82fd0d7c35af889a96cbd4d79dece9cfdac3aab06`.
The verification checks every selected file's SHA-256 and size, rejects a
family hardlink, and requires link count one.  This covers the requested
2019–2025 data plus the manifest's earlier USDJPY files.

## Fail-closed launch boundary

The production Custom-history activation at
`D:/QM/strategy_farm/state/custom_history_isolation_activation.json` binds
only T1–T10.  `custom_history_gate.run_worker_gate(..., terminal='T11')`
therefore returns `FAIL_CLOSED / terminal_not_in_activation`.  This is correct:
no work-item claim, factory mutation lock, or state-DB write is permitted for
this research task.  T11 and T12 remain in
`D:/QM/strategy_farm/state/disabled_terminals.txt`.

No governed `research_canary` controller exists yet that simultaneously:

- confines reports to `D:/QM/reports/research/<program>/`;
- preserves zero `work_items` and state-DB writes;
- enforces the requested continuous CPU/RAM/MetaTester-agent guards;
- binds the tester defaults and an evidenced commission schedule; and
- launches MT5 through an existing governed command surface without invoking
  `terminal64.exe` manually.

Accordingly no S3 smoke cell was started.  There is no claim of matching
`QM5_41398` fleet metrics, trades, or report hash.  The existing
`custom_history_smoke_admission.py` cannot be repurposed: it deliberately
requires an active worker-bound work item under the signed T1–T10 activation.

## Isolation record and hand-back

No T11 worker was enabled or restarted; T_Live, FTMO terminals, AutoTrading,
EA source/binaries, queue rows, verdicts, counters and gates were untouched.
The catalog repair resolves the named ASTRA prerequisite, but does not reopen
`b48ba1fb` until a reviewed canary controller produces a real Model-4 receipt
and exact fleet-cell comparison.  T12 remains declared but disabled fallback.
