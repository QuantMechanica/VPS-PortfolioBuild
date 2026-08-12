# QM5_12583 XTIUSD Q02 stale-EX5 repair

Date: 2026-07-23  
EA: `QM5_12583_eia-distillate-winter`  
Work item: `f5d5a7f4-066e-4d3f-af80-d9136241bbc2`

## Failure evidence

- Q02 summary:
  `D:\QM\reports\work_items\f5d5a7f4-066e-4d3f-af80-d9136241bbc2\QM5_12583\20260723_124535\summary.json`
- Verdict: `INFRA_FAIL`
- Reason classes: `ONINIT_FAILED`, `INCOMPLETE_RUNS`
- T4 tester journal at 2026-07-23 14:45:58 local:
  `EA_MAGIC_NOT_REGISTERED: ea_id=12583 slot=0 magic=125830000`
- The governed registry already contained the active row:
  `12583,eia-distillate-winter,0,XTIUSD.DWX,125830000,...,active`.
- The failed binary SHA-256 was
  `0f4e1dfb405fdc8700ce7b45f9e8a9c43fec8c964a7bd5daf92b30bc34ea62c7`
  and dated 2026-06-26. The current generated `QM_MagicResolver.mqh`
  contains magic `125830000`, proving the binary was stale relative to the
  resolver.

## Repair

Recompiled the unchanged MQ5 source with the current generated resolver:

```text
framework/scripts/compile_one.ps1
  -EAPath framework/EAs/QM5_12583_eia-distillate-winter/QM5_12583_eia-distillate-winter.mq5
  -Strict
```

Result: PASS, 0 errors, 0 warnings.

- Compile log:
  `C:\QM\repo\framework\build\compile\20260723_140141\QM5_12583_eia-distillate-winter.compile.log`
- Compile summary:
  `D:\QM\reports\compile\20260723_140141\summary.csv`
- Rebuilt EX5 SHA-256:
  `23b3f8a455e367f3bef81a1f886990f125b12b968fb82b5f1ad8fe0802bfb696`

The same Q02 work item was returned to `pending`, with stale execution fields
and the old verdict removed and `expected_ex5_sha256` rebound to the rebuilt
binary. No backtest was launched by this repair, and no live terminal,
AutoTrading setting, portfolio gate, deploy manifest, or T_Live artifact was
touched.
