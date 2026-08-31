# QM5_41237 WTI same-calendar Cauchy build — CPU ceiling stop

Date: 2026-08-31

Branch: `agents/board-advisor`

Outcome: `SOURCE_BUILD_COMMITTED_STATIC_Q01_PASS_COMPILE_Q02_DEFERRED_CPU_CEILING`

## Delivered edge

`QM5_41237_wti-samecal-cauchy5` is a low-frequency direct-WTI structural
calendar candidate. At the first genuine normalized `XTIUSD.DWX` D1
broker-month transition into `(Y,M)`, it reconstructs the completed WTI log
return for the same named month in exact years `Y-5..Y-1`. All five returns
are mandatory.

The EA starts at the odd median, freezes `scale=1.4826*MAD`, and executes
exactly 32 Cauchy derivative-weight updates:

```text
u[i]      = (r[i] - mu[j]) / scale
weight[i] = 1 / (1 + u[i]^2)
mu[j+1]   = sum(weight[i] * r[i]) / sum(weight[i])
```

It buys only above `+1e-12`, sells only below `-1e-12`, and consumes the
month flat at equality or on any invalid state. The attempt is persisted
before history and entry gates. A position holds to the next normalized
broker month behind a frozen `3.5*ATR(20,D1)` hard stop, with 40 elapsed days
as survivor repair.

Direct WTI is outside the certified XAU/SP500/NDX/XNG carrier set. This is a
structural diversification objective only; unchanged Q09 remains the sole
authority for realized overlap and portfolio value.

## Governance and non-duplicate evidence

The source packet combines complete peer-reviewed same-calendar commodity and
WTI own-return lineages with official SciPy Cauchy-loss documentation. The
five-return derivative-weight conjunction, continuous CFD, scale, update
count, epsilon, stop, spread, and lifecycle are disclosed pre-result QM
choices. No source performance, CFD equivalence, or correlation result
transfers.

The corrected-root canonical dedup receipt scanned 4,736 registry identities,
1,374 cards, and 45 Strategy Wiki nodes, found no exact identity, and returned
only expected same-calendar robust-location neighbors. On
`[-0.080,-0.050,-0.001,+0.005,+0.010]`, the locked Cauchy path buys from
approximately `+0.001385877861`; raw mean, median, trim, Winsor, trimean,
midhinge, bisquare, and Hampel peers sell. Bisquare is approximately
`-0.001228911486` and Hampel approximately `-0.017078133333`. Sign reflection
reverses the strict mapping.

The governed identity is `QM5_41237`, slot 0, magic `412370000`. Relevant
branch commits are:

- source approval: `db875341a`;
- bounded source packet: `f2cdeefd3`;
- ID reservation: `2a8ec789d`;
- approved G0 card: `5f71420d2`;
- magic allocation and local card: `8918c3027`;
- EA, SPEC, and fixed-risk preset: `e213ccea9`;
- independent reference tests and SPEC conformance: `7e9da1d91`.

## Build and static validation

The branch contains the complete `.mq5`, one D1 backtest preset, SPEC, local
byte-identical card, registry row, resolver binding, and independent fixtures.
The sole preset locks `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`; its build hash remains `pending` until strict governed
compilation.

- independent reference suite: 11 passed;
- governed allocator/precheck suite: 17 passed;
- card schema lint: PASS;
- SPEC validation: PASS;
- strategy-entry validation: PASS;
- raw-source quarantine validation: PASS;
- scoped static build guardrails: PASS, zero findings.

The active factory correctly refused the ad-hoc build-check compile route and
directed compilation to a bound `COMPILE_EA` item. No retry was attempted.

## CPU ceiling stop

Immediately before governed compile, the mandatory whole-host five-sample
window at `2026-08-31T00:10:11.6040536Z` was:

`100.0000%, 100.0000%, 99.9028%, 99.3178%, 99.4150%`

Average was `99.7271%` and maximum was `100.0000%`, both above the `97%` hard
ceiling. The snapshot contained seven terminal processes and five MetaTester
processes. Work stopped as required.

No `COMPILE_EA` item was created, no strict compiler was launched, no `.ex5`
was produced, and Q02 was not enqueued. The remaining step is a fresh CPU
window below the ceiling, followed by governed compile, zero-error/zero-warning
Q01 completion, and exactly one Q02 enqueue.

## Safety boundary

No tester, dispatcher, AutoTrading state, `T_Live` control or manifest,
deploy manifest, portfolio gate, portfolio admission, correlation waiver, or
certification state was touched. No live-use or decorrelation claim is made.

Machine-readable receipt:
`artifacts/qm5_41237_build_cpu_stop_20260831.json`.
