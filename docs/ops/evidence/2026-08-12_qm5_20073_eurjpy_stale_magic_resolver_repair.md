# QM5_20073 EURJPY stale-magic resolver repair and Q02 handoff

Date: 2026-08-12  
Branch: `agents/board-advisor`  
Farm claim: `7f3063d4-7e84-4aee-b3f9-0b9aadeec654`  
Disposition: `REPAIRED_AND_ENQUEUED`

## Selection

This is a paced-fleet priority-2 infrastructure repair on the diverse FX cross
`EURJPY.DWX`. The approved strategy card is
`D:\QM\strategy_farm\artifacts\cards_approved\QM5_20073_pip-hunter-heiken-ashi-r1-recovery.md`.
The strategy remains the approved structural H1 Heiken-Ashi/EMA/RSI mechanic;
no strategy mechanic or parameter was changed.

## Bound failure and diagnosis

- Terminal source work item:
  `c31268a7-e015-4366-88d1-429f223c83f4` (`Q02`, `INFRA_FAIL`).
- Bound source evidence:
  `D:\QM\reports\work_items\c31268a7-e015-4366-88d1-429f223c83f4\QM5_20073\20260811_175634\summary.json`.
- That run bound EX5 SHA-256
  `d2e23c5a4b91d431ab1affe93b2938aefc46e239e41cceaa65bf26c410df4b33`
  and unchanged MQ5 SHA-256
  `e0158e32e05cd326b6c2d2ce2169f391fbd06b72b1d077ee337d1b678ca581dc`.
- `D:\QM\mt5\T6\Tester\logs\20260811.log:125294` records:
  `EA_MAGIC_NOT_REGISTERED: ea_id=20073 slot=4 magic=200730004`, followed by
  the non-zero `OnInit` stop represented in the bound summary.
- `framework/registry/magic_numbers.csv` and the current generated
  `framework/include/QM/QM_MagicResolver.mqh` both contain the active EURJPY
  slot-4 registration (`200730004`). Resolver dry-run kept 15,904 rows, dropped
  none, and bound registry-content SHA-256
  `608de45bbe302f695619b93bc4cad1a9476dc03927652b2247f6edb00d275019`.

The failure is therefore a stale generated resolver baked into the prior EX5,
not missing history and not an entry-rule defect.

## Repair and verification

- Recompiled the unchanged MQ5 with `compile_one.ps1 -Strict` against the
  current generated resolver. The standard compile passed with 0 errors and
  0 warnings and initially produced EX5 SHA-256
  `eb6f6fcab7ff663f9828f33a558cb42cce9df044f6da7ddf3bc3b3e25300a7cf`.
- Initial compile log:
  `C:\QM\repo\framework\build\compile\20260812_182706\QM5_20073_pip-hunter-heiken-ashi-r1-recovery.compile.log`.
- Initial compile summary:
  `D:\QM\reports\compile\20260812_182706\summary.csv`.
- Before that dirty artifact could be committed, a concurrent workspace
  reconciliation restored the old EX5. The first handoff failed closed at
  dispatch preflight; it did not launch MT5. The controlled integrity rebuild
  through the same wrapper re-synchronized the same include tree. Its outer
  shell timed out during that sync, but the spawned MetaEditor compile
  completed normally with 0 errors and 0 warnings. Final compile log:
  `C:\QM\repo\framework\build\compile\20260812_183320\QM5_20073_pip-hunter-heiken-ashi-r1-recovery.compile.log`.
- Canonical committed EX5 SHA-256:
  `c4d720ac955d36c46761863e24384ef36e57fe8fa1d9989f397fe5337132cb33`.
- Canonical artifact commit: `95ee5c07d8ae79cc3b1dab62395ead8ee40c2621`.
- MQ5 SHA-256 remained
  `e0158e32e05cd326b6c2d2ce2169f391fbd06b72b1d077ee337d1b678ca581dc`.
- Approved-card build guard: PASS.
- SPEC validation: PASS.
- Pre- and post-compile framework build-check: PASS with zero failures and
  warnings. Post-compile report:
  `D:\QM\reports\framework\21\build_check_20260812_182743.json`.
- All six canonical backtest setfiles were rebound by the standard compile
  process. Their executable risk contract remains `RISK_FIXED=1000`,
  `RISK_PERCENT=0`; the queued EURJPY setfile SHA-256 is
  `184d3e903fe9538ba5c232c319f6a35851130dc8fb7a8943e717025ea7674422`.

## Append-only Q02 handoff

`farmctl enqueue-backtest` first created repaired-infrastructure row
`d44cbe94-0a52-464f-b722-4de7036fdc73`. It failed closed at preflight with
`staged_ex5_preflight_failed` when the concurrent reconciliation exposed old
EX5 SHA-256 `d2e23c5...` instead of its sealed `eb6f6fca...` identity. Its
evidence is
`D:\QM\reports\work_items\d44cbe94-0a52-464f-b722-4de7036fdc73\QM5_20073\Q02\preflight_failure.json`;
attempt count remained zero, so no tester run occurred.

After committing the canonical rebuild, `farmctl enqueue-backtest` created the
append-only successor `194c5c03-8ba7-43cf-936a-5e8434cf99e1` for
`EURJPY.DWX` / H1. It preserves both earlier infrastructure rows and is bound
to final EX5 SHA-256 `c4d720ac...`, unchanged MQ5 SHA-256 `e0158e32...`, and
EURJPY setfile SHA-256 `184d3e90...`. The successor was `pending` at
`2026-08-12T18:37:46+00:00` with `RISK_FIXED=1000` and `RISK_PERCENT=0`.

At the handoff check (`2026-08-12T18:27:51+00:00`), T1-T10 were all occupied.
No direct smoke/backtest was started and no terminal or worker was disturbed;
the queued farm worker will execute when capacity becomes available.

No T_Live file, AutoTrading setting, portfolio gate, or deploy manifest was
touched.
