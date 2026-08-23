# WTI completed-month mean-to-RMS coherence momentum - Source Approval

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

- proposed slug: `wti-mrms-coherence-mom`
- proposed strategy ID: `MOP-WTI-MRMS-COHERENCE-MOM-2026_S01`
- proposed source ID: `MOP-WTI-MRMS-COHERENCE-MOM-2026`
- carrier: exact `XTIUSD.DWX`, D1
- state: the immediately completed broker-calendar month's signed daily-log-
  return mean has absolute mean-to-root-mean-square coherence of at least 0.16
- action: follow the sign of the completed-month net return
- lifecycle: one persisted attempt per broker month and first-later-month flat

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved source basis

The governed parent record
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
was read completely before this approval. It preserves the complete 23-page
published-paper review of Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje
Pedersen (2012), "Time Series Momentum," *Journal of Financial Economics*
104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`. Its retrieval receipt
records the author-hosted PDF, 23 pages, 976,459 bytes, and PDF SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.

The paper tests each instrument's own monthly return at lags one through sixty,
finds positive continuation over the first twelve lags, explicitly reports a
`k=1`, `h=1` commodity-futures portfolio, renews mechanically each month, uses
ex-ante volatility scaling, and includes NYMEX WTI in its commodity universe.
It does not report a WTI-specific one-month result and does not test the
within-month mean-to-RMS coherence gate below.

The bounded child extraction will be
`strategy-seeds/sources/MOP-WTI-MRMS-COHERENCE-MOM-2026/source.md`. It is the
card's single canonical `source_id`; the parent record remains its governed
lineage.

The source supports a WTI own-return continuation hypothesis and a monthly
formation/holding clock. The daily path reconstruction, fixed 0.16 gate,
Darwinex continuous CFD, broker-calendar labels, fixed cash risk, ATR stop,
spread cap, attempt ledger, and lifecycle controls are transparent QM
falsification choices. No source return, alpha, probability, density, profit
factor, drawdown, transaction cost, CFD equivalence, or portfolio-correlation
statistic transfers.

## Locked mechanic

1. Require exact `XTIUSD.DWX`, D1, slot zero, fixed-risk backtest inputs, both
   news axes OFF, and Friday close OFF.
2. On the first executable D1 bar of a new broker-calendar month, within 180
   elapsed minutes of the raw current bar open, reconstruct every completed D1
   close labeled with the immediately preceding calendar month. Require 17
   through 23 unique month-session closes in strict chronological order plus
   one immediately older close from the adjacent prior calendar month. Exclude
   every current-month close.
3. Starting from the older boundary close, form exactly one chronological log
   return ending on each completed-month session. For `n` returns define
   `N=sum(r[j])`, `Q=sum(r[j]^2)`, and
   `C=abs(N)/sqrt(n*Q)`, equivalently `abs(mean(r))/RMS(r)`. Require positive
   finite closes, finite returns and sums, `Q>0`, and `C` in `[0,1]` up to
   `1e-10`. Verify the return sum equals the boundary-to-final endpoint log
   return within `1e-10`.
4. Qualify only when `C>=0.16` and `N!=0`. Buy WTI when `N>0`; sell WTI when
   `N<0`. A zero net move, zero squared path, below-threshold coherence,
   malformed month, or invalid numerical state consumes the month flat.
   Coherence and return magnitude never alter the fixed risk budget.
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
scanned 4,623 registry identities, 1,292 cards, and 45 Strategy-Wiki nodes,
found no exact or fuzzy collision, and returned `CLEAN`. Evidence:
`artifacts/qm5_wti_mrms_coherence_mom_preallocation_dedup_20260823.json`.

Manual semantic review fixes the closest-family boundaries:

- `QM5_20187_wti-tsmom1m` uses only the immediately completed month-end return
  sign and attempts every valid month. This candidate requires the same sign
  to pass a fixed all-daily-return coherence gate.
- `QM5_20288_wti-volnorm-mom` separately divides each of twelve historical
  month returns by its own daily L2 norm and averages the twelve normalized
  states without a threshold. This candidate uses only the immediately
  completed month and qualifies its one net return with the bounded
  mean-to-RMS quotient at a fixed 0.16 threshold.
- `QM5_20274_wti-path-eff` follows a twelve-month net move divided by the L1
  path of twelve monthly returns. This candidate uses one month of daily
  returns, an L2/RMS denominator, and an endpoint-identity check.
- `QM5_41111_wti-mdaybreadth-mom` counts daily signs and discards magnitudes.
  This candidate uses every squared return magnitude and is order-invariant.
- `QM5_41114`, `QM5_41115`, and `QM5_41117` aggregate fixed month halves,
  thirds, or early/late blocks; `QM5_41122` uses extreme-state sequence order.
  This candidate has no block boundary, vote, location, or sequence state.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon single-symbol
  XNG oscillator pullback, not a completed-month WTI path-coherence trend.

The exact WTI carrier, immediately completed calendar month, older boundary
close, every daily return ending in that month, signed sum, squared-path RMS,
inclusive 0.16 gate, same-sign direction, consumed attempt, fixed risk, and
next-month exit are jointly load-bearing. Manual verdict:
`CLEAN_WTI_COMPLETED_MONTH_MEAN_RMS_COHERENCE_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Reputable-source criteria

- R1 `PASS_WITH_WITHIN_MONTH_GATE_TRANSLATION_RISK`: one canonical governed
  child source preserves a named peer-reviewed trading paper, DOI,
  author-hosted complete-paper evidence, durable hashes, explicit WTI
  membership, and the source-declared one-month formation/hold. The daily-path
  coherence gate is an explicitly untested QM translation.
- R2 `PASS`: exact month labels, session count, chronology, return endpoints,
  signed sum, squared path, normalization, identity tolerance, threshold,
  direction, attempt, risk, stop, spread gate, and lifecycle are fixed before
  testing.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history plus MT5 state provides every runtime input. Q02 owns
  history sufficiency, costs, financing, gaps, fills, density, and CFD-basis
  sufficiency.
- R4 `PASS`: runtime uses timestamps, completed prices, logarithms, addition,
  multiplication, square root, division, comparisons, ATR, quotes, positions,
  deals, and persistent terminal state; no trained logic, banned signal,
  external feed, grid, martingale, scale-in, or pyramid exists.

## Frequency, portfolio claim, and falsification

An ex-ante zero-drift Gaussian design reference with 17, 20, and 23 returns
qualifies approximately 52.6%, 48.9%, and 45.6% of months at `C>=0.16`, or
about 6.3, 5.9, and 5.5 decisions/year. This is a threshold-density sanity
check, not market evidence. Q02 must retire below five completed positions in
any full scored post-warm-up year, at zero trades, with nonpositive governed
economics, or on any month-label, orientation, arithmetic, threshold,
direction, attempt, risk, lifecycle, or determinism defect.

WTI supplies a different economic carrier from the certified XAU/SP500/NDX/
XNG book, but different carrier does not prove profitability or low realized
correlation. Q09 alone owns the portfolio finding.

No weak result may be rescued by changing the threshold, direction, return
inclusion, carrier, hold, risk, or by adding a fitted mean, volatility forecast,
moving average, sign count, block vote, sequence, range location, seasonality,
event, external, or prior-result state.

## Implementation and safety boundary

Only one D1 backtest preset is permitted, with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `ENV=backtest`. No live, demo, shadow, stress, or
optimization preset is authorized. This approval forbids manual backtests,
terminal control, AutoTrading, `T_Live`, deploy or T_Live manifest mutation,
portfolio-gate changes, portfolio admission, decorrelation claims, and
correlation waivers. Strict Q01 must precede one Q02 enqueue, and the fresh
tester/host-CPU ceiling remains fail closed.
