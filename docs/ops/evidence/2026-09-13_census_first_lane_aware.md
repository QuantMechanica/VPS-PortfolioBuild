# CENSUS-FIRST lane-aware claimability

Task: `c07b8653-29c2-408e-b4e2-038bcd56b394`

`_opt_census_cells_claimable_in_txn` retains its legacy pending-row EXISTS
answer unless `QM_CENSUS_FIRST_LANE_AWARE=1`. When enabled, it uses the same
transaction-local active census snapshot, `effective_limits(K,L,G)`, and
same-program allow-list already computed by `claim_atomic`. It returns true
only for a pending, unheld, unsuperseded cell whose global cell slot, program
slot, per-program lane and exact arm lane are free. It opens no second SQLite
connection while the claim transaction is held.

The fixture reproduces the reported starvation shape: three active programs,
L=1, G=3 and 500 pending cells belonging to those programs. Legacy mode says
census work exists and defers a 12 GB heavy row at 27 GB free RAM. Lane-aware
mode says no cell can claim and admits the heavy row. Removing one active
program makes the predicate true again.

Verification:

```text
python -m pytest -q tools/strategy_farm/tests/test_terminal_worker_census_first_ram_priority.py
20 passed

python -m pytest -q tools/strategy_farm/tests/test_terminal_worker_census_first_ram_priority.py tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py
118 passed, 4 failed (pre-existing SH-3 fixture taxonomy mismatch outside this change)
```

The switch is Default-OFF. No deferral band, RAM reservation, K/L/G cap,
allow-list value, verdict, or pipeline phase changed. Activation remains an
operator action through the separately governed staggered reload.

RESULT task=c07b8653 default_off=true legacy_defer=true lane_aware_defer=false tests=20 verdict=IMPLEMENTATION_PASS
