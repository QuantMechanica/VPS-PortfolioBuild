# Strategy Card — Williams Pro-Go (Public-vs-Professional A/D divergence + line-crossing entry/timing)

> Drafted by Research Agent on 2026-05-01 from `strategy-seeds/sources/SRC03/raw/full_text.txt` lines 905-936 (verbatim Williams "ENTRY TECHNIQUES — § 4. A NEW INDICATOR PRO-GO" PDF p. 18). Closes a SRC03 first-pass survey omission: the original SRC03 source.md candidate table tabulated PDF p. 17 (18-Bar MA → S12), p. 19 (Smash → S07; Fake Out → S08), p. 20 (Naked Close → S09; Specialist Trap → S10) but **skipped p. 18 § 4 Pro-Go**, which Williams himself frames as an "entry or timing technique" — i.e. a Strategy Card candidate, not a workshop §§ 1-8 setup-filter. Authority for revisiting: QUA-664 (OWNER bounded supersede of DL-044, Card 1 of 2 in 7-day backlog).
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per DL-032 + DL-030 Class 2 Review-only execution policy).

## Card Header

```yaml
strategy_id: SRC03_S16
ea_id: TBD
slug: williams-pro-go
status: DRAFT
created: 2026-05-01
created_by: Research
last_updated: 2026-05-01

strategy_type_flags:
  - atr-hard-stop                              # Williams' canonical $1,500 dollar-stop framing (PDF p. 21) — V5 ATR-equivalent translation
  - symmetric-long-short                       # Williams: divergence + crossing rules stated symmetrically (price low → bullish; price high → bearish)
  - friday-close-flatten                       # V5 default; Williams characterises Pro-Go signals as "intermediate term" — typical hold spans days-to-weeks; default Friday-close applies, weekly-cycle waiver candidate noted in § 12
  - signal-reversal-exit                       # Williams: line-crossing entry implies opposite-crossing exit (signal-reversal) per the "crossings ... excellent intermediate, term buy and sell signal" framing
  # PROPOSED NEW VOCAB GAP (entry-mechanism): `flow-divergence-crossover` — see § 16 Lessons + future-vocab-watches
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Williams, Larry R. (1999). Long-Term Secrets to Short-Term Trading. Wiley Trading. New York: John Wiley & Sons."
    location: "PDF p. 18 (Inner Circle Workshop companion volume), § 'ENTRY TECHNIQUES — 4. A NEW INDICATOR PRO-GO'. Cross-references: PDF p. 17 (18-Bar MA, the indicator's structural sibling — same 'two-line crossover' mechanic), PDF pp. 20-21 § 'WHEN TO EXIT' (sub-sections 1 'Least Favorite Exit' = $1,500 dollar stop, 2 'Amazing 3 Bar Entry/Exit'). Williams cites worked-example chart pages (PDF pp. 93-100, 'See Pages 93 Through 100') that fall in the OCR-degraded range of the source text — Research could not extract numerical examples, only the indicator definition and two entry-rule families."
    quality_tier: A
    role: primary
```

Raw evidence: `strategy-seeds/sources/SRC03/raw/full_text.txt` lines 905-936 (indicator definition + two entry-rule families verbatim) and lines 1108 (Williams' own retrospective placement: "break outs Pro/Go, seasonal indications and all the other tricks of our trades", confirming Pro-Go is a top-of-mind entry technique alongside breakouts and seasonality, not a §§ 1-8 setup filter). Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Long-Term Secrets to Short-Term - Larry R. Williams.pdf`.

## 2. Concept

A **derived-signal divergence + line-crossover system** built from the daily decomposition of price change into two flow components: the **overnight gap** (close[t-1] → open[t], framed by Williams as "public" buying) and the **intraday session move** (open[t] → close[t], framed as "professional" buying). Williams' thesis: separating these two components reveals when retail / news-driven flow (overnight gaps) and institutional / session flow (intraday moves) AGREE versus DIVERGE — and divergence/crossover regimes are tradeable intermediate-term entry signals.

Williams' verbatim framing, PDF p. 18:

> "Many, many years ago I wrote about how to separate public buying from professional buying. The essence of the technique was to create an A/D line for the public that shows the change from yesterdays close to today's open. The professional A/D line is then constructed by using the change from today's open to today's close. Those two lines clearly 'tip' us as to what is really [happening]."
>
> "We can take this one step farther by simply constructing an index of the previous close to open +/- values and then taking a 14 day average which is plotted against a 14 day average of the +/- values of the open to close."
>
> "I can see at least two ways to use this data, and there may be more. The first is to simply look for divergences between price and the Professional index. Price lows not matched by the Pro index are bullish. New highs not matched by this index tend to be bearish."
>
> "Additionally, crossings of these two indicators have given some excellent intermediate, term buy and sell signal as the charts below depict. This can be used as an entry or timing technique with the rules as provided at the seminar."

This card extracts BOTH entry families Williams names: (A) **Pro-vs-price divergence** at swing highs/lows, and (B) **Pro-vs-Public line crossing**. Entry default = Rule B (crossing — fully mechanical, deterministic given indicator values) since Rule A's "new low" / "new high" lookback is not specified verbatim and is enhancement_doctrine load-bearing. Williams' explicit "rules as provided at the seminar" pointer (PDF p. 18) references chart pages 93-100 which are OCR-degraded in the supplied PDF — V5 cannot recover the seminar specifics, so the card encodes the verbatim mechanical core and exposes the under-specified pieces as P3 sweep axes.

## 3. Markets & Timeframes

```yaml
markets:                                       # Williams' deployment universe is multi-market futures + currency / commodity futures; the indicator is generic to any asset with a daily open / close
  - index_futures                              # Williams' deployment context: S&P 500 + T-Bonds futures (cf. SRC03 § "Inside Circle Short-Term Trading Approach"). V5 proxy: US500.DWX
  - bond_futures                               # Williams' deployment context: T-Bonds. V5 proxy: bond CFD if Darwinex offers; else flag dwx_suffix_discipline
  - commodities                                # Williams workshop covers Wheat, Cotton, Pork Bellies, Copper, Sugar, Coffee, Beans, Gold (cf. SRC03_S12 18-Bar MA 14-symbol backtest spans these). V5 proxy: GOLD.DWX, OIL.DWX, NATGAS.DWX where Darwinex offers.
  - forex                                      # Williams workshop covers Swiss Franc, D-Mark, B-Pound, J-Yen futures. V5 proxy: spot Darwinex .DWX FX symbols. Pro-Go is generic — the public/pro decomposition only requires open + close per session.
timeframes:
  - D1                                         # Williams: rules stated on daily bars (open[t], close[t], close[t-1]); 14-day MA implies daily-bar context
  - H4                                         # plausible D1-derivative for parameter sweep — would require redefining "overnight gap" as "session-close gap" (sweep axis)
session_window: not specified                  # signal evaluated at daily close; entry actionable on next bar
primary_target_symbols:
  - "S&P 500 futures (Williams' deployment) → US500.DWX V5 proxy"
  - "T-Bonds futures (Williams' deployment) → bond CFD if available; else flag dwx_suffix_discipline"
  - "GOLD.DWX, EURUSD.DWX, USDJPY.DWX as multi-market generalization (Pro-Go is symbol-generic — only requires open / close per daily bar)"
```

## 4. Entry Rules

Pseudocode — verbatim translation of Williams PDF p. 18 § 4 indicator definition + the two entry families he names ("divergences between price and the Professional index" and "crossings of these two indicators"). The crossing rule is the deterministic default; the divergence rule is an alternative-entry P3 sweep axis.

```text
PARAMETERS:
- MA_PERIOD         = 14         // Williams: "taking a 14 day average" (PDF p. 18, verbatim)
- BAR               = D1
- SIGNAL_MODE       = sign       // "an index of the previous close to open +/- values" — Williams' "+/- values"
                                 //   wording is ambiguous: (a) +/- 1 sign-only (so the 14-day MA is the signed-day count
                                 //   ratio in [-1, +1]), or (b) the raw signed magnitude (so the 14-day MA is the average
                                 //   signed gap / session move in instrument units). Default = SIGNED_VALUE; sign-only
                                 //   exposed as P3 sweep axis.
- DIVERGENCE_LOOKBACK = 20       // P3 sweep axis ONLY for Rule A; Williams does not specify
- DIVERGENCE_TOLERANCE = 0       // pips/units of slack on "matching" the prior extreme (P3 axis)

INDICATOR (computed at bar close each day):
- public_change[t] = Open[t] - Close[t-1]                       // Williams: "change from yesterdays close to today's open"
- pro_change[t]    = Close[t] - Open[t]                         // Williams: "change from today's open to today's close"
- public_line[t]   = SMA(public_change, MA_PERIOD)              // Williams: "14 day average of [public_change values]"
- pro_line[t]      = SMA(pro_change,    MA_PERIOD)              // Williams: "14 day average of the +/- values of the open to close"
   // SIGNAL_MODE = sign sweep variant: replace public_change[t] with sign(public_change[t]) before the SMA, idem for pro_change[t]

ENTRY — RULE B (CROSSING, default; deterministic):
- if pro_line[t] crosses_above public_line[t]
    AND not in position
  then OPEN_LONG at next-bar open  (or stop-buy at next-bar open + small offset, configurable)
- if pro_line[t] crosses_below public_line[t]
    AND not in position
  then OPEN_SHORT at next-bar open

ENTRY — RULE A (DIVERGENCE, P3 alternative-entry axis):
- bullish divergence: Low[t] = MIN(Low[t-DIVERGENCE_LOOKBACK..t])  // price prints a new N-bar low
                   AND pro_line[t] > MIN(pro_line[t-DIVERGENCE_LOOKBACK..t]) + DIVERGENCE_TOLERANCE
                                                                  // Pro line did NOT match the price low
                   then OPEN_LONG at next-bar open
- bearish divergence: High[t] = MAX(High[t-DIVERGENCE_LOOKBACK..t])
                   AND pro_line[t] < MAX(pro_line[t-DIVERGENCE_LOOKBACK..t]) - DIVERGENCE_TOLERANCE
                   then OPEN_SHORT at next-bar open

EXCLUSIVITY: one open position per direction per symbol; no pyramiding.
DUAL-FIRE HANDLING: if both Rule B crossing and Rule A divergence fire on the same bar in the
  SAME direction → take the position (signal confluence). If they fire in OPPOSITE directions
  → no entry (regime ambiguity); wait for next bar.
```

Williams does not specify whether the entry is at-market on the close, at next-bar open, at a stop-buy/sell offset above/below the close, or at a limit through the close. Card adopts **next-bar open** as the conservative reading consistent with his other PDF p. 17-21 entry techniques (18-Bar MA, Failure Day Family, Volatility Breakout) which all stage triggers at the day's open or as next-day stop-orders. Stop-buy / stop-sell variants are P3 sweep axes.

## 5. Exit Rules

Williams pairs Pro-Go entries with the same generic exit menu he documents on PDF pp. 20-21 (§ "When to Exit" — applicable to all Entry Techniques in § 1-7, not Pro-Go-specific). The default exit is the dollar-stop + 3-bar trailing combo per the SRC03 family convention; signal-reversal (opposite Pro-vs-Public crossing) is a natural Pro-Go-specific alternative-exit axis.

> **3-bar trail spec ratified at `framework/V5_TM_MODULES.md` § TM-3BAR-TRAIL** (Williams PDF p. 21; CEO ratified 2026-04-28 in QUA-298 closeout). The pseudocode below is retained inline and matches the canonical TM-module spec.

```text
DEFAULT EXIT (dollar stop + 3-bar trail combo + signal-reversal close):
PARAMETERS:
- HARD_STOP_USD     = 1500       // Williams PDF p. 21 generic "$1,500 as final proof I am wrong"
                                 //   V5 translation: ATR-scaled hard stop at entry; ATR(14) × {1.5..3.0} sweep
- TRAIL_BARS        = 3          // Williams' "Amazing 3 Bar Entry/Exit Technique" PDF p. 21
- TRAIL_NO_INSIDE   = true       // Williams: "None of these can be an inside day"
- TRAIL_ACTIVATE    = first_close_in_profit
- SIGNAL_REVERSAL_EXIT = true    // Pro-Go-specific: exit when Pro vs Public lines cross AGAINST the open position

EACH-BAR (in position):
- HARD STOP — fires at HARD_STOP_USD-equivalent ATR distance from entry; never moves
- TRAIL (activates after first profitable close OR position has held 3 non-inside bars):
  if LONG:
    trail_anchor_close = highest_close_since_entry
    trail_window = three most recent non-inside bars ending at the bar of trail_anchor_close
    trail_level = MIN( true_low(b) for b in trail_window )
    if Low[t] <= trail_level: CLOSE_LONG at trail_level (or next-bar open if gap-through)
  if SHORT: mirror — lowest_close_since_entry / true_high / max(true_high)
- SIGNAL_REVERSAL EXIT (default ON):
  if LONG  and pro_line[t] crosses_below public_line[t]: CLOSE_LONG at next-bar open
  if SHORT and pro_line[t] crosses_above public_line[t]: CLOSE_SHORT at next-bar open

FRIDAY CLOSE: V5 default applies (force-flat at Friday 21:00 broker time). Williams characterises
Pro-Go signals as "intermediate, term buy and sell signal" — typical holds may span 1-3 weeks
which means Friday-close binds. Default V5 force-flat-Friday applies; the long-hold signal-
reversal-exit may produce mid-week close-out; ANY waiver request is noted at G0 for CEO
decision. Per V5 default, no waiver is asserted by this card.
```

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults: kill-switch, news filter, MAX_DD trip, Friday Close
- pyramiding: NOT allowed (one position per direction per symbol)
- gridding: NOT allowed
- BURN-IN: skip first MA_PERIOD × 2 = 28 bars after deployment so both 14-day SMAs are stable
- "primed market" optional confluence filter (P3 sweep axis): trade only when at least ONE of
  Williams' workshop §§ 1-8 setup tools agrees with the Pro-Go entry direction (WVI / COT / DMI /
  Sentiment / Seasonal). Off by default; on as axis variant for high-conviction filter test.
  Same filter framework as williams-vol-bo § 6.
- ATR floor (P3 sweep axis): skip entries when ATR(14) < ATR(50) × 0.5
  // Rationale: Pro-Go's two 14-day-MA components both flatten in extreme low-volatility regimes,
  //   producing whipsaw crossings near zero; an ATR floor avoids signal density spikes during
  //   choppy compression phases. Williams does not address this; default OFF, sweep axis ON.
```

## 7. Trade Management Rules

```text
- one open position per direction per symbol at any time (no pyramiding, no stacking)
- position size: maps to V5 risk-mode framework at sizing-time;
  Williams' explicit money-management formula (PDF pp. 28-31) uses fixed-fractional with
  20% of equity divided by largest accepted loss = number of contracts. V5 adapts to its
  own RISK_PERCENT / RISK_FIXED switch.
- Friday Close: forced flat per V5 default
- gridding: NOT allowed
- "intermediate term" Williams hold-horizon implication: V5 does not impose a maximum hold;
  trail / signal-reversal / hard-stop / Friday-close handle exit. Time-stop sweep axis
  (5/10/20 bars) exposed in P3 for sensitivity testing.
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: ma_period
  default: 14                                  # Williams: "14 day average" (PDF p. 18, verbatim)
  sweep_range: [7, 10, 14, 21, 28]             # bracket [half, 2x] around Williams' default
- name: signal_mode
  default: signed_value                        # raw daily +/- magnitude (default reading of Williams' "+/- values")
  sweep_range: [signed_value, sign_only]       # sign-only variant per ambiguity in Williams' wording
- name: entry_rule
  default: crossing                            # Williams' Rule B — fully mechanical, deterministic
  sweep_range: [crossing, divergence, both_or_either, both_and_confluence]
- name: divergence_lookback
  default: 20                                  # Williams does not specify; 20 = standard short-term swing window
  sweep_range: [10, 15, 20, 30, 50]            # only relevant when entry_rule includes divergence
- name: divergence_tolerance_pct
  default: 0                                   # exact-match default; ATR-fraction tolerance for noise
  sweep_range: [0, 0.10, 0.25, 0.50]           # × ATR(14) — only when entry_rule includes divergence
- name: entry_timing
  default: next_open_market                    # safest mechanical reading of Williams
  sweep_range: [close_market, next_open_market, next_open_stop_offset]
- name: signal_reversal_exit
  default: true                                # natural Pro-Go-specific exit
  sweep_range: [true, false]
- name: trail_bars
  default: 3                                   # Williams TM-3BAR-TRAIL
  sweep_range: [2, 3, 4, 5]
- name: hard_stop_atr_mult
  default: 2.0                                 # ATR-equivalent of Williams' $1,500
  sweep_range: [1.5, 2.0, 2.5, 3.0, 4.0]
- name: alt_exit
  default: trail_3bar_plus_signal_reversal
  sweep_range: [trail_3bar_plus_signal_reversal, trail_3bar_only, signal_reversal_only, time_stop_10bars]
- name: primed_filter
  default: off
  sweep_range: [off, wvi_extreme, cot_12mo, sentiment_extreme, season_match, ANY_2_AGREE]
- name: atr_floor
  default: off
  sweep_range: [off, 0.25, 0.50, 0.75]         # × ATR(50)
```

P3.5 (CSR) axis: re-run on Darwinex symbol cohort. Pro-Go is a generic public-vs-pro flow decomposition — applicable to any asset with a daily open / close. CSR validates whether the divergence/crossover edge survives across:
- Index CFDs: US500.DWX, US100.DWX, GER40.DWX, UK100.DWX
- Metals: GOLD.DWX, XAGUSD.DWX
- Energies: OIL.DWX, NATGAS.DWX (if Darwinex offers)
- Spot FX: EURUSD.DWX, USDJPY.DWX, GBPUSD.DWX, AUDUSD.DWX

## 9. Author Claims (verbatim, with quote marks)

Pro-Go indicator definition, PDF p. 18:

> "Many, many years ago I wrote about how to separate public buying from professional buying. The essence of the technique was to create an A/D line for the public that shows the change from yesterdays close to today's open. The professional A/D line is then constructed by using the change from today's open to today's close. Those two lines clearly 'tip' us as to what is really [happening]."

Indicator construction (14-day MA framing), PDF p. 18:

> "We can take this one step farther by simply constructing an index of the previous close to open +/- values and then taking a 14 day average which is plotted against a 14 day average of the +/- values of the open to close."

Two entry families, PDF p. 18:

> "I can see at least two ways to use this data, and there may be more. The first is to simply look for divergences between price and the Professional index. Price lows not matched by the Pro index are bullish. New highs not matched by this index tend to be bearish."
>
> "Additionally, crossings of these two indicators have given some excellent intermediate, term buy and sell signal as the charts below depict. This can be used as an entry or timing technique with the rules as provided at the seminar."

Williams' retrospective placement of Pro-Go alongside the breakout / seasonality core entry techniques (i.e., NOT a §§ 1-8 setup-filter), PDF text-clean range line 1108:

> "[I use] break outs Pro/Go, seasonal indications and all the other tricks of our trades."

**Williams provides NO numeric performance claim** for Pro-Go on its own. Williams cites worked-example chart pages ("See Pages 93 Through 100" at the end of § 4) which fall in the OCR-degraded range of the supplied PDF — Research could not recover the seminar's specific entry rules or backtest figures. Williams' qualitative framing is positive ("excellent intermediate, term buy and sell signal") but no win-rate, Sharpe, drawdown, or cumulative-P&L number is asserted. Per BASIS rule, no extrapolated performance number is asserted in this card; Pipeline P2-P9 produce the actual edge measurement.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.15                              # rough estimate; derived-signal divergence/crossover systems on D1 typically produce modest positive expectancy with moderate signal density; under bare 14-MA crossing with no filter, expect noisy mid-1.0s PF
expected_dd_pct: 22                            # rough estimate; 14-day MA crossover on derived flow series will whipsaw in choppy regimes; 20-25% DD typical for D1 crossover systems pre-filter
expected_trade_frequency: 12-30/year/symbol    # rough estimate; 14-day MA-of-MA crossings on a single symbol typically produce 1-2 crossings per month → ≈12-24/yr; divergence rule layered adds ~6-15/yr
risk_class: medium                             # daily-bar single-symbol derived-signal crossover; not scalping, not gridding
gridding: false
scalping: false                                # D1 bars
ml_required: false                             # SMA arithmetic + threshold logic; no fitted parameters
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical (deterministic SMA-of-derived-signal computation; mechanical crossing rule; divergence rule mechanical given lookback parameter)
- [x] No Machine Learning required
- [x] If gridding: not applicable (one open position per direction)
- [x] If scalping: not applicable (D1 bars)
- [x] Friday Close compatibility: 14-day-MA crossover holds may span 1-3 weeks; default V5 Friday-close applies and may close mid-trade — flagged in § 12 as `friday_close` LOAD-BEARING for review. No waiver asserted; CEO decides at G0.
- [x] Source citation is precise enough to reproduce (PDF p. 18 § 4 indicator + entry rules; verbatim quotes preserved; OCR-degraded chart-pages 93-100 limitation explicitly documented)
- [x] No near-duplicate of existing approved card (`strategy-seeds/cards/`: SRC03 williams-* family covers volatility-breakout, calendar-bias, OOPS gap-fade, Failure-Day-Family rejection-bar, narrow-range, MA-stack, single-MA-trend filter — none use Pro-Go's public/pro flow decomposition; V4 SM_419 ProGo is a NAMING-COINCIDENT but mechanically distinct intraday pivot break-and-go pattern per `strategy_type_flags.md` `intraday-session-pattern` flag — see § 16 disambiguation)

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "standard V5 default (kill-switch, news filter, MAX_DD trip, Friday-close); 28-bar burn-in for SMA stability; optional 'primed' filter and ATR floor as P3 sweep axes"
  trade_entry:
    used: true
    notes: "Pro-vs-Public 14-day-MA crossing (default Rule B) OR price-vs-Pro divergence (Rule A, P3 axis); next-bar open entry"
  trade_management:
    used: false
    notes: "no break-even, no partial close, no pyramiding; trail engages at first profitable close; signal-reversal monitored each bar"
  trade_close:
    used: true
    notes: "3-bar non-inside trail (Williams primary) + signal-reversal exit (Pro-Go-specific) + hard-stop ATR-equivalent of $1,500"
```

```yaml
hard_rules_at_risk:
  - dwx_suffix_discipline                      # Williams' deployment is futures (S&P / T-Bonds / commodities). V5 maps to .DWX CFDs / spot FX. Per-symbol map at G0 + CSR (P3.5) to validate generalization — Pro-Go is symbol-generic but the empirical edge may be CME-microstructure-dependent.
  - friday_close                               # LOAD-BEARING — Williams characterises Pro-Go as "intermediate, term" signal; 14-day-MA crossover holds typically span 1-3 weeks → Friday-close BINDS frequently. Default V5 force-flat applies; CEO decision at G0 on whether to assert waiver candidate based on multi-week-hold thesis.
  - enhancement_doctrine                       # LOAD-BEARING on three under-specified axes: (1) SIGNAL_MODE — Williams' "+/- values" wording is ambiguous (sign-only vs signed-magnitude); (2) entry_rule — Williams names two rules but does not specify confluence policy; (3) divergence_lookback — Williams does not specify "new low" / "new high" lookback. P3 sweep brackets all three; any post-PASS retune is enhancement_doctrine.
  - news_pause_default                         # standard V5 P8 news-blackout applies. Pro-Go specifically encodes overnight-gap (public_change) which IS news-flow proxy — extreme high-impact news days will spike the public_line and may produce false crossings in the next 14 days. P8 default gating is appropriate and minimum sufficient; no Pro-Go-specific override asserted.

at_risk_explanation: |
  dwx_suffix_discipline — Williams' rules originate on US futures (CME / CBOT). V5 deploys on
  Darwinex .DWX CFD / spot FX symbols. Symbol-by-symbol map at G0 (CTO sanity-check). CSR P3.5
  runs Pro-Go across the index / metal / energy / FX cohort to validate that the public/pro flow-
  decomposition edge is not a CME-microstructure artifact. Pro-Go's mechanic (overnight gap +
  intraday session decomposition) requires that the deployed symbol HAS a meaningful overnight
  gap — for 24/5 spot FX, the "overnight gap" is the broker-end-of-day rollover gap (typically
  near-zero for major pairs); the indicator may degenerate into pro_line-dominant on FX vs
  Williams' US-futures setting where overnight gaps carry real overnight news flow. CSR P3.5
  cohort validates whether the edge survives this regime difference.

  friday_close — LOAD-BEARING. Williams calls Pro-Go an "intermediate, term" signal; expected hold
  on a 14-day-MA-of-flow crossover is 1-3 weeks. V5 default Friday-close force-flat will close
  many trades mid-week; this changes the strategy from "hold to signal-reversal" to "hold to
  next-Friday-21:00 OR signal-reversal whichever first." If the empirical edge is concentrated in
  the multi-week tail of crossings, Friday-close may degrade PF by ≥30%. CEO decision at G0:
  (a) accept default Friday-close as-is and let pipeline measure the impact; (b) ask CTO to
  consider whether Pro-Go qualifies for a `friday_close` waiver (precedent: SRC02_S01 chan-pairs-
  stat-arb received unconditional waiver due to OU-half-life-driven exit; SRC04_S09 lien-perfect-
  order received conditional waiver candidacy for multi-month MA-stack hold); (c) set a hold-cap
  rule (close at first Friday after K days, K to be swept).

  enhancement_doctrine — Three under-specified axes with verbatim Williams ambiguity:
    1. SIGNAL_MODE — "an index of the previous close to open +/- values" (PDF p. 18). The +/-
       wording supports either sign-only (index in {-1, 0, +1} per day) or signed-magnitude (raw
       gap / session move in instrument units). Default = SIGNED_VALUE (more information-preserving);
       SIGN_ONLY exposed as P3 sweep axis to validate Williams' likely intent.
    2. entry_rule — Williams names Rule A (divergence) and Rule B (crossing) but does not specify
       confluence/precedence. Default = Rule B alone (deterministic); Rule A + Rule B as an
       OR-rule, AND-rule (confluence), or A-only are P3 sweep axes.
    3. divergence_lookback — Rule A requires defining "new low" / "new high" lookback. Williams
       does not specify. P3 sweep brackets [10, 15, 20, 30, 50] with default 20 (standard short-
       term swing window). Any post-PASS retune is enhancement_doctrine.
  All three are documented; the card defaults are the conservative-mechanical readings; P3
  exposes the sensitivity space.

  news_pause_default — V5 P8 news-blackout applies at high-impact macro events. Pro-Go encodes
  overnight-gap as one of its two flow components; news-driven gaps will spike public_line and
  could produce false crossings during the 14-day MA window. P8 default gating handles event-
  windows; no Pro-Go-specific override is asserted. CTO at G0 may want to confirm that P8 gating
  ALSO suppresses the indicator update on news days (vs only the entry trigger), to avoid the
  14-day MA polluting on high-impact days; this is a CTO implementation detail.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                                # standard V5 default + 28-bar SMA burn-in
  entry: TBD                                   # Pro-line / Public-line crossing detection + optional divergence detector with lookback
  management: TBD                              # n/a (no break-even, no partial close)
  close: TBD                                   # 3-bar non-inside trail + signal-reversal-exit + hard-stop
estimated_complexity: small                    # two SMAs of derived daily series + crossing/divergence logic + 3-bar trail; ~150 LOC MQL5
estimated_test_runtime: 4-8h                   # P3 sweep (5×2×4×5×4×3×2×4×5×4×6×4 cells; smaller subspace under default Rule-B-only ≈ 5×2×4×5×6×4 ≈ 4,800; D1 bars; 10+ years; multi-market) — moderate
data_requirements: standard                    # D1 OHLC on Darwinex .DWX symbols; no external feeds
```

## 14. Pipeline History

| version | date | rebuild reason | P-stage reached | verdict |
|---|---|---|---|---|
| _v1 | 2026-05-01 | initial build | TBD | TBD |

## 15. Pipeline Phase Status (current `_v1`)

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-05-01 | DRAFT (awaiting CEO + Quality-Business review) | this card |
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
- 2026-05-01: SRC03_S16 closes a SRC03 first-pass survey omission. The original SRC03 source.md
  candidate table tabulated PDF p. 17 (18-Bar MA → S12), p. 19 (Smash Day → S07; Fake Out Day →
  S08), p. 20 (Naked Close → S09; Specialist Trap → S10), p. 21 (3-Bar Exit → S13 ESCALATED) but
  SKIPPED PDF p. 18 § 4 "A NEW INDICATOR PRO-GO". This was a Research-side oversight: Pro-Go is
  Williams' own self-described "entry or timing technique" (PDF p. 18), not a workshop §§ 1-8
  setup-filter. SRC03 completion-report pre-classification of §§ 1-8 as filters was correct as
  applied (WVI / COT / DMI/ADX / Pinch/Paunch / Sentiment / Seasonal / Open Interest / Spreads
  ARE filters), but Pro-Go sits in § "Entry Techniques" between 18-Bar MA (§ 3) and Failure Day
  Family (§ 5) and was structurally an extracted-card candidate. Authority for revisiting:
  QUA-664 (OWNER bounded supersede of DL-044, Card 1 of 2 in 7-day backlog, 2026-05-01).

- 2026-05-01: PROPOSED NEW VOCAB GAP (entry-mechanism) — `flow-divergence-crossover`. Pro-Go is a
  derived-signal divergence + line-crossover system on the daily decomposition of price change
  into overnight (public) + intraday (professional) flow components. Distinct from existing
  entry-mechanism flags:
  - `vol-expansion-breakout` (entry on stop-buy at next-bar open + N% × range; Pro-Go is on a
    14-day MA crossing of two derived series, not a price-based stop-trigger);
  - `donchian-breakout` / `n-period-max-continuation` / `narrow-range-breakout` (all use raw price
    extremes; Pro-Go uses derived-signal MAs);
  - `trend-filter-ma` (single-MA filter; Pro-Go is a two-MA-crossing trigger ON DERIVED DATA, not
    on price);
  - `signal-reversal-exit` (exit-mechanism; Pro-Go is an entry-mechanism that pairs naturally
    with signal-reversal on the same crossing — listed in Header strategy_type_flags as the
    paired exit, separate from the entry trigger).
  Williams' Pro-Go is the FIRST V5 card on a derived-signal flow decomposition. V4 had no
  equivalent EA per `strategy_type_flags.md` Mining-provenance table — the V4 SM_419 ProGo is a
  NAMING-COINCIDENT but mechanically distinct intraday pivot break-and-go pattern (per the
  existing `intraday-session-pattern` flag entry), not a 14-day flow-decomposition crossover.
  Vocab proposal deferred to a future SRC03 vocab back-port follow-up issue OR batched with the
  SRC02/SRC03/SRC04 future-vocab-watch family at next ratification cycle. Until ratified, Header
  strategy_type_flags lists the strict-existing-vocabulary subset only; the proposed-new flag
  appears in Header as a comment annotation.

- 2026-05-01: NAMING-COINCIDENT DISAMBIGUATION (Williams Pro-Go vs V4 SM_419 ProGo). V4's
  star-EA reference (`reference/v4_doc/star-ea-reference.md`) lists SM_419 ProGo as a "pivot
  break-and-go pattern" with "Strong USDCHF sample" — this is an INTRADAY pattern based on
  pivot-point breaks. Williams' Pro-Go (this card, SRC03_S16) is a DAILY indicator built from
  open/close decomposition with 14-day MAs. The names share "Pro-Go" / "Pro/Go" wording (Williams
  in his own retrospective uses "Pro/Go" — see § 9 author-claim citation lines 1108) which may
  cause CTO / Pipeline-Op / Documentation-KM confusion. Card slug `williams-pro-go` and the
  `strategy_type_flags` entry `flow-divergence-crossover` (proposed) preserve the distinction.
  V4's SM_419 ProGo flag is `intraday-session-pattern` (alongside SM_221 SilverBullet); V5's
  williams-pro-go flag is `flow-divergence-crossover` (proposed). No V4-to-V5 inheritance
  relationship — Williams' indicator is V5-net-new vocabulary territory.

- 2026-05-01: Williams provides NO numeric performance claim for Pro-Go on its own — chart pages
  93-100 he references for examples are OCR-degraded in the supplied PDF (text-clean range is
  pp. 1-46 per SRC03 source.md § 2). Per BASIS rule, no extrapolated number is asserted in § 9;
  the entry rule + indicator definition are the verbatim mechanical content available. Pipeline
  P2-P9 produce the actual edge measurement. If P2 baseline screening reveals Pro-Go is a
  high-edge / low-DD strategy on a Darwinex symbol cohort, a follow-up Research task may attempt
  re-OCR of the supplied PDF chart pages (pdftotext -raw + tesseract fallback) to recover the
  seminar's specific entry rules — defer to extraction-time-2 only if pipeline signals warrant it.

- 2026-05-01: V5-architecture-fit profile is FAVOURABLE — single-symbol, daily bars, no multi-
  leg / multi-stock / cointegration architecture concerns. Pro-Go is symbol-generic (only
  requires daily open + close), so CSR P3.5 generalization should expose how broadly the
  public/pro flow-decomposition edge holds across Darwinex .DWX CFD / spot FX cohort. The 24/5
  spot FX context differs from Williams' US-futures regime (overnight gaps in spot FX are
  typically near-zero rollover gaps vs Williams' US-futures session-end gaps that carry real
  overnight news flow) — this is the primary CSR sensitivity dimension to validate.
```
