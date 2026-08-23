# XAU/XAG completed-month path-efficiency reversion - Source Approval

Date: 2026-08-23

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if tester and whole-host CPU
ceilings permit. This decision does not authorize a manual tester dispatch.

Authority: the current explicit OWNER commodity/energy portfolio mission
delivered to Codex on branch `agents/board-advisor` on 2026-08-23. The mission
requires one new, non-duplicate, structural low-frequency commodity edge and
expressly permits an `XAUUSD`/`XAGUSD` gold/silver-ratio reversion basket. It
also requires reputable-source criteria and `RISK_FIXED` backtests and excludes
live and portfolio-gate mutation.

## Candidate identity

- proposed slug: `xauxag-mpath-eff-rv`
- proposed strategy ID:
  `SCHWEIKERT-MOP-CME-XAUXAG-MPATH-EFF-RV-2026_S01`
- proposed source ID: `SCHWEIKERT-MOP-CME-XAUXAG-MPATH-EFF-RV-2026`
- carrier: exact synchronized `XAUUSD.DWX`/`XAGUSD.DWX` D1 opposite-leg basket
- state: the immediately completed broker-calendar month's gold-minus-silver
  log-ratio net displacement is at least 20% of its full daily absolute path
- action: fade the completed ratio displacement with equal absolute notionals
- lifecycle: one persisted attempt per broker month and first-later-month flat

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved source basis

The following governed records were read completely before this approval:

1. `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`, SHA-256
   `4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B`.
   It preserves Karsten Schweikert (2018), "Are gold and silver
   cointegrated? New evidence from quantile cointegrating regressions,"
   *Journal of Banking & Finance* 88, 44-51, DOI
   `10.1016/j.jbankfin.2017.11.010`, and supporting fractional-cointegration
   research. The record supports a related, state-dependent gold/silver
   relation rather than one universal constant equilibrium.
2. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, SHA-256
   `2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`.
   CME Group defines the gold/silver ratio, presents it as an intermarket
   spread, and distinguishes gold's monetary/safe-haven drivers from silver's
   industrial-cycle exposure.
3. `strategy-seeds/sources/MOP-WTI-PATHEFF-2026/source.md`, SHA-256
   `7D4F2B86DA31EEA2ECAEE7573E3CF1629883B05A575FFEB694944A99D907DBE8`,
   plus its completely read parent
   `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
   The parent preserves Moskowitz, Ooi, and Pedersen (2012), "Time Series
   Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`, with a complete published-paper read and
   retrieval hash. The bounded child fixes the closed-form net-to-absolute-path
   statistic and its numerical validity contract.

The bounded child extraction will be
`strategy-seeds/sources/SCHWEIKERT-MOP-CME-XAUXAG-MPATH-EFF-RV-2026/source.md`.
It is the card's single canonical `source_id`; the records above are preserved
as its governed lineage.

Schweikert and CME support testing a relative-value gold/silver carrier.
Moskowitz, Ooi, and Pedersen support a mechanical completed-price path and a
monthly decision/holding clock, while the existing bounded packet supplies the
auditable path-efficiency formula. None of the sources tests within-month
daily XAU/XAG ratio efficiency, a fixed 0.20 threshold, contrarian direction,
Darwinex continuous CFDs, equal-notional sizing, fixed cash risk, ATR stops,
or the QM portfolio. Those are transparent QM falsification choices. No source
return, alpha, probability, density, risk, cost, hedge ratio, neutrality, CFD
equivalence, or portfolio-correlation result transfers.

## Locked mechanic

1. Require exact `XAUUSD.DWX` host and `XAGUSD.DWX` companion, D1, slots zero
   and one, fixed-risk backtest inputs, both news axes OFF, and Friday close
   OFF.
2. On the first synchronized D1 bar of a new broker-calendar month, within 180
   elapsed minutes of the raw host-bar open, reconstruct every synchronized D1
   close pair in the immediately preceding calendar month. Require 17 through
   23 unique timestamps in strict chronological order and one adjacent older
   pair proving the package was not truncated. Exclude all current-month
   prices.
3. For chronological paired closes, define
   `s[i]=ln(XAU_close[i])-ln(XAG_close[i])`,
   `r[i]=s[i]-s[i-1]`, `N=sum(r[i])`, `P=sum(abs(r[i]))`, and
   `E=abs(N)/P`. Require all closes, ratios, returns, sums, and the quotient to
   be finite; require `P>0`; and require `E` in `[0,1]` up to `1e-10`.
4. Qualify only when `E>=0.20` and `N!=0`. If `N>0`, sell gold and buy
   silver. If `N<0`, buy gold and sell silver. A zero net move, zero path,
   below-threshold path, invalid history, or unsynchronized package consumes
   the month flat. Efficiency and displacement magnitude never alter risk.
5. Persist the exact decision `yyyymm` attempt before every fallible
   downstream gate. Rejection, atomic repair, order failure, or restart cannot
   retry that broker month.
6. Open one opposite-leg package with equal target absolute USD notionals,
   maximum 20% realized notional mismatch, aggregate `RISK_FIXED=1000`, frozen
   `3.5 * ATR(20,D1)` hard stops on both legs, no target, and entry-spread
   ceilings of 1,500 XAU points and 500 XAG points.
7. Close both legs on the first tick of a later broker-calendar month or after
   forty calendar days. Malformed, orphaned, duplicated, same-side, stopless,
   or notional-invalid ownership flattens immediately. Never retry, trail,
   partial-close, scale in, grid, martingale, pyramid, or read an external
   runtime feed.

## Non-duplicate decision

The fail-closed pre-allocation checker used the proposed slug, strategy ID,
named authors, complete mechanic, and actual Company Reference Wiki root. It
scanned 4,622 registry identities, 1,291 repository cards, and 45 Strategy
Wiki nodes, found no exact or fuzzy collision, and returned `CLEAN`. Evidence:
`artifacts/qm5_xauxag_mpath_eff_rv_preallocation_dedup_20260823.json`.

Manual semantic review fixes the closest-family boundaries:

- `QM5_12577_cme-xauxag-ratio`, `QM5_20157_xau-xag-ratio`, and
  `QM5_20263_xauxag-mad-rv` use rolling level centers, scales, and threshold
  crossings. This candidate has no fitted center, scale, lookback state, or
  crossing rule.
- `QM5_20274_wti-path-eff` follows an outright WTI twelve-month path at a
  0.25 threshold. This candidate fades one completed month of synchronized
  gold/silver relative daily returns with opposite legs and a 0.20 threshold.
- `QM5_41112_xauxag-mdaybreadth-rv` counts daily return signs and discards
  magnitudes. This candidate uses every return magnitude and is invariant to
  how many returns have either sign when `N` and `P` are unchanged.
- `QM5_41113_xauxag-mhalfagree-rv`, `QM5_41116_xauxag-mthirdvote-rv`, and
  `QM5_41118_xauxag-mlatehalf-dom-rv` aggregate fixed calendar blocks. This
  candidate has no block boundary or vote.
- `QM5_41119_xauxag-mclose-quartile-rv`,
  `QM5_41120_xauxag-mopen-residence-rv`, and
  `QM5_41121_xauxag-mseqdom-rv` use close location, anchor residence, or
  sequence/reversal counts. This candidate uses only the first-to-last net
  ratio move and total absolute adjacent path.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon single-symbol
  XNG oscillator pullback, not an opposite-leg precious-metals basket.

The exact paired carrier, immediately completed calendar month,
17-to-23-session synchronization, every adjacent relative log return,
net-to-absolute-path quotient, fixed inclusive 0.20 threshold, contrarian
sides, consumed monthly attempt, equal-notional aggregate-risk package, and
next-month exit are jointly load-bearing. Manual verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_PATH_EFFICIENCY_REVERSION_AFTER_FAMILY_REVIEW`.

## Reputable-source criteria

- R1 `PASS_WITH_PATH_HORIZON_AND_DIRECTION_TRANSLATION_RISK`: one canonical
  governed child source preserves a peer-reviewed gold/silver DOI, official
  CME spread-carrier research, and a peer-reviewed path-efficiency lineage
  with complete-read hashes. The daily-ratio horizon and contrarian direction
  are explicitly untested translations.
- R2 `PASS`: exact synchronization, month membership, ratios, adjacent
  returns, numerator, denominator, zero and numerical handling, threshold,
  sides, attempt, risk, stops, atomicity, spread gates, and lifecycle are fixed
  before testing.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered
  native `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus MT5 state provide
  every runtime input. Q02 owns history, holiday attrition, costs, financing,
  density, fills, and CFD-basis sufficiency.
- R4 `PASS`: runtime uses timestamps, completed prices, logarithms, absolute
  values, sums, division, comparisons, ATR, quotes, positions, deals, and
  persistent terminal state; no trained logic, banned signal, external feed,
  grid, martingale, scale-in, or pyramid exists.

## Frequency, portfolio claim, and falsification

A seeded zero-drift Gaussian reference with twenty returns qualifies
approximately 48.3% of months at `E>=0.20`, or 5.8 decisions/year. This is a
design-density reference, not market evidence. Q02 must retire below five
completed packages in any full scored year, at zero trades, with nonpositive
governed economics, or on any synchronization, arithmetic, side, attempt,
risk, atomicity, lifecycle, or determinism defect.

Opposite equal-notional legs are designed to reduce common outright-metal
direction but do not prove neutrality or low portfolio correlation. Q09 alone
owns the realized portfolio finding.

No weak result may be rescued by changing the carrier, month package,
threshold, direction, risk, or hold, or by adding a fitted center, scale,
z-score, close-location, sign-count, block-vote, sequence, volatility, volume,
calendar, event, external, or prior-result state.

## Implementation and safety boundary

Only one logical D1 backtest preset is permitted, with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `ENV=backtest`. No live, demo, shadow, stress, or
optimization preset is authorized. This approval forbids manual backtests,
terminal control, AutoTrading, `T_Live`, deploy or T_Live manifest mutation,
portfolio-gate changes, portfolio admission, decorrelation claims, and
correlation waivers. Strict Q01 must precede one Q02 enqueue, and the fresh
tester/host-CPU ceiling remains fail closed.
