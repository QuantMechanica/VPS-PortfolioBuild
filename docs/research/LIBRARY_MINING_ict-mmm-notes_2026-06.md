# Library Mining: Forex ICT & MMM Notes (Mmari, Jan 2020)

**Mined:** 2026-06-12
**Source file:** `D:/QM/strategy_farm/source_cache/ict-mmm-notes.txt`
**Author:** Reginald Mmari — a compilation/commentary on ICT (Inner Circle Trader) concepts
**Source line references:**
- Kill Zones: lines 1446–1489 (pages 44–45)
- Order Blocks: lines 955–1037 (pages 28–31)
- Crouching Outside Order Block: lines 1276–1279 (page 38)
- Judas Swing: lines 2640–2675 (pages 93–94)
- Power of Three / Accumulation: lines 1395–1430 (pages 42–43)
- OTE / Fibonacci: lines 542–553 and 2952–2986 (pages 15 and 103)
- ICT Buy and Sell Model: lines 1535–1611 (pages 47–50)
- Session Trading: lines 2013–2271 (pages 66–77)

---

## Step 0 — Dedup Gate (BINDING)

**Author/book match:** This document is an explicit ICT-framework compilation. The fidelity
initiative (QM5_12534–12540) was created precisely to canonicalize ICT rules into V5 cards.
Every named concept in the MMM notes — kill zones, order blocks, OTE, Judas Swing, AMD,
session tactics — has a direct card in the existing library. The dedup gate triggers strongly.

**Mechanism keyword check:**

| MMM Concept | Library coverage |
|---|---|
| Kill zones (Asian / London / NY) | QM5_12535_ict-killzone-sweep-idx, QM5_12539_ict-london-kz-cable-sweep, tv-ict-sess-v3 |
| Order blocks (bullish / bearish) | QM5_12536_ict-ob-retest-idx, tv-smc-ob, tv-nq-ict-ob, QM5_10095_gh-ict-orderblk |
| OTE (0.62–0.79 Fib retracement) | QM5_12537_ict-ote-displacement-xau, tv-ict-ote, tv-xau-smc-0618 |
| Judas Swing / stop-hunt / sweep | QM5_12540_ict-amd-judas-xau, tv-smc-liqgrab |
| AMD model (Accumulation-Manipulation-Distribution) | QM5_12540_ict-amd-judas-xau |
| FVG / displacement | tv-ict-ny-fvg, QM5_12537 |
| Market structure shift (MSS) | tv-smc-mss-fvg, tv-smc-fractal |
| Silver Bullet / Golden Bullet (session-scoped OTE) | QM5_1233, QM5_1234 |
| ICT Buy/Sell Model | QM5_12536, QM5_12540 (covered implicitly in AMD + OB retest logic) |
| London Close reversal | QM5_12539_ict-london-kz-cable-sweep (partial) |
| SMT divergence | tv-smc-mss-fvg, tv-ict-retest |
| Asian range / CBDR | tv-ict-sess-v3 |

**Concept tag coverage:** kill_zone, order_block, ote, fib_retracement, liquidity_sweep,
judas_swing, amd, session_structure, market_structure_shift, fvg — all populated in the
existing fidelity-initiative cards.

**Dedup verdict: The MMM notes are a derivative ICT teaching document. Core concepts are
saturated in the existing library. Proceed only to assess rule VARIANTS with meaningful
mechanical delta and any genuinely new combinatorial rules.**

---

## Section 1 — DUPLICATE (no new card warranted)

The following concepts appear verbatim or functionally equivalent in existing cards and
generate no new mechanical rules:

### 1.1 Kill Zones — DUPLICATE

MMM defines four kill zones identical to the ICT canonical times:
- Asian: 23:00–03:00 GMT
- London Open: 07:00–10:00 GMT
- London Close: 15:00–18:00 GMT
- NY Open: 12:00–15:00 GMT

**Covered by:** QM5_12535, QM5_12539, tv-ict-sess-v3.

No delta. DUPLICATE.

### 1.2 Order Block Definition and Entry — DUPLICATE

MMM bullish OB = last bearish candle before upward structural break; bearish OB = last
bullish candle before downward structural break. Entry = return to OB high (bull) or OB low
(bear). Stop = beyond OB extreme.

**Covered by:** QM5_12536_ict-ob-retest-idx, tv-smc-ob, tv-nq-ict-ob, QM5_10095_gh-ict-orderblk.

No delta. DUPLICATE.

### 1.3 OTE Fibonacci Retracement (0.62–0.79) — DUPLICATE

MMM table: 0.62, 0.705 (sweet spot), 0.79 as OTE zone. Entry between 62% and 79% of a
completed structural swing.

**Covered by:** QM5_12537_ict-ote-displacement-xau, tv-ict-ote, tv-xau-smc-0618.

No delta. DUPLICATE.

### 1.4 Judas Swing / Stop Hunt — DUPLICATE

MMM: engineered false move to raid stops at prior session highs/lows before true directional
leg. If trading London, look for Asian stops raided; if NY, look for London stops raided.

**Covered by:** QM5_12540_ict-amd-judas-xau, tv-smc-liqgrab.

No delta. DUPLICATE.

### 1.5 AMD / Accumulation-Manipulation-Distribution — DUPLICATE

MMM Power of Three section: open near 20% of day's range, Judas Swing (manipulation) in
opposite direction, then real expansion (distribution) to close near 80% of range.

**Covered by:** QM5_12540_ict-amd-judas-xau by design.

No delta. DUPLICATE.

### 1.6 ICT Buy and Sell Model (6-phase) — DUPLICATE

Consolidation → run to S/R → smart money reversal → accumulation → re-accumulation →
distribution. This is the structural narrative underlying QM5_12536 + QM5_12540.

No delta. DUPLICATE.

### 1.7 Asian Session Counter-Trend OTE — DUPLICATE

Asian session trades counter NY direction, rarely sees follow-through on new lows/highs,
provides OTE setups for London open continuation.

**Covered by:** tv-ict-sess-v3 (session OTE structure).

No delta. DUPLICATE.

---

## Section 2 — VARIANTS WITH MEANINGFUL DELTA

The following are not new concepts but contain quantified sub-rules not present in existing
card specifications. Each is assessed for mechanical completeness and card-worthiness.

### 2.1 Kill Zone + ADR Gate for London Close (VARIANT — NOTABLE)

**MMM rule (London Close Counter-Trend, pages 70–72):**

> "Reference the US Dollar Index and determine if it has met its 5-day Average Daily Range.
> Determine if the pair traded has met its 5-day ADR. As price drops/rises into the ADR level
> and Kill Zone, look at the 5-min lows/highs for a bounce. After the bounce, pull a Fib over
> the short-term swing and consider buying/selling at OTE on the 5-min chart. Risk 10 pips
> under/above the low/high used for the Fib. Ideally, better trades form on swings measuring
> at least 15%–20% of the daily range of the trading day."

**Delta vs. existing cards:**

QM5_12539_ict-london-kz-cable-sweep targets the London open kill zone sweep direction.
No existing card uses the ADR-exhaustion gate as a filter to flip to a counter-trend
London Close scalp. The specific quantification is:
- Filter: pair has met its 5-day ADR before 15:00 GMT
- Filter: DXY has also met its 5-day ADR (corroborating USD exhaustion)
- Entry: OTE (0.62–0.79) on 5-min swing at 15:00–18:00 GMT, counter to daily trend
- Stop: 10 pips beyond the swing extreme used to draw the Fib
- Target: 15–20 pips minimum (high of Fib swing for sells; low for buys)
- Minimum swing size: swing used for Fib must be at least 15%–20% of the day's range

**Mechanical completeness assessment:**

The entry, stop, and target are all quantified. The ADR gate is calculable (5-day average of
H-L). The "5-min low for bounce" requires a fractal/swing-low detector but is standard.
DXY as corroborating filter is a secondary symbol read. This is mechanically expressible.

**Applicable .DWX symbols:** EURUSD.DWX, GBPUSD.DWX (DXY correlation is strongest
for major USD pairs). NDX/XAU are less appropriate for DXY-gated reversal logic.

**Card recommendation: PROPOSE (new card) — ADR-gated London Close counter-trend
OTE scalp. Working title: `QM5_XXXX_ict-london-close-adr-ct`**

Rule completeness: HIGH. Novelty delta vs. existing library: MEANINGFUL (ADR gate +
counter-trend flip + 10-pip stop specification not present anywhere in the library).

---

### 2.2 10:00 GMT Judas + 12:20 NY Futures Open Entry (VARIANT — MARGINAL)

**MMM rule (Kill Zones, pages 44–45):**

> "10:00 GMT most of the time expect to see a Judas Swing or Divergence above/below the
> 07:00–09:00 GMT price. Mark the opening price of 10:00 GMT and most of the time this
> price will setup New York Optimal Trade Entry."

> "12:20 GMT is when futures contracts begin trading. For a buy trade you need to buy 10
> pips below the 12:20 price and for a sell trade you need to sell 10 pips above the 12:20
> price for New York trade."

**Delta vs. existing cards:**

The 12:20 entry anchor (10 pips offset from 12:20 open price) is a specific quantification
not captured in QM5_1233 (Silver Bullet runs 10:00–11:00 NY time = 15:00–16:00 GMT) or
QM5_12535 (killzone sweep). The 12:20 futures-open entry uses the opening price of the
12:20 candle as an absolute level anchor, not a Fib retracement.

**Mechanical completeness assessment:**

Entry is defined (10 pips below/above 12:20 open). Direction requires a higher-timeframe
bias input (not specified here). Stop and target are not quantified in the MMM notes. The
10:00 Judas observation is directional narrative — it does not produce an independent entry
rule without the OTE/Fib overlay already captured in existing cards.

**Card recommendation: NO CARD — insufficient to stand alone. The 12:20 entry offset
is a parameter-level detail that could be incorporated as a variant parameter into
QM5_12535 or the proposed `ict-london-close-adr-ct` card. The 10:00 Judas is
covered structurally in existing cards.**

---

### 2.3 Order Block Invalidation Threshold (50% Rule) — VARIANT — PARAMETER NOTE

**MMM rule (Order Blocks, page 30):**

> "If price retraces more than 50% of the order block then the order block will not be valid,
> look for a previous order block and project the same."

> "Third objective will be middle of the order block."

**Delta vs. existing cards:**

This is a precise OB invalidation rule: once price penetrates beyond the midpoint (50%) of
the OB candle's total range (Open-to-Close), the OB is voided and the trader cascades to the
previous OB. This is a parameter specification, not a new strategy. It would tighten the OB
retest entry logic in QM5_12536 (currently the card specifies entry at OB high/low retest
but does not codify the 50% invalidation depth).

**Card recommendation: NO NEW CARD — parameter update candidate for QM5_12536.
If that card's specification already has a stop at OB extreme, the 50% rule would move
the stop inside the OB (to the midpoint), which is a meaningful tightening. Flag for
QM5_12536 spec review.**

---

### 2.4 Crouching Outside Order Block (VARIANT — INCOMPLETE)

**MMM rule (page 38):**

> "This is one of the strongest setup for London open kill zone, New York Open Kill Zone or
> London Close reversal profile setup. When price is going to higher time frame Order block
> in the Kill zone time."

**Delta vs. existing cards:**

"Crouching outside OB" names a specific confluence: price approach to a higher-timeframe
OB coinciding with a kill zone window. This is a filter combination (HTF OB proximity AND
kill zone) not explicitly named in any existing card though functionally implied by
QM5_12536 + QM5_12535 used together.

**Mechanical completeness assessment:**

MMM provides only two sentences on this setup. No entry trigger, stop, or target is
specified. The setup name implies waiting for price to approach an OB from outside while
inside a kill zone window, but the exact trigger (does price need to touch OB? print a candle
pattern? show SMT divergence?) is not given.

**Card recommendation: NO CARD — mechanically incomplete. The confluence is valid
but the trigger specification is missing entirely. Cannot be built without discretion.**

---

### 2.5 London Buy / Sell Trade with Turtle Soup Entry Sequence (VARIANT — NOTABLE)

**MMM rule (Session Trading, pages 68–70):**

> "Turtle soup is initial fake out outside Asian range before the real Judas swing to the key
> support/resistance level. After turtle soup the Judas swing will begin and break Asian
> Session Hi/Lo to the key support/resistance. On the move to key support/resistance
> anticipate price to retest the broken Asian range."

> "Buy below 05:00–05:30 price, below opening price and below Asian Session Swing Low."
> "Sell above 05:00–05:30 price, above opening price and above Asian Session Swing High."

**Delta vs. existing cards:**

This is a two-phase liquidity sweep sequence: (1) turtle soup fakes out outside the Asian
range, then (2) the Judas swing breaks the Asian range in the same direction as the fake out
to hunt S/R beyond. Entry is the retest of the broken Asian range boundary after the Judas
completes. The 05:00–05:30 open price is used as a bias anchor (sell above it, buy below it).

This is mechanically distinguishable from QM5_12535_ict-killzone-sweep-idx in that:
- It requires a two-phase sequence: turtle soup fake-out FIRST, then sweep of Asian range
- Entry is specifically the retest of the broken Asian range boundary (not the OTE of the
  subsequent swing)
- The 05:00 price anchor is an explicit level, not a Fib

**Mechanical completeness assessment:**

Entry level: broken Asian range high/low (retest). Direction: defined by the Judas swing
direction. Bias confirmation: price above/below 05:00 open. Stop: below/above the Asian
range retest level (implied, not stated). Target: key S/R beyond (HTF OB, prev day H/L, etc.).
Time window: London Open kill zone (07:00–10:00 GMT).

This is substantially complete for a card proposal but requires a stop specification
(reasonable default: beyond the Asian range extreme used as entry level).

**Card recommendation: PROPOSE (new card) — London Open two-phase liquidity sweep
with turtle soup pre-condition and Asian range retest entry.**
Working title: `QM5_XXXX_ict-london-turtle-soup-sweep`

Applicable .DWX symbols: EURUSD.DWX, GBPUSD.DWX (major FX pairs with defined
Asian ranges; can extend to USDJPY.DWX, AUDUSD.DWX). XAU and NDX have Asian
sessions but the 05:00 anchor and Asian range concept is most natural in FX majors.

---

## Section 3 — NEW MECHANICAL RULES (not yet carded)

After full coverage assessment, the only rules in the MMM notes with genuine novelty delta
are the two proposals surfaced in Section 2. No fundamentally new ICT sub-system exists
in this document beyond what is already in the fidelity initiative cards and the broader SMC
library. The MMM notes are a teaching compilation, not a primary source with proprietary
rules.

**New card proposals from this mining pass:**

| # | Working title | Core rule | Symbols | Completeness |
|---|---|---|---|---|
| P1 | ict-london-close-adr-ct | ADR-exhaustion filter + counter-trend OTE scalp at London Close (15:00–18:00 GMT), 10-pip stop, 15–20 pip target | EURUSD.DWX, GBPUSD.DWX | HIGH |
| P2 | ict-london-turtle-soup-sweep | Two-phase London Open sweep: turtle soup fake-out then Asian range Judas; entry = Asian range retest; bias anchor = 05:00 open price | EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX | MEDIUM-HIGH (stop needs spec) |

---

## Section 4 — Parameter Notes for Existing Cards (no new card, flagged for spec review)

| Card | Finding | Action |
|---|---|---|
| QM5_12536_ict-ob-retest-idx | 50% OB midpoint = invalidation threshold (if price exceeds midpoint, cascade to prior OB). Currently not specified in card. | Update card spec with 50% invalidation rule and midpoint stop-raise logic |
| QM5_12535_ict-killzone-sweep-idx | 12:20 GMT futures-open price anchor (buy 10 pips below, sell 10 pips above) could be a secondary entry variant for NY session. | Consider as parameter note; not a standalone card |

---

## Section 5 — Source Quality Assessment (R1–R4)

**R1 — Track record:** Reginald Mmari is a retail educator compiling ICT material. ICT
(Michael Huddleston) is a widely known price-action educator; the underlying concepts have
substantial community documentation. However, neither Mmari nor ICT publishes audited
live performance records. R1 = PARTIAL (educator, not verified performance).

**R2 — Mechanical:** The core ICT concepts are described with sufficient rule specificity to
be mechanically expressed (kill zone times, OB definition, OTE Fib levels, stop placement
logic). Judgement is required for HTF bias, but the execution rules are quantified.
R2 = PASS on the subset of proposals above.

**R3 — Independence:** ICT material is one methodological school; the MMM notes are
doubly derivative (ICT → Mmari compilation). The proposals P1 and P2 combine known
ICT sub-rules in specific sequences not represented in the library. R3 = MARGINAL
(within-school, but delta is real).

**R4 — Reputable source:** ICT material is widely distributed retail education. Not a
peer-reviewed or institutional source. R4 = LOW (retail educator). Proposals proceed under
the understanding that Q02–Q08 pipeline must validate mechanically.

---

## Summary

**Total concepts reviewed:** 12 named mechanical concepts from 7 source sections.

**DUPLICATE (no action):** 7 — kill zones, OB definition, OTE, Judas Swing, AMD, ICT
Buy/Sell Model, Asian session OTE.

**VARIANT — no card, parameter note only:** 3 — 10:00/12:20 entry anchor (parameter
detail for existing card), 50% OB invalidation rule (spec update for QM5_12536), Crouching
Outside OB (mechanically incomplete, cannot card without discretion).

**NEW CARD PROPOSALS:** 2

- **P1 `ict-london-close-adr-ct`** — ADR-gated London Close counter-trend OTE scalp.
  Highest priority. Clean mechanical delta vs. existing library.
- **P2 `ict-london-turtle-soup-sweep`** — London Open two-phase Asian range sweep with
  turtle soup pre-condition. Meaningful sequence delta; stop spec needs one design
  decision before carding.

Both proposals target major FX pairs (.DWX universe). Neither requires ML or discretion.
Both operate inside defined kill zones. Pipeline viability depends on frequency — London
Close counter-trend scalps and London Open sweeps are daily-occurrence candidates on
major FX, expected 2–5 setups/week per pair minimum.
