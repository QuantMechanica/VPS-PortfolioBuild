# WTI completed-month daily-persistence momentum - Source Approval

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

- proposed slug: `wti-mdaily-persist-mom`
- proposed strategy ID: `MEHLITZ-MOP-WTI-MDAILY-PERSIST-MOM-2026_S01`
- proposed source ID: `MEHLITZ-MOP-WTI-MDAILY-PERSIST-MOM-2026`
- carrier: exact `XTIUSD.DWX`, D1
- state: the immediately completed broker-calendar month's 17 through 23
  daily log returns have a strictly positive bias-neutralized lag-one
  persistence score
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
2. `strategy-seeds/sources/MEHLITZ-AUER-MEM-2024/source.md`, SHA-256
   `A422025CE4C7FA2F9BEB995F496103D0FCCCED899C143771F58DB7E2222D3AC8`.
   It preserves an end-to-end review of Chapter 3 and Appendix C of Julia S.
   Mehlitz's open doctoral manuscript and the canonical peer-reviewed article
   by Mehlitz and Benjamin R. Auer (2024), "Memory-enhanced momentum in
   commodity futures markets," *The European Journal of Finance* 30(8),
   773-802, DOI `10.1080/1351847X.2023.2220118`.

Moskowitz, Ooi, and Pedersen test each instrument's own monthly return at lags
one through sixty, report continuation over the first twelve lags, explicitly
report a `k=1`, `h=1` commodity-futures portfolio, renew monthly, and include
NYMEX WTI. Mehlitz and Auer explicitly include WTI and define persistence from
lagged return autocorrelations through the Lo-MacKinlay variance-ratio family.

Neither source tests the completed-month daily statistic below. Mehlitz and
Auer use 32 monthly observations, a heteroskedasticity-robust significance
test, and a continuation/reversal matrix. This candidate instead uses the
17-23 daily returns inside one completed broker month, a fixed finite-sample
neutralization, persistence-only qualification, and the completed-month
endpoint sign. That conjunction is a transparent QM falsification
translation, not a source result.

The bounded child extraction will be
`strategy-seeds/sources/MEHLITZ-MOP-WTI-MDAILY-PERSIST-MOM-2026/source.md`.
It is the card's single canonical `source_id`; the two parent records remain
its governed lineage.

No source return, alpha, probability, density, profit factor, Sharpe ratio,
drawdown, transaction cost, CFD equivalence, trade count, or portfolio-
correlation statistic transfers.

## Locked mechanic

1. Require exact `XTIUSD.DWX`, D1, slot zero, fixed-risk backtest inputs, both
   news axes OFF, and Friday close OFF.
2. On the first executable D1 bar of a new broker-calendar month, within 180
   elapsed minutes of the raw current bar open, reconstruct every completed
   D1 close labeled with the immediately preceding calendar month. Require 17
   through 23 unique month-session closes in strict chronological order plus
   one immediately older close from the adjacent prior calendar month. Exclude
   every current-month close.
3. Starting from the older boundary close, form exactly one chronological log
   return ending on each completed-month session. For `n` returns define:

   ```text
   N   = sum(r[j])
   mu  = N / n
   S   = sum((r[j] - mu)^2)
   A   = sum((r[j] - mu) * (r[j-1] - mu)), j=1..n-1
   rho = A / S
   J   = rho + 1/(n-1)
   ```

   Require positive finite closes, finite returns and sums, `S>0`, finite
   `rho` and `J`, and `rho` inside `[-1,1]` within `1e-10`. Verify that `N`
   equals the boundary-to-final endpoint log return within `1e-10`.
4. Qualify only when `J>0` and `N!=0`. Buy WTI when `N>0`; sell WTI when
   `N<0`. Equality at `J=0`, zero net move, zero variance, malformed month, or
   invalid numerical state consumes the month flat. Score and return magnitude
   never alter the fixed risk budget.
5. Persist the exact decision `yyyymm` attempt before every fallible downstream
   gate. Rejection, order failure, stop-out, or restart cannot retry that month.
6. Open at most one WTI position with aggregate `RISK_FIXED=1000`, a frozen
   `3.5 * ATR(20,D1)` server-side hard stop, no target, and a 1,500-point entry
   spread ceiling.
7. Close on the first tick whose broker `yyyymm` is later than the entry
   attempt month or after forty calendar days. Malformed, duplicated, wrong-
   magic, wrong-symbol, or stopless owned exposure flattens immediately. Never
   retry, trail, partial-close, scale in, grid, martingale, or pyramid.

The `1/(n-1)` term fixes the conventional short-sample negative center of a
demeaned lag-one autocorrelation before any market result is observed. It is
not fitted to WTI and has no tunable threshold. Its use on one broker month is
an untested QM translation and is load-bearing.

## Non-duplicate decision

The fail-closed pre-allocation checker used the proposed slug, strategy ID,
all named authors, complete mechanic, and actual Company Reference Wiki root.
It scanned 4,626 registry identities, 1,295 cards, and 45 Strategy-Wiki nodes,
found no exact or fuzzy collision, and returned `CLEAN`. Evidence:
`artifacts/qm5_wti_mdaily_persist_mom_preallocation_dedup_20260823.json`.

Manual semantic review fixes the closest-family boundaries:

- `QM5_20187_wti-tsmom1m` follows the immediately completed month-end return
  without inspecting daily serial dependence.
- `QM5_13134_energy-vr-mom` estimates a source-specified q=2 robust variance
  ratio from 32 completed **monthly** returns and can reverse significant
  anti-persistence. This candidate estimates one demeaned lag-one score from
  17-23 **daily** returns ending in one month, qualifies persistence only, and
  never reverses the endpoint sign.
- `QM5_20245`, `QM5_20253`, `QM5_20256`, and `QM5_20257` use multi-month
  robust variance-ratio states at fixed ranking horizons. None measures the
  immediately completed month's internal daily serial path.
- `QM5_41111_wti-mdaybreadth-mom` counts positive and negative daily signs;
  `QM5_41114`, `QM5_41115`, and `QM5_41117` aggregate calendar blocks; and
  `QM5_41122` orders extremes. This candidate uses centered adjacent return
  products and no sign count, block vote, or extreme state.
- `QM5_41124_wti-mrms-coherence-mom` compares the month mean with the RMS of
  daily returns; `QM5_41126_wti-mpath-eff-mom` compares endpoint displacement
  with the L1 absolute path. Neither multiplies adjacent demeaned returns or
  applies the fixed short-sample neutralization.
- `QM5_41123` and `QM5_41125` trade synchronized XAU/XAG relative baskets;
  this candidate is one outright WTI carrier.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon single-symbol
  XNG oscillator pullback rather than completed-month WTI trend structure.

The exact WTI carrier, immediately completed calendar month, older boundary
close, every daily return ending in that month, centered variance, adjacent
cross-product sum, fixed `1/(n-1)` neutralization, strict positive gate,
endpoint direction, consumed attempt, fixed risk, and next-month exit are
jointly load-bearing. Manual verdict:
`CLEAN_WTI_COMPLETED_MONTH_DAILY_PERSISTENCE_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Reputable-source criteria

- R1 `PASS_WITH_WITHIN_MONTH_PERSISTENCE_TRANSLATION_RISK`: the canonical
  child preserves two named peer-reviewed trading papers, DOIs, complete-read
  evidence, durable hashes, explicit WTI membership, own-return momentum,
  monthly formation/hold, and return-autocorrelation lineage. The daily
  horizon, finite-sample neutralization, and persistence-only gate are
  explicitly untested QM translations.
- R2 `PASS`: exact month labels, session count, chronology, return endpoints,
  centering, denominator, adjacent-product inclusion, fixed correction, strict
  threshold, direction, attempt, risk, stop, spread gate, and lifecycle are
  fixed before testing.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history plus MT5 state provides every runtime input. Q02 owns
  history sufficiency, costs, financing, gaps, fills, density, and CFD-basis
  sufficiency.
- R4 `PASS`: runtime uses timestamps, completed prices, logarithms, addition,
  multiplication, division, comparisons, ATR, quotes, positions, deals, and
  persistent terminal state; no trained logic, banned signal, external feed,
  grid, martingale, scale-in, or pyramid exists.

## Frequency, portfolio claim, and falsification

A seeded zero-drift Gaussian design reference with 20,000 samples at each of
17, 20, and 23 returns qualified 50.385%, 49.595%, and 50.210% of months,
respectively, or approximately six decisions/year. This is a pre-result code-
path and density sanity check, not market evidence. Q02 must retire below five
completed positions in any full post-warm-up year, at zero trades, with
nonpositive governed economics, or on any month-label, orientation, arithmetic,
threshold, direction, attempt, risk, lifecycle, or determinism defect.

WTI supplies a different economic carrier from the certified XAU/SP500/NDX/
XNG book, but different carrier does not prove profitability or low realized
correlation. Q09 alone owns the portfolio finding.

No weak result may be rescued by changing the centering, correction, gate,
direction, return inclusion, carrier, hold, risk, or by adding a fitted
threshold, variance-ratio significance test, anti-persistence reversal,
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
