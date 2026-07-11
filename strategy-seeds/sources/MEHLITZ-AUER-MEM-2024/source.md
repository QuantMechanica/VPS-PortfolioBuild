# MEHLITZ-AUER-MEM-2024 — Source Packet

## Approval

- Approval basis: OWNER mission dated 2026-07-11 to select, card, build, and
  enqueue one new non-duplicate structural commodity or energy sleeve.
- Extraction scope: the published `R1-q2` short-memory rule as a bounded WTI
  carrier (`S01`). The Hurst-coefficient family is excluded because the source
  finds it materially weaker, and no alternate parameter family is imported.
- Review status: Chapter 3 of the open doctoral manuscript, including its data,
  methodology, results, robustness sections, conclusion, and Appendix C, was
  reviewed end-to-end on 2026-07-11. The later peer-reviewed journal article is
  the canonical citation and the thesis chapter is its openly readable precursor.

## Canonical Citation

Mehlitz, Julia S., and Benjamin R. Auer (2024), "Memory-enhanced
momentum in commodity futures markets," *The European Journal of Finance*
30(8), 773-802. DOI: https://doi.org/10.1080/1351847X.2023.2220118.

Publisher page:
https://www.tandfonline.com/doi/full/10.1080/1351847X.2023.2220118

Open precursor containing the complete strategy chapter:
https://www.researchgate.net/publication/357152829_Risk_and_return_of_passive_and_active_commodity_futures_strategies

The open document is Julia Sophia Mehlitz's 2021 doctoral thesis, *Risk and
return of passive and active commodity futures strategies*, Brandenburg
University of Technology Cottbus-Senftenberg, CC BY-NC-SA 4.0. Chapter 3 is
"Memory-enhanced momentum in commodity futures markets," pp. 51-74, with
supplementary material on pp. 110-113.

## Relevant Source Locations

- Chapter 3, pp. 53-54: the commodity universe explicitly contains WTI crude
  oil and uses monthly fully collateralized commodity-futures index returns.
- Section 3.3.1, p. 55: winners and losers are determined by positive and
  negative past returns; the paper does not skip a month between ranking and
  investment in the commodity implementation.
- Section 3.3.2.1, pp. 55-56, equations (3.1)-(3.3): variance ratio as a
  weighted aggregation of autocorrelation coefficients and the
  heteroskedasticity-robust Lo-MacKinlay standard-normal statistic.
- Section 3.3.2.2, pp. 56-57, equation (3.4): persistent winners are long,
  persistent losers are short, anti-persistent winners are short, and
  anti-persistent losers are long.
- Section 3.3.2.2, p. 57: use q in `{2,4,7,13}`, link q to ranking period, label
  persistence or anti-persistence only for a two-sided 10% significant
  deviation from one, estimate the test over 32 monthly observations, and
  remain flat when the test is insignificant.
- Tables 3.4-3.5 and Sections 3.4.2-3.4.4, pp. 63-73: `R1-q2` is the leading
  short-memory specification and the authors examine alternative data,
  transaction costs, data mining, and factor exposures.
- Appendix Figure C.2, p. 113: WTI is explicitly shown in the variance-ratio
  analysis.

## Locked Source Rule

For one commodity at each month boundary:

1. Use the latest 32 completed monthly log returns.
2. Set `q=2`, so `VR(2) = 1 + rho_hat(1)`.
3. Compute the Lo-MacKinlay heteroskedasticity-robust standard error from
   equation (3.3) and `z = (VR(2) - 1) / se`.
4. Require `abs(z) > 1.64485362695147`, the two-sided 10% critical value.
5. Classify the latest one-month return as winner when positive or loser when
   negative.
6. Trade `sign(latest_return) * sign(z)`: continuation for significant
   persistence and reversal for significant anti-persistence.
7. Stay flat when the test is insignificant or the latest return is zero.
8. Hold until the next month formation.

The source uses simple returns to describe investment outcomes and log returns
for variance-ratio estimation. Simple and log monthly returns have the same
sign for positive prices, so the EA uses the latest log-return sign without
changing the direction rule.

## Bounded QM Mechanization

`QM5_13134_energy-vr-mom` ports the source's per-commodity decision rule to
`XTIUSD.DWX`, which is the native WTI proxy and is explicitly represented in
the source universe and appendix. It derives 33 completed month-end closes from
completed D1 bars (the tester-safe equivalent of native MN1 closes), forms 32
monthly log returns, applies the locked `R1-q2` statistic, and opens at most one
position per broker month. A frozen D1 ATR hard stop and fixed-risk sizing are
QM risk controls; they do not alter the signal.

This is a falsifiable single-carrier port, not a claim to replicate the
source's diversified long-short futures portfolio. Continuous-CFD roll and
financing behavior, single-instrument concentration, broker monthly bars, and
the significance gate may change both economics and density. Q02 must reject
the carrier below five completed trades per year or on unacceptable economics;
Q09 alone may establish realized portfolio orthogonality.

## Non-Duplicate Review

Repository-wide searches for `memory-enhanced`, `Lo-MacKinlay`,
`anti-persistent`, and a locked variance-ratio momentum rule found no existing
EA or approved card with this mechanic.

- `QM5_11070_persistent-anti` counts weekly direction transitions over ten
  bars and defaults to fading persistence; it has no variance-ratio estimator,
  significance test, monthly return classification, or `R1-q2` lifecycle.
- `chan-at-ts-mom-fut_card.md` is an N-day sign momentum strategy with
  overlapping holding slots. Its optional research axes mention a Hurst or
  variance-ratio filter, but its approved entry is not the published
  significance-gated continuation/reversal matrix mechanized here.
- `QM5_12784_progo-xti` trades a daily public/professional-flow crossover.
- Existing energy momentum, carry, BAB, IVol, skew, kurtosis, MAX, calendar,
  ratio, oscillator, and spread-reversion EAs use different information sets.
- `SRC05` contains educational variance-ratio discussion, but no existing EA
  implements this paper's monthly 32-observation robust test and four-state
  memory-enhanced momentum rule.

The dedup utility reported no exact registry or strategy-ID collision. Its two
fuzzy hits (`energy-bab` and `energy-rsj`) were common `energy-*` slug tokens;
manual mechanic review rejected both as duplicates.
