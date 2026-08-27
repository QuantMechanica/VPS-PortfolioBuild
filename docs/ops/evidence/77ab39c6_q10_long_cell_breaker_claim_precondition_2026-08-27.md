# Q10 long-cell breaker v2 — active-claim precondition and dry-run retrospective

- Router task: `77ab39c6-c2e4-4b86-be36-46f304f63db7`
- Predecessor evidence: `docs/ops/evidence/2026-08-27_q10_long_cell_breaker_activation_proposal.md`
- Executed: 2026-08-27 from canonical checkout `C:/QM/repo`, branch
  `agents/board-advisor`
- Scope: dry-run-only repair. No Scheduled Task was installed or changed, no
  `--apply` run was made, no terminal was started/stopped, and no pipeline
  verdict was written.

## Result

The false-positive path is closed in two places:

1. `read_active_q10_parents()` now admits only `status='active'` parents with a
   non-empty `claimed_by` and a valid timezone-bearing
   `payload_json.claimed_at_iso`. Pending/released rows are not breaker input.
2. Cell run-dir, `inputs.set`, and cell-directory mtimes are accepted as a
   wall-time start only when they fall within that current claim. An old plan
   mtime cannot make a newly claimed parent appear days old.

The kill switch remains `QM_DISABLE_Q10_LONG_CELL_BREAKER=1`, read on every
run. `--apply` remains opt-in; the default remains dry-run.

## Seven-day retrospective v2

Frozen source:
`D:/QM/reports/state/q10_long_cell_breaker_7day_retro.json`, generated
`2026-08-27T10:05:19Z`, SHA-256
`028570b7bbdf96489443f1a96f8fc7c83c725ac139a2a197b25f4755e73653d1`.
The predecessor cross-join classified the 62 legacy breaches into 54
never-claimed false positives, 3 active genuine candidates, and 5 released
ambiguous rows. Replaying that classification through the v2 admission rule
gives:

| Frozen class | Legacy breaches | v2 breaker-eligible | Pending false positives after fix | v2 disposition |
|---|---:|---:|---:|---|
| Never claimed / no active holder | 54 | 0 | **0** | Excluded before artifact timing |
| Active holder + active claim time | 3 | 3 | 0 | Genuine breaker population |
| Prior attempt, holder released | 5 | 0 | 0 | Excluded; stale-debris cleanup/forensics only |
| **Total** | **62** | **3** | **0** | 59 non-current rows cannot receive a breaker hold |

The three genuine rows in the frozen snapshot were `a0694aa0` (`QM5_10848`),
`205e5aef` (`QM5_10938`), and `ac59fa26` (`QM5_10692`). The five ambiguous
released rows cross-checked from the retained DB claim metadata were
`d00ee295`, `5f1b3b71`, `1e3b7aa9`, `ce9d7a9e`, and `f350a252`. They remain
observable evidence but are deliberately outside the live hold path.

## Fresh governed dry-run

Command:

```powershell
python tools/strategy_farm/q10_long_cell_breaker.py --json --no-state
```

At `2026-08-27T12:07:32Z` the fixed runner saw exactly three currently active,
claimed parents (`T6`, `T3`, `T10`), all with valid claim stamps. Result:

| Metric | Value |
|---|---:|
| Parents scanned | 3 |
| Parents breached | 0 |
| Holds written | 0 |
| Existing active `Q10_LONG_CELL_BREAKER` holds after run | 0 |

This was read-only (`--apply` omitted and `--no-state` supplied). It did not
interrupt or alter any active Q10 run.

## Focused verification

```text
python -m pytest tools/strategy_farm/tests/test_q10_long_cell_breaker.py -q
................................. [100%]
33 passed in 6.89s

python -m py_compile tools/strategy_farm/q10_long_cell_breaker.py
PASS

git diff --check -- tools/strategy_farm/q10_long_cell_breaker.py \
  tools/strategy_farm/tests/test_q10_long_cell_breaker.py \
  docs/ops/evidence/77ab39c6_q10_long_cell_breaker_claim_precondition_2026-08-27.md
PASS
```

Coverage added for never-claimed pending exclusion, missing claim-holder/time
exclusion, pre-claim `inputs.set` rejection, within-claim fallback timing, hold
behavior after worker release, dry-run no-write, and kill-switch no-write.

## Activation checklist v2 (not executed by this ticket)

1. [x] Land active-holder + active-claim-time admission and current-claim mtime
   boundary.
2. [x] Focused tests and a live governed dry-run show zero pending false
   positives and zero writes.
3. [ ] Orchestrator reviews this packet and explicitly authorizes any scheduler
   change; this ticket does not authorize activation.
4. [ ] If authorized, run the canonical command without `--apply` for a full
   24-hour observation window and archive each dry-run sidecar/summary.
5. [ ] Confirm pending/released rows remain absent and decide the separate
   cleanup path for the five ambiguous stale-debris cases.
6. [ ] Confirm the operator runbook records the immediate kill switch
   `QM_DISABLE_Q10_LONG_CELL_BREAKER=1` and hold-release procedure.
7. [ ] Only after review, change the governed schedule to `--apply`; observe
   `q10_long_cell_breaker_holds` for at least the existing six-hour escalation
   window. A hold is not a pipeline verdict.

## Verdict

**READY_FOR_ORCHESTRATOR_REVIEW; ACTIVATION REMAINS OFF.** The implementation
removes the 87% false-positive class by construction, retains the documented
kill switch, and leaves production behavior unchanged until a separately
authorized scheduler activation.
