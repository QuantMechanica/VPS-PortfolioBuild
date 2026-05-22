---
title: Portfolio Fit Caps — Dual-Gate Reference Table
date: 2026-05-15
qa_agent: Quality-Business (0ab3d743-e3fb-44e5-8d35-c05d0d78715d)
authority: DL-061 (forex_market_cap_interpretation.md, V5 Pipeline Operations decisions folder)
ratified_by: CEO (QUA-1528)
status: BINDING
---

# Portfolio Fit Caps — Dual-Gate Reference Table

This document is the QB-owned canonical reference for portfolio-fit concentration caps applied
at the dual-gate (G0/G1 card selection) and at P9 (deploy-inclusion decision).
Authority: DL-061, ratified by CEO at QUA-1528.

---

## 1. Asset-Class / Market Caps

| Asset class | G0/G1 gate (card-selection) | P9 gate (live deploy) | Authority |
|---|---|---|---|
| **Forex market** | Option A: 40% of FX deployable sub-universe. Does NOT bind on FX card count given DXZ FX-first universe. QB G1 only flags if a *non-FX* class exceeds 40% of its own sub-universe. | Option C: 40% of live equity allocation in FX-market instruments at any one time. QB triggers CEO P9 review if proposed deploy would breach 40% live FX allocation. | DL-061 |
| **Indices** | Option A: 40% of indices deployable sub-universe (on DXZ typically the full sub-universe given narrow coverage). | Same as G0 — 40% of live equity allocation if indices coverage widens. | DL-061 |
| **Commodities** | Option A: 40% of commodities deployable sub-universe. | Same as G0. | DL-061 |
| **Metals** | Option A: 40% of metals deployable sub-universe. | Same as G0. | DL-061 |
| **Energy** | Option A: 40% of energy deployable sub-universe. | Same as G0. | DL-061 |

### Forex-market cap interpretation detail (DL-061)

- **G0/G1 (Option A):** The 40% cap is relative to the *deployable universe* for FX on DXZ, not to
  the total multi-asset universe. Because DXZ is FX-primary (90%+ of listed instruments are FX
  pairs), a portfolio that is 100% FX does not violate the G0 cap. QB G1 only flags if a *non-FX*
  card class exceeds 40% of its own deployable sub-universe.
- **P9 (Option C):** Once EAs are live, 40% of live equity allocation must not be concentrated in
  FX-market instruments. This is the binding constraint on actual capital exposure. QB raises a
  CEO P9 review trigger if a proposed deploy would push the live FX allocation above 40%.

---

## 2. Timeframe Cap

| Cap | Gate applied | Value |
|---|---|---|
| Single timeframe (M15 / H1 / H4 / D1) | P9 live portfolio | Max 30% of live portfolio |

QB monitors at G0/G1 for early warning but does not hard-block builds. Hard-block applies at P9
inclusion if adding the EA would push any single timeframe above 30% of live portfolio.

---

## 3. Correlation Cap

| Cap | Gate applied | Value |
|---|---|---|
| Pairwise strategy correlation | P9 live portfolio | < 0.7 on 6-month equity curves |

Measured using equity-curve pairwise correlation at the time of P9 inclusion decision.

---

## 4. Style Cap

| Cap | Gate applied | Value |
|---|---|---|
| Single style (trend-following / mean-revert / breakout / news) | P9 live portfolio | Max 50% of live portfolio |

QB monitors style distribution at G0/G1 (as flagged in dual-gate registry) for early warning.
Hard-block at P9 if adding the EA would push any single style above 50%.

---

## 5. Summary Matrix

| Dimension | G0/G1 rule | P9 hard-gate |
|---|---|---|
| Forex market | 40% of FX sub-universe (Option A, DL-061) — not a card-count cap | 40% of live equity in FX (Option C, DL-061) |
| Indices / commodities / metals / energy | 40% of that class's deployable sub-universe | 40% of live equity per class |
| Timeframe | Monitor + warn | 30% per timeframe |
| Pairwise correlation | — | < 0.7 |
| Style | Monitor + warn | 50% per style |

---

## 6. Amendment History

| Date | Change | Authority |
|---|---|---|
| 2026-05-15 | Initial ship — forex-market cap two-layer phrasing (Option A at G0, Option C at P9). Indices/commodities/metals/energy set to Option A at G0. Timeframe / correlation / style caps unchanged. | DL-061 / CEO QUA-1528 / QB QUA-1529 |

---

*QB Quality-Business — 2026-05-15. Cite this file as `processes/strategy_cards/portfolio_fit_caps.md`.
For amendment, open an issue referencing the relevant Decision Log entry.*
