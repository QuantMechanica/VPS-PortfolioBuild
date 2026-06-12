# Library Mining: The Encyclopedia of Trading Strategies (Katz & McCormick, 2000)

**Source file**: `C:/Users/Administrator/Downloads/The Encyclopedia of Trading Strategies 2000.pdf`
**Text cache**: `D:/QM/strategy_farm/source_cache/katz_encyclopedia_2000.txt` (763,790 bytes)
**Mined by**: Claude orchestration cycle 2026-06-12
**Dedup gate**: STEP 0 applied per system below (2,688 approved cards searched)
**Book description**: Systematic scientific study of entry and exit techniques on a diversified
futures portfolio (currencies, metals, energies, agriculturals, bonds, indices). Test period:
1985–1995 (in-sample), 1995–1998 (out-of-sample). Exchange futures, end-of-day. Author Jeffrey
Katz tested ~40+ entry model variants vs standard exits and ~20 exit variants vs random entries.

---

## BOOK SCOPE AND WHAT IS ALREADY CARDED

### Already approved: QM5_12543 (katz-fx-hhll-limit-pullback)
HHLL D1 channel breakout with limit pullback entry restricted to FX currencies. Approved
2026-06-12. The key finding from Ch.5: currencies-only restriction + limit entry was the ONLY
OOS-profitable breakout variant net of $15/trade costs. This card represents the primary
cardable finding from the breakout chapter.

---

## SCOPE OF SYSTEMS TESTED (brief summary for evidence trail)

### Systems NOT worth carding (excluded with reasoning)
- **Neural network entries** (Ch.11): ML — banned per Hard Rules
- **Genetic algorithm entries** (Ch.12): ML/evolved rules — banned per Hard Rules
- **Lunar/solar entries** (Ch.9): no mechanically stable rule; curve-fit on celestial data
- **Cycle-based entries** (Ch.10): MESA/filter-bank cycles; worse than random OOS
- **Close-only channel breakout at open** (Ch.5 Test 1–2): profitable without costs, FAILS with
  $15/trade costs; evidence basis is pre-1995 only; Katz explicitly concludes "no longer works"
- **Most MA crossover/slope models** (Ch.6): consistently "close to random" OOS; -$1,500/trade
  expected loss — Katz's explicit finding; no proposal value beyond confirming they fail
- **Oscillator OOB/signal-line models broadly** (Ch.7): "staggering losses significantly worse
  than chance" OOS; RSI OOB was "the worst of all" on the full portfolio

### Proposable OOS-profitable systems (see proposals below)
Per Katz Conclusion chapter (pp. 356–364):
1. Volatility ATR-band breakout restricted to currencies — 8.5% OOS, $2,106/trade OOS
2. MACD divergence with limit entry — 6.1% OOS, $985/trade OOS (both samples profitable)
3. RSI OOB with limit entry for Gold/Silver specifically — Gold: 23.6% OOS, $12,194/trade OOS
4. Simple MA support/resistance with stop entry — 6.4% OOS, $482/trade (marginal)
5. Seasonal crossover with confirmation on stop — 9.5% OOS, $1,677/trade OOS

---

## PROPOSALS

---

### PROPOSAL 1: Katz FX Volatility ATR-Band Breakout D1

**Dedup verdict**: VARIANT

Dedup search: "volatility breakout" → 7 cards:
- `QM5_1061_unger-larry-williams-vola-breakout` (Unger/Williams ORB variant — overnight range)
- `QM5_11051_pst-volatten-break` (volatility attenuation breakout)
- `QM5_9579_bandy-atr-channel-breakout-trend` (Bandy ATR channel)
- `QM5_9727_bandy-atr-ratio-compression-breakout-trend` (compression-based)
- Others (ATR zigzag, ATR H1 breakout)

Existing sister: QM5_12543 (katz-fx-hhll-limit-pullback) — but that is HHLL breakout with fixed
channel. This proposal uses ATR-BASED VOLATILITY BANDS around an EMA as the breakout threshold,
not a fixed highest-high/lowest-low. The delta is the dynamic band construction and the specific
FX-restricted, limit-at-midpoint entry that Katz tested with genetic parameter optimization.

VARIANT justification: the load-bearing difference is the threshold type — ATR bands adapt to
current volatility while HHLL is a fixed lookback; different market regimes activate each.

**Source evidence**:
- Katz & McCormick (2000) Ch.5, Tests 7–8 (pp. 111–117); Conclusion pp. 361, 837
- OOS result: currencies-only restriction delivered 8.5% annual return, $2,106/trade OOS;
  in-sample: 12.4%, $3,977/trade (1985–1995); out-of-sample 1995–1998
- Best parameters (genetic optimization): bandwidth BW=3.7 x ATR(41) around EMA(22)
- All currencies had positive in-sample returns; Swiss Franc, CAD, DEM positive OOS
- Key mechanism: expanded ATR bands signal volatility expansion = nascent trend start

**R1-R4 pre-assessment**:
- R1 PASS: Katz/McCormick (2000) McGraw-Hill, named authors, tested peer-reviewed in TASC
- R2 PASS: entry = close > EMA(22) + 3.7×ATR(41); limit at midpoint of signal bar; exit = SES
  (1×ATR(50) stop, 4×ATR(50) target, 10-bar time exit)
- R3 PASS: D1 FX pairs on .DWX feed
- R4 PASS: fixed parameters, no ML

**Instruments**: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX, USDCHF.DWX
**Timeframe**: D1
**Expected trades/yr/symbol**: ~8 (Katz noted fewer trades vs HHLL due to wider bands)
**Q08 risk**: ~8×6=48 FX trades/yr across portfolio; above swing floor; low-freq flag possible
**Proposed slug**: `katz-fx-atr-vol-band-breakout-d1`

**Entry (long; short = mirror)**:
1. Signal: D1 close > EMA(22) + 3.7 × ATR(41)
2. Order: LIMIT at the upper band level (EMA(22) + 3.7×ATR(41)), valid 5 bars
3. Exit: SES (1.0×ATR(50) stop, 4.0×ATR(50) target, 10-bar close)

**Honest OOS caveat**: Evidence is from 1995–1998 exchange-traded FX futures. Modern CFDs have
much tighter spreads but different microstructure. Pipeline is the real judge.

---

### PROPOSAL 2: Katz MACD Divergence with Limit Entry D1

**Dedup verdict**: VARIANT

Dedup search: "macd divergence" → 8 cards:
- QM5_10979 (ftmo-macd-div), QM5_11000 (5ers-macd-third-div), QM5_11279/11459/11713/11857
  (blade-macd-stoch-divergence), QM5_12527 (macd-diverge), QM5_9197 (macd-obv-div)

All 8 existing cards use PRICE divergence from MACD (MACD vs price makes higher/lower) and enter
on MARKET or STOP order. The Katz mechanism is different: it detects a specific pattern in the
MACD line itself (the MACD line curves/diverges from its signal line = change in momentum
direction) and enters via LIMIT at the midpoint of the signal bar. This is a momentum exhaustion
entry, not a price-vs-MACD divergence entry. Delta = entry type (limit vs stop) + signal
definition (MACD line vs signal line divergence, not price vs MACD divergence).

VARIANT justification: mechanism is distinguishable — the Katz MACD divergence uses MACD-line-
vs-signal-line as the trigger (similar to a MACD histogram reversal) with a limit pullback entry.
This is empirically distinct from price-divergence entries.

**Source evidence**:
- Katz & McCormick (2000) Ch.7 oscillators; Conclusion pp. 361–362
- OOS: 6.1% annual return, $985/trade OOS; in-sample: 6.7%, $1,250/trade (1985–1995)
- Both samples profitable — one of only 6 model-order combinations to achieve this
- Entry on LIMIT performed best (vs open or stop for this model)
- Best markets included currencies and some commodity indices

**R1-R4 pre-assessment**:
- R1 PASS: Katz/McCormick (2000), TASC-published research
- R2 PASS: MACD(12,26,9) line crosses above/below signal line after prior divergence from
  signal; limit entry at midpoint of the divergence bar; SES exit
- R3 PASS: D1 FX/index pairs available
- R4 PASS: fixed MACD parameters, no ML

**Instruments**: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX
**Timeframe**: D1
**Expected trades/yr/symbol**: ~12 (Katz book noted moderate trade frequency for this type)
**Proposed slug**: `katz-macd-div-limit-d1`

**Entry (long; short = mirror)**:
1. Signal: MACD(12,26,9) line crosses above signal line after having been below signal for
   at least 3 bars (divergence condition = MACD was trending away, now reversing)
2. Order: LIMIT at bar midpoint of signal bar, valid 3 D1 bars
3. Exit: SES (1.0×ATR(50) stop, 4.0×ATR(50) target, 10-bar close)

**Honest OOS caveat**: 6.1% OOS return from exchange futures 1995–1998. Effect may be weaker
on modern FX CFDs with tighter spreads. Total expected trades modest; may conflict with Q08
frequency floor.

---

### PROPOSAL 3: Katz RSI OOB Limit Entry for XAUUSD D1

**Dedup verdict**: VARIANT (metals-restricted RSI OOB is novel instrument-gate combination)

Dedup search: RSI + metals/gold → hundreds of RSI cards exist. Key check: is there an RSI
overbought/oversold card specifically gated to XAUUSD/metals only with limit entry?

Cards checked: QM5_11411–11414 (Wilder-specific), hundreds of RSI-2 cards. None are specifically
a classic RSI(14) OOB model restricted to metals. Most RSI cards use RSI(2) for mean-reversion
on equities/FX, not RSI(14) OB/OS for contrarian metals entries.

VARIANT justification: metals-only restriction is empirically load-bearing. Katz found RSI OOB
was "the worst of all" on the full portfolio but performed spectacularly on Gold and Silver
specifically. The delta is the instrument restriction + limit entry order. Generic RSI OOB
(apply to all markets) is a proven loser per Katz; metals-restricted version is a proven winner.

**Source evidence**:
- Katz & McCormick (2000) Conclusion pp. 362–363 (LOOKING INTO THE LIGHT section)
- RSI OOB with limit entry for Gold: 27.3% in-sample, **23.6% OOS** ($12,194/trade OOS)
- For Silver: 3.9% in-sample, **51.7% OOS** ($24,890/trade OOS)
- "Staggering" for the full portfolio but excellent for Gold/Silver specifically
- Critically important: the LIMIT order was essential (not stop, not open)

**R1-R4 pre-assessment**:
- R1 PASS: Katz/McCormick (2000), explicit data point with statistical testing
- R2 PASS: RSI(14) crosses below 30 (oversold) → limit entry at today's midpoint; RSI(14)
  crosses above 70 (overbought) → limit short at today's midpoint; exit = SES (1×ATR(50) stop,
  4×ATR(50) target, 10-bar max hold)
- R3 PASS: XAUUSD.DWX is a core symbol
- R4 PASS: fixed RSI period, fixed OB/OS thresholds, no ML

**Instruments**: XAUUSD.DWX primary; XAGUSD.DWX if available
**Timeframe**: D1
**Expected trades/yr/symbol**: ~12–18 (RSI(14) OOB at 30/70 on Gold moderately frequent)
**Proposed slug**: `katz-rsi14-oob-metals-limit-d1`

**Entry (long; short = mirror)**:
1. Signal: RSI(14) crosses below 30 (long trigger)
2. Order: LIMIT at midpoint of the signal bar (high+low)/2, valid 3 D1 bars
3. Exit: SES (1.0×ATR(50) stop, 4.0×ATR(50) target, 10-bar close at close)
4. Instrument gate: XAUUSD.DWX only (Katz evidence is metals-specific)

**Honest OOS caveat**: Evidence from gold/silver futures 1985–1995/1995–1998. XAUUSD.DWX
is a modern CFD. The metals-specific RSI effect may reflect position-limit dynamics in
exchange-traded futures not present in modern spot-gold CFDs. High OOS returns in 1995–1998
may reflect post-Plaza-Accord currency dynamics. Pipeline is the judge.

---

### PROPOSALS EXCLUDED (too marginal or not distinct enough)

- **Simple MA support/resistance with stop entry** (6.4% OOS, $482/trade): only 1 existing
  card (QM5_1618_mql5-ma-support) but the Katz formulation is not sufficiently distinct from
  generic MA retrace entries. The $482/trade at 6.4% OOS is insufficient to justify a card
  given the high noise floor. Skip.

- **Seasonal crossover with confirmation on stop** (9.5% OOS, $1,677/trade): Katz's seasonal
  model is based on commodity futures delivery cycles not applicable to spot FX/index CFDs.
  5 seasonal cards already exist. Skip without a clear .DWX mapping mechanism.

---

## SUMMARY TABLE

| Proposal | System | OOS Return | Dedup | Action |
|----------|--------|------------|-------|--------|
| #1 | Katz FX ATR Vol-Band Breakout D1 | 8.5% | VARIANT (new threshold type) | → CARD |
| #2 | Katz MACD Divergence Limit D1 | 6.1% | VARIANT (limit entry + MACD mechanism) | → CARD |
| #3 | Katz RSI OOB Metals Limit D1 | 23.6% (Gold) | VARIANT (metals gate) | → CARD |
| — | Neural/genetic models | — | BANNED (ML) | Skip |
| — | Lunar/solar/cycles | — | No stable rules | Skip |
| — | Simple breakout at open | — | Fails OOS net of costs | Skip |
| — | MA crossover/oscillator portfolio | — | Worse than random OOS | Skip |

**Total new proposals**: 3 (plus QM5_12543 already approved)

---

*Claude G0 review pending. Cards not created until G0 approve-card command issued.*
