# DL-081 — Bounded-Risk Grid/Hedged-Basket Exception (account-capped at 1%)

**Date:** 2026-06-30
**Status:** ADOPTED (OWNER-authorized)
**Authority:** OWNER (Hard Rules live under OWNER; this is an explicit, documented
exception — not a silent violation. Claude enforces it as written.)
**Supersedes (scoped):** the V5 Hard Rule "no martingale / grid / averaging-down" — for
this strategy class ONLY.

## Context
The Antigravity agent-army reverse-engineered the `UnconventionalForexTrading` channel's
**T-WIN / U.F.O. basket strategy** (Dr. Marco Giavon): a currency-strength model that ranks
the 8 majors, builds a **hedged basket** of strongest-vs-weakest pairs, and manages it with
**grid / hedging-recovery** logic. The edge (relative-strength divergence basket) is real and
mechanizable; the grid/recovery money-management is the V5-forbidden part.

## Decision
**Grid + hedged-basket + averaging mechanics are PERMITTED for this strategy class, gated by a
HARD aggregate risk cap of 1% of account equity.** On a €100k account that is a €1,000 maximum
loss for the entire trading idea per cycle. Within that envelope the basket may open multiple
correlated legs and add to positions; the cap — not a per-leg stop — is the safety invariant.

### The binding invariant (what makes this NOT classic martingale)
- A **basket-level hard equity stop** at **1% of ACCOUNT_EQUITY** (account-wide, measured on
  floating P&L across ALL legs of the idea) **flattens the entire basket** when breached.
- Therefore **max realized loss per cycle = 1%** (ex-gap; see caveats). This converts an
  unbounded grid into a **bounded-risk basket**.
- No doubling-to-recover beyond the cap: once aggregate floating P&L hits −1%, everything
  closes. The grid lives entirely inside the 1% box.

### Why this is acceptable (the asymmetry)
- Downside per cycle is **hard-capped at 1%**; upside is **uncapped** — when the strength
  divergence resolves, multiple basket legs profit together, so a cycle can return several×1%.
- "Über-proportionale Gewinne bei kontrolliertem Risiko" = this asymmetry, NOT leverage abuse.

## Scope & limits
- **This strategy class only** (currency-strength hedged basket). This is NOT a blanket repeal
  of the no-grid Hard Rule; every other EA remains bound by it unless OWNER extends this DL.
- **Risk-mode discipline unchanged:** RISK_FIXED for backtest / RISK_PERCENT for live; the 1%
  cap is a basket-equity-stop layered on top, not a replacement for per-trade sizing.
- **Profitability is still judged by the pipeline.** The 1% cap makes the idea SAFE, not
  profitable. It must still clear Q02–Q08 (the capped losers must be outweighed by winning
  cycles). The cap changes the risk envelope; it does not lower any gate.

## Caveats (must be designed for)
- **Gap / news risk:** a basket-wide equity stop can be gapped through (weekend, news spike),
  so realized loss can exceed 1% in the tail. Mitigate with the mandatory news blackout (DL-080)
  + session limits; document residual gap-tail in the EA's risk notes.
- **Whipsaw frequency:** repeated 1% stop-outs bleed capital; the strength edge must produce
  enough winning cycles. This is exactly what Q04/Q08 measure.
- **Correlation regime shift:** "hedged" legs can de-hedge in a crisis; the 1% cap is the
  backstop precisely for that.

## Build implications
- New EA primitive: a **basket/aggregate equity-stop** (account-wide floating-P&L monitor that
  flattens a tagged group of magics at −1%). Conceptually adjacent to `QM_KillSwitch` (which
  already checks ACCOUNT_EQUITY) but group-scoped to the basket, not the whole account.
- The reconstruction (`docs/research/unconventional_forex/T-WIN_STRATEGY_RECONSTRUCTION_*.md`)
  must specify the strength-ranking, basket construction, and the 1% aggregate stop precisely.
