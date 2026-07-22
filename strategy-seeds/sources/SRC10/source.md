---
source_id: SRC10
source_id_status: CONFIRMED_OWNER_DELEGATED
source_type: paper
title: Indexing and Stock Market Serial Dependence Around the World
authors: Guido Baltussen, Sjoerd van Bekkum, Zhi Da
publication: Journal of Financial Economics, accepted manuscript 2018; published 2019
doi: https://doi.org/10.1016/j.jfineco.2018.07.016
author_manuscript_url: https://personal.eur.nl/vanbekkum/2018%20JFE%20BaltussenVanBekkumDa.pdf
status: EXTRACTION_COMPLETE_CARD_APPROVED
created: 2026-07-17
created_by: Research
last_updated: 2026-07-17
approval_basis: "Explicit OWNER authorization in this workspace on 2026-07-17: 'alles freigegeben, los gehts!' and delegated technical release: 'mach weiter, gib du frei, wir brauchen ein komplettes Buch!'"
parent_issue: LOCAL_OWNER_APPROVAL_RECORD
---

# SRC10 — Baltussen, van Bekkum, and Da: Index MAC(5) reversal

## Source approval and exhaustive read

OWNER approved the proposed FTMO-book sources and delegated technical review in this workspace. This repository record is the durable approval trail.

- Author manuscript: https://personal.eur.nl/vanbekkum/2018%20JFE%20BaltussenVanBekkumDa.pdf
- DOI: https://doi.org/10.1016/j.jfineco.2018.07.016
- Local read copy SHA-256: `495914b78944131b73754759e6003d1cfde3aae5e0e5b7e081411ddaffebeeee`.
- 57 PDF pages read end-to-end on 2026-07-17, including equations, appendices, tables, figures, notes, and references.
- Empirical index sample: earliest available date or 1951 through 2016; 20 developed-market indexes plus corresponding futures and ETFs.

## Distinct strategy extracted

One mechanical strategy is extracted:

| Slot | Slug | Card | Status |
|---|---|---|---|
| S01 | index-mac5-rev | `strategy-seeds/cards/index-mac5-rev_card.md` | APPROVED; EA ID 4007 |

The paper's constituent overweighting and S&P-membership tests are causal identification exercises, not directly portable single-CFD trading rules, so they are not separate cards. EMAC(5) is a robustness measure and is not extracted as an additional strategy.

## Source-faithful signal

For daily log returns `r`, the paper defines the position driver

`m_t = 4*r_(t-1) + 3*r_(t-2) + 2*r_(t-3) + r_(t-4)`

and daily MAC(5) return

`MAC5_t = r_t * m_t / (5*sigma^2)`.

The paper finds post-indexing MAC(5) is negative and describes an economically positive strategy that trades against it. The contrarian target is therefore proportional to `-m_t`; positive `m_t` produces a short target and negative `m_t` a long target. The authors report annualized Sharpe ratios of 0.63 across all indexes and 0.67 for the S&P 500 alone after 1999, before an implementable CFD cost reconciliation.

The variance divisor is a full-sample scaling constant in the paper and does not determine direction. A live implementation may not use a full-sample or future-looking variance estimate. The draft card therefore preserves the exact return weights and direction, while making the exposure-normalization choice an explicit review item.

## Timing interpretation

The signal uses only four completed D1 returns. At the first executable quote of a new broker D1 session, the contrarian target is recomputed. The operational sign-only port retains an existing position when direction is unchanged, closes and reverses on a sign flip, and closes on a flat/invalid target; a restart more than 900 seconds after the boundary flattens stale exposure and skips catch-up entry. Retained volume and its original frozen catastrophic stop are not changed. Daily attribution is mark-to-market, while completed-deal P/L may span several D1 bars. There is no intraday parameter search. A separate one-day implementation-lag diagnostic is source-supported by Tables 2 and 3, but it is not the baseline and may not be selected after seeing results.

## Duplicate and lineage check

- `QM5_1059_jegadeesh-stm-reversal-indices` ranks a four-index basket by unweighted five-day return once per week and holds Friday-to-Friday. It is not the same signal, rebalance frequency, or portfolio construction.
- `QM5_1081_chan-lo-1d-reversal` is a daily cross-sectional long-loser/short-winner rank across a basket. MAC(5) is a single-index time-series signal with fixed linearly declining lags.
- Existing TOM candidates use calendar month boundaries rather than daily serial dependence.
- No Baltussen/van Bekkum/Da MAC(5) source, exact formula, or EA was found in the repository before this extraction.

## Data and implementation boundary

- `SP500.DWX` has D1 history registered for 2018-2026 and is the primary research/backtest instrument. Its separately confirmed Darwinex-Zero route to broker symbol `SP500` is not an FTMO route.
- `GDAXI.DWX` has D1 history for 2018-2026 and is a source-covered cross-sectional falsification target, but its symbol-matrix validation is not currently PASS.
- `NDX.DWX` has only 2021-2026 registered D1 history and a failing matrix evidence record; it cannot be the primary robustness window.
- The source uses indexes, front-month futures, and ETFs. An FTMO CFD lifecycle must be requalified and judged on native `US500.cash` prices, Model-4-equivalent bid/ask costs, financing, session gaps, contract fields, and order routing from a current exact FTMO snapshot; paper Sharpe and Darwinex routing are not net FTMO evidence.

## Limitations carried into review

- The source sample ends in 2016.
- The reported strategy requires daily rebalancing; page 19 explicitly warns that transaction costs may make it unexploitable.
- Full-sample variance scaling is not live-safe and cannot be reproduced with future data.
- The source specifies neither a stop loss nor FTMO account-level sizing.
- A one-index CFD loses the paper's cross-index diversification, although the paper separately reports the S&P 500 result.
- Broker D1 boundaries and weekend/holiday gaps must be fixed before build; they may not be optimized.

Extraction is complete. The card remains `DRAFT` with `ea_id: TBD` until independent CEO/CTO/Quality-Business review resolves exposure normalization, catastrophic-stop sizing, exact day boundary, and cost gates.
