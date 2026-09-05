# QM5_41339 WTI ADF-LZ76 Agreement - Q02 CPU-Ceiling Stop

**Date:** 2026-09-05  
**Branch:** `agents/board-advisor`  
**Outcome:** one new non-duplicate structural WTI edge was source-approved,
carded, allocated, and source-built. Its governed compile was enqueued, then
the mission stopped before compile release and Q02 because the binding CPU
ceiling was hit.

## Edge delivered

`QM5_41339_wti-adf-lz-agree-tr` is a direct `XTIUSD.DWX` D1 energy sleeve.
Once per broker month it reconstructs sixty completed monthly WTI log closes
and trades the newest twelve-month direction only when both states qualify:

- lag-one intercept/no-time-trend ADF t statistic is at least `-2.594`;
- exact LZ76 exhaustive-history complexity of the newest twenty monthly
  return signs is at most six.

The month is consumed before fallible gates. The sole backtest set locks
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`, with frozen
ATR(20) x 3.5 stop, no target, and next-month lifecycle.

This is distinct from the single ADF (`41319`), single LZ76 (`41309`),
ADF-KPSS (`41336`), ADF-spectral-entropy (`41337`), and ADF-raw-von-Neumann
(`41338`) implementations. LZ76 uses variable-length phrase novelty rather
than partial sums, frequency power, or successive-return dispersion. Shared
WTI continuation may still correlate; Q09 has no waiver.

## Durable repository evidence

- source packet, retrieval receipt, approval, and preallocation dedup:
  `67b4040d7b`;
- atomic identity reservation: `db7e481a12`;
- approved card and G0 decision: `e735809bd9`;
- governed magic/resolver allocation and EA-local card: `20d78f3d2e`;
- MQ5, SPEC, three-test independent reference model, and fixed-risk set:
  `99334157f0`.

Pinned build inputs:

- MQ5 SHA-256:
  `95A9C04867100145D7D937EF5D99269C56079877DB58EE783FA097F3711E59AB`;
- setfile SHA-256:
  `2B4933027C360A49F2CC5897F092D6EF4AF0A842AA703889BF550FBEB9A841DB`;
- approved-card SHA-256:
  `7890F87327A2C81207C18017069AD15702AEBC959DC8BA81FF0034A20D280516`.

Card schema lint passed with no missing sections or ML hits. The independent
reference suite passed `3/3`; it pins the LZ76 phrase example, the inclusive
six/seven complexity boundary, ADF arithmetic, fixed risk, joint gate, and
magic. Static forbidden-pattern grep returned no hit.

## Governed compile and Q02 state

Ad-hoc strict compile/build-check correctly refused while `terminal64`
processes were alive (`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`). No terminal was
stopped, restarted, or bypassed. Governed compile work item
`d79fa1aa-f91e-4d47-ac34-58633ce5eddf` is pending, unclaimed, attempt zero,
under `COMPILE_EA_WORKER_ROLLOUT_PENDING`, with no verdict, EX5, or evidence
path. The runtime census contains exactly this one `COMPILE_EA` row for
`QM5_41339` and no Q02 row.

## Binding CPU stop

At `2026-09-05T02:57:07.5313151Z`, the required fresh five-sample
`Win32_PerfFormattedData_PerfOS_Processor` total-CPU window was:

```text
98, 80, 98, 99, 100 percent
average = 95.0 percent
maximum = 100 percent
binding ceiling = 97 percent
```

Although the average was below the ceiling, the maximum was not strictly
below 97%. Per the mission instruction, the compile hold was not released and
no smoke, manual backtest, or Q02 work item was launched.

## Safe continuation boundary

Reuse compile work item `d79fa1aa-f91e-4d47-ac34-58633ce5eddf`; do not enqueue
a duplicate. Only after a fresh five-sample window has both average and
maximum strictly below 97% may the standard rollout hold be released. After
strict compile/Q01 PASS, bind the resulting build hash and enqueue exactly the
sole `XTIUSD.DWX / D1 / RISK_FIXED=1000` Q02 set.

No portfolio gate, live/deploy manifest, live setfile, `T_Live`, AutoTrading,
terminal-control, or live state was touched.
