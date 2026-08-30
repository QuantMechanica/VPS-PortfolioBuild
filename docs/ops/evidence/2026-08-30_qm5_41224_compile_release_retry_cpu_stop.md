# QM5_41224 governed compile release retry — CPU ceiling stop

Date: 2026-08-30 UTC

Branch: `agents/board-advisor`

Farm build task: `ff4d22ef-de6d-49f1-83ac-80d62b4b810b`

Outcome: **THE SOURCE-BOUND COMPILE RELEASE WAS READY, BUT THE FRESH HOST
WINDOW PEAKED AT 98.245%; THE HOLD REMAINS ACTIVE AND Q02 WAS NOT ENQUEUED**

## Diversity and collision control

`QM5_41224_wti-samecal-regimeshift` remained the highest-diversity compliant
claimable build candidate after excluding non-structural, already-built, and
invalid-task-binding alternatives. It is a structural D1 WTI sleeve on
`XTIUSD.DWX`, beyond the certified book's index, metal, and XNG concentration.
The strategy compares exact recent-five and older-five same-calendar-year WTI
return means, requires strict opposite signs, and follows the recent block.

The sole open build task was atomically claimed by
`codex:agents/board-advisor` at `2026-08-30T22:09:28.037876+00:00`. It was
already bound to exactly one pending, unclaimed compile work item:
`7b947ba4-f327-4eb2-af86-a0333e27de6a`. Other paced-agent EAs and unrelated
worktree changes were not touched.

The protected pre-claim online database backup is:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_41224_compile_release_claim_20260830T220928Z_422a74a3.sqlite`

It has `734773248` bytes, SHA-256
`e57a8f3bb80735d8251a320ac52e3f678e6eeef6f64954d3888719b848b4bb5f`,
and returned `integrity_check=ok`.

## Deterministic preflight

The existing approved implementation remained byte-identical. Fresh checks
returned:

- same-calendar reference fixture: 11/11 PASS;
- build-skill identity guard: PASS;
- SPEC validator: 1/1 PASS;
- build guardrails: PASS with zero findings;
- build-gate hardening: PASS with zero failures and zero warnings;
- symbol-scope validator: `SINGLE_SYMBOL_OK`;
- fixed-risk preset: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

The target-only release dry run selected exactly the held item, deferred none,
and matched actual and expected MQ5 SHA-256:
`fede16790ec29627b6c38415f6db95ec0146c9a312789ff5645240014769b2d5`.

Other stable artifact identities are:

| Artifact | SHA-256 |
|---|---|
| Approved runtime card | `a3bdbf819f5acd9d22550b2703ad87655fc202280d4498087bd91356b138c9c9` |
| SPEC | `575f674b73486a3e674f8cb0a07371d7412d031fe20fa1a72399c6dcfd2631a4` |
| Fixed-risk backtest setfile | `d63212d34f8fd376095b1a036932fdb3147711f45101f7ef4a7f1e9c0ed28fc3` |

## Binding CPU stop

The initial admission window ended at `2026-08-30T22:07:51.1433199Z` with
average `95.732502%` and maximum `96.388903%`, both strictly below the `97%`
ceiling.

The mandatory immediate pre-release window ended at
`2026-08-30T22:13:17.3977897Z` with samples:

`94.766740%, 96.887808%, 98.245025%, 93.460984%, 93.389890%`

Average was `95.350090%`; maximum was `98.245025%`. Because either measure at
or above `97%` binds, the maximum stopped the unit before the apply command.
The activation hold was never released, so no resident worker could compile or
consume backtest capacity.

## Atomic release and resume point

The exact build-task claim was CAS-released at
`2026-08-30T22:14:49.496935+00:00`. Post-release readback confirms:

- build task `pending`, with no active claim key or claimant;
- compile item `pending`, unclaimed, attempt 0, no verdict or evidence;
- activation hold `COMPILE_EA_WORKER_ROLLOUT_PENDING` still active;
- no EX5 and zero Q02 rows.

A future paced worker may reclaim the same build task only after a fresh
five-sample host window has both average and maximum strictly below `97%`.
It should rerun the target-only release dry run, then release only work item
`7b947ba4-f327-4eb2-af86-a0333e27de6a` through
`tools/strategy_farm/release_compile_wave.py`. It must wait for source-bound
`COMPILE_OK` before recording the build and creating the sole fixed-risk Q02
row.

No strategy source, setfile, registry, compiler, tester, dispatcher, terminal
reservation, terminal process, AutoTrading setting, portfolio gate, `T_Live`
path, deploy manifest, or certification state was changed.

Machine-readable receipt:
`artifacts/qm5_41224_compile_release_retry_cpu_stop_20260830T221317Z_board_advisor.json`.
