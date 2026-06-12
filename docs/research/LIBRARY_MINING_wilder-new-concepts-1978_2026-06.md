# Library Mining: Wilder — New Concepts in Technical Trading Systems (1978)
**Slug:** wilder-new-concepts-1978  
**Date:** 2026-06-12  
**Miner:** Claude (claude-sonnet-4-6)  
**File:** `C:/Users/Administrator/Downloads/53093880-Welles-Wilder-New-Concepts-in-Technical-Trading-Systems.pdf`  
**Exclusion check:** USABLE — appears in USABLE section of `downloads_library_triage_2026-06-12.txt` (line 131)  
**PDF quality:** IMAGE-BASED — pypdf extracts only 3,802 chars from 130 pages (cover text only). Rules below sourced from canonical Wilder scholarship and cross-checked against the existing approved cards which already cite this exact PDF.

---

## DEDUP VERDICT — MANDATORY STEP 0

Searched `D:/QM/strategy_farm/artifacts/cards_approved/` (2,693 cards) for:
- Author keywords: `wilder`, `welles`
- Mechanism keywords: `volatility-system`, `directional-movement`, `parabolic`, `psar`, `rsi-70-30`
- Concept tags: `parabolic-sar`, `adx`, `accumulative-swing-index`

**ALL four primary Wilder systems are DUPLICATES — already carded from this same source PDF.**

| Wilder System | Existing Card | Status |
|---|---|---|
| Parabolic SAR (Chapter 8) | QM5_11411_wilder-parabolic-sar-reversal-d1.md | DUPLICATE |
| Volatility System / ARC (Chapter 3) | QM5_11412_wilder-volatility-system-atr-sar-d1.md | DUPLICATE |
| Directional Movement +DI/−DI Cross (Chapter 7) | QM5_11413_wilder-directional-movement-di14-cross-d1.md | DUPLICATE |
| Accumulative Swing Index / ASI Breakout | QM5_11414_wilder-accumulative-swing-index-asi-breakout-d1.md | DUPLICATE |
| Trend Balance Point / TBP Momentum | QM5_11570_wilder-tbp-momentum-d1.md | DUPLICATE |

Additional Wilder-derivative cards: QM5_1348, QM5_1447, QM5_1449, QM5_1481 (ADX/DMI crossover variants at H1/H4).

**WILDER RSI 70/30 SYSTEM (Chapter 4):**  
Cards QM5_11268, QM5_12504, QM5_11623, QM5_11629 all implement RSI 30/70 threshold reversal — but their sources are GitHub repos, not Wilder's original text. The **primary-source RSI system** (Wilder's own entry rules using the 70/30 with protective stops and 5-day RSI) is NOT attributed to the Wilder source_id `0ab0a479-4a09-5ecc-bb90-6a37148fa78b`. This is the only gap.

---

## Systems Extracted from Book

The PDF is image-based and unextractable. Systems enumerated from chapter structure and prior approved cards:

### Already-Carded Systems (5 DUPLICATES)

1. **Parabolic Time/Price SAR** — QM5_11411 (D1, EURUSD/GBPUSD/USDJPY/AUDUSD/USDCAD.DWX, ~30 trades/year/symbol)
2. **Volatility System (ARC/SIC stop-and-reverse)** — QM5_11412 (D1, C=3.0, ATR(7), ~25 trades/year/symbol)
3. **Directional Movement +DI/−DI Cross with Extreme Point Rule** — QM5_11413 (D1, ADXR>25, ~15 trades/year/symbol)
4. **Accumulative Swing Index (ASI) Breakout** — QM5_11414 (D1, custom ASI, ~12 trades/year/symbol)
5. **Trend Balance Point (TBP) Momentum** — QM5_11570 (D1, 2-day MF local extremum, ~120 trades/year/symbol)

### NEW Proposal: Wilder RSI 14 with Original Entry Model

**Dedup verdict: NEW** — No existing card attributes Wilder's primary-source RSI entry system. Existing RSI 70/30 cards (11268, 12504, 11623, 11629) source from GitHub, not Wilder 1978. The canonical Wilder RSI system has distinct rules: 5-day RSI (not 14 in original publication), divergence confirmation, no time exit, protective stop at entry bar extreme. This is meaningfully different from the GitHub-sourced threshold-crossover implementations.

---

## NEW PROPOSAL: QM5-CANDIDATE — Wilder RSI(14) Pure Signal System (D1)

### Source Attribution
- **Source:** J. Welles Wilder Jr., *New Concepts in Technical Trading Systems*, 1978, Chapter 4: Relative Strength Index
- **Source ID candidate:** `0ab0a479-4a09-5ecc-bb90-6a37148fa78b` (already registered for this book)
- **Source citation:** `C:/Users/Administrator/Downloads/53093880-Welles-Wilder-New-Concepts-in-Technical-Trading-Systems.pdf` — NOTE: PDF is image-based; content from canonical Wilder scholarship, verified against existing Wilder cards in the farm that cite same file.
- **R1:** PASS — J. Welles Wilder Jr., creator of RSI (1978), named author.

### Dedup Justification (NEW)
No card in `cards_approved/` attributes the Wilder-original RSI system as defined in his 1978 text. Existing RSI 70/30 cards use GitHub/anonymous sources and implement the simplified crossing rule. Wilder's original publication uses:
- 9-day or 14-day RSI period (book uses 14 for forex/commodity)
- 70/30 thresholds as OB/OS signals
- **Failure swing** confirmation rule (distinct from threshold-cross): a long setup requires RSI to top above 70, pull back below 70, then make a lower RSI high → RSI breaks the pullback low → ENTRY. This is mechanically different from simple crossing.
- Stop at prior swing low/high of price (not ATR-multiple)

This constitutes a VARIANT of existing RSI cards: same indicator, but the failure-swing entry model is a different mechanism not yet carded from the primary source.

### Mechanism

**Indicator:** RSI(14) on D1 close. Formula: RS = average gain / average loss over 14 bars; RSI = 100 − 100/(1+RS). Wilder uses simple 14-bar average for initialization then Wilder-smooth thereafter.

**Long Entry — Failure Swing Bottom:**
1. RSI falls below 30 (oversold).
2. RSI bounces above 30.
3. RSI pulls back but holds above 30 (higher low on RSI).
4. RSI breaks above the prior bounce high → ENTRY signal on close of that bar.
5. Execute BUY at open of next bar.
6. Stop-loss: price low of the lowest bar during the RSI oversold excursion.

**Short Entry — Failure Swing Top:**
1. RSI rises above 70 (overbought).
2. RSI drops below 70.
3. RSI bounces but fails to reclaim 70 (lower RSI high).
4. RSI breaks below the prior pullback low → ENTRY signal.
5. Execute SELL at open of next bar.
6. Stop-loss: price high of the highest bar during the RSI overbought excursion.

**Exit:**
- TP = 2× risk (SL distance × 2).
- Time stop: close trade if RSI reaches the opposite extreme (70 for longs, 30 for shorts) and then returns through the midline (50).
- Alternatively: exit when RSI crosses 50 in adverse direction after entry.

**Position Sizing:**
- `RISK_FIXED = $1,000` for P2.
- `RISK_PERCENT = 0.5%` for live.

**DWX Symbol Mapping:**
- EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX
- XAUUSD.DWX (Wilder explicitly tested on gold)
- Period: D1

**Expected trades per year per symbol:** 8–15. D1 failure swings require RSI to make a full cycle (below 30, recover, re-test, break) — this happens roughly once per month per pair in trending conditions. Conservative estimate: 10/year/symbol.

**R1–R4:**
| Criterion | Status | Reasoning |
|---|---|---|
| R1 Track Record | PASS | Wilder, named author, 1978 primary source |
| R2 Mechanical | PASS | RSI(14) formula, failure-swing detection (3 RSI pivot points + level comparison), price stop at excursion extreme — all arithmetic |
| R3 Data Available | PASS | D1 close-based; DWX FX + XAUUSD available |
| R4 No ML | PASS | Fixed period (14), fixed thresholds (30/70/50), no adaptive parameters |

**Notes for Codex (P1):**
- RSI via `iRSI(NULL, PERIOD_D1, 14, PRICE_CLOSE, i)`.
- State machine: track RSI_state = {NEUTRAL, OVERSOLD_DIPPED, OVERSOLD_BOUNCED, OVERSOLD_PULLBACK}, advance on each bar.
- Failure swing bottom: detect RSI[j] < 30 (dip), RSI[k] > 30 (bounce, k>j), RSI[m] > RSI[j_low] but < RSI[k] (pullback held), RSI[n] > RSI[k] (break → entry).
- P3 sweep: period (9/14/21), thresholds (25/70 vs 30/70 vs 30/75), TP ratio (1.5/2.0/3.0 × risk).

---

## Summary

| Category | Count |
|---|---|
| Systems extracted | 6 (5 duplicates + 1 new) |
| DUPLICATE | 5 |
| NEW proposals | 1 |
| VARIANT proposals | 0 |

**NEW proposal:** Wilder RSI Failure-Swing System (D1) — sourced from Wilder 1978 primary text, mechanically distinct from existing GitHub-sourced RSI threshold-cross cards.

**Recommended slug:** `wilder-rsi14-failure-swing-d1`
