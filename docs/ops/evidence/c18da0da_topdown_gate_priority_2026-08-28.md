# Top-down gate-priority selector — implementation evidence

Date: 2026-08-28  
Router task: `c18da0da-184e-48d8-8340-2bf4844e8e70`  
OWNER decision: `OWNER-DEC-TOPDOWN-PRIORITY-20260828`  
Decision file SHA-256: `781ee98be8931c645a25863f39787081d1a5a82f9df1cdaf2a0f26fa48d03f2b`

## Verdict

PASS for implementation and review. Activation was intentionally not performed.

`pending_claim_order_sql()` now has a strict highest-gate-first ordering behind
`QM_TOPDOWN_GATE_PRIORITY_ENABLED=1`. The flag is default OFF: absent, `0`, or
any value other than the exact string `1` retains the incumbent age-weighted
selector behavior.

With the flag ON, the order inside the existing universe/recovery boundaries is:

1. `priority_track=true` emergency work before ordinary work;
2. optimization work (`Q12`–`Q14` and `OPT_CENSUS`), plus the existing short
   compile/harness unblockers;
3. `Q11`;
4. `Q10` executable roles;
5. `Q09` down through `Q02`, strictly descending;
6. existing age, basket, diagnostic, winner, asset, and timestamp tie-breakers
   within a gate tier.

No gate criterion, verdict path, hold, cap, recovery throttle, history guard,
or resource guard changed. The existing claim loop continues after a candidate
is rejected by a hold/cap/resource constraint, so a lower gate fills the slot
when higher work is not currently claimable (the OWNER utilization clause).
The phase-age health checks were not changed.

## Focused verification

Commands:

```powershell
python -m py_compile tools/strategy_farm/farmctl.py tools/strategy_farm/tests/test_ultracode_wsa_claim.py
python -m pytest tools/strategy_farm/tests/test_ultracode_wsa_claim.py -q -k "TopDownGatePrioritySelectorTests or topdown_longrun_cap_falls_through"
python -m pytest tools/strategy_farm/tests/test_ultracode_wsa_claim.py tools/strategy_farm/tests/test_opt_census_dispatch.py tools/strategy_farm/tests/test_pending_superseded_claim_filter.py -q
```

Results:

- focused: `5 passed, 29 deselected`;
- selector/regression cohort: `55 passed`;
- syntax compile: PASS;
- `git diff --check`: PASS.

Coverage includes flag OFF, strict rank despite extreme Q02 age, the
`priority_track` emergency override, active-hold fall-through, and the real
`terminal_worker.claim_atomic` path falling from a capped Q10 row to a claimable
Q09 row.

## Read-only real-queue simulation

Database opened with SQLite URI `mode=ro`:
`D:/QM/strategy_farm/state/farm_state.sqlite`.

Snapshot result:

| Selector | Claimable rows | First row | Top-100 phase mix |
|---|---:|---|---|
| Flag OFF | 4,287 | priority Q02 `3420d430` / `QM5_20060` | Q02: 1, OPT_CENSUS: 99 |
| Flag ON | 4,287 | priority OPT_CENSUS `6ba1f20b` / `QM5_41097` | OPT_CENSUS: 100 |

The candidate set is identical (4,287 rows); only ordering changes. On the real
snapshot, strict top-down ordering removes the aged priority-Q02 row from the
head because the optimization rows are themselves priority-track work. No row
was claimed or mutated during this simulation.

## Restart-window activation checklist

- [ ] OWNER/Orchestrator reviews this commit and the 55-test receipt.
- [ ] Confirm no active T1–T10 backtest will be interrupted; wait for the
  governed restart window.
- [ ] Set `QM_TOPDOWN_GATE_PRIORITY_ENABLED=1` in the environment inherited by
  the canonical terminal-worker scheduled path. Do not launch `terminal64.exe`.
- [ ] Restart only the worker daemons through the governed scheduler path.
- [ ] Confirm a new worker reports the flag as enabled and run the same
  read-only selector preview; optimization must head ordinary work.
- [ ] Observe the first claims: capped/held high-gate rows must fall through and
  no terminal may idle while any lower-gate row is claimable.
- [ ] Leave age-health thresholds and every gate criterion unchanged.
- [ ] Rollback: remove/unset the flag and restart worker daemons in a governed
  window; the incumbent selector is restored without a code rollback.

