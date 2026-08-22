# QM5_20211 FX cointegration Q05 active CPU stop

Date: 2026-08-22 Europe/Berlin (`2026-08-22T05:02:24Z`)

Branch: `agents/board-advisor`

Status: the sole rank-31 Q05 successor advanced from pending to active on T1;
stopped at the explicit backtest CPU ceiling without queue or terminal mutation

## Outcome

No new Strategy Card or EA was created. The durable sign-aware reconciliation
in commit `a80493291` already covers all 66 relationships from the frozen
`analyze_cross_asset_v3.py --include-negative-hedges` scan. Creating another
Card, registry allocation, basket manifest, EA, or Q02 row would duplicate
governed work.

The preferred anchors are not blocked at Q02 by ONINIT or NO_HISTORY:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 PASS and Q04 PASS, then Q05
  FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 PASS, then Q04 FAIL.

The allowed existing-card fallback is frozen-scan rank 31,
`GBPJPY.DWX` / `EURAUD.DWX`, implemented once as
`QM5_20211_gbpjpy-euraud`. It retains logical Q02 PASS and Q04 PASS. Commit
`9ea2bfd68` appended exactly one Q05 successor. The canonical farm has now
claimed that same row on T1:

| Field | Value |
|---|---|
| Work item | `b240acaa-15b2-4850-a615-3a80d770cb60` |
| Logical basket | `QM5_20211_GBPJPY_EURAUD_COINTEGRATION_D1` |
| Exact Q05 row count | 1 |
| Previous committed state | pending, unclaimed |
| Current state | active, claimed by T1 |
| Attempt count | 0 |
| Created | `2026-08-22T00:17:29Z` |
| Activated / updated | `2026-08-22T05:00:58Z` |

No duplicate enqueue, requeue, priority mutation, timestamp restamp, dispatch
tick, or terminal-control action was performed by this run.

## Package and risk binding

The approved Card remains G0 APPROVED with R1-R4 PASS. Its structural,
fixed-beta method is backed by the OWNER-ratified Tier-A Chan extraction and
the OWNER-requested Darwinex D1 scan. It remains low-frequency and contains no
ML, grid, martingale, online refit, or rescue filter.

The canonical backtest setfile still binds:

```text
RISK_FIXED=1000
RISK_PERCENT=0
PORTFOLIO_WEIGHT=1
```

Fresh SHA-256 checks matched the original Q05 enqueue record for the EA source,
EX5, basket manifest, logical backtest setfile, and approved Card. No governed
package artifact or execution contract changed.

The active worker concurrently materialized the untracked Q05 stress setfile
`QM5_20211_gbpjpy-euraud_QM5_20211_GBPJPY_EURAUD_COINTEGRATION_D1_D1_q05_stress_medium.set`.
It was left untouched and unstaged, as were all unrelated pre-existing
worktree changes.

## Binding capacity stop

Five whole-host CPU samples were `97%`, `94%`, `96%`, `29%`, and `54%`.
Their average was 74.0%, but the 97% maximum reached the explicit 97% hard
ceiling under the `average_or_maximum_gte_hard_ceiling` rule.

At `2026-08-22T05:02:24Z`, the canonical farm had three active rows: one Q05,
one Q07, and one Q09_NEWS. The supported path-aware slot view observed factory
terminal processes on T3 and T10. The Q05 row was claimed by T1 and a T1
custom-history admission reservation was visible, although no T1 terminal
process was present in that instantaneous slot snapshot. `T_Live` and the
unrelated FTMO terminal were observed only to exclude them; neither was
controlled.

Per the mission stop condition, no further enqueue, queue mutation, dispatch,
tester launch, terminal reservation, reconciliation, interruption, or control
followed.

Machine-readable evidence:
`artifacts/fx_cointegration_qm5_20211_q05_active_hard_cpu_stop_20260822T050224Z_board_advisor.json`.

## Safety

- No portfolio admission, portfolio KPI, or Q08 contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Card, EA, EX5, setfile, basket manifest, registry, or magic row changed.
- Concurrent unrelated worktree and worker-created changes remain unstaged.
