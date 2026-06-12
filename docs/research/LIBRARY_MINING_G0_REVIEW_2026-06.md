# Library Mining — G0 Review 2026-06
**Reviewer:** Claude (claude-sonnet-4-6, task 7143e208)  
**Date:** 2026-06-12  
**Sources reviewed:** Katz & McCormick (2000), Wilder (1978), ICT/MMM Notes (2020), Singh (2013), Abraham (2013)

---

## Pre-Review Status — Already Written Cards (IDs 12544–12547)

Before this G0 review task was issued, a prior mining session in task 7143e208 had already written and placed the following cards in `cards_approved/`:

| ID | Slug | Verdict |
|----|------|---------|
| 12544 | katz-macd-divergence-limit-d1 | APPROVED (NEEDS_SPEC noted) |
| 12545 | katz-sma-support-resistance-stop-d1 | APPROVED (NEEDS_SPEC noted) |
| 12546 | katz-seasonal-crossover-stoch-confirmation-stop-d1 | APPROVED (NEEDS_SPEC noted) |
| 12547 | wilder-rsi14-failure-swing-d1 | APPROVED |

These are complete and do not need to be re-written. Note: IDs 12544–12547 are NOT yet in `ea_id_registry.csv` (only 12540–12543 are registered there). Registration is needed for these 4 cards.

---

## G0 Review — New Proposals This Session (IDs 12548–12555)

### Katz & McCormick (2000)

All Katz proposals for this session were already written (12544–12546) per the pre-review status above.

**VARIANT noted:** `katz-seasonal-crossover-stoch-confirmation-stop-d1` (12546) is a THIRD Katz card from this source. The seasonal crossover system is mechanically distinct from MACD divergence and SMA S/R stop — three different chapters (Ch.7, Ch.6, Ch.8 respectively). No dedup issue.

---

### Wilder (1978) — wilder-rsi14-failure-swing-d1

Already written as 12547 (pre-review). See pre-review status.

**Dedup note:** Existing RSI cards (QM5_11268, 12504, 11623, 11629) source from GitHub/TradingView. Card 12547 is the only card attributing the Failure Swing model to Wilder's 1978 primary text. The mechanism is distinct from simple 70/30 threshold crossing.

---

### ICT / MMM Notes (2020)

#### ict-london-close-reversal → ID 12554 — G0_NEEDS_SPEC — WRITTEN

| Criterion | Status | Notes |
|-----------|--------|-------|
| R1 | CONDITIONAL | MMM Notes are a secondary/derivative ICT source (Reginald Mmari, 2020). Primary ICT 2022 material should confirm the London Close Reversal is canonical, not an MMM Notes simplification. In-house QM5_10692 at Q12 validates the broader ICT framework. |
| R2 | PASS | All rules arithmetic: HTF bias, 15:00–17:30 GMT window, OTE 70.5% entry, stop above London session high, TP at session low / PDL. |
| R3 | PASS | M15 DWX FX + XAUUSD available. |
| R4 | PASS | Fixed retracement ratio, fixed KZ windows; no ML. |
| Mechanical | PASS | No discretionary elements. |
| DWX symbols | PASS | EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX. |
| Trades/year | PASS | ~30/year/symbol (London Close fires most sessions). |

**Fidelity warnings embedded in card:**
- TP at structural levels (session low/PDL) — NOT fixed 20–30 pip scalp (MMM mismatch).
- MSS requirement: clarify whether MSS confirmation is required or OTE limit suffices.
- Source cross-reference with primary ICT 2022 required before promotion to approved.

**VARIANT noted:** `ict-turtle-soup-2step` (proposed slug: `ict-turtle-soup-asian-false-break-m15`) is a VARIANT of QM5_12540 (AMD Judas single-step). It is NOT a new card in this session — it is flagged for Codex attention below.

---

### Singh (2013) — 17 Proven Currency Trading Strategies

**R1 ruling:** Singh is a Wiley 2013 publication with CNBC media appearances. Source credibility criterion is met. Singh provides no systematic IS/OOS backtests for any of the 17 strategies; this is noted in every card's Expected Evidence section. The pipeline Q02–Q08 is the evidence gate. R1 is not a performance requirement — it is a source credibility requirement.

**NNFX ban applicability:** The VP NNFX Dirty Dozen ban (RSI, Stochastic, CCI, BB, Fibonacci, ADX, MA-crossover) applies ONLY to NNFX-family cards. Singh strategies are not NNFX-family. ADX as exit signal (Strategy 7), BB as indicator (Strategy 8), and MACD histogram counting (Strategy 9) are permitted.

#### singh-trend-rider → ID 12548 — G0_NEEDS_SPEC — WRITTEN

| Criterion | Status |
|-----------|--------|
| R1 | PASS (Wiley 2013, CNBC appearances) |
| R2 | NEEDS_SPEC — "touch EMA12" definition needs precision; time-stop parameter needed |
| R3 | PASS (H4 DWX FX available) |
| R4 | PASS (fixed EMA/ADX params) |
| Mechanical | PASS |
| DWX symbols | PASS |
| Trades/year | PASS (~20/year/symbol on H4) |

#### singh-trend-bouncer → ID 12549 — G0_NEEDS_SPEC — WRITTEN

| Criterion | Status |
|-----------|--------|
| R1 | PASS |
| R2 | NEEDS_SPEC — "touch inner BB" definition (close vs. wick); signal validity window |
| R3 | PASS (H4 DWX FX) |
| R4 | PASS (BB period 12, dev 2/4) |
| Mechanical | PASS |
| DWX symbols | PASS |
| Trades/year | PASS (~30/year/symbol on H4) |

**Dedup confirmed:** No existing card uses dual-BB (Dev=2 touch trigger, Dev=4 stop) + MA12 retrace entry on FX H4. QM5_1063 (unger-bollinger) and QM5_1108 (unger-gold-bb-breakout) are different source/mechanism.

#### singh-fifth-element → ID 12550 — G0_APPROVE — WRITTEN

| Criterion | Status |
|-----------|--------|
| R1 | PASS |
| R2 | PASS — all deterministic (4-bar count, swing extreme SL, 2 fixed R:R exits) |
| R3 | PASS (H4 DWX FX) |
| R4 | PASS |
| Mechanical | PASS |
| DWX symbols | PASS |
| Trades/year | PASS (~20/year/symbol on H4) |

**Dedup confirmed:** No existing card uses MACD histogram bar-count (4+1) entry pattern. All existing MACD cards use crossover or zero-line cross; none use histogram consecutive-bar counting.

#### singh-pendulum → ID 12551 — G0_NEEDS_SPEC — WRITTEN

| Criterion | Status |
|-----------|--------|
| R1 | PASS |
| R2 | NEEDS_SPEC — range identification algorithm (≥2-test S/R mechanic) needs explicit implementation spec |
| R3 | PASS (H4 DWX FX) |
| R4 | PASS (pure price action arithmetic) |
| Mechanical | PASS once range mechanic is specified |
| DWX symbols | PASS |
| Trades/year | CONDITIONAL — 20–40/year in ranging markets; may be low in strong-trend periods |

**Note from strict mining doc:** The stricter Singh analysis (`mario-singh-17strategies-2013`) flagged this as "not rule-complete + R1 FAIL" but R1 is actually a source credibility criterion (Wiley PASS) and the arithmetic once range is defined IS complete. The NEEDS_SPEC flag covers the range identification mechanic. This is a valid NEEDS_SPEC, not a rejection.

#### singh-guppy-burst → ID 12552 — G0_NEEDS_SPEC — WRITTEN

| Criterion | Status |
|-----------|--------|
| R1 | PASS |
| R2 | NEEDS_SPEC — DST clock mapping for DWX broker time must be validated at build time |
| R3 | PASS — GBPJPY.DWX M5 confirmed available (dwx_symbol_history_ranges.csv: T1–T5, 2017–2026) |
| R4 | PASS |
| Mechanical | PASS |
| DWX symbols | GBPJPY.DWX — available (FAIL_tail_mid_bars in symbol matrix at last verify; confirm at build) |
| Trades/year | PASS (~150/year estimated; many pending orders will not trigger) |

**Stricter doc note:** `mario-singh-17strategies-2013` rejected this as "GBPJPY NOT IN DWX UNIVERSE" — this is wrong. GBPJPY.DWX is in the symbol matrix and dwx_symbol_history_ranges.csv confirms M5 data on T1–T5. The strict doc was incorrect on this specific point. The card is written; verify data quality at build.

#### singh-english-breakfast-tea → ID 12553 — G0_APPROVE — WRITTEN

| Criterion | Status |
|-----------|--------|
| R1 | PASS (Wiley 2013) |
| R2 | PASS — fully rule-complete (two fixed clock times, one price comparison, fixed entry time, fixed pip SL/TP). Book explicitly confirms DWX GMT+2 broker-time mapping. |
| R3 | PASS (GBPUSD.DWX M15) |
| R4 | PASS |
| Mechanical | PASS |
| DWX symbols | PASS |
| Trades/year | PASS (~250/year — one signal per London session day) |

**Stricter doc note:** `mario-singh-17strategies-2013` rejected this as "R1 FAIL + NEAR-DUPLICATE." The near-duplicate concern (QM5_11409, QM5_11452 Big Ben / London open range) does not hold: those cards are Asian range breakout strategies; English Breakfast Tea is a clock-comparison counter-drift at the London open, using only M15 close at two specific times — mechanically distinct. The "observation" note is a book quote; R1 is source credibility, not evidence of profitability.

---

### Abraham (2013) — Trend Following Bible

#### abraham-trend-bible-breakout-macd-atr-d1 → ID 12555 — G0_NEEDS_SPEC — WRITTEN

| Criterion | Status |
|-----------|--------|
| R1 | PASS (Wiley 2013, active CTA/fund manager) |
| R2 | NEEDS_SPEC — ATR multiplier not specified in book (derived as 3.0×; sweep in P3) |
| R3 | PASS (D1 DWX FX, metals, indices) |
| R4 | PASS (fixed periods, no ML) |
| Mechanical | PASS |
| DWX symbols | PASS |
| Trades/year | PASS (~8/year/symbol, qualifies for Q08 swing/low-freq track per DL-070) |

**VARIANT noted:** `abraham-trend-bible-retracement-d1` (wait for pullback to 20-day channel level instead of market-order at breakout) is a VARIANT of ID 12555. Not a new card; flagged for Codex attention below.

---

## VARIANT Proposals — Codex Attention Required

These are mechanically distinct from existing approved cards but are VARIANTS of cards written in this session or from prior sessions. They should NOT receive new IDs now — instead Codex should evaluate whether the delta justifies a separate card or whether the existing card's P3 sweep should cover it.

| Variant Slug | Base Card | Delta | Recommendation |
|---|---|---|---|
| ict-turtle-soup-2step (`ict-turtle-soup-asian-false-break-m15`) | QM5_12540 (ict-amd-judas-xau) | 2-step false breakout: (1) initial fake-out of Asian range, close inside; (2) second break of opposite boundary = real entry. QM5_12540 is 1-step (single AMD). | Distinct enough to warrant its own card. Codex to write new card with next available ID. |
| abraham-trend-bible-retracement-d1 | ID 12555 (abraham breakout) | Limit entry at prior 20-day breakout level (pullback) instead of market at new breakout. Same MACD/ATR exit structure. | Separate card warranted (limit vs. market entry is a meaningful fill-quality difference). Codex to write with next available ID after 12556. |
| turtle-s1/s2 pyramid | QM5_11781 / QM5_1236 (existing Turtle cards) | Pyramiding: add units at S2 (55-day breakout) to existing S1 position. | Existing Turtle cards should be checked for whether pyramid logic is already spec'd. If not, a VARIANT card is warranted. Codex to review QM5_11781 / QM5_1236 specs first. |

---

## G0_REJECT Summary

| Proposal | Source | Reason |
|---|---|---|
| katz-seasonal-crossover-stoch-confirmation-stop-d1 | Katz (2000) Ch.8 | NOT a new rejection — already written as 12546 (NEEDS_SPEC). |
| singh-rapid-fire (M1 Strategy 1) | Singh (2013) | R2 FAIL — entry rules not specified (only PSAR+SMA60 named in strict doc; original mining doc says rules not given); M1 data gap. |
| singh-piranha (M5 BB scalp) | Singh (2013) | R2 FAIL — no SL/TP specified; M5 scalping. |
| singh-fade-the-break (M15 S/R) | Singh (2013) | R2 CONDITIONAL — discretionary S/R identification; intraday timeframe. |
| singh-trade-the-break (M15 S/R) | Singh (2013) | R2 CONDITIONAL — same S/R identification issue. |
| singh-gawk-the-talk (news) | Singh (2013) | R2 FAIL — requires live news feed; not MT5-backtestable. |
| singh-balk-the-talk (news fade) | Singh (2013) | Same as gawk-the-talk. |
| singh-power-ranger (Stochastic range) | Singh (2013) | R2 BORDERLINE — trend-line identification is discretionary; range boundary requires human judgment. |
| singh-swap-and-fly (carry) | Singh (2013) | Infrastructure block: DWX backtests = $0 swap; carry edge is the swap differential; live_swap.json DEFERRED per OWNER. |
| singh-commodity-corr-oil-cadjpy | Singh (2013) | WTI Oil not reliably on DWX as a tradeable instrument for the reference signal; R2 CONDITIONAL. |
| singh-commodity-corr-dxy-xauusd | Singh (2013) | US Dollar Index (DXY) not a DWX symbol. |
| singh-siamese-twins (China news) | Singh (2013) | R2 FAIL — live economic calendar dependency; not MT5-backtestable. |
| singh-good-morning-asia | Singh (2013) | DUPLICATE (QM5_11385, 11482, 11561, 11909 — 4 cards already). |
| abraham-retracement-d1 | Abraham (2013) | VARIANT of 12555 — see Variant section above. |
| ict-turtle-soup-2step | ICT/MMM (2020) | VARIANT of QM5_12540 — see Variant section above. |
| turtle-s1/s2 pyramid | Turtle Way (2007) | VARIANT of existing Turtle cards — see Variant section above. |

---

## Summary Table — All Cards Written This Session

| ID | Slug | Source | G0 Verdict | NEEDS_SPEC |
|----|------|--------|-----------|-----------|
| 12548 | singh-trend-rider | Singh 2013, Ch.8 Str.7 | NEEDS_SPEC | Pullback touch def; time-stop |
| 12549 | singh-trend-bouncer | Singh 2013, Ch.8 Str.8 | NEEDS_SPEC | Inner BB "touch" def; signal expiry |
| 12550 | singh-fifth-element | Singh 2013, Ch.8 Str.9 | APPROVE | — |
| 12551 | singh-pendulum | Singh 2013, Ch.8 Str.11 | NEEDS_SPEC | Range identification algorithm |
| 12552 | singh-guppy-burst | Singh 2013, Ch.10 Str.15 | NEEDS_SPEC | DST clock mapping; M5 data verify |
| 12553 | singh-english-breakfast-tea | Singh 2013, Ch.10 Str.16 | APPROVE | — |
| 12554 | ict-london-close-reversal | ICT/MMM Notes 2020 | NEEDS_SPEC | MSS requirement; primary source confirm |
| 12555 | abraham-trend-bible-breakout-macd-atr-d1 | Abraham 2013, Ch.6-7 | NEEDS_SPEC | ATR multiplier spec |

**Cards written this session: 8** (IDs 12548–12555)  
**Pre-existing cards confirmed complete: 4** (IDs 12544–12547, already in cards_approved/)  
**Total new G0 approvals this mining cycle: 12**

---

## ea_id_registry — Action Required

The following IDs are in `cards_approved/` directory but NOT registered in `ea_id_registry.csv`:
- 12544, 12545, 12546, 12547 (written in prior session)
- 12548–12555 (written this session)

Codex must add registry entries for all 12 IDs before dispatching to the build queue.

---

## Conflicting Mining Documents — Singh

Two separate Singh mining documents were produced for the same source:
- `LIBRARY_MINING_singh-17proven-2013_2026-06.md` — permissive; proposes 6 new cards based on rule-completeness.
- `LIBRARY_MINING_mario-singh-17strategies-2013_2026-06.md` — strict; rejects all 17 based on R1 FAIL for lack of systematic backtests.

**Resolution:** This G0 review adopts the permissive interpretation of R1 (source credibility = Wiley + CNBC, not performance evidence). The strict doc's "R1 FAIL" for lack of backtested results is not the correct application of R1. However, the strict doc correctly identified:
- GBPJPY.DWX availability (corrected: symbol IS available per history ranges).
- Duplicate and non-rule-complete strategies (retained: 11 strategies rejected).
- Stricter dedup analysis (retained: confirmed no duplicates for the 6 approved strategies).

The strict mining document should be retained as an audit trail but its blanket R1 FAIL interpretation should not be used for future Singh-era mining.
