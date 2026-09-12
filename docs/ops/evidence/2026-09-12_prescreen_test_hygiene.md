# PRESCREEN follow-up test hygiene — 2026-09-12

Task: `b32462f2-6774-4eb6-9045-74a59c07f120`  
Disposition: **REVIEW — named suite green; test/fixture changes only**

## Result

The exact named baseline reproduced five failures across 98 tests. Each was
classified before editing; none justified weakening a production guard.

| Failure | Classification | Repair |
|---|---|---|
| `test_config_locked_q09_news_is_rebind_not_reusable` | stale verdict constant | Use the actual `SUPERSEDED` stale class. `CONFIG_LOCKED` is the ratified Q09 success verdict. |
| two `test_policy_disabled_*` cases | fixture leaked into the independent calendar-taint gate | Patch only the separately tested taint guard so these cases measure the long-run rollback switch. |
| `test_configure_connection_applies_short_busy_timeout` | environment-sensitive constant drift | Assert the configured `sqlite_busy.BUSY_TIMEOUT_MS`, not a literal 750 while the process is configured to 15000. |
| `test_topdown_longrun_cap_falls_through_to_next_gate` | phase-class drift | Use ordinary short Q06 as the fallback; Q09 is now correctly RAM-gated. |

The config-sweep promotion fixture proves the declared mandatory control arm
is retained even when it ranks last and therefore is outside the natural top
keep fraction. The same file also contains the append-only PRESCREEN rerun
fixture for the separately queued schema-recovery review; both are tests only.

No production behavior, queue row, terminal, worker, T_Live, AutoTrading,
phase verdict, threshold, or registry was changed.

## Verification

```text
python -m pytest -q \
  tools/strategy_farm/tests/test_config_sweep.py \
  tools/strategy_farm/tests/test_backfill_planner.py \
  tools/strategy_farm/tests/test_longrun_scheduling_policy.py \
  tools/strategy_farm/tests/test_sqlite_busy_retry.py \
  tools/strategy_farm/tests/test_ultracode_wsa_claim.py

98 passed in 25.77s
```
