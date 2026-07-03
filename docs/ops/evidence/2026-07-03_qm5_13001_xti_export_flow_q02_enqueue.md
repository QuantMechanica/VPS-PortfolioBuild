# QM5_13001 XTI Export Flow Q02 Enqueue

- EA: `QM5_13001_xti-export-flow-brk`
- Card: `strategy-seeds/cards/xti-export-flow-brk_card.md`
- Edge: low-frequency `XTIUSD.DWX` D1 last-business-days export-flow breakout.
- Q01 build: PASS via `framework/scripts/build_check.ps1 -EALabel QM5_13001_xti-export-flow-brk -Strict`.
- Compile log: `framework/build/compile/20260703_170731/QM5_13001_xti-export-flow-brk.compile.log`.
- Build-check report: `D:/QM/reports/framework/21/build_check_20260703_170731.json`.
- EX5 SHA256: `BD45DF4ECBC74014272B0E5DF6DE73FB360E1BB4E8375BB723FC50F1AABCCE75`.
- Q02 enqueue: `python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_13001 --queue-ceiling 10000`.
- Work item: `c5f1bee1-4bc8-40fa-ba6e-9d6472b78b6b`, `Q02`, `pending`, `XTIUSD.DWX`.

Boundary check: no `T_Live`, AutoTrading, deploy manifest, or portfolio gate was touched.
