# WINSWEEP Stage-B tooling — REVIEW

Task: `fc926dde-c7c7-4b8b-bc72-b354909ea062`  
Canonical checkout: `C:/QM/repo`, branch `agents/board-advisor`.

## Result

`tools/strategy_farm/window_sweep.py` now provides the sealed Stage-B path.
It refuses unless the Stage-A surface is complete and bound to the existing
declaration. From that report it derives exactly its deterministic top five,
then plans 210 annual cells: five windows × exit `{15,16,17,19,20,21}` × seven
years. The original 420-cell ledger remains immutable; Stage B is a single
hash-bound append-only amendment containing the Stage-A report path/SHA-256,
top-five identity, rendered-set SHA-256 values, and all 210 deterministic
UUIDv5 cells.

Each Stage-B payload retains the existing OPT_CENSUS evidence, source/binary,
setfile, symbol, period and annual-window bindings. Its only rendered input
change relative to the selected Stage-A window is `strategy_exit_hour`.
`enqueue --stage B` is idempotent; `--apply` is still subject to the existing
canonical-worker freshness gate. No Stage-B apply was attempted.

Stage-A reports now expose `refutation_verdict` (`H-WIN KEPT` or `H-WIN
REFUTED`) plus winner/baseline OOS costed return-to-max-DD and pooled costed PF.
`report --stage B` evaluates the exit-axis plateau (only adjacent tested exit
points), the OOS check, and the sealed final rule: select Stage B only on both
OOS confirmation and at least `1.10` × the Stage-A winner's plateau DEV score;
otherwise the Stage-A winner at exit 18 stands.

## Focused verification

```text
python -m pytest -q tools/strategy_farm/tests/test_window_sweep.py \
  tools/strategy_farm/tests/test_claim_order_memo.py \
  tools/strategy_farm/tests/test_set_dl089_queue_order.py
43 passed
```

The added temporary-DB test proves: Stage-A ledger prerequisite; 210 Stage-B
rows inserted on first apply and zero on repeat; amendment/report SHA binding;
and worker-side ledger authentication. A synthetic-surface test proves the
exit-axis plateau/tie rule and that exit 18 remains when the 1.10 threshold is
not met. The existing incomplete-report test proves refusal before any enqueue.

## Production dry-run/refusal evidence

At 2026-09-10 21:xxZ, the current Stage-A surface contained 349 `MEASURED`, one
active, and 70 pending cells (148 missing/unusable as reported at the latest
surface pass). The guarded command:

```text
python C:/QM/repo/tools/strategy_farm/window_sweep.py enqueue --stage B \
  --stage-a-report C:/QM/repo/docs/ops/evidence/2026-09-09_window_sweep_surface.json
```

returned, without touching the DB or artifact ledger:

```json
{"ok": false, "error": "stage-A report incomplete or wrong declaration"}
```

This is the required documented refusal. The orchestrator, not this ticket,
may later adjudicate a complete Stage A and decide whether to run an apply.
