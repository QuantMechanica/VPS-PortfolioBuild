# QuantMechanica Edge Lab — Charter

Date: 2026-05-22
Status: ACTIVE PROGRAM CHARTER
Lead: Claude (operation lead), authorized by OWNER 2026-05-22

## Why this exists

Researched / published strategies are not delivering. They are crowded,
regime-dependent, or already arbitraged, and the pipeline gates (correctly)
kill them. The Edge Lab is QuantMechanica's in-house edge-construction
program: we author falsifiable edge theses from structural market causes,
build small variant families, and let the Q00–Q14 gates remain the sole judge.

"Build our own" means we own the **hypothesis** and the **falsification**. It
does NOT mean AI-generated indicator mining — that is curve-fitting, and the
gates will kill it. No ML inside the EA (Hard Rule 14): the AIs are the
research / development tools, never a model embedded in the EA.

## The design box — every Edge Lab EA must fit

Dual deployment target: **Darwinex Zero AND FTMO-style prop**. The intersection
of the two rule sets is the binding box:

- **Drawdown:** ≤5% daily loss, ≤10% total loss. FTMO's 10% total is stricter
  than the DXZ mission's 20% — **FTMO binds.** (Flag for OWNER: this tightens
  the working DD constant for Edge Lab EAs from 20% to 10% total.)
- **News blackout:** mandatory. No trade entries within a blackout window
  around high-impact calendar events; for FTMO compliance, no entries or exits
  in the restricted window. This **overrides `allow_fomc_hold`** — the
  QM5_10260 setting that holds across FOMC is now non-compliant and must be
  removed / inverted.
- **Horizon:** swing (H1–D1, hold hours-to-days) or scalping (M5–M15, hold
  minutes-to-hours). **No HFT** — no sub-minute logic, no tick-scalping, no
  latency arbitrage.
- **No prohibited techniques:** no martingale, no grid, no averaging into
  losers. RISK_FIXED for backtest, RISK_PERCENT for live.
- Mechanical, deterministic, reproducible.

An EA "graduates" the Edge Lab only on a real Q11 PASS **and** a passed
FTMO-compliance check.

## The four directions and launch sequence

Launched sequentially — each direction starts once the prior one has produced
its first screened thesis batch.

1. **Cross-sectional relative-value** (swing / D1) — *launching now.* Rank the
   28-pair FX basket, trade relative strength / weakness. Market-neutral-ish →
   smoother equity → FTMO-friendly. NNFX diversification done as one engine.
2. **Event-conditioned** (swing-horizon drift) — behaviour in the days around
   scheduled events, news-blackout-safe (we trade the drift, not the release
   spike). FOMC track is the seed.
3. **Calendar / seasonal flow** — month-end, quarter-end, expiry, time-of-day
   liquidity. Cheap and fast to test.
4. **SMC / microstructure** (scalping, M5–M15) — one disciplined mechanization
   of liquidity-sweep / order-block / FVG logic. Highest failure odds, last.

## Thesis schema

Every Edge Lab thesis, before any code:

- **Structural cause** — the economic / behavioural / microstructure reason the
  pattern exists.
- **Price signature** — the observable, mechanical pattern.
- **Persistence** — why it is not arbitraged away.
- **Falsification** — the specific test that would kill it.
- **Q08 / Q11 risk** — how it behaves in crisis and around news.
- **FTMO fit** — DD profile, news-blackout compatibility, horizon.

## Workflow & AI division of labour

Gemini (breadth) → Claude (adversarial screen + thesis specs) → Codex
(variant-family build + pipeline wiring) → Q00–Q14 → gates judge.

- Most theses die at the Claude screen, on paper, before any MT5 time. Cheap
  falsification is the discipline.
- Each surviving thesis → 2–3 mechanized variants (a family), so a failed test
  teaches something.
- The pipeline gates are never loosened. Q08 and Q11 stay hard.

## Artifacts

- Charter: this document.
- Thesis bank: `docs/research/EDGE_THESES_*.md`, one per direction.
- Card drafts: `D:/QM/strategy_farm/artifacts/cards_review/` (never written
  directly to `cards_approved/`).
