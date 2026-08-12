# QM5_12355 EURUSD Q02 stale-magic-resolver repair

Date: 2026-08-11  
Branch: `agents/board-advisor`  
EA: `QM5_12355_orev-powertrend`  
Scope: one-EA Q02 infrastructure repair; no strategy-logic change

## Selection and claim

- The approved card is a deterministic D1 persistence strategy with an expected cadence of about 10 trades/year/symbol and no ML, grid, or martingale logic.
- EURUSD adds an FX instrument to a certified book currently concentrated in indices, metals, and energy.
- The card has an exact, reproducible source pointer (`oreilm49/quantconnect`, `Powertrend/main.py`) and G0 OWNER-policy approval.
- No Q02/Q03/Q04 economic verdict existed for this EA at claim time. Repeated rows were infrastructure-only `ONINIT_FAILED` results.
- Farm claim: `33d9fd8c-886e-4939-9832-9e2ce9f7b2ea`, assigned to `codex:agents/board-advisor`.
- Pre-claim DB backup: `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_12355_q02_claim_20260811T120121Z.sqlite`.

## Root cause

The authenticated EURUSD predecessor `fe1da919-d653-4482-a552-5fda372153ae` staged and verified EX5 SHA-256
`3d14621aaf49dc5a1e71a9aa751ace372c5916e239dc74468bec93daa288afb2`, then failed OnInit with:

```text
EA_MAGIC_NOT_REGISTERED: ea_id=12355 slot=3 magic=123550003
tester stopped because OnInit returns non-zero code 1
```

Evidence is in `D:\QM\reports\work_items\fe1da919-d653-4482-a552-5fda372153ae\QM5_12355\20260811_110218\raw\run_01\20260811.log`.
An independent XAU row reproduced the same defect for slot 4. The canonical magic registry now contains active rows for both slots, while the failed EX5 predated the current generated `QM_MagicResolver.mqh`. This classifies the blocker as a stale compiled resolver, not strategy mechanics or market history.

## Repair and verification

- MQ5 logic remained byte-identical: `751345cb308b330886e8bd39342be4a2f30b205369a0729bf564634556030c28`.
- Recompiled EX5: `4f4f2510eff48d947421a2dae7a93f4c45696803a8490a822fce4080d72a6589`.
- Strict compile: PASS, 0 errors, 0 warnings.
  - Log: `C:\QM\repo\framework\build\compile\20260811_120235\QM5_12355_orev-powertrend.compile.log`
  - Log SHA-256: `95a11b67a5847907e682c41c3ff2dbb99bc16ec6513f36dc157be686af84202d`
- Static build gate: PASS, 0 failures, 0 warnings.
  - Report: `D:\QM\reports\framework\21\build_check_20260811_120309.json`
  - Report SHA-256: `e93884ef59083e9d28bcedb32eff1f88920d3c8bac3c1363a5bff9741c45e28f`
- The build gate pinned deterministic `build_hash` comments in all five backtest setfiles. Their executable inputs remain `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- Repaired EURUSD setfile SHA-256: `31390d0376838fbca36c6bb1ec49ead775a83f29bdbe7030d208e1346458ad84`.

No local smoke test was launched. Immediately before enqueue, six pipeline work items were active against the seven-terminal ceiling; five CPU samples averaged 91.76%. Runtime work remains scheduler-controlled.

## Append-only Q02 handoff

The governed, factory-locked enqueue was restricted to `--ea QM5_12355 --symbols EURUSD.DWX --max-part2-per-run 1`.

- Successor work item: `3786430a-647c-4a30-b1aa-b10e17b37f5c`
- Phase / symbol: `Q02` / `EURUSD.DWX`
- Initial state: `pending`
- Predecessor: `fe1da919-d653-4482-a552-5fda372153ae` (`INFRA_FAIL`)
- Priority track: retained
- Other EAs or symbols enqueued: 0

No T_Live files, AutoTrading state, portfolio gate, or deploy manifest were read or changed as part of this repair.
