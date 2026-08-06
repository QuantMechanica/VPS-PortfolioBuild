# QM5_10286 EURJPY Q02 infrastructure recovery handoff

Date: 2026-08-06

Branch: `agents/board-advisor`

Agent task: `0035013b-f66a-445a-bb6c-14466f88c63f`

## Outcome

`QM5_10286_cinar-supertrend` on `EURJPY.DWX` is the highest-value non-duplicate diverse-instrument recovery found after the build-task claim guard rejected every remaining build-backlog row as terminal, already active, excluded, missing its card, or mechanically blocked.

The prior Q02 result is an infrastructure-only cold-cache failure. The recovery was deliberately not enqueued because the factory was already at the backtest CPU ceiling: Windows reported 99% CPU, all T1-T8 terminals were running work, and 10 `terminal64` processes were present at `2026-08-06T08:45:25Z`. Adding a pending row while workers were polling could have launched another test immediately. No MT5 process was started, stopped, or modified.

The claim is returned to `BACKLOG` unassigned with this artifact so a later paced agent can enqueue the exact append-only rerun when capacity is available.

## Selection and collision guard

- Instrument diversity: `EURJPY.DWX`, a JPY cross absent from the index/metal/energy-heavy Q08 survivor set.
- Strategy: approved, structural D1 SuperTrend stop-and-reverse; no ML or banned indicator dependency.
- Approved card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_10286_cinar-supertrend.md` (`g0_status: APPROVED`; R1-R4 PASS; exact public GitHub source recorded).
- Expected frequency: 20 trades/year from the approved card, above the Q02 floor while remaining low-frequency.
- Before claiming, the farm DB had no pending/active work item for `QM5_10286` and no open agent task referencing it.
- The claim was inserted under `BEGIN IMMEDIATE` after repeating both collision checks. Pre-change backup: `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_10286_q02_recovery_20260806T084422Z.sqlite`.

## Bound failure diagnosis

Source work item: `3ccc88e6-c17b-4317-993d-93d8dc8ae9f7`

Evidence: `D:\QM\reports\work_items\3ccc88e6-c17b-4317-993d-93d8dc8ae9f7\QM5_10286\20260728_092743\summary.json`

The source row is `Q02 / failed / INFRA_FAIL` after three cold-cache attempts. Each run produced `BARS_ZERO` with empty expert/symbol logs and the final reason `cold_cache_retries_exhausted:BARS_ZERO`. The evidence reports:

- binary deployment and source binding matched and remained stable;
- setfile binding matched and remained stable;
- Model 4 marker present;
- no `OnInit` failure;
- no log bomb;
- news status OK.

Current artifacts still match the failed work item's expected bindings exactly:

| Artifact | SHA-256 |
| --- | --- |
| `QM5_10286_cinar-supertrend.mq5` | `c526193c85700bd696ed1c234164ac344eb8a1b141c1777d2a3c67791c2d09ca` |
| `QM5_10286_cinar-supertrend.ex5` | `f895bcd791a74c73e5f572f80cab82f5f1cea6658e7cad3ee6c56ac8d71aafd4` |
| `QM5_10286_cinar-supertrend_EURJPY.DWX_D1_backtest.set` | `4de5518d1d8f4fda0a49b34883c30b55db3fbf16992495a7f3e3ea5232947ad3` |

The setfile remains backtest-safe with `RISK_FIXED=1000` and `RISK_PERCENT=0`. The EA directory was clean before this handoff. There is no stale `.ex5`, set drift, source drift, or EA initialization defect to repair, so changing or recompiling the EA would invalidate a known-good evidence binding without addressing the failure. Per the operating rule for `NO_HISTORY`/cold-cache failures, history was not re-imported.

## Next paced action

When CPU and terminal capacity are below the ceiling, enqueue one append-only Q02 rerun from the canonical checkout, bound to the current binary:

```powershell
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_10286_cinar-supertrend --phase Q02 --append-only-rerun-of 3ccc88e6-c17b-4317-993d-93d8dc8ae9f7 --rerun-reason "diversity_recovery: EURJPY.DWX prior Q02 exhausted cold-cache retries with BARS_ZERO; exact binary/source/set binding verified; no history re-import" --expected-current-ex5-sha256 f895bcd791a74c73e5f572f80cab82f5f1cea6658e7cad3ee6c56ac8d71aafd4
```

Do not run a manual smoke, dispatch the item directly, or re-import history. Let the paced factory claim it when a terminal slot and CPU headroom are available.

## Safety boundary

No portfolio gate, T_Live manifest, T_Live configuration, or AutoTrading state was read for mutation or changed. No backtest was launched. The only repository change is this evidence handoff.
