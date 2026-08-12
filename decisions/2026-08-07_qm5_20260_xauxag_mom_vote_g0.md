# QM5_20260 XAU/XAG Multi-Horizon Momentum Vote G0 Authorization

Date: 2026-08-07

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch.

## Decision

Authorize one bounded V5 Strategy Card and non-live build for
`QM5_20260_xauxag-mom-vote`. At the first D1 bar of each genuine broker-month
transition, the candidate reconstructs thirteen synchronized consecutive
completed month ends for XAU and XAG. It compares the metals' arithmetic-
average simple monthly returns over the source-defined one-, three-, and
twelve-month formation horizons. It buys XAU and sells XAG when XAU wins at
least two ranks, and sells XAU and buys XAG when XAG wins at least two ranks.
An exact tie or invalid component consumes the month flat.

The candidate may proceed through source/card lint, deterministic registry and
magic allocation, resolver regeneration, strict compile, one logical-basket
`RISK_FIXED` backtest setfile and basket manifest, Q01 validation, and one
paced Q02 enqueue. This authorization does not pre-approve efficacy,
neutrality, diversification, decorrelation, certification, execution-contract
promotion, or portfolio admission.

## Source Boundary

The approved source of record will be
`strategy-seeds/sources/FMR-XAUXAG-MOMVOTE-2026/source.md`, bounded by the
completely reviewed repository packet
`strategy-seeds/sources/FMR-MOMTS-2010/source.md`:

- Fuertes, Ana-Maria, Joelle Miffre, and Georgios Rallis (2010), "Tactical
  Allocation in Commodity Futures Markets: Combining Momentum and Term
  Structure Signals," *Journal of Banking & Finance* 34(10), 2530-2548, DOI
  `10.1016/j.jbankfin.2010.04.009`.

The governed parent records a complete read of the 47-page accepted
manuscript, monthly cross-sectional commodity-momentum ranks, explicit one-,
three-, and twelve-month formation horizons, and a one-month holding period.
The repository already implements each horizon separately on XAU/XAG; no
horizon was selected from Darwinex results.

The two-of-three rank vote and two-metal CFD translation are transparent QM
hypotheses, not performance claims made by the paper. The source does not test
this vote, a two-name precious-metals subset, Darwinex continuous CFDs,
broker-month endpoint reconstruction, equal fixed-risk legs, ATR stops,
spread caps, persisted attempt state, or the QM portfolio. No source PF,
return, Sharpe ratio, drawdown, trade count, cost, neutrality, or correlation
statistic transfers.

## Locked Rule

For synchronized completed month-end closes in newest-to-oldest order
`C_i[0]..C_i[12]` for metal `i`, define the arithmetic-average simple return
over horizon `h` in `{1,3,12}`:

```text
A_i(h) = (1/h) * sum(C_i[k] / C_i[k+1] - 1, k=0..h-1)
D(h)   = A_XAU(h) - A_XAG(h)
vote   = sign(D(1)) + sign(D(3)) + sign(D(12))
```

Require synchronized timestamps, consecutive broker-month keys, positive
closes, finite arithmetic, and `abs(D(h)) > 1e-10` for every component. A
positive vote opens long XAU/short XAG; a negative vote opens short XAU/long
XAG. Vote magnitude does not change the fixed package-risk budget.

## Non-Duplicate Decision

The deterministic pre-allocation checker scanned 4,317 registry rows and 434
canonical intake cards. It found no exact slug or strategy-ID collision and
returned seven expected source/mechanic-family fuzzy neighbors. Manual review
resolves them:

- `QM5_20057_xauxag-xmom1`, `QM5_20184_xauxag-xmom3`, and
  `QM5_20050_xauxag-xmom12` rank one horizon alone. This candidate requires
  all three non-tied ranks and trades their fixed majority.
- `QM5_13126_energy-momcarry` ranks XTI/XNG on one-month momentum and a broker-
  swap proxy; `QM5_20051_energy-xmom1` ranks XTI/XNG on one month. Neither
  trades the XAU/XAG carrier or uses three formation ranks.
- `QM5_20258_wti-mom-vote` and `QM5_20259_xng-mom-vote` vote on one
  instrument's own cumulative return signs. This candidate instead votes on
  three cross-sectional XAU-minus-XAG average-return ranks and must execute an
  opposite two-leg basket.
- XAU/XAG ratio, residual, return-spread, volatility-rank, reversal, calendar,
  conditional-quantile, and single-horizon momentum EAs use different state
  variables or lifecycle rules.

A content-level scan of every intake card requiring both `XAUUSD.DWX` and
`XAGUSD.DWX` found no existing majority or vote mechanic. The exact two-metal
carrier, synchronized calendar-month endpoints, arithmetic-average ranks at
all three locked horizons, strict no-tie rule, majority mapping, shared-risk
opposite-leg package, consumed monthly attempt, and monthly renewal are jointly
load-bearing. Verdict: `CLEAN_AFTER_EXPECTED_FUZZY_AND_MANUAL_REVIEW`.

## Allocation And Kill Boundary

- intended EA ID: `QM5_20260`, subject to deterministic registry allocation;
- slug: `xauxag-mom-vote`;
- strategy ID: `FMR-MOMTS-2010_XAU_XAG_MAJ1312_S05`;
- intended slot 0: `XAUUSD.DWX` / magic `202600000`;
- intended slot 1: `XAGUSD.DWX` / magic `202600001`;
- cadence: at most one completed two-leg package per broker month after a
  thirteen-month-end warm-up; Q02 owns the realized density verdict;
- retire below five completed packages per full post-warm-up year;
- retire on unsynchronized or nonconsecutive month ends, wrong simple-return
  orientation, wrong horizon average or vote, entry with a tied component,
  repeated monthly attempt, non-opposite legs, aggregate-risk breach, orphan
  persistence, invalid risk mode, missing hard stop, or nonpositive governed
  economics;
- no post-result horizon, vote, tie threshold, stop, spread, retry, direction,
  weighting, or carrier rescue is authorized.

## Safety Boundary

This authorization excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; `T_Live`; AutoTrading; deploy or T_Live manifests;
portfolio admission; portfolio-gate edits; and correlation waivers. Q02 uses
exactly one logical basket setfile with `RISK_FIXED=1000`, `RISK_PERCENT=0`,
and `PORTFOLIO_WEIGHT=1`.
