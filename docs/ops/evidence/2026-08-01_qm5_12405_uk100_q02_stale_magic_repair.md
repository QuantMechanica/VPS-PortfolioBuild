# QM5_12405 UK100 Q02 stale-magic repair

Date: 2026-08-01 (Europe/Berlin)

Branch: `agents/board-advisor`

EA: `QM5_12405_stock-cycle12`

Instrument / timeframe: `UK100.DWX` / `D1`

## Outcome

The existing UK100 Q02 work item was repaired and atomically reopened for the
factory. No replacement work item or manual tester process was created.

- Work item: `4955fdfd-5a5b-408a-bce8-ba52f2b2990a`
- Transition: `done / INFRA_FAIL` -> `pending / NULL`
- Transition-ledger action: `infra_repair_requeue`
- Re-enqueued at: `2026-08-01T12:11:31+00:00`
- Canonical farm claim: `agent_tasks.id=6d9f9b5a-c5bb-426f-9d92-b68b670b0f56`,
  `assigned_agent=codex`

This is a priority-2 diversity recovery. The sole magic-ready, unbuilt approved
diversity card was already claimed by another paced lane, while the remaining
approved candidates lacked their deterministic magic allocation. `UK100.DWX`
is absent from the current Q08-PASS symbol set (`EURJPY`, `EURUSD`, `GDAXI`,
`NDX`, `SP500`, `USDCAD`, `XAUUSD`, `XTIUSD`), so recovering this lane can add
instrument diversity rather than another build behind Q02.

The approved G0 card describes a structural, price-only, monthly
cross-sectional seasonality rank with long/short winner and loser buckets. It
cites the public Papers With Backtest / Quantpedia implementation of the
12-month cross-sectional return cycle and passes R1-R4, including the no-ML
gate. The backtest setfile is fixed-risk only.

## Diagnosis

The retained Q02 evidence is:

`D:\QM\reports\work_items\4955fdfd-5a5b-408a-bce8-ba52f2b2990a\QM5_12405\20260728_173806\summary.json`

It records `ONINIT_FAILED;INCOMPLETE_RUNS`, zero bars, zero trades, a stable
source/deployed binary pair, and old EX5 SHA-256
`14e4f1413a796821fb11764b7aa7a9f74de3c31c8d57b506b49afad57eebbec1`.
This is infrastructure evidence, not a strategy verdict.

Git/build chronology identifies the binding defect:

- `07e2cc8d0130676324edf9718811d0ab37b903b3` added active magic rows
  `124050000` through `124050004` to `magic_numbers.csv` at
  `2026-06-18T06:44:30+02:00`.
- The retained EX5 was compiled at `2026-06-18T04:47:39Z` and committed in
  `6917109eaf16580fba25b3d60f649f3457b2b1d0` at
  `2026-06-18T06:53:43+02:00`.
- Those magics first entered generated `QM_MagicResolver.mqh` in
  `aa3d8c768338be1acb85d4ca4c15ee094b9afa2a` at
  `2026-06-18T07:01:18+02:00`, after the EX5 build.

The tested binary therefore could not resolve its registered magic during
`QM_FrameworkInit()` and returned `INIT_FAILED`. The current resolver contains
all five active mappings, including slot 4 / `UK100.DWX` / `124050004`.

## Repair

- Recompiled the unchanged MQ5 source against the current generated resolver.
- Regenerated the canonical UK100 D1 backtest setfile from the approved card.
  It explicitly binds `qm_ea_id=12405`, `qm_magic_slot_offset=4`,
  `RISK_FIXED=1000`, and `RISK_PERCENT=0` plus the preregistered strategy
  defaults.
- The targeted full build check refreshed the build-hash headers on the other
  four registered backtest setfiles for this same compiled EA.
- No entry, exit, indicator, or risk mechanics were changed.

The deterministic build pump committed the EX5 and five setfile artifacts in
`bf86eb262f1fe7e2d4e9d2d8a2531b1f50dcb328`. That shared pump commit also
contained one approved-card artifact from a different paced lane; this repair
did not create or modify that card.

## Verification

- Strategy spec validation: `PASS` (1/1)
- Strict MetaEditor compile: `PASS`, 0 errors, 0 warnings
- Compile log:
  `C:\QM\repo\framework\build\compile\20260801_120812\QM5_12405_stock-cycle12.compile.log`
- Full build check: `PASS`, 0 failures, 2 advisory warnings
- Build-check report:
  `D:\QM\reports\framework\21\build_check_20260801_120812.json`

The two static spread advisories are non-blocking false positives: the
implementation explicitly returns `true` when current `.DWX` spread is zero
and skips zero historical spread observations. It does not reject entries on a
zero/degenerate tester spread.

Bound artifact SHA-256 values:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `884f117258491cda8ac0f6a32630a65ecc9567b77bb81a62d9042eda647e700f` |
| EX5 | `53ad2d5c2d0e9b67021ceb35e41b05d2959c16e72764f213c7f7f4eec2ec9b8b` |
| UK100 backtest setfile | `034433bf1037842d92b5cd9924be97e1eca9a8dc2f46046a753ed97debe0c3e4` |
| Current magic resolver | `266ed8934ccddaa09edd461c485b3e3a08f44c2ae699bf347d6fc947e17087a5` |

The retry payload binds the expected MQ5, EX5, and setfile hashes. The prior
failed-run evidence path and all three prior artifact hashes remain in
`infra_repair_history`.

## Farm coordination and safety

- Pre-claim DB backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_12405_claim_20260801T120700Z.sqlite`
- Pre-requeue DB backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_12405_q02_requeue_20260801T121131Z.sqlite`
- Capacity immediately before enqueue: 2 active T1-T10 factory backtests;
  ceiling 7.
- Dispatch mode: queue only (`manual_dispatch=false`). The factory owns Q02
  execution and evidence production.
- No `T_Live`, AutoTrading, live/deploy manifest, portfolio gate, portfolio
  admission, or live setfile was changed or operated.
