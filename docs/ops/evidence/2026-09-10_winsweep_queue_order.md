# WINSWEEP governed queue-order lever

Task: `ba63936d-b0a0-4f76-a2d9-71f911fd2c6c` (Codex, REVIEW)

## Result

`WINSWEEP_QM5_41398_USDJPY_DWX_2019_2025` now has an append-only,
non-dispatchable `WINDOW_SWEEP_OWNER` record.  It is deterministic
(`e144b67f-787d-5386-b7e7-9f070fb89a58`) and its payload has one mutable field:
`queue_order_at`.  Existing 420 sealed window-cell payloads are not changed.

With top-down selection enabled, `farmctl.pending_claim_order_sql()` reads the
owner timestamp only for `schema=qm.window-sweep.v1` and `program_id` beginning
`WINSWEEP_`.  All non-window rows retain their prior ordering keys.  A window
owner uses `status=done`, `verdict=DECLARED`, `kind=control`, and is therefore
not terminal-dispatchable.

`window_sweep.py` provides the governed operator interface:

```powershell
# one-time append-only registration; this does not alter any cell
python tools/strategy_farm/window_sweep.py queue-owner --apply

# plan before applying the OWNER-approved timestamp
python tools/strategy_farm/window_sweep.py queue-order plan `
  --queue-order-at '<approved ISO-8601 timestamp>' `
  --reason '<recorded reason>' --owner-decision '<recorded OWNER decision id>'

# apply: SQLite backup, CAS/revalidation, payload-only update, audit event
python tools/strategy_farm/window_sweep.py queue-order apply `
  --queue-order-at '<approved ISO-8601 timestamp>' `
  --reason '<recorded reason>' --owner-decision '<recorded OWNER decision id>'
```

The operator must first use the staggered idle-worker reload process. This
changes `farmctl.pending_claim_order_sql()`, which worker processes import; this
task does not restart workers. After the reload and lever application, inspect
`queue-order list` and the canonical claim order. No terminal, AutoTrading,
T_Live, backtest, gate, verdict, DL-089 rule, or existing row payload changed.

## Verification

`python -m pytest -q tools/strategy_farm/tests/test_claim_order_memo.py
tools/strategy_farm/tests/test_window_sweep.py
tools/strategy_farm/tests/test_set_dl089_queue_order.py`

Result: **41 passed**.

The new temporary-DB regression creates XAU and NDX frontier rows plus a
WINSWEEP cell. Before the lever, order is XAU, NDX, WINSWEEP. After an explicit
earlier owner timestamp it is WINSWEEP, XAU, NDX. It asserts the WINSWEEP cell
payload is byte-equivalent and the ordered-ID SHA-256 for all non-window rows is
identical before/after. Existing DL-089 queue-order tests and the sealed
window-sweep regressions also pass. The DL-089 plan generator was not edited.

## OWNER finding (proposal only)

USDJPY (asset rank 3) programs can be starved while XAU (0) and NDX (1) frontier
rows are continuously re-boosted under top-down selection. The governed lever
solves the immediate WINSWEEP admission problem, but not the general fairness
policy. Candidate OWNER decision: round-robin authenticated idle programs
before asset rank. Do not implement that policy without an OWNER decision.
