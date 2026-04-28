# QUA-414 Liveness Continuation — 2026-04-28

Action completed for run-liveness continuation:
- Added canonical Pipeline-Operator 36-symbol matrix dispatch snippet to `framework/scripts/README.md`.

Included in snippet:
- 36-symbol `.DWX` matrix payload template
- `--event start` matrix dispatch command
- `--event complete` PASS/FAIL completion command pattern
- explicit `--next-strategy-unblocked` fail-path example
- expected state location: `phase_matrix_index["<ea_id>_<version>_<phase>"]`

Verification:
- `rg -n "Pipeline-Op Matrix Dispatch|matrix_36.json|next-strategy-unblocked" framework/scripts/README.md`
- Matches found at lines 25, 44, 48, 71.

Next action:
- If required for closeout, commit the QUA-414 touched files and post closeout comment with commit hash.
