---
source_id: SRC10
tier: T2_named_public_container
parent_issue: QUA-1604
lane: 3_of_4
status: intake_complete_one_candidate_proposed
authored-by: Research Agent
date-checked: 2026-05-15
source-url: https://www.mql5.com/en/market/mt5/expert
source-name: MQL5 Market — MT5 Expert Advisors
access-method: WebFetch (top-product page summary OK) + WebSearch for product detail
mode: IDEA_DISCOVERY_ONLY
proprietary-code-prohibition: BINDING — no MQL5 source code is copied, downloaded, decompiled, or reverse-engineered. Idea-level extraction only, then codified from first principles by Research/Dev.
---

# SRC10 — MQL5 Market MT5 Expert Advisors (Lane 3 of QUA-1604)

## 1. Source identification

- **Source:** MQL5 Market — MT5 Expert Advisors storefront (commercial).
- **URL:** https://www.mql5.com/en/market/mt5/expert
- **Date checked:** 2026-05-15
- **Tier:** T2 (OWNER-named public container)
- **Issue:** [QUA-1604](/QUA/issues/QUA-1604) Lane 3

## 2. Mode

**Idea discovery only.** Per QUA-1604: *"do not copy proprietary code; reject black-box martingale/grid unless clearly justified."*

The intake operates on **public product descriptions** (vendor-authored marketing copy on the MQL5 Market product page) — not on MQL5 source code, not on decompiled binaries, not on signal-listing trade histories. Any candidate forwarded to G0 is to be codified **from first principles by Research/Dev** based only on the publicly stated concept; no rule is to be copied verbatim from the vendor product page.

## 3. Survey scope and rejection criteria

Inspected: the MQL5 Market storefront page (top-of-rank section) plus blog-aggregator commentary on best-selling EAs.

Hard rejection:
- Black-box (vendor refuses to disclose strategy mechanism)
- Martingale or grid recovery
- "AI signals" / undisclosed-ML-decided entries
- Vague concept that cannot be codified to a specific edge

Conditional acceptance:
- Concept fully disclosed in product description (BB touch, breakout, session range, etc.)
- Risk management plainly stated (single position OK; multiple-position-pyramiding-without-cap is REJECT-adjacent)
- No martingale / no grid

## 4. EAs surveyed

| # | EA (MQL5 product) | Vendor | Strategy concept (vendor's description) | Disposition | Reason |
|---|---|---|---|---|---|
| 1 | [Quantum Queen MT5 (118805)](https://www.mql5.com/en/market/product/118805) | Bogdan Ion Puscasu | "proprietary intelligent algorithm" XAUUSD | REJECT — black-box | Vendor does not disclose mechanism; independent commentary (mql5/blogs/post/759696) flags curve-fitting on gold only |
| 2 | Quantum Emperor MT5 | Bogdan Ion Puscasu | "groundbreaking" GBPUSD | REJECT — black-box | No disclosed mechanism |
| 3 | Quantum Valkyrie | Bogdan Ion Puscasu | "Precision.Discipline.Execution" multi-instrument | REJECT — black-box | No disclosed mechanism |
| 4 | Pulse Engine | Jimmy Peter Eriksson | "intraday directional pattern scalping without martingale/grid... independent of indicators" | REJECT — concept too vague | No specific edge stated; "intraday directional patterns" is unprovable without specification of which patterns |
| 5 | [BB Return MT5 (162150)](https://www.mql5.com/en/market/product/162150) | Leonid Arkhipov | "Gold XAUUSD M5 — return of price to Bollinger Bands range; wait for *confirmed return candle*, not a band touch; additional filters; no grid/martingale; single-position" | **CANDIDATE — see §5** | Concept fully disclosed; no martingale/grid; "wait for confirmed return candle" is a specific entry rule distinct from naive band-touch |
| 6 | [Bollinger Bands Mean Reversion With Walk Feature (150219)](https://www.mql5.com/en/market/product/150219) | (various) | Gold M1 BB mean-reversion with "walk" feature | REJECT — redundant | Same family as #5; #5 has cleaner concept description and explicit no-grid stance |
| 7 | Full Throttle DMX | (multi-pair vendor) | "10 independent strategies" on EURUSD/AUDUSD/NZDUSD/EURGBP/AUDNZD with "well-known technical indicators" | REJECT — bundle | Bundle of 10 strategies is not a single edge; the 10 sub-strategies are not individually disclosed enough to pick one |
| 8 | Aurum | (gold vendor) | XAUUSD without news filter, without protective restrictions, "profitable and stable" | REJECT — black-box | No disclosed mechanism; "no protective restrictions" + "no news filter" is a stability red-flag, not a strength |
| 9 | [Mean Reversion Jutsu (120766)](https://www.mql5.com/en/market/product/120766) | (vendor) | Mean-reversion (free download) | REJECT — concept undisclosed | Free product but product page does not disclose mechanism in surveyed snippets |
| 10 | [Momentum Reversal Scalper XAUUSD (171641)](https://www.mql5.com/en/market/product/171641) | (vendor) | XAUUSD momentum-reversal scalping | REJECT — concept undisclosed | "momentum reversal" without parameters is non-specific |
| 11 | [FMAN ScalpXAU M1 (142531)](https://www.mql5.com/en/market/product/142531) | (vendor) | XAUUSD M1 scalping | REJECT — concept undisclosed | M1 gold scalping is a category, not an edge; mechanism not disclosed |

## 5. Candidate proposed for G0

### SRC10_S01 — Confirmed-Return-Candle Bollinger Band Mean-Reversion on XAUUSD M5 *(idea, not code)*

**Source citation:**
> Leonid Arkhipov, "BB Return MT5" — MQL5 Market product 162150 — https://www.mql5.com/en/market/product/162150 (vendor product description accessed 2026-05-15). **No source code consulted; no signal trade history consulted; idea-only extraction from publicly-displayed product description.**

**Idea (in Research's words, codified from product-page concept):**

A mean-reversion strategy that:
1. Trades XAUUSD on M5.
2. Operates only on Bollinger Band excursions that subsequently produce a **confirmed return candle** — i.e. the next candle after a band-piercing candle closes back inside the bands. This is the distinctive rule vs. naive band-touch entry: naive entry trades the touch; this concept trades the **post-touch confirmation**, filtering out trend-continuation breaks.
3. Single position at a time, no grid, no martingale.
4. Uses additional filters to exclude "weak and non-working market situations" — vendor does not disclose which filters. Research's first-principles candidate filter set: (a) reject in extreme-trend regime (e.g. ATR-percentile or ADX threshold); (b) reject during macro news high-impact-event blackout (V5 framework).

**Mechanical-rules pre-check (everything below to be ratified at G0):**

| Element | Proposed rule (Research's codification) | Status |
|---|---|---|
| Instrument | XAUUSD | ✓ |
| Timeframe | M5 | ✓ (SCALPING flag applies — VPS-realistic-latency P5b will be binding) |
| Indicator | Bollinger Bands (20, 2.0) — standard parameters; G0 to confirm | ✓ |
| Long entry | Bar N closes below lower BB; bar N+1 closes back ABOVE lower BB; enter long at bar N+1 close | ✓ deterministic |
| Short entry | Bar N closes above upper BB; bar N+1 closes back BELOW upper BB; enter short at bar N+1 close | ✓ deterministic |
| Stop loss | Below bar N low (for long) / above bar N high (for short), with small buffer (G0: spread+1 ATR(14) on M5 or 5 fixed pips, whichever larger) | ✓ deterministic |
| Take profit | BB middle band (20-SMA) touch — classical mean-reversion target | ✓ deterministic |
| Filter 1 | ADX(14) < 25 on M5 (reject in strong-trend regime) | ⚠ to-be-confirmed at G0 |
| Filter 2 | Economic-calendar high-impact-event blackout per V5 framework | ✓ standard |
| Position management | Single position; no scaling-in, no grid, no martingale | ✓ |
| Time-stop | Close at N=12 bars (1 hour on M5) if neither TP nor SL hit | ✓ deterministic — Research adds this; not in vendor description, but standard MR hygiene |

**Author performance claim:** None quoted. Vendor product page exists but Research has not consulted vendor-disclosed backtest or signal history (out of caution against borrowing curve-fit defaults). QM P2 baseline will be the binding evidence.

**V5 flags:**
- `SCALPING` — M5 entries; P5b VPS-realistic-latency required
- `MEAN_REVERSION` — V5 supports MR family
- `GOLD_SPECIFIC` — XAUUSD-only candidate; G0 to also evaluate the obvious generalization to other high-volatility instruments (DAX, NAS100, USOIL)
- No ML / SMC / Elliott / Gann

**Differentiation from existing QM cards:**
- vs. `chan-bollinger-es`: Chan's BB strategy on ES (S&P 500 emini) uses different instrument and naive band-touch entry; this candidate adds the **confirmation-candle filter** and trades XAUUSD.
- vs. `chan-at-bb-pair`: Chan's BB pairs is a relative-value strategy, not a single-instrument MR.
- No existing XAUUSD BB mean-reversion in QM portfolio.

**Proprietary-code prohibition satisfied:** Rules above are Research's codification of the publicly-stated CONCEPT. No vendor source code, signal trade history, or proprietary parameter values have been used. The 20/2.0 BB parameters and ADX/N-bar filters are V5-standard defaults to be optimized in P3, not borrowed from vendor.

## 6. Lane disposition

- **EAs surveyed:** 11 (top-of-rank + corroborated cross-search hits)
- **EAs passing idea-disclosure + no-martingale/grid screen:** 1 of 11 (signal rate ≈ 9%)
- **Candidates forwarded to G0:** 1 (SRC10_S01)
- **Candidates rejected with evidence:** 10 (table above)

**Storefront-wide observation:** MQL5 Market top-of-rank is dominated by (a) Bogdan Ion Puscasu's "Quantum" series and similar black-box gold/forex EAs with undisclosed mechanisms — many of which independent commentary (e.g. mql5/blogs/post/759696 "Top 10 Expert Advisors in the market — the Golden trick", November 2024) flags as gold-only curve-fit; (b) generic XAUUSD M1/M5 scalpers; (c) bundle "10-strategy" EAs that don't expose individual rules. The "no martingale/grid, disclosed concept" cohort is rare. BB Return is the cleanest specimen for idea-level extraction.

**Lane 3 status:** COMPLETE. Hand off SRC10_S01 to G0 review on a child issue if CEO ratifies this intake.

## 7. Next-lane gate

Lane 3 produces: **1 candidate (SRC10_S01) + evidence-backed reject for 10 other EAs.** Gate condition satisfied to proceed to Lane 4 (legacy local).
