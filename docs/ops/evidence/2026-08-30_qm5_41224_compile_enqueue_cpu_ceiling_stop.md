# QM5_41224 governed compile enqueue — CPU ceiling stop

Date: 2026-08-30 UTC

Branch: `agents/board-advisor`

Farm build task: `ff4d22ef-de6d-49f1-83ac-80d62b4b810b`

Outcome: **ONE SOURCE-BOUND COMPILE ITEM CREATED AND LEFT ACTIVATION-HELD;
THE 97% CPU WALL STOPPED THE WAKE BEFORE RELEASE, COMPILE, OR Q02**

## Diversity selection

The current canonical scorer placed
`QM5_41224_wti-samecal-regimeshift` first among the claimable compliant build
backlog (`score=1010.31`, `priority_track=true`). The higher raw-diversity NNFX
candidate was not compliant with this mission's structural and reputable-source
constraint. The otherwise suitable peer-reviewed GBPUSD month-end card
`QM5_41143` had no required magic row and therefore failed the build-only skill
precondition without mutation.

`QM5_41224` is a direct `XTIUSD.DWX` D1 carrier beyond the certified book's
index, metal, and XNG concentration. It is structural and low-frequency: at a
normalized month transition it compares the exact recent five and older five
same-calendar WTI returns, trades only when their arithmetic means have strict
opposite signs, and follows the recent block. Stable-sign or incomplete
histories consume the month flat.

The reputable lineage is Keloharju, Linnainmaa, and Nyberg (2016), *Return
Seasonalities*, *Journal of Finance* 71(4), DOI `10.1111/jofi.12398`, plus
Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*, *Journal of
Financial Economics* 104(2), DOI `10.1016/j.jfineco.2011.11.003`. Neither paper
is represented as testing the exact five/five chronological reversal rule or
the Darwinex WTI CFD translation.

## Preflight and identity

The existing implementation remained clean at commit
`86b5852ee4eea4a84167cd65af2a6242fb8e0ecf`. No strategy source, card, SPEC,
setfile, registry, magic row, or resolver was changed in this wake.

Fresh deterministic checks returned:

- exact same-calendar reference fixture: 11 tests PASS;
- build-skill identity guard: PASS;
- SPEC validator: PASS;
- build guardrails: PASS with zero findings;
- build-gate hardening: PASS with zero failures and zero warnings;
- EA registry: active `41224` / `wti-samecal-regimeshift`;
- magic registry: active slot 0 / `XTIUSD.DWX` / `412240000`;
- fixed-risk preset: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

The runtime approved card and the repository mirror differ only in the
informational `r1_track_record` and `r1_reasoning` fields; the mechanical
contract is identical. Runtime-card SHA-256 is
`a3bdbf819f5acd9d22550b2703ad87655fc202280d4498087bd91356b138c9c9`;
repository-card SHA-256 is
`6a266965f7cf089e610ef4be6fa4aa34a7fd892bbf8a15699c344555ed72efc4`.

The remaining build identities are:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `fede16790ec29627b6c38415f6db95ec0146c9a312789ff5645240014769b2d5` |
| SPEC | `575f674b73486a3e674f8cb0a07371d7412d031fe20fa1a72399c6dcfd2631a4` |
| Backtest setfile | `d63212d34f8fd376095b1a036932fdb3147711f45101f7ef4a7f1e9c0ed28fc3` |

## Atomic farm coordination

The existing task was CAS-claimed as
`build:QM5_41224:ff4d22ef-de6d-49f1-83ac-80d62b4b810b` by
`codex:agents/board-advisor` at `2026-08-30T17:56:25.971129Z`. The transaction
confirmed exactly one open build task and zero work items for this EA.

The protected pre-claim online database backup is:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_41224_compile_claim_20260830T175422Z_e8c68d0d.sqlite`

It contains `734773248` bytes, has SHA-256
`10186d18c890569d632460d5ea9a9ff7a473e4ca49507e58c8320488d9570e13`,
and returned `integrity_check=ok`.

The supported build-task-bound enqueue command created exactly one compile
item:

- work item: `7b947ba4-f327-4eb2-af86-a0333e27de6a`;
- phase/status: `COMPILE_EA` / `pending`;
- expected MQ5 SHA-256:
  `fede16790ec29627b6c38415f6db95ec0146c9a312789ff5645240014769b2d5`;
- activation hold: `COMPILE_EA_WORKER_ROLLOUT_PENDING`, active;
- attempt: 0; claimed terminal: none; evidence: none.

The hold was not released, so no resident worker could compile the EA. This is
a non-duplicate advance over the two earlier QM5_41224 capacity stops, both of
which ended before a compile item existed.

## Binding CPU stop

Two admission windows were clear:

- `2026-08-30T17:46:26.8550827Z`: average `78.866866%`, maximum
  `86.767157%`;
- `2026-08-30T17:53:47.0129126Z`: average `89.337695%`, maximum
  `92.661446%`.

The mandatory immediate pre-release window ended at
`2026-08-30T17:58:09.5502038Z` with samples:

`70.818455%, 78.268472%, 79.699893%, 85.555632%, 97.461201%`

Average was `82.360731%`; maximum was `97.461201%`. The paced-fleet contract
stops when either measure reaches `97%`, so the peak bound before compile-hold
release.

The exact claim was CAS-released at `2026-08-30T17:58:45.827618Z`. Readback
shows the build task pending with no active claim, the compile item still
pending and held, and zero Q02 rows.

## Resume point and safety boundary

A later paced worker must first take a fresh five-sample CPU window whose
average and maximum are both strictly below `97%`. It may then atomically
reclaim the same build task, run a target-only dry run and apply of
`tools/strategy_farm/release_compile_wave.py` for exact work item
`7b947ba4-f327-4eb2-af86-a0333e27de6a`, require source-bound `COMPILE_OK`, and
only then record the build so the farm creates the sole fixed-risk Q02 row.

No ad-hoc compiler, tester, dispatcher, terminal reservation, terminal
start/stop, AutoTrading toggle, portfolio gate, `T_Live` path, deploy manifest,
certification state, or Q02 row was touched.

Machine-readable receipt:
`artifacts/qm5_41224_compile_enqueue_cpu_stop_20260830T175809Z_board_advisor.json`.
