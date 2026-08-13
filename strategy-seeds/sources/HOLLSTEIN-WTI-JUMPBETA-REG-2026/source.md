---
source_id: HOLLSTEIN-WTI-JUMPBETA-REG-2026
parent_source_id: HOLLSTEIN-AGGJUMP-2021
title: WTI Self-Relative Realized Common-Energy Jump-Beta Regime
publisher: QuantMechanica governed extraction of peer-reviewed sources
source_type: peer_reviewed_trading_paper_bounded_carrier
status: approved_source_complete
approval_basis: decisions/2026-08-13_qm5_20304_wti_jumpbeta_reg_g0.md
parent_sha256: 88E56C93892D2382B7EFA4DB9130991EB1B7C0999C549520F9D3BA9510684D44
created: 2026-08-13
created_by: Research+Development
cards_extracted:
  - wti-jumpbeta-reg
---

# WTI Self-Relative Common-Jump-Beta Source Packet

## Approved Trading Sources Of Record

Hollstein, Fabian; Prokopczuk, Marcel; and Tharann, Bjoern (2021),
"Anomalies in Commodity Futures Markets," *Quarterly Journal of Finance*
11(4), article 2150017, DOI `10.1142/S2010139221500178`.

Nguyen, Duy B. B., and Marcel Prokopczuk (2019), "Jumps in Commodity
Markets," *Journal of Commodity Markets* 13, 55-70, DOI
`10.1016/j.jcomm.2018.10.002`.

The complete accepted manuscript and online appendix for the primary source
were read end to end in the governed parent packet
`strategy-seeds/sources/HOLLSTEIN-AGGJUMP-2021/source.md`, content-bound by the
SHA-256 above. The durable OWNER authorization for this bounded carrier is
`decisions/2026-08-13_qm5_20304_wti_jumpbeta_reg_g0.md`.

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
- WTI and natural gas are explicit members of the source commodity universe.
- Nguyen and Prokopczuk supply only the finding that jumps are material in
  commodity markets and within-sector energy co-jumps can be strong.
- Neither paper studies a realized two-energy-CFD factor, an outright WTI
  position, or a time-series change in WTI jump beta.

## Bounded Carrier Mechanization

At the first processed WTI D1 bar of each genuine broker month, load exactly
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

r_XTI,t = alpha + beta_energy * m_t + beta_jump * jump_t + error_t
```

Use exactly 252 OLS rows per block and require at least six nonzero jump rows.
Buy WTI when recent `beta_jump` is below the preceding value by more than
`1e-12`; sell WTI when it is above by more than `1e-12`. A tie or invalid state
consumes the month flat. XNG is a read-only factor input and may never be
ordered.

This preserves the primary source's jump-beta information object, monthly
clock, and negative high-minus-low orientation while translating a broad
cross-sectional options-based sort into an own-history WTI state. It is not a
replication. No source return, alpha, significance, cost, WTI-only result, CFD
equivalence, trade density, neutrality, or correlation claim transfers.

## Family Evidence

`QM5_13147_energy-jumpbeta` uses the same price-native factor proxy in a
simultaneous XTI/XNG two-leg rank. It passed Q02 through Q07 and failed Q08
hard. The Q08 baseline recorded PF 1.10 and 83 trades; the runs-test p-value
was `0.04487`, and both low- and normal-volatility regime P&L were negative.
Those results are material adverse family evidence. They neither prove nor
disprove this distinct one-leg, two-block carrier and supply no waiver,
parameter change, or performance inheritance.

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
- Solve the intercept/market/jump normal equation by deterministic partial-
  pivot Gaussian elimination and fail closed on singular or nonfinite state.
- Buy below the preceding jump beta by more than `1e-12`; sell above it by
  more than `1e-12`; consume a tie or invalid state flat.
- Host and trade only WTI D1 on slot 0, risk one `RISK_FIXED=1000` position,
  renew monthly, close stale after forty days, and persist the attempted month
  before any history or execution gate.

## Non-Duplicate Boundary

The canonical checker found no exact slug or strategy-ID identity across
4,369 registry rows and 480 cards. One expected source-family match was
manually resolved:

- `QM5_13147_energy-jumpbeta` ranks concurrent XTI and XNG coefficients and
  trades opposite legs. This extraction compares two disjoint WTI coefficient
  histories and owns one WTI position; XNG is read-only.
- `QM5_20303_wti-volbeta-reg` fits the coefficient on changes in rolling
  smooth volatility after zeroing jump rows. This extraction fits the
  coefficient on the realized jump residual itself and has no rolling-
  volatility series or smooth-day floor.
- `QM5_20295`, `QM5_20298`, `QM5_20300`, `QM5_20301`, and `QM5_20302` measure
  marginal kurtosis, volatility-of-volatility, MAX, expected shortfall, or
  activity-scaled absolute return, not controlled common-jump sensitivity.
- WTI trend, calendar, event, breakout, reversal, robust-location, and
  variance-ratio systems use different state variables or clocks.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG pullback,
  not a monthly WTI factor-sensitivity state.

The synchronized inputs, block-local inverse-volatility weights, fixed
two-sigma realized-jump factor, three-column OLS, disjoint offsets, source
low-beta direction, one-leg WTI topology, and consumed monthly attempt are
jointly load-bearing. Verdict:
`CLEAN_AUTHORIZED_WTI_TIME_SERIES_COMMON_JUMP_BETA_AFTER_MANUAL_REVIEW`.

## Reputable-Source Criteria

- R1: PASS with translation and sibling-failure caveats. The primary and
  supplementary sources are peer reviewed, have DOIs, and the governed parent
  records a complete primary-source read.
- R2: PASS. Fixed synchronized blocks, weights, jump estimator, OLS design,
  direction, cadence, risk, stop, attempt, renewal, and stale guard are
  deterministic.
- R3: PASS for the disclosed proxy. Registered XTI/XNG D1 closes suffice;
  realized common-energy jumps are not the source option factor, and XNG is
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
