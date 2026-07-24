# STR-021 — Reconciliation (Claude spec ↔ Codex spec)

## Consensus
Weekly-open level primacy; M15 closed-bar state machine; OB candle geometry
(bearish candle below level for longs, mirror), close-beyond-extreme
confirmation, limit at OB edge, SL beyond opposite extreme; 2R as the only
self-contained exit; no market chase on missed retrace; metals transfer risk +
episodic frequency documented; framework overlay (news, Friday-close).

## Divergences → decisions

1. **Final rule hierarchy (p.25).** Codex surfaced the author's final evolution:
   "only enter after liquidity has been taken out and an order block has formed
   afterward. Volumes serve only as confirmation." Claude had extreme-volume as a
   HARD OB qualifier. → **Codex wins (source-final):** sequence = sweep → OB
   (formed AFTER the sweep) → confirmation close → limit. Volume becomes an
   OPTIONAL confirmation input, **default OFF** (author himself rejects FX/CFD
   tick volume; metals have no source-approved feed).
2. **Liquidity-sweep definition** (unstated in source; both flagged): →
   deterministic minimal reading anchored in the thread's level framework:
   sell-side sweep (long case) = an M15 bar that trades below the weekly open AND
   below the **previous day's low** (the nearest canonical sell-side pool in the
   author's MOP/WOP/DOP level system). Mirror for buy-side. Recorded as
   reconciliation definition.
3. **OB selection:** most recent qualifying opposing candle formed after the
   sweep, entirely beyond the weekly open (long: High < weekly_open, Close<Open);
   newer qualifying candles replace older ones until confirmation. ("First vs
   most recent" unstated; most-recent = nearest liquidity, consistent with the
   author's worked entries.)
4. **Exit mode:** fixed 2R from ACTUAL fill (codex's R-from-fill precision
   adopted). Other three source options documented, not built.
5. **Pending management** (unstated): expiry at week end; invalidation cancel if
   an M15 close breaches the OB's far extreme before fill (long: close < OB.low);
   one pending OR one position per symbol; opposite setups ignored while
   pending/position exists. (Restrictive composite of both specs.)
6. **SL buffer:** none stated → SL = OB extreme ∓ 1 tick ("below the low"
   minimal reading; no pip buffer invented). Stops-level too tight → SKIP setup
   and log (geometry is the trade; no widening). [both restrictive]
7. **Week/day boundary:** author "clock set to UTC"; our platform = broker time
   (NY-close GMT+2/+3). → use BROKER W1/D1 bars (deterministic, data-native);
   UTC-offset fidelity noted in card (constant 2-3h shift of level anchors).
8. **Weekly-open break semantics:** wick sufficient for the SWEEP leg (codex:
   "a wick may perform the sweep"), but OB qualification and confirmation use
   closes. Break-below-level = `Low < weekly_open` intra-week precondition
   folded into the sweep condition (#2).
9. **Symbols:** XAUUSD.DWX + XAGUSD.DWX (Claude) — codex neutral ("metals").
   Kept; XTIUSD deferred (venue costs/session differ).

## Frequency
8–25 filled/yr/symbol (codex, fill-adjusted) — above floor but the thinnest of
the three; flagged for Q02 watch.

---

## Amendment 2026-07-24 (post-smoke defect fix, evidence-driven)

First valid smoke (T5, XAUUSD.DWX M15 2024, `D:\QM\reports\smoke\QM5_20098\20260724_123426\`)
PASSed with 516 trades but exposed a management defect: when the market trades
through the 2R target before the deferred TP can be attached (limit fill at the
OB retest with immediate continuation), the TP-modify sits on the wrong side of
the price and is rejected (`10016 Invalid stops`) — the hook then retried every
tick (**653,089 rejected modify requests** vs 515 successful TP attaches).

Fix (within the spec's stated intent "TP computed at ACTUAL fill"):
1. **Attained-target close:** if bid/ask is already at/beyond the 2R target at
   management time, the exit condition is fulfilled → close at market, log
   `STRATEGY_EXIT reason=rr_target_attained_pre_tp`. Source-faithful: the trade
   achieved its 2R objective.
2. **Retry pacing:** a rejected TP modify is retried at most once per M15 bar
   (global wait-bar latch), bounding worst-case request/log volume.

No entry, sweep, OB, invalidation, or risk logic touched. Tie-break rule 2/3
(more restrictive / conservative-testable) applied; codex review requested as
build-closure ACK.

Also recorded: realized fill frequency 516/yr on XAUUSD vs the 8–25/yr spec
estimate — the per-side state machine re-arms after each completed trade within
the same week (mechanically allowed by the final spec; economics judged by
Q02+, not the build gate).
