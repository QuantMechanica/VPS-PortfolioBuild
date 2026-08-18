# QM5_1229 EURCHF Q02 History-Isolation Recovery — Capacity Stop

Date: 2026-08-18 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `DIAGNOSED_AND_CLAIMED; Q02 NOT ENQUEUED — HARD CPU CEILING`

## Selection and non-duplicate claim

The approved build backlog was checked first. The highest-diversity candidate,
`QM5_41002`, had no governed magic-number rows. The standard
`qm-build-ea-from-card` preflight forbids building it without those rows, and
the sanctioned allocator could not run while its registry inputs contained
other agents' uncommitted changes. Its temporary claim was released; no build,
ad-hoc allocation, or registry change was made.

The next-priority diverse infrastructure recovery was therefore selected:

- EA: `QM5_1229_carver-statevol`;
- target: `EURCHF.DWX`, `D1`, Q02;
- failed predecessor: `8870ee05-fbc6-4bc2-a721-b3cba2a334c5`;
- approved card:
  `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1229_carver-statevol.md`;
- card SHA-256:
  `4748cb03bcf6109512d09ec150df3bb9dda263990c127447d5f341206886cf38`;
- governance: `g0_status: APPROVED`, R1-R4 PASS, expected 10
  trades/year/symbol;
- source and mechanic: Rob Carver's reputable qoppac “State of Vol” research,
  implemented as a structural volatility-regime factor without ML, grid, or
  martingale; and
- diversity basis: EURCHF/CHF is absent from the Q10 certified book, while all
  seven current Q08 `FAIL_SOFT` survivors are concentrated in index, metal,
  and energy sleeves.

The market-neutral `QM5_1058` candidate was rejected as a collision because it
already had a pending Q04 row. The earlier `QM5_1236 / EURUSD.DWX` capacity
investigation was also excluded as duplicate work. For `QM5_1229 /
EURCHF.DWX`, the pre-claim read found no downstream row, no open work item, and
no competing active task; its historical target rows were Q02 infrastructure
failures only.

The farm database atomically assigned distinct task
`076c4a69-79c6-4b41-9034-37a895783719` to `codex` at priority 98 under claim
key
`manual:codex:agents/board-advisor:QM5_1229:EURCHF.DWX:q02-bars-zero:20260818T005137Z`.
Before the claim, the canonical database was backed up online to:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_1229_eurchf_q02_claim_20260818T005137Z.sqlite`

The 400,490,496-byte backup passed `PRAGMA quick_check` and has SHA-256
`c34ad50d2ab9640306d8f39816a2fbd565b60cc4af416aebdb0dfbc8e31c7dac`.

## Infrastructure diagnosis and repair readiness

The predecessor's bound summary is:

`D:/QM/reports/work_items/8870ee05-fbc6-4bc2-a721-b3cba2a334c5/QM5_1229/20260728_142608/summary.json`

Its SHA-256 is
`0e39a681e9aed08748a8d7126783988183d4c7e6ff633c9617053d83571f909b`.
All three attempts were invalid infrastructure runs with `BARS_ZERO`, empty
expert/symbol fields, and the characteristic 1970/M0 signature. Artifact
deployment was stable, and no valid economic result was produced; these runs
are not strategy-quality verdicts.

The failed predecessor used EX5 SHA-256
`2ac03868ed7b6c93565f1031a778f32509dc00cc4d884d65ac3b3203026e45dd`.
The current EX5 is a strict post-migration rebuild dated 2026-08-12 with
SHA-256
`a1cb81c11a932a1f3f5f00f1af7a32952466d26fcbf3ff31434a4cc22256eda1`.
Its compile log reports 0 errors and 0 warnings and has SHA-256
`8599828dc3de15e2ceba5ffd858584790f843bec764fc5ebfed98df530d45b33`.
Current artifact hashes are:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `98c621bdcf2e22ced88e2da30387789ba7219b42e83b37963ce1b0521689080f` |
| EX5 | `a1cb81c11a932a1f3f5f00f1af7a32952466d26fcbf3ff31434a4cc22256eda1` |
| EURCHF D1 backtest setfile | `a78381adf6e6b4653c196e50140bd68af0e8d91cd33d4a895f5809e809f49eaa` |

`validate_spec_doc.py` and both source and setfile passes of
`validate_build_guardrails.py` succeeded. The source scan found no banned,
ML, grid, or martingale mechanics. The setfile is backtest-only fixed risk:
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, and
`environment=backtest`. The active magic registry contains slot 10
`EURCHF.DWX` magic `12290010`.

Variant-A custom-history copy-on-claim isolation is active for T1-T10, with
containment disabled. Its activation file has SHA-256
`0089c8b613a1181ff4d2304a9b2d7102da5445e6f7e9970841739dd5533f3672`,
and its OWNER-approved archive manifest has SHA-256
`fe0dd0fdd90dc26b806044c82fd0d7c35af889a96cbd4d79dece9cfdac3aab06`.
Archive admission for this card and EURCHF target passed, selecting 422 rows
for the explicitly named universe. A post-migration sibling retry for this EA
on EURGBP produced a valid six-trade report; it failed only the minimum-trades
strategy criterion. This is empirical confirmation that the repaired runtime
path can produce valid reports, not a claim that EURCHF has passed Q02.

## Mandatory capacity stop

At `2026-08-18T00:56:39Z`, the canonical database reported six governed active
work items:

| Terminal | EA | Phase | Symbol |
|---|---|---|---|
| T10 | `QM5_20161` | Q04 | `XAU/XAG` logical pair |
| T2 | `QM5_10114` | Q08 | `SP500.DWX` |
| T3 | `QM5_10128` | Q08 | `XAUUSD.DWX` |
| T4 | `QM5_10513` | Q08 | `XAUUSD.DWX` |
| T6 | `QM5_10403` | Q08 | `XAUUSD.DWX` |
| T7 | `QM5_11287` | Q04 | `USDJPY.DWX` |

The terminal census found the corresponding factory activity without a
duplicate or orphan. Five consecutive whole-host CPU samples at
`2026-08-18T00:56:44Z` were `96.0`, `98.0`, `62.0`, `93.0`, and `97.0`
percent: average `89.2%`, maximum `98.0%`. The maximum exceeds the explicit
97% hard host-CPU ceiling.

Per the mission stop condition, no append-only Q02 row was created. The final
target readback still showed no successor and no open work item for
`QM5_1229 / EURCHF.DWX`. There was no dispatcher tick, smoke test, MetaTrader
launch, phase runner, or manual backtest.

At `2026-08-18T00:59:30Z`, task
`076c4a69-79c6-4b41-9034-37a895783719` was atomically moved from
`IN_PROGRESS` to `BLOCKED` with verdict `BLOCKED_CAPACITY`; its lease was
released. This prevents a stale ownership collision and requires a fresh
capacity and collision check before a later retry.

## Capacity-clear handoff

Only after a fresh collision guard, artifact-hash check, archive-admission
check, governed-slot census, and five-sample CPU check all pass, the canonical
append-only handoff is:

```powershell
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-backtest --ea QM5_1229 --phase Q02 --from-work-item-id 8870ee05-fbc6-4bc2-a721-b3cba2a334c5 --append-only-rerun-of 8870ee05-fbc6-4bc2-a721-b3cba2a334c5 --rerun-reason "Predecessor ended with infrastructure-only BARS_ZERO on 2026-07-28 before Variant-A custom-history copy-on-claim isolation; current EX5 is a strict post-migration rebuild, the active manifest admits EURCHF.DWX, and the D1 backtest set remains RISK_FIXED. Append one isolated EURCHF.DWX retry without manual dispatch." --expected-current-ex5-sha256 a1cb81c11a932a1f3f5f00f1af7a32952466d26fcbf3ff31434a4cc22256eda1
```

No EA source, EX5, Strategy Card, setfile, registry, resolver, portfolio gate,
portfolio manifest, deploy artifact, `T_Live` path, or AutoTrading state was
changed.
