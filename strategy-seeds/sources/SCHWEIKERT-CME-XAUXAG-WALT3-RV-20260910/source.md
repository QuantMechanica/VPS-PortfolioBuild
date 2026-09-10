---
source_id: SCHWEIKERT-CME-XAUXAG-WALT3-RV-20260910
title: Gold-silver three-week relative-sign alternation reversion
publisher: QuantMechanica governed extraction of peer-reviewed and exchange sources
source_type: peer_reviewed_plus_exchange_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-10_xauxag_weekly_alternation_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - CME-GSR-SPREAD-2025
created: 2026-09-10
created_by: Research+Development
cards_extracted:
  - xauxag-walt3-rv
---

# XAU/XAG Three-Week Relative-Sign Alternation Reversion

## Approval And Complete-Read Scope

The current OWNER PACER mission explicitly authorizes one reputable-source,
structural, low-frequency commodity/energy card, branch-only build, and paced
Q02 enqueue. Before extraction, the complete governed packets
`strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md` and
`strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md` were read. They preserve
the underlying peer-reviewed DOI and CME exchange lineage.

This extraction is bounded to one price-native state: three adjacent completed
week XAU-minus-XAG relative log returns whose signs strictly alternate. It does
not transfer a source result or claim that alternation is a documented anomaly.

## Primary Citations

1. Karsten Schweikert (2018), "Are gold and silver cointegrated? New evidence
   from quantile cointegrating regressions," *Journal of Banking & Finance*
   88, 44-51, DOI `10.1016/j.jbankfin.2017.11.010`.
2. CME Group, "Gold & Silver Ratio Spread," and the governed related exchange
   material recorded in `CME-GSR-SPREAD-2025`.

## Source Boundary And Adverse Evidence

Schweikert supports testing a potentially state-dependent long-run relationship
between gold and silver rather than assuming one fixed equilibrium. CME defines
the gold/silver ratio and supports expressing the metals as an intermarket
relative-value carrier while noting their different monetary and industrial
sensitivities.

Neither source specifies three weekly relative returns, strict sign
alternation, contrarian direction, a one-week hold, ATR stops, equal-notional
CFD legs, or Darwinex continuous labels. Those are explicit, unproven QM
translations. Equal notional is a construction target, not proof of beta,
volatility, dollar, factor, or portfolio neutrality.

## Bounded Mechanization

At the first tradable D1 bar of a new broker week, reconstruct exactly four
consecutive synchronized completed-week endpoints for `XAUUSD.DWX` and
`XAGUSD.DWX`. Each completed week must contain three through five synchronized
sessions. In oldest-to-newest order compute:

`d[i] = log(XAU[i+1]/XAU[i]) - log(XAG[i+1]/XAG[i])`, for `i=0..2`.

All three differences must be finite and have absolute magnitude above
`1e-10`. Open only for strict alternation:

- `d0 > 0, d1 < 0, d2 > 0`: sell XAU and buy XAG;
- `d0 < 0, d1 > 0, d2 < 0`: buy XAU and sell XAG.

Thus the package fades the newest relative winner. Split one aggregate fixed
risk budget across equal-absolute-notional opposed legs, use independent
`3.5 * ATR(20,D1)` hard stops, and close both legs at the next broker-week
boundary. Consume a durable weekly attempt before fallible gates and flatten
malformed or orphaned exposure atomically.

## Non-Duplicate Boundary

The deterministic checker covered 4,890 EA-registry rows, 1,500 repository
cards, and all 45 configured Strategy Wiki nodes. It found no exact identity
and returned five expected fuzzy family members. Manual review resolves them:

- `QM5_41373` uses the same three-return strict alternation topology on an
  XTI/XNG energy-relative-value carrier. This card uses the state-dependent
  gold/silver relationship and XAU/XAG opposed legs; carrier and exposure are
  load-bearing and disjoint.
- `QM5_41066` uses two same-sign relative returns and requires the newest
  magnitude to shrink; this card uses three alternating signs and no magnitude
  comparison.
- `QM5_41075` uses two opposite signs plus a newest-overshoot inequality;
  this card uses three strict alternating signs and ignores magnitude.
- `QM5_41076` uses two same-sign returns plus acceleration; this card's
  adjacent signs must all reverse.
- `QM5_41077` follows a two-return retracement; this card fades the newest leg
  after a three-return alternation path.
- `QM5_41078` requires a fresh three-week same-sign XAU/XAG streak after an
  opposite predecessor. Its admitted state is disjoint from exact alternation.

Verdict:
`DISTINCT_XAUXAG_THREE_WEEK_STRICT_RELATIVE_SIGN_ALTERNATION_NEWEST_WINNER_FADE`.

## Reputable-Source Criteria

- R1: `PASS_WITH_ALTERNATION_TRANSLATION_RISK`. Named peer-reviewed DOI and
  official exchange lineage are preserved; no performance claim transfers.
- R2: `PASS`. Clock, endpoints, synchronization, strict signs, side, attempt,
  risk, stops, atomic repair, and one-week lifecycle are fixed.
- R3: `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`. Registered
  native XAU/XAG D1 histories and broker metadata supply all runtime inputs.
- R4: `PASS`. Deterministic arithmetic only; no ML, external runtime feed,
  banned signal indicator, grid, martingale, pyramid, or adaptive PnL fit.

## Safety And Falsification Boundary

Q02 must retire the card on zero packages, fewer than five completed paired
packages in any full post-warm-up year, or nonpositive governed economics. No
carrier, sign pattern, direction, risk, stop, or lifecycle change is authorized
after results. This approval excludes manual testing, optimization, portfolio
admission, correlation waivers, deployment, live manifests, `T_Live`,
AutoTrading, and live use.
