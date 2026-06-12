# Self-Development Hypothesis Backlog — own-data, hypothesis-first

**Author:** Claude · **Date:** 2026-06-12 · **Status:** living program doc ·
**Method precedent:** `CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` (produced the AUDUSD~
NZDUSD OOS survivor, net Sharpe 1.29 — our only own-developed edge so far).

## Program rules (pre-registered, non-negotiable)

1. **Hypothesis before data.** Each entry states mechanism + direction BEFORE the study.
2. **DEV/OOS split** stated up front (default: DEV 2018-2022, OOS 2023-2026).
3. **Tradeable threshold:** OOS net Sharpe > 0.5 with same sign as DEV, net of
   worst_case_dxz_ftmo costs. Below = DEAD or INCONCLUSIVE; no card.
4. **Tooling:** `D:/QM/mt5/T_Export` analysis terminal only (factory-collision-free),
   Export_FX_Bars.mq5 + analyze_cross_asset*.py patterns.
5. Cards are written ONLY from study survivors; the study doc is the card's R1 source.

## Backlog (priority order)

| # | Hypothesis | Mechanism | Status |
|---|---|---|---|
| H1 | XAUUSD drifts down into the 10:30 London AM fix and up after the 15:00 PM fix (2016-2026) | LBMA auction hedging flow (Nilsson 2015 pattern, post-reform unverified) | DISPATCHED (task 27195799, study A) |
| H2 | OPEX-week long-index effect exists at index level post-2010 on NDX/WS30/GDAXI; week-after-witching is weak | delta-hedge unwind flows | DISPATCHED (task 27195799, study B) |
| H3 | NDX/XAU have stable intra-session return structure (NY lunch lull vs power hour) 2018-2026 | institutional execution scheduling (VWAP/MOC clustering) | QUEUED (task: this doc) |
| H4 | GDAXI drifts systematically between Xetra cash close (17:30 CET) and US close (22:00 CET) | European cash-close flow vs 24h CFD pricing; literature ends 2015, post-2016 unmapped | QUEUED (task: this doc) |
| H5 | XAU Asia-range contraction (< 0.6x median) predicts London-session directional expansion | volatility clustering + session liquidity cycle; validates/falsifies the AMD card family (QM5_12540) independently | QUEUED (task: this doc) |
| H6 | FX majors show systematic Wednesday (triple-swap) pre/post-rollover pressure | swap-avoidance position flows; wave-1 research: unmined, not dead | backlog |
| H7 | Gold day-of-week structure post-2018 (Friday strength claim) survives OOS | weekly hedging cycle | backlog |
| H8 | NDX-XAU D1 regime relationship is exploitable as a portfolio FILTER (not a strategy): XAU strength regime → NDX mean-reversion outperforms trend | risk-on/off rotation; feeds Q11 portfolio layer (DL-064), not a card | backlog |
| H9 | Oil-return → index-return predictability (Driesprong-Jacobsen-Maat) is DEAD post-2015 in G7 — confirm on XTIUSD.DWX → NDX/WS30/GDAXI before anyone cards it | documented decay (Quantpedia #0096 follow-up refs); cheap D1 falsification study | backlog |

## Why this program (honest math)

External mining yield is ~1 survivor per 700 EAs because published edges are crowded
or stale (see `EDGE_QUALITY_RESEARCH_SYNTHESIS_2026-06-09.md`). The one edge nobody
else can have mined is structure in OUR instruments' OWN data that was never published.
The AUDNZD study proved the loop works end-to-end. Cost per study: hours of T_Export
compute, zero factory disruption. Even a 1-in-4 study hit rate beats card-volume
economics by an order of magnitude.

## Log

- 2026-06-12: program formalized; H1+H2 dispatched (27195799); H3-H5 dispatched (see
  router task created same day); H6-H8 backlog.
