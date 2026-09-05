---
source_id: AI-CODEX-XAUXAG-MBISQUARE-RV-20260905
title: XAU/XAG monthly redescending-bisquare ratio-return reversion
publisher: QuantMechanica governed synthesis of peer-reviewed and exchange sources
source_type: governed_composite_source
status: approved_source_complete
approval_basis: decisions/2026-09-05_xauxag_monthly_bisquare_reversion_source_approval.md
created: 2026-09-05
created_by: Research+Development
parent_sources:
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - CME-GSR-SPREAD-2025
  - MOP-WTI-BISQUARE-2026
cards_extracted:
  - xauxag-mbisquare-rv
---

# XAU/XAG Monthly Redescending-Bisquare Reversion Source Packet

## Approved evidence

The OWNER mission of 2026-09-05 explicitly authorizes one new low-frequency
commodity sleeve and names gold/silver ratio reversion as a candidate. This
packet binds three already governed sources:

1. Karsten Schweikert (2018), “Are gold and silver cointegrated? New evidence
   from quantile cointegrating regressions,” *Journal of Banking & Finance*
   88, 44–51, DOI `10.1016/j.jbankfin.2017.11.010`. The governed complete
   boundary is `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`
   (SHA-256 `4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B`).
2. CME Group, “Gold & Silver Ratio Spread” and associated precious-metals
   spread education. The governed packet is
   `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md` (SHA-256
   `2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`).
3. The exact fixed-step Tukey redescending-bisquare arithmetic in
   `strategy-seeds/sources/MOP-WTI-BISQUARE-2026/source.md` (SHA-256
   `5B9B8452A816309AD0B8BC93830119B9C1DFE11860CECBBC617FFF25ABCA629B`).
   That packet derives the estimator from a reputable peer-reviewed trading
   lineage but does not claim that the estimator itself creates alpha.

Schweikert supports a long-run, state-dependent gold/silver relationship and
warns against assuming one universal constant vector. CME defines the ratio
and the opposed-leg precious-metals spread. The third source fixes transparent
robust-location arithmetic. None tests the conjunction below.

## Bounded QM hypothesis

At the first synchronized D1 bar of each broker month, reconstruct thirteen
consecutive synchronized completed XAU/XAG month-end ratios and form twelve
chronological adjacent log-ratio returns. Estimate their central direction by
the exact 32-step redescending Tukey-bisquare location. Trade the *opposite*
direction as an equal-target-notional XAU/XAG package and renew next month.

For positive synchronized closes `G[0..12]` and `S[0..12]`, oldest first:

```text
q[i] = ln(G[i] / S[i])
r[i] = q[i+1] - q[i], i=0..11
s = sort_ascending(r)
m = (s[5] + s[6]) / 2
d[i] = abs(r[i] - m)
a = sort_ascending(d)
MAD = (a[5] + a[6]) / 2
cutoff = 4.685 * 1.4826 * MAD

mu[0] = m
for j=0..31:
  u[i] = (r[i] - mu[j]) / cutoff
  w[i] = (1-u[i]^2)^2 when abs(u[i]) < 1, else 0
  mu[j+1] = sum(w[i]*r[i]) / sum(w[i])

LONG RATIO  when mu[32] < -1e-12: buy XAU, sell XAG
SHORT RATIO when mu[32] > +1e-12: sell XAU, buy XAG
FLAT otherwise or on invalid arithmetic
```

The median, raw MAD, normalization `1.4826`, cutoff `4.685`, strict support,
frozen cutoff, and exactly 32 updates are locked. Magnitude never changes risk.
The signal is a contrarian QM translation; the peer-reviewed momentum parent
does not supply its direction.

## Identity boundary

The corrected-root deterministic receipt
`artifacts/qm5_xauxag_mbisquare_rv_preallocation_dedup_20260905.json` scanned
4,821 registry identities, 1,440 repository cards, and 45 Strategy Wiki nodes
and returned `CLEAN` (SHA-256
`20199A15CDC7640740D82D8BDADC624B98109932C9882398DCF327F5E352AAA7`).

Manual review separates this exact functional from:

- `QM5_12577` absolute ratio z-score reversion;
- `QM5_20161` rolling OLS residual reversion and `QM5_21526` CADF gating;
- `QM5_20263` one-shot median/MAD tail reversion;
- `QM5_41286` old/recent Siegel-Tukey tail-occupancy reversion;
- `QM5_41318` old/recent squared-rank dispersion reversion; and
- `QM5_20286`, which applies the same estimator to outright WTI returns and
  follows rather than fades its final sign.

Verdict:
`DISTINCT_XAUXAG_SYNCHRONIZED_MONTHLY_RATIO_RETURN_FIXED_32_STEP_REDESCENDING_BISQUARE_CONTRARIAN_BASKET`.
This is an identity verdict, not a performance or correlation claim.

## Reputable-source criteria

- R1 `PASS_WITH_SYNTHESIS_RISK`: peer-reviewed gold/silver relationship,
  exchange-defined spread, and governed exact robust arithmetic; no source
  claims efficacy for the conjunction or Darwinex CFDs.
- R2 `PASS`: symbols, synchronization, endpoint order, formula, direction,
  one-attempt state, opposed legs, fixed risk, stops, and lifecycle are exact.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native XAUUSD.DWX and
  XAGUSD.DWX D1 histories provide all runtime inputs.
- R4 `PASS`: deterministic timestamp, logarithm, sort, absolute-deviation,
  and bounded arithmetic only; no ML, prohibited signal indicator, external
  runtime data, grid, martingale, scale-in, or pyramid.

## Kill and safety boundary

Q02 retires the edge below five completed logical packages in any full
post-warm-up year or on nonpositive governed economics. Downstream gates alone
own robustness and realized book correlation. A failure cannot be rescued by
changing horizon, estimator, direction, constants, carrier, risk, stop, or
retry behavior.

Authorized scope is the card, deterministic registry allocation, one
branch-only non-live V5 build, reference tests, strict Q01, and one paced Q02
enqueue below the host CPU ceiling. No manual backtest, optimization,
portfolio-gate edit, portfolio admission, deploy/live manifest, `T_Live`,
AutoTrading, or live use is authorized.
