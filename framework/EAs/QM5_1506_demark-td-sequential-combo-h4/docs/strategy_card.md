---
ea_id: QM5_1506
slug: demark-td-sequential-combo-h4
expected_trades_per_year_per_symbol: 100
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/setup-countdown-exhaustion]]"
  - "[[concepts/swing-reversal]]"
indicators:
  - "[[indicators/td-setup-9]]"
  - "[[indicators/td-combo-countdown-13]]"
  - "[[indicators/atr]]"
  - "[[indicators/sma-d1-50]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: Single source_id present; body cites FF cluster URL plus DeMark Wiley 1994 (ISBN 978-0-471-03548-1) and Perl Bloomberg Press 2008 (ISBN 978-1-57660-314-8), satisfying the one-source-per-card rule.
r2_mechanical: PASS
r2_reasoning: Five closed-form gates over TD Setup (9-bar price comparison) and TD Combo Countdown (4-condition AND-gate over 13 bars), ATR floor, D1 SMA(50), and cooldown; DeMark's verbal rules reduce directly to bit-exact arithmetic.
r3_data_available: PASS
r3_reasoning: Pure OHLC plus ATR and D1 SMA are testable on every DWX instrument.
r4_ml_forbidden: PASS
r4_reasoning: Fixed Setup (9 bars) and Countdown (13 bars) bar-counting rules, fixed 60-bar valid-Setup window and 30-bar cooldown, bounded SL (true-range-high plus 1 ATR); no ML or adaptive PnL logic, single position per magic.
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 PASS: cites DeMark/Perl books and FF source; R2 PASS: deterministic TD Setup/Combo countdown entries and exits; R3 PASS: OHLC/ATR/D1-SMA rules testable on DWX instruments; R4 PASS: no ML/adaptive PnL logic, bounded SL, single-position HR14-compatible."
---

# DeMark TD Sequential Combo (H4)

## Quelle
- Source: [[sources/forexfactory-trading-systems]]
- Page / Timestamp: ForexFactory Trading Systems subforum
  cluster "TD Sequential Combo EA" / "DeMark Combo Countdown
  MT4" / "TD Combo 13 detector" threads (2010-2024). Tom R.
  DeMark, *The New Science of Technical Analysis* (John Wiley
  & Sons 1994, ISBN 978-0-471-03548-1), ch. 2 ("Sequential")
  and ch. 3 ("Combo"). DeMark, *DeMark on Day Trading Options*
  (with Tom DeMark Jr., McGraw-Hill 1999, ISBN
  978-0-07-016196-2), ch. 6 (TD Combo H4 application).
  Jason Perl, *DeMark Indicators* (Bloomberg Press 2008, ISBN
  978-1-57660-314-8), ch. 4 (TD Combo). Continuation of the
  DeMark cluster opened in prior batches: QM5_1432 (TD
  Setup-Trend), QM5_1438 (TD Demarker), QM5_1443 (TD Lines),
  QM5_1446 (TD Open Range), QM5_1475 (TD D-Wave), QM5_1477
  (TD D-Wave Wave3). This card adds the **TD Combo** variant
  — a tightened TD Sequential Countdown that requires the
  Combo conditions (stricter than vanilla TD Countdown) and is
  distinct in topology from TD Setup-Trend (1432, Setup only)
  and from all other DeMark cards in the registry. Per Perl
  2008 ch. 4, TD Combo is "Sequential with restrictive
  Countdown" and is DeMark's own preferred exhaustion-reversal
  primitive on shorter timeframes.

## Mechanik

TD Combo (DeMark *The New Science of Technical Analysis* ch. 3)
combines TD Sequential's two-phase structure (Setup → Countdown)
but tightens the Countdown to require **monotonically
strengthening** bars relative to a tighter lookback. The setup
identifies a trending environment; the combo countdown
identifies exhaustion within that trend.

### Phase 1 — Setup (TD Sell Setup mirror for Buy Setup)

A **TD Sell Setup** completes at bar k if:
- close[k-i] > close[k-i-4] for i = 0..8 (9 consecutive bars
  where each close is higher than the close 4 bars earlier).

A **TD Buy Setup** mirrors: close[k-i] < close[k-i-4] for
i = 0..8 (9 consecutive bars where each close is lower than
the close 4 bars earlier).

The setup-completion bar is the 9th consecutive bar.

### Phase 2 — Combo Countdown

After a Sell Setup completes at bar k, the Combo Countdown
starts on bar k+1. Each bar j is counted as a "valid Combo
Countdown bar" if **all four** Combo conditions hold:

1. close[j] > high[j-2] (price closing above the high 2 bars
   ago — vanilla Sequential Countdown condition).
2. close[j] > close[j-1] (price closing higher than the prior
   bar — Combo tightening #1, not required in vanilla
   Sequential).
3. close[j] > close[j-1-N] where N is the count of the bar
   (i.e., the 1st Combo bar requires close[j] > close[j-2],
   the 2nd requires close[j] > close[j-3], etc.) — Combo
   tightening #2 ("monotonically strengthening" lookback).
4. high[j] > high[j-1] (each Combo bar makes a higher high
   than the prior — Combo tightening #3, ensures the
   exhaustion is occurring on bars that still extend the
   trend's high).

When 13 Combo Countdown bars accumulate (not necessarily
consecutive), the Combo signal completes — this is the TD
Combo Sell signal.

TD Combo Buy Countdown mirrors all four conditions with
direction reversed.

### Entry (short on TD Combo Sell — long mirror)

All five gates must PASS on the bar where the 13th valid Combo
Countdown bar completes (call this bar t):

1. **TD Sell Setup gate**: a TD Sell Setup completed within
   the trailing 60 H4 bars before bar t (Sequential's "valid
   setup" window — DeMark 1994 ch. 2 recommends 50-60 bars).
2. **TD Combo Countdown gate**: 13 valid Combo Countdown bars
   have accumulated since the Sell Setup completion, with bar
   t being the 13th. The Countdown phase has not been
   "perfected" or "cancelled" per DeMark's standard cancellation
   rules (any close below close 4 bars earlier resets the
   setup; any close above the highest Setup bar's true high
   "perfects" the Countdown to allow trade).
3. **Macro-bias gate**: D1 close < D1 SMA(50) AND D1 SMA(50)[t]
   < D1 SMA(50)[t-5] for shorts (mirror for longs). Per DeMark
   1994 ch. 3, TD Combo Sell at H4 has its highest hit-rate
   when the daily trend is **down** (the H4 trend that
   exhausted was a counter-trend rally within a daily
   downtrend). The H4 reversal entry returns to the daily
   trend.
4. **ATR floor gate**: ATR(14)[t] > 0.6 * SMA(ATR(14), 200)[t].
   In compressed-vol regimes the Combo Countdown can complete
   on a nearly-flat 13-bar drift; ATR floor filters these out.
5. **No-recent-combo-entry gate**: no prior TD Combo entry on
   this symbol within the last 30 H4 bars. Combo signals can
   re-fire if the Setup phase recycles immediately after
   completion; 30-bar cooldown prevents over-trading on the
   same exhaustion cluster.

Direction: short on TD Combo Sell / long on TD Combo Buy.
Order: market on H4 close of bar t.

### Exit

- **TP1**: 1.5 * ATR(14)[t] from entry — close 60% of
  position.
- **TP2**: structural target — DeMark's "TDST" support level
  for shorts (lowest true low of the Sell Setup phase) / TDST
  resistance level for longs (highest true high of the Buy
  Setup phase). Close remaining 40%.
- **Time-stop**: 24 H4 bars elapsed without TP1 → close at
  market. (TD Combo Sequential reversals are typically 2-5
  day moves on H4; 24 H4 bars ~ 4 trading days.)

### Stop Loss

Hard SL at the true range high (= max of bar t high, bar t-1
close) plus a 1.0 * ATR(14)[t_entry] buffer for shorts;
mirror for longs. Fixed at fill, never trailed. Bounded
worst-case per HR14: SL distance is at most 2.5 * ATR
in any plausible setup geometry.

### Position Sizing

P2 baseline: RISK_FIXED = $1000 per trade per HR4. Live:
RISK_PERCENT = 0.5%.

### Zusätzliche Filter

- News-blackout: 60 min around NFP / ECB / FOMC.
- Spread filter: spread <= 1.5 * 20-bar median.
- Warm-up filter: require >= 300 H4 bars of history before
  the first entry (Setup window 9 bars + Combo Countdown
  worst-case 13 bars + 60-bar valid-Setup window + 200-bar
  ATR baseline + D1 SMA(50) warm-up + 30-bar cooldown).

### Target symbols

TD Combo uses OHLC bar relationships + ATR + D1 SMA — works on
every DWX instrument. Initial P2 baseline scope: EURUSD.DWX,
GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX (FX majors),
NDX.DWX, WS30.DWX, GDAXI.DWX, UK100.DWX (index CFDs — DeMark's
TD indicators were originally calibrated on S&P futures,
indices map naturally), XAUUSD.DWX, XTIUSD.DWX (commodities).
H4 timeframe.

## Concepts (was ist das für eine Strategie)
- [[concepts/setup-countdown-exhaustion]] — primary (the
  named DeMark two-phase Setup → Countdown topology, with
  Combo tightening of the Countdown phase to require
  monotonically strengthening bars)
- [[concepts/swing-reversal]] — secondary (the 13th Combo
  Countdown bar is the exhaustion-reversal trigger; trade
  direction reverses the trend that exhausted)

## R1–R4 Bewertung

| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PENDING | FF Trading Systems cluster URL + DeMark *The New Science of Technical Analysis* John Wiley 1994 ch. 3 (ISBN-cited, named-author seminal book) + DeMark *DeMark on Day Trading Options* McGraw-Hill 1999 ch. 6 + Perl *DeMark Indicators* Bloomberg Press 2008 ch. 4 (ISBN-cited reference treatment). Tom DeMark is one of the most widely-published TA authors (multiple books, Bloomberg TD-indicator licensee). R1 PASS expected under relaxed 2026-05-15 criteria. |
| R2 Mechanical | PENDING | All five gates are closed-form arithmetic over price-comparison inequalities (Setup: close > close[-4] for 9 bars; Combo: 4-condition AND-gate over 13 bars) + ATR + D1 SMA + bar-count cooldown. Direction is unambiguous (Sell Setup → short, Buy Setup → long). DeMark's verbal rules in the 1994 source reduce directly to bit-exact arithmetic — the most-implemented mechanical-pattern primitive in TA history. R2 PASS expected. |
| R3 Data Available | PENDING | Pure OHLC input + ATR + D1 SMA — testable on every DWX symbol. R3 PASS expected. |
| R4 ML Forbidden | PENDING | No ML, no adaptive parameters, fixed lookbacks (9 Setup, 13 Combo, 60-bar valid-Setup window, 200-bar ATR, 30-bar cooldown), fixed thresholds throughout. Bounded worst-case SL (true-range-high + 1 ATR buffer = at most 2.5 ATR). Single position per magic per HR14. R4 PASS expected. |

## Pipeline-Verlauf
- G0: PENDING

## Verwandte Strategien
- [[strategies/QM5_1432_demark-td-setup-trend-h4]] — sibling
  (TD Setup-Trend uses only the Setup phase — trend-continuation
  primitive when Setup completes; this card uses Setup → Combo
  Countdown two-phase structure — exhaustion-reversal primitive.
  Same DeMark Setup definition, completely different trade-
  direction logic.)
- [[strategies/QM5_1438_demark-demarker-h4]] — distinguished
  (DeMarker oscillator = oscillator topology on running max/min
  of bar extremes; this card is a price-comparison-pattern
  primitive — different domain.)
- [[strategies/QM5_1443_demark-td-lines-h4]] — distinguished
  (TD Lines = mechanical trend-line construction from named
  TD Points; this card is a Setup → Countdown bar-counting
  primitive — different domain.)
- [[strategies/QM5_1446_demark-td-open-range-h4]] —
  distinguished (TD Open Range = first-bar range breakout
  with DeMark filters; this card is an exhaustion-reversal
  pattern — different topology.)
- [[strategies/QM5_1475_demark-td-d-wave-h4]] — distinguished
  (TD D-Wave = wave-counting topology on D-Wave bar
  relationships; this card is the Setup-Combo bar-counting
  primitive — different DeMark indicator.)
- [[strategies/QM5_1477_demark-td-d-wave-wave3-h4]] —
  distinguished (TD D-Wave Wave3 = specific wave-3 entry within
  D-Wave; this card is the Setup-Combo exhaustion primitive.)

## Lessons Learned (während Pipeline-Lauf)
- <Datum>: <Erkenntnis> — siehe `docs/ops/LESSONS_LEARNED_<YYYY-MM>.md`

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
