# QM5_41206 XAU/XAG same-calendar Huber build and Q02 enqueue

Date: 2026-08-29

Branch: `agents/board-advisor`

Outcome: `BUILT_COMPILE_OK_Q02_ENQUEUED_CPU_CEILING_BOUND_POST_ENQUEUE`

## Delivered edge

`QM5_41206_xauxag-samecal-huber10` is a low-frequency market-neutral-style
precious-metals relative-value candidate. At the first `XAUUSD.DWX` D1
broker-month transition it requires exact synchronized completed XAU-minus-XAG
log returns for the same calendar month in years `Y-1..Y-10`. It forms the
even median and raw even MAD, freezes `scale=1.4826*MAD` and
`delta=1.5*scale`, runs exactly 32 Huber reweighted-location updates, and
holds an opposite-leg basket in the final sign until the next month.

This is structurally different from an outright XAU, index, or energy sleeve:
positive location buys XAU and sells XAG; negative location reverses the
legs. That design does not prove dollar, beta, volatility, factor, market, or
portfolio neutrality. Unchanged Q09 remains the only realized-correlation
authority.

Canonical preallocation dedup scanned 4,705 registry identities, 1,351 cards,
and 45 wiki nodes. It found no exact identity and surfaced the expected raw
mean, signed-rank, WTI-Huber, and XNG-Huber neighbors. On the locked ten-value
fixture the new Huber location is `-0.00031225666666666747`, while the raw
mean is positive and centered strict signed-rank score is `+3`; the two nearby
XAU/XAG estimators therefore take the opposite package side.

## Governance and implementation

- Peer-reviewed lineages: Keloharju, Linnainmaa, and Nyberg (2016), *Journal
  of Finance*; Fuertes, Miffre, and Rallis (2010), *Journal of Banking &
  Finance*; Huber (1964), *Annals of Mathematical Statistics*.
- Durable source approval commit: `342e07a71`.
- Approved G0 card and deterministic identity commit: `7c16fa21c`.
- EA, magics, resolver, logical basket manifest, reference fixtures, spec, and
  fixed-risk preset commit: `675ec9628`.
- Active slots: XAU slot 0 / magic `412060000`; XAG slot 1 / magic
  `412060001`.
- Sole Q02 package risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, split into two fixed stop-risk halves.

The executable endpoint reconstruction scans chronological completed D1 bars,
uses the last target-month close over the prior-month close, requires a
confirming following-month bar, and matches prior/target/following timestamps
across both legs. Missing any exact year fails the whole month; no later year
substitutes for it.

The independent suite passed 11 deterministic calendar, endpoint,
synchronization, exact-year, Huber-arithmetic, disagreement, attempt,
lifecycle, card, setfile, registry, resolver, and basket-manifest fixtures.
Card-schema, G0, execution-contract, spec, basket symbol-scope, array/bounds,
MAE-hook, setfile, and static build gates had no candidate-specific failures.

## Governed compile

Build task `02942676-738f-45e9-9be6-6d7d5f6fd6ae` bound source SHA-256
`df3150c19e72716c78a0f9fd4f0952350f676b32baecdd4b8bc5f3b3184094fd`
to compile item `25c25747-2490-442f-9ed4-455ddacd10e2`. Target-only dry-run
and apply receipts released no other item.

The resident T2 worker returned:

- verdict: `COMPILE_OK`;
- strict compiler: 0 errors, 0 warnings;
- build check: PASS, 0 failures, 0 warnings;
- EX5 SHA-256:
  `581e05eaeb136c6289284e7d6e9bc17eaf6027fc9def8bde354ea87a5bb7f347`;
- evidence:
  `D:/QM/reports/work_items/25c25747-2490-442f-9ed4-455ddacd10e2/QM5_41206/COMPILE_EA/compile_evidence.json`.

The worker generated standard per-symbol compilation presets in addition to
the logical basket preset. They are build artifacts only: neither component
was enqueued or treated as a standalone strategy.

## Q02 enqueue and CPU stop

The five-sample pre-compile window averaged `79.18%` and peaked at `80.77%`.
The fresh pre-Q02 window averaged `80.86%` and peaked at `83.61%`. Both were
below the hard `97%` ceiling, so recording the successful build atomically
created exactly one logical-basket Q02 item:

- work item: `fc00fd9e-98ea-44aa-8502-2f7cf40919ae`;
- symbol/timeframe: `QM5_41206_XAU_XAG_SAMECAL_HUBER10_D1` / D1;
- logical setfile:
  `framework/EAs/QM5_41206_xauxag-samecal-huber10/sets/QM5_41206_xauxag-samecal-huber10_QM5_41206_XAU_XAG_SAMECAL_HUBER10_D1_D1_backtest.set`;
- readback: `pending`, attempt 0, unclaimed;
- component Q02 items: zero.

The immediate post-enqueue window averaged `95.04%` and peaked at `98.35%`,
crossing the ceiling once. Work stopped at that point. No manual dispatch,
tester launch, retry, terminal reservation, or further pipeline action was
taken.

## Remaining falsification risks

- Exact ten-year warm-up and cross-leg synchronization can produce zero or
  sub-floor activity if either history is incomplete.
- Continuous-CFD session labels, financing, roll construction, legging, and
  futures/CFD basis remain empirical translation risks.
- Opposite legs are market-neutral-style plumbing, not proof of low portfolio
  correlation. Q09 must reject excessive overlap.

## Safety boundary

No AutoTrading state, live/demo/shadow/stress preset, `T_Live` control or
manifest, deploy manifest, portfolio gate, portfolio admission, or
correlation waiver was touched. Neither certification nor diversification is
claimed before downstream evidence.

Machine-readable receipt:
`artifacts/qm5_41206_build_q02_enqueue_20260829.json`.
