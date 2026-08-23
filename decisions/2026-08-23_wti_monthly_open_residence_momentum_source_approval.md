# WTI completed-month fixed-open residence momentum - Source Approval

Date: 2026-08-23

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if tester and whole-host CPU
ceilings permit. This decision does not authorize a manual tester dispatch.

Authority: the current explicit OWNER commodity/energy portfolio mission
delivered to Codex on branch `agents/board-advisor` on 2026-08-23. The mission
requires one new, non-duplicate, structural low-frequency commodity edge,
expressly permits a structural `XTIUSD` trend/seasonality edge, requires
reputable-source criteria and `RISK_FIXED` backtests, and excludes live and
portfolio-gate mutation.

## Candidate identity

- proposed slug: `wti-mopen-residence-mom`
- proposed strategy ID: `MOP-WTI-MOPEN-RESIDENCE-MOM-2026_S01`
- proposed source ID: `MOP-WTI-MOPEN-RESIDENCE-MOM-2026`
- carrier: exact `XTIUSD.DWX`, D1
- state: at least three quarters of the immediately completed month's closes
  remain strictly on the final endpoint side of the prior month-end close
- action: follow the sign of the completed-month endpoint return
- lifecycle: one persisted attempt per broker month and first-later-month flat

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved source basis

The following governed records were read completely before this approval:

1. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
   It preserves the complete 23-page published-paper review of Tobias J.
   Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen (2012), "Time Series
   Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`. Its retrieval receipt records the
   author-hosted PDF, 23 pages, 976,459 bytes, and PDF SHA-256
   `7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.
2. `strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-MOPEN-RESIDENCE-RV-2026/source.md`,
   SHA-256
   `CB9B22CA3B0EAAD7AB3D606E1E07C1A049D80C6AD0D09EAF5394093C16D35D32`.
   This already approved bounded packet fixes auditable close-residence
   counting, exact-tie handling, integer ceiling arithmetic, and a monthly
   lifecycle for a different two-leg metals carrier. It supplies statistic
   lineage only; its carrier, side, and any result do not transfer to WTI.

Moskowitz, Ooi, and Pedersen test each instrument's own monthly return at lags
one through sixty, report positive continuation over the first twelve lags,
explicitly report a `k=1`, `h=1` commodity-futures portfolio, renew monthly,
and include NYMEX WTI. They do not report a WTI-specific one-month result and
do not test the within-month fixed-open residence gate below.

The bounded child extraction will be
`strategy-seeds/sources/MOP-WTI-MOPEN-RESIDENCE-MOM-2026/source.md`. It is the
card's single canonical `source_id`; the parent records remain its governed
lineage.

The trading paper supports a WTI own-return continuation hypothesis and a
monthly formation/holding clock. The D1 path reconstruction, prior-month-end
anchor, three-quarter gate, Darwinex continuous CFD, broker-calendar labels,
fixed cash risk, ATR stop, spread cap, attempt ledger, and lifecycle controls
are transparent QM falsification choices. No source return, alpha,
probability, density, profit factor, drawdown, transaction cost, CFD
equivalence, or portfolio-correlation statistic transfers.

## Locked mechanic

1. Require exact `XTIUSD.DWX`, D1, slot zero, fixed-risk backtest inputs, both
   news axes OFF, and Friday close OFF.
2. On the first executable D1 bar of a new broker-calendar month, within 180
   elapsed minutes of the raw current bar open, reconstruct every completed D1
   close labeled with the immediately preceding calendar month. Require 17
   through 23 unique month-session closes in strict chronological order plus
   one immediately older close from the adjacent prior calendar month. Exclude
   every current-month close.
3. Let the older boundary close be `P` and the chronological completed-month
   closes be `Q[0]..Q[n-1]`. Require every close to be positive and finite.
   Count `above = count(Q[j] > P)` and `below = count(Q[j] < P)` over all `n`
   month closes. Exact ties remain in the denominator and count toward neither
   side. Set `required = ceil(3*n/4) = (3*n+3)//4` using integers.
4. Verify that `N=log(Q[n-1]/P)` is finite and equals the sum of all
   chronological log returns from `P` into each month close within `1e-10`.
   Qualify long only when `above>=required` and `N>0`; qualify short only when
   `below>=required` and `N<0`. Equality, insufficient residence, endpoint
   disagreement, malformed history, or invalid arithmetic consumes the month
   flat. Residence surplus and return magnitude never alter risk.
5. Persist the exact decision `yyyymm` attempt before every fallible downstream
   gate. Rejection, order failure, stop-out, or restart cannot retry that month.
6. Open at most one WTI position with aggregate `RISK_FIXED=1000`, a frozen
   `3.5 * ATR(20,D1)` server-side hard stop, no target, and a 1,500-point entry
   spread ceiling.
7. Close on the first tick whose broker `yyyymm` is later than the entry
   attempt month or after forty calendar days. Malformed, duplicated, wrong-
   magic, wrong-symbol, or stopless owned exposure flattens immediately. Never
   retry, trail, partial-close, scale in, grid, martingale, or pyramid.

## Non-duplicate decision

The fail-closed pre-allocation checker used the proposed slug, strategy ID,
named authors, complete mechanic, and actual Company Reference Wiki root. It
scanned 4,629 registry identities, 1,297 repository cards, and 45 Strategy-Wiki
nodes, found no exact or fuzzy collision, and returned `CLEAN`. Evidence:
`artifacts/qm5_wti_mopen_residence_mom_preallocation_dedup_20260823.json`.

Manual semantic review fixes the closest-family boundaries:

- `QM5_20187_wti-tsmom1m` follows only the immediately completed month-end
  return. This candidate additionally requires exhaustive close residence
  against one fixed older boundary.
- `QM5_41111_wti-mdaybreadth-mom` counts signs of adjacent daily returns. This
  candidate counts cumulative close levels relative to the single prior-
  month-end anchor; alternating daily returns can therefore leave residence
  unchanged while changing breadth.
- `QM5_41114`, `QM5_41115`, and `QM5_41117` vote on fixed calendar blocks.
  This candidate has no half, third, or late-block return.
- `QM5_41122_wti-mextreme-sequence-mom` uses the order of the month's most
  extreme close states. This candidate exhaustively counts all closes and has
  no extreme-order state.
- `QM5_41124_wti-mrms-coherence-mom`, `QM5_41126_wti-mpath-eff-mom`, and
  `QM5_41127_wti-mdaily-persist-mom` respectively use L2 coherence, L1 path
  efficiency, and adjacent centered-return products. This candidate uses no
  return magnitude, center, scale, or adjacent-product statistic.
- `QM5_41120_xauxag-mopen-residence-rv` applies a related residence operator
  to synchronized gold/silver log ratios, anchors on the first in-month ratio,
  and fades with two opposite equal-notional legs. This candidate anchors on
  the older WTI month-end close, follows the endpoint, and owns one outright
  physical-energy position.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon, single-symbol,
  long-only XNG oscillator pullback rather than monthly WTI path continuation.

The exact WTI carrier, immediately completed calendar month, older boundary
close, 17-to-23 exhaustive close comparisons, strict tie handling, integer
ceiling three-quarter gate, endpoint-side confirmation, continuation side,
consumed attempt, fixed risk, and next-month exit are jointly load-bearing.
Manual verdict:
`CLEAN_WTI_COMPLETED_MONTH_FIXED_OPEN_RESIDENCE_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Reputable-source criteria

- R1 `PASS_WITH_OPEN_RESIDENCE_TRANSLATION_RISK`: one canonical governed child
  source preserves a named peer-reviewed trading paper, DOI, author-hosted
  complete-paper evidence, durable hashes, explicit WTI membership,
  source-declared one-month formation/hold, and a previously approved
  deterministic residence operator. The D1 path gate and continuation map are
  explicitly untested QM translations.
- R2 `PASS`: exact month labels, session count, chronology, fixed anchor,
  exhaustive strict counts, integer threshold, endpoint identity, direction,
  attempt, risk, stop, spread gate, and lifecycle are fixed before testing.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history plus MT5 state provides every runtime input. Q02 owns
  history sufficiency, costs, financing, gaps, fills, density, and CFD-basis
  sufficiency.
- R4 `PASS`: runtime uses timestamps, completed prices, logarithms, integer
  counts, comparisons, ATR, quotes, positions, deals, and persistent terminal
  state; no trained logic, banned signal, external feed, grid, martingale,
  scale-in, or pyramid exists.

## Frequency, portfolio claim, and falsification

A seeded zero-drift Gaussian design reference with 20,000 paths qualifies
64.200%, 65.170%, and 60.825% of months at 17, 20, and 23 sessions,
respectively, or roughly seven to eight decisions per year. This is a
pre-result density and code-path sanity check, not market evidence. Q02 must
retire below five completed positions in any full scored post-warm-up year,
at zero trades, with nonpositive governed economics, or on any month-label,
anchor, count, threshold, side, attempt, risk, lifecycle, or determinism
defect.

WTI supplies a different economic carrier from the certified XAU/SP500/NDX/
XNG book, but different carrier does not prove profitability or low realized
correlation. Q09 alone owns the portfolio finding.

No weak result may be rescued by changing the residence fraction, tie
handling, anchor, direction, carrier, hold, risk, or by adding a fitted mean,
scale, return threshold, volatility forecast, moving average, sign count,
block vote, sequence, range location, seasonality, event, external, or prior-
result state.

## Implementation and safety boundary

Only one D1 backtest preset is permitted, with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `ENV=backtest`. No live, demo, shadow, stress, or
optimization preset is authorized. This approval forbids manual backtests,
terminal control, AutoTrading, `T_Live`, deploy or T_Live manifest mutation,
portfolio-gate changes, portfolio admission, decorrelation claims, and
correlation waivers. Strict Q01 must precede one Q02 enqueue, and the fresh
tester/host-CPU ceiling remains fail closed.
