# QM5_20064 WTI Two-Month TSMOM — Build And Q02 Enqueue

Date: 2026-07-23

## Scope

One new low-frequency WTI sleeve was mechanized from Moskowitz, Ooi and
Pedersen (2012). The EA evaluates once per broker-month boundary and trades
the sign of WTI's completed 42-D1-bar return. It is distinct from the existing
WTI 3-, 6-, 9-, and 12-month rules and from `QM5_12567` cumulative-RSI
pullback logic.

No live set, T_Live access, AutoTrading action, deploy manifest, portfolio
manifest, or portfolio-gate change was made.

## Build Evidence

- Card schema lint: PASS; no missing sections or ML hits.
- EA: `framework/EAs/QM5_20064_wti-tsmom2m/QM5_20064_wti-tsmom2m.mq5`
- Binary SHA256: `EE40B1064D191FDBB3519F3102AD1250F53E068CD0EB71D5E278CBD82DD6B414`
- Setfile build hash: `bdf179c62a55c1447a0f882bf131b73f33d4e586948136e478aa8b7585df8723`
- Strict compile: PASS, 0 errors, 0 warnings.
- Compile log:
  `C:\QM\repo\framework\build\compile\20260723_200601\QM5_20064_wti-tsmom2m.compile.log`
- Build check: PASS, 0 failures, 0 warnings.
- Build report:
  `D:\QM\reports\framework\21\build_check_20260723_200728.json`
- Magic: `200640000`, slot 0, `XTIUSD.DWX`.

## Q02 Enqueue

The pre-mutation fleet check found only T1, T3, and T9 running tester
processes, below the ten-terminal CPU ceiling. A dry-run first confirmed one
eligible insertion. The applied sweep was restricted to `QM5_20064`,
`XTIUSD.DWX`, and disabled stranded-retry fan-out.

- Work item: `d80fe226-7093-4fcc-bdf6-050c812cccd3`
- Phase: `Q02`
- Status after insertion: `pending`, unclaimed
- Duplicate guard: exactly one work item exists for `QM5_20064`
