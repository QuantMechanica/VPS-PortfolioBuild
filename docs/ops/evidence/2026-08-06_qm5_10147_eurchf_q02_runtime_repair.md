# QM5_10147 EURCHF Q02 runtime repair

Date: 2026-08-06 (Europe/Berlin)
Branch: `agents/board-advisor`
EA: `QM5_10147_tii-momentum`
Target canary: `EURCHF.DWX`, D1
Farm claim: `a647d84f-4761-442c-934d-b44c0d27c57c`

## Selection and non-duplication

The nominal approved-card build backlog contained no genuinely unbuilt,
constraint-qualified diversity candidate: the remaining rows were already
built/pipelined zombie tasks or lacked the required DWX history. The mission
therefore moved to priority 2.

`QM5_10147` was selected as an unclaimed rare-FX recovery because:

- its approved card is
  `D:\QM\strategy_farm\artifacts\cards_approved\QM5_10147_tii-momentum.md`
  (`g0_status: APPROVED`, R1-R4 all PASS, no ML/grid/martingale);
- the strategy is a closed-bar D1 TII state machine with an expected cadence
  of 10 trades/year/symbol;
- all backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`;
- the EA has no Q03 or later work-item lineage; and
- there was no open work item, dirty EA path, or competing agent claim when
  the atomic claim was taken.

The claim transaction created the pre-mutation backup:
`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_10147_q02_runtime_claim_20260805T230043Z.sqlite`.

## Failure evidence

Source Q02 work item:
`14111248-8316-4caa-8a0c-66b1075f9871`.

- Symbol/timeframe: `EURCHF.DWX`, D1.
- Terminal outcome: `failed / INFRA_FAIL` after two retries.
- Three terminal cohorts (T9, T4, and T2) produced invalid `BARS_ZERO`
  reports; the final bound run was reaped at 0% progress as
  `ACTIVE_TIMEOUT / NO_FORWARD_PROGRESS`.
- The source row was bound to the old binary
  `dcb983ffbe16a850bacc83117a9c1cb5ad4b97282fea6004fd425d798deabd5c`.
- There is no economic Q02 verdict to preserve and no downstream result for
  this EA.

## Root cause and repair

The former implementation calculated current and previous TII separately on
every completed bar. Each calculation looped over 60 historical closes and
called `QM_SMA` for every close. At the default period this created 120
framework indicator reads per D1 bar, or well over 100,000 reads over the Q02
window. The spread filter also called `QM_ATR` on every tick. This is consistent
with the repeated no-forward-progress infrastructure outcome.

The repair preserves the approved TII formula and thresholds while changing
only the computation/lifecycle shape:

- one `CopyClose` cache of `2 * period` closed bars is populated per new bar;
- rolling SMA sums derive both shift-1 and shift-2 TII values in O(period)
  without per-history-bar indicator handles;
- ATR used by the spread guard is cached once per completed bar;
- `QM_IsNewBar()` is consumed once and the cached state is reused by exits and
  entries;
- Q08 MAE sampling is now the first `OnTick` statement, management/source
  exits run before the central news entry gate, same-tick exit/re-entry is
  blocked, and the entry request is zero-initialized.

No entry/exit threshold, risk amount, symbol slot, timeframe, optimization
parameter, or source mechanic was changed.

## Verification

- Rolling-window equivalence: PASS for periods 2, 3, 10, 60, and 90 at both
  TII offsets; numerical difference was below `1e-10` versus the former
  nested-SMA definition.
- SPEC validation: `PASS 1/1`.
- Framework build check: PASS, 0 failures, 0 warnings.
  Report:
  `D:\QM\reports\framework\21\build_check_20260805_230306.json`.
- Strict MetaEditor compile: PASS, 0 errors, 0 warnings.
  Log:
  `C:\QM\repo\framework\build\compile\20260805_230306\QM5_10147_tii-momentum.compile.log`.
- Current MQ5 SHA-256:
  `a767f02c2ed31f90e2d8233fdf0cfb23a9a8c4314c7734e942fef65f3e650741`.
- Current EX5 SHA-256:
  `12fd25c63ef5aafcd6cfea88ebf76c193c8a95e0bedc5d25935113e19fbfcb2e`.
- EURCHF fixed-risk setfile SHA-256:
  `ef7e3dee6a76a6253e2f39f7fb762abb0d289a548ce7a468af0f5514b07e8ba1`.
- The rebuilt EX5 and the 37 mechanically rebound fixed-risk setfiles were
  captured by artifact commit `90a103333879495c507c55ee2d0cd3d31d9e4d3b`.

No smoke test or pipeline phase was launched.

## CPU ceiling stop and queue handoff

At the enqueue gate the farm had 10 active work items and all 10 managed test
terminals T1-T10 were running, above the operating ceiling of 7. Per the paced
fleet instruction, the EURCHF rerun was not enqueued and no additional tester
process was started.

When managed terminal use is below the ceiling, the exact append-only handoff
is ready as follows (recheck the EA claim/open-row guards immediately before
executing):

```powershell
python tools/strategy_farm/farmctl.py enqueue-backtest `
  --ea QM5_10147 `
  --phase Q02 `
  --from-work-item-id 14111248-8316-4caa-8a0c-66b1075f9871 `
  --append-only-rerun-of 14111248-8316-4caa-8a0c-66b1075f9871 `
  --rerun-reason "Q02 runtime hot path removed; approved TII mechanics preserved; single EURCHF diversity canary" `
  --expected-current-ex5-sha256 12fd25c63ef5aafcd6cfea88ebf76c193c8a95e0bedc5d25935113e19fbfcb2e
```

Historical Q02 evidence remains append-only. T_Live, AutoTrading, the
portfolio gate, and the deploy manifest were not touched.
