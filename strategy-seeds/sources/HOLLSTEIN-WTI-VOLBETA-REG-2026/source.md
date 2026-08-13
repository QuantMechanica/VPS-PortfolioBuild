---
source_id: HOLLSTEIN-WTI-VOLBETA-REG-2026
parent_source_id: HOLLSTEIN-AGGVOL-2021
title: WTI Self-Relative Smooth Common-Energy Volatility-Beta Regime
publisher: QuantMechanica governed extraction of peer-reviewed source
source_type: peer_reviewed_trading_paper_bounded_carrier
status: approved_source_complete
approval_basis: decisions/2026-08-13_qm5_20303_wti_volbeta_reg_g0.md
parent_sha256: F8DB880A24BD0F24D75AFA0DF4DF192EE019321391E304B8B45A84929BA334DC
created: 2026-08-13
created_by: Research+Development
cards_extracted:
  - wti-volbeta-reg
---

# WTI Self-Relative Smooth-Volatility-Beta Source Packet

## Approved Trading Source Of Record

Hollstein, Fabian; Prokopczuk, Marcel; and Tharann, Bjoern (2021),
"Anomalies in Commodity Futures Markets," *Quarterly Journal of Finance*
11(4), article 2150017, DOI `10.1142/S2010139221500178`.

The complete accepted manuscript and online appendix were read end to end in
the governed parent packet
`strategy-seeds/sources/HOLLSTEIN-AGGVOL-2021/source.md`, content-bound by the
SHA-256 above. The durable OWNER authorization for this bounded carrier is
`decisions/2026-08-13_qm5_20303_wti_volbeta_reg_g0.md`.

## Trading-Source Findings Used

- The source forms commodity characteristics from the prior twelve months of
  daily data, sorts a broad futures cross-section monthly, and holds the
  resulting portfolios for one month.
- Smooth aggregate-volatility beta is the coefficient on an option-derived
  continuous aggregate-volatility factor in a regression that also controls
  for the equity-market return.
- The source's high-minus-low smooth-volatility-beta spread is positive under
  the baseline construction, fixing the translated direction as high beta
  long and low beta short.
- The ordinary result does not clear the paper-wide multiple-testing
  threshold. That adverse inference is binding.
- WTI and natural gas are explicit members of the source commodity universe.
- The source does not study a realized two-energy-CFD factor, an outright WTI
  position, or a time-series change in WTI beta.

## Bounded Carrier Mechanization

At the first processed WTI D1 bar of each genuine broker month, load exactly
545 synchronized completed D1 closes for `XTIUSD.DWX` and `XNGUSD.DWX`, form
544 chronological simple returns, and split them into two disjoint blocks of
272 returns. Within each block independently:

```text
rank span                 = indices 20..271 (252 observations)
sd_i                      = sample standard deviation on the rank span
w_i                       = inverse(sd_i) / sum(inverse(sd_XTI), inverse(sd_XNG))
m_t                       = w_XTI * r_XTI,t + w_XNG * r_XNG,t
mean_m, sd_m              = mean and sample sd of m_t on indices 20..271
RV20_t                    = sample sd(m_[t-19..t])
smooth_t                  = 0 when abs(m_t - mean_m) >= 2 * sd_m
                            else RV20_t - RV20_[t-1]

r_XTI,t = alpha + beta_energy * m_t + beta_smooth * smooth_t + error_t
```

Use exactly 252 OLS rows per block and require at least 200 non-jump rows.
Buy WTI when recent `beta_smooth` exceeds the preceding value by more than
`1e-12`; sell WTI when it is lower by more than `1e-12`. A tie or invalid
state consumes the month flat. XNG is a read-only factor input and may never
be ordered.

This preserves the source's smooth-volatility-beta information object,
monthly clock, and high-minus-low orientation while translating a broad
cross-sectional options-based sort into an own-history WTI state. It is not a
replication. No source return, alpha, significance, cost, WTI-only result,
CFD equivalence, trade density, neutrality, or correlation claim transfers.

## Family Evidence

`QM5_13151_energy-volbeta` uses the same price-native factor proxy in a
simultaneous XTI/XNG two-leg rank. Its baseline Q02 row recorded PF 1.46, net
profit 1,894.48, and 46 trades. It passed Q03 through Q07 and failed Q08 hard:
the runs-test p-value was `0.02295`, and its low-volatility-regime P&L was
negative. Those results are material family evidence but neither prove nor
disprove this distinct one-leg, two-block carrier and supply no waiver,
parameter change, or performance inheritance.

## Exact Runtime Contract

- Use only completed, exactly synchronized XTI/XNG D1 closes. Require the
  newest endpoint before the decision bar and no more than ten calendar days
  stale, strict series chronology, positive finite closes, and exactly 545
  closes per symbol.
- Convert to 544 chronological simple returns. The preceding block uses
  returns `0..271`; the recent block uses returns `272..543`. They share only
  the boundary close and no return.
- Each block computes its own inverse-volatility weights, factor mean and
  sample standard deviation, jump classification, rolling sample volatility,
  and OLS coefficients.
- The 20-return realized-volatility window uses denominator 19. Jump days
  remain in the 252-row regression with `smooth_t=0`; they are not dropped.
- Solve the intercept/market/smooth normal equation by deterministic partial-
  pivot Gaussian elimination and fail closed on singular or nonfinite state.
- Buy above the preceding beta by more than `1e-12`; sell below it by more
  than `1e-12`; consume a tie or invalid state flat.
- Host and trade only WTI D1 on slot 0, risk one `RISK_FIXED=1000` position,
  renew monthly, close stale after forty days, and persist the attempted month
  before any history or execution gate.

## Non-Duplicate Boundary

The canonical checker found no exact slug or strategy-ID identity across
4,368 registry rows and 479 cards. One expected fuzzy source-family match was
manually resolved:

- `QM5_13151_energy-volbeta` ranks concurrent XTI and XNG coefficients and
  trades opposite legs. This extraction compares two disjoint WTI coefficient
  histories and owns one WTI position; XNG is read-only.
- `QM5_20298_wti-vov-regime` measures dispersion over the mean of nested WTI
  realized-volatility levels. It has no common-energy factor, return
  regression, jump zeroing, or beta coefficient.
- WTI MAX, ES, ALIQ, skewness, kurtosis, trend, robust-location, calendar,
  event, breakout, reversal, and variance-ratio systems use different state
  variables or clocks.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon, long-only XNG pullback,
  not a monthly WTI factor-sensitivity state.

The synchronized inputs, block-local inverse-volatility weights, 20-return
sample-volatility changes, two-sigma zeroing, three-column OLS, disjoint
offsets, source high-beta direction, one-leg WTI topology, and consumed
monthly attempt are jointly load-bearing. Verdict:
`CLEAN_AUTHORIZED_WTI_TIME_SERIES_SMOOTH_VOL_BETA_AFTER_MANUAL_REVIEW`.

## Reputable-Source Criteria

- R1: PASS with inference, translation, and sibling-failure caveats. The
  primary source is peer reviewed, has a DOI and complete institutional text,
  and the governed packet preserves its weak multiple-testing evidence.
- R2: PASS. Fixed synchronized blocks, weights, rolling-volatility estimator,
  jump rule, OLS design, direction, cadence, risk, stop, attempt, renewal, and
  stale guard are deterministic.
- R3: PASS for the disclosed proxy. Registered XTI/XNG D1 closes suffice;
  realized common-energy volatility is not the source option factor, and XNG
  is read-only.
- R4: PASS. Native arithmetic only; no trained output, prohibited signal
  indicator, external runtime feed, grid, martingale, or pyramid.

## Claim, Kill, And Safety Boundary

Q02 must retire the carrier below five completed positions per full post-
warm-up year or on nonpositive governed economics. Q09 alone may establish
realized book correlation. No failed result may change the return type, block
support, weights, standard-deviation denominator, RV window, jump rule, OLS
design, direction, carrier, cadence, risk, stop, hold, spread, or retry policy.

This packet authorizes one branch-only non-live build and paced Q02 handoff.
It excludes manual testing, live/demo/shadow/stress/optimization artifacts,
AutoTrading, `T_Live`, deploy manifests, portfolio gates, portfolio admission,
and correlation waivers.

