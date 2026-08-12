# QM5_12784 Pro-Go XTI Q02 stale-magic repair

Date: 2026-08-01 (Europe/Berlin)

Branch: `agents/board-advisor`

EA: `QM5_12784_progo-xti`

Instrument / timeframe: `XTIUSD.DWX` / `D1`

## Outcome

The existing Q02 work item was repaired and atomically reopened for the factory.
No replacement work item or manual tester process was created.

- Work item: `e04d6c58-8b0d-461c-a0f3-22912b484695`
- Transition: `done / INFRA_FAIL` -> `pending / NULL`
- Transition-ledger action: `infra_repair_requeue`
- Re-enqueued at: `2026-07-31T22:44:57+00:00`
- Agent claim: `37aa62cb-e5f3-4f85-91a0-47e9aff97d2a`

This is a priority-2 diversity recovery: an approved, structural, low-frequency
WTI sleeve was stuck at Q02 on infrastructure, with no Q02 pass, downstream
phase, open Q02/Q03 duplicate, or competing repair claim. The approved card
cites Larry Williams, *Long-Term Secrets to Short-Term Trading* (Wiley, 1999),
and expects approximately 16 trades/year.

## Diagnosis

The retained Q02 summary at
`D:\QM\reports\work_items\e04d6c58-8b0d-461c-a0f3-22912b484695\QM5_12784\20260723_030717\summary.json`
classified the run as `ONINIT_FAILED;INCOMPLETE_RUNS`. Its MT5 report contains
zero bars and zero ticks. The tested EX5 SHA-256 was:

`6743903a3efb46504bb9ddd5c2e9658603a6e356c51603b788b394065a564016`

Git/build chronology identifies the binding defect:

- `f94c127ca9297d56c27e0ceac71c634b71d758bc` built the EA on 2026-06-29;
  the EX5 timestamp is `2026-06-29T17:10:20Z`.
- That build added the active CSV allocation `12784,progo-xti,0,XTIUSD.DWX,127840000`.
- The generated `QM_MagicResolver.mqh` did not contain `127840000` in that
  commit. The magic first entered the generated resolver in
  `eeb8c77284b857487e0feec76e622b4a2d72988f` at 2026-06-29 19:40 +02:00.
- Q02 later exercised the unchanged original EX5, so `QM_FrameworkInit()`
  could not resolve the EA's registered magic and returned `INIT_FAILED`.

## Repair

- Recompiled the EA against the current generated resolver, which contains
  active magic `127840000` for slot 0 / `XTIUSD.DWX`.
- Updated stale framework wiring so MAE sampling runs before early returns,
  position management/exits remain active during news blackouts, and the news
  gate applies only to new entries.
- Zero-initialized `QM_EntryRequest` before populating the entry request.
- Regenerated the canonical D1 backtest setfile. It now explicitly binds
  `qm_ea_id=12784`, `qm_magic_slot_offset=0`, `RISK_FIXED=1000`, and
  `RISK_PERCENT=0`.

## Verification

- Strategy spec validation: `PASS` (1/1)
- Strict MetaEditor compile: `PASS`, 0 errors, 0 warnings
- Compile log:
  `C:\QM\repo\framework\build\compile\20260731_224207\QM5_12784_progo-xti.compile.log`
- Full build check: `PASS`, 0 failures, 0 warnings
- Build-check report:
  `D:\QM\reports\framework\21\build_check_20260731_224207.json`
- The standard build pump committed the regenerated EX5 and setfile in
  `63107b2d1c8ed1906a298b4e3c0903d091623fd7`; the source repair and this
  evidence remain paired in the explicit branch commit that contains this file.

Bound artifact SHA-256 values:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `034a76bf8a998bacbebc34634e31025c6db83f4009cef3f7294ad0e37725c292` |
| EX5 | `f73ed4c5913d3dcaaf4a514462ba842a8bb8fb5f54365eeb15caab324cf36e58` |
| Backtest setfile | `1ad2189a4b73cb6821453e7626ed668d24566480a45011d5992ccaf5e7fb2d6e` |
| Current magic resolver | `4c6fc13fa506f41e29fcbbd2b64f95462a9a2bc68453c01bc4dcc77ca058f93d` |

The retry payload binds the expected MQ5, EX5, and setfile hashes. The prior
failed-run evidence path and binary hash remain in `infra_repair_history`.

## Farm coordination and safety

- Pre-claim DB backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_12784_q02_repair_20260731T223750Z.sqlite`
- Pre-requeue DB backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_12784_q02_requeue_20260731T224457Z.sqlite`
- Capacity immediately before enqueue: 6 active T1-T10 factory terminals;
  ceiling 7.
- Dispatch mode: queue only (`manual_dispatch=false`). The factory owns the
  Q02 execution and evidence production.
- No `T_Live`, AutoTrading, live/deploy manifest, portfolio gate, portfolio
  admission, or live setfile was readied or changed.
