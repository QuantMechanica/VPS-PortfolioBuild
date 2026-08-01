# QM5_11521 GBPJPY Q02 infrastructure repair and requeue — 2026-08-01

## Outcome

Repaired and re-enqueued `QM5_11521_carter-t-ema6-13-macd-psar-h4-gbp`,
a low-frequency H4 FX sleeve on `GBPJPY.DWX`. The repair moves entry-only
calendar and spread checks behind the single H4 new-bar edge, refreshes the
compiled binary, and makes both backtest setfiles reproduce the approved card
parameters explicitly. Exactly one append-only GBPJPY Q02 work item was added.

Farm coordination:

- agent task: `031b2223-61f0-4867-8121-7fd4dfccd79f`
- claim key: `manual:codex:agents/board-advisor:QM5_11521:q02-infra-repair:20260801T162513Z`
- source work item: `cffec1e3-45a0-46ea-9dd5-97270c275723`
- branch: `agents/board-advisor`

No claimable priority-1 diversity build remained after the deterministic card
and registry gates, so this was paced-fleet priority 2.

## Approved source and mechanics

The card of record is
`D:\QM\strategy_farm\artifacts\cards_approved\QM5_11521_carter-t-ema6-13-macd-psar-h4-gbp.md`.
It is OWNER-approved with R1-R4 recorded as PASS and cites Thomas Carter,
"Forex Trend Following Strategies: 20 Trend Following Systems", System #18
(2014). The mechanical rule remains unchanged: an EMA(6/13) cross within three
closed H4 bars, confirmed by MACD(12,26,9) sign and Parabolic SAR position,
with fixed source stops and 2.5R targets. No ML, grid, martingale, or adaptive
PnL parameter was introduced.

Both backtest setfiles retain:

- `RISK_FIXED=1000`
- `RISK_PERCENT=0`

## Diagnosis

The farm contained 12 terminal `INFRA_FAIL` rows for each of `GBPJPY.DWX` and
`GBPUSD.DWX`, with no pending/active sibling and no economic verdict. The two
latest attempts used source, executable, and setfile SHA-256 values that
matched the repository exactly, ruling out stale `.ex5` and identity drift.

The retained worker evidence for GBPJPY records `ACTIVE_TIMEOUT` /
`NO_FORWARD_PROGRESS` after 23.36 minutes. The terminal and tester journals
show that the correct executable initialized, the complete 2022 H4/tick
history synchronized, and the strategy advanced normally through November.
It then stopped advancing without publishing a report. The independent
GBPUSD attempt followed the same pattern and stopped late in December after
27.96 minutes. This rules out `ONINIT` and `NO_HISTORY`.

The implementation evaluated `QM_NewsAllowsTrade2()` and its spread/Friday
entry filter before consuming `QM_IsNewBar()` on every Model-4 real tick. That
made entry-only work part of the hot path and allowed blocked H4 edges to be
consumed later, mid-bar. The strategy itself has fixed broker-side SL/TP and
no discretionary exit or active management requirement.

The static guardrail also exposed a reproducibility defect in both setfiles:
strategy parameters were implicit (`card_defaults_source=not_found`). In
particular, GBPJPY inherited the GBPUSD 40-pip stop even though both the
approved card and SPEC require 60 pips for GBPJPY H4.

## Repair

- Kept kill-switch and framework Friday-close protection on the per-tick path.
- Consumed the framework H4 new-bar edge before entry-only news and spread
  checks.
- Kept equity snapshots on every consumed new bar, independent of entry
  eligibility.
- Zero-initialized `QM_EntryRequest` before strategy population.
- Made all card strategy inputs explicit in both backtest setfiles.
- Set GBPJPY to the source 60-pip stop; GBPUSD remains at 40 pips; both remain
  at 2.5R.

## Verification

- Governed strict compile: PASS, 0 errors, 0 warnings.
  - log: `C:\QM\repo\framework\build\compile\20260801_163321\QM5_11521_carter-t-ema6-13-macd-psar-h4-gbp.compile.log`
  - summary: `D:\QM\reports\compile\20260801_163321\summary.csv`
- Strict framework build check: PASS, 0 failures, 0 warnings.
  - report: `D:\QM\reports\framework\21\build_check_20260801_163359.json`
- Build guardrails: PASS, 0 findings across the MQ5 and two setfiles.
- SPEC validation: PASS (1/1).
- `git diff --check`: PASS.

Artifact SHA-256 values:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `d4d4652d52a4a408bc22fd70abbec774fa8dba864683eb04a0aef24e5fa31418` |
| EX5 | `93ac53cdea3c7d092baa4e090dd0ae1a2a26c49ba25750aac338e1d0c3af9471` |
| GBPJPY setfile | `d731ac7874dff2cf083f874ecf8b0792c9591127a962db2e4dece15d4f9f396f` |
| GBPUSD setfile | `a8a63eccaa54ec3e4e4cde429e6c44883f53100827d4da3118e178001c6615f9` |

## Capacity and queue handoff

Immediately before the handoff, six farm terminals were already running.
The separate `T_Live` process was observed read-only and was not counted or
touched. Transient host memory pressure also appeared during a static command,
so no manual smoke/backtest was launched.

The standard stranded-INFRA sweep was bounded to one EA, one symbol, one row,
and the explicit 13-attempt cap required for this repaired 12-INFRA cohort:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --apply \
  --ea QM5_11521 --symbols GBPJPY.DWX \
  --max-part2-per-run 1 --max-infra-attempts 13
```

Result:

- exactly one Q02 row appended: `6219ba64-6e84-4ff3-9ce2-49b84c2ba1bb`
- initial status: `pending`, `attempt_count=0`
- all prior INFRA rows preserved unchanged
- no GBPUSD or other EA row enqueued
- sweep evidence: `D:\QM\reports\state\claude_sweep_enqueue_2026-06-10.json`

No `T_Live`, AutoTrading, portfolio gate, deploy manifest, or live artifact was
modified.
