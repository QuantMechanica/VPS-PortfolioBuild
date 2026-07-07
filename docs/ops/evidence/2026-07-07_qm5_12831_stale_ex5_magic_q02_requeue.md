# QM5_12831 Q02 stale EX5 requeue - 2026-07-07

## Scope

- EA: `QM5_12831_wti-audusd-brk`
- Logical symbol: `QM5_12831_XTI_AUDUSD_BRK_D1`
- Work item: `73e2fb91-713c-46ae-bf99-5d6f59002af1`
- Diversity target: WTI/AUDUSD energy-FX basket.
- Unit of work: Q02 infrastructure unblock only; no backtest was run in this turn.

## Diagnosis

The prior Q02 evidence at
`D:\QM\reports\work_items\73e2fb91-713c-46ae-bf99-5d6f59002af1\QM5_12831\20260706_194155\summary.json`
reported `ONINIT_FAILED`.

The T3 tester log for the failed run stopped in `OnInit` with:

```text
EA_MAGIC_NOT_REGISTERED: ea_id=12831 slot=0 magic=128310000
```

`framework/registry/magic_numbers.csv` and `framework/include/QM/QM_MagicResolver.mqh`
already contained slots `0` and `1` for `QM5_12831`, so the binary was stale relative to
the current resolver.

## Repair

- Regenerated `QM_MagicResolver.mqh` from `magic_numbers.csv`; no registry source diff was produced.
- Strict-recompiled `framework/EAs/QM5_12831_wti-audusd-brk/QM5_12831_wti-audusd-brk.mq5`.
- Compile result: PASS, 0 errors, 0 warnings.
- Compile log: `C:\QM\repo\framework\build\compile\20260707_055424\QM5_12831_wti-audusd-brk.compile.log`
- New EX5 SHA256: `892518D461FB352652CCF7DB298B9E8B2DEB46934F53F2C3CA50E9C7358ED606`

The previous report root was archived before requeue:

```text
D:\QM\reports\work_items\73e2fb91-713c-46ae-bf99-5d6f59002af1.requeued_20260707T0555430000
```

## Requeue

The farm DB row was reset to pending Q02 with `verdict=NULL`, `evidence_path=NULL`, and
`claimed_by=NULL`. The payload records:

- `enqueued_by=codex_requeue.stale_ex5_magic_resolver`
- `requeue_reason=stale_ex5_embedded_pre_12831_magic_resolver; prior Q02 OnInit stopped at EA_MAGIC_NOT_REGISTERED slot0`
- `repair_compile_result=PASS_0_errors_0_warnings`

## Verification

- Strict compile passed with 0 errors and 0 warnings.
- Q02 work item `73e2fb91-713c-46ae-bf99-5d6f59002af1` is pending after requeue.
- `framework/scripts/validate_registries.py` remains globally red from pre-existing unrelated registry issues; no registry file was changed for this repair.
- No `T_Live`, AutoTrading setting, portfolio gate, or live manifest was touched.
