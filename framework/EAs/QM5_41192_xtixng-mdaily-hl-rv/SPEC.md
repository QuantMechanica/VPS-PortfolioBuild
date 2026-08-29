# QM5_41192 `xtixng-mdaily-hl-rv`

## Contract

This EA implements only the approved Strategy Card at
`docs/strategy_card.md`: a monthly XTI/XNG relative-value package that fades
the exact Hodges-Lehmann-style pseudomedian of synchronized daily oil-minus-
gas log returns from the immediately completed broker month.

- Host / slot 0: `XTIUSD.DWX`, D1, magic `411920000`.
- Companion / slot 1: `XNGUSD.DWX`, D1, magic `411920001`.
- Logical tester symbol: `QM5_41192_XTI_XNG_MDAILY_HL_RV_D1`.
- Backtest risk: one aggregate `RISK_FIXED=1000` budget,
  `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- News axes and Friday close: OFF.
- Lifecycle: one consumed attempt per broker month; next-month exit; forty-day
  stale repair.

## Signal

At the first synchronized D1 bar of a genuine new broker month, within 180
minutes of the raw host bar open, copy 45 completed D1 bars for both legs.
Select all exactly synchronized pairs in the immediately completed month and
one adjacent older boundary pair. Require 17-23 completed-month sessions.

For chronological log-ratio levels
`s[j]=ln(XTI_close[j])-ln(XNG_close[j])`, form each adjacent return ending in
the completed month, `r[j]=s[j+1]-s[j]`. The sum of returns must equal the
older-boundary-to-final displacement within `1e-10`.

Enumerate every inclusive pair `(i,j)` with `i<=j` as
`w=(r[i]+r[j])/2`. Require exactly `n(n+1)/2` finite values, 153-276, and
prove each self-pair reproduces its source return. Sort ascending and use the
single center for an odd count or the arithmetic mean of the two centers for
an even count.

- positive pseudomedian: sell XTI / buy XNG;
- negative pseudomedian: buy XTI / sell XNG; and
- zero or invalid state: consume the month flat.

The raw endpoint and signal magnitude are diagnostic only.

## Risk And Atomicity

The EA uses completed `ATR(20,D1)` and frozen `3.5*ATR` broker stops on both
legs. It splits one aggregate fixed-risk budget and reduces only to target
equal absolute USD notionals. Realized mismatch may not exceed 20%. XTI is
submitted first and XNG second; a rejected or malformed second leg causes
immediate flattening with no retry. Entry spread ceilings are 1,500 XTI points
and 3,000 XNG points.

## Framework Alignment

- `Strategy_NoTradeFilter`: exact identity, host/timeframe, locked inputs,
  fixed risk, news/Friday contract, and cheap structural guards.
- `Strategy_EntrySignal`: synchronized completed-month reconstruction,
  endpoint identity, exact inclusive-pair pseudomedian, fixed-risk sizing, and
  atomic opposite-leg submission.
- `Strategy_ManageOpenPosition`: package composition/notional repair,
  next-month exit, and stale exit before entry gates.
- `Strategy_ExitSignal`: no additional signal exit; framework hard stops and
  kill switch remain authoritative.
- `Strategy_NewsFilterHook`: always false because both approved news axes are
  OFF.

## Artifacts And Boundary

The two per-leg setfiles are non-gating basket-plumbing diagnostics. Only the
logical-symbol setfile may be enqueued for Q02. The independent Python fixture
checks pseudomedian arithmetic, pair-count invariants, endpoint identity,
direction, persistent attempt semantics, card/set/manifest wiring, registry
rows, and resolver entries.

This build creates no live/demo/shadow/stress/optimization preset, deploy
manifest, portfolio-gate change, portfolio admission, or live entitlement.
