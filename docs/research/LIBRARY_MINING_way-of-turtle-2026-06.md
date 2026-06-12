# Library Mining — Way of the Turtle (Faith, 2007)

**Mined:** 2026-06-12  
**Task:** 7143e208-5a5c-4c0a-a142-e168b25bedf7  
**Source file:** `C:/Users/Administrator/Downloads/Way of the Turtle - The Secret Methods that Turned Ordinary People into Legendary Traders 2007.pdf`  
**Extraction:** `D:/QM/strategy_farm/source_cache/way-of-the-turtle-2007.txt` (458,542 bytes, 312 pages)  
**Author:** Curtis M. Faith (one of the original Turtles, trained by Richard Dennis / William Eckhardt)

---

## Source Assessment (R1–R4)

**R1 — Track record:** Richard Dennis + William Eckhardt created the Turtle program. Curtis Faith was the most profitable Turtle trainee (reportedly +$31M for Dennis over 4 years). The rules are historically documented and have been extensively backtested by third parties. **PASS.**

**R2 — Mechanical:** The rules in the book are fully algorithmic — no discretionary elements except the fail-safe filter (see below). **PASS.**

**R3 — Data available:** Standard daily futures data. On our infrastructure: XAUUSD.DWX, NDX.DWX, WS30.DWX available on D1. **PASS** for index/commodity variants.

**R4 — No ML:** Fixed lookback rules, no optimization. **PASS.**

---

## Complete Turtle Rules (Canonical)

### System 1 — 20-Day Breakout

| Parameter | Value |
|-----------|-------|
| Entry | New 20-day high (long) / new 20-day low (short) |
| Exit | 10-day opposing breakout (long exits on 10-day low; short exits on 10-day high) |
| Stop | 2N below entry (where N = ATR(20) using Wilder smoothing, alpha = 1/20) |
| Pyramid | Add 1 unit every 1/2N price movement in profitable direction |
| Max units | 4 per single market |
| Fail-Safe | **Skip this entry** if the previous System 1 signal for this market was a winning trade |

**Fail-Safe Rule detail:** A System 1 breakout is skipped if the *preceding* System 1 signal on the same market would have been stopped out at a loss of less than 2N before the 10-day exit triggered (i.e., the preceding signal was profitable). This filter addresses whipsaw by forcing patience after winners.

### System 2 — 55-Day Breakout

| Parameter | Value |
|-----------|-------|
| Entry | New 55-day high (long) / new 55-day low (short) |
| Exit | 20-day opposing breakout |
| Stop | 2N below entry |
| Pyramid | Same as System 1 (add 1 unit per 1/2N) |
| Max units | 4 per single market |
| Fail-Safe | **None** — all System 2 breakouts are traded without exception |

### N (Volatility Unit) Calculation

`N = ATR(20)` using **Wilder smoothing** (alpha = 1/20, not standard EMA 2/21):

```
N_today = (19/20) * N_yesterday + (1/20) * TrueRange_today
```

Unit size: `1 Unit = Account × Account_Risk_Pct / (N × Dollar_Per_Point)`

### Position Sizing Limits (Portfolio-Level Risk Caps)

| Level | Limit |
|-------|-------|
| Single market | 4 units maximum |
| Closely correlated markets (e.g., EUR/USD + GBP/USD) | 6 units total across the group |
| Loosely correlated markets (e.g., gold + silver) | 10 units total |
| Single direction (all longs or all shorts combined) | 12 units maximum |

### Stop Adjustment on Pyramid

When adding a pyramid unit, raise the stop on all existing units so the total portfolio risk does not exceed 2N per unit:
- After adding unit 2: move all stops to 2N below unit 2 entry (equivalent to 1.5N below unit 1 entry)
- After adding unit 3: move stops to 2N below unit 3 entry
- After adding unit 4: move stops to 2N below unit 4 entry

---

## Existing Card Coverage

Searching `cards_approved/`:

| Pattern | Count | Notes |
|---------|-------|-------|
| `*turtle*` | 8 | See list below |
| `turtle.*55\|55.*day` | 0 | System 2 = not carded |
| `fail.safe\|failsafe` | 0 | Fail-Safe Rule = not carded |

**Existing 8 turtle cards:**
- `QM5_10210_tv-turtle-ny-sweep.md` — TradingView NY liquidity sweep (ICT-inspired, uses "turtle soup" name)
- `QM5_10272_ltz-turtle20.md` — 20-day breakout (System 1 core)
- `QM5_10346_et-turtle-intra.md` — Intraday turtle adaptation
- `QM5_10403_et-turtle20x.md` — System 1 variant
- `QM5_11781_turtle-trading-20day-breakout-d1.md` — Canonical System 1 (D1)
- `QM5_11879_turtle-20day-breakout.md` — System 1 variant
- `QM5_12488_myh-turtle60.md` — 60-day breakout (similar to System 2 but uses **60** not **55**)
- `QM5_6004_macro-turtle-system.md` — Macro-timeframe variant

**QM5_12488 note:** The "turtle60" card uses a 60-day lookback (not the canonical 55). This is likely a variant derived from independent research, not the Faith/Dennis System 2. The canonical System 2 (55-day entry / 20-day exit) is NOT carded.

**Position sizing limits (4/6/10/12 rule):** Not present in any card. These are portfolio-level rules, not individual strategy rules, so they would be documented in a portfolio construction policy, not a strategy card.

---

## Dedup Verdicts

| Item | Verdict | Notes |
|------|---------|-------|
| System 1 (20-day breakout, 10-day exit) | DUPLICATE | Carded as QM5_10272, QM5_11781, QM5_11879 |
| System 2 (55-day breakout, 20-day exit) | NEW | QM5_12488 uses 60-day, not 55; no existing 55-day card |
| Fail-Safe Rule for System 1 | NEW | 0 existing fail-safe cards; no existing card mentions this filter |
| N-unit position sizing (ATR Wilder, 1/2N pyramid) | VARIANT | Wilder ATR carded as QM5_11412; pyramid rule not explicit in any existing card |
| Correlated group limits (4/6/10/12) | SKIP (portfolio rule) | Belongs in Q11 portfolio construction layer, not a strategy card |

---

## Card Proposals

### Proposal 1: `turtle-system2-55day-breakout-d1` (NEW)

**Dedup verdict:** NEW — QM5_12488 uses 60-day; no canonical 55/20 card exists.

```yaml
slug: turtle-system2-55day-breakout-d1
source: "Faith, C. (2007). Way of the Turtle. McGraw-Hill."
source_citation: "Faith (2007), Chapter 5 — The Complete Turtle Rules, pp. 85–107"
edge_type: trend
period: D1
target_symbols: [XAUUSD.DWX, NDX.DWX, WS30.DWX, EURUSD.DWX, GBPUSD.DWX]
expected_trades_per_year_per_symbol: 8
```

**Entry rules:**
- Long: Close above the 55-bar rolling maximum (all 55 periods must be full daily bars)
- Short: Close below the 55-bar rolling minimum
- Entry: Next bar open (stop order breakout style, or limit at new high/low)

**Exit rules:**
- Long exit: Close below 20-bar rolling minimum
- Short exit: Close above 20-bar rolling maximum

**Stop:** 2 × ATR(20, Wilder smooth) below/above entry bar close

**Pyramid:** Add one unit per 0.5 ATR(20) of favorable movement; max 4 units per market

**Notes for builder:**
- Wilder ATR: `N_today = (19/20)*N_prev + (1/20)*TR_today` (NOT standard EMA)
- System 2 has NO fail-safe filter — trade all valid breakouts
- The 55-day lookback will generate ~8–15 trades/year on major FX/index pairs — sufficient for Q08 swing track

---

### Proposal 2: `turtle-system1-failsafe-filter-d1` (NEW)

**Dedup verdict:** NEW — the fail-safe rule is not present in any existing turtle card. It is an important risk-control element of System 1 that substantially changes its behavior vs. a naive 20-day breakout.

```yaml
slug: turtle-system1-failsafe-filter-d1
source: "Faith, C. (2007). Way of the Turtle. McGraw-Hill."
source_citation: "Faith (2007), Chapter 5 — The Complete Turtle Rules, p. 94"
edge_type: trend
period: D1
target_symbols: [XAUUSD.DWX, NDX.DWX, WS30.DWX, EURUSD.DWX, GBPUSD.DWX]
expected_trades_per_year_per_symbol: 6
```

**Entry rules (System 1 + Fail-Safe):**
- Prerequisite: identical to System 1 (20-day high/low breakout, 10-day exit, 2N stop)
- **Fail-Safe gate:** Before entering, check if the immediately preceding System 1 signal on this market was a winning trade. If the previous signal exited profitably (price never hit the 2N stop before the 10-day exit triggered), **skip this signal**.
- If the previous signal was a loser (stopped out at −2N), the next signal is taken normally.

**Mechanical implementation note:** Requires persistent state tracking of the prior trade outcome per symbol. Implement as an `ea_last_trade_result[symbol]` variable updated on every trade close.

**Notes for builder:**
- This card is specifically the System 1 + Fail-Safe variant; document it alongside QM5_11781 (System 1 without fail-safe) as a controlled pair
- The fail-safe materially reduces trade count (approx. 30–40% reduction) but improves win rate on the trades taken

---

## Recommendation

Both proposals are buildable against `D1` timeframe on existing factory infrastructure. System 2 (55-day) is higher priority — it's a canonical standalone system with a clean 55/20 parameter set and no state-tracking complexity. The fail-safe filter card is lower priority but worth building as a controlled companion to the existing System 1 cards.

Priority: System 2 card first → Fail-Safe filter card second.
