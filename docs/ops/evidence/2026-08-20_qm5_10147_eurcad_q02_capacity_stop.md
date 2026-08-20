# QM5_10147 EURCAD Q02 stale-binary recovery capacity stop

Date: 2026-08-20 (Europe/Berlin)

Branch: `agents/board-advisor`

## Outcome

No farm claim, build, enqueue, backtest, dispatch, or terminal action was
performed. The host CPU ceiling was already saturated, so the paced-fleet stop
condition took precedence.

The next distinct diversity recovery candidate is the `EURCAD.DWX` D1 row for
`QM5_10147_tii-momentum`. This is not the previously completed `EURCHF.DWX`
canary.

## Selection and non-duplication

The approved-card build backlog had no unclaimed, buildable forex, crypto,
rates, beyond-XNG energy, or market-neutral card. The apparent fresh entries
were either already claimed/built or durably blocked by absent `.DWX` history.

Priority 2 therefore identified the terminal Q02 work item
`44023000-f837-4323-be2e-442c353ca2e8`:

- EA/symbol/timeframe: `QM5_10147` / `EURCAD.DWX` / D1;
- terminal result: `failed / INFRA_FAIL`;
- reason: `cold_cache_retries_exhausted:BARS_ZERO`;
- expected cadence: 10 trades/year/symbol;
- no Q03-or-later lineage, open work item, or open competing agent task was
  present at inspection time;
- the approved card has `g0_status: APPROVED`, R1-R4 PASS, fixed TII mechanics,
  and no ML, grid, or martingale; and
- the canonical EA path was clean.

The old row is bound to the pre-repair artifacts:

- MQ5 SHA-256:
  `c47b1814e8d2be930424b91ee20a9c01112529e5b0e9e5a90ce39cfd875fabab`;
- EX5 SHA-256:
  `dcb983ffbe16a850bacc83117a9c1cb5ad4b97282fea6004fd425d798deabd5c`.

The mechanics-preserving hot-path repair documented in
`docs/ops/evidence/2026-08-06_qm5_10147_eurchf_q02_runtime_repair.md` is the
current canonical build:

- MQ5 SHA-256:
  `a767f02c2ed31f90e2d8233fdf0cfb23a9a8c4314c7734e942fef65f3e650741`;
- EX5 SHA-256:
  `12fd25c63ef5aafcd6cfea88ebf76c193c8a95e0bedc5d25935113e19fbfcb2e`;
- EURCAD fixed-risk setfile SHA-256:
  `84b51c358cfc14dd8eefbea90205a937acb2359f3f100b01102841c58f019d55`.

That repair already converted the separate EURCHF infrastructure lineage into
a real economic Q02 verdict. EURCAD has not received its own append-only rerun,
so this is a distinct stale-binary recovery rather than a duplicate retry.

## Capacity evidence

Five one-second host CPU samples immediately before any mutation were:

`98.84%, 99.81%, 97.87%, 99.13%, 99.42%`

Average CPU was `99.01%`; every sample exceeded the 97% ceiling. The farm also
had five active managed work items on `T2`, `T4`, `T5`, `T8`, and `T9`.

Per the mission's explicit CPU-ceiling instruction, no claim was taken and the
append-only enqueue was not attempted.

## Ready handoff after capacity clears

Recheck the backlog, exact-row successor guard, current artifact hashes, open
work items, and competing claims. If they remain unchanged and CPU is below the
ceiling, the governed recovery command is:

```powershell
python tools/strategy_farm/farmctl.py enqueue-backtest `
  --ea QM5_10147 `
  --phase Q02 `
  --from-work-item-id 44023000-f837-4323-be2e-442c353ca2e8 `
  --append-only-rerun-of 44023000-f837-4323-be2e-442c353ca2e8 `
  --rerun-reason "Current mechanics-preserving TII hot-path repair; distinct EURCAD D1 stale-binary recovery" `
  --expected-current-ex5-sha256 12fd25c63ef5aafcd6cfea88ebf76c193c8a95e0bedc5d25935113e19fbfcb2e
```

Historical work-item evidence must remain append-only. T_Live, AutoTrading,
the portfolio gate, and deploy manifests remain out of scope.
