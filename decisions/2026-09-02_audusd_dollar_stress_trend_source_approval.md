# AUDUSD Dollar-Stress Trend Continuation - Source Approval

Date: 2026-09-02

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced Q02 enqueue. Enqueue does not authorize a manual tester run or work
above the whole-host CPU ceiling.

Authority: the current explicit OWNER diversity and funnel-throughput mission
on branch `agents/board-advisor`. Exhaustive farm-state and repository review
found no collision-free approved diverse build and no genuine diverse
Q02-Q03 infrastructure recovery. The mission therefore authorizes exactly one
new structural, low-frequency edge on an instrument absent from the certified
book, under reputable-source and `RISK_FIXED` constraints.

## Candidate Identity

- proposed slug: `audusd-dollar-stress-tr`
- proposed strategy ID:
  `AI-CODEX-AUDUSD-DOLLAR-STRESS-TREND-20260902_S01`
- proposed source ID: `AI-CODEX-AUDUSD-DOLLAR-STRESS-TREND-20260902`
- proposed symbol / host: exact `AUDUSD.DWX`, D1, slot 0
- signal family: short-only global-dollar-stress continuation, requiring
  synchronized SP500 stress, broad USD strength, and an AUDUSD channel break

The deterministic registry owns the EA ID. This decision neither predicts nor
reserves an identity.

## Approved Source Basis

The bounded source packet at
`strategy-seeds/sources/AI-CODEX-AUDUSD-DOLLAR-STRESS-TREND-20260902/source.md`
was read completely and preserves four inputs:

1. the complete OWNER Orthogonal Return Sources Program, including candidate
   14's exact D1 mechanization brief;
2. the complete official AEA metadata and abstract for Avdjiev, Du, Koch, and
   Shin (2019), DOI `10.1257/aeri.20180322`;
3. the complete official AEA metadata and abstract for Maggiori (2017), DOI
   `10.1257/aer.20130479`; and
4. the complete local adverse result that simple SP500-to-AUDUSD next-day
   lead-lag and beta-reversion forms are not tradeable out of sample.

The public-source scope is deliberately narrow: official abstracts support a
global-dollar funding/risk-sharing carrier, not this trading rule. The exact
daily conjunction, AUDUSD carrier, windows, thresholds, ATR lifecycle,
activity, costs, and portfolio effect are transparent pre-result
QuantMechanica synthesis. Q02 must establish activity and economics, Q04 must
establish temporal robustness, and Q09 alone may establish complementarity.

## Locked Mechanic

At each new exact `AUDUSD.DWX` D1 bar, align the latest completed D1 bar across
AUDUSD, EURUSD, GBPUSD, and SP500 and use no current/incomplete observation.

1. Require SP500's completed close `S0` strictly below the arithmetic mean of
   `S1..S50` and `S0/S20-1 < 0`.
2. Require the mean of `C0/C5-1` for EURUSD, GBPUSD, and AUDUSD to be at most
   `-0.010`.
3. Require AUDUSD's completed close strictly below the minimum of its prior
   twenty completed lows, excluding the signal bar.
4. Open one market SELL only. Attach a hard stop at entry plus two times the
   signal-bar `ATR(14,D1)` under fixed-dollar risk.
5. On each later completed D1 bar, tighten but never loosen the stop to that
   bar's close plus two times its completed `ATR(14,D1)`. Exit after ten D1
   bar shifts or as soon as any SP500 or broad-USD gate clears.
6. No long, retry loop, same-bar re-entry, averaging, scale-in, pyramid, grid,
   martingale, take-profit, external feed, or current-bar reference is
   permitted. Friday close and both news axes are OFF.
7. Q02-Q10 use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
   `PORTFOLIO_WEIGHT=1`.

The baseline trades only AUDUSD. NZDUSD is a potential distinct future
carrier, not part of this approval.

## Non-Duplicate Decision

The corrected canonical checker scanned 4,782 registry identities, 1,418
card files, and all 45 Strategy Wiki nodes. It returned `CLEAN`; evidence:
`artifacts/qm5_audusd_dollar_stress_preallocation_dedup_20260902.json`,
SHA-256
`5EA79E6A5AC8FE6F4187C8F0F6118F9BE550804E297B8D1CB43975D222377F2E`.

Manual semantic review fixes the load-bearing distinctions:

- `QM5_1013_lien-20day-breakout` is a generic direct-price breakout family;
  it has no synchronized SP500 stress and three-pair broad-dollar conjunction.
- `QM5_20292` and its carry-unwind siblings express volatility-gated JPY/CHF
  carry baskets, not AUDUSD dollar-funding continuation.
- `QM5_12580` fades broad-USD exhaustion; its economic sign is the opposite
  of this strict risk-off continuation rule.
- Generic AUDUSD D1 trend cards do not require the same SP500 50-day/20-day
  regime plus three-cross five-day USD breadth gate.
- The local dead SP500 lead-lag/RV study is not duplicated: this rule makes no
  next-day cross-asset forecast and uses AUDUSD's own channel break for entry.

Verdict:
`DISTINCT_AUDUSD_D1_SHORT_ONLY_SYNCHRONIZED_SP500_STRESS_BROAD_USD_CHANNEL_BREAK`.

## Reputable-Source Criteria

- R1 `PASS_WITH_UNTESTED_MECHANIZATION`: complete OWNER ticket plus official
  peer-reviewed-journal abstracts establish the research lane and structural
  carrier; no source trading result transfers.
- R2 `PASS`: aligned closed-bar endpoints, strict/equality boundaries, side,
  hard stop, monotone trail, gate/time exits, fixed risk, and activity floor
  are deterministic and locked.
- R3 `PASS`: registered exact AUDUSD/EURUSD/GBPUSD/SP500 `.DWX` D1 data are
  native runtime inputs; only AUDUSD can be traded.
- R4 `PASS`: fixed completed-OHLC arithmetic, ATR, quotes, positions, and V5
  framework state only; no ML, banned indicator, external signal, grid,
  martingale, averaging, or pyramid.

## Activity And Kill Boundary

The source program's approximately ten annual trades is only an ordering
prior. Retire zero trades or fewer than five distinct entry days in any full
post-warm-up year. Retire nonpositive governed economics, walk-forward or
stress failure, timestamp misalignment, signal-bar leakage, equality drift,
wrong side, missing hard stop, loosening trail, retry/scale-in, or wrong risk
mode. No post-result parameter rescue is authorized.

## Safety Boundary

Approved: one registered identity, one source/card extraction, one non-live
build, pure reference checks, strict Q01, one canonical `RISK_FIXED` AUDUSD D1
backtest set, and one paced Q02 enqueue if fresh CPU admission allows.

Not approved: manual backtests, optimization, live/demo/shadow/stress presets,
portfolio admission, portfolio-gate edits, correlation waivers, deploy/live
manifests, `T_Live`, AutoTrading, terminal control, or work above Q02.
