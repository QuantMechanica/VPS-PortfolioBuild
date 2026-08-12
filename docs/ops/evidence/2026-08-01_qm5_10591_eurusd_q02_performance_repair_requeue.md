# QM5_10591 EURUSD Q02 performance repair and requeue — 2026-08-01

## Outcome

Repaired `QM5_10591_mql5-ozym`, a low-frequency H4 FX sleeve whose Q02
history was infrastructure-only. The Ozymandias structural state is now
evaluated once per closed bar instead of twice per tick. A fresh binary was
compiled and one append-only `EURUSD.DWX` Q02 work item was enqueued through
the standard stranded-INFRA sweep.

This was paced-fleet priority 2. No priority-1 build candidate was eligible:
the nominal high-diversity leaders were incomplete/unallocated, below the Q02
trade-frequency floor, or outside the current DWX symbol matrix.

Farm coordination claim:

- agent task: `ef76ea5f-1626-4954-bfa6-3a428e266185`
- claim key: `manual:codex:agents/board-advisor:QM5_10591:q02-performance-repair:20260801`
- source work item: `a7ff9e53-a49e-4f48-9a21-fdbfb939c670`

## Candidate and source quality

The approved card is
`D:\QM\strategy_farm\artifacts\cards_approved\QM5_10591_mql5-ozym.md`.
It cites Nikolay Kositsin's `Exp_Ozymandias` in the MQL5 CodeBase
(`https://www.mql5.com/en/code/12543`) and records R1/R2/R3/R4 `PASS` plus
`g0_status: APPROVED`. Its rule is mechanical and structural: trade a confirmed
closed-bar Ozymandias middle-line colour change. The primary universe includes
`EURUSD.DWX`, the period is H4, and the card estimates 25–60 trades/year/symbol.
There is no ML, grid, martingale, or adaptive sizing.

All four canonical backtest setfiles retain:

- `RISK_FIXED=1000`
- `RISK_PERCENT=0`

## Diagnosis

The exact EURUSD Q02 cohort had 12 terminal `INFRA_FAIL` rows, no pending or
active sibling, and no economic `PASS`, `FAIL`, or `ZERO` verdict. The latest
row was reaped as `ACTIVE_TIMEOUT` after repeated `NO_HISTORY`/incomplete
attempts. Its retained payload records only 5% progress after 56.81 minutes.

The surviving implementation defect was deterministic tester cost:

1. `Strategy_ExitSignal()` ran on every tick.
2. It rebuilt both 240-bar Ozymandias state windows on every call.
3. `Strategy_EntrySignal()` rebuilt the same state again on each new bar.

An earlier repair replaced raw history access with guarded framework reads, but
did not remove this per-tick structural recomputation. That explains why cache
recovery could make the tester start while full-window runs still timed out.

## Repair

`QM5_10591_mql5-ozym.mq5` now:

- returns at the framework new-bar gate before evaluating the source exit;
- computes `OzymandiasColorChange()` once after that gate;
- caches the closed-bar result for both entry and adverse-signal exit.

Kill switch, Friday close, news handling, broker SL/TP, and open-position
management remain in their existing per-tick locations. The source entry and
adverse-signal exit were already closed-bar rules, so the change preserves
alpha semantics while eliminating the repeated scan.

## Verification

- Governed strict compile: `PASS`, 0 errors, 0 warnings.
  - log: `C:\QM\repo\framework\build\compile\20260801_000923\QM5_10591_mql5-ozym.compile.log`
  - summary: `D:\QM\reports\compile\20260801_000923\summary.csv`
- Build guardrails: `PASS`, 0 findings across 5 checked files.
- Strict framework build check: `PASS`, 0 failures, 0 warnings.
  - report: `D:\QM\reports\framework\21\build_check_20260801_001011.json`
- SPEC validation: `PASS` (1/1).

Artifact SHA-256 values after the repair:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `55d2237975ce2306c1b1fd29ae48df4792bf3de42c156ffd91ba92ea4ceb4414` |
| EX5 | `0dd503bfd16af2b547a660f02306d098aad9dfd2f401a5ee452ef655fad07c80` |
| EURUSD setfile | `39adede2b27938580d7315dccf0ebaf50cae85fdff52b4d047dbad8b25d0d876` |
| GBPJPY setfile | `bd4fc45528494c90163060de79aebcefc49f63b34049fafac5364cddc471f0e0` |
| USDJPY setfile | `8c236ac2c45acd5cbf78fb19cb42c1b1f23c826c33a56ffa123424eef23dfa04` |
| XAUUSD setfile | `4bc6afec5a87fd966aff9b410c4ddd2196c4e6ff1da723b0bf6a8a9922473d89` |

## Capacity check and Q02 enqueue

Immediately before enqueue, `farmctl mt5-slots` reported only T1 and T4
running farm tests, below the seven-terminal CPU ceiling. The separate
`T_Live` process was observed read-only and was not counted or touched.

The default targeted sweep dry-run refused the exact cohort at its configured
12-INFRA retry cap. Because the executable had now materially changed, the
same governed sweep was applied with its explicit cap override of 13 and a
one-row rate limit:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --apply \
  --ea QM5_10591 --symbols EURUSD.DWX \
  --max-part2-per-run 1 --max-infra-attempts 13
```

Result:

- exactly one Q02 row appended: `92290c04-8598-499c-8b2f-f0172990c5d5`
- status immediately after enqueue: `pending`, `attempt_count=0`
- old terminal INFRA rows preserved unchanged
- queue evidence:
  `D:\QM\reports\state\claude_sweep_enqueue_2026-06-10.json`

No tester was started manually. No T_Live, AutoTrading, portfolio gate, deploy
manifest, or live artifact was modified.
