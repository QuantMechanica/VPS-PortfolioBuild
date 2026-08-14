# QM5_20073 AUDUSD stale-resolver rebuild and Q02 handoff

Date: 2026-08-14

Branch: `agents/board-advisor`

Farm claim: `d1515c17-1db7-455e-bfd9-be1d0b02a191`

Disposition: `REPAIRED_COMMITTED_Q02_PENDING`

## Selection

This is one paced-fleet priority-2 infrastructure recovery for the diverse FX
host `AUDUSD.DWX`. The higher-priority approved GBPUSD build card
`QM5_21512_qs-fibonacci-ma-band-gbp` could not enter Development because its
governed `(ea_id, symbol_slot)` magic allocation does not exist. Development
did not bypass that preflight boundary.

`QM5_20073_pip-hunter-heiken-ashi-r1-recovery` has an approved, reputable-lineage
card, an active EA-ID row, and active magic rows for all six card symbols. This
recovery changes no strategy source or parameter. It only refreshes the compiled
artifact against the active generated resolver and gives the stranded AUDUSD
row an append-only Q02 successor.

## Bound failure and diagnosis

- Predecessor work item:
  `8758e398-19fc-4b85-8b04-b68635bebc17` (`Q02`, `INFRA_FAIL`,
  `AUDUSD.DWX`).
- Bound summary:
  `D:\QM\reports\work_items\8758e398-19fc-4b85-8b04-b68635bebc17\QM5_20073\20260811_165601\summary.json`,
  SHA-256 `afe1dd201bdab555b897b7e180ce3e3f74d9e17fe12450c8f4039c2cc867923e`.
- The summary records `ONINIT_FAILED;INCOMPLETE_RUNS`, zero bars, and old EX5
  SHA-256 `d2e23c5a4b91d431ab1affe93b2938aefc46e239e41cceaa65bf26c410df4b33`.
- `D:\QM\mt5\T8\Tester\logs\20260811.log:73741` records the deterministic
  cause: `EA_MAGIC_NOT_REGISTERED: ea_id=20073 slot=3 magic=200730003`.
  The log SHA-256 is
  `e6eff3b6b96d9f94abce2dca751512cdf5fbc2afc53795bae1035caa50cd231f`.
- `framework/registry/magic_numbers.csv` now contains the active AUDUSD slot-3
  row and the generated resolver contains magic `200730003`.
- Prior repair proof work item
  `194c5c03-8ba7-43cf-936a-5e8434cf99e1` ran the same unchanged MQ5 with a
  resolver-refreshed EX5 on `EURJPY.DWX`: Q02 PASS, 202 trades, no OnInit
  failure. This separates the stale binary defect from strategy entry logic and
  history availability.

The AUDUSD predecessor had no successor and the EA had no open work item when
the farm claim was acquired. The pre-claim database snapshot is
`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_20073_audusd_repaired_identity_claim_20260814T120807Z.sqlite`.

## Repair and deterministic verification

- Strategy MQ5 remained byte-identical at SHA-256
  `e0158e32e05cd326b6c2d2ce2169f391fbd06b72b1d077ee337d1b678ca581dc`.
- `build_check.ps1` compiled the EA against the current include/resolver tree:
  0 errors, 0 warnings, PASS.
- Current EX5 SHA-256:
  `04bd3445580f18b4e7fca82984fb7511e75214fe9002b6b51b3329f2320dcbca`.
- AUDUSD setfile SHA-256:
  `a571367f3da5a783e9ece12bd24dea683cf5911b2da226dab2666b2066ac64a0`.
- AUDUSD risk contract remains `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, H1, magic slot 3.
- Approved-card guard: PASS.
- SPEC validation: PASS.
- Build guardrails: PASS with no findings.
- Framework build-check report:
  `D:\QM\reports\framework\21\build_check_20260814_121123.json`.
- Compile log:
  `C:\QM\repo\framework\build\compile\20260814_121124\QM5_20073_pip-hunter-heiken-ashi-r1-recovery.compile.log`.
- Artifact commit: `b90351e997bd864486cb33b3237b8bd87cf44e66`.

No manual smoke or backtest was launched. Immediately before enqueue, only T6
was running a factory MT5 test; three CPU samples were 67.63%, 60.89%, and
72.57%, so the backtest CPU/terminal ceiling was not reached.

## Append-only Q02 handoff

`farmctl enqueue-backtest` preserved the failed predecessor and created exact
AUDUSD successor `72305c4f-4142-4358-a342-9ca1161cd45c`. At handoff it was
`pending`, attempt count 0, priority-track enabled, and bound to:

- MQ5 SHA-256 `e0158e32...`;
- EX5 SHA-256 `04bd3445...`;
- setfile SHA-256 `a571367f...`;
- expert `QM\QM5_20073_pip-hunter-heiken-ashi-r1-recovery`;
- `AUDUSD.DWX`, H1, 2018-07-02 through 2022-12-31;
- `RISK_FIXED=1000`, `RISK_PERCENT=0`.

The normal farm pump/worker owns execution from this point. No `T_Live` file,
AutoTrading setting, portfolio gate, or deploy manifest was touched.
