# Library Mining: Way of the Turtle (2007)
**Slug:** turtle-way-2007  
**Date:** 2026-06-12  
**Miner:** Claude (claude-sonnet-4-6)  
**File:** `C:/Users/Administrator/Downloads/Way of the Turtle - The Secret Methods that Turned Ordinary People into Legendary Traders 2007.pdf`  
**Author:** Curtis M. Faith, McGraw-Hill 2007  
**Exclusion check:** USABLE — appears in USABLE section of `downloads_library_triage_2026-06-12.txt` (line 333)  
**PDF quality:** 313 pages, 442,855 chars extracted. Text-based PDF, fully readable.  
**Source cache:** `D:/QM/strategy_farm/source_cache/turtle_extracted.txt`

---

## DEDUP VERDICT — MANDATORY STEP 0

Searched `D:/QM/strategy_farm/artifacts/cards_approved/` (2,693 cards) for:
- Keywords: `turtle`, `donchian`, `breakout-20`, `breakout-55`, `trend-follow`, `raschke`, `channel-breakout`

**Results:**
- `QM5_11781_turtle-trading-20day-breakout-d1.md` — Turtle System 1 (20-day), sourced from anonymous retail PDF
- `QM5_11879_turtle-20day-breakout.md` — 20-day breakout, R1 FAIL (no source_id)
- `QM5_1236_gh-donchian-55.md` — 55-day breakout sourced from GitHub (no Turtle attribution), no pyramiding
- `QM5_6004_macro-turtle-system.md` — R1 FAIL, no source_id
- `QM5_9911_bandy-donchian-20-classic-breakout-trend.md` — Bandy-sourced Donchian 20
- `QM5_9986_tv-donchian20-breakout-flip.md` — TradingView-sourced Donchian 20
- `QM5_10346_et-turtle-intra.md`, `QM5_10403_et-turtle20x.md` — unnamed turtle variants

**Key finding:**
- No existing card implements the **complete Turtle System** with: (a) Faith/Dennis/Eckhardt 1978-era primary-source attribution via *Way of the Turtle* (ISBN 0-07-148664-X); (b) proper ATR/N-based position sizing; (c) pyramiding at 1/2N intervals; (d) trailing stops adjusted as units add; (e) skip-losing-breakout rule (System 1 only).
- QM5_11781 and QM5_1236 are simplified versions without pyramiding, without skip-rule, and without primary-source attribution.
- The **55-day breakout with pyramiding** (System 2 complete) has NO proper-attribution card.

| Turtle Component | Existing Cards | Status |
|---|---|---|
| System 1 (20-day, no pyramid) | QM5_11781, QM5_11879, QM5_9911 | PARTIAL (missing pyramid, N-sizing) |
| System 2 (55-day, complete) | QM5_1236 (no pyramid, GitHub source) | VARIANT (delta: pyramid + N-sizing + primary source) |
| Complete System with pyramid | None | NEW |
| N/ATR position sizing (unit = 1% of account) | None explicit in turtle context | NEW |
| Raschke Holy Grail | QM5_1329 (H1, ADX pullback) | DUPLICATE |

---

## Turtle System Rules Extracted

From `turtle_extracted.txt` pages 251–295 (Appendix A: Original Turtle Trading System Rules):

### Core Definitions

**N (Average True Range — Wilder-smoothed over 20 days):**
```
N = (19 × PDN + TR) / 20
where:
  TR = max(High − Low, |High − PrevClose|, |PrevClose − Low|)
  PDN = prior day's N
  Initial N = simple 20-day average of TR
```

**Dollar Volatility:** N × contract size (for FX: N × 100,000 × price for base currency value)

**Unit Size:** Units sized so that 1N = 1% of account equity.
```
Unit Size = (Account × 0.01) / (N × Dollar_per_pip × pip_size)
```

### System 1 — 20-Day Breakout

**Entry:**
- LONG: Price exceeds the **20-day high by 1 tick** → BUY 1 unit at market.
- SHORT: Price drops below the **20-day low by 1 tick** → SELL 1 unit at market.
- **SKIP RULE (System 1 only):** If the last breakout signal (in that instrument, regardless of direction) would have resulted in a profitable trade, SKIP the current breakout. Take it only if the last breakout was a losing trade. (A losing breakout = price moved 2N against the position before a 10-day-exit occurred.)

**Pyramiding (Add Units):**
- Add 1 unit for every **1/2N** of favorable price movement from the prior fill.
- Maximum: **4 units total** per instrument.
- When adding a unit, raise all previous stops to **2N below the newest unit's entry price** (net effect: all stops converge to 2N below most-recent entry).

**Stops:**
- Initial stop: **2N below** entry for longs; **2N above** entry for shorts.
- On adding each new unit: prior units' stops raised by 1/2N (all stops converge to 2N from newest unit).
- Alternative (Whipsaw): 1/2N stop per unit; re-enter at original breakout price if stopped out.

**Exit:**
- LONG: **10-day low** (close position if price drops to/below 10-day low).
- SHORT: **10-day high** (close if price rises to/above 10-day high).
- All units exit simultaneously on the exit signal.

**Expected trades per year per symbol (System 1):** 4–6 entry signals; with skip rule, actual trades ~3–4/year. Estimate: **5/year/symbol** for DWX FX on D1.

### System 2 — 55-Day Breakout

**Entry:**
- LONG: Price exceeds the **55-day high by 1 tick** → BUY 1 unit.
- SHORT: Price drops below the **55-day low by 1 tick** → SELL 1 unit.
- **NO skip rule.** All breakouts taken regardless of last breakout outcome.

**Pyramiding (identical to System 1):**
- Add 1 unit per 1/2N of favorable movement.
- Maximum 4 units.
- Stop adjustment: same as System 1.

**Stops:** Same as System 1 (2N initial; converge on pyramid adds).

**Exit:**
- LONG: **20-day low.**
- SHORT: **20-day high.**

**Expected trades per year per symbol (System 2):** ~2–4 genuine breakouts/year on D1. Estimate: **3/year/symbol** on DWX FX. LOW frequency — qualifies for Q08 swing/low-freq track (DL-070).

### Position Limits
- Maximum 4 units per instrument.
- Maximum 6 units in correlated instruments.
- Maximum 10 units in one direction (long or short) total.

### DWX Symbol Mapping
Turtle traded FX via CME futures (Swiss franc, Deutschmark, British pound, Japanese yen, Canadian dollar). DWX equivalents:

| Original Turtle Market | DWX Symbol |
|---|---|
| British pound (CME) | GBPUSD.DWX |
| Japanese yen (CME) | USDJPY.DWX |
| Swiss franc (CME) | USDCHF.DWX |
| Canadian dollar (CME) | USDCAD.DWX |
| Gold (COMEX) | XAUUSD.DWX |
| Crude oil (NYMEX) | XTIUSD.DWX |
| S&P 500 (CME) | WS30.DWX or NDX.DWX (proxy; SP500.DWX backtest-only) |

---

## NEW PROPOSALS

### Proposal 1: Turtle System 1 — Primary Source with Pyramid + N-Sizing (D1)

**Dedup verdict: VARIANT** — Delta from existing QM5_11781: (a) **primary source** Curtis Faith *Way of the Turtle* (ISBN 0-07-148664-X, McGraw-Hill 2007) instead of anonymous PDF; (b) **ATR/N-based unit sizing** (1N = 1% equity) instead of fixed lot; (c) **pyramiding** at 1/2N intervals up to 4 units; (d) **skip-losing-breakout rule**; (e) trailing stop adjustment on pyramid adds. These are mechanically distinct enhancements, not just a new source citation.

**Mechanism:** As documented in "System 1 — 20-Day Breakout" section above.

**R1–R4:**
| Criterion | Status | Reasoning |
|---|---|---|
| R1 Track Record | PASS | Curtis M. Faith, named author, first Turtle class; Dennis/Eckhardt underlying system well-documented; ISBN 0-07-148664-X |
| R2 Mechanical | PASS | 20-day HHV/LLV, 1-tick breakout, N calculation (Wilder-smooth ATR), unit sizing formula, 1/2N pyramid intervals, 2N stop, 10-day channel exit, skip-rule — all deterministic arithmetic |
| R3 Data Available | PASS | D1 DWX FX + XAUUSD + XTIUSD available; 20-day and 10-day channels OHLC-only |
| R4 No ML | PASS | Fixed periods; no ML; one directional position per instrument |

**Expected trades/year/symbol:** 5 (System 1 skip-rule suppresses some signals)  
**Slug:** `turtle-s1-pyramid-d1`  
**Period:** D1  
**Symbols:** GBPUSD.DWX, USDJPY.DWX, USDCHF.DWX, USDCAD.DWX, XAUUSD.DWX, XTIUSD.DWX

**Notes for Codex (P1):**
- Track `last_breakout_direction` and `last_breakout_was_profitable` per instrument in a persistent state variable.
- N computation: initialize with `iATR(NULL, PERIOD_D1, 20, i)` (MT5 native Wilder-smooth); or manually compute Wilder-smooth.
- Unit = `(Account * 0.01) / (N * tick_value_per_pip * pips_per_point)`.
- Skip rule: maintain a running "last-breakout outcome" flag updated when the 10-day exit is hit — if last exit was profitable, skip next same-symbol breakout.
- Pyramid state: track unit count and entry prices; MT5 requires managing multiple positions under one magic or using a position-augment approach.
- P3 sweeps: entry period (15/20/25), exit period (8/10/12), N multiple for stop (1.5/2.0/2.5).

**Regime note:** Low-frequency system (~5 trades/year/symbol). Will qualify for Q08 swing/low-freq track per DL-070 (floor reduced from 100 to 40 trades/year; ~5 trades/year requires only 8.9 CAGR/MaxDD floor per DL-070). OWNER confirmed ~10 trades/year sufficient for swing EAs.

---

### Proposal 2: Turtle System 2 — 55-Day Breakout with Full Pyramid (D1)

**Dedup verdict: VARIANT** — Delta from QM5_1236 (gh-donchian-55): (a) primary source Faith 2007 vs. anonymous GitHub; (b) **pyramiding** with N-based unit sizing vs. fixed lot without pyramid; (c) **20-day channel exit** (not 20-day failure exit); (d) **no skip rule**; (e) 2N trailing stops with pyramid adjustment. Mechanically distinct in the pyramid + N-sizing + stop-adjustment combination.

**Mechanism:** As documented in "System 2 — 55-Day Breakout" section above.

**R1–R4:**
| Criterion | Status | Reasoning |
|---|---|---|
| R1 Track Record | PASS | Curtis M. Faith, *Way of the Turtle*, McGraw-Hill 2007, ISBN 0-07-148664-X |
| R2 Mechanical | PASS | 55-day HHV/LLV, N-based unit sizing, 1/2N pyramid at up to 4 units, 2N initial stop with pyramid convergence, 20-day channel exit — all arithmetic |
| R3 Data Available | PASS | D1 DWX FX + XAUUSD available; 55-day lookback requires ~3 months of data (available) |
| R4 No ML | PASS | Fixed periods; no ML; always-long-or-short design |

**Expected trades/year/symbol:** 3 (very low frequency)  
**Slug:** `turtle-s2-pyramid-d1`  
**Period:** D1  
**Symbols:** GBPUSD.DWX, USDJPY.DWX, USDCHF.DWX, USDCAD.DWX, XAUUSD.DWX

**Notes for Codex (P1):** Same architecture as System 1 without skip rule; 55-day lookback for entry, 20-day for exit.

**Regime note:** 3 trades/year/symbol — qualifies for swing track DL-070. Expected to fail absolute trade-count floors unless applied to all 5 symbols simultaneously (15 total trades/year on a 5-symbol basket).

---

## Summary

| Category | Count |
|---|---|
| Systems found in book | 3 (System 1, System 2, Whipsaw variant) |
| DUPLICATE | 0 (no exact primary-source + pyramid match) |
| VARIANT proposals | 2 (System 1 + System 2, both with primary source + pyramid) |
| NEW proposals | 0 |

**Primary delta from existing cards:** ATR/N-based position sizing + pyramiding at 1/2N intervals + stop adjustment on pyramid adds + primary-source attribution. All three properties are missing from QM5_11781/1236/9911.

**Recommended slugs:**
- VARIANT: `turtle-s1-pyramid-d1` (vs. QM5_11781)
- VARIANT: `turtle-s2-pyramid-d1` (vs. QM5_1236)
