# QM5_11325 repaired USDJPY Q02 continuation — CPU-ceiling stop

Date: 2026-08-17

Branch: `agents/board-advisor`

Outcome: `STOPPED_AT_HARD_BACKTEST_CPU_CEILING_NO_ENQUEUE`

## Selected non-duplicate continuation

The fresh diversity-build preflight found no eligible approved card that met
the deterministic build contract: the highest-ranked unbuilt forex cards had
active EA-ID rows but no preallocated magic rows, which the
`qm-build-ea-from-card` boundary forbids Development from allocating.

The next valid priority-2 unit was therefore the repaired FX EA
`QM5_11325_tc-m5-9-ema50-100-macd-partial-exit`. Its EURUSD canary has already
reached Q02 `PASS`, so it was excluded as duplicate work. USDJPY was selected
ahead of GBPUSD because it adds a distinct JPY/Asian-session regime to the
EURUSD evidence already present.

At the final farm-DB preflight:

- `QM5_11325 / USDJPY.DWX / Q02` had zero pending or active rows;
- the EA had no result above Q02;
- exact predecessor `e763acba-f1cc-4911-8119-76a7a650241d` remained terminal
  `INFRA_FAIL`, unclaimed, with `ONINIT_FAILED;INCOMPLETE_RUNS`;
- no append-only successor cited that predecessor.

The preserved source summary is
`D:\QM\reports\work_items\e763acba-f1cc-4911-8119-76a7a650241d\QM5_11325\20260811_070422\summary.json`,
SHA-256
`21b3a67a307b5bdcbcc96352f35c2aa4ff5eebba142609ece4ef31bac997eda5`.
It records one attempted run, an OnInit failure, and incomplete execution, not
an economic zero-trade verdict.

## Current immutable bindings

| Artifact | SHA-256 |
|---|---|
| MQ5 | `a6ad9de616453c7fa414379b025d07d9eaabd085298f0687202418a1c4d2da2f` |
| EX5 | `2bf875d2a303fe36dbae9c8a51d85c9ae44bdbe28c8099c25a4a2596b8d6c171` |
| USDJPY backtest set | `4e4508f90ed2766c7dd58abc71161743eaf4f92d219147eef3893649496a0dcf` |

The USDJPY set remains sealed to `RISK_FIXED=1000`, `RISK_PERCENT=0`,
`PORTFOLIO_WEIGHT=1`, and numeric news modes `0/0/0`.

## Capacity gate and stop

An initial five-sample host check was below the ceiling at
`82, 69, 87, 87, 77%` (average `80.4%`, maximum `87%`). The live database then
contained 1,011 open rows: 6 active and 1,005 pending. A verified online SQLite
backup was created before any intended mutation:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11325_usdjpy_q02_canary_20260817T171709Z.sqlite`

The backup is 392,024,064 bytes and returned `PRAGMA quick_check = ok`.

Because capacity can change between selection and apply, the binding
immediate pre-enqueue check was repeated. Its five
`Win32_PerfFormattedData_PerfOS_Processor` samples were:

| UTC | CPU |
|---|---:|
| `2026-08-17T17:17:34Z` | 87% |
| `2026-08-17T17:17:36Z` | 99% |
| `2026-08-17T17:17:38Z` | 95% |
| `2026-08-17T17:17:41Z` | 100% |
| `2026-08-17T17:17:43Z` | 100% |

The maximum was 100%, above the governed 97% hard backtest ceiling. Per the
paced-fleet stop condition, no enqueue command was invoked. No work item was
inserted, reopened, reset, claimed, or dispatched; no tester or terminal was
launched or reserved.

## Exact continuation

After a new immediate CPU sample is wholly below the ceiling, atomically
recheck the target identity and append exactly one successor:

```powershell
python tools/strategy_farm/farmctl.py enqueue-backtest `
  --ea QM5_11325 `
  --phase Q02 `
  --from-work-item-id e763acba-f1cc-4911-8119-76a7a650241d `
  --append-only-rerun-of e763acba-f1cc-4911-8119-76a7a650241d `
  --rerun-reason "repaired current-framework EX5 and news-off contract; one USDJPY Q02 diversity canary after ONINIT INFRA_FAIL" `
  --expected-current-ex5-sha256 2bf875d2a303fe36dbae9c8a51d85c9ae44bdbe28c8099c25a4a2596b8d6c171
```

## Safety boundary

No EA, setfile, registry, resolver, Strategy Card, portfolio gate, T_Live path,
AutoTrading state, deploy manifest, live preset, terminal process, or unrelated
shared-worktree artifact was changed.
