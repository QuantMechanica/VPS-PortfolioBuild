# MNT-006 drain phase 2: deterministic wait disposition

Date: 2026-08-21  
Router task: `626975ca-2b3c-4a6b-8232-5b91c3703656`  
Branch: `agents/board-advisor`

The phase-two sequencing predicate is not satisfied. Read-only DB verification
found all three named row-one work items still `pending`, unclaimed, with no
terminal verdict or evidence path:

| Work item | EA / symbol | State |
|---|---|---|
| `cc347183-5365-427e-b815-3879639c0d42` | QM5_10505 / XAUUSD.DWX | pending |
| `6384b2f7-164b-4af6-b849-6184bde5ed2d` | QM5_11286 / NDX.DWX | pending |
| `256846e2-edce-4354-a346-0a428dafcc1b` | QM5_20096 / USDCHF.DWX | pending |

The third row also has a documented execution-identity defect: its payload binds
the omitted EX5 hash `531e8e75...`, while the current committed, clean rebuild is
`4a60bfcd...` (MNT-020 evidence commit `421159586`). It cannot be treated as a
reviewed canary result.

Per `GOVERNED_SINGLE_ROW_REQUEUE_AFTER_REVIEW`, no row-two candidate was
enqueued. A pending row is not a reviewed terminal disposition, and neither a
PASS nor a deterministic re-fail can be inferred. The three blocked-class
repairs/re-stagings also remain separate prerequisites; this pass did not weaken
their identity or repair-first checks.

Correct continuation:

1. allow the two identity-valid row-one canaries to reach real pipeline
   dispositions;
2. preserve the stale QM5_20096 pending row and create a governed successor
   bound to committed EX5 `4a60bfcd...` through an append-only repair path;
3. only after review, enqueue row two for a passing/non-deterministic class or
   stop the class on deterministic re-failure;
4. re-stage the ACTIVE_TIMEOUT/BARS_ZERO current identities through normal
   build/review and repair QM5_1196 logging before their first canaries.

No work item, verdict, terminal, setfile, binary, AutoTrading, or T_Live state
was changed by this phase-two check.
