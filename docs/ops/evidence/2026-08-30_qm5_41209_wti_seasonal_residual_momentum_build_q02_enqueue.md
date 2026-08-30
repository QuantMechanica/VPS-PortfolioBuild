# QM5_41209 WTI seasonal-residual momentum build and Q02 enqueue

Date: 2026-08-30

Branch: `agents/board-advisor`

Outcome: `BUILT_COMPILE_OK_Q02_ENQUEUED`

## Delivered edge

`QM5_41209_wti-seas-resid-mom` is a structural, low-frequency WTI candidate.
At the first genuine D1 broker-month boundary it measures the just-completed
WTI monthly log return against five to ten valid returns for that same calendar
month in the exact prior ten years. It excludes the realized year, uses an
arithmetic mean and `n-1` sample standard deviation, and follows the residual
only outside the strict `0.50+1e-10` z band until the next month.

This is not another index, precious-metal, or incumbent XNG rule. It also
differs from existing WTI raw momentum and seasonal cards because it removes a
historical same-calendar expectation before applying a continuation side. That
mechanical and carrier distinction is not proof of low realized correlation;
unchanged Q09 remains the sole portfolio-overlap authority.

## Research and non-duplicate boundary

The card is supported by complete governed reads of Keloharju, Linnainmaa, and
Nyberg (2016), *The Journal of Finance*, for recurring same-calendar commodity
returns with explicit crude-oil membership, and Moskowitz, Ooi, and Pedersen
(2012), *Journal of Financial Economics*, for own-return continuation with
explicit WTI membership and a pooled one-month formation/hold commodity test.
The exact standardized residual conjunction, Darwinex CFD translation, and all
performance claims remain untested.

Canonical preallocation dedup was clean across 4,708 registry identities,
1,354 cards, and 45 Strategy Wiki nodes. Manual review separates the rule from
raw one-month WTI momentum (`QM5_20187`), upcoming-month same-calendar sign
(`QM5_20099`), seasonal/raw agreement (`QM5_20205`), fixed physical-season
reversal (`QM5_20229`), XNG residual reversion (`QM5_41208`), and the paired
XAU/XAG residual-reversion basket (`QM5_21517`).

Governed commits before this receipt:

- source approval: `a19955cc0`;
- bounded extraction: `d5a6cc40c`;
- G0-approved card and identity: `342cf22ca`;
- EA, magic/resolver, fixed-risk set, spec, and fixtures: `932d694c1`.

Farm approval normalized informational R1 tier and G0 reasoning only. It did
not change the committed signal, side, risk, stop, spread, or lifecycle.

## Implementation and validation

- exact host/slot/magic: `XTIUSD.DWX`, D1, slot 0, `412090000`;
- sole preset: backtest `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`;
- frozen stop: `3.5*ATR(20,D1)`, no target;
- lifecycle: next genuine broker month, with 40-day stale repair;
- both news axes, legacy news, and Friday close: OFF;
- current `yyyymm` is consumed before history and every later entry gate;
- nonnegative modeled spread is admitted only through 1,500 points; crossed
  quotes are rejected.

The independent suite passed 12 calendar, endpoint, exclusion, missing-year,
five-through-ten-sample, arithmetic, strict-boundary, side, quote, attempt,
lifecycle, card, setfile, registry, and resolver fixtures. Card-schema, G0,
execution-contract, spec, symbol-scope, and static build checks passed with no
candidate-specific issue. The execution-contract lint used the repository's
bounded `2026-08-29` calendar snapshot.

## Governed compile

Build task `a8ba8b13-1e33-453c-a3f0-d0f9bdfc1e95` bound source SHA-256
`0775c586e5fb92c1e9847fa60992f321b06a2dc85733b52b3c832f627cafd224`
to compile item `29a4f785-5281-4a42-b03f-d7619833e80d`. Target-only dry-run
and apply receipts released no other compile item.

The resident T5 worker returned:

- verdict: `COMPILE_OK`;
- strict compiler: 0 errors, 0 warnings;
- build check: PASS, 0 failures, 0 warnings;
- EX5 SHA-256:
  `45a0baa4cf8fb9d162afc18f9a54daf04b3ce2a71a13669f4443acdcb1d42f32`;
- evidence:
  `D:/QM/reports/work_items/29a4f785-5281-4a42-b03f-d7619833e80d/QM5_41209/COMPILE_EA/compile_evidence.json`.

No tester was launched by the build lane.

## Q02 enqueue and CPU boundary

The five-sample pre-compile window averaged `64.66%` and peaked at `66.72%`.
The fresh pre-Q02 window averaged `80.12%` and peaked at `91.55%`. Both were
below the hard `97%` ceiling, so recording the successful build atomically
created exactly one Q02 item:

- work item: `2e986e51-3d24-4346-b03d-d3dc82d6cdb9`;
- symbol/timeframe: `XTIUSD.DWX` / D1;
- setfile:
  `framework/EAs/QM5_41209_wti-seas-resid-mom/sets/QM5_41209_wti-seas-resid-mom_XTIUSD.DWX_D1_backtest.set`;
- readback: `pending`, attempt 0, unclaimed.

The immediate post-enqueue window averaged `68.53%` and peaked at `73.75%`,
also below the ceiling. No manual dispatch, tester launch, retry, terminal
reservation, or additional pipeline phase was performed.

## Safety boundary

No AutoTrading state, live/demo/shadow/stress preset, `T_Live` control or
manifest, deploy manifest, portfolio gate, portfolio admission, or correlation
waiver was touched. Neither certification nor diversification is claimed before
downstream evidence.

Machine-readable receipt:
`artifacts/qm5_41209_build_q02_enqueue_20260830.json`.
