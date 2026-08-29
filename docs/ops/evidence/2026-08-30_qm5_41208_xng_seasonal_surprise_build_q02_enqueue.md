# QM5_41208 XNG seasonal-surprise build and Q02 enqueue

Date: 2026-08-30

Branch: `agents/board-advisor`

Outcome: `BUILT_COMPILE_OK_Q02_ENQUEUED_CPU_CEILING_BOUND_POST_ENQUEUE`

## Delivered edge

`QM5_41208_xng-seas-surprise-rv` is a structural low-frequency natural-gas
candidate. At the first normalized D1 broker-month boundary it measures the
just-completed XNG log return against five to ten valid returns for that same
calendar month in the exact prior ten years. It excludes the realized year,
uses an arithmetic mean and `n-1` sample standard deviation, and trades
contrarian only outside the strict `0.50+1e-10` z band until the next month.

This is not the certified book's incumbent `QM5_12567` logic: that sleeve is a
long-only, trend-filtered, two-day cumulative-RSI pullback with a five-bar hold.
The new identity is monthly, symmetric, seasonally adjusted, and oscillator-
free. That mechanical difference is not proof of low realized correlation;
unchanged Q09 remains the sole portfolio-overlap authority.

## Research and non-duplicate boundary

The card is supported by complete governed reads of Keloharju, Linnainmaa, and
Nyberg (2016), *Journal of Finance*, for same-calendar commodity information
with explicit natural-gas membership, and Mishra and Smyth (2016), *Economic
Modelling*, for direct natural-gas fixed-frequency contrarian evidence and its
adverse robustness caveat. No source performance or CFD equivalence transfers.

Canonical preallocation dedup was clean across 4,707 registry identities,
1,353 cards, and 45 Strategy Wiki nodes. Manual review separates the rule from
the incumbent RSI (`QM5_12567`), unconditional one-month fade (`QM5_20054`),
upcoming-month raw/Huber seasonal following (`QM5_20100`, `QM5_41205`), and
the two-leg metals surprise basket (`QM5_21517`).

Governed commits before this receipt:

- source approval: `c69176b43`;
- bounded extraction: `a6cb76267`;
- G0-approved card and identity: `69423f42d`;
- EA, magic/resolver, fixed-risk set, spec, and fixtures: `99a1d1120`.

The canonical schema amendment is hash-bound and adds validator headings only;
it changes no signal, side, risk, stop, spread, or lifecycle mechanic.

## Implementation and validation

- exact host/slot/magic: `XNGUSD.DWX`, D1, slot 0, `412080000`;
- sole preset: backtest `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`;
- frozen stop: `3.5*ATR(20,D1)`, no target;
- lifecycle: next normalized broker month, with 40-day stale repair;
- both news axes, legacy news, and Friday close: OFF;
- durable current-`yyyymm` consumption before history and every later gate;
- zero modeled spread reachable; crossed or over-3,000-point quotes rejected.

The independent suite passed 12 calendar, endpoint, exclusion, missing-year,
five-through-ten-sample, arithmetic, strict-boundary, side, quote, attempt,
lifecycle, card, setfile, registry, and resolver fixtures. Card-schema, G0,
execution-contract, spec, symbol-scope, and static build checks passed with no
candidate-specific failures. The execution-contract lint used the repository's
bounded `2026-08-29` calendar snapshot; the next-day full-registry expiry noise
was unrelated to this news-OFF candidate.

## Governed compile

Build task `e0c31390-cc4d-4dc7-92d8-1e0c183634f8` bound source SHA-256
`fd7245683b69696c55fbd73a4da19a6271b9543a5175fb679982f41fb1effbbb`
to compile item `e099e331-094c-4697-963f-3b10c1fadc23`. Target-only dry-run
and apply receipts released no other item.

The resident T10 worker returned:

- verdict: `COMPILE_OK`;
- strict compiler: 0 errors, 0 warnings;
- build check: PASS, 0 failures, 0 warnings;
- EX5 SHA-256:
  `041e31ea7de2c20e1891fb3d186a9a9785a185e06b93fe98fee00d88ec66ff68`;
- evidence:
  `D:/QM/reports/work_items/e099e331-094c-4697-963f-3b10c1fadc23/QM5_41208/COMPILE_EA/compile_evidence.json`.

No tester was launched by the build lane.

## Q02 enqueue and CPU stop

The five-sample pre-compile window averaged `90.75%` and peaked at `95.71%`.
The fresh pre-Q02 window averaged `83.93%` and peaked at `94.92%`. Both were
below the hard `97%` ceiling, so recording the successful build atomically
created exactly one Q02 item:

- work item: `a6496270-03b5-4036-bb4b-86d19071f0c7`;
- symbol/timeframe: `XNGUSD.DWX` / D1;
- setfile:
  `framework/EAs/QM5_41208_xng-seas-surprise-rv/sets/QM5_41208_xng-seas-surprise-rv_XNGUSD.DWX_D1_backtest.set`;
- readback: `pending`, attempt 0, unclaimed.

The immediate post-enqueue window averaged `88.52%` and peaked at `100%`,
crossing the hard ceiling. Work stopped. No manual dispatch, tester launch,
retry, terminal reservation, or additional pipeline phase was performed.

## Safety boundary

No AutoTrading state, live/demo/shadow/stress preset, `T_Live` control or
manifest, deploy manifest, portfolio gate, portfolio admission, or correlation
waiver was touched. Neither certification nor diversification is claimed before
downstream evidence.

Machine-readable receipt:
`artifacts/qm5_41208_build_q02_enqueue_20260830.json`.
