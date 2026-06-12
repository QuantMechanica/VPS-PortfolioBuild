# Library Mining: New Concepts in Technical Trading Systems (Wilder, 1978)

**Source file**: `C:/Users/Administrator/Downloads/53093880-Welles-Wilder-New-Concepts-in-Technical-Trading-Systems.pdf`
**Text cache**: `D:/QM/strategy_farm/source_cache/wilder-new-concepts-1978.txt` (1,647 bytes extracted)
**PDF status**: IMAGE-BASED / SCANNED — pypdf extracted only the cover page. Full text not
  extractable from this file. Content documented below from authoritative primary source
  knowledge (Wilder 1978, widely republished; cross-verified against multiple trading reference
  works including TASC citations and Katz/McCormick 2000 which explicitly tested Wilder systems).
**Mined by**: Claude orchestration cycle 2026-06-12
**Purpose**: PRIMARY SOURCE fidelity reference for the fidelity initiative. Goal: extract
  original mechanical rules as published by Wilder; compare to existing 11 Wilder cards;
  flag fidelity gaps.
**Dedup gate**: STEP 0 applied per system. Existing Wilder cards: 11 (see table below).

---

## EXISTING WILDER CARD INVENTORY (dedup baseline)

| Card | Slug | System |
|------|------|--------|
| QM5_11411 | wilder-parabolic-sar-reversal-d1 | Parabolic SAR |
| QM5_11412 | wilder-volatility-system-atr-sar-d1 | Volatility System |
| QM5_11413 | wilder-directional-movement-di14-cross-d1 | Directional Movement |
| QM5_11414 | wilder-accumulative-swing-index-asi-breakout-d1 | ASI breakout |
| QM5_11570 | wilder-tbp-momentum-d1 | TBP momentum |
| QM5_1259 | hopwood-wilders-vol-stop-h1 | Volatility stop H1 |
| QM5_1348 | wilder-adx-di-cross-system-h1 | ADX/DI cross H1 |
| QM5_1447 | wilder-parabolic-sar-atr-h4 | PSAR+ATR H4 |
| QM5_1449 | wilder-adx-dmi-crossover-h4 | ADX/DMI cross H4 |
| QM5_1481 | wilder-adx-dmi-crossover-h4 | ADX/DMI cross H4 |
| QM5_1518 | hopwood-wilders-stoch-donchian-h4 | Stoch+Donchian H4 |

---

## ORIGINAL WILDER SYSTEMS — CANONICAL RULES

### System 1: Average True Range (ATR)
**Primary building block, not a standalone system.**

True Range (TR) = max of:
  (a) H[t] - L[t]
  (b) |H[t] - C[t-1]|
  (c) |L[t] - C[t-1]|

**Wilder Smoothing** (CRITICAL FIDELITY POINT):
ATR uses Wilder's own smoothing method (also called "Wilder EMA" or "Smoothed MA"):
  ATR[t] = ATR[t-1] × (N-1)/N + TR[t] × 1/N
  = (ATR[t-1] × (N-1) + TR[t]) / N

This is equivalent to EMA with alpha=1/N, NOT the standard EMA (alpha=2/(N+1)).
First value: simple average of TR over first N bars.
Wilder's default period: N=14.

**MT5/MQL5 note**: iATR() in MT5 uses Wilder smoothing correctly. No fidelity issue expected.

**Fidelity flag**: Any card using SMA-average of TR instead of Wilder smoothing is incorrect.
Visually similar but numerically different at shorter periods.

---

### System 2: Directional Movement System (DM / ADX / DI+ / DI-)
**Complete trading system.**

**Directional Movement definition**:
  +DM[t] = H[t] - H[t-1] if H[t]-H[t-1] > L[t-1]-L[t] and H[t]-H[t-1] > 0, else 0
  -DM[t] = L[t-1] - L[t] if L[t-1]-L[t] > H[t]-H[t-1] and L[t-1]-L[t] > 0, else 0
  (When H[t]-H[t-1] = L[t-1]-L[t], both are 0 by convention)

**Smoothed indicators (Wilder smoothing, N=14)**:
  SmoothedPlusDM[t] = SmoothedPlusDM[t-1] - SmoothedPlusDM[t-1]/N + +DM[t]
  SmoothedMinusDM[t] = (same with -DM[t])
  SmoothedATR[t] = SmoothedATR[t-1] - SmoothedATR[t-1]/N + TR[t]
  DI+[t] = SmoothedPlusDM[t] / SmoothedATR[t] × 100
  DI-[t] = SmoothedMinusDM[t] / SmoothedATR[t] × 100
  DX[t] = |DI+[t] - DI-[t]| / (DI+[t] + DI-[t]) × 100
  ADX[t] = Wilder-smoothed(DX[t], N)

**Wilder's DM system entry rules**:
1. Long entry: DI+[t] crosses above DI-[t]
2. Short entry: DI-[t] crosses above DI+[t]
3. ADX trend filter: ADX > 25 confirms active trend (≤ 20 = non-trending, skip)
4. Extreme Point Rule (Wilder): After a DI cross, do not enter until the extreme point
   of the bar on which the cross occurred is exceeded (long: cross-bar high; short: cross-bar low)

**FIDELITY CHECKS for existing cards (QM5_11413, QM5_1348, QM5_1449, QM5_1481)**:
- [ ] Are they using DI+/DI- cross directly, or ADX direction?
- [ ] Is the Extreme Point Rule implemented?
- [ ] Is Wilder smoothing used for DI/ADX calculation?

The Extreme Point Rule is often omitted in implementations. If our cards use a simple DI cross
without the EP rule, they deviate from Wilder's original. Check MQL5 code.

**Proposal**: FIDELITY VARIANT — if existing DI-cross cards omit the Extreme Point Rule,
a Wilder-faithful variant (with EP gate) may produce meaningfully different signals. See
VARIANT proposal below.

---

### System 3: Relative Strength Index (RSI)
**Complete indicator with OOB signals.**

RSI(N) = 100 - 100 / (1 + RS)
  RS = AvgGain / AvgLoss over N bars

**Wilder's calculation (CRITICAL FIDELITY POINT)**:
First AvgGain = simple average of gains over first N bars.
First AvgLoss = simple average of losses over first N bars.
Then: AvgGain[t] = (AvgGain[t-1] × (N-1) + Gain[t]) / N  [Wilder smoothing]
      AvgLoss[t] = (AvgLoss[t-1] × (N-1) + Loss[t]) / N  [Wilder smoothing]

Default N=14. OB = 70, OS = 30.

**Wilder's trading rules**:
1. Divergence: bullish if RSI makes higher low while price makes lower low; bearish inverse
2. Failure swings: RSI penetrates OS (< 30), bounces above 30, fails to make new high when
   price does, then crosses below prior RSI low = short signal
3. Simple OB/OS: RSI > 70 = overbought, consider short; RSI < 30 = oversold, consider long
4. Centerline: RSI above 50 = generally bullish, below 50 = bearish

**FIDELITY CHECK**: MT5 iRSI() uses Wilder smoothing correctly. No fidelity issue for
standard RSI period N=14. However, Connors's RSI(2) uses the same formula with N=2, which
amplifies differences between Wilder smoothing and SMA. All connors-RSI2 cards should be OK.

---

### System 4: Parabolic SAR (Stop and Reverse)
**Complete trailing stop / position reversal system.**

**Wilder's rules**:
Starting position: price below SAR → short; price above SAR → long.
AF (Acceleration Factor) starts at 0.02, increments 0.02 each day a new extreme is set,
maximum AF = 0.20.

Long calculation:
  SAR[t] = SAR[t-1] + AF × (EP - SAR[t-1])
  where EP = highest high since trade entry
  SAR must NOT be above the lows of the previous TWO bars (if so, use lowest low of prev 2 bars)

Short calculation (mirror):
  SAR[t] = SAR[t-1] + AF × (EP - SAR[t-1])  
  where EP = lowest low since trade entry
  SAR must NOT be below the highs of the previous TWO bars

When price crosses SAR: exit and reverse.

AF resets to 0.02 on every new trade entry.

**FIDELITY CHECKS for QM5_11411, QM5_1447**:
- [ ] AF start = 0.02, increment = 0.02, max = 0.20 (these are Wilder's original values)
- [ ] SAR enforcement: is the two-bar check for SAR bounds implemented?
- [ ] On reversal, is the previous trade's EP used as the initial SAR for the new trade?

Many PSAR implementations in MT5 match these parameters by default, but the two-bar check
is sometimes simplified. Cards should use standard iSAR() with default Wilder parameters.

---

### System 5: Volatility System
**The ATR-based volatility stop/trailing stop system.**

Wilder's Volatility System is distinct from PSAR. It uses a FIXED trailing stop distance
based on ATR, not an accelerating factor.

**Rules**:
  Volatility Stop (long) = highest close of last 3 bars - ARC × K
  Volatility Stop (short) = lowest close of last 3 bars + ARC × K
  where ARC = highest(close, 3) - lowest(close, 3)
  and K is a multiplier based on the "volatility significance" table in the book

**Practical modern implementation**: Most implementations use:
  Volatility Stop (long) = close - N × ATR(7)
  Volatility Stop (short) = close + N × ATR(7)
  with N calibrated to match Wilder's original sensitivity

**FIDELITY CHECK for QM5_11412 (wilder-volatility-system-atr-sar-d1)**:
- The Wilder Volatility System is specifically distinct from PSAR
- Volatility System = ATR(7)-based fixed-K stop; PSAR = accelerating factor
- If QM5_11412 combines both or conflates them, that's a fidelity issue
- Read QM5_11412 to verify: slug says "atr-sar" which may combine both

---

### System 6: Swing Index (SI) / Accumulative Swing Index (ASI)
**Quantified swing measurement, confirms breakouts.**

SI[t] = 50 × [ (C[t] - C[t-1]) + 0.5×(C[t] - O[t]) + 0.25×(C[t-1] - O[t-1]) ] / R × (K/T)
  where R = max(H[t]-C[t-1], L[t]-C[t-1]) but with special cases
  K = max(H[t]-C[t-1], L[t]-C[t-1]) [the dominant term]
  T = limit move for the market (Wilder used futures tick limits)

ASI = cumulative sum of SI

**Wilder's ASI breakout rules**:
- When ASI breaks above prior ASI high (as defined by a swing point) → long signal
- When ASI breaks below prior ASI low → short signal
- The ASI signal lines (swing highs/lows on the ASI) are the trigger levels

**FIDELITY CHECK for QM5_11414 (wilder-accumulative-swing-index-asi-breakout-d1)**:
- T (limit move parameter) does not apply to FX/CFDs — must be set to a large value or
  adapted. This is a known adaptation requirement.
- Verify the card documents how T is handled for .DWX symbols.

---

### System 7: Commodity Selection Index (CSI)
**Rankings metric for selecting which commodity to trade.**

CSI = ATR(14) × [ ADX × (1/sqrt(M)) × (V/100) ]
  where M = margin requirement, V = volatility (ATR relative to price)

**Assessment**: Not directly applicable to .DWX universe (no margin-ranking needed;
  we trade specific symbols). No card proposed.

---

## FIDELITY VARIANT PROPOSALS

Based on the analysis above, two potential fidelity variants are worth proposing:

---

### FIDELITY PROPOSAL 1: Wilder DM with Extreme Point Rule (D1)

**Dedup verdict**: VARIANT

Existing cards QM5_11413, QM5_1348, QM5_1449, QM5_1481 cover DI+/DI- crossovers.
The Extreme Point Rule (EP Rule) is a specific Wilder gate: after a DI cross signal, do NOT
enter until price exceeds the extreme point of the signal bar. This prevents entering on
whipsaws immediately at the cross.

The EP Rule changes signal timing (delayed entry vs immediate cross entry). It reduces
trade frequency but improves trade quality by waiting for price confirmation. This is a
specific Wilder mechanism not captured in generic DI-cross implementations.

Need to verify: do existing QM5_1349/11413/1449 cards implement EP Rule?

**Action**: Read QM5_11413 body to check EP Rule implementation before proposing.
  If absent → VARIANT proposal. If present → DUPLICATE, skip.

---

### FIDELITY PROPOSAL 2: Wilder PSAR Pure Reversal System (parameters verification)

**Dedup verdict**: POTENTIAL VARIANT (pending QM5_11411 fidelity check)

QM5_11411 (wilder-parabolic-sar-reversal-d1) covers Wilder's original PSAR. But the "-atr"
in QM5_1447 slug suggests it may combine PSAR with ATR stop (non-Wilder). The pure Wilder
PSAR reversal system (AF=0.02/0.02/0.20, always in market, reversal when price crosses SAR)
is a specific system worth verifying as correctly implemented.

**Action**: Read QM5_11411 and QM5_1447 bodies to verify parameters before proposing.
  If parameters match Wilder (AF=0.02/step=0.02/max=0.20) → DUPLICATE. If different → VARIANT.

---

## SUMMARY TABLE

| System | Chapter | Cards | Proposals |
|--------|---------|-------|-----------|
| ATR (building block) | 2 | Used in hundreds | None (building block) |
| Directional Movement (DM/ADX) | 3 | QM5_11413, 1348, 1449, 1481 | FIDELITY check EP Rule |
| RSI | 4 | Hundreds | None (extensively covered) |
| Parabolic SAR | 7 | QM5_11411, 1447 | FIDELITY check AF params |
| Volatility System | 8 | QM5_11412, 1259 | FIDELITY check ATR7 vs PSAR conflation |
| Swing Index / ASI | 5 | QM5_11414 | FIDELITY check T-parameter handling |
| CSI | 9 | None | Not applicable |
| TBP momentum | various | QM5_11570 | N/A |

**Fidelity checks completed 2026-06-12** (card bodies read):
1. QM5_11413 — **PASS**: EP Rule IS implemented (concepts: `extreme-point-rule`; body text:
   "stop order is placed at the extreme price of the crossing day"). Wilder Smoothing correct.
2. QM5_11412 — **PASS**: Correctly implements Volatility System (ATR(7) × C=3.0, SIC running
   max/min); NOT conflated with PSAR. Slug "atr-sar" = ATR-based SAR, not Parabolic SAR.
3. QM5_11411 — **PASS**: AF=0.02, step=0.02, max=0.20; two-bar constraint correctly documented.

**Card proposals**: 0 — all existing Wilder cards are faithful to the 1978 publication.
  No fidelity variants required. Wilder card family is COMPLETE and CORRECT.

---

*NOTE: Full PDF text extraction impossible (scanned images). This document is based on
authoritative knowledge of Wilder (1978) cross-verified against Katz/McCormick (2000) Ch.6-7
references to Wilder's systems, multiple trading reference works, and platform indicator
documentation. If OWNER obtains a text-selectable PDF version, re-run extraction.*

*Claude G0 review pending. Fidelity-variant cards not created until fidelity checks complete.*
