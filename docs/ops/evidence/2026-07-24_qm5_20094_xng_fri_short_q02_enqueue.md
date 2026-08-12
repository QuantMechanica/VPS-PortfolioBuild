# QM5_20094 XNG Friday Short — Build And Q02 Enqueue

Date: 2026-07-24

## Scope

One new natural-gas calendar carrier was extracted from the fully reviewed
Borowski (2016) source. It sells `XNGUSD.DWX` on broker Friday D1 bars and
closes at the next D1 boundary. The source Friday mean is explicitly recorded
as weak/non-significant. This is not QM5_12567 cumulative-RSI2 logic.

No live setfile, T_Live access, AutoTrading action, deploy manifest, portfolio
manifest, portfolio admission, or portfolio-gate change was made.

## Build evidence

- Card schema lint: PASS; no missing sections or ML hits.
- Strict compile: PASS, 0 errors, 0 warnings.
- Compile log:
  `C:\QM\repo\framework\build\compile\20260724_012141\QM5_20094_xng-fri-short.compile.log`
- Binary SHA256:
  `E1E92544EE80C3EFB913C31C3D82BC3072B41D7B9CAFC91C0BCE3FF1ABF01FF1`
- Setfile build hash:
  `2d0443d3c38b9319ea79b08f9991ca6c95d02db2a2a5f0143effd7bb3bce28c7`
- Magic: `200940000`, slot 0, `XNGUSD.DWX`.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Q02 enqueue

The pre-mutation slot check found three active pipeline tester terminals,
below the ten-terminal CPU ceiling. A scoped dry-run confirmed exactly one
eligible insertion. The applied sweep was restricted to `QM5_20094`,
`XNGUSD.DWX`, with stranded-retry fan-out disabled.

- Work item: `56d4a26f-bef1-43df-8d98-ac93fddeef71`
- Phase: `Q02`
- Status after insertion: `pending`, unclaimed
- Duplicate guard: exactly one work item exists for `QM5_20094`
