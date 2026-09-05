# QM5_41338 WTI ADF–von Neumann Agreement — Q02 CPU-Ceiling Stop

**Date:** 2026-09-05

**Branch:** `agents/board-advisor`

**Outcome:** one new, non-duplicate structural commodity edge was source-approved,
carded, allocated, and source-built. Its governed compile was enqueued, then the
mission stopped before compile release and Q02 because the binding host CPU ceiling
was hit.

## Edge delivered

`QM5_41338_wti-adf-vn-agree-tr` is a direct `XTIUSD.DWX` D1 energy sleeve.
Once per broker month it reconstructs 60 completed monthly WTI log closes and
trades the newest 12-month return direction only when both structural state tests
agree:

- the lag-one, intercept-only ADF t statistic is at least `-2.594`;
- the raw von Neumann ratio of the newest 20 monthly log returns is strictly below
  `2.0`.

This conjunction is not the existing single-ADF, single-von-Neumann, ADF-KPSS,
or ADF-spectral-entropy implementation. Fixed fixtures cover bullish and bearish
agreement plus both one-gate disagreement directions, which remain flat. The sole
backtest set is locked to `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`, with ATR(20) x 3.5 stop distance and a monthly lifecycle.

## Durable repository evidence

- source packet, retrieval receipt, approval, and preallocation dedup:
  `76a71f1c22`;
- approved card, G0 decision, fixture, and EA identity reservation:
  `328ac4ee3e`;
- governed magic/resolver allocation and EA-local card mirror: `be0d0e6894`;
- MQ5, SPEC, independent oracle tests, and fixed-risk set: `85a18bd00f`.

Pinned build-input hashes:

- MQ5 SHA-256:
  `405202F5FA354429F767ED54C5D2A51D020A31A2E1BE876A1D2DFA0826A98AD5`;
- setfile SHA-256:
  `03619AA900FBDFA2E08D84DC85E7F1E8EF2935272E8BC38B01892DA771056717`;
- approved-card SHA-256:
  `F02EC8CB3FC01F850EE29FF395A4FE53A9BF48FC9922B6A57FDF6587FF17DB4A`.

The independent reference suite passed all three tests. Card schema lint passed
with no ML hits, and the generated registry allocation is `413380000` for
`XTIUSD.DWX` slot 0.

## Governed compile state

The local strict compile and build-check correctly refused the ad-hoc include
mirror while `terminal64` processes were alive
(`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`). No terminal was stopped, restarted, or
bypassed. The source-fresh governed compile row is:

- work item: `779b4e98-8ef6-4918-8903-07d074a8c523`;
- status: `pending`, unclaimed, attempt 0;
- activation hold: `COMPILE_EA_WORKER_ROLLOUT_PENDING`;
- compile verdict / EX5 / evidence path: none.

This is a governed capacity handoff, not a compile PASS or Q01 verdict.

## Binding CPU stop

At `2026-09-05T01:21:01Z` through `01:21:06Z`, the required fresh five-sample
`Win32_PerfFormattedData_PerfOS_Processor` total-CPU window was:

```text
92, 100, 100, 99, 100 percent
average = 98.2 percent
maximum = 100 percent
binding ceiling = 97 percent
```

Both the average and maximum violated the strict-below-97% admission rule. Per
the mission instruction, the compile hold was not released and no smoke,
backtest, or Q02 row was launched. The runtime census contains exactly the one
pending compile item for `QM5_41338` and no backtest item.

## Safe continuation boundary

On a later paced wake, re-use compile work item
`779b4e98-8ef6-4918-8903-07d074a8c523`; do not enqueue a duplicate. Only after a
fresh five-sample window has both average and maximum strictly below 97% may its
standard rollout hold be released. After strict `COMPILE_OK`, run the bounded Q01
smoke, record/review the hash-bound build, and enqueue exactly the sole
`XTIUSD.DWX / D1 / RISK_FIXED=1000` Q02 set.

No portfolio gate, `T_Live` manifest, live setfile, AutoTrading setting, or live
deployment state was touched.
