# WTI completed-month daily tail-trim momentum - Source Approval

Date: 2026-08-23

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if tester and whole-host CPU
ceilings permit. This decision does not authorize a manual tester dispatch.

Authority: the current explicit OWNER commodity/energy portfolio mission
delivered to Codex on branch `agents/board-advisor` on 2026-08-23. The mission
requires one new, non-duplicate, structural low-frequency commodity edge and
expressly permits a structural `XTIUSD` trend/seasonality carrier. It also
requires reputable-source criteria and `RISK_FIXED` backtests and excludes
live and portfolio-gate mutation.

## Candidate Identity

- proposed slug: `wti-mdaily-tailtrim-mom`
- proposed strategy ID: `MOP-WTI-MDAILY-TAILTRIM-MOM-2026_S01`
- proposed source ID: `MOP-WTI-MDAILY-TAILTRIM-MOM-2026`
- carrier: exact `XTIUSD.DWX`, D1, slot zero
- state: the immediately completed broker-calendar month's daily WTI log
  returns after deleting exactly its single minimum and single maximum return
- action: follow the sign of the remaining inner-return sum for one broker
  month
- lifecycle: one persisted attempt per broker month and first-later-month flat

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The following governed records were read completely before this approval:

1. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
   It preserves the complete-read evidence for Tobias J. Moskowitz, Yao Hua
   Ooi, and Lasse Heje Pedersen (2012), "Time Series Momentum," *Journal of
   Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`. The paper tests own-return continuation at
   monthly lags, renews positions monthly, and explicitly includes NYMEX WTI
   crude in its commodity universe.
2. `strategy-seeds/sources/MOP-WTI-TRIMMEAN-2026/source.md`, SHA-256
   `63F8C5FC06BAE2D90B50673C6B7B966FBAF5962150D70F695DD3DA8DBB221FA8`.
   This governed child fixes an auditable
   robust order-statistic convention: sort disjoint returns, delete declared
   tails, and trade the sign of the retained center. Its approved build uses
   twelve monthly returns, not daily returns inside one completed month.
3. `strategy-seeds/sources/MEHLITZ-MOP-WTI-MDAILY-PERSIST-MOM-2026/source.md`,
   SHA-256
   `62FB3C500F4176047667F5194A446BFA7C53B0D1F4D3E523F226449416D398F4`.
   This governed child
   supplies the already reviewed WTI completed-month packaging contract:
   exactly 17 through 23 daily returns ending inside the immediately completed
   month, one older boundary close, endpoint identity, a durable monthly
   attempt, and next-month lifecycle. Its alpha statistic is lag-one
   persistence, not trimming.

The bounded child extraction will be
`strategy-seeds/sources/MOP-WTI-MDAILY-TAILTRIM-MOM-2026/source.md`. It is the
card's single canonical `source_id`; the records above remain governed lineage
and implementation-boundary evidence.

Moskowitz, Ooi, and Pedersen support testing WTI own-return continuation and a
monthly formation/holding clock. The existing trimmed-mean packet supplies a
pre-result robust aggregation convention, and the completed-month packet
supplies an audited calendar/session boundary. None tests the exact daily
single-tail deletion below, a Darwinex continuous CFD, fixed-dollar ATR risk,
or the QM portfolio. Those are transparent QM falsification choices. No source
return, alpha, probability, density, trade count, risk, cost, CFD equivalence,
or portfolio-correlation result transfers.

## Locked Mechanic

1. Require exact `XTIUSD.DWX`, D1, slot zero, fixed-risk backtest inputs, both
   news axes OFF, and Friday close OFF.
2. On the first executable D1 bar of a new broker-calendar month, within 180
   elapsed minutes of the raw host-bar open, reconstruct every D1 close whose
   uniformly normalized label belongs to the immediately preceding calendar
   month plus one adjacent older close proving the left boundary. Require 17
   through 23 completed-month sessions, strictly ordered and unique. Exclude
   every current-month close.
3. Starting from the older boundary close, form exactly one chronological log
   return ending on every completed-month session:
   `r[j]=ln(close[j]/close[j-1])`. Require positive finite closes and finite
   returns. Verify that the raw return sum equals the direct boundary-to-final
   log return within `1e-10`.
4. Sort a copy of all `n` returns ascending. Delete exactly sorted index `0`
   and sorted index `n-1`; sum exactly indexes `1..n-2`:

   ```text
   raw_sum   = sum(r[j]), j=0..n-1
   inner_sum = sum(sorted[j]), j=1..n-2

   inner_sum > 0 => BUY XTIUSD.DWX
   inner_sum < 0 => SELL XTIUSD.DWX
   inner_sum = 0 or invalid state => FLAT
   ```

   Equal constituent returns are valid, including tied minimum or maximum
   values: the stable value order is irrelevant because exactly one array
   element at each endpoint is omitted. Neither `raw_sum` nor signal magnitude
   gates or scales the trade.
5. Persist the exact decision `yyyymm` attempt before every fallible downstream
   gate. History rejection, flat signal, spread/news/quote/ATR failure, order
   rejection, stop-out, or restart cannot retry that broker month.
6. Open at most one slot-zero WTI position with `RISK_FIXED=1000`,
   `RISK_PERCENT=0`, a frozen `3.5 * ATR(20,D1)` hard stop, no target, and a
   1,500-point entry-spread ceiling.
7. Close on the first tick of a later broker-calendar month or after forty
   calendar days. Malformed, duplicated, wrong-symbol, wrong-magic, or
   stopless owned exposure flattens immediately. Never retry, trail,
   partial-close, scale in, grid, martingale, or pyramid.

The single-observation-per-tail deletion is locked before any candidate result
and leaves 15 through 21 daily returns. It tests whether the central daily
return path, rather than either one-month endpoint or one extreme shock,
contains continuation information. It is not a fitted threshold, confidence
measure, volatility regime, or risk multiplier.

## Non-Duplicate Decision

The fail-closed canonical checker used the proposed slug, strategy ID, named
authors, complete mechanic, and actual Company Reference Wiki root. It scanned
4,630 registry identities, 1,298 repository cards, and 45 Strategy Wiki nodes,
found no exact or fuzzy collision, and returned `CLEAN`. Evidence:
`artifacts/qm5_wti_mdaily_tailtrim_mom_preallocation_dedup_20260823.json`.

Manual semantic review fixes the closest-family boundaries:

- `QM5_20187_wti-tsmom1m` follows the full completed-month endpoint return;
  one extreme daily shock can determine it. This candidate deletes the single
  best and worst daily returns before choosing direction.
- `QM5_20270_wti-trimmean-mom` sorts twelve disjoint completed monthly returns,
  deletes two observations per tail, and estimates a one-year central trend.
  This candidate sorts 17-23 daily returns from exactly one completed month,
  deletes one observation per tail, and holds only the next month.
- `QM5_41111_wti-mdaybreadth-mom` counts daily return signs and requires
  endpoint agreement. This candidate retains magnitudes, counts no signs, and
  deliberately does not require raw endpoint agreement.
- `QM5_41124_wti-mrms-coherence-mom` divides the raw monthly mean by daily RMS,
  and `QM5_41126_wti-mpath-eff-mom` divides the endpoint displacement by the
  full L1 path. Neither sorts or removes observations.
- `QM5_41127_wti-mdaily-persist-mom` centers daily returns and multiplies
  adjacent demeaned observations to gate the raw endpoint. This candidate
  uses no chronology after return construction, autocorrelation, centering,
  variance, or endpoint-direction gate.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only, short-horizon XNG
  oscillator pullback rather than symmetric monthly WTI robust momentum.

The exact WTI carrier, immediately completed calendar month, older boundary
close, every daily return ending in the month, ascending sort, single endpoint
deletion at each tail, inner-return sum, symmetric continuation, consumed
monthly attempt, fixed risk, and next-month exit are jointly load bearing.
Manual verdict:
`CLEAN_WTI_COMPLETED_MONTH_DAILY_SINGLE_TAIL_TRIM_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1 `PASS_WITH_WITHIN_MONTH_ROBUST_AGGREGATION_TRANSLATION_RISK`: one canonical
  governed child preserves a peer-reviewed JFE own-return source with DOI,
  complete-read evidence, durable hash, explicit WTI membership, and governed
  trimmed-statistic and completed-month lineage. The daily horizon and exact
  one-per-tail deletion are explicitly untested translations.
- R2 `PASS`: exact symbol, clock, month membership, session count, boundary,
  return orientation, endpoint identity, sort, deleted and retained indexes,
  zero handling, direction, attempt, risk, stop, spread gate, and lifecycle
  are fixed before testing.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history plus MT5 calendar, ATR, spread, quote, position,
  deal, and persistent state supplies every runtime input. Q02 owns history,
  holiday attrition, costs, financing, fills, and CFD-basis sufficiency.
- R4 `PASS`: runtime uses deterministic timestamps, logarithms, sorting,
  addition, comparison, ATR, and execution state only; no trained logic,
  banned signal, external runtime feed, grid, martingale, scale-in, or pyramid.

## Frequency, Portfolio Claim, And Falsification

Every valid nonzero completed month can qualify, giving a pre-result density
prior near twelve decisions per year. This is not market evidence. Q02 must
retire below five completed positions in any full post-warm-up year, at zero
trades, with nonpositive governed economics, or on any calendar, return,
sort, tail-deletion, side, attempt, risk, or lifecycle defect.

Direct WTI exposure is economically different from the certified XAU, SP500,
NDX, and XNG carriers but does not prove decorrelation. Q09 alone owns the
realized portfolio finding.

No weak result may be rescued by changing the tail count, retained indexes,
direction, return inclusion, carrier, hold, risk, or by adding an endpoint,
sign-count, persistence, volatility, seasonality, event, external, or
prior-result state.

## Implementation And Safety Boundary

Only one D1 backtest preset is permitted, with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, and `ENV=backtest`. No live, demo,
shadow, stress, or optimization preset is authorized. This approval forbids
manual backtests, terminal control, AutoTrading, `T_Live`, deploy or T_Live
manifest mutation, portfolio-gate changes, portfolio admission, decorrelation
claims, and correlation waivers. Strict Q01 must precede one Q02 enqueue, and
the fresh tester/host-CPU ceiling remains fail closed.
