# Library Mining: Short-Term Trading Strategies That Work (Connors & Alvarez, 2009)

**Source file**: `C:/Users/Administrator/Downloads/100324184-Short-Term-Trading-Strategies-That-Work-by-Larry-Connors-and-Cesar-Alvarez.pdf`
**Text cache**: `D:/QM/strategy_farm/source_cache/connors-short-term-full.txt` (11,021 bytes)
**PDF note**: Extraction yielded only the slide-deck/summary portion (61 pages, slide format).
  The full text of the chapters is embedded in a format not extractable by pypdf. The slide deck
  DOES contain all 16 strategy rule summaries (verified below) which are sufficient for
  card proposals per the extraction_standard.
**Mined by**: Claude orchestration cycle 2026-06-12
**Dedup gate**: STEP 0 applied per strategy (2,688 approved cards searched)
**Book description**: 16 quantified short-term trading strategies for stocks and ETFs, primarily
  US equity indices (SPY/SPX) backtested 1995–2007. Larry Connors & Cesar Alvarez.
  Framework: buy oversold conditions within long-term uptrends; mean-revert to 5-day MA.

---

## STRATEGY-BY-STRATEGY DEDUP AUDIT

### Strategy 1: Buy Pullbacks Not Breakouts
3-down-days-in-a-row entry rule. SPY above 200MA, buy when market has dropped 3 consecutive days.
**DEDUP**: DUPLICATE. Covered by connors family cards (QM5_11365, QM5_11497 etc. — RSI-2/3-day
pullback family). Multiple variants already carded.

### Strategy 2: Buy After Multiple Down Days
Same mechanism as #1. Empirical data: 3+ consecutive down days → outperforms 5-day average gain.
**DEDUP**: DUPLICATE. See connors-rsi2-sma200-pullback cards.

### Strategy 3: Buy Stocks Above 200-Day MA
Filter rule, not a standalone strategy. All Connors cards already apply this filter.
**DEDUP**: N/A (filter component, not a strategy).

### Strategy 4: Use VIX to Your Advantage (VIX 5% Rule)
SPY above 200-day SMA + VIX > 5% above 10-day SMA → buy close. Exit when VIX < 5% below 10-day SMA.
**DEDUP**: DUPLICATE. QM5_1492_connors-vix-spike-reversal-h4 covers this strategy with ATR-stretch
port (VIX unavailable on DWX). VIX-stretch variants also covered by QM5_11130, QM5_1177.

### Strategy 5: Stops Hurt
Risk management guideline — tighter stops = less profit. ATR-based position sizing preferred.
**DEDUP**: N/A (not a trading strategy).

### Strategy 6: It Pays To Hold Positions Overnight
Empirical finding: buying SPY at open and selling at close = -70.88 pts; buying close/selling next open = +171.40 pts (test period 1993-2007). Open-to-close day trades lose.
**DEDUP**: N/A (execution principle baked into all D1 cards).

### Strategy 7: Buy on Intraday Pullbacks
Intraday momentum to the upside → worse 5-day performance; intraday selloff → better.
Specifically: buy on intraday pullbacks to improve entries.
**DEDUP**: N/A (refinement principle, not standalone). Covered by limit-entry concepts.

### Strategy 8: The 2-Period RSI (RSI-2)
SPY above 200-day SMA + RSI(2) below 10 (or 5) → buy close. Exit when RSI(2) > 65.
**DEDUP**: DUPLICATE. QM5_1235_connors-rsi2, QM5_11365_connors-rsi2-sma200-pullback-d1,
QM5_11427_connors-rsi2-sma200-pullback-d1 etc. Extensive coverage across D1/H4.

### Strategy 9: RSI-2 Below 5
Specific version of Strategy 8 with stricter RSI-2 < 5 threshold.
**DEDUP**: DUPLICATE. Covered in connors-rsi2 card family (various thresholds tested).

### Strategy 10: Cumulative RSI
Sum of last 2 days RSI(2) < 45 → buy close. Exit when RSI(2) > 65.
**DEDUP**: DUPLICATE. QM5_11498_connors-alvarez-cumulative-rsi2-sma200-d1 explicitly covers this.

### Strategy 11: Double 7's
SPY above 200-day MA + close at 7-day low → buy. Exit at 7-day high.
**DEDUP**: DUPLICATE. QM5_11366_connors-double7s-sma200-d1, QM5_11497, QM5_11564, QM5_1242 etc.

### Strategy 12: Market Timing with TRIN/VIX/RSI-2 (Five Strategies)

**12a. VIX Stretches**: SPY above 200MA + VIX > 5% above 10-day MA for 3+ days → buy close
  → exit when RSI(2) > 65.
  DEDUP: DUPLICATE of QM5_1492 (ATR-stretch port of exact same mechanism).

**12b. VIX RSI**: SPY above 200MA + RSI(2) of VIX > 90 + today VIX open > yesterday close
  + RSI(2) of SPY < 30 → buy close → exit RSI(2) > 65.
  DEDUP: VARIANT of QM5_1492 (additional VIX RSI filter + VIX-open gate). Gap: the VIX RSI
  version has additional filters not captured in the ATR-stretch card. HOWEVER: VIX RSI(2) is
  not available on .DWX; the ATR-based port makes the additional filter untranslatable without
  a custom data feed. FLAG for OWNER: if VIX feed added to DWX, this becomes NEW.
  Current verdict: **SKIP** (untranslatable additional filter).

**12c. TRIN**: SPY above 200MA + RSI(2) < 50 + TRIN > 1.00 for 3 days → buy close
  → exit RSI(2) > 65.
  DEDUP: DUPLICATE. QM5_10061_connors-trin3-d1 covers exactly this mechanism.

**12d. Cumulative RSI (overlap)**: Already covered in Strategy 10. DUPLICATE.

**12e. S&P Short**: SPY BELOW 200-day MA + market closes up 4 or more consecutive days
  → sell short at close → cover when SPY closes below 5-period MA.
  DEDUP: **NEW** — No connors short/bear cards exist (0 matches). This is the only short-side
  Connors strategy in the book. **See Proposal 1 below.**

### Strategy 13: End of Month Strategy
For stocks above 200-day MA, buy on calendar days 25, 24, 1, 27, 26, 29, 28 (best days in order
of performance); sell 3–5 trading days later. Effect is amplified when stock has dropped 1–2
consecutive days before the buy date.
**DEDUP**: VARIANT. Two month-turn cards exist:
- QM5_10763_fx-month-end-rebal (FX month-end rebalancing — different mechanism: FX flows)
- QM5_10892_el-d3-t11-month-end-rev (edge lab month-end reversal)
Neither targets US equity calendar-day anomaly specifically. The Connors EOM targets SPY/US
equity indices on specific calendar dates 24/25/26/27 — distinct from FX rebalancing flows.
**See Proposal 2 below.**

### Strategy 14: Exit Strategies
Best exits: 5-day MA, RSI-2 > 65/70/75. Dynamic exits beat fixed time exits.
**DEDUP**: N/A (exit guidance, not a standalone entry strategy).

### Strategy 15–16: Psychology / Summary
Not a trading strategy.

---

## PROPOSALS

---

### PROPOSAL 1: Connors S&P Short (SPY Below 200MA + 4 Up Days → Short) D1

**Dedup verdict**: NEW

Search "connors short", "connors bear", short-side SPY strategies → 0 matches.
The entire Connors card family (31 connors-named cards) is long-only on US indices. This is the
only explicit short-side Connors strategy in the book.

**Source evidence**:
- Connors & Alvarez (2009) "Short Term Trading Strategies That Work", TradingMarkets Publishing,
  Ch. 12 "Five Strategies to Time the Market" (S&P Short variant) + Connors Research notes.
- Rule (from slide deck, p.26): SPY BELOW 200-day MA + market closes up 4 or more consecutive
  days → sell short at close → cover when SPY closes below 5-period MA.
- Test period 1995–2007. Connors's finding: when SPY is below its 200MA (bearish regime), 4+
  consecutive up closes are unsustainable mean-reversion shorting opportunities.
- This is the mirror logic of the long strategies: in downtrend, excessive strength = short.

**R1-R4 pre-assessment**:
- R1 PASS: Connors & Alvarez (2009), named author, ISBN 978-0-9819239-0-1
- R2 PASS: Deterministic: 200MA regime filter + consecutive-close counter + 5-period MA exit
- R3 PASS: NDX.DWX, WS30.DWX (indices in bear regimes) — map SPY's 200MA filter to index MA
- R4 PASS: fixed MA periods, binary close-count rule, no ML

**Instruments**: NDX.DWX, WS30.DWX, SP500.DWX (backtest-only), GDAXI.DWX
**Timeframe**: D1
**Expected trades/yr/symbol**: ~6–10 (bear-regime condition + 4+ up days is moderately rare)
**Q08 risk**: Low frequency; may hit swing-track threshold. Directionally SHORT — diversification
  value if long strategies dominate the portfolio.
**Proposed slug**: `connors-sp-short-4updays-200ma-d1`

**Entry (short)**:
1. Regime: D1 close < SMA(200) [bearish regime required]
2. Signal: 4 or more consecutive D1 up closes (close[t] > close[t-1] for 4 bars)
3. Order: market sell at close of bar t
4. Exit: cover when D1 close < SMA(5); OR 10-bar time exit

**Stop Loss**: Entry + 2.0×ATR(14) (Connors did not specify a stop; ATR-based stop added for
DXZ risk management compliance)

**Honest caveat**: Connors's test period 1995–2007 included the dot-com crash and GFC early
stages. The bear-regime + 4-up-days short has not been independently verified on FX CFDs.
Frequency is low (~8 trades/yr/symbol), which may conflict with Q08 floor.

---

### PROPOSAL 2: Connors End-of-Month Equity Calendar Effect D1

**Dedup verdict**: VARIANT

Search month-end/calendar → QM5_10763 (FX month-end rebalancing) and QM5_10892 (edge-lab
month-end reversal). Both are FX-specific. The Connors mechanism targets US equity indices
(SPY, NDX) on SPECIFIC CALENDAR DAYS (24,25,26,27), not FX. The underlying mechanism differs:
Connors's EOM effect is driven by end-of-month portfolio rebalancing into US equities (401k/pension
inflows), not the FX month-end spot-rate adjustment flows. Delta is justified: US equity calendar
days 24/25/26/27 vs FX spot rebalancing flows are different phenomena.

**Source evidence**:
- Connors & Alvarez (2009) Ch.13 "End of Month Strategy" (slide deck pp.19–20)
- Rule: for indices/ETFs above 200-day MA, gain is highest on calendar days 25, 24, 1, 27, 26,
  29, 28 (in order of magnitude); losses concentrated on days 3–8.
- Enhanced version: if index dropped previous day, best days are 25, 30, 27, 26, 24, 28, 29.
- If dropped 2+ consecutive days, best days: 25, 26, 24, 27, 30, 28, 29, 23, 1, 22.
- Test: buy at close of eligible calendar day, sell at open 3 trading days later.
- Test period 1995–2007 on US equities; statistical significance for calendar-day clustering.

**R1-R4 pre-assessment**:
- R1 PASS: Connors & Alvarez (2009), explicit backtested calendar data
- R2 PASS: Deterministic date-gate + 200MA regime filter + 3-day time exit
- R3 PASS: NDX.DWX, WS30.DWX (US equity-adjacent indices with correlated EOM inflows)
- R4 PASS: fixed MA period, fixed calendar day set, no ML

**Instruments**: NDX.DWX, WS30.DWX (US equity indices most likely to share inflow effect)
**Timeframe**: D1
**Expected trades/yr/symbol**: ~24 (12 months × ~2 eligible days/month, filtered by 200MA)
**Proposed slug**: `connors-end-of-month-equity-d1`

**Entry (long)**:
1. Regime: D1 close > SMA(200)
2. Date gate: today is calendar day 24, 25, 26, or 27
   Enhanced: if yesterday close < close[t-2] (down day), also include day 30
   Enhanced2: if 2+ consecutive down closes, also include day 1
3. Order: buy at close of eligible date
4. Exit: close at open 3 trading days after entry (time exit)
5. Stop: entry - 1.5×ATR(14) (Connors's strategy had no explicit stop; added for risk compliance)

**Honest caveat**: EOM calendar effects may have decayed since 2007. 401k/pension inflow
patterns have changed (ETF proliferation, algorithmic trading). NDX/WS30 on DWX share the
US-equity EOM inflow dynamic but are not SPY exactly. Pipeline is the judge.

---

## SUMMARY TABLE

| # | Strategy | Dedup | Verdict |
|---|----------|-------|---------|
| 1 | Buy pullbacks (3-down) | DUPLICATE (connors RSI-2 family) | Skip |
| 2 | Buy after multiple down days | DUPLICATE | Skip |
| 3 | Above 200MA filter | N/A | Skip |
| 4 | VIX 5% rule | DUPLICATE (QM5_1492) | Skip |
| 5 | Stops hurt | N/A | Skip |
| 6 | Overnight hold | N/A | Skip |
| 7 | Intraday pullbacks | N/A | Skip |
| 8 | RSI-2 <10 | DUPLICATE (multiple cards) | Skip |
| 9 | RSI-2 <5 | DUPLICATE | Skip |
| 10 | Cumulative RSI | DUPLICATE (QM5_11498) | Skip |
| 11 | Double 7's | DUPLICATE (multiple cards) | Skip |
| 12a | VIX Stretches | DUPLICATE (QM5_1492) | Skip |
| 12b | VIX RSI | SKIP (VIX RSI untranslatable to .DWX) | Skip |
| 12c | TRIN 3-day | DUPLICATE (QM5_10061) | Skip |
| 12d | Cumulative RSI (repeat) | DUPLICATE | Skip |
| **12e** | **S&P Short 4-up-days** | **NEW** | **→ CARD** |
| **13** | **End of Month Calendar** | **VARIANT** | **→ CARD** |
| 14 | Exit strategies | N/A | Skip |
| 15–16 | Psychology | N/A | Skip |

**Total new proposals**: 2

---

*Claude G0 review pending. Cards not created until G0 approve-card command issued.*
