# QM5_12821 T-WIN — Fidelity Audit + Modular Rebuild Master Spec (2026-07-01)

OWNER-directed, **highest priority, runs separate from all processes.** OWNER challenged whether
T-WIN was built 1:1 from the videos. Claude audit answer: **NO — the current EA is a gross proxy.**
Root cause = a complex 28-pair CSM basket was squeezed into one 646-line monolithic `.mq5`, forcing
silent simplifications. Fix = rebuild as separate, unit-testable modules (OWNER's architecture call).

Roles: **Agy** closes [DESIGN] gaps from the video (visual, on-screen values transcripts miss);
**Codex** builds the modules + unit tests then recomposes the EA; **Claude** owns this spec, the
Agy↔Codex synthesis, and the fidelity review. Source of truth: `docs/research/unconventional_forex/`
(`T-WIN_STRATEGY_RECONSTRUCTION_2026-06-30.md` + batch_01..13 + transcripts).

## A. Fidelity audit — current EA (QM5_12821_twin-csm-basket.mq5) vs spec

| # | Spec mechanic (video) | Current EA | Severity |
|---|---|---|---|
| 1 | MTF coherence **D1 + W1 + MN** (decisive TFs) | `QM12821_StrengthState` uses **H1 + D1** only (L242-247); W1/MN absent; H1 (timing-only per spec) misused as decider | **CRITICAL** |
| 2 | Exhaustion gate: currency \|strength\| past **±95 norm / ±350-400 raw** | No exhaustion gate; only a `gap` (strong−weak) that is **never even tested** in the entry path (L503-522) | **CRITICAL** |
| 3 | Probability **≥6/7 of the currency's crosses agree** | **Missing entirely** | **HIGH** |
| 4 | **Pullback only, never chase** (30-min fair-price boundary) | **Missing** — opens immediately on coherence+session (L519-522) | **HIGH** |
| 5 | **7**-to-1 cluster of the single most-extreme currency; leg side by base/quote role | `strategy_cluster_size=6`; selects weak-vs-top-6 counterparts (L404-436) — not the canonical 7-cross single-currency cluster | **HIGH** |
| 6 | **No broker SL** ("don't give the broker information"); only the 1% basket equity-stop | Each leg gets an ATR SL (L387) — contradicts spec + DL-081 | **MEDIUM** |
| 7 | CSM from daily-open %-change, base-add/quote-subtract, zero-sum | `QM12821_CurrencyStrength` (L175-223) looks structurally OK — **verify** | verify |

**Verdict:** 5 of 7 core mechanics missing or wrong. This is not a 1:1 build. The gross Q02 PASSes on
the 3 per-leg legs were on a different (simplified) strategy than the videos describe.

## B. Modular architecture (the rebuild)

Each module is a standalone `framework/include/QM/*.mqh` with a **standalone MT5 test harness**
(`framework/EAs/_tests/` script: fixed inputs → asserted outputs). The EA becomes thin: compose the
modules. This forces every mechanic to exist and be verified, and makes the CSM/basket primitives
reusable (unblocks the #20 dormant-basket sweep).

### Module 1 — `QM_CurrencyStrength.mqh` (the hard core) [SPEC]
- `Perf(pair) = (Price_now − DailyOpen_brokerMidnight) / DailyOpen × 100`.
- `Strength(C) = Σ Perf(crosses where C is BASE) − Σ Perf(crosses where C is QUOTE)` over the 8 majors.
  Zero-sum. Parametrized on TF (so D1/W1/MN callable).
- **Exhaustion normalization to ±100** + `IsExhausted(C, thr)`.
- **Probability ratio**: fraction of C's 7 crosses agreeing with its strength sign; `Prob(C) ≥ k/7`.
- **Agy gaps:** exact exhaustion threshold (panel shows raw −1600/+700; what maps to "exhausted"?
  is it ±95 normalized, ±350-400 raw, or a rank?); how the ±100 normalization is derived.
- **Codex tests:** hand-computed Perf/Strength on a fixed 28-price vector; zero-sum assertion;
  probability ratio on a known configuration.

### Module 2 — `QM_MTFCoherence.mqh` [SPEC]
- Strength sign for the selected currency must agree on **D1 AND W1 AND MN** simultaneously.
- **Agy gaps:** does Giavon require all three, or D1 primary with W1/MN as confirm? Any 9-TF panel
  role? (spec says decision = D/W/M, lower TFs time entry only.)
- **Codex tests:** synthetic per-TF strength arrays → coherent vs contradictory cases.

### Module 3 — `QM_PullbackGate.mqh` [SPEC gate, DESIGN thresholds]
- Enter only on a retracement at the **30-min fair-price oversold/overbought boundary** — never chase
  an already-extended move.
- **Agy gaps:** what exactly is the "fair-price boundary" on screen (a band? MA? % from daily open?);
  how Giavon decides "already moved → skip".
- **Codex tests:** price paths that are extended (reject) vs pulled-back (accept).

### Module 4 — `QM_BasketBuilder.mqh` [SPEC]
- **Mode C (primary):** the single most-extreme currency → open **all 7 of its crosses**, side per the
  currency's base/quote role (strong→buy where base, sell where quote; weak→invert).
- **Mode B:** 4-pair net-zero square (secondary).
- **Agy gaps:** confirm 7 legs (not 6/8); confirm the EUR/GBP-type inversion legs; the exact leg-side
  table for a worked example (GBP-strong shown in video).
- **Codex tests:** GBP-strong → exact 7 (symbol, side) set matches the video's worked example.

### Module 5 — `QM_BasketEquityStop.mqh` [V5 binding, DL-081]
- Magic-group floating-P&L monitor; flatten ALL legs at **−1% of account equity**. Reusable primitive.
- **No agy gap** (this is our DL-081 control, not from the video). **No broker-side per-leg SL.**
- **Codex tests:** simulated floating P&L crossing −1% → all-flat; +TP% → all-flat.

## C. Execution order
1. **Now (Claude):** this spec. **Agy task #28** + **Codex task #29** enqueued.
2. **Parallel:** Codex builds the clear-spec modules immediately (1 CSM core formula, 4 basket-builder,
   5 equity-stop); Agy verifies the [DESIGN] gaps (exhaustion thr, pullback, MTF combination, leg count).
3. **After Agy verdicts:** Codex finalizes the design-dependent gates (exhaustion threshold, pullback,
   MTF rule) + recomposes the thin EA composing all 5 modules.
4. **Claude review:** module tests green + EA fidelity re-checked line-by-line vs this table, then
   re-enqueue the logical-basket Q02 (already wired, FX8_TWIN_CSM_BASKET_H1) → Q04 net-of-cost = judge.

## D. Non-negotiables (no shortcuts — OWNER)
Every row in table A must be implemented and unit-tested. RISK_FIXED backtest / RISK_PERCENT live;
mandatory news-blackout; no ML; deterministic; no invented commission/swap. The multi-symbol
serialization for 12821 is in place (registry + payload markers; ≤1 basket active farm-wide).
