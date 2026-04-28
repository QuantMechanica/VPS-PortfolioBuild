# Strategy Card — Chan AT Opening-Gap Momentum on FSTX (futures + currencies, gap-go-with at session open with σ-band trigger and exit at close)

> Drafted by Research Agent on 2026-04-28 from `strategy-seeds/sources/SRC05/raw/full_text.txt` lines 7012-7066 (Ex 7.1 verbatim MATLAB + FSTX/GBPUSD performance + Chan's causal explanation of the gap-mechanism).
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per QUA-188 waiver v3).

## Card Header

```yaml
strategy_id: SRC05_S12
ea_id: TBD
slug: chan-at-fstx-gap-mom
status: DRAFT
created: 2026-04-28
created_by: Research
last_updated: 2026-04-28

strategy_type_flags:
  - opening-gap-momentum                        # NEW VOCAB GAP — entry mechanism: long if today_open > prev_high * (1 + entryZscore * 90d_close-to-close_stdret), short if today_open < prev_low * (1 - entryZscore * 90d_close-to-close_stdret); position held one session and liquidated at the close. Distinct from gap-fade-stop-entry (opposite direction; that flag is FADE the gap with calendar-pattern + stop-entry placed back); distinct from vol-expansion-breakout (next-bar open + N% × prior-day-range projection rather than prev-bar-extreme + σ-band scale). Sibling proposal — direction-mirror of gap-fade-stop-entry and S03 chan-at-buy-on-gap (gap-FADE in the cross-sectional-screen specialization).
  - time-stop                                   # exit mechanism: positions liquidated at session close on the same calendar bar (open-to-close hold, ≤ 1 day duration)
  - symmetric-long-short                        # both gap-up→long and gap-down→short directions deployable from the same source rule (Chan's positions(longs)=1; positions(shorts)=-1)
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Chan, Ernest P. (2013). Algorithmic Trading: Winning Strategies and Their Rationale. Wiley Trading. Hoboken, NJ: John Wiley & Sons. ISBN 978-1-118-46014-6 (cloth) / 978-1-118-46019-1 (ebk)."
    location: "Chapter 7 'Intraday Momentum Strategies', § 'Opening Gap Strategy' (PDF pp. 156-157 / printed pp. 156-157). Example 7.1 'Opening Gap Strategy for FSTX' (PDF p. 156 / printed p. 156) is the primary FSTX (Dow Jones STOXX 50 index futures, Eurex) case with full MATLAB code and 2004-2012 performance. Inline GBPUSD currency-pair generalization (PDF p. 157) with redefined 'open' = 5:00 a.m. ET (London open) and 'close' = 5:00 p.m. ET, weekend gap interpretation."
    quality_tier: A
    role: primary
```

Raw evidence: `strategy-seeds/sources/SRC05/raw/full_text.txt` lines 7012-7066 (extracted via `pdftotext -layout` 2026-04-28). Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Algorithmic Trading_ Winning St - Ernie Chan.pdf`.

## 2. Concept

A **single-instrument intraday opening-gap momentum strategy** that goes WITH the gap direction at the session open and liquidates at the session close. The σ-band trigger requires the gap to clear prior-bar high (resp. low) by `entryZscore` multiples of the 90-day close-to-close return-volatility, filtering noise gaps. Chan motivates the go-with (vs. fade) direction structurally — the opposite of his Ch4 cross-sectional buy-on-gap MR for stocks (that's S03). From Ch 7 § "Opening Gap Strategy" (p. 156):

> "In Chapter 4, we discussed a mean-reverting buy-on-gap strategy for stocks. The opposite momentum strategy will sometimes work on futures and currencies: buying when the instrument gaps up, and shorting when it gaps down." (p. 156)

Chan's causal mechanism is the **stop-cascade-at-open** hypothesis (p. 157):

> "What's special about the overnight or weekend gap that sometimes triggers momentum? The extended period without any trading means that the opening price is often quite different from the closing price. Hence, stop orders set at different prices may get triggered all at once at the open. The execution of these stop orders often leads to momentum because a cascading effect may trigger stop orders placed further away from the open price as well. Alternatively, there may be significant events that occurred overnight. As discussed in the next section, many types of news events generate momentum." (p. 157)

The full source rule, **verbatim** from Ex 7.1 MATLAB (p. 156):

```matlab
entryZscore=0.1;
stdretC2C90d=backshift(1, smartMovingStd(calculateReturns(cl, 1), 90));
longs  = op > backshift(1, hi).*(1+entryZscore*stdretC2C90d);
shorts = op < backshift(1, lo).*(1-entryZscore*stdretC2C90d);
positions=zeros(size(cl));
positions(longs)=1;
positions(shorts)=-1;
ret=positions.*(op-cl)./op;
```

So the trade lifecycle is exactly: at session open, IF `op > prev_high * (1 + 0.1 * 90d_stdret)` go LONG; IF `op < prev_low * (1 - 0.1 * 90d_stdret)` go SHORT; in either case liquidate at session close. The PnL accounting `(op-cl)/op` in Chan's code is mid-loop bookkeeping for a SHORT (entered at open, exited at close); long PnL is `(cl-op)/op` and `positions(longs)=1; positions(shorts)=-1` carries the sign. The threshold `entryZscore=0.1` is unusually small (literally 0.1·σ) — this is a *near-any-overnight-gap* trigger, with the 90-day vol scaling preventing entries on micro-gaps under quiet regimes.

The currency-pair generalization defines the daily "open" and "close" virtually since 24-hour FX has no exchange-imposed bar boundary (Chan p. 157):

> "The same strategy works on some currencies, too. However, the daily 'open' and 'close' need to be defined differently. If we define the close to be 5:00 p.m. ET, and the open to be 5:00 a.m. ET (corresponding to the London open), then applying this strategy to GBPUSD yields an APR of 7.2 percent and a Sharpe ratio of 1.3 from July 23, 2007, to February 20, 2012. Naturally, you can experiment with different definitions of opening and closing times for different currencies. Most currency markets are closed from 5:00 p.m. on Friday to 5:00 p.m. on Sunday, so that's a natural 'gap' for these strategies." (p. 157)

So for currencies the strategy is anchored to **London open = 5 a.m. ET** entry, **NY close = 5 p.m. ET** exit, with weekend Friday-evening-to-Sunday-evening gaps as a natural high-amplitude trigger.

## 3. Markets & Timeframes

```yaml
markets:
  - indices                                    # FSTX (Dow Jones STOXX 50 index futures, Eurex) source case → V5 Darwinex EUSTX50.DWX or STOXX50.DWX equivalent
  - forex                                      # GBPUSD source case → V5 Darwinex GBPUSD.DWX
  - commodities_futures                        # Chan: "After being tested on a number of futures, this strategy proved to work best on the Dow Jones STOXX 50 index futures (FSTX)" — generalizes to other index/commodity futures with overnight gaps
timeframes:
  - D1                                         # daily-bar entries on session open, exits on session close
session_window: open-to-close                  # session-open ENTRY → session-close EXIT
primary_target_symbols:
  - "FSTX (Dow Jones STOXX 50 index futures, Eurex) — primary source case (Chan p. 156)"
  - "GBPUSD (with virtual session: open=5 a.m. ET London open; close=5 p.m. ET NY close) — currency variant (Chan p. 157)"
  - "V5 Darwinex mapping: STOXX50.DWX or EUSTX50.DWX (FSTX analogue), GBPUSD.DWX (direct), candidate generalizations to other Darwinex-supported index CFDs (US500.DWX, GER40.DWX, UK100.DWX, NIKKEI.DWX, AUS200.DWX) and forex pairs (EURUSD.DWX, USDJPY.DWX, AUDUSD.DWX) per Chan's 'experiment with different definitions of opening and closing times for different currencies' license"
```

## 4. Entry Rules

```text
- on each new daily bar's session open:
    let stdretC2C90d = stdev_of_close_to_close_returns(close, lookback=90, shifted_back_1_bar)
    let upper_trigger = prev_bar.high * (1 + entryZscore * stdretC2C90d)
    let lower_trigger = prev_bar.low  * (1 - entryZscore * stdretC2C90d)
    if today.open > upper_trigger then BUY at market on open
    if today.open < lower_trigger then SELL at market on open
    otherwise no trade today
- entryZscore = 0.1 (Chan's source default; §8 sweeps higher / lower)
- 90d stdret is computed from close-to-close log-or-arithmetic returns over 90 prior bars, lagged 1 bar to avoid look-ahead
- prev_bar.high / prev_bar.low are the prior session's actual high/low (also lagged 1 bar)
- not in news blackout window per QM_NewsFilter (V5 framework default)
- not in framework Friday-Close window per V5 framework default
```

## 5. Exit Rules

```text
- exit at session close (today's close), regardless of intraday excursion direction
- one position per bar; exited at close before next bar's signal computation
- no SL or TP referenced in the source; intraday excursion is not gated → time-stop = session close is the only exit
- no trailing stop in source rule (positions held flat-through to close; the (op-cl)/op return accounting is unmodified)
- Friday Close enforced (default per V5 framework — for FSTX this means no Fri 17:30 CET → Mon 09:00 CET overnight position; for GBPUSD this means no Fri 21:00 broker → Mon 00:00 broker weekend hold)
- explicit MQL5 V5 mapping: optional `QM_StopRules.QM_StopAbsolute(stop_loss_price = some-multiple-of-90d-stdret-as-disaster-stop)` to bound runaway intraday-news outliers; documented as enhancement-doctrine candidate, not in source rule
```

## 6. Filters (No-Trade module)

```text
- entryZscore >= 0.1 effectively requires a non-trivial gap (> 0.1·σ)
- no further regime filter in source rule (no MA filter, no ADX filter, no time-of-day filter beyond session-open)
- V5 framework defaults (kill-switch + news-pause + Friday Close) apply
- (V5 enhancement candidate, NOT in source rule) — skip the entry if today's session-open is on a major-news-blackout calendar day (NFP, ECB, FOMC); not in Chan's rule but might reduce false-trigger gap noise
- (V5 enhancement candidate, NOT in source rule) — skip the entry if 90d_stdret is below an absolute floor (regime-too-quiet filter); Chan's σ-band trigger already self-scales to vol regime so this is likely redundant
```

## 7. Trade Management Rules

```text
- one position per session per symbol (default V5 one-position-per-magic-symbol)
- pyramiding: NOT allowed (default V5 framework)
- gridding: NOT allowed (default V5 framework)
- no break-even-move during the intraday hold (source rule is hold-flat-through-close)
- no partial close at intraday level (source rule is single-leg open-to-close)
- the position carries a single direction set at session open and is closed at session close — no intraday flips
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: entryZscore
  default: 0.1
  sweep_range: [0.05, 0.1, 0.15, 0.2, 0.3, 0.5, 1.0]
  notes: "Chan's source default = 0.1 (very low threshold, near-any-overnight-gap trigger). Higher values (0.5, 1.0) might trade fewer days but with cleaner signal."
- name: vol_lookback
  default: 90
  sweep_range: [30, 60, 90, 120, 250]
  notes: "Chan uses 90-day close-to-close stdev of returns, lagged 1 bar. Sensitivity: shorter lookbacks adapt faster to vol regimes but are noisier."
- name: session_open_time_currency
  default: "5:00 a.m. ET (London open) — for currency pairs"
  sweep_range: ["5:00 a.m. ET (London)", "8:30 a.m. ET (NY)", "0:00 ET (Asia close / weekend gap)"]
  notes: "Chan p. 157: 'Naturally, you can experiment with different definitions of opening and closing times for different currencies.' For FSTX this is the actual exchange session open (Eurex); for currencies this is virtual. CTO selects per-symbol broker time at G0."
- name: session_close_time_currency
  default: "5:00 p.m. ET — for currency pairs"
  sweep_range: ["5:00 p.m. ET (NY close)", "9:00 p.m. ET", "0:00 ET"]
  notes: "Defines the exit time for currencies. FSTX exits at exchange close. Per-symbol parameter at G0."
- name: reference_extreme_choice
  default: "prev_bar.high / prev_bar.low"
  sweep_range: ["prev_bar.high/low", "prev_bar.close + N·stdret (close-anchored)", "MAX(prev_3_bar.high) / MIN(prev_3_bar.low)"]
  notes: "Chan's source uses a 1-bar reference (prev_bar.high/low). Generalizing to N-bar might reduce false trigger frequency."
```

Conditional / V5-architecture-pending parameters (CTO + CEO discretion at G0):

```yaml
- name: friday_close_override
  default: false                                # framework default applies; FSTX & GBPUSD both Friday-close-friendly (intraday lifecycle)
  sweep_range: [false]
  notes: "All entries are open-to-close intraday lifecycles, fully Friday-Close-compatible without override."
```

## 9. Author Claims (verbatim, with quote marks)

```text
"this strategy proved to work best on the Dow Jones STOXX 50 index futures (FSTX) trading on Eurex, which generates an annual percentage rate (APR) of 13 percent and a Sharpe ratio of 1.4 from July 16, 2004, to May 17, 2012." (p. 156)

"applying this strategy to GBPUSD yields an APR of 7.2 percent and a Sharpe ratio of 1.3 from July 23, 2007, to February 20, 2012." (p. 157)

"Most currency markets are closed from 5:00 p.m. on Friday to 5:00 p.m. on Sunday, so that's a natural 'gap' for these strategies." (p. 157)

"In Chapter 4, we discussed a mean-reverting buy-on-gap strategy for stocks. The opposite momentum strategy will sometimes work on futures and currencies: buying when the instrument gaps up, and shorting when it gaps down." (p. 156)

"What's special about the overnight or weekend gap that sometimes triggers momentum? The extended period without any trading means that the opening price is often quite different from the closing price. Hence, stop orders set at different prices may get triggered all at once at the open. The execution of these stop orders often leads to momentum because a cascading effect may trigger stop orders placed further away from the open price as well." (p. 157)
```

Subsequent cross-reference in Ch 8 (p. 173 area) confirms the FSTX result was the headline strategy used as an in-flight illustration of constant-leverage strategies (raw evidence: full_text.txt line 8324):

```text
"FSTX opening gap strategy depicted in Chapter 7. That strategy had an annualized average return ... [under constant-leverage rebalancing in a high-vol period] annualized average return drops to 2.6 percent and the Sharpe ratio to 0.16." (Ch 8, full_text.txt line 8324-8327, exact PDF page TBD)
```

This is corroborating evidence that the headline 13%/1.4 figure is *not* leverage-overlay-stable — Ch 8 shows the constant-leverage-overlay specifically degrades it. Strategy-Card-level note: per V5 P5 stress, the constant-leverage degradation case is on the standard testing matrix.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.4                              # Sharpe 1.4 → rough PF ≈ 1.4-1.6 for daily intraday MOC strategy
expected_dd_pct: 12                           # rough estimate from 8-year Sharpe 1.4 daily-bar ETF/futures performance — typical mid-Sharpe daily strategies see 10-15% MaxDD
expected_trade_frequency: 100/year            # rough estimate — 252 sessions × ~40% gap-pass-σ-trigger rate per Chan's 0.1·σ low threshold
risk_class: medium                            # daily-bar intraday momentum on liquid futures + forex; not scalping; symmetric long/short
gridding: false
scalping: false
ml_required: false
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical — full MATLAB rule, fully discretionary-judgment-free
- [x] No Machine Learning required — pure rule-based signal computation
- [x] Friday Close compatibility — strategy is intraday open-to-close, fully compatible
- [x] Source citation precise — Chan AT (2013), Ch 7 Ex 7.1, PDF p. 156
- [x] No near-duplicate of existing approved card — Williams' SRC03_S02 `williams-spx-tue-buy` is calendar-day-of-week + at-market on open (no σ-band gap trigger); SRC03_S03 `williams-tbond-tue-sell` similar; Chan's S03 `chan-at-buy-on-gap` is the OPPOSITE direction (gap-FADE) on a cross-sectional stock screen rather than gap-GO-WITH on a single futures/forex symbol; SRC02 `chan-bollinger-es` is mean-reversion intraday band (not gap-mechanic-conditional)
- [x] No gridding, no scalping, no ML

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "framework defaults (kill-switch + news-pause + Friday-Close) apply with no strategy-specific override; optional enhancement candidates documented in §6 are NOT in source rule"
  trade_entry:
    used: true
    notes: "Strategy_EntrySignal: at session open, compute upper_trigger and lower_trigger from prev_bar.high * (1 + entryZscore · 90d_stdret) and prev_bar.low * (1 - entryZscore · 90d_stdret); if today.open > upper_trigger → BUY at market on open; if today.open < lower_trigger → SELL at market on open"
  trade_management:
    used: false
    notes: "no break-even / trail / partial-close in source rule; position is single-leg open-to-close"
  trade_close:
    used: true
    notes: "Strategy_ExitSignal: time-stop at session close (close at today's bar close); exit signal is purely time-based, not price-based"
```

```yaml
hard_rules_at_risk:
  - dwx_suffix_discipline                     # Chan source instruments are FSTX (Eurex DJ STOXX 50 index futures) and GBPUSD (FX); V5 deployment requires Darwinex spot-CFD or index-CFD substitution. FSTX's Darwinex equivalent is STOXX50.DWX or EUSTX50.DWX (CTO confirms exact symbol at G0). For FSTX, the exchange-session-open vs. CFD-continuous-trading gap is a methodological consideration: Darwinex CFDs trade on different schedules than the Eurex futures, and the "session open" virtual time defines the strategy. CTO confirms whether STOXX50.DWX has a clean daily session boundary.
at_risk_explanation: |
  dwx_suffix_discipline: FSTX (Eurex DJ STOXX 50 index futures) does not exist as such on
  Darwinex. The Darwinex-native equivalent is STOXX50.DWX or EUSTX50.DWX (index-CFD), which
  trades continuously rather than on Eurex sessions. The strategy is anchored to a session-open
  vs. session-close lifecycle; Darwinex CFDs may not have a clean "session open" boundary. For
  GBPUSD, Chan defines a virtual session: open=5 a.m. ET (London open), close=5 p.m. ET (NY
  close), and Darwinex GBPUSD.DWX is fully compatible with this virtual session at the EA-tick
  level. CTO confirms at G0 whether STOXX50.DWX (or other index CFD) supports the strategy's
  session-anchored lifecycle and whether the "open" reference price is the post-Eurex-open or
  the post-Asian-session 24h-rolling-day start. Documented as `dwx_suffix_discipline` at risk
  for the index-futures-source-mapped variant.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD
  entry: TBD
  management: TBD
  close: TBD
estimated_complexity: small
estimated_test_runtime: TBD
data_requirements: standard
```

## 14. Pipeline History (per `_v<n>` rebuild)

| version | date | rebuild reason | P-stage reached | verdict |
|---|---|---|---|---|
| _v1 | 2026-04-28 | initial build (h3 SRC05 batch) | TBD | TBD |

## 15. Pipeline Phase Status (current `_v<n>`)

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-04-28 | DRAFT | this card |
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
- 2026-04-28: VOCAB-GAP candidate `opening-gap-momentum` proposed (per source.md §6 batch). Direction-mirror of existing `gap-fade-stop-entry` (which is calendar-pattern + stop-entry placed BACK after gap-through). Distinct from `vol-expansion-breakout` (next-bar open + N% × prior-day-range; opening-gap-momentum compares prev-bar-extreme + σ-band scaling not next-bar-open + range-projection). Sibling-flag pattern (matching V4 sibling-flag-not-generalize precedent for `intraday-day-of-month` / `intraday-day-of-week` / `holiday-anchored-bias` from SRC03 closeout). Recommend: add to `strategy_type_flags.md` as a new heading, parameterized by `direction_mode ∈ {long, short, symmetric}` and `reference_extreme ∈ {prev_high_low, prev_close_plus_stdret, n_bar_high_low}`.
- 2026-04-28: Causal mechanism Chan provides ("stop-cascade-at-open" hypothesis, p. 157) is itself testable — V5 P3 sweep should include at least one variant where the trigger is replaced by *random-direction at random-day with same trade frequency* to validate the gap-direction edge is not a coincidence of period or vol-regime.
- 2026-04-28: Chan's Ch 8 cross-reference (constant-leverage degradation: APR drops from 13% to 2.6%, Sharpe drops from 1.4 to 0.16) is corroborating evidence that the headline figure is *not* leverage-overlay-stable. P5 stress covers this case in V5 standard testing matrix.
- 2026-04-28: Currency variant requires per-symbol "session open" / "session close" mapping that may be load-bearing on the result. CTO confirms at G0 whether MQL5 EA can compute virtual-session-open / virtual-session-close on Darwinex broker time, OR whether the strategy is gated to D1-bar-aligned only.
```
