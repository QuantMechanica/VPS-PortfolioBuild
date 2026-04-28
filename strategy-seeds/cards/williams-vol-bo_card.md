# Strategy Card — Williams Volatility Breakout (open ± N% prior day's range, multi-market)

> Drafted by Research Agent on 2026-04-28 from `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt` (verbatim Williams Entry-Techniques § "Volatility breakouts" + structural exit-rule derivation from § "When to Exit").
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per DL-032 + DL-030 Class 2 Review-only execution policy).

## Card Header

```yaml
strategy_id: SRC03_S01
ea_id: TBD
slug: williams-vol-bo
status: DRAFT
created: 2026-04-28
created_by: Research
last_updated: 2026-04-28

strategy_type_flags:                          # closest existing values from strategy_type_flags.md;
                                              # entry-side vocabulary gap (no Section-A flag for "open + N% range" volatility-expansion breakout — distinct from
                                              # narrow-range-breakout which requires an explicit range-contraction precondition).
  - atr-hard-stop                             # Williams: "$1,500 as final proof I am wrong" — fixed catastrophic stop; V5 translates to ATR-equivalent
  - symmetric-long-short                      # Williams: "Buy at the open the next day +100% of the previous days range. ... year in and year out it has been very good." Implicit mirror for sells (the workshop's broader "Failure Day Family" treats long/short symmetrically).
  - friday-close-flatten                      # V5 default; Williams uses bail-out-on-first-profitable-open OR $1,500 stop OR 3-bar trail (max ~5-day hold)
  # *vocabulary-gap flag proposed for CEO + CTO ratification per strategy_type_flags.md addition-process (see § 16):
  #   - vol-expansion-breakout                # entry mechanism: stop-buy/sell at next bar's open ± N% × range(prior_bar), no NR precondition
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Williams, Larry R. (1999). Long-Term Secrets to Short-Term Trading. Wiley Trading. New York: John Wiley & Sons."
    location: "PDF p. 25 (Inner Circle Workshop companion volume), § 'ENTRY TECHNIQUES — Volatility breakouts'. Exit-rule cross-reference: PDF pp. 20-21 § 'WHEN TO EXIT' (sub-sections 1 'Least Favorite Exit' = $1,500 dollar stop, 2 'Amazing 3 Bar Entry/Exit', 3 '18 Day Moving Average', 4 'Channel Breaks')."
    quality_tier: A
    role: primary
```

Raw evidence: `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt` lines 412-414 (entry rule verbatim), lines 238-313 (exit menu). Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Long-Term Secrets to Short-Term - Larry R. Williams.pdf`.

## 2. Concept

A **classical volatility-expansion breakout** evaluated each daily bar close. The next bar's entry is staged at the open ± N% × range(today) — when "the market is primed" by an upstream setup (WVI / COT / Sentiment / Seasonal / DMI overlays, workshop §§ 1-8). The thesis: Williams' "Law of Averages" implies that range-cycle expansions tend to follow range-cycle compressions, and a breakout BEYOND a multiple of the prior bar's range signals that the range-cycle has flipped from compression to expansion — momentum carries through over the next 1-5 sessions.

Williams' verbatim framing, PDF p. 25:

> "Volatility breakouts. Generally speaking, when the market is 'primed' I will buy at the open the next day +100% of the previous days range. This can be a smaller figure for some markets, [b]ut year in and year out it has been very good."

This card extracts the **base mechanical entry** (open ± N% × prior-range stop entry) without binding to any specific upstream setup — those are filters, not entry triggers, per DL-033 Rule 1 and SRC03 source.md § 6 (filters integrated per-card, not extracted as separate cards). The N% multiplier is Williams' load-bearing parameter; the source default is 100%; the strategy-richer Bonds section (PDF p. 37) cites a "30% volatility expansion works well in this market" disambiguation, motivating the P3 sweep range.

## 3. Markets & Timeframes

```yaml
markets:                                      # Williams' deployment universe; V5 re-mapping at CTO sanity-check
  - index_futures                             # Williams: S&P 500 futures (PDF p. 37+ Bonds & S&P specific tables). V5 proxy: US500.DWX
  - bond_futures                              # Williams: T-Bonds (PDF p. 37 cited "30% volatility expansion works well in this market"). V5 proxy: bond CFD if available; else flag dwx_suffix_discipline.
  - commodities                               # Williams workshop § 6 lists Wheat, Cotton, Pork Bellies, Copper, Sugar, Coffee, Beans, etc. V5 proxy: GOLD.DWX / XAGUSD.DWX / OIL.DWX / NATGAS.DWX where Darwinex offers.
  - forex                                     # Williams workshop covers currency futures (Swiss Franc, D-Mark, B-Pound, J-Yen). V5 proxy: spot Darwinex .DWX FX symbols.
timeframes:
  - D1                                        # Williams: rules stated on daily bars (open, close, "yesterday's range")
  - H4                                        # M15+ V5 fit per QUA-298 V5 boundary check; H4 is plausible D1-derivative for parameter sweep
session_window: not specified                 # Williams' rule fires once per day on next-open
primary_target_symbols:
  - "S&P 500 futures (Williams' deployment) → US500.DWX V5 proxy"
  - "T-Bonds futures (Williams' deployment) → bond CFD if Darwinex offers; flag dwx_suffix_discipline otherwise"
  - "GOLD.DWX, EURUSD.DWX, USDJPY.DWX as multi-market generalization (Williams: 'works on all major markets')"
```

## 4. Entry Rules

Pseudocode — verbatim translation of Williams' PDF p. 25 § "Volatility breakouts" rule with the mirror-sell extension implicit in his broader Entry-Techniques framing.

```text
PARAMETERS:
- N_PCT             = 100        // Williams: "+100% of the previous days range" (default)
                                 //   Bonds-context disambiguation: 30% (PDF p. 37). P3 sweep axis.
- BAR               = D1         // Williams: daily bars
- MIN_RANGE_FLOOR   = 0          // optional sweep axis; off by default (Williams does not specify)

EACH-BAR (next-day open trigger, evaluated at prior-day close):
- range_t-1 = High[t-1] - Low[t-1]                    // prior bar's range
- buy_trigger  = Open[t] + (N_PCT / 100.0) * range_t-1
- sell_trigger = Open[t] - (N_PCT / 100.0) * range_t-1

ENTRY (only when not in position; stop-buy / stop-sell orders staged at session start):
- if intra-day High[t] >= buy_trigger  then OPEN_LONG  at buy_trigger  (stop-buy filled)
- if intra-day Low[t]  <= sell_trigger then OPEN_SHORT at sell_trigger (stop-sell filled)
- if BOTH triggered (inside-day breakout-fade): take whichever fired first;
  if implementation cannot tick-replay, take the LONG (Williams' verbatim reads long-side;
  short side is structural mirror)
```

Williams does not specify whether the trigger is calculated from yesterday's HIGH-LOW or yesterday's TRUE-RANGE (max(high, prev close) − min(low, prev close)). Card adopts **plain HIGH-LOW range** as the conservative reading; TRUE-RANGE is a P3 sweep axis variant.

## 5. Exit Rules

Williams lists FOUR exit options on PDF pp. 20-21 (§ "When to Exit"), positioned as a menu the trader picks per-strategy. For this V5 card, default exit is the dollar-stop + 3-bar trailing combo (Williams' "Amazing 3 Bar Entry/Exit Technique" PDF p. 21). The 18-bar MA and Channel-Break exits are P3 alternative-exit axes.

```text
DEFAULT EXIT (dollar stop + 3-bar trail combo):
PARAMETERS:
- HARD_STOP_USD     = 1500       // Williams: "I'm willing to use a stop of about $1,500 as final proof I am wrong" (PDF p. 21)
                                 //   V5 translation: ATR-scaled hard stop at entry; cell-size depends on instrument tick-value.
                                 //   Sweep axis: ATR(14) × {1.5, 2.0, 2.5, 3.0} for V5-friendly normalization.
- TRAIL_BARS        = 3          // Williams: "determine the highest close in the up move so far. Count that as day one and go back to get two more days. None of these can be an inside day. Once all three days have been noted, then determine the lowest true low of those three days. Place your stop to exit ... at that price."
- TRAIL_NO_INSIDE   = true       // Williams: "None of these can be an inside day" — trail counts only non-inside bars
- TRAIL_ACTIVATE    = first_close_in_profit  // Williams: trail engages once "the market is in a run away move ... Price must be out of a trading range"

EACH-BAR (in position):
- HARD STOP — fires at HARD_STOP_USD-equivalent ATR distance from entry; never moves
- TRAIL (activates after first profitable close OR position has held 3 non-inside bars):
  if LONG:
    trail_anchor_close = highest_close_since_entry
    trail_window = three most recent non-inside bars ending at the bar of trail_anchor_close
    trail_level = MIN( true_low(b) for b in trail_window )
    if Low[t] <= trail_level: CLOSE_LONG at trail_level (or next-bar open if gap-through)
  if SHORT: mirror — lowest_close_since_entry / true_high / max(true_high)

FRIDAY CLOSE: V5 default applies (force-flat at Friday 21:00 broker time). Williams' max
holding period is approx 3-5 sessions before trail or stop hits; weekends rarely bind.
No waiver required.
```

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults: kill-switch, news filter, MAX_DD trip, Friday Close
- pyramiding: NOT allowed (Williams: "I will also protect against loss by a rally to new highs if short, new lows if long. This does not mean I'm through with it ... I'll be back on the next buy/sell ... if the conditions are still there.")
- gridding: NOT allowed
- "primed market" upstream filter (OPTIONAL P3 sweep axis): trade only when at least ONE of Williams' setup tools agrees with direction:
  - WVI < 15 (undervalued) for longs / WVI > 75 (overvalued) for shorts (workshop § 1)
  - COT 12-month low (Commercials extreme long) for longs / 12-month high for shorts (workshop § 2)
  - DMI/ADX > 60 with directional bias for new-trend signal (workshop § 3)
  - Sentiment < 33 (extreme bearish public) for longs / > 75 for shorts (workshop § 5)
  - Seasonal-up month for longs / seasonal-down month for shorts (workshop § 6)
  - Off by default (raw vol breakout); on as an axis variant for "high-conviction" filter test
- ATR floor (P3 sweep axis): skip entries when range_t-1 < ATR(14) × 0.5
  // Rationale: Williams' "smaller figure for some markets" suggests N% should match instrument
  // vol scale; an ATR floor on the precondition range avoids triggering on truncated-range bars.
  // Off by default; sweeps [0.0, 0.25, 0.5, 0.75] × ATR(14)
```

## 7. Trade Management Rules

```text
- one open position per direction at any time (no pyramiding, no stacking)
- position size: maps to V5 risk-mode framework at sizing-time;
  Williams' explicit money-management formula (PDF pp. 28-31) uses fixed-fractional with
  20% of equity divided by largest accepted loss = number of contracts. V5 adapts to its
  own RISK_PERCENT / RISK_FIXED switch.
- Friday Close: forced flat per V5 default (no waiver)
- gridding: NOT allowed
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: n_pct
  default: 100                                # Williams: "+100% of the previous days range"
  sweep_range: [25, 50, 75, 100, 125, 150]    # Bonds disambiguation 30% (p. 37) → low end; T-Bonds tested at 7% (p. 43 "plus 7% of the previous days range") → very low end is also Williams-cited; 150% upper as bracket extension
- name: range_definition
  default: hl_range                           # Williams says "previous days range" — ambiguous; default = High-Low
  sweep_range: [hl_range, true_range]
- name: trail_bars
  default: 3                                  # Williams: "Count that as day one and go back to get two more days"
  sweep_range: [2, 3, 4, 5]
- name: trail_no_inside
  default: true                               # Williams: "None of these can be an inside day"
  sweep_range: [true, false]
- name: hard_stop_atr_mult
  default: 2.0                                # ATR-equivalent of Williams' $1,500
  sweep_range: [1.5, 2.0, 2.5, 3.0, 4.0]
- name: alt_exit
  default: trail_3bar
  sweep_range: [trail_3bar, ma18_cross, donchian20_break, time_stop_5bars]
- name: primed_filter
  default: off
  sweep_range: [off, wvi_extreme, cot_12mo, sentiment_extreme, season_match, ANY_2_AGREE]
```

P3.5 (CSR) axis: re-run on Darwinex symbol cohort. **Multi-market generalization is Williams' explicit claim** ("works on all major markets" — workshop framing); CSR validates whether the volatility-expansion edge survives across:
- Index CFDs: US500.DWX, US100.DWX, GER40.DWX, UK100.DWX
- Metals: GOLD.DWX, XAGUSD.DWX
- Energies: OIL.DWX, NATGAS.DWX (if Darwinex offers; else flag)
- Spot FX: EURUSD.DWX, USDJPY.DWX, GBPUSD.DWX, AUDUSD.DWX
- Crypto (V5 boundary check: only if no T6 work touched): not applicable

## 9. Author Claims (verbatim, with quote marks)

Volatility breakout entry rule, PDF p. 25:

> "Volatility breakouts. Generally speaking, when the market is 'primed' I will buy at the open the next day +100% of the previous days range. This can be a smaller figure for some markets, [b]ut year in and year out it has been very good."

Bonds-specific N% disambiguation, PDF p. 37 (Bonds Specific Patterns wrap-up):

> "By and large a 30% volatility expansion works well in this market as well."

T-Bonds best-trade-day implementation note, PDF p. 43:

> "The rules are slightly different, buy on the opening of the day shown, plus 7% of the previous days range added to the opening. Use an $1,800 protective stop or exit on any profitable opening after 3 days."

3-Bar trail technique, PDF p. 21:

> "If so, and we are long, determine the highest close in the up move so far. Count that as day one and go back to get two more days. None of these can be an inside day. Once all three days have been noted, then determine the lowest true low of those three days. Place your stop to exit ... at that price."
>
> "If short determine the lowest close in the down move so far. Count that as day one and go back to get two more days. None of these can be an inside day. Once you have all three days note the highest true high. Place your stop to exit ... at that price."

Dollar-stop framing, PDF p. 21:

> "These major mega trades we are looking for have often made $5,000 to $10,000 a contract so I'm willing to use a stop of about $1,500 as final proof I am wrong."

**Williams provides NO numeric performance claim specific to the Volatility Breakout entry on its own** — the entry rule is presented as a generic technique to be combined with one of his upstream "set-up" tools. Numeric tables on PDF pp. 31, 37, 41, 44 reflect specific setup-combinations (Monday-buys / Bonds-with-Gold-filter / S&P holiday trades), not the bare volatility-breakout entry. Per BASIS rule, no extrapolated performance number is asserted in this card; pipeline P2-P9 produce the actual edge measurement.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.2                              # rough estimate; Williams' calling-card pattern with broad documented use across his career; expected positive but modest given multi-market generality
expected_dd_pct: 20                           # rough estimate; daily-bar breakout strategies typically 15-25% DD on D1 in V4 archive
expected_trade_frequency: 30-80/year/symbol   # rough estimate at N=100% threshold; lower at higher N; multi-market deployment scales accordingly
risk_class: medium                            # daily-bar single-symbol breakout; not scalping, not gridding; classic risk class
gridding: false
scalping: false                               # D1 bars; not scalping
ml_required: false                            # threshold + range arithmetic; no fitted parameters
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical (open ± N% × range arithmetic; deterministic stop-buy / stop-sell trigger)
- [x] No Machine Learning required
- [x] If gridding: not applicable (one open position per direction)
- [x] If scalping: not applicable (D1 bars)
- [x] Friday Close compatibility: 3-5 session typical hold; trail or hard-stop usually fires before Fri 21:00; V5 default Friday-close applies cleanly. No waiver required.
- [x] Source citation is precise enough to reproduce (PDF p. 25 entry rule + PDF p. 21 exit menu + PDF pp. 37, 43 N% disambiguations; verbatim quotes preserved)
- [x] No near-duplicate of existing approved card (`strategy-seeds/cards/`: SRC01 davey-* and SRC02 chan-* families differ — Davey cards are RSI/Bollinger/baseline patterns, Chan cards are stat-arb/cointegration/factor; no Williams family yet)

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "standard V5 default (kill-switch, news filter, MAX_DD trip, Friday-close); optional 'primed' filter and ATR-range floor as sweep axes"
  trade_entry:
    used: true
    notes: "stop-buy / stop-sell at next bar's open ± N% × range(prior_bar); single position per direction"
  trade_management:
    used: false
    notes: "no break-even, no partial close, no pyramiding; trail engages at first profitable close (close-out via § 5)"
  trade_close:
    used: true
    notes: "3-bar non-inside trail (Williams primary), or alt-exit (18-bar MA cross / 20-bar Donchian break / 5-bar time-stop) per P3 sweep"
```

```yaml
hard_rules_at_risk:
  - dwx_suffix_discipline                     # PRIMARY — Williams' deployment is futures (S&P / T-Bonds / commodities). V5 maps to .DWX CFDs / spot FX. Per-symbol map at G0 + CSR (P3.5) to validate generalization.
  - friday_close                              # NOT load-bearing — typical 3-5 session hold leaves Friday gap rarely binding. Listed here so CTO can confirm at G0 that no edge case forces a weekend hold.
  - enhancement_doctrine                      # load-bearing on N_PCT — Williams cites THREE distinct values (100% generic, 30% Bonds, 7% T-Bonds best-day rules). Initial value defaults to 100% per workshop; P3 sweep brackets [25-150]; any post-PASS retune of N_PCT is enhancement_doctrine.
  - news_pause_default                        # standard V5 P8 news-blackout applies; Williams does not address news explicitly but the "primed market" filter implicitly excludes pre-event chop. Default V5 gating handles it.

at_risk_explanation: |
  dwx_suffix_discipline — Williams' rules originate on US futures (CME / CBOT). V5 deploys on
  Darwinex .DWX CFD / spot FX symbols. Symbol-by-symbol map at G0 (CTO sanity-check). CSR P3.5
  runs the strategy across the index / metal / energy / FX cohort to validate that volatility-
  expansion-breakout edge is not a CME-microstructure artifact.

  friday_close — Williams' typical 3-5 session hold rarely reaches Friday 21:00. Default V5
  Friday-close applies cleanly. Listed for completeness so CTO can spot edge-case (e.g.,
  multi-week trail on a runaway move).

  enhancement_doctrine — N_PCT is the load-bearing parameter and Williams cites THREE values
  (100% generic, 30% Bonds, 7% T-Bonds best-day rules). The card defaults N_PCT = 100% per the
  workshop's primary statement and sweeps [25, 50, 75, 100, 125, 150] in P3. Once a live
  N_PCT is fixed at deployment, any subsequent retune is enhancement_doctrine.

  news_pause_default — V5 P8 news-blackout applies at high-impact macro events. Williams does
  not address this; standard framework gating handles it.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                               # standard V5 default; optional 'primed' filter and ATR floor as sweep axes
  entry: TBD                                  # stop-buy / stop-sell at session start each day; ~50-100 LOC in MQL5
  management: TBD                             # n/a (no break-even, no partial close)
  close: TBD                                  # 3-bar non-inside-day trail; alt-exit axes
estimated_complexity: small                   # straightforward range arithmetic + non-inside-day trail logic
estimated_test_runtime: 2-4h                  # P3 sweep (6×2×4×2×5×4×6 ≈ 11,500 cells; D1 bars; 10+ years; multi-market) — moderate
data_requirements: standard                   # D1 OHLC on Darwinex .DWX symbols; no external feeds
```

## 14. Pipeline History

| version | date | rebuild reason | P-stage reached | verdict |
|---|---|---|---|---|
| _v1 | 2026-04-28 | initial build | TBD | TBD |

## 15. Pipeline Phase Status (current `_v1`)

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-04-28 | DRAFT (awaiting CEO + Quality-Business review) | this card |
| P1 Build Validation | TBD | TBD | TBD |
| P2 Baseline Screening | TBD | TBD | TBD |
| P3 Parameter Sweep | TBD | TBD | TBD |
| P3.5 CSR | TBD | TBD | TBD |
| P4 Walk-Forward | TBD | TBD | TBD |
| P5 Stress | TBD | TBD | TBD |
| P5b Calibrated Noise | TBD | TBD | TBD |
| P5c Crisis Slices | TBD | TBD | TBD |
| P6 Multi-Seed | TBD | TBD | TBD |
| P7 Statistical Validation | TBD | TBD | TBD |
| P8 News Impact | TBD | TBD | TBD |
| P9 Portfolio Construction | TBD | TBD | TBD |
| P9b Operational Readiness | TBD | TBD | TBD |
| P10 Shadow Deploy | TBD | TBD | TBD |
| Live Promotion | TBD | TBD | TBD |

## 16. Lessons Captured

```text
- 2026-04-28: SRC03_S01 surfaces a NEW `strategy_type_flags` controlled-vocabulary GAP (entry side):
  `vol-expansion-breakout` — entry mechanism: stop-buy / stop-sell at next bar's open ± N% ×
  range(prior_bar). Distinct from `narrow-range-breakout` (which requires an explicit range-
  CONTRACTION precondition such as NR4/NR7) — Williams' rule fires on ANY prior bar's range
  scaled by N%, regardless of whether that range was unusually narrow. Distinct from `donchian-
  breakout` (which uses N-bar rolling extreme, not single prior-bar range). V4 had no equivalent
  SM_XXX EA per `strategy_type_flags.md` Mining-provenance table. Williams citation: PDF p. 25
  (primary) + p. 37 Bonds disambiguation + p. 43 T-Bonds best-day rules.
  Research will batch-propose this gap with subsequent SRC03 vocabulary findings (S02 gap-fade,
  S07 smash-pattern stop entry) once SRC03 extraction stabilizes.

- 2026-04-28: Williams provides NO numeric performance claim for the bare Volatility Breakout
  entry on its own — performance numbers in the source (e.g., $79,200 / 69% accuracy on PDF p. 31
  for "Monday-buys with bail-out + $1,750 stop") reflect specific setup-combinations, not the
  generic vol-bo entry. Per BASIS rule, no extrapolated number is asserted; § 9 cites only what
  the source verbatim quotes. Pipeline P2-P9 produce the actual edge measurement.

- 2026-04-28: Williams' "primed market" precondition (workshop §§ 1-8) is structurally
  optional — the bare entry rule is well-defined without it. Card extracts the bare rule and
  treats "primed" as an OPTIONAL P3-sweep filter axis. This is consistent with DL-033 Rule 1
  ("filters are documented per-card under § 6, not as separate Strategy Cards") and SRC03
  source.md § 6 (filters NOT extracted as separate cards).

- 2026-04-28: V5-architecture-fit profile is FAVOURABLE — single-symbol, daily bars, no
  multi-leg / multi-stock / cointegration architecture concerns. First clean architectural fit
  in SRC03 family (vs SRC02 Chan where 4/8 cards were multi-stock-incompatible). Expected G0
  yield CLEAN.
```
