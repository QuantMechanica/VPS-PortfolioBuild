---
source_id: SCHWEIKERT-MEHLITZ-CME-XAUXAG-MDAILY-PERSIST-RV-2026
title: XAU/XAG completed-month daily-persistence reversion extraction
publisher: QuantMechanica governed extraction of peer-reviewed and exchange research
source_type: peer_reviewed_exchange_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-23_xauxag_monthly_daily_persistence_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - CME-GSR-SPREAD-2025
  - MEHLITZ-MOP-WTI-MDAILY-PERSIST-MOM-2026
parent_sha256:
  SCHWEIKERT-XAUXAG-RATIO-2026: 4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B
  CME-GSR-SPREAD-2025: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
  MEHLITZ-MOP-WTI-MDAILY-PERSIST-MOM-2026: 62FB3C500F4176047667F5194A446BFA7C53B0D1F4D3E523F226449416D398F4
  MEHLITZ-AUER-MEM-2024: A422025CE4C7FA2F9BEB995F496103D0FCCCED899C143771F58DB7E2222D3AC8
created: 2026-08-23
created_by: Research+Development
cards_extracted:
  - xauxag-mdaily-persist-rv
---

# XAU/XAG Completed-Month Daily-Persistence Reversion Source Packet

## Approved Sources Of Record

This bounded extraction uses one canonical child `source_id` with three
governed source lineages. Every record was read completely before source
approval:

- `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md` preserves
  Karsten Schweikert (2018), "Are gold and silver cointegrated? New evidence
  from quantile cointegrating regressions," *Journal of Banking & Finance*
  88, 44-51, DOI `10.1016/j.jbankfin.2017.11.010`, and supporting fractional-
  cointegration research.
- `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md` records CME Group's
  definition of the gold/silver ratio, the intermarket-spread carrier, and the
  metals' differing monetary and industrial drivers.
- `strategy-seeds/sources/MEHLITZ-MOP-WTI-MDAILY-PERSIST-MOM-2026/source.md`
  preserves the exact within-month lag-one persistence score, endpoint
  identity, and numerical contract as a bounded mechanization of Mehlitz and
  Auer (2024), "Memory-enhanced momentum in commodity futures markets,"
  *The European Journal of Finance* 30(8), 773-802, DOI
  `10.1080/1351847X.2023.2220118`. Its completely read parent packet is
  `strategy-seeds/sources/MEHLITZ-AUER-MEM-2024/source.md`.

The durable OWNER approval is
`decisions/2026-08-23_xauxag_monthly_daily_persistence_reversion_source_approval.md`,
committed before this extraction at `8889d7f32`. No blocked page, inferred
source-table value, secondary summary, or unrecorded performance claim is
used.

## Source Findings Used

Schweikert supports testing a long-run gold/silver relation while warning that
its behavior can be state dependent rather than governed by one constant
cointegrating vector. CME defines the gold/silver ratio as gold price divided
by silver price, presents it as an intermarket spread, and explains why the
legs can diverge because gold has stronger monetary and safe-haven sensitivity
while silver has stronger industrial sensitivity.

Mehlitz and Auer condition commodity momentum and reversal on return memory.
The governed WTI child defines a closed-form statistic that centers a completed
month's daily returns, compares adjacent demeaned returns, and corrects the
short-sample negative center by fixed `1/(n-1)`. That packet follows a
persistent outright WTI endpoint. It does not test gold/silver, synchronized
daily relative returns, or contrarian direction.

The sources do not establish that a persistent one-month gold/silver-ratio
move predicts reversion. They do not prescribe a 17-to-23-session broker
month, equal-notional sizing, Darwinex continuous CFDs, fixed cash risk, ATR
stops, spread caps, persistent attempt state, or portfolio behavior. Those are
transparent QM hypotheses. No source alpha, profit estimate, probability,
density, hedge ratio, neutrality, cost, CFD equivalence, or portfolio-
correlation statistic is imported.

## Bounded QM Mechanization

On the first tradable synchronized `XAUUSD.DWX` and `XAGUSD.DWX` D1 bar of a
new broker-calendar month, reconstruct every synchronized close pair in the
immediately completed calendar month plus the adjacent older synchronized
pair. Require 17 through 23 completed-month pairs. Define the gold-minus-
silver log ratio at every paired endpoint and form one chronological relative
return ending on every session of the completed month.

For older boundary ratio `s[-1]`, month ratios `s[0]..s[n-1]`, and returns
`r[j]=s[j]-s[j-1]` for `j=0..n-1`:

```text
N   = sum(r[j])
mu  = N / n
S   = sum((r[j] - mu)^2)
A   = sum((r[j] - mu) * (r[j-1] - mu)), j=1..n-1
rho = A / S
J   = rho + 1/(n-1)

require finite arithmetic, S > 0, and rho in [-1,1] within 1e-10

J > 0 and N > 0
    => SELL XAUUSD.DWX, BUY XAGUSD.DWX

J > 0 and N < 0
    => BUY XAUUSD.DWX, SELL XAGUSD.DWX

otherwise
    => FLAT
```

The sum of chronological relative returns must equal the direct relative
log-ratio displacement from the older boundary pair to the completed month's
final pair within `1e-10`. Each return ending in the completed month
contributes exactly once. Exact-zero constituent returns are valid. Zero
variance, exact-zero net, nonpositive corrected score, nonfinite state, or an
out-of-range correlation consumes the month flat. Score and displacement
magnitude never change risk.

The fixed `1/(n-1)` shift neutralizes the conventional negative center of the
demeaned sample lag-one autocorrelation at short `n`. It is neither fitted nor
optimized and is applied before any market result. The resulting score is a
path-state gate, not a confidence estimate or risk multiplier.

## Exact Event Contract

1. Require exact `XAUUSD.DWX` host, exact `XAGUSD.DWX` companion, D1, and entry
   no later than 180 elapsed minutes after the raw first host D1 bar open of a
   new broker month.
2. Require the newest synchronized completed pair to belong to the immediately
   preceding calendar month. Within a fixed 45-bar buffer, require 17 through
   23 unique completed-month timestamps in strict reverse-time order and one
   immediately older synchronized pair from the adjacent calendar month. A
   current-month close or mismatched timestamp is excluded.
3. Reverse the selected pairs into chronological order beginning with the
   older boundary. Form one gold-minus-silver relative return into every
   completed-month session, with no gap, overlap, duplicate, or omitted
   endpoint.
4. Accumulate `N`, `mu`, `S`, and `A` from the same bounded data, verify the
   endpoint identity, then compute `rho` and fixed `J` without rounding.
5. Fade the sign of `N` only when `J>0`. Every invalid or nonqualifying state
   consumes the month flat.
6. Persist current decision `yyyymm` before history, signal, news, spread,
   quote, ATR, sizing, or order submission. No outcome may retry that month.
7. Open one opposite-leg package with equal target absolute USD notionals and
   no more than 20% realized notional mismatch. Split one aggregate
   `RISK_FIXED=1000` budget across two frozen `3.5 * ATR(20,D1)` hard stops,
   use no target, and enforce 1,500-point XAU and 500-point XAG spread ceilings.
8. Close both legs on the first tick in a later broker month, with a forty-
   calendar-day stale repair. Flatten malformed, duplicated, same-side,
   wrong-symbol, wrong-magic, stopless, notional-invalid, or orphan exposure
   immediately.

## Non-Duplicate Boundary

The fail-closed canonical checker found no exact or fuzzy collision across
4,627 registry identities, 1,296 cards, and 45 Strategy Wiki nodes. Evidence
is
`artifacts/qm5_xauxag_mdaily_persist_rv_preallocation_dedup_20260823.json`.

Manual semantic review fixes a new mechanic:

- rolling ratio, OLS, conditional-quantile, and MAD cards estimate a center,
  beta, scale, or crossing. This extraction estimates none.
- `QM5_20249_xauxag-vr-spread` estimates serial dependence over 32 monthly
  relative returns and can continue or reverse. This extraction uses one
  month of daily relative returns and only a positive-memory reversion state.
- `QM5_41112_xauxag-mdaybreadth-rv` counts signs; fixed-block cards aggregate
  halves or thirds; and `QM5_41121_xauxag-mseqdom-rv` orders state changes.
  This extraction multiplies adjacent centered return magnitudes and uses no
  count, block, vote, range, or extreme state.
- `QM5_41123_xauxag-mpath-eff-rv` normalizes by an L1 path and
  `QM5_41125_xauxag-mrms-coherence-rv` normalizes by an L2 path. Neither
  measures adjacent dependence or applies the fixed short-sample shift.
- `QM5_41127_wti-mdaily-persist-mom` follows the same statistic on outright
  WTI. This extraction fades it on a synchronized two-leg relative carrier
  with equal-notional atomic lifecycle.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon XNG oscillator
  pullback rather than a monthly relative-value package.

The exact paired carrier, immediately completed month, older boundary pair,
every relative return ending in the month, centered variance, adjacent cross-
product sum, fixed `1/(n-1)` correction, strict positive gate, contrarian
sides, consumed attempt, aggregate fixed risk, equal-notional atomic package,
and next-month exit are jointly load-bearing. Manual verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_DAILY_PERSISTENCE_REVERSION_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1: `PASS_WITH_PATH_HORIZON_AND_DIRECTION_TRANSLATION_RISK`. The canonical
  child preserves a peer-reviewed gold/silver DOI, official exchange carrier,
  peer-reviewed commodity-memory lineage, complete-read evidence, and durable
  hashes. The daily relative-path gate and contrarian direction are untested
  translations.
- R2: `PASS`. Pair synchronization, month membership, observation bounds,
  chronology, return inclusion, endpoint identity, centering, sums,
  correction, strict threshold, sides, attempt, risk, stops, atomicity, spread
  gates, and lifecycle are fixed.
- R3: `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`. Registered
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus native MT5 calendar, ATR,
  spread, quote, position, deal, and persistent state provide every runtime
  input.
- R4: `PASS`. Deterministic timestamps, logarithms, addition, multiplication,
  division, comparisons, ATR, and execution state only; no trained output,
  banned signal, external runtime feed, grid, martingale, scale-in, or pyramid.

## Claim And Kill Boundary

The fixed positive-score gate is designed to admit approximately half of
valid months, corresponding to roughly six decisions per year. This is a pre-
result density prior, not market evidence. Q02 must retire below five
completed packages in any full post-warm-up year, at zero trades, or with
nonpositive governed economics.

Opposite equal-notional legs are intended to reduce common outright-metal
direction but do not prove dollar, beta, volatility, factor, or portfolio
neutrality. Q09 alone owns the realized portfolio result. No failure may be
rescued by changing the correction, gate, direction, observation inclusion,
carrier, risk, hold, or by adding a fitted center, scale, sign count, block
vote, sequence, range location, seasonality, event, external, or prior-result
state.

## Safety Boundary

This packet supports one Strategy Card, one V5 build, strict compile/Q01, and
one paced non-live Q02 handoff only. It does not authorize a manual backtest,
live artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or decorrelation claim.
