# T-WIN / U.F.O. Basket Strategy — Reconstruction & V5 Build Spec

**Date:** 2026-06-30
**Source:** YouTube channel `UnconventionalForexTrading` (Dr. Marco Giavon / "MT Algo
Solutions"), 50 videos. Reverse-engineered by the Antigravity agent-army (7/13 batches
landed before agy hit a rate-wall: batch_01/03/06/07/08/09/11, ~28 videos incl. the core
mechanics + the mature T-WIN webinars). Synthesis by Claude over the batch analyses.
**Policy:** built under [[decisions/DL-081]] (bounded-risk grid/basket, 1% account cap).

---

## 1. What it is (the edge)

**"Trade What Is Not" (T-WIN)** — a **currency-strength divergence basket**. It ignores
single-pair charts and instead ranks the **8 major currencies** (USD, EUR, GBP, JPY, CHF,
AUD, CAD, NZD) by absolute strength, then trades the **strongest against the weakest** as a
multi-pair basket. The edge is **relative-strength momentum/divergence** captured at the
**London open**, smoothed by spreading exposure across many correlated legs.

### The Currency Strength Meter (CSM) — the engine (deterministic, codeable)
- For each of the 28 major pairs, intraday performance from the **daily open (broker
  midnight)**: `Perf(pair) = (Price_now − Price_open) / Price_open × 100`.
- Each currency's strength = sum of its performance across the 7 pairs it appears in,
  **signed +1 when it is the base, −1 when it is the quote**:
  `Strength(C) = Σ_base Perf(C/x) − Σ_quote Perf(y/C)`.
- The 28 changes are **zero-sum** (`Σ ≈ 0`), so the matrix self-normalizes: one currency is
  the extreme winner, one the extreme loser.
- Multi-timeframe coherence: the same ranking must hold on H1 + Daily before acting.
- (Giavon ran this in Excel via DDE/RTD off an MT4 feed EA, refreshing every 2–3 min. For us
  it is just an indicator computed on closed bars — no Excel, no DDE.)

## 2. Basket construction (two modes seen)
- **Mode A — single-currency cluster (dominant / cleanest):** trade ONE extreme currency
  against the rest. E.g. JPY weakest → LONG all JPY crosses (GBPJPY, EURJPY, AUDJPY, NZDJPY,
  CADJPY, USDJPY) = 6–7 legs; NZD strongest → buy NZD vs all. Individual-leg retracements are
  offset by the cluster → smoother basket equity.
- **Mode B — synthetic 4-pair pair-trade:** replicate a target cross (e.g. SELL AUD/JPY) with
  4 legs whose intermediates (EUR, USD) net to zero → synthetic 2× exposure, spreading
  correlation risk. (Elegant but more complex; Mode A is the workhorse.)
- "Double size" qualifier when both legs of a cross sit at the strength/weakness extremes.

## 3. Entry / exit (native)
- **Session:** London open **06:30–08:30 broker time**, and the London–NY overlap
  **09:30–10:00**. Intraday only (≈95%); **no overnight, no weekend hold** (keeps swap ≈ 0).
- **Entry:** extreme strength/weakness gap in the CSM + multi-TF coherence → wait for a
  pullback/consolidation on M1/M5/M15 → inject the basket as pending orders at S/R.
- **Exit:** (a) basket-wide **combined profit target** (close all legs as a group); OR
  (b) **strength-ranking shift** — if the CSM extreme currency changes, flatten immediately
  regardless of per-leg P&L; (c) time-stop before US session close; (d) Friday pre-close flat.
- **Skip filter:** don't trade when a major session is on holiday (frozen correlations).

## 4. Native money-management = the V5-forbidden part (now exception-allowed)
The native system has **no per-trade hard SL**; instead a **global soft SL of 2–3%** and a
**grid "enforcement" scale-in**: when a leg retraces, add larger positions at S/R
(martingale lot-multipliers) to drag the basket break-even toward price for a quick exit.
Under [[decisions/DL-081]] this is **now permitted** — but re-bounded (see §5).

---

## 5. V5-compliant rebuild (DL-081 bounded version) — THE BUILD SPEC

Keep the CSM edge + the cluster basket + the grid/martingale scale-in, but replace the
"soft 2–3% global SL" with a **hard 1%-of-account basket equity-stop** as the single,
binding risk control.

**Signal engine (deterministic, closed-bar):**
1. Compute `Strength(C)` for all 8 majors from the daily-open % change (above), each new bar.
2. Require an extreme gap: `max(Strength) − min(Strength) ≥ G` (tunable) AND the same
   strongest/weakest currency on H1 **and** D1 (coherence).
3. Identify the target currency (weakest → short its crosses; strongest → long its crosses).

**Basket open (Mode A):**
4. Only inside the London / overlap session windows; skip on configured holidays + news
   blackout ([[decisions/DL-080]]).
5. Open the cluster legs (the 5–7 crosses of the target currency) at the aligned direction.
6. **Grid + martingale scale-in ALLOWED** (DL-081): on retrace, add "enforcement" legs at
   stepped S/R levels with a lot-multiplier. The schedule is free.

**Risk control (the binding invariant):**
7. **Basket equity-stop:** monitor the **aggregate floating P&L of the magic-group** every
   tick; when it hits **−1% of ACCOUNT_EQUITY**, **flatten ALL legs** and stop adding.
   → max loss per cycle = 1% (ex-gap). This is the new EA primitive.
8. **Basket take-profit:** flatten all at a combined `+T%` (T uncapped vs the 1% downside →
   the asymmetry). Plus the **strength-shift exit** (recompute CSM; flip → flatten).
9. Intraday time-stop + Friday flat. No position survives the news blackout window.

**Framework implications (important):**
- This is a **basket EA** → it breaks the single-position-per-magic convention. Use the
  reference single-host basket pattern (QM5_10717) + a magic-group allocation for the legs.
- New primitive **`QM_BasketEquityStop`** (group-scoped floating-P&L flatten-all) — adjacent
  to `QM_KillSwitch` (which already reads ACCOUNT_EQUITY) but scoped to the basket's magics.
- `RISK_FIXED` for backtest / `RISK_PERCENT` for live; the 1% cap sits on top of leg sizing.

## 6. ⚠️ The #1 viability risk — FX-basket commission
T-WIN is **FX-only** (the 8 majors) and opens **6–14 legs per cycle, intraday, possibly
several cycles/day**. Forex commission is **~$45 round-trip per standard lot** (HIGH;
[[reference_commission_by_asset_class_2026-06-26]]). A single cluster cycle = 6–14 legs ×
commission + spread on every leg. **This is a brutal cost load** — the gross edge per cycle
must clear 6–14× the per-trade cost. Q04 (net-of-cost walk-forward) is exactly where this
will be decided, and it is the most likely killer (more than the grid). Mitigations to test:
fewer/larger legs, higher gap threshold G (fewer, higher-conviction cycles), and only the
highest-strength clusters.

## 7. Edge-plausibility verdict
- **Plausible core:** currency-strength relative-momentum at the London open is a real,
  documented intraday phenomenon; the cluster smooths variance. The CSM is fully mechanical.
- **Real risks (ranked):** (1) FX-basket commission, (2) grid/martingale whipsaw frequency
  hitting the 1% stop, (3) gap-through-stop tail (mitigated by intraday/no-weekend/news).
- **Bottom line:** worth building as a DL-081 bounded basket EA and running the full pipeline.
  The 1% cap makes it SAFE; Q02→Q04(net-of-cost)→Q08 decide if it is PROFITABLE. Do not
  assume the YouTube "+428%" demo numbers (1.0 flat lot, no commission, no slippage).

## 8. Coverage gap
6 batches (videos 5–8, 13–20, 37–40, 45–50 — incl. the final monthly-report videos) were not
analyzed (agy rate-wall). The core mechanics are covered; re-run `antigravity_channel_harvest.py
--synth-only` style on the missing IDs when agy quota resets to confirm late refinements.

## Next step
Draft a Strategy Card (basket EA, DL-081 bounded, CSM cluster) → build via the basket-EA
pattern → Q02. Source per modified R1 = the channel itself (no author pedigree needed).
