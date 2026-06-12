# Library Mining: ICT/MMM Notes + Trading Hub 3.0
**Slug:** ict-trading-hub-notes  
**Date:** 2026-06-12  
**Miner:** Claude (claude-sonnet-4-6)

**Files:**
- `C:/Users/Administrator/Downloads/Twfx-Forex-Ict-Mmm-Notes.pdf` — 109 pages, 128,801 chars extracted
- `C:/Users/Administrator/Downloads/Trading Hub 3.0.pdf` — 36 pages, IMAGE-BASED (0 chars extractable)

**Exclusion check:**
- `Twfx-Forex-Ict-Mmm-Notes.pdf` — USABLE (line 330 in triage file, USABLE section)
- `Trading Hub 3.0.pdf` — USABLE (line 322 in triage file, USABLE section)
- EXCLUDED file is: `Unlocking Success in ICT 2022 Mentorship...by Lumitraders (Z-Library).pdf` — confirmed NOT in this batch

---

## DEDUP VERDICT — MANDATORY STEP 0

Searched `D:/QM/strategy_farm/artifacts/cards_approved/` (2,693 cards) for:
- Author keywords: `ict`, `trading-hub`
- Mechanism keywords: `killzone`, `fvg`, `fair-value-gap`, `order-block`, `sweep.*liquidity`, `mss`, `market-structure-shift`, `judas`
- Canonical family: QM5_12535–12540 (reviewed in full)

**ICT family card count:** 65 matching cards found.

### ICT Canonical Family (QM5_12535–12540) — Review
These six cards were minted 2026-06-12 from the **ICT 2022 Mentorship canonical model** and cover:
- QM5_12535: Killzone sweep + MSS + FVG retracement (indices, NY session)
- QM5_12536: OB retest variant (indices, NY session)
- QM5_12537: OTE 70.5% retracement (XAUUSD/NDX, NY session)
- QM5_12539: London KZ sweep + FVG (GBPUSD/EURUSD, London session)
- QM5_12540: AMD Judas swing (XAUUSD/GBPUSD, London open)
- QM5_1233, QM5_1234: ICT Silver/Golden Bullet systems

### What ICT/MMM Notes Contains vs. What Is Already Carded

| Concept | ICT/MMM Notes Content | Existing Card | Status |
|---|---|---|---|
| Killzone definitions (Asian 23:00–03:00, London 07:00–10:00, NY 12:00–15:00 GMT) | Yes — precise hourly windows | QM5_12535, QM5_12539 use identical windows | DUPLICATE |
| FVG (Fair Value Gap) definition | Yes — 3-candle imbalance, one-sided liquidity | QM5_12535 uses same | DUPLICATE |
| Order Block definition | Yes — last opposing candle body before displacement | QM5_12536 uses same | DUPLICATE |
| London Buy/Sell Trade (Asian-sweep + OTE) | Yes — Judas swing to support/resistance | QM5_12539, QM5_12540 | DUPLICATE |
| NY Open Trade (London-high/low continuation) | Yes — trade in direction of London move | QM5_12535 covers NY killzone | DUPLICATE |
| AMD (Accumulation–Manipulation–Distribution) | Yes | QM5_12540 | DUPLICATE |
| Market Structure (LTH/LTL/ITH/ITL/STH/STL) | Conceptual reference only — no standalone entry rules | — | NOT a standalone system |
| London Close Reversal (15:00–18:00 GMT) | YES — specific model with OTE and false-break rules | QM5_1233, QM5_1234 (Silver/Golden Bullet) partially cover NY session; **London Close specifically is NOT carded** | PARTIAL GAP |
| Liquidity Injection / Turtle Soup | YES — false breakout of Asian range before real Judas swing | QM5_12540 covers AMD/Judas; Turtle Soup is a specific 2-step pattern | VARIANT GAP |

**Trading Hub 3.0:** Image-based PDF, zero extractable text. No rules can be mined directly. Content is assumed to overlap with ICT/MMM Notes given it is a derivative ICT notes compilation. No new systems can be verified from this file.

---

## ICT FIDELITY MATRIX — MMM Notes vs. Canonical ICT 2022 Model

Cross-checking MMM Notes content against the canonical ICT 2022 model used in QM5_12535 family:

| Rule Component | Canonical ICT 2022 (QM5_12535) | MMM Notes (Reginald Mmari, 2020) | Verdict |
|---|---|---|---|
| HTF Bias | D1/H4 swing structure determines long/short direction | "Market structure" LTH/LTL hierarchy | CONSISTENT |
| Killzone filter | NY Open 12:00–15:00 GMT; London 07:00–10:00 GMT | Asian 23:00–03:00; London 07:00–10:00; London Close 15:00–18:00; NY 12:00–15:00 | CONSISTENT |
| Sweep definition | Wick exceeds prior PDH/PDL or Asia-range extreme; closes back inside | "First objective after London Open is to raid Asian High/Low stops" | CONSISTENT |
| MSS requirement | Required: MSS on M15 within 8 bars of sweep | Not explicitly required in MMM notes for all setups — some models skip MSS | **MISMATCH: MMM notes allow entry before MSS confirmation in some profiles** |
| FVG entry | Limit at FVG midpoint after MSS | OTE used as entry zone (not always FVG) — OTE is 62–79% retracement | VARIANT (OTE vs FVG) |
| Stop location | Below sweep wick | Below key support/resistance level | CONSISTENT |
| Take profit | PDH/PDL or next liquidity pool | "Take profit at 12:00" (small TP) + hold for "London Express" | **MISMATCH: MMM notes bias toward 20–30 pip scalp TP at 12:00 GMT; canonical model holds for liquidity pool** |
| London Close entry | Not a primary model in canonical 12535 | Explicit London Close/NY Reversal Profile described | **GAP in canonical cards** |

**Key finding:** MMM Notes by Reginald Mmari (2020) is an educational compilation, not the canonical 2022 source. Its entry timing sometimes precedes MSS confirmation (enters on sweep itself, before displacement bar closes), which the canonical ICT 2022 model prohibits. The TP model (fixed 20–30 pip) contradicts the canonical approach (hold to next liquidity pool). These mismatches match the "wrong realization" pattern identified in the Fidelity Initiative (MEMORY.md).

---

## NEW PROPOSALS

### Proposal 1: ICT London Close Reversal Profile (D1/H4 setup, M15 entry)

**Dedup verdict: NEW** — Specific London Close session (15:00–18:00 GMT) reversal model not carded. QM5_1233/1234 cover NY Silver/Golden Bullet windows; QM5_12539 covers London open; no card targets London Close reversal specifically.

**Mechanism (from MMM Notes page 80–82):**

The London Close Reversal Profile forms when:
1. **Asian and London sessions are directional** (e.g., London was a buy day: price made a new high).
2. **During London Close KZ (15:00–18:00 GMT):** price fails to hold its earlier session rally and begins reversing.
3. **Identification:** The reversal will often sweep through the New York session lows, London session lows, and Asian session low in sequence.
4. **HTF context:** The swing up during London session is typically the Right Shoulder of an inverted H&S top on H4, or a swing into an H4 OTE (62–79% retracement of a prior H4 down-move).

**Entry rules (M15):**
1. Assert bearish HTF bias (D1/H4 in downtrend or at structural resistance).
2. London session is bullish (price makes HH during London KZ).
3. During 15:00–17:30 GMT: price begins to reverse; look for M15 rejection at an H4 OB or H4 OTE zone.
4. Entry: SELL LIMIT at H4 OB zone upper boundary OR at 70.5% retracement of the London-open-to-high swing.
5. Stop: above the London session high + spread.
6. TP: London session low, then prior day's low.

**Symmetric long version:** London was a sell day → London Close sees reversal rally; entry ABOVE 15:00–17:30 consolidation after a sweep of London session lows.

**DWX symbols:** EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX  
**Period:** M15 execution, H4 context  
**Expected trades per year per symbol:** 25–40 (London Close session fires most trading days; reversal profile filters to ~1–2/week when HTF bias aligns)  

**R1–R4:**
| Criterion | Status | Reasoning |
|---|---|---|
| R1 Track Record | PASS | ICT/Michael J. Huddleston 2022 mentorship; MMM Notes is a named educational derivative; mechanism family validated in-house (QM5_10692 at Q12) |
| R2 Mechanical | PASS | HTF bias (D1/H4 swing structure), session-time KZ filter (15:00–17:30 GMT), OTE entry zone (fixed 70.5% retracement), stop above London high, TP at London low — all arithmetic |
| R3 Data Available | PASS | M15 DWX FX + XAUUSD on factory terminals |
| R4 No ML | PASS | Fixed retracement ratio, fixed KZ windows; no ML |

**Slug:** `ict-london-close-reversal-m15`

---

### Proposal 2: ICT Turtle Soup (Asian Range False Breakout — 2-step Judas)

**Dedup verdict: VARIANT** — QM5_12540 covers AMD/Judas single-step (London open sweeps Asian range → reverse). Turtle Soup is a **2-step** refinement: (1) initial false breakout of Asian range ("turtle soup" outside Asian range), (2) price returns inside, then makes a second and larger Judas swing to key support/resistance. This 2-step structure is mechanically distinct from QM5_12540's single-step AMD.

**Delta from QM5_12540:** QM5_12540 enters on the re-close inside Asian range (1-step). Turtle Soup adds: after the first re-close, expect a second breakout of the Asian range boundary in the same direction before the real directional move. This second breakout is the actual entry. The false-first-break confirmation eliminates many false trades by requiring TWO attempts before entry.

**Mechanism (from MMM Notes page 72):**

1. **Asian session (23:00–03:00 GMT)** establishes a range (Asian High and Asian Low).
2. **London KZ (07:00–09:00 GMT):** Price breaks OUT of Asian range briefly ("Turtle Soup" = initial fake-out).
3. Price closes back INSIDE the Asian range (this is the fake-out signal).
4. A short time later (same London KZ), price breaks THROUGH the opposite side of the Asian range — this is the real Judas swing.
5. The Judas swing then drives to the key HTF support/resistance level (HTF OB, PDH/PDL, Week Open, Day Open).
6. On the pullback to the broken Asian range boundary (or immediately if no pullback), ENTER in the direction of the Judas swing.
7. SL: beyond the Turtle Soup extreme (the fake-out wick).
8. TP: next HTF support/resistance, then PDH/PDL.

**DWX symbols:** EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX  
**Period:** M15  
**Expected trades per year per symbol:** 30–50 (London KZ fires daily; Turtle Soup pattern filters to ~2–3/week)

**R1–R4:**
| Criterion | Status | Reasoning |
|---|---|---|
| R1 Track Record | PASS | ICT/Huddleston 2022; MMM Notes named derivative; mechanism precedent QM5_10692 |
| R2 Mechanical | PASS | 2-step false-break: first close inside range, second break outside, pullback entry at range boundary — all OHLC comparisons with fixed time window |
| R3 Data Available | PASS | M15 DWX FX + XAUUSD |
| R4 No ML | PASS | Fixed windows, price comparisons; no ML |

**Slug:** `ict-turtle-soup-asian-false-break-m15`

---

## ICT/MMM FIDELITY WARNINGS

The following rule mismatches must NOT be implemented in any ICT EA:

1. **TP mismatch:** MMM Notes recommends taking a 20–30 pip fixed profit at 12:00 GMT. Canonical ICT 2022 holds to a liquidity pool (PDH/PDL, session high/low). **DO NOT use fixed pip targets.** Use structural levels (next PDH/PDL).

2. **MSS skip:** MMM Notes implies entry is valid on the sweep bar itself in some contexts ("buy when you see a fast move down to support"). Canonical ICT 2022 requires a closed MSS bar confirming displacement before entry. **REQUIRE MSS confirmation.** This is non-negotiable per the Fidelity Initiative.

3. **Classic Buy Template:** The "always buy below opening price" rule in MMM Notes (page 78) is a simplified heuristic, not a mechanical rule. The "opening price" reference is the Day Open (00:00 broker time). This alone is NOT sufficient as an entry gate. Acceptable only if combined with sweep + MSS.

---

## Summary

| Category | Count |
|---|---|
| Systems extracted | 7 (assessed from MMM Notes; Trading Hub image-based, no extraction) |
| DUPLICATE | 5 (killzone, FVG, OB, London Buy/Sell, AMD) |
| NEW proposals | 1 (London Close Reversal) |
| VARIANT proposals | 1 (Turtle Soup 2-step) |
| Fidelity warnings | 3 rule mismatches vs. canonical 2022 model |

**Recommended slugs:**
- NEW: `ict-london-close-reversal-m15`
- VARIANT: `ict-turtle-soup-asian-false-break-m15`
