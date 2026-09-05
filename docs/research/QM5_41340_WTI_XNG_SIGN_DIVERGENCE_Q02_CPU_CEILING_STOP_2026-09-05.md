# QM5_41340 WTI/XNG Sign-Divergence Trend — Q02 CPU-Ceiling Stop

**Date:** 2026-09-05  
**Branch:** `agents/board-advisor`  
**Outcome:** one new non-duplicate structural WTI edge was approved, allocated,
and source-built. Its governed compile row was released and remains pending;
the mission stopped before Q02 because the binding host CPU ceiling was hit.

## Edge delivered

`QM5_41340_wti-xng-divtrend` is a direct `XTIUSD.DWX` D1 sleeve. Once per
broker month it reconstructs exactly thirteen synchronized completed XTI/XNG
month ends. It trades WTI in its own exact twelve-month return sign only when
XNG's exact twelve-month sign is strictly opposite. XNG is read-only and has
no magic allocation or order path.

The signal is distinct from `QM5_21516_wti-decoup-trend`, whose admission gate
is the magnitude of a 63-D1 Pearson correlation, and from every two-leg energy
ratio, rank, residual, weekday, and seasonal basket. The corrected-root scan
across 4,820 registry identities, 1,439 repository cards, and 45 Strategy Wiki
nodes returned `CLEAN`. Q09 receives no decorrelation waiver.

## Durable repository evidence

- source approval, G0 card/decision, atomic EA identity, and dedup receipt:
  `041c13ade8`;
- governed magic/resolver allocation and EA-local card: `12032b2289`;
- MQ5, SPEC, six-test independent reference model, and fixed-risk set:
  `823b6f6bd3`.

Pinned inputs:

- MQ5 SHA-256:
  `344F5D588E9F698B83CDCD69685132F3257ACEF8D115EF9A3FF3E78812321FBC`;
- setfile SHA-256:
  `DFD965177406DFF63621A3D1E805399C80D2C47DC4D0683D5D07C1C079F27CCA`;
- approved-card SHA-256:
  `A44ADC0CD9553E98BFC0DEC2CAD64C486598D7C87959AB1E29A0B96BE774BFFC`.

The independent reference suite passed `6/6`, pinning both executable sign-
disagreement directions, agreeing-sign abstention, tie boundaries, exact
endpoint/chained return identity, and fail-closed invalid input behavior.
The sole setfile locks `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`; no live/demo/shadow/stress set exists.

## Governed compile state

Ad-hoc strict compile correctly refused while factory `terminal64` processes
were alive (`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`). No process was stopped,
restarted, or bypassed. Governed compile work item
`b07f4a19-163f-467a-be56-7c10ff65a573` was source-hash verified and released
through the bounded compile-wave utility. At final inspection it remained
`pending`, unclaimed, attempt zero, with no verdict, EX5, or evidence path.
The dry-run and apply receipts are committed beside this report.

## Binding CPU stop

At `2026-09-05T03:58:40.5140317Z`, the required fresh five-sample
`Win32_PerfFormattedData_PerfOS_Processor` total-CPU window was:

```text
96, 94, 94, 92, 97 percent
average = 94.6 percent
maximum = 97 percent
binding ceiling = 97 percent
```

Admission requires both average and maximum to be strictly below 97%. The
maximum equals the ceiling, so no Q02 row, smoke, manual backtest, or terminal
operation was launched.

## Safe continuation boundary

Reuse compile work item `b07f4a19-163f-467a-be56-7c10ff65a573`; do not enqueue
a duplicate. After its governed compile/Q01 result is `COMPILED` with strict
build checks and only after a new five-sample CPU window has average and
maximum strictly below 97%, enqueue exactly the sole
`XTIUSD.DWX / D1 / RISK_FIXED=1000` Q02 set.

No portfolio gate, live/deploy manifest, live setfile, `T_Live`, AutoTrading,
or live state was touched.
