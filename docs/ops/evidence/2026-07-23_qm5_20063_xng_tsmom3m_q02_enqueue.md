# QM5_20063 XNG Three-Month TSMOM — Build And Q02 Enqueue

Date: 2026-07-23

## Scope

One new low-frequency energy sleeve was mechanized from the peer-reviewed
Moskowitz, Ooi and Pedersen (2012) time-series-momentum source. The EA trades
`XNGUSD.DWX` D1 once per monthly boundary from the sign of the completed
63-D1-bar return. It is not a cumulative-RSI pullback like `QM5_12567`.

No live set, T_Live access, AutoTrading action, deploy manifest, portfolio
manifest, or portfolio-gate change was made.

## Build Evidence

- EA: `framework/EAs/QM5_20063_xng-tsmom3m/QM5_20063_xng-tsmom3m.mq5`
- Binary SHA256: `AF02AB88AF117D92ABECC8C3265179FC3785616A08D7912F5AC4843272B6E65A`
- Setfile build hash: `ce6867b65d6b39fe2bc0f53842f5469e64cfc3e74ffe6d77b5fc5ce27913ec1f`
- Strict compile: PASS, 0 errors, 0 warnings
- Compile log:
  `C:\QM\repo\framework\build\compile\20260723_182003\QM5_20063_xng-tsmom3m.compile.log`
- Build check: PASS, 0 failures, 0 warnings
- Build report:
  `D:\QM\reports\framework\21\build_check_20260723_182003.json`
- Card schema lint: PASS, no missing sections, no ML hits
- Magic: `200630000`, slot 0, `XNGUSD.DWX`

## Q02 Enqueue

The pre-mutation fleet check showed eight T1-T10 tester terminals actively
running, below the ten-terminal ceiling. The targeted sweep was constrained to
`QM5_20063`, `XNGUSD.DWX`, with stranded-retry fan-out disabled.

- Work item: `97aa3634-e22c-458e-8c75-e96e45383445`
- Phase: `Q02`
- Symbol: `XNGUSD.DWX`
- Status after insertion: `pending`, unclaimed
- Duplicate guard: exactly one work item exists for `QM5_20063`
