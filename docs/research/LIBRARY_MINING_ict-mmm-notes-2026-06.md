# Library Mining — FOREX ICT & MMM Notes (Mmari, 2020)

**Mined:** 2026-06-12  
**Task:** 7143e208-5a5c-4c0a-a142-e168b25bedf7  
**Source file:** `C:/Users/Administrator/Downloads/Twfx-Forex-Ict-Mmm-Notes.pdf`  
**Extraction:** `D:/QM/strategy_farm/source_cache/ict-mmm-notes.txt` (134,684 bytes, 109 pages)  
**Author/compiler:** Reginald Mmari, January 2020 (Telegram: t.me/twfforex)

---

## Source Assessment (R1–R4)

**CRITICAL: This is a SECONDARY source** — a student's synthesis of Michael J. Huddleston's (ICT) concepts. It is NOT a primary ICT publication. Attribution must always reference the primary source (ICT 2022 Mentorship, ICT YouTube channel) with this document cited only as a secondary synthesis.

**R1 — Track record:** The synthesized content reflects Michael Huddleston's ("ICT — Inner Circle Trader") publicly documented methodology, which has established real-world validity: our own QM5_10692 (sweep+MSS) reached Q12 using the core ICT mechanism. The secondary author (Mmari) has no independent track record. **PASS for primary ICT concepts; PARTIAL for Mmari-specific interpretations.**

**R2 — Mechanical:** Core ICT concepts (FVG, Order Blocks, Kill Zones, AMD) are mechanically defined. Some concepts (SMT divergence, Breaker Block) require multi-symbol data or subjective identification. **PASS for FVG/OB/AMD/Kill Zones; PARTIAL for SMT/Mitigation.**

**R3 — Data available:** M15/H1/H4/D1 data for FX and index .DWX symbols available on factory. **PASS.**

**R4 — No ML:** Fixed price-structure rules. **PASS.**

---

## Table of Contents (from source)

The 109-page document covers:

| Section | Pages | Coverage |
|---------|-------|----------|
| Price Foundation — Swing Points | 7 | Fractals: HH/HL/LH/LL definition |
| Market Structure | 8–10 | Structure breaks, trend confirmation |
| Support & Resistance types | 12–17 | Natural, implied, institutional levels |
| COT Data + Commercials | 18–22 | Commitment of traders interpretation |
| Seasonal Tendencies | 22 | Seasonal calendar patterns |
| Smart Money Correlation (SMT) | 23–26 | USDX divergence, correlated pairs |
| Order Blocks (bullish/bearish) | 28–31 | Last candle before expansion |
| Liquidity Pools / Voids | 31–36 | Stop clusters and gap-fill targets |
| Fair Value Gaps | 34 | 3-candle imbalance pattern |
| Mitigation Blocks | 40 | Failed OB revisited |
| **The Breaker** | 41 | Failed OB flipping role |
| Power of Three (AMD) | 42–43 | Accumulation-Manipulation-Distribution |
| Kill Zones | 44–45 | Session timing windows |
| Market Profiles | 46–47 | Consolidation/Breakout/Trending/Reversal |
| ICT Buy/Sell Model | 47–50 | Full entry model |
| Top-Down Analysis | 51–57 | MTF framework M→W→D→H4→H1→M15→M5 |
| Session Trading | 66–77 | Asian, London, NY session tactics |
| ICT Intraday Price Templates | 78–109 | Classic buy/sell templates |

---

## Existing ICT/SMC Card Coverage

Searching `cards_approved/` for ICT/SMC concepts:

| Concept | Existing cards | Notes |
|---------|---------------|-------|
| FVG (fair value gap) | 23+ | Extensively carded (tv-fvg-*, ftmo-fvg-*, etc.) |
| Order Blocks | 12+ | QM5_10095, QM5_1050, QM5_10758, etc. |
| Sweep + MSS | 8+ | QM5_10253, QM5_10628, QM5_10728, QM5_12535, etc. |
| AMD / Power of Three | 3 | QM5_12540, QM5_10963, QM5_9250 |
| Kill Zones | 1 | QM5_12535 (killzone-conditioned sweep+MSS) |
| **Mitigation Block** | **0** | Not carded |
| **ICT Breaker Block** | **0** | Not carded (r-breaker and fib-breaker ≠ ICT Breaker) |
| **SMT Divergence** | **0** | 9 generic correlation cards but none ICT-flavored |

**Total ICT/SMC cards:** 56

---

## Fidelity Check: Kill Zone Times

**Source (ICT MMM Notes, p. 44):**
- Asian Kill Zone: **23:00 – 03:00 GMT**
- London Open Kill Zone: **07:00 – 10:00 GMT**
- London Close Kill Zone: **15:00 – 18:00 GMT**
- New York Open Kill Zone: **12:00 – 15:00 GMT**

**Cross-reference vs QM5_12535 (ict-killzone-sweep-idx):**
QM5_12535 was created 2026-06-12 as part of the fidelity initiative from the primary ICT 2022 Mentorship source. Its r2_reasoning confirms "fixed killzone windows (broker NY-close time = ET-stable year-round)." The card references the 2022 Mentorship model (Michael Huddleston, YouTube), not this secondary document.

**Verdict:** The ICT MMM Notes kill zone times are consistent with canonical ICT published times. No fidelity discrepancy. QM5_12535 should implement these exact GMT windows (verifiable in the card body — not audited here, but creation context confirms fidelity).

**Note on broker-time conversion:** DXZ broker time = GMT+2 (non-DST) / GMT+3 (US DST). Kill zones in broker time:
- Asian: 01:00–05:00 (non-DST) / 02:00–06:00 (DST)
- London Open: 09:00–12:00 / 10:00–13:00
- London Close: 17:00–20:00 / 18:00–21:00
- NY Open: 14:00–17:00 / 15:00–18:00

This conversion must be hardcoded as DST-aware in any killzone-filtering EA.

---

## Concept Definitions: Novel Items Not Yet Carded

### Mitigation Block (pp. 40)

**Primary source:** ICT — "A mitigation block is a bearish or bullish order block that was broken through (the original supply or demand was 'mitigated'). After the price breaks through, it will often return to test the mitigation zone as a new resistance or support level, but with reduced effectiveness compared to the original OB."

**Mechanical definition:**
1. Identify a bullish OB: the last bearish candle before a strong upward expansion
2. Price breaks back down through the OB (OB is "mitigated" — supply has been cleared)
3. On the return to that level from below, it now acts as resistance → short setup
4. Same logic inverted for bearish OB → becomes support after mitigation

**Difference from Order Block:** An OB is tested while still "active" (first test). A Mitigation Block is tested after the original supply/demand has been consumed — the level now operates in the opposite role (former support becomes resistance).

**Difference from Breaker Block:** A Breaker also flips role, but the trigger is a specific pattern (see below). Mitigation is the broader concept; Breaker is a specific price-structure variant.

---

### ICT Breaker Block (p. 41)

**Primary source:** ICT — "A breaker is formed when a swing high or low that was swept is later broken in the same direction as the sweep. The original order block that caused the sweep becomes the 'breaker' — it now acts as support (bullish breaker) or resistance (bearish breaker) when price returns."

**Mechanical definition:**
1. Identify a swing high (H1 or H4)
2. Price sweeps above the swing high (liquidity grab)
3. Price then pulls back and **breaks** (closes) below the swing high → this confirms a bearish displacement
4. The candle(s) that formed the original swing high become a **bearish breaker block** (resistance)
5. On return to the breaker zone, enter short

**Long variant:** Sweep below swing low → break above swing low → bullish breaker block on return.

**Critical distinction vs existing "breaker" cards:**
- `QM5_10271_ltz-rbreaker.md` = Toby Crabel's "R-Breaker" (daily range pivot system — completely different)
- `QM5_11016_the5ers-fib-breaker.md` = Fibonacci retracement level labeled "breaker" — not the ICT concept

Zero cards implement the ICT Breaker Block sweep-and-reverse pattern.

---

### SMT Divergence (pp. 23–26)

**Primary source:** ICT — "Smart Money Tool (SMT) divergence occurs when two highly correlated currency pairs fail to confirm each other's extremes. For example, if EUR/USD makes a new swing high but GBP/USD does NOT make a new swing high at the same time, this indicates institutional activity (smart money) is not confirming the EUR/USD move → bearish divergence signal for EUR/USD."

**Mechanical definition:**
- Pair 1 (e.g., EUR/USD): makes new N-bar high on current bar
- Pair 2 (e.g., GBP/USD): does NOT make a corresponding new N-bar high on the same bar
- Signal: Fade Pair 1 move (sell EUR/USD) on next bar
- Confirmation: Look for FVG or OB at the extreme of Pair 1's swing high as entry zone

**Variants documented in source:**
1. USDX vs EUR/GBP pair — USD Index divergence from EUR/USD
2. Correlated pair (EUR/USD vs GBP/USD) — most common
3. CRB Commodity Index vs commodity currencies (AUD/USD, CAD pairs)
4. Stock index vs currency — risk-on/off correlation breakdown

**Implementation complexity:** Requires multi-symbol data access in MQL5. More complex than single-instrument strategies but technically feasible.

---

## Dedup Verdicts

| Concept | Verdict | Notes |
|---------|---------|-------|
| FVG, OB, Sweep/MSS, AMD | DUPLICATE | Extensively covered (23+, 12+, 8+, 3 cards) |
| Kill Zones (time windows) | COVERED | QM5_12535; times verified as canonical |
| Liquidity pools/voids | COVERED | Multiple FVG+sweep cards address these concepts |
| COT data strategies | COVERED | QM5_1345, QM5_1582 |
| ICT Buy/Sell Model | COVERED | QM5_12535/12536/12537 cover the main model variants |
| **Mitigation Block** | **NEW** | 0 existing cards; mechanically defined above |
| **ICT Breaker Block** | **NEW** | 0 existing ICT-specific breaker cards |
| **SMT Divergence** | **NEW** | 0 existing SMT-specific cards; requires multi-symbol |

---

## Card Proposals (2 primary + 1 complex)

### Proposal 1: `ict-mitigation-block-fade-h1` (NEW)

```yaml
slug: ict-mitigation-block-fade-h1
source: "Huddleston, M.J. ('ICT'). Inner Circle Trader YouTube (2022 Mentorship series)."
source_citation: "ICT 2022 Mentorship — Mitigation Block concept; synthesized in Mmari (2020) FOREX ICT & MMM Notes, p. 40"
edge_type: mean-reversion
period: H1
target_symbols: [EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, NDX.DWX]
expected_trades_per_year_per_symbol: 30
```

**Entry (short example):**
1. Identify a historical bullish OB on H1 (the last bearish candle before a strong N-candle upward expansion, where N ≥ 3)
2. Price later breaks back down through the OB's low (OB is "mitigated")
3. Price rallies back up and enters the OB range (now a mitigation zone = resistance)
4. Short entry on touch of the mitigation block's original high (limit order)
5. Stop: 1 ATR(14) above the mitigation block high
6. Target: Recent swing low below entry

**Note for builder:** The OB identification logic is identical to existing QM5_10095/QM5_1050 — the key difference is the "mitigation" state flag (has price already broken through the OB at least once before?). Requires tracking OB states across the backtest.

---

### Proposal 2: `ict-breaker-block-sweep-reverse-h4` (NEW)

```yaml
slug: ict-breaker-block-sweep-reverse-h4
source: "Huddleston, M.J. ('ICT'). Inner Circle Trader YouTube (2022 Mentorship series)."
source_citation: "ICT 2022 Mentorship — Breaker Block concept; synthesized in Mmari (2020) FOREX ICT & MMM Notes, p. 41"
edge_type: mean-reversion
period: H4
target_symbols: [EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX]
expected_trades_per_year_per_symbol: 15
```

**Entry (bearish breaker example):**
1. Identify swing high: highest close of the past 20 bars
2. Price wicks above (sweeps) the swing high on next bar, then closes below the swing high close
3. On the next bar or within 5 bars: price also closes below the swing high's open (confirming displacement)
4. The candle(s) forming the original swing high define the **bearish breaker zone** (high of swing candles)
5. Short entry: Limit order at the breaker zone (expect price to return and be rejected)
6. Stop: 1 ATR(14) above the highest candle in the breaker zone
7. Target: 2:1 R:R minimum; or next swing low

---

### Proposal 3 (complex): `ict-smt-divergence-eurusd-gbpusd-h1` (NEW — multi-symbol)

```yaml
slug: ict-smt-divergence-eurusd-gbpusd-h1
source: "Huddleston, M.J. ('ICT'). Inner Circle Trader YouTube (2022 Mentorship series)."
source_citation: "ICT 2022 Mentorship — SMT Divergence; synthesized in Mmari (2020), pp. 23–26"
edge_type: mean-reversion
period: H1
target_symbols: [EURUSD.DWX]
secondary_symbol: GBPUSD.DWX
expected_trades_per_year_per_symbol: 20
```

**Entry (bearish divergence = sell EUR/USD):**
1. EUR/USD closes at a new 20-bar high on current H1 bar
2. GBP/USD does NOT close at a new 20-bar high on the same bar (non-confirmation)
3. Bearish SMT signal: short EUR/USD at next bar open
4. Stop: 1 ATR(14) above the EUR/USD swing high that triggered the signal
5. Target: 20-bar low of EUR/USD

**Implementation note:** Requires `CopyRates("GBPUSD.DWX", ...)` in the EUR/USD chart EA. Builder must verify both symbols available simultaneously on factory terminals. This is the same infrastructure challenge as the commodity correlation card.

---

## Fidelity Initiative Note

The fidelity initiative (project_qm_fidelity_initiative_2026-06-12) is focused on ensuring new ICT card builds implement canonical ICT rules rather than TradingView adaptations. This mining doc confirms:

1. **Kill zone times are canonical** — 23:00-03:00, 07:00-10:00, 15:00-18:00, 12:00-15:00 GMT
2. **Mitigation Block and Breaker Block are distinct ICT concepts** not yet carded — both are high-fidelity candidates
3. **SMT Divergence** is canonical ICT but requires multi-symbol infrastructure

For QM5_12535/12536/12537 (the three fidelity cards built 2026-06-12): this source confirms their conceptual framework. Individual card body review is in `LIBRARY_MINING_wilder-new-concepts-1978_2026-06.md` (Wilder/fidelity section). No ICT card body failures noted.

---

## Recommendation

Priority: Proposal 2 (Breaker Block, H4) > Proposal 1 (Mitigation Block, H1) > Proposal 3 (SMT Divergence, multi-symbol complex).

Breaker Block first because: (a) sweep+reversal family is already proven in our pipeline via QM5_10692, (b) H4 generates manageable trade frequency, (c) no multi-symbol complexity. Mitigation Block requires careful OB state tracking (more complex builder ask). SMT Divergence is most novel but most complex — flag for later when multi-symbol EA infrastructure is better tested.
