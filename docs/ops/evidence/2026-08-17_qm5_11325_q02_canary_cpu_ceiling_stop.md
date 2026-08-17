# QM5_11325 repaired FX canary — CPU-ceiling stop

Date: 2026-08-17

Branch: `agents/board-advisor`

Outcome: `STOPPED_AT_HARD_BACKTEST_CPU_CEILING`

## Selected unit

The approved-card backlog still had no valid unbuilt diversity candidate. The
remaining genuinely unbuilt rates/cross-asset cards require native Treasury,
IEF/BIL/DBC, or lumber inputs that are absent from the `.DWX` history matrix.
The six-symbol FX build `QM5_11754` also acquired live Q02 rows from another
fleet worker during this slot, so touching it would have duplicated active
work.

The non-duplicate priority-2 continuation was therefore
`QM5_11325_tc-m5-9-ema50-100-macd-partial-exit` on `EURUSD.DWX`:

- its approved card covers three major-FX hosts and expects 36 trades/year per
  symbol;
- all 36 historical Q02 rows are terminal `INFRA_FAIL`, with no economic
  verdict or deeper-phase row;
- the repaired source, current-framework EX5, and numeric news-off setfile were
  already strictly validated in commit `a5bf531a0c76e7d2136e43c7cce9de4b5b231c51`;
- immediately before the claim there was no pending/active work item and no
  competing active EA claim.

Current immutable artifact bindings were rechecked:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `a6ad9de616453c7fa414379b025d07d9eaabd085298f0687202418a1c4d2da2f` |
| EX5 | `2bf875d2a303fe36dbae9c8a51d85c9ae44bdbe28c8099c25a4a2596b8d6c171` |
| EURUSD RISK_FIXED set | `c90f9aa80ebe8710354eeaae5eb71ae0988c287f0e7a7f3516a647faee5e103c` |

The intended append-only predecessor was
`6b0dc37c-437f-4804-9f1a-6ef944160a14`. Its preserved evidence is
`D:\QM\reports\work_items\6b0dc37c-437f-4804-9f1a-6ef944160a14\QM5_11325\20260811_151555\summary.json`,
classified `ONINIT_FAILED;INCOMPLETE_RUNS` with zero bars rather than an
economic zero-trade result.

## Farm coordination

An atomic farm-DB recheck and claim completed before any enqueue:

- claim task: `e2d2ea39-662a-47f6-b3f0-4ed22d6b9bd3`;
- task type/state at claim: `q02_infra_repair / IN_PROGRESS`;
- assigned agent: `codex:agents/board-advisor`;
- claim time: `2026-08-17T09:50:10.388746+00:00`;
- pre-claim online backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11325_q02_enqueue_claim_20260817T095010Z.sqlite`.

The claim transaction aborted on any open target row or competing active
claim. Neither existed. The historical rows were not reset or edited.

## Binding capacity gate

At the earlier selection sample the farm had three governed testers active and
five CPU readings between 63% and 88%. Capacity changed before apply, so the
mandatory immediate pre-enqueue check was repeated.

`farmctl mt5-slots` at `2026-08-17T09:56:11+00:00` found five governed factory
terminals active: `T1`, `T3`, `T4`, `T5`, and `T8`. `T_Live` and the FTMO
terminal were visible but excluded and untouched. Five consecutive host CPU
samples were:

| UTC | CPU |
|---|---:|
| `2026-08-17T09:56:20Z` | 100% |
| `2026-08-17T09:56:23Z` | 100% |
| `2026-08-17T09:56:26Z` | 100% |
| `2026-08-17T09:56:29Z` | 100% |
| `2026-08-17T09:56:32Z` | 97% |

The 99.4% average meets the hard backtest CPU ceiling. The worker admission
contract also defines `CPU_MAX_LOAD_PERCENT = 97.0` in
`tools/strategy_farm/terminal_worker.py`. Per the paced-fleet mission, the
operation stopped before invoking `farmctl enqueue-backtest`.

## Exact continuation

After a fresh immediate sample is below the CPU ceiling, recheck that
`QM5_11325` still has no open row or competing claim, then append exactly one
EURUSD Q02 successor:

```powershell
python tools/strategy_farm/farmctl.py enqueue-backtest `
  --ea QM5_11325 `
  --phase Q02 `
  --append-only-rerun-of 6b0dc37c-437f-4804-9f1a-6ef944160a14 `
  --rerun-reason "repaired current-framework EX5 and news-off contract; one EURUSD Q02 canary after ONINIT INFRA_FAIL" `
  --expected-current-ex5-sha256 2bf875d2a303fe36dbae9c8a51d85c9ae44bdbe28c8099c25a4a2596b8d6c171
```

No work item was inserted, reopened, reset, claimed, or dispatched in this
slot. No EA, setfile, registry, resolver, Strategy Card, terminal process,
portfolio gate, deploy manifest, `T_Live` path, or AutoTrading state changed.
