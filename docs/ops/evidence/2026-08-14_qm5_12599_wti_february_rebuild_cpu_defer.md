# QM5_12599 WTI February framework rebuild and CPU defer

Date: 2026-08-14 (Europe/Berlin)

Branch: `agents/board-advisor`

## Outcome

`QM5_12599_wti-feb-prem` is an OWNER-approved, structural, low-frequency D1
WTI calendar sleeve sourced from Gorska and Krawiec (2015). Its current source
had exhausted automated review retries because it hand-rolled calendar cadence
from raw `iTime`, while three exact-bound Q02 runs each produced only one trade.

The EA now uses the V5 calendar helper and current lifecycle wiring. Q01 passes
strictly with zero compile errors and warnings. Q02 was not enqueued because the
paced tester fleet reached its CPU ceiling before the record boundary.

## Selection and farm claim

The mission-filtered backlog was screened for approved, low-frequency,
structural, reputable-source strategies on instruments that diversify the
index/metal/energy survivor concentration. Rates cards require unavailable DWX
inputs, the broad eligible FX alternatives had already reached and failed Q04,
and the remaining fresh FX row was an M5 high-frequency indicator stack.

`QM5_12599` was therefore the highest-value eligible row: a peer-reviewed D1
calendar mechanism on WTI, explicitly satisfying the energy-beyond-XNG lane.

- Build task: `eba2ee32-da67-477d-9cb7-7131b40c01ad`.
- Build generation: 2.
- Agent task: `a2460b52-0bfa-445d-bfcb-3fddad6a4519`.
- Claim owner: `codex:agents/board-advisor`.
- Claim key:
  `manual:codex:agents/board-advisor:QM5_12599:q01-build-rework-q02-handoff:20260814T102549Z`.
- Pre-claim online backup:
  `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12599_build_claim_20260814T102549Z.sqlite`.

The farm claim was recorded before repository mutation. At claim time there
was no other active agent task, build task, or pending/active work item for this
EA. The build task was set `active`, preventing automatic duplicate dispatch.

## Bound prior evidence

The last three Q02 rows all used the registered XTIUSD D1 setfile and real MT5
Model 4 execution over the full 2018-07-02 through 2022-12-31 window:

| Work item | Result | Trades | OnInit | Exact source/binary binding |
|---|---|---:|---|---|
| `c95aa425-2e4a-4141-8b97-931d4acc2089` | `MIN_TRADES_NOT_MET` | 1 | PASS | legacy evidence, real MT5 |
| `ebd5b796-c008-4b33-a16f-e3450173776e` | `MIN_TRADES_NOT_MET` | 1 | PASS | PASS |
| `254d0394-f5d0-471d-9a01-01fbc6607505` | `MIN_TRADES_NOT_MET` | 1 | PASS | PASS |

The latter two runs authenticated the same source, `.ex5`, and setfile hashes
before and after execution. They exclude ONINIT, missing history, report
generation, and stale deployment as the first failing layer. The remaining
failure was entry reachability/frequency on a July 2026 framework binary.

## Card-exact repair

- Replaced both raw D1 `iTime` reads with
  `QM_CalendarPeriodKey(PERIOD_D1)` and cached the key/month once per genuine
  D1 boundary.
- Primed `QM_IsNewBar()` in `OnInit` so an attach or restart inside an existing
  D1 bar cannot manufacture a calendar entry.
- Preserved the approved February-only long direction, one-D1-bar/month-end
  exit, one-calendar-day stale guard, ATR stop, spread cap, and one-position
  rule.
- Restored explicit first-statement Q08 MAE sampling, zero-initialized entry
  requests, and symbol-scoped close filtering.
- Added bounded registered `ENTRY_ATTEMPT`, `ENTRY_REJECTED`, and
  `ENTRY_SIGNAL_FIRE` events once per relevant D1 boundary. The next Q02 can
  identify calendar, position, spread, news, ATR, price, or stop rejection
  without another opaque one-trade result.

No signal threshold, month, direction, stop multiple, hold period, sizing, or
source mechanic changed.

## Q01 evidence

| Check | Result |
|---|---|
| Approved-card/registry/magic build guard | PASS |
| Embedded, canonical, approved, and farm card identity | exact SHA-256 match |
| Seven-section SPEC validation | PASS, 1/1 |
| Strict V5 build check | PASS, 0 failures, 0 warnings |
| Strict MetaEditor compile | PASS, 0 errors, 0 warnings |
| Backtest setfile risk | `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` |

- Build-check report:
  `D:/QM/reports/framework/21/build_check_20260814_103426.json`.
- Strict compile summary:
  `D:/QM/reports/compile/20260814_103540/summary.csv`.
- Strict compile log:
  `C:/QM/repo/framework/build/compile/20260814_103540/QM5_12599_wti-feb-prem.compile.log`.
- MQ5 SHA-256:
  `c692a2e36ac5155cbfb24069ef8f14b2321184fcbc479c3eda7df56a10329e34`.
- EX5 SHA-256:
  `e40ee4d97eec6656096d828c8cc0f08a7988a7e74d469e68d1562a00c82e4a60`.
- Setfile SHA-256:
  `a9d70beb8de318094ee161408fca8044fbf35a5602fc785e2a763d95e8816b1b`.

## Capacity stop and next action

At `2026-08-14T10:36:20Z`, all T1-T10 were occupied by ten active work items.
Three CPU samples were 97.1%, 97.8%, and 98.4% on 16 logical processors
(97.8% average). This is the paced-fleet backtest CPU ceiling.

No smoke, tester, terminal dispatch, worker tick, optimization, or backtest was
started by this unit. The governed build result is sealed at
`D:/QM/strategy_farm/artifacts/builds/eba2ee32-da67-477d-9cb7-7131b40c01ad.json`.

When capacity is below the ceiling, the next operator should independently
review this commit, clear the capacity hold, and record the immutable result:

```powershell
python tools/strategy_farm/farmctl.py record-build `
  --task-id eba2ee32-da67-477d-9cb7-7131b40c01ad `
  --result-file D:/QM/strategy_farm/artifacts/builds/eba2ee32-da67-477d-9cb7-7131b40c01ad.json
```

That supported recorder path should append one fresh Q02 item. The three prior
one-trade rows remain immutable history and must not be reused as proof for the
new binary.

## Safety boundary

- No `T_Live` file, live manifest, deploy manifest, portfolio gate, or
  portfolio-admission artifact was accessed or changed.
- AutoTrading was not toggled.
- No registry or framework include changed.
- The unrelated pre-existing working-tree files were left untouched.
