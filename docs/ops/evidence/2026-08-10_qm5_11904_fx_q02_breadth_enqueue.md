# QM5_11904 Structural FX Q02 Breadth Enqueue

Date: 2026-08-10 (Europe/Berlin)

Branch: `agents/board-advisor`

Status: seven deferred FX hosts promoted to Q02 after a stage-1 PASS

## Outcome

The frozen 66-pair FX cointegration scan is already fully mechanized. Creating
another pair Card or EA would be duplicate work, and neither requested anchor
needs a Q02 repair: `QM5_12532` has logical-basket Q02 PASS followed by Q05
FAIL, while `QM5_12533` has logical-basket Q02 PASS followed by Q04 FAIL.

The authorized fallback advanced one existing structural FX card,
`QM5_11904_grimes-sperandeo-failure-test-2b-h1`. Its stage-1 `USDJPY.DWX`
work item `38c08150-b157-4de3-bba1-3e73e4a0e661` completed Q02 PASS at
`2026-08-10T16:31:48Z`. The canonical selector then promoted all seven
deferred FX hosts with `promotion_reason=stage1_pass` at
`2026-08-10T17:07:30Z`.

This is a Q02 breadth enqueue, not a backtest result, certified sleeve,
portfolio-admission decision, or live authorization.

## Card Boundary

`QM5_11904` is an OWNER-approved, low-frequency H1 failure-test sleeve sourced
to Adam Grimes and Victor Sperandeo, with Wyckoff structural antecedent. Entry
is deterministic price structure: a fixed swing pivot, a three-pip minimum and
1.5-ATR maximum breach, then a close back inside the pivot. Stops, targets, and
the 48-bar exit are fixed formulas. The approved cadence is approximately ten
trades per year per symbol.

The build in commit `fc71511485e14d04ca265229b605dd4dfbb80ceb`
compiled with zero errors and warnings and passed the strict build check. All
ten backtest presets use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The EA contains no ML, learned output, adaptive PnL
logic, grid, martingale, or external runtime feed.

## Paced Enqueue

A target-only dry run selected exactly seven deferred promotions and no
never-tested or stranded-retry row. The first guarded apply attempt made no
change because the canonical factory mutation lock was held; the lock was not
removed or bypassed.

The immediate pre-apply sample at `2026-08-10T17:07:25Z` found two running
factory terminals:

```text
T3, T8
```

Two is below the binding ceiling of seven. `T_Live` and the unrelated FTMO
terminal were excluded and not controlled. The exact target-only apply was:

```powershell
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_11904 --apply
```

The selector saw 1,137 pending rows against the 7,000-row queue ceiling,
promoted seven rows, selected no unrelated EA, and removed the completed
`QM5_11904` entry from `q02_deferred_symbols.json`.

| Symbol | Q02 work item |
|---|---|
| `AUDJPY.DWX` | `51b3ac5e-4480-4edf-a758-5d3acd4ce4de` |
| `AUDUSD.DWX` | `d0715f0d-3553-407b-995c-13df4d33c1ea` |
| `EURJPY.DWX` | `5c988fff-add3-4c6f-9f9a-53e7f17e3cd5` |
| `GBPJPY.DWX` | `31a10cf5-9645-4d25-bc07-6f8a55cef05f` |
| `NZDUSD.DWX` | `be06ccdb-02a7-4301-8c76-58ed7a27b9df` |
| `USDCAD.DWX` | `59d1ff63-83a9-4c65-bb55-36008e1b032a` |
| `USDCHF.DWX` | `40257e3d-cac5-48d8-a027-2c88730a4e0e` |

Canonical readback at `2026-08-10T17:08:42Z` found all seven rows pending,
unclaimed, at attempt zero, and without verdicts. Normal workers own later
claim and execution.

## Evidence Identity

| Artifact | SHA-256 |
|---|---|
| MQ5 | `1748EB75D9A9033A117AD1105F245A2A8D44887231F302FCF99B152C8ED5E7C4` |
| EX5 | `07A0B77E270BC966BC12FC0E7D26BC84104026BD1F4B6F638FC2DFBD06CA4C29` |
| Approved card copy | `4664DE1C1F2DD9F1828CFE4D60215E4BBDD513A9E03DAFB326A22599B14AA65E` |
| Selector evidence at readback | `466980CC7A6AD6D31E7C12CBC6D7AC803A38A43AE2F19DD12512A0D8E493FA36` |
| Deferred sidecar after apply | `9C574E42BD68D22B8D9FDF6E11355296D5EA135C41B2FBFB455D83A98BC1DA3D` |

The machine-readable snapshot is
`artifacts/qm5_11904_fx_q02_breadth_enqueue_20260810T170730Z.json`.

## Safety

- No manual backtest, smoke test, dispatch tick, or downstream phase ran.
- No terminal was started, stopped, reserved, reaped, or changed.
- No `T_Live` file, process, manifest, or AutoTrading state changed.
- No live/demo/shadow setfile or deployment artifact was created.
- No portfolio-admission, portfolio KPI, or Q08-contribution path changed.
- Pre-existing unrelated dirty-worktree files were preserved and excluded.
