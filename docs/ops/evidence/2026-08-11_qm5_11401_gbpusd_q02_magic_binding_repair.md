# QM5_11401 GBPUSD Q02 magic-binding repair

Timestamp: `2026-08-11T02:58:08Z`

Branch: `agents/board-advisor`

## Decision

No new cointegration pair was created. The governed 66-pair FX frontier is
already fully mechanized, and the two requested anchors are beyond Q02:

- `QM5_12532`: logical-basket Q02 PASS and Q04 PASS, followed by Q05 FAIL.
- `QM5_12533`: logical-basket Q02 PASS, followed by Q04 FAIL.

Creating another scan-derived basket would duplicate a built relationship.
The mission fallback therefore advanced the existing approved, low-frequency
D1 FX sleeve `QM5_11401_davey-low-volume-mean-reversion-d1` on
`GBPUSD.DWX`.

## Failure classification

The most recent exact Q02 work item,
`eb481e3b-95b3-4bdc-8f7d-5ca99fffa92c`, ended `INFRA_FAIL` with
`ONINIT_FAILED;INCOMPLETE_RUNS`. Its row-bound tester evidence proves that
GBPUSD history and ticks synchronized, then OnInit stopped on:

```text
EA_MAGIC_NOT_REGISTERED: ea_id=11401 slot=1 magic=114010001
```

The deterministic registries already contain active EA `11401` and active
GBPUSD slot 1 / magic `114010001`. The failure is therefore a stale compiled
resolver binding, not a strategy or market-data verdict. The MQ5 strategy
source was left unchanged.

## Repair

The already OWNER-approved farm Card was normalized into the repository at:

- `strategy-seeds/cards/davey-low-volume-mean-reversion-d1_card.md`; and
- `framework/EAs/QM5_11401_davey-low-volume-mean-reversion-d1/docs/strategy_card.md`.

The two copies are byte-identical. They preserve Kevin J. Davey's named-source
lineage, the structural low-volume/N-bar-extreme D1 rule, fixed ATR exits,
approximately eight trades per year per symbol, and the ML/banned-indicator
prohibition. No strategy mechanic, parameter default, symbol slot, or risk
amount changed.

The EA was force-recompiled against the current registered resolver:

| Binding | Before | After |
|---|---|---|
| MQ5 SHA-256 | `2b69efd37e8b2b44330e3ecff0a62b385e2a17f9b52efc95ba086a87bdaa14fe` | unchanged |
| EX5 SHA-256 | `41c52ad5b0a5e2d097d2e168d311d025208ae52b2533382387d985058429e9a2` | `8a7491bbcb9d7f9956b6b6f3d31eaaa3a612fa0371b2c2dc706146263568e661` |
| GBPUSD setfile SHA-256 | `3a992831a047469baf794180fa5672a21e122bf9afcd3f9e23c0c493d07452f8` | `e3eafa8cdc3ac8cf385221fb924ae1d1e92690d91de9046205c8dd15639b4060` |
| Card SHA-256 | absent locally | `847fc9f41bb100fdab97b347f4f78f97b94ac196643fdb98448bcbc46f364484` |

All four backtest setfiles remain D1 `RISK_FIXED=1000`, `RISK_PERCENT=0`,
with their existing slots and parameters. The targeted V5 build check refreshed
only their deterministic `build_hash` headers (and normalized the pre-existing
UTF-8 BOM).

## Validation

- Strict MetaEditor compile: PASS, 0 errors, 0 warnings;
  `D:/QM/reports/compile/20260811_025440/summary.csv`.
- Targeted V5 build check: PASS, 0 failures, 0 warnings;
  `D:/QM/reports/framework/21/build_check_20260811_025550.json`.
- Card schema lint: PASS, no missing sections and no ML hits.
- G0 readiness lint: PASS, no missing fields or sections.
- EA build guard: PASS across source, binary, Card, and four fixed-risk
  backtest setfiles.

## Q02 handoff and CPU ceiling

The canonical sweep created one exact successor while the rebuild was in
progress:

- work item: `5f000316-5d0a-4559-9828-3fc22a9658b1`;
- EA / host / phase: `QM5_11401` / `GBPUSD.DWX` / Q02;
- state at snapshot: `pending`, unclaimed, attempt 0, no verdict; and
- exact open-row count: one.

No duplicate row was inserted. The pending payload contains no pre-claim
execution hashes; the farm dispatcher resolves and records the current
canonical EX5, MQ5, and setfile hashes immediately before spawn, so this row
will bind the repaired binary when claimed.

The immediate fail-closed snapshot found seven active backtests against the
configured active-work ceiling of seven. Normal paced workers own claim,
dispatch, and evidence publication. No manual tester, pump, dispatch tick,
terminal reservation, or process control was performed.

## Safety

- No `T_Live` file, manifest, process, AutoTrading state, live setfile, or
  deployment artifact was touched.
- No portfolio-admission, portfolio KPI, or Q08-contribution path was touched.
- No basket manifest was needed because `QM5_11401` is a single-host,
  single-position FX EA rather than a logical multi-leg tester row.
- Pre-existing unrelated worktree changes were preserved and excluded.

Machine-readable evidence:
`artifacts/qm5_11401_gbpusd_q02_magic_binding_repair_20260811T025808Z.json`.
