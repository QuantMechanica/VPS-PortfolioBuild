---
source_id: HOLLSTEIN-XNG-JUMPBETA-REG-2026
parent_source_id: HOLLSTEIN-AGGJUMP-2021
title: XNG Self-Relative Realized Common-Energy Jump-Beta Regime
publisher: QuantMechanica governed extraction of peer-reviewed sources
source_type: peer_reviewed_trading_paper_bounded_carrier
status: approved_source_complete
approval_basis: decisions/2026-08-13_qm5_20306_xng_jumpbeta_reg_g0.md
parent_sha256: 88E56C93892D2382B7EFA4DB9130991EB1B7C0999C549520F9D3BA9510684D44
created: 2026-08-13
created_by: Research+Development
cards_extracted:
  - xng-jumpbeta-reg
---

# XNG Self-Relative Common-Jump-Beta Source Packet

## Approved Trading Source Of Record

Hollstein, Fabian; Prokopczuk, Marcel; and Tharann, Bjoern (2021),
"Anomalies in Commodity Futures Markets," *Quarterly Journal of Finance*
11(4), article 2150017, DOI `10.1142/S2010139221500178`.

The complete accepted manuscript and online appendix were read end to end in
the governed parent packet
`strategy-seeds/sources/HOLLSTEIN-AGGJUMP-2021/source.md`, content-bound by the
SHA-256 above. The durable OWNER authorization for this bounded carrier is
`decisions/2026-08-13_qm5_20306_xng_jumpbeta_reg_g0.md`.

Nguyen, Duy B. B., and Marcel Prokopczuk (2019), "Jumps in Commodity Markets,"
*Journal of Commodity Markets* 13, 55-70, DOI
`10.1016/j.jcomm.2018.10.002`, is retained only as supporting energy co-jump
context; it is not a second strategy source and supplies no trade direction.

## Trading-Source Findings Used

- The primary source forms commodity characteristics from the prior twelve
  months of daily data, sorts a broad futures cross-section monthly, and holds
  the resulting portfolios for one month.
- Aggregate jump beta is the coefficient on an option-derived jump factor in a
  daily regression that also controls for market return.
- The source's high-minus-low jump-beta spread is negative, fixing the
  translated direction as low jump beta long and high jump beta short.
- The paper treats jump risk as one of its significant, robust commodity
  premia; no numerical performance result transfers to this carrier.
- Natural gas and WTI are explicit members of the source commodity universe.
- Neither paper studies a realized two-energy-CFD factor, an outright XNG
  position, or a time-series change in XNG jump beta.

## Bounded Carrier Mechanization

At the first processed XNG D1 bar of each genuine broker month, load exactly
505 synchronized completed D1 closes for `XTIUSD.DWX` and `XNGUSD.DWX`, form
504 chronological simple returns, and split them into two disjoint blocks of
252 returns. Within each block independently:

```text
sd_i       = sample standard deviation of the 252 returns for leg i
w_i        = inverse(sd_i) / sum(inverse(sd_XTI), inverse(sd_XNG))
m_t        = w_XTI * r_XTI,t + w_XNG * r_XNG,t
mean_m     = average(m_t)
sd_m       = sample standard deviation(m_t)
jump_t     = m_t - mean_m when abs(m_t - mean_m) >= 2 * sd_m
             else 0

r_XNG,t = alpha + beta_energy * m_t + beta_jump * jump_t + error_t
```

Use exactly 252 OLS rows per block and require at least six nonzero jump rows.
Buy XNG when recent `beta_jump` is below the preceding value by more than
`1e-12`; sell XNG when it is above by more than `1e-12`. A tie or invalid
state consumes the month flat. XTI is a read-only factor input and may never
be ordered.

This preserves the primary source's jump-beta information object, monthly
clock, and negative high-minus-low orientation while translating a broad
cross-sectional options-based sort into an own-history XNG state. It is not a
replication. No source return, alpha, significance, cost, XNG-only result, CFD
equivalence, trade density, neutrality, or correlation claim transfers.

## Family Evidence

`QM5_13147_energy-jumpbeta` uses the same price-native factor proxy in a
simultaneous XTI/XNG two-leg rank. It passed Q02 through Q07 and failed Q08
hard. The Q08 baseline recorded PF 1.10 and 83 trades; the runs-test p-value
was `0.04487`, and both low- and normal-volatility regime P&L were negative.
Those results are material adverse family evidence. They neither prove nor
disprove this distinct one-leg, two-block XNG carrier and supply no waiver,
parameter change, or performance inheritance.

`QM5_20304_wti-jumpbeta-reg` is the same locked estimator and lifecycle on
WTI. It establishes implementability only. Its performance, correlation, and
carrier behavior do not transfer to natural gas.

## Exact Runtime Contract

- Use only completed, exactly synchronized XTI/XNG D1 closes. Require the
  newest endpoint before the decision bar and no more than ten calendar days
  stale, strict series chronology, positive finite closes, and exactly 505
  closes per symbol.
- Convert to 504 chronological simple returns. The preceding block uses
  returns `0..251`; the recent block uses returns `252..503`. They share only
  the boundary close and no return.
- Each block computes its own inverse-volatility weights, factor mean and
  sample deviation, jump classification, and OLS coefficients.
- The jump threshold is inclusive at two sample deviations. Non-jump rows
  remain in the 252-row regression with `jump_t=0`; no row is dropped.
- Regress XNG return on an intercept, common-energy return, and jump residual.
  Solve the normal equation by deterministic partial-pivot Gaussian
  elimination and fail closed on singular or nonfinite state.
- Buy below the preceding jump beta by more than `1e-12`; sell above it by
  more than `1e-12`; consume a tie or invalid state flat.
- Host and trade only XNG D1 on slot 0, risk one `RISK_FIXED=1000` position,
  renew monthly, close stale after forty days, and persist the attempted month
  before any history or execution gate.
- Use a frozen `3.5 * ATR(20,D1)` hard stop, no take-profit, a 3,000-point
  entry-spread cap, and no retry after a stop or failed gate.

## Non-Duplicate Boundary

The canonical checker found no exact slug or strategy-ID identity across
4,371 registry rows and 482 root cards. Four expected family matches were
manually resolved:

- `QM5_13147_energy-jumpbeta` ranks concurrent XTI and XNG coefficients and
  trades opposite legs. This extraction compares two disjoint XNG coefficient
  histories and owns one XNG position; XTI is read-only.
- `QM5_20304_wti-jumpbeta-reg` trades WTI. This carrier extension trades XNG
  with locked parameters and imports no sibling result.
- `QM5_20303_wti-volbeta-reg` fits a smooth-volatility-change coefficient,
  not the extreme-day jump residual coefficient.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG oscillator
  pullback, not a monthly symmetric common-jump-sensitivity regime.
- XNG ALIQ, skew, kurtosis, volatility-of-volatility, trend, calendar,
  seasonality, event, variance-ratio, and relative-value systems use different
  state variables or clocks.

The XNG carrier, synchronized inputs, block-local inverse-volatility weights,
fixed two-sigma jump factor, three-column OLS, disjoint offsets, source low-
beta direction, one-leg topology, and consumed monthly attempt are jointly
load-bearing. Verdict:
`CLEAN_AUTHORIZED_XNG_TIME_SERIES_COMMON_JUMP_BETA_CARRIER_EXTENSION_AFTER_MANUAL_REVIEW`.

## Reputable-Source Criteria

- R1: PASS with translation and sibling-failure caveats. The single primary
  source is peer reviewed, has a DOI, and the governed parent records a
  complete source read.
- R2: PASS. Fixed synchronized blocks, weights, jump estimator, OLS design,
  direction, cadence, risk, stop, attempt, renewal, and stale guard are
  deterministic.
- R3: PASS for the disclosed proxy. Registered XTI/XNG D1 closes suffice;
  realized common-energy jumps are not the source option factor, and XTI is
  read-only.
- R4: PASS. Native arithmetic only; no trained output, prohibited signal
  indicator, external runtime feed, grid, martingale, or pyramid.

## Claim, Kill, And Safety Boundary

Q02 must retire the carrier below five completed positions per full post-
warm-up year or on nonpositive governed economics. Q09 alone may establish
realized book correlation. No failed result may change the return type, block
support, weights, deviation denominator, jump threshold, OLS design,
direction, carrier, cadence, risk, stop, hold, spread, or retry policy.

This packet authorizes one branch-only non-live build and paced Q02 handoff. It
excludes manual testing, live/demo/shadow/stress/optimization artifacts,
AutoTrading, `T_Live`, deploy manifests, portfolio gates, portfolio admission,
and correlation waivers.
