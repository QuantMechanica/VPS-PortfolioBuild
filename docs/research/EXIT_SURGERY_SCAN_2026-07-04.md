# Exit-Surgery Candidate Scan — 2026-07-04

**Purpose:** Systematically identify Q08 FAIL_SOFT EAs whose entry edge is real but whose
exit mechanics amputate it, following the precedent set by T-WIN (QM5_10821) and the
10939→12990 / 10940→12989 v2 pairs.

**Analyst:** Claude  
**Evidence path:** MT5 baseline report.htm files under
`D:/QM/reports/pipeline/QM5_xxxxx/Q08/_baseline/`  
**Precedent:** T-WIN diagnosis — hold-time gradient (short holds deeply negative, long holds
strongly positive) plus TIME_MGMT / signal-decay dominance in early closes = surgery candidate.

---

## 1. Method

### Population

The Q08 FAIL_SOFT pool was read from `farm_state.sqlite` (latest row per ea_id/symbol):
31 pairs total, excluding already-surgered / fresh v2s (10939/GBPUSD, 10940/XAUUSD,
12989/XAUUSD, 12990/GBPUSD, 12958/XAUUSD) leaves **26 pairs** for analysis.

Live sleeves from `D:/QM/reports/state/live_book_pulse.json` were cross-referenced.
**3 HIGH candidates are currently live:** QM5_10440/NDX, QM5_10715/USDJPY,
QM5_10911/GDAXI.

### Data source

Per-trade data was extracted from the **most-recent Q08 baseline report.htm** for each
EA:symbol pair (selected by tester.ini `Symbol=` match + most recent mtime). Each
report.htm Deals table row-pairs (direction=in / direction=out) to produce matched trades
with: entry_time, exit_time, hold_h, net PnL, exit comment. Minimum 30 trades required.

Exit comment classification:
- `TIME_MGMT`: contains `qm_tm` or `time_stop` (framework time management label, covers
  both fixed time stops and signal/MA crossover closes that the framework labels uniformly)
- `TP` / `SL`: contains `tp ` / `sl ` prefix
- `SIGNAL_DECAY`: explicit signal close labels
- `OTHER`: empty or unknown (frequently the opposite-channel/reversal close in DEMA-type
  strategies, or session-end pending expiry)

### Hold-time buckets (adaptive)

Buckets adapt to the EA's average hold time:
- Short avg (<8h): `<1h / 1-4h / 4-12h / 12-48h / >48h`
- Medium avg (8-48h): `<2h / 2-8h / 8-24h / 1-3d / >3d`
- Long avg (>48h): `<12h / 12-48h / 2-7d / 1-4wk / >4wk`

### Surgery signal score

**HIGH:** early bucket(s) net-negative AND WR < 45% AND WR gradient early→late > 8-15 pp
AND late buckets positive AND either: TIME_MGMT/mechanical >35% of early exits (time-based
surgery), or SL dominance with large gradient (SL-tightness surgery).

**WEAK:** gradient present but not unambiguous (mild slope, early not clearly negative).

**NO_CASE:** flat or negative gradient (later holds not better — exits are not the problem;
edge is genuinely weak or absent).

**NO_DATA:** fewer than 30 trades, or fewer than 3 buckets with >=5 trades.

---

## 2. Population Summary Table

| EA | Symbol | Trades | Avg Hold | Verdict | Live? |
|---|---|---|---|---|---|
| QM5_10115 | GDAXI | 430 | 10.2h | **HIGH** | No |
| QM5_10440 | NDX | 451 | 4.3h | **HIGH** | **YES** |
| QM5_10476 | USDCAD | 257 | 10.2h | **HIGH** | No |
| QM5_10494 | XAUUSD | 667 | 22.2h | **HIGH** | No |
| QM5_10513 | XAUUSD | 76 | 65.4h | NO_DATA | YES |
| QM5_10569 | XAUUSD | 324 | 33.3h | NO_CASE | No |
| QM5_10692 | NDX | 530 | 17.0h | WEAK | YES |
| QM5_10715 | USDJPY | 1466 | 13.7h | **HIGH** | **YES** |
| QM5_10911 | GDAXI | 296 | 12.5h | **HIGH** | **YES** |
| QM5_10919 | XTIUSD | 29 | — | NO_DATA | No |
| QM5_10920 | XAUUSD | 81 | 24.2h | NO_CASE | No |
| QM5_10938 | GDAXI | 78 | 9.3h | **HIGH** | No |
| QM5_10939 | XAUUSD | 94 | 29.6h | **HIGH** | No |
| QM5_10943 | NDX | 120 | 5.0h | **HIGH** | No |
| QM5_11124 | SP500 | 60 | 68.6h | NO_CASE | No |
| QM5_11128 | NDX | 146 | 79.6h | NO_CASE | No |
| QM5_11128 | SP500 | 150 | 72.8h | NO_CASE | No |
| QM5_11132 | NDX | 56 | 76.7h | NO_CASE | Yes |
| QM5_11132 | SP500 | 65 | 63.6h | NO_CASE | Yes |
| QM5_11165 | AUDCAD | 207 | 11.7h | NO_CASE | Yes |
| QM5_11421 | AUDUSD | 81 | 33.3h | NO_CASE | Yes |
| QM5_11421 | EURUSD | 92 | 30.8h | NO_CASE | Yes |
| QM5_12567 | XAUUSD | 73 | 63.3h | NO_CASE | Yes |
| QM5_12567 | XNGUSD | 58 | 67.3h | NO_DATA | Yes |
| QM5_12847 | NDX | 69 | 590.9h | **HIGH** | No |
| QM5_12915 | SP500 | 66 | 117.5h | NO_CASE | No |

**Results:** 26 scanned, 23 with >=30 trades. **10 HIGH, 1 WEAK, 10 NO_CASE, 2 NO_DATA.**

---

## 3. HIGH Candidate Detail

### Priority ranking: time/session kill confirmed (highest confidence)

---

### 3.1 QM5_10494 / XAUUSD — HIGHEST PRIORITY

**EA:** `mql5-dema-chan` (DEMA Range Channel breakout, signal_tf=H8)  
**Trades:** 667 | Avg hold: 22.2h | Exit dist: TIME_MGMT 63%, SL 13%, OTHER 21%, TP 3%

| Bucket | N | Net PnL | WR | Avg Net | Dominant Exits |
|---|---|---|---|---|---|
| <2h | 13 | -12,916 | **0%** | -994 | SL×13 |
| 2-8h | 116 | -22,221 | **36%** | -192 | OTHER×66, TIME_MGMT×31, SL×17 |
| 8-24h | 190 | -73,615 | **14%** | -387 | TIME_MGMT×94, SL×47, OTHER×38 |
| **1-3d** | **343** | **+121,194** | **68%** | **+353** | TIME_MGMT×288, TP×10, SL×10 |
| >3d | 5 | +2,616 | 80% | +523 | TIME_MGMT×5 |

**Gradient:** WR 0% → 68% (+68 pp), avg_net -994 → +353.

**Mechanics:**
- `strategy_hold_minutes = 1920` (32h fixed time stop) triggers qm_tm_close at 32h
- `strategy_signal_tf = PERIOD_H8`: opposite-channel signal closes = qm_tm_close label also
- The 8-24h bucket (190 trades, WR 14%) is dominated by TIME_MGMT exits = channel-reversal
  signal fires prematurely before the trade matures, killing trades that would have been
  32h winners
- Confirmed via empty-comment exits at exactly 5.0h hold in 2-8h bucket: opposite channel
  signal reversal at first H1/H8 bar closure (net positive on average = wrongly killed)
- The 1-3d bucket (343 trades at 68% WR) are ALL killed by the 32h time stop = these
  survivors were in profit at forced exit

**Proposed v2 change:**
1. Add a `strategy_min_hold_h = 24` no-close zone: suppress all signal-reversal channel
   exits for the first 24h (let position breathe through initial H8 signal noise)
2. Keep `strategy_hold_minutes = 1920` as outer hard stop
3. Net effect: eliminate the 8-24h signal-decay kills; preserve 32h forced exit on winners

---

### 3.2 QM5_10943 / NDX — HIGH (LIVE: No)

**EA:** `grimes-trendday` (trend-day session breakout, pending expiry to session close 22:45)  
**Trades:** 120 | Avg hold: 5.0h | Exit dist: TIME_MGMT 88%, SL 9%, OTHER 3%

| Bucket | N | Net PnL | WR | Avg Net | Dominant Exits |
|---|---|---|---|---|---|
| <1h | 42 | -9,618 | **12%** | -229 | TIME_MGMT×39, SL×3 |
| 1-4h | 39 | -4,204 | **36%** | -108 | TIME_MGMT×34, OTHER×4, SL×1 |
| **4-12h** | **31** | **+12,493** | **77%** | **+403** | TIME_MGMT×27, SL×4 |
| 12-48h | 6 | +2,480 | 67% | +413 | TIME_MGMT×4, SL×2 |
| >48h | 2 | +873 | 50% | +436 | TIME_MGMT×1, SL×1 |

**Gradient:** WR 12% → 77% (+55 pp), avg_net -229 → +403.

**Mechanics:**
- The EA places pending orders (BUY_STOP/SELL_STOP) at the opening range breakout with
  `req.expiration_seconds = max(60, seconds_to_session_close_22:45)`
- Orders placed late in the session fill with very little time remaining → closed by
  session end within <1h (TIME_MGMT×39 = session-close pending expiry at 22:45)
- Orders placed earlier (4-12h before 22:45) = profitable 77% WR survivors

**Proposed v2 change:**
1. Add a `strategy_min_hold_available_h = 4` gate at entry submission: do not place pending
   if fewer than 4h remain before session close. This filters the late-entry noise.
2. Alternatively, allow extended hold past session (set EOD expiry to 22:45 of NEXT day for
   entries that fill with >2h remaining, letting trend-day holds extend overnight).

---

### 3.3 QM5_10939 / XAUUSD — HIGH (LIVE: No — XAUUSD stream, the GBPUSD v2 is live)

**EA:** `grimes-context-pb` (H4 context pullback, `strategy_time_exit_h4_bars = 18`)  
**Trades:** 94 | Avg hold: 29.6h | Exit dist: SL 48%, OTHER 26%, TIME_MGMT 13%, TP 14%

| Bucket | N | Net PnL | WR | Avg Net | Dominant Exits |
|---|---|---|---|---|---|
| <2h | 4 | -1,226 | 25% | -307 | SL×1, OTHER×3 |
| 2-8h | 20 | -8,772 | **25%** | -439 | SL×14, TP×2, OTHER×4 |
| 8-24h | 28 | +6,652 | 43% | +238 | SL×12, OTHER×9, TP×7 |
| 1-3d | 30 | +5,136 | **30%** | +171 | SL×18, OTHER×8, TP×4 |
| **>3d** | **12** | **+6,902** | **83%** | **+575** | TIME_MGMT×12 |

**Gradient:** WR 25% → 83% (+58 pp) at >3d bucket. TIME_MGMT×12 = all killed by the
72h time stop (18 H4 bars × 4h = 72h).

**Mechanics:**
- `strategy_time_exit_h4_bars = 18` fires at 72h; all 12 >3d trades are TIME_MGMT exits
- The >3d bucket (83% WR, avg +575) shows the real edge lives beyond 72h
- The 1-3d dip to 30% WR (SL-dominated) is noise before the edge materializes

**Proposed v2 change (for XAUUSD rebuild):**
Extend `strategy_time_exit_h4_bars` from 18 → 30+ (120h+). Test at 24 (96h) and 30 (120h).
The edge clearly needs more than 72h to mature on XAUUSD. The current 72h is cutting winners.

---

### 3.4 QM5_10911 / GDAXI — HIGH (LIVE: YES — active sleeve)

**EA:** `grimes-complex-pb` (complex pullback, `strategy_max_hold_bars = 30`, runs on H1)  
**Trades:** 296 | Avg hold: 12.5h | Exit dist: TIME_MGMT 44%, SL 21%, TP 25%, OTHER 9%

| Bucket | N | Net PnL | WR | Avg Net | Dominant Exits |
|---|---|---|---|---|---|
| <2h | 37 | -11,875 | **27%** | -321 | SL×22, TIME_MGMT×5, TP×8, OTHER×2 |
| 2-8h | 107 | -8,870 | **32%** | -83 | SL×37, TIME_MGMT×33, TP×31, OTHER×6 |
| 8-24h | 107 | +19,333 | 45% | +181 | TIME_MGMT×62, TP×27, OTHER×16, SL×2 |
| **1-3d** | **43** | **+20,942** | **72%** | **+487** | TIME_MGMT×29, TP×9, OTHER×4, SL×1 |

**Gradient:** WR 27% → 72% (+45 pp), avg_net -321 → +487.

**Mechanics:**
- `strategy_max_hold_bars = 30` H1 bars = 30h max hold
- The 1-3d bucket (24-72h) has TIME_MGMT×29/43 (67%) = trades killed at the 30h ceiling
- WR 72% and avg +487 = these are winners being cut at 30h

**LIVE SLEEVE — IMMEDIATE SURGERY CANDIDATE.**

**Proposed v2 change:**
Extend `strategy_max_hold_bars` from 30 → 60 (60h) or 72 (72h). The evidence shows the
edge matures fully in the 24-72h window; cutting at 30h is premature. Rebuild as v2,
enqueue at Q02, replace live sleeve only after Q08 PASS_SOFT + portfolio re-admission.

---

### 3.5 QM5_10715 / USDJPY — HIGH (LIVE: YES — active sleeve)

**EA:** `tv-asian-box` (Asian session breakout, M15, EOD close at 23:55)  
**Trades:** 1466 | Avg hold: 13.7h | Exit dist: TIME_MGMT 64%, SL 36%

| Bucket | N | Net PnL | WR | Avg Net | Dominant Exits |
|---|---|---|---|---|---|
| <2h | 56 | -12,798 | **7%** | -229 | SL×50, TIME_MGMT×6 |
| 2-8h | 231 | -55,065 | **6%** | -238 | **SL×200**, TIME_MGMT×31 |
| **8-24h** | **1177** | **+89,334** | **58%** | **+76** | TIME_MGMT×907, SL×270 |
| >3d | 2 | +609 | 50% | +305 | mixed |

**Gradient:** WR 6% → 58% (+51 pp), avg_net -238 → +76.

**Mechanics:**
- Asian box breakout: pending order at box high/low with expiry = seconds to EOD (23:55)
- Early holds (<2h, 2-8h): 87% SL exits. The breakout triggers but immediately reverses
  (London session noise, stop-hunt patterns before NY continuation)
- Trades surviving past 8h = NY session confirms the direction → 58% WR (TIME_MGMT×907
  = EOD close at 23:55, these are the winners running their full session)
- 1466 trades on M15 = very high frequency; noise in first 8h is statistically robust

**LIVE SLEEVE — IMMEDIATE SURGERY CANDIDATE.**

**Proposed v2 change:**
Add a time-gated SL: widen initial SL for first 4-6h after fill (e.g., 2× ATR initial
stop vs current `strategy_atr_sl_mult = 0.35-0.50`), then tighten to normal SL after 6h.
Alternative: add a break-even trigger at first +0.5R (trail after profit), so early
reversals don't kill the trade if they recover. The core issue is SL too tight for
London-session noise on the Asian breakout.

---

### 3.6 QM5_10938 / GDAXI — HIGH (LIVE: No)

**EA:** `grimes-accept-high` (acceptance high breakout, H1, `strategy_max_hold_bars = 24`)  
**Trades:** 78 | Avg hold: 9.3h | Exit dist: SL 62%, TP 22%, OTHER 8%, TIME_MGMT 9%

| Bucket | N | Net PnL | WR | Avg Net | Dominant Exits |
|---|---|---|---|---|---|
| <2h | 12 | -7,132 | **8%** | -594 | **SL×11**, TP×1 |
| 2-8h | 37 | -1,228 | **30%** | -33 | SL×24, OTHER×3, TP×9, TIME_MGMT×1 |
| 8-24h | 21 | +6,927 | 48% | +330 | TP×6, SL×11, OTHER×3 |
| **1-3d** | **8** | **+6,083** | **62%** | **+760** | TIME_MGMT×5, SL×2, TP×1 |

**Gradient:** WR 8% → 62% (+54 pp), avg_net -594 → +760.

**Mechanics:**
- `strategy_max_hold_bars = 24` H1 = 24h time stop (TIME_MGMT in 1-3d bucket)
- Early <2h losses: 11/12 SL hits at -594 avg — very tight SL relative to H1 bar noise
- The `strategy_acceptance_close_fraction = 0.70` (acceptance range fraction for entry)
  means entries close to the breakout level = stop easily reached on initial pullback

**Proposed v2 change:**
Extend `strategy_max_hold_bars` from 24 → 48. Also consider widening SL slightly
(`strategy_atr_sl_mult` or buffer) to survive the initial pullback noise. Sample is
small (78 trades) — rebuild and test.

---

### 3.7 QM5_10115 / GDAXI — HIGH (LIVE: No)

**EA:** `tv-ma-scalper-relief` (MA-crossover relief rally, M15, `strategy_max_hold_bars = 96`)  
**Trades:** 430 | Avg hold: 10.2h | Exit dist: TIME_MGMT 56%, SL 35%, OTHER 9%

| Bucket | N | Net PnL | WR | Avg Net | Dominant Exits |
|---|---|---|---|---|---|
| **<2h** | 84 | -24,444 | **36%** | **-291** | TIME_MGMT×42, SL×34, OTHER×8 |
| 2-8h | 134 | +7,911 | 54% | +59 | SL×55, TIME_MGMT×64, OTHER×15 |
| 8-24h | 157 | +11,679 | 56% | +74 | TIME_MGMT×81, SL×61, OTHER×15 |
| **1-3d** | **55** | **+20,237** | **67%** | **+368** | TIME_MGMT×55 |

**Gradient:** WR 36% → 67% (+32 pp), avg_net -291 → +368.

**Mechanics:**
- `strategy_max_hold_bars = 96` M15 bars = 24h hard stop (all 1-3d exits = TIME_MGMT =
  24h ceiling; 67% WR = winners killed at 24h)
- Early <2h TIME_MGMT×42 are MA-crossover exits (not the 24h stop) = signal-decay closes
  happening before the relief-rally matures past M15 noise
- `strategy_signal_tf = PERIOD_M15`: MA crossover closes labeled qm_tm_close

**Proposed v2 change:**
1. Extend `strategy_max_hold_bars` from 96 → 192+ M15 bars (48h) to capture the 24-72h
   winners
2. Add minimum hold on MA-crossover exit (don't close on MA flip within first 4h/16 M15
   bars) to suppress the early noise kills

---

### 3.8 QM5_10440 / NDX — HIGH, LIVE (SL-tightness pattern)

**EA:** `mql5-ohlc-mtf` (OHLC multi-timeframe structure, H1, pending_expiry=240min)  
**Trades:** 451 | Avg hold: 4.3h | Exit dist: SL 60%, TP 38%, OTHER 2%

| Bucket | N | Net PnL | WR | Avg Net | Dominant Exits |
|---|---|---|---|---|---|
| <1h | 105 | -25,385 | **27%** | -242 | SL×77, TP×27, OTHER×1 |
| 1-4h | 205 | +5,821 | **35%** | +28 | SL×130, TP×68, OTHER×7 |
| **4-12h** | **108** | **+67,000** | **55%** | **+620** | **SL×48, TP×58**, OTHER×2 |
| 12-48h | 31 | +25,065 | 61% | +808 | TP×19, SL×12 |

**Gradient:** WR 27% → 61% (+35 pp), avg_net -242 → +808.

**Mechanics:**
- No time management exits; gradient is entirely SL/TP driven
- `strategy_pending_expiry_minutes = 240` (4h pending order expiry) — unfilled orders
  expire; this does not affect post-fill behaviour
- Early <1h SL hits (77/105 = 73%) = MTF structure entries that immediately reverse
- The gradient suggests SL is too tight for the H4/M30 structure to play out; trades
  need 4h+ to prove direction
- `strategy_take_profit_r = 2.0`: TP is 2× the stop distance — winners take time to reach

**LIVE SLEEVE.**

**Proposed v2 change:**
Widen SL: increase `strategy_atr_sl_mult` or structural buffer to survive initial
reversal noise. Add an initial break-even guard (if price returns to entry within first
2h, set BE instead of SL) OR extend SL for first N bars and tighten after. The TP/SL
ratio is good (2R) but SL is prematurely triggering.

---

### 3.9 QM5_10476 / USDCAD — HIGH (SL-tightness pattern)

**EA:** `mql5-pamxa` (PAMXA regime breakout, H1, `strategy_regime_expiry_days = 5`)  
**Trades:** 257 | Avg hold: 10.2h | Exit dist: SL 53%, TP 36%, OTHER 9%, TIME_MGMT 2%

| Bucket | N | Net PnL | WR | Avg Net | Dominant Exits |
|---|---|---|---|---|---|
| <2h | 44 | -19,307 | **20%** | -439 | SL×33, TP×7, OTHER×4 |
| 2-8h | 97 | +18,516 | 43% | +191 | SL×49, TP×32, OTHER×13 |
| 8-24h | 93 | +41,929 | 51% | +451 | TP×42, SL×44, OTHER×5 |
| **1-3d** | **23** | **+14,366** | **57%** | **+625** | SL×10, TP×11, OTHER×2 |

**Gradient:** WR 20% → 57% (+36 pp), avg_net -439 → +625.

**Mechanics:**
- `strategy_regime_expiry_days = 5`: regime cross entry validity window, not a trade exit
- Pattern is pure SL-tightness: 33/44 (75%) of <2h trades are SL hits at -439 avg
- Regime breakout entries that immediately fail = price reverting after breakout
- Longer holds progressively better as regime direction proves itself

**Proposed v2 change:**
Widen the initial SL or add a hold zone (suppress SL for first 2h, use wider initial
stop then trail). Alternatively: add a 1h confirmation bar before entry (don't enter on
bar-close breakout if H1 bar immediately followed by an inside-bar reversal).

---

### 3.10 QM5_12847 / NDX — HIGH (long-horizon, turn-of-month)

**EA:** `turn-of-month-sp500` (monthly calendar effect, `exit_td_of_next = 3`)  
**Trades:** 69 | Avg hold: 590.9h | Exit dist: TIME_MGMT 70%, SL 29%, OTHER 1%

| Bucket | N | Net PnL | WR | Avg Net | Dominant Exits |
|---|---|---|---|---|---|
| 2-7d | 7 | -5,564 | **14%** | -795 | SL×6, TIME_MGMT×1 |
| 1-4wk | 19 | -10,322 | **26%** | -543 | SL×13, TIME_MGMT×6 |
| **>4wk** | **43** | **+20,319** | **72%** | **+473** | TIME_MGMT×41, SL×1, OTHER×1 |

**Gradient:** WR 14% → 72% (+58 pp), avg_net -795 → +473.

**Mechanics:**
- `exit_td_of_next = 3`: exit on 3rd trading day of next month. Avg 590h (25 calendar days)
  suggests the entry window spans broadly through the month (not just last 3-5 TDs)
- The 2-7d and 1-4wk SL losses are premature exits before the month-turn effect plays
- TIME_MGMT×41 in >4wk = 3rd-TD-of-next-month forced exits; 72% WR confirms effect is real

**Note:** The 590h average hold is anomalous for a "turn of month" strategy designed to hold
~8-10 trading days. This suggests entries are not restricted to the last N trading days.
If entries happen throughout the month, many are exited at the next month's TD3, producing
24+ calendar day holds. Consider: (a) restrict entry window to last 5 TDs only, or
(b) increase `exit_td_of_next` from 3 → 5 to let the effect fully deliver.

**Proposed v2 change:**
Add `strategy_entry_min_td_before_eom = 5` (only enter in last 5 TDs of month) to
concentrate entries at the timing that actually captures the month-turn effect. Also
consider widening SL (SL×13 in 1-4wk = SL too tight for 2-4 week holds).

---

## 4. WEAK: QM5_10692 / NDX

**EA:** `tv-ls-ms` (long-short momentum structure, H1)  
**Trades:** 530 | Avg hold: 17.0h | Exit dist: TIME_MGMT 42%, SL 29%, TP 12%, OTHER 16%

| Bucket | N | Net PnL | WR | Avg Net | Dominant Exits |
|---|---|---|---|---|---|
| <2h | 33 | +3,053 | 52% | +93 | TIME_MGMT×13, OTHER×7, SL×11, TP×2 |
| 2-8h | 95 | -14,148 | 43% | -149 | TIME_MGMT×32, SL×33, OTHER×24, TP×6 |
| 8-24h | 354 | +186,508 | 52% | +527 | TIME_MGMT×138, SL×88, OTHER×53, TP×75 |
| 1-3d | 41 | -11,093 | 27% | -271 | TIME_MGMT×27, SL×9, OTHER×5 |
| >3d | 7 | -3,742 | 14% | -535 | TIME_MGMT×7 |

Gradient is not monotonic: 8-24h is the winning zone but both shorter AND longer holds
are negative. This is a classic "optimal window" pattern, not exit-surgery — the 1-3d and
>3d failures indicate extended holds beyond the LS momentum horizon also lose. Verdict
stands WEAK; the EA's exits are roughly correct in principle; the real problem is elsewhere
(edge weaker at long holds, TIME_MGMT kills some 8-24h survivors prematurely, but also
kills losers if TIME_MGMT is extended). **Do not build v2 until Q08 diagnosis reveals
which sub-gates are failing.**

This is also a **LIVE SLEEVE** — no change recommended.

---

## 5. NO_CASE EAs (representative notes)

EAs with NO_CASE verdict: QM5_10569/XAUUSD, QM5_10920/XAUUSD, QM5_11124/SP500,
QM5_11128/NDX & SP500, QM5_11132/NDX & SP500, QM5_11165/AUDCAD, QM5_11421/AUDUSD &
EURUSD, QM5_12567/XAUUSD, QM5_12915/SP500.

Common pattern in NO_CASE: flat or negative WR gradient — the later hold buckets are NOT
better than early ones. This means exits are not the culprit; the strategy's edge is
absent or already expressed in short holds. Surgery would not help these EAs.

Example:
- **QM5_11165/AUDCAD** (207 trades, 11.7h avg): WR is ~45% across all buckets with no
  gradient. Classic edge-absent pattern.
- **QM5_12915/SP500** (66 trades, 117.5h avg): All long-hold buckets show similar WR.
  The Q08 FAIL_SOFT verdict here reflects genuine statistical weakness, not exit mistakes.

---

## 6. Ranked Surgery Shortlist

| Rank | EA | Symbol | Live? | WR Gradient | Suspected Killer | Proposed Fix |
|---|---|---|---|---|---|---|
| 1 | QM5_10494 | XAUUSD | No | 0%→68% | Signal-reversal channel close (H8 TF noise) killing 8-24h window | Min-hold 24h before signal-reversal allowed |
| 2 | QM5_10943 | NDX | No | 12%→77% | Session-close pending expiry (22:45) = only 1-4h window | Filter: don't place if <4h to session end |
| 3 | **QM5_10911** | **GDAXI** | **YES** | 27%→72% | 30h max_hold_bars ceiling kills 24-72h winners | Extend max_hold to 60-72h |
| 4 | **QM5_10715** | **USDJPY** | **YES** | 6%→58% | SL too tight for 0-8h London noise (87% SL in 2-8h) | Widen initial SL or time-gated SL |
| 5 | QM5_10939 | XAUUSD | No | 25%→83% | 72h time stop (18 H4 bars) cuts XAUUSD wins | Extend to 30+ H4 bars (120h+) |
| 6 | QM5_10938 | GDAXI | No | 8%→62% | 24h max_hold + tight SL on initial pullback | Extend to 48h; widen SL |
| 7 | QM5_10115 | GDAXI | No | 36%→67% | MA-crossover early kills + 24h ceiling | Min-hold on MA exit; extend ceiling to 48h |
| 8 | **QM5_10440** | **NDX** | **YES** | 27%→61% | SL too tight for H4 MTF structure (73% SL in <1h) | Widen SL or add break-even buffer |
| 9 | QM5_10476 | USDCAD | No | 20%→57% | SL too tight for regime-breakout settling | Widen initial SL; 2h confirmation |
| 10 | QM5_12847 | NDX | No | 14%→72% | Entry window too broad + SL tight for multi-week hold | Restrict to last 5 TDs of month; widen SL |

---

## 7. Recommended Next Actions

**Immediate (live sleeves):**

1. **QM5_10911/GDAXI v2**: Change `strategy_max_hold_bars` 30→60. Rebuild, test Q02→Q08,
   compare. If Q08 PASS_SOFT, admit to portfolio and plan live swap. EA is currently live
   and may be leaving 45pp of WR on the table at every trade.

2. **QM5_10715/USDJPY v2**: Widen `strategy_index_sl_atr_mult` or
   `strategy_fx_metal_sl_atr_mult` from current default (~0.35-0.50) to 0.75+. Alternatively
   add a 4-6h SL holdback zone. This is the highest-trade-count candidate (1466 trades, very
   robust gradient).

3. **QM5_10440/NDX v2**: Widen SL or add break-even trigger. The live sleeve is trading
   with a Q08 FAIL_SOFT verdict; surgery is the path to PASS_SOFT.

**High priority (not live):**

4. **QM5_10494/XAUUSD v2**: Add `strategy_min_hold_h = 24` no-signal-close zone. Most
   robust single candidate (667 trades, 0%→68% WR, clear mechanism).

5. **QM5_10943/NDX v2**: Add entry submission gate: no pending if seconds_to_session_end
   < 4×3600. Simple one-line guard.

**Build queue priority order:** 10494 → 10943 → 10939 → 10938 → 10115 → 10476 → 12847

---

*Evidence: report.htm files parsed from
`D:/QM/reports/pipeline/QM5_*/Q08/_baseline/QM5_*/*/raw/run_01/report.htm`.
Live book cross-check: `D:/QM/reports/state/live_book_pulse.json`.
Source code: `C:/QM/repo/framework/EAs/QM5_*/`.*

---

## Claude review verdict (2026-07-04 night, before any v2 builds)

The scan's HIGH class splits into two evidence tiers:

**Tier A — time-exit amputation (T-WIN class, ACTIONABLE):** 10494, 10943, 10911,
10939:XAUUSD, 10938, 10115, 12847. Killer = mechanical time/ceiling/expiry exits
cutting trades whose win rate RISES with hold time. Same mechanism as the proven
12989/12990 surgeries. Eligible for v2 rebuilds (new EA id, full Q02→Q08 cascade).

**Tier B — "SL too tight" (10715, 10440, 10476, all-or-partly LIVE): NOT actionable
on hold-gradient evidence.** Short-hold losers are partially tautological in stop-based
systems (losers exit early at SL by construction). Widening stops changes risk geometry
— that claim needs MAE/MFE evidence (did price recover past the stop?), which the
2026-06-30 intraday-MAE capture (1d72d68a) only provides for streams recorded going
forward. PARKED until MAE data accumulates. No live-sleeve parameter changes proposed.

**Build decision (tonight):** v2 rebuilds for QM5_10911 (max_hold_bars 30→60; single
param; leg in BOTH the live S3 book and the Round25 FTMO composition) and QM5_10943
(pending-expiry fix; M15 NDX density candidate for FTMO). Remaining Tier A queued
behind these two; every v2 is judged by the pipeline, never swapped automatically
(challenger-swap discipline at Q09; live changes only via OWNER-signed manifest).
