# QM5_41226 XAU/XAG median same-calendar build — Q02 CPU ceiling stop

Date: 2026-08-30 UTC

Branch: `agents/board-advisor`

Outcome: **BUILT AND COMPILE-PASS; Q02 NOT ENQUEUED BECAUSE THE GOVERNED
97% WHOLE-HOST CPU STOP WALL FIRED**

## Delivered edge

`QM5_41226_xauxag-medcal` is a structural, low-frequency,
market-neutral-style gold/silver relative-seasonality candidate. At the first
normalized `XAUUSD.DWX` D1 broker-month transition, it reconstructs the same
calendar month's synchronized XAU-minus-XAG log returns in exact years
`Y-1..Y-10`. Five to ten valid pairs are sorted and reduced to the ordinary
sample median: the middle observation for odd samples and the average of the
two central observations for even samples. A median above `+1e-12` buys XAU
and sells XAG; a median below `-1e-12` reverses the legs; the inclusive band is
flat and still consumes the month.

The package uses one aggregate `RISK_FIXED=1000` budget, split equally by
frozen per-leg `3.5*ATR(20,D1)` stop risk. `RISK_PERCENT=0` and
`PORTFOLIO_WEIGHT=1` are locked in the logical and both component build
presets. Entry is atomic with compensating close on a second-leg failure,
positions renew at the next broker-month boundary, and a 40-day stale repair
is retained. Both news axes and Friday flattening are off.

Opposite XAU/XAG legs target a different information object and position
shape than the book's outright XAU, SP500, NDX, and XNG exposures. This is not
a claim of dollar, beta, volatility, factor, market, or portfolio neutrality;
unchanged Q09 remains the only realized-correlation authority.

## Non-duplicate and governed basis

The canonical preallocation check returned CLEAN across 4,725 registry
identities, 1,363 cards, and 45 strategy-Wiki nodes. The central order
statistic is load-bearing:

- On `[0.01,0.01,0.01,0.01,-0.20]`, the raw-mean sibling sells XAU while
  this median rule buys XAU.
- On `[0.001,-0.20,-0.20,0.20,0.20]`, the binary sign-score sibling is flat
  while this median rule buys XAU.
- Unlike the Huber sibling, this rule accepts five through ten pairs and has
  no scale gate or iterative update; unlike the t-score sibling, it has no
  standard-error participation gate.

The reputable source basis is the complete governed peer-reviewed lineage
for same-calendar return seasonality (Keloharju, Linnainmaa, and Nyberg,
2016, *Journal of Finance*) and commodity cross-sectional monthly allocation
(Fuertes, Miffre, and Rallis, 2010, *Journal of Banking & Finance*). The exact
ordinary-median two-CFD conjunction, epsilon, costs, and lifecycle are
disclosed QM translations with no transferred performance claim.

Source approval commit: `01dd23e256e501cf0456a650b8a042130a27fb3e`.
Approved card/G0/EA-ID commit:
`cfc0f23c699d314385ecdf3897b3ca0e22132498`. Governed magic allocation
commit: `40e6e5e098c68041e953ecc2e8e6050d7b88876c`.

## Build and compile

Implementation commit `43515226f3018710dfa21c2273bab39b6141b955`
contains the EA, logical basket manifest, specification, 10-test independent
reference suite, fixed-risk presets, and compiled EX5.

Compile work item `d795d22d-1289-4f40-9fcf-585bbedc282d` was released with
an exact source-hash match and returned `COMPILE_OK`:

- compiler: zero errors and zero warnings;
- build check: PASS with zero failures and four nonfatal static warnings;
- MQ5 SHA-256:
  `b521d8569b42c3607dab63af8991c783d9de80cd4bbfbeaa7ec0329995cd16bb`;
- EX5 SHA-256:
  `48a311eebd07ace8cf22d8fc66af6d899493bbe54226671e853fffa5d89d390e`;
- compile evidence SHA-256:
  `2f5a8f87fb15b1abcb3e65b9b2a191e2fccf17ee3f3773838952505f52e2ced6`.

The call-graph-insensitive performance warning points at the two-bar host
`CopyRates` inside `Strategy_NormalizedHostSessions`; that function is reached
only from the new-bar decision path. The three card-undecidable warnings are
also nonfatal and did not infer or change any parameter. The independent
reference suite passed 10/10 after the worker refreshed the three build
hashes; card schema lint also passed.

## Binding Q02 stop

The mandatory five-sample whole-host CPU window ended at
`2026-08-30T11:06:24.2093529Z`:

`97.30%, 96.29%, 92.35%, 88.12%, 86.27%`

Average was `92.07%`; maximum was `97.30%`. The paced-fleet contract stops
when either value reaches the `97%` ceiling, so the maximum bound immediately.
The same read-only snapshot showed seven active work items across Q03, Q07,
Q10_NEWS, and OPT_CENSUS.

No `enqueue-backtest`, `record-build`, dispatcher, smoke, or tester command
was run after the stop. Readback for `QM5_41226` shows exactly one completed
`COMPILE_EA` row and zero Q02 rows. The card therefore records
`q01_status: PASS` and `q02_status: NOT_ENQUEUED_CPU_CEILING`.

A future paced worker may resume only after a fresh governed capacity check
passes, including a five-sample CPU window whose average and maximum are both
strictly below 97%. The supported handoff is:

```text
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_41226_xauxag-medcal --phase Q02
```

It must create one logical-basket Q02 row for
`QM5_41226_XAU_XAG_MEDCAL_D1`; neither component preset is a standalone
strategy or enqueue target.

## Safety boundary

No AutoTrading state, manual tester, `T_Live` control or manifest, deploy
manifest, portfolio gate, portfolio admission, correlation waiver, or
certification state was touched. No live-use or decorrelation claim is made.

Machine-readable receipts:

- `artifacts/qm5_41226_build_result_20260830.json`
- `artifacts/qm5_41226_q02_cpu_stop_20260830T110624Z_board_advisor.json`
