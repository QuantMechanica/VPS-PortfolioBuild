# Library Mining: Reginald Mmari — ICT & MMM Notes (January 2020)

**Date:** 2026-06-12
**Miner:** Claude (library-mining task 7143e208)
**Source file:** ICT & MMM Forex Notes by Reginald Mmari (compilation of ICT teachings)
**Text cache:** `D:/QM/strategy_farm/source_cache/ict-twfx-mmm-notes.txt`
**Extraction quality:** GOOD — 3178 lines, full ToC visible, body content present.
**Note:** This is a third-party compilation of Michael J. Huddleston ("ICT") teachings, not a book by ICT himself. Concepts are attributed to ICT but filtered through the compiler. Cross-reference with the ICT fidelity spec from VARIANT_REALIZATION_SURVEY_2026-06.md before carding.

---

## STEP 0 — DEDUP STATUS

Existing ICT cards in pool (21 found):
```
QM5_10095  gh-ict-orderblk
QM5_10664  tv-ict-ny-fvg
QM5_10688  tv-ict-sess-v3
QM5_10694  tv-ict-silver
QM5_10712  tv-ict-retest
QM5_10744  tv-ict-ote         ← OTE covered
QM5_10834  tv-nq-ict-ob
QM5_1233   ict-silver-bullet  ← Silver Bullet covered
QM5_1234   ict-golden-bullet  ← Golden Bullet covered
QM5_12535  ict-killzone-sweep-idx  ← killzone+sweep concept
QM5_12536  ict-ob-retest-idx  ← OB retest covered
QM5_12537  ict-ote-displacement-xau  ← OTE covered for XAU
```

**ICT Fidelity Requirement (from VARIANT_REALIZATION_SURVEY_2026-06.md):**
All ICT-family cards MUST comply with:
1. HTF bias established first (monthly/weekly/daily)
2. MSS (Market Structure Shift) as entry trigger
3. Killzone timing enforced (see below for exact times)
4. FVG retracement entry within the gap
5. OTE range: 62%-79% Fibonacci retracement

---

## MMM Notes — Table of Contents (Strategy-Relevant Sections)

| Section | Page | Assessment |
|---|---|---|
| Price Foundation / Swing Points | 7 | Framework — no new card |
| Market Structure Concept | 8 | Framework — covered by existing cards |
| SMT Divergence (USDX, Correlated, Index) | 23-27 | **NEW — see below** |
| Order Blocks (Bullish/Bearish) | 28 | DUPLICATE (QM5_10095, QM5_10834, QM5_12536) |
| Breaker Block | 41 | **NEAR-NEW — see below** |
| Power of Three + Judas Swing | 42-43 | **NEAR-NEW — see below** |
| ICT Kill Zones | 44 | Already in fidelity spec |
| ICT Buy and Sell Model | 47 | Framework — no standalone card |
| Session Trading (London Open, NY Open) | 66-77 | Covered by session cards |
| ICT Intraday Price Templates | 78 | Framework |
| Judas Swing | 93 | **NEW — see below** |
| OTE (62%–79% Fibonacci) | 103 | DUPLICATE (QM5_10744, QM5_12537) |

---

## Kill Zone Times (Canonical — from this source)

| Session | GMT start | GMT end |
|---|---|---|
| Asian Kill Zone | 23:00 | 03:00 |
| London Open Kill Zone | 07:00 | 10:00 |
| London Close Kill Zone | 15:00 | 18:00 |
| New York Open Kill Zone | 12:00 | 15:00 |

These are the canonical GMT kill zone windows. All ICT-family cards must filter to trades initiated within these windows.

---

## New / Near-New Concepts Assessed

### Concept 1: Judas Swing (p. 93)

**DUPLICATE — already carded.**

**QM5_12540 (AMD Judas swing, XAUUSD/GBPUSD, London open)** covers the AMD/Judas Swing pattern directly. Additionally, `LIBRARY_MINING_ict-trading-hub-notes_2026-06.md` (a more comprehensive prior-session doc covering 65 ICT cards from the same source PDF) confirmed this and proposed a 2-step **Turtle Soup** variant (`ict-turtle-soup-asian-false-break-m15`) that extends the Judas concept.

The Turtle Soup VARIANT (2-step false break per `ict-trading-hub-notes` doc) is the only gap: QM5_12540 is 1-step; Turtle Soup requires 2 breakout attempts before entry. See `LIBRARY_MINING_ict-trading-hub-notes_2026-06.md` for full spec.

**Verdict: DUPLICATE (QM5_12540); see Turtle Soup VARIANT in prior doc.**

---

### Concept 2: Breaker Block (p. 41)

**Description (from MMM notes):**
- The order block (OB) prior to the Judas swing / false move
- Bullish Breaker Block: most recent swing high BEFORE an old low is violated. When price returns to that swing high zone, it's a long setup.
- Bearish Breaker Block: most recent swing low BEFORE an old high is violated. When price returns, it's a short setup.
- Distinct from standard OB: the "breaker" OB has already been confirmed by the subsequent false move

**DEDUP CHECK:** Breaker Block is NOT named in any existing ICT card. Standard OB cards (QM5_10095, QM5_12536) use the OB concept but not the breaker-specific rule (prior OB before false move → confirmed when false move resolves).

**Verdict: NEEDS_SPEC** — the Breaker Block concept is rule-complete enough for a NEEDS_SPEC card. The distinguishing rule: "OB is a breaker if the swing that formed it was later violated by a false move; entry is on price return to that OB zone after the false move resolves."

---

### Concept 3: SMT Divergence — Correlated Pair (p. 23-25)

**Description (from MMM notes):**
- When two correlated FX pairs (EURUSD + GBPUSD) should move together but one fails to confirm the other's new extreme
- Bullish SMT: GBPUSD makes lower low but EURUSD fails to confirm → long signal on EURUSD (or GBPUSD)
- Bearish SMT: one pair makes higher high, other fails to confirm → short signal
- Also applicable between USDX and FX pairs (inverse correlation) and between stock indices

**MT5 mechanizability:** Requires reading two symbol prices simultaneously. MT5 allows iHigh/iLow on a different symbol in the same EA. Technically feasible but adds complexity.

**DEDUP CHECK:** No existing card covers SMT Divergence by name or concept.

**Verdict: NEEDS_SPEC (COMPLEX)** — SMT divergence is a distinct concept with no existing card. However, the two-symbol dependency makes it architecturally complex. The signal rule is: "compare N-bar high/low between EURUSD and GBPUSD; if one makes new extreme while other doesn't, trade in direction of the failing pair." Entry would still use OTE.

---

### Concept 4: Weekly High/Low Timing Rule (p. 104-105)

**Description (from MMM notes):**
- Weekly High or Low forms 80% of the time before Tuesday's London Open
- If not, likely between Tuesday and Wednesday London Open

**Assessment:** This is a timing observation, not a standalone strategy. It could augment a weekly-range breakout card but is not standalone. No new card warranted.

---

## Summary Table

| Concept | Source Pages | Dedup Status | Verdict | Action |
|---|---|---|---|---|
| Judas Swing | p. 42-43, 93 | QM5_12535 proximity — check | NEEDS_SPEC | Draft card: ict-judas-swing-killzone |
| Breaker Block | p. 41 | No existing card | NEEDS_SPEC | Draft card: ict-breaker-block |
| SMT Divergence (correlated pair) | p. 23-25 | No existing card | NEEDS_SPEC (complex) | Draft card: ict-smt-divergence-fx |
| Weekly H/L timing | p. 104-105 | Not standalone | INFORMATIONAL | Add to existing session cards |
| Order Block | p. 28 | DUPLICATE (QM5_10095/12536) | SKIP | — |
| OTE (62-79%) | p. 103 | DUPLICATE (QM5_10744/12537) | SKIP | — |
| Kill Zone times | p. 44 | Fidelity spec documented | SKIP | Confirm in existing cards |
| ICT Buy/Sell Model | p. 47 | Framework, not standalone | SKIP | — |

**Net new NEEDS_SPEC proposals: 3**

---

## Key Findings for OWNER

1. **Three new concepts emerge** beyond what's already in the pool: Judas Swing (session-open false move), Breaker Block (prior OB confirmed by false move), and SMT Divergence (correlated-pair confirmation failure).

2. **Fidelity audit required for all new cards.** All three proposals must comply with the full ICT fidelity spec (HTF bias + MSS + kill zone + OTE entry). See `docs/research/VARIANT_REALIZATION_SURVEY_2026-06.md`.

3. **SMT Divergence requires two symbols.** This is architecturally more complex than single-symbol EAs. Suggest building it as a research study first (compute SMT signal on historical data) before committing to an EA.

4. **Kill zone times are now canonical from this source.** All ICT-family cards should use: Asian 23:00-03:00, London Open 07:00-10:00, London Close 15:00-18:00, NY Open 12:00-15:00 (all GMT).

5. **The ICT MMM notes are a secondary source** (third-party compilation). Any card built from this should be cross-referenced with primary ICT YouTube course material before final approval.

---

## Evidence file

| File | Description |
|---|---|
| `D:/QM/strategy_farm/source_cache/ict-twfx-mmm-notes.txt` | Full text extract (3178 lines) |
| `C:/QM/repo/docs/research/VARIANT_REALIZATION_SURVEY_2026-06.md` | ICT fidelity specification |
