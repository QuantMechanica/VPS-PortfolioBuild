# QM5_13029 FX slow-horizon revision and Q02 enqueue

Date: 2026-08-12

Branch: `agents/board-advisor`

Router claim: `41092da0-e9a5-4983-b615-2c85993668fa`

Standard build task: `6000e70b-9b3d-41c2-97ce-113858c6a77d`

## Selection

The approved unbuilt backlog had no actionable forex, crypto, rates, or
market-neutral pair identity with complete deterministic registry allocation.
The remaining registered unbuilt candidate was index-only. The inactive
Q02/Q03 infrastructure set likewise had no reputable-source, off-book FX
candidate that had not already advanced or received a terminal strategy
verdict.

Priority 3 therefore selected `QM5_13029_gbpcad-gbpnzd-coint`. Both traded
legs, `GBPCAD.DWX` and `GBPNZD.DWX`, are absent from the current certified-book
instrument set. The approved D1 basket is sourced to Chan's cointegration
method plus the OWNER-directed Darwinex extended FX screen. No target work item
or agent task was active when the claim transaction began. A consistent online
farm-state backup was written before the claim:

`D:/QM/strategy_farm/state/backups/farm_state_pre_qm5_13029_slow_horizon_claim_20260812T045349Z.sqlite`

## Structural revision

The source screen estimates an 84.8-day residual half-life, while the original
mechanization used a 60-bar z-score state window. The approved card had already
declared 90 bars as a permitted window. This revision mechanizes that single
source-aligned slow-horizon variant:

- `strategy_z_lookback_d1`: `60 -> 90` in source, approved/package card, spec,
  and the canonical logical-basket setfile;
- fixed beta `0.3460`, entry `2.0`, exit `0.5`, ATR(20) stop at `2.0`, symbol
  scope, and two-leg direction are unchanged;
- backtest risk remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`;
- no ML, grid, martingale, optimization, adaptive PnL logic, or banned
  indicator was introduced.

The prior Q04 evidence was a genuine strategy split, not infrastructure:
work item `629d9f34-d7a4-42e6-82f0-c7b4d26289b7` reported F1 net PF `0.920`
and F2 net PF `1.420`. The 90-bar choice comes from the source half-life and the
pre-approved card range, not from selecting a fold winner.

## Q01 validation

- SPEC validation: PASS.
- Build check: PASS, 0 failures, 0 warnings.
- Strict compile: PASS, 0 errors, 0 warnings.
- Build-check report:
  `D:/QM/reports/framework/21/build_check_20260812_045715.json`.
- Final compile log:
  `C:/QM/repo/framework/build/compile/20260812_045800/QM5_13029_gbpcad-gbpnzd-coint.compile.log`.
- Final compile summary: `D:/QM/reports/compile/20260812_045800/summary.csv`.

Final artifact SHA-256 values:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `6d51cdb12a515d26c1ca2fddd3a75eb9927e39dcfd4ceac7422758e4f7ff77bf` |
| EX5 | `957b7065a6fc75d3e81feeab5e4a691872763a8b11203f067676da3758438525` |
| SPEC | `d32e91ea489ea361c597d8886c16854652ab4d207288d72f771eb5d821768347` |
| basket manifest | `3295e479a33e2e6ab9ffa71e26f5bdabd88af0d26cdf2897157d584c34dd8069` |
| backtest setfile | `0f9a304236e2352de8eca4c4048d7ad07be544889174dbbfab390b9b9c65e693` |
| normalized build result | `6512551e13c1169ffe29f5a4ac395492111a645ea1252950d2b57c8f6c1396b6` |

## Smoke boundary and Q02 handoff

Exactly one direct smoke invocation was attempted for `GBPCAD.DWX`, D1, 2024,
using the canonical logical-basket setfile. Admission was below the CPU ceiling,
but active custom-history isolation refused T2 before MT5 launch because the
request was not yet worker-bound. No tester result was fabricated and no second
smoke invocation was made.

The standard build recorder converted that clean-build infrastructure result to
`deferred_p2_smoke`, set `needs_p2_smoke_via_pump=true`, and atomically enqueued
exactly one managed logical-basket Q02 row:

- work item: `614cc154-31e1-4919-9a1e-de7bc5e0c5f3`;
- phase/status: `Q02 / pending`;
- logical symbol: `QM5_13029_GBPCAD_GBPNZD_COINTEGRATION_D1`;
- host/timeframe: `GBPCAD.DWX / D1`;
- basket history scope: `GBPCAD.DWX`, `GBPNZD.DWX`, `USDCAD.DWX`, and
  `NZDUSD.DWX`;
- tester account: USD 100,000; managed Q02 owns runtime evidence and strategy
  judgment.

No dispatch tick or manual pipeline phase was run after enqueue.

## Safety boundary

No T_Live file, AutoTrading setting, portfolio gate, T_Live manifest, deploy
manifest, or live-trading state was changed. Registry identity and magic rows
were already active and were not modified.
