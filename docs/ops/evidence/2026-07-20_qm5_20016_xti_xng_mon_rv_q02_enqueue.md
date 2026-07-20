# QM5_20016 XTI/XNG Monday relative-value Q02 handoff

Date: 2026-07-20

## Outcome

The already-built, APPROVED `QM5_20016_xti-xng-mon-rv` package was recorded
through the canonical farm lifecycle and auto-enqueued as exactly one logical
Q02 basket. This completed the outstanding funnel handoff without rebuilding
the EA, duplicating either physical leg, or starting a tester.

- Build task: `45b03eb8-039c-4f1e-a6df-2b2a3a50ea8c`
- Build-task transition: `pending -> done`
- Q02 work item: `31e19c25-1edd-4516-86dc-86d78529250f`
- Logical symbol: `QM5_20016_XTI_XNG_MON_RV_D1`
- Host/timeframe: `XTIUSD.DWX` / `D1`
- Basket symbols: `XTIUSD.DWX`, `XNGUSD.DWX`
- Status at verification: `pending`, attempt `0`, unclaimed
- Enqueued at: `2026-07-20T10:56:54+00:00`

The deterministic handoff command was:

```powershell
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm record-build `
  --task-id 45b03eb8-039c-4f1e-a6df-2b2a3a50ea8c `
  --result-file D:/QM/strategy_farm/artifacts/builds/45b03eb8-039c-4f1e-a6df-2b2a3a50ea8c.json
```

It returned `recorded=true`, `new_status=done`, one item in
`auto_q02_enqueued.enqueued`, and zero skipped items. A read-only
`farmctl work-items --ea QM5_20016` verification returned one Q02 row total.

## Build evidence inherited by the handoff

The build was already committed through `dab30bd380bcbebf55b438f1af179c2d86efcf43`
and its result is stored at
`D:/QM/strategy_farm/artifacts/builds/45b03eb8-039c-4f1e-a6df-2b2a3a50ea8c.json`.
The recorded result carries:

- approved card and all R1-R4 gates: PASS / approved;
- SPEC, guardrails, symbol scope, strict build check, and strict compile: PASS;
- compile: 0 errors, 0 warnings;
- EX5 SHA256:
  `D509D1C828B99B88A3E508B0F972632CEC8261032C9A57824AD32BE01BFD3649`;
- one logical basket manifest and one logical backtest setfile;
- risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`;
- active magic rows `200160000` (`XTIUSD.DWX`, slot 0) and `200160001`
  (`XNGUSD.DWX`, slot 1).

The package is a structural, one-session Monday relative-value rule sourced
from Hoelscher, Mbanga and Nelson (2017), *TGIF? The Weekend Effect in Energy
Commodities*, DOI `10.58886/jfi.v16i1.2264`. It sells XTI and buys XNG with
approximately equal USD notionals. This is not evidence of beta, volatility,
or realized portfolio neutrality; Q02 and later gates must falsify those
claims. The exact two-leg package is new, while overlap with the standalone
XTI-short and XNG-long Monday components is explicitly disclosed in the card
and build result.

## CPU ceiling

No smoke, backtest, optimization, dispatch tick, worker tick, or terminal was
started by this handoff. `farmctl mt5-slots` at
`2026-07-20T10:57:19+00:00` showed eight active factory terminals
(`T1`, `T3`, `T4`, `T6`, `T7`, `T8`, `T9`, `T10`) and ten terminal processes
including the isolated live and FTMO GUIs. The recorded build therefore keeps
`smoke_result=deferred_p2_smoke` and `needs_p2_smoke_via_pump=true`; the normal
farm owns the first tester run when capacity becomes available.

## Coordination and rollback

Preflight found no `QM5_20016` agent task, spawn lease, review, process, or
work item. `QM5_1224` was separately leased by another paced worker and was
left untouched. The canonical database was backed up before recording:

- `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_20016_record_build_20260720T105646Z.sqlite`
- SHA256:
  `002E0E06FD137BB67F4BE5E9531F3E326EABC6F839F1AAF2573758BD6BA490A5`

## Safety boundary

No T_Live file or process, AutoTrading setting, live setfile, deploy manifest,
T_Live manifest, portfolio gate, portfolio admission, or portfolio KPI was
read for mutation or changed.
