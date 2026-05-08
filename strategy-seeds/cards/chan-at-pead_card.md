# Strategy Card — Chan AT Post-Earnings Announcement Drift (PEAD) (cross-sectional intraday momentum on overnight earnings-event gap, σ-band trigger, exit at close)

> Drafted by Research Agent on 2026-05-08 from `strategy-seeds/sources/SRC05/raw/full_text.txt` lines 7068-7274 (Ex 7.2 verbatim MATLAB + S&P-500 Jan-2011 → Apr-2012 performance + Chan's "let the market tell us" framing).
> Heartbeat trigger: [QUA-783](/QUA/issues/QUA-783) — OWNER directive via Board Advisor [QUA-740](/QUA/issues/QUA-740) comment `3d7e598e` (2026-05-08T04:33Z) — extract ≤3 cards from current chan-family SRC under DL-057 self-continuing loop. This card lifts SRC05_S13 from "DRAFT-PENDING-or-SKIP" (prior Research policy at SRC05 first-pass closeout) to **DRAFT** with `darwinex_native_data_only` Hard Rule at-risk surfaced for QB G0 verdict.
> Submitted for Quality-Business G0 review per [QUA-783](/QUA/issues/QUA-783) action plan.

## Card Header

```yaml
strategy_id: SRC05_S13
ea_id: TBD
slug: chan-at-pead
status: DRAFT
created: 2026-05-08
created_by: Research
last_updated: 2026-05-08

strategy_type_flags:
  - event-driven-momentum                       # NEW VOCAB GAP — entry mechanism: gap-direction momentum at session open, gated on a calendar-known corporate event (here: an earnings announcement made between previous-day's close and today's open). Distinct from `opening-gap-momentum` (S12 chan-at-fstx-gap-mom — unconditional gap trigger, no event gating); distinct from `news-blackout` (no-trade filter, not an entry trigger). Sibling proposal under SRC05 first-pass vocab batch (per `strategy-seeds/sources/SRC05/source.md` § 6 vocab-gap proposal #7).
  - opening-gap-momentum                        # secondary flag — the trigger logic is the same σ-band gap logic as S12 chan-at-fstx-gap-mom (overnight retC2O > 0.5·90d_stdC2O for long, < -0.5·90d_stdC2O for short); the differentiator vs. S12 is the additional `earnann` event-gate filter
  - cross-sectional-decile-sort                 # multi-stock universe cardinality (S&P 500 stocks); on each event-day positions(longs)=1 and positions(shorts)=-1 across all stocks meeting the threshold simultaneously. Matches existing flag (SRC02_S03/S04/S05/S06 family) with weighting_scheme=event-conditional-sigma-screen and ranking_metric=overnight-return-relative-to-90d-stdev
  - time-stop                                   # exit mechanism: positions liquidated at session close (open-to-close hold, ≤ 1 day duration)
  - symmetric-long-short                        # both directions deployable from the same source rule (positions(longs)=1; positions(shorts)=-1)
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Chan, Ernest P. (2013). Algorithmic Trading: Winning Strategies and Their Rationale. Wiley Trading. Hoboken, NJ: John Wiley & Sons. ISBN 978-1-118-46014-6 (cloth) / 978-1-118-46019-1 (ebk)."
    location: "Chapter 7 'Intraday Momentum Strategies', § 'News-Driven Momentum Strategy' → § 'Post-Earnings Announcement Drift' (PDF pp. 158-162 / printed pp. 158-162). Example 7.2 'Backtest of Post-Earnings Annoucement [sic] Drift Strategy' (PDF p. 161 / printed p. 161) is the primary case with full MATLAB code and S&P-500 Jan-2011 → Apr-2012 performance. BOX 7.1 'Function for Retrieving Earnings Calendar from earnings.com' (PDF pp. 159-160) provides the data-feed scaffold that defines the `earnann` logical array on which Ex 7.2 is conditioned."
    quality_tier: A
    role: primary
  - type: paper
    citation: "Bernard, Victor L. and Thomas, Jacob K. (1989). Post-Earnings-Announcement Drift: Delayed Price Response or Risk Premium? Journal of Accounting Research, Vol. 27 (Supplement)."
    location: "cited by Chan, p. 158: 'though this fact has been known and studied since 1968 (Bernard and Thomas, 1989), the effect still has not been arbitraged away'"
    quality_tier: A
    role: supplement
```

Raw evidence: `strategy-seeds/sources/SRC05/raw/full_text.txt` lines 7068-7274 (extracted via `pdftotext -layout` 2026-04-28). Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Algorithmic Trading_ Winning St - Ernie Chan.pdf`.

## 2. Concept

A **cross-sectional intraday event-driven momentum strategy** on stocks announcing earnings between previous-day's close and today's open. On the morning after an earnings announcement, the strategy buys at the open if the overnight close-to-open return is large-positive (≥ 0.5·90d_stdev) and shorts if large-negative (≤ -0.5·90d_stdev), liquidating all positions at the same day's close. The market — not the trader — decides whether the announcement is "good" or "bad"; the trader rides the announced-news drift for a single intraday session. Chan's framing (p. 158):

> "buying the stock if the return is very positive and shorting if the return is very negative, and liquidate the position at the same day's close. Notice that this strategy does not require the trader to interpret whether the earnings announcement is 'good' or 'bad.' It does not even require the trader to know whether the earnings are above or below analysts' expectations. We let the market tell us whether it thinks the earnings are good or bad." (p. 158)

The economic mechanism is the **slow-diffusion-of-news** hypothesis (Chan, p. 158, citing Bernard and Thomas 1989): an earnings announcement persists in the same direction for "some time after the announcement, allowing momentum traders to benefit. Even more surprising is that though this fact has been known and studied since 1968, the effect still has not been arbitraged away, though the duration of the drift may have shortened" — Chan demonstrates the drift is now "intraday" rather than multi-day.

## 3. Markets & Timeframes

```yaml
markets:
  - stocks                                      # PRIMARY — S&P 500 universe (Chan p. 161); not a Darwinex-native universe (see § 11)
timeframes:
  - D1                                          # daily-bar entries on session open, exits on session close; conditioned on T-1 → T overnight return + earnann gate
session_window: open-to-close                   # session-open ENTRY → session-close EXIT (intraday hold)
primary_target_symbols:
  - "S&P 500 stocks (universe-cross-section, ≤ 30 stocks per day per Chan; max-positions denominator = 30 per Chan p. 161)"
  - "V5-architecture mapping: NO clean Darwinex equivalent. Darwinex spot/CFD universe is FX + indices + metals + select commodity-CFDs; multi-stock cross-section is not natively supported. CTO + CEO ratify substitution path at G0 (option A: synthetic event-driven gap on US500.DWX whenever S&P 500 earnings density is high; option B: defer until V5 acquires multi-stock-equity broker access)"
```

## 4. Entry Rules

```text
- on each new daily bar's session open:
    let stdC2O[t] = stdev_of_close_to_open_returns(prev_close, today_open, lookback=90)  # 90-day rolling stdev of overnight returns
    let retC2O[t,i] = (op[t,i] - cl[t-1,i]) / cl[t-1,i]                                  # per-stock overnight return
    let earnann[t,i] = TRUE iff stock i had an earnings announcement after cl[t-1] and before op[t]
    longs[t,i]  = retC2O[t,i] >= 0.5 * stdC2O[t,i] AND earnann[t,i]
    shorts[t,i] = retC2O[t,i] <= -0.5 * stdC2O[t,i] AND earnann[t,i]
    if longs[t,i]  then BUY  stock i at market on open
    if shorts[t,i] then SELL stock i at market on open
    otherwise no trade in stock i today
- entryZscore (the 0.5·σ multiplier) = 0.5 (Chan's source default; §8 sweeps higher / lower)
- 90d stdev is computed from prev_close→today_open returns over 90 prior bars per stock
- earnann calendar gate is binary (earnings announced after prev close + before today open → eligible; else excluded)
- not in news blackout window per QM_NewsFilter (V5 framework default)
- not in framework Friday-Close window per V5 framework default
```

Verbatim source MATLAB (Ex 7.2, p. 161):

```matlab
lookback=90;
retC2O=(op-backshift(1, cl))./backshift(1, cl);
stdC2O=smartMovingStd(retC2O, lookback);
positions=zeros(size(cl));
longs=retC2O >= 0.5*stdC2O & earnann;
shorts=retC2O <= -0.5*stdC2O & earnann;
positions(longs)=1;
positions(shorts)=-1;
ret=smartsum(positions.*(cl-op)./op, 2)/30;
```

## 5. Exit Rules

```text
- exit at session close (today's close), regardless of intraday excursion direction
- one position per event-eligible stock per day; liquidated at close before next bar's signal computation
- no SL or TP referenced in the source; intraday excursion is not gated → time-stop = session close is the only exit
- no trailing stop in source rule (positions held flat-through to close; the (cl-op)/op return accounting is unmodified)
- Friday Close enforced (default per V5 framework — earnings announcements made Friday after-close → Monday open are still within the strategy's open-to-close lifecycle, fully Friday-close-compatible since no weekend hold)
- Chan p. 162 inline note: "the overnight returns are negative on average" — overnight extension of the position is explicitly contraindicated by Chan
```

## 6. Filters (No-Trade module)

```text
- earnann gate is the PRIMARY filter (most session-days for most stocks have earnann=FALSE → no trade)
- |retC2O| >= 0.5 * stdC2O is the SECONDARY filter (filters small-noise overnight gaps even on event days)
- max 30 simultaneous positions per Chan's denominator choice (p. 161); CTO + CEO confirm at G0 whether to enforce this as a hard cap or as a portfolio-level position-sizing throttle
- V5 framework defaults (kill-switch + news-pause + Friday Close) apply
- (V5 enhancement candidate, NOT in source rule) — skip the entry on FOMC / NFP / ECB calendar days where macro-news may compete with the earnings-specific drift; not in Chan's rule
- (V5 enhancement candidate, NOT in source rule) — skip the entry if earnann calendar is unavailable for the day (data-quality fallback); not in Chan's rule
```

## 7. Trade Management Rules

```text
- one position per event-eligible stock per session (default V5 one-position-per-magic-symbol; MULTI-symbol variant required for cross-sectional deployment)
- pyramiding: NOT allowed (default V5 framework)
- gridding: NOT allowed (default V5 framework)
- no break-even-move during the intraday hold (source rule is hold-flat-through-close)
- no partial close at intraday level (source rule is single-leg open-to-close)
- the position carries a single direction set at session open and is closed at session close — no intraday flips
- portfolio-level: equal-weight exposure across simultaneous positions; Chan denominator-of-30 implies per-position notional = capital / 30
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: entryZscore
  default: 0.5
  sweep_range: [0.25, 0.5, 0.75, 1.0, 1.5]
  notes: "Chan's source default = 0.5 (half-sigma threshold). Higher values (1.0, 1.5) trade fewer events with cleaner signal but lower frequency."
- name: vol_lookback
  default: 90
  sweep_range: [30, 60, 90, 120, 180, 250]
  notes: "Chan uses 90-day rolling stdev of close-to-open returns per stock. P2/P3 test-window note: at 90 D1 bars (~4.5 calendar months), default V5 P2 6-month window provides only ~30 bars of post-warmup signal — TIGHT FIT. See § 11 forward-looking flag for QM-00086 Path X1 dependency."
- name: max_positions_per_day
  default: 30
  sweep_range: [10, 20, 30, 50, 100]
  notes: "Chan p. 161: 'we have used 30 as the denominator … since there is a maximum of 30 positions in one day during that backtest period.' Sweep tests whether the cap is binding on more recent universes / vol regimes."
- name: holding_period
  default: same-day-close
  sweep_range: ["same-day-close", "intraday-half-day", "next-bar-open"]
  notes: "Chan p. 162: 'It remains to be tested whether an even shorter holding period may generate better returns.' This is Chan-explicit: the source default is liquidate-at-close but Chan invites shorter-hold testing. Longer holds (next-bar-open / overnight) are explicitly contraindicated by Chan ('overnight returns are negative on average', p. 162) and are NOT in P3 sweep candidate range."
- name: leverage_overlay
  default: 1.0
  sweep_range: [1.0, 2.0, 3.0, 4.0]
  notes: "Chan p. 162: 'it is possible to lever it up by at least four times, giving an annualized average return of close to 27 percent.' Sweep against V5 P5 stress (constant-leverage degradation; see SRC05 S12 Ch 8 cross-reference precedent)."
```

Conditional / V5-architecture-pending parameters (CTO + CEO discretion at G0):

```yaml
- name: substitution_universe
  default: "S&P 500 stocks (Chan source case — NOT Darwinex-native)"
  sweep_range:
    - "S&P 500 stocks (Chan source case)"
    - "US500.DWX synthetic event-day proxy (substitute the per-stock event-density into a single-symbol S&P-500-CFD signal; CEO ratifies whether this preserves the strategy's edge)"
    - "Single-symbol equity-CFDs from the broker's stock-CFD list, restricted to S&P 500 members offered by the broker"
  notes: "PRIMARY G0 BLOCKER. Chan's universe is direct S&P-500 stock holdings; Darwinex spot stack does not natively support multi-stock cross-section. CEO + CTO ratify whether to (a) defer this card until V5 acquires multi-stock-equity broker access, (b) accept a synthetic single-symbol US500.DWX substitution path with documented edge degradation, or (c) restrict to a subset of broker-offered S&P 500 equity-CFDs."
- name: earnings_calendar_source
  default: "earnings.com via parseEarningsCalendarFromEarningsDotCom.m (Chan BOX 7.1, pp. 159-160) — NOT Darwinex-native"
  sweep_range:
    - "earnings.com (Chan source case)"
    - "Bloomberg / Refinitiv / FactSet earnings calendar (paid feed)"
    - "Public-domain earnings RSS / SEC 8-K filings (DIY)"
  notes: "PRIMARY G0 BLOCKER (jointly with substitution_universe). Earnings-calendar data is required to compute the earnann logical array — without it, the strategy cannot fire. CEO + CTO ratify the data-feed path at G0; documented as `darwinex_native_data_only` Hard Rule at-risk in § 11."
```

## 9. Author Claims (verbatim, with quote marks)

```text
"For a universe of S&P 500 stocks, the APR from January 3, 2011, to April 24, 2012, is 6.7 percent, while the Sharpe ratio is a very respectable 1.5. The cumulative returns curve is displayed in Figure 7.2." (p. 161)

"Note that we have used 30 as the denominator in calculating returns, since there is a maximum of 30 positions in one day during that backtest period. Of course, there is a certain degree of look-ahead bias in using this number, since we don't know exactly what the maximum will be. But given that the maximum number of announcements per day is quite predictable, this is not a very grievous bias." (p. 161)

"Since this is an intraday strategy, it is possible to lever it up by at least four times, giving an annualized average return of close to 27 percent." (p. 162)

"You might wonder whether holding these positions overnight will generate additional profits. The answer is no: the overnight returns are negative on average. On the contrary, many published results from 10 or 20 years ago have shown that PEAD lasted more than a day. This may be an example where the duration of momentum is shortened due to increased awareness of the existence of such momentum. It remains to be tested whether an even shorter holding period may generate better returns." (p. 162)

"Notice that this strategy does not require the trader to interpret whether the earnings announcement is 'good' or 'bad.' It does not even require the trader to know whether the earnings are above or below analysts' expectations. We let the market tell us whether it thinks the earnings are good or bad." (p. 158)

"Even more surprising is that though this fact has been known and studied since 1968 (Bernard and Thomas, 1989), the effect still has not been arbitraged away, though the duration of the drift may have shortened." (p. 158)
```

## 10. Initial Risk Profile

```yaml
expected_pf: 1.5                              # Sharpe 1.5 → rough PF ≈ 1.5-1.7 for daily intraday MOC strategy on event-conditioned stocks
expected_dd_pct: 10                           # rough estimate from 16-month Sharpe-1.5 daily-bar performance — Chan's Fig 7.2 cumulative-returns curve is shown but max-DD not stated verbatim; mid-Sharpe daily strategies typically see 8-12% MaxDD
expected_trade_frequency: 200/year            # rough estimate — S&P-500 has ~125 events/quarter × 4 quarters × event-σ-pass-rate ≈ 30% × max-cap-30/day ≈ 200 trade-days/year (multi-position)
risk_class: medium                            # daily-bar event-driven intraday momentum on liquid stocks; not scalping; symmetric long/short; 4× leverage overlay candidate (per Chan p. 162) elevates to high if applied
gridding: false
scalping: false
ml_required: false
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical — full MATLAB rule (Ex 7.2 p. 161), discretionary-judgment-free
- [x] No Machine Learning required — pure rule-based signal computation; "let the market tell us" framing is mechanical (sign of overnight return is the signal)
- [x] Friday Close compatibility — strategy is intraday open-to-close, fully compatible
- [x] Source citation precise — Chan AT (2013), Ch 7 Ex 7.2, PDF p. 161 + BOX 7.1 pp. 159-160
- [ ] **No near-duplicate of existing approved card** — partial overlap with SRC05_S12 `chan-at-fstx-gap-mom` (same σ-band gap-go-with mechanic) but DIFFERENTIATED by event-conditional `earnann` gate (S12 is unconditional; PEAD is event-gated). Distinct from SRC05_S03 `chan-at-buy-on-gap` (opposite direction — gap-FADE on cross-section). Distinct from SRC02 PEAD-narrative SKIP (SRC02 source.md § 6 PEAD was skipped at SRC02 time as "underspecified-beyond-cardable" because Chan QT 2009 delegated entry/exit thresholds to reader; Chan AT 2013 specifies them concretely in Ex 7.2 → this card is the SRC05 first concrete-mechanical extraction of the PEAD insight).
- [x] No gridding, no scalping, no ML
- [ ] **`darwinex_native_data_only` Hard Rule AT RISK (PRIMARY G0 BLOCKER) — see § 12**
- [ ] **`dwx_suffix_discipline` Hard Rule AT RISK (S&P-500 stocks not in Darwinex spot universe) — see § 12**

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "framework defaults (kill-switch + news-pause + Friday-Close) apply; PRIMARY no-trade gate is `earnann == FALSE` (most stock-day pairs); SECONDARY is |retC2O| < 0.5·90d_stdC2O (small-overnight-gap filter)"
  trade_entry:
    used: true
    notes: "Strategy_EntrySignal: at session open, for each stock i where earnann[t,i]=TRUE compute retC2O[t,i] and stdC2O[t,i]; if retC2O ≥ 0.5·stdC2O → BUY at market on open; if retC2O ≤ -0.5·stdC2O → SELL at market on open"
  trade_management:
    used: false
    notes: "no break-even / trail / partial-close in source rule; position is single-leg open-to-close per stock; portfolio-level equal-weight allocation across simultaneous positions"
  trade_close:
    used: true
    notes: "Strategy_ExitSignal: time-stop at session close (close at today's bar close); exit signal is purely time-based, not price-based; Chan p. 162 explicitly contraindicates overnight extension"
```

```yaml
hard_rules_at_risk:
  - darwinex_native_data_only                   # PRIMARY G0 BLOCKER. Strategy requires per-stock earnings-announcement calendar (earnann logical array) — Chan's BOX 7.1 sources this from earnings.com. Darwinex-native data feed does NOT include earnings calendars; this is an external-data-feed dependency.
  - dwx_suffix_discipline                       # PRIMARY G0 BLOCKER. Chan's universe is S&P 500 individual stocks; Darwinex spot/CFD universe is FX + indices + metals + select commodity-CFDs. Multi-stock cross-section is not natively supported; CTO + CEO ratify substitution path at G0.
  - one_position_per_magic_symbol               # cross-sectional deployment requires concurrent positions across up to 30 stocks per day — CTO + CEO ratify whether to use multi-symbol Magic Formula registry (one slot per S&P 500 member offered by broker) or to keep single-symbol architecture and SKIP the strategy.
  - magic_schema                                # if cross-sectional deployment is approved, magic-formula registry needs an event-day cardinality extension (max-30-positions-per-event-day across the universe of mapped symbols); deviates from default ea_id*10000+symbol_slot single-symbol assumption.
  - kill_switch_coverage                        # max-30 simultaneous positions × 4× leverage overlay (per Chan p. 162) creates portfolio-level DD-volatility distinct from V5's single-symbol QM_KillSwitch coverage; CTO + CEO calibrate at G0.
  - enhancement_doctrine                        # `entryZscore`, `vol_lookback`, `max_positions_per_day` are entry-side parameters likely to change post-PASS based on universe / event-density regime; flagged for enhancement-doctrine documentation discipline.
at_risk_explanation: |
  darwinex_native_data_only (PRIMARY): Earnings-announcement calendar (the `earnann[t,i]` logical
  array) is required to fire any trade. Chan provides parseEarningsCalendarFromEarningsDotCom.m
  (BOX 7.1, p. 159) which scrapes earnings.com — that is an external HTTP feed, not Darwinex
  spot/CFD broker data. CEO + CTO ratify the data-feed path at G0: (a) accept the
  external-calendar dependency (earnings.com or paid Bloomberg / Refinitiv / FactSet feed) with
  documented data-quality fallback, OR (b) SKIP the strategy with rationale.

  dwx_suffix_discipline (PRIMARY, jointly with above): Chan's universe is S&P 500 individual
  stocks. Darwinex spot stack offers FX + indices + metals + commodity-CFDs but no native
  multi-stock equity cross-section. CEO + CTO ratify substitution path at G0: (a) defer until V5
  acquires multi-stock-equity broker access, (b) accept synthetic US500.DWX event-density
  proxy with documented edge degradation, OR (c) restrict to a subset of broker-offered
  S&P 500 equity-CFDs (if any).

  one_position_per_magic_symbol + magic_schema: Cross-sectional simultaneous-position
  cardinality (up to 30 stocks/day) requires multi-symbol magic-formula registry extension; CTO
  + CEO confirm the schema at G0.

  kill_switch_coverage: 30 simultaneous positions × 4× leverage overlay creates portfolio-level
  DD distinct from V5's single-symbol kill-switch coverage; CTO calibrates at G0.

  enhancement_doctrine: entryZscore, vol_lookback, max_positions_per_day are entry-side
  parameters; sweep ranges in § 8 are explicit per Chan's "It remains to be tested whether an
  even shorter holding period may generate better returns" (p. 162) — the source author
  explicitly invites parameter exploration, which is exactly the enhancement-doctrine signature.
```

**Forward-looking flag per [QUA-740](/QUA/issues/QUA-740) audit comment `312aef75` (2026-05-08T03:02Z) and [QUA-783](/QUA/issues/QUA-783) extraction constraint:** This card has D1 lookback = 90 bars (close-to-open stdev). At default V5 P2 6-month window (~125 D1 bars), the strategy gets ~35 post-warmup signal bars. **TIGHT FIT** — not as severe as the 252-bar audit cluster (chan-pairs-stat-arb / chan-at-fx-coint-pair / chan-at-xs-mom-fut / chan-at-xs-mom-stock / chan-at-spy-arb / williams-pinch-paunch / lien-carry-trade) but still vulnerable on bar-density edges. **Pipeline-Op MUST verify QM-00086 Path X1 (`p2_baseline.py` reads card § 4 / § 8 for warmup/training/min-hold and extends test window) is shipped before this card's P2 dispatch produces meaningful baseline.** Alternatively, Pipeline-Op may accept a 12-month P2 window for this card by manual override at dispatch time. CEO ratifies the policy at G0 promotion.

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD
  entry: TBD
  management: TBD
  close: TBD
estimated_complexity: large                    # multi-stock universe + external earnings-calendar feed + per-stock 90d rolling stdev + max-30-positions cardinality
estimated_test_runtime: TBD
data_requirements: custom_news                 # PRIMARY: external earnings-calendar feed (earnings.com or paid equivalent); SECONDARY: per-stock D1 OHLC bars for S&P 500 universe
```

## 14. Pipeline History (per `_v<n>` rebuild)

| version | date | rebuild reason | P-stage reached | verdict |
|---|---|---|---|---|
| _v1 | 2026-05-08 | initial build (h6 SRC05 closeout v2 batch — extracted under [QUA-783](/QUA/issues/QUA-783) DL-057 directive) | TBD | TBD |

## 15. Pipeline Phase Status (current `_v<n>`)

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-05-08 | DRAFT | this card |
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
- 2026-05-08: Card lifted from "DRAFT-PENDING-or-SKIP" (SRC05 first-pass closeout policy) to DRAFT under [QUA-783](/QUA/issues/QUA-783) DL-057 OWNER directive. Prior policy was "draft only if CEO ratifies darwinex_native_data_only exception"; OWNER directive's "Hand to QB for G0 review" is interpreted as authorizing the draft with explicit § 11 / § 12 at-risk flagging, with QB G0 as the verdict gate on the data-exception substitution path.
- 2026-05-08: Forward-looking QM-00086 / Path X1 dependency flagged in § 12 per [QUA-740](/QUA/issues/QUA-740) audit comment 312aef75. PEAD's 90-bar lookback is tight-but-not-blocking on V5 default 6-month P2 window; longer audit cluster (252-bar lookback chan-family) is the harder constraint.
- 2026-05-08: Cross-source disambiguation against SRC02 PEAD SKIP — SRC02 source.md § 6 PEAD was correctly classified "underspecified-beyond-cardable" because Chan QT (2009) delegated entry/exit thresholds to reader. Chan AT (2013) Ex 7.2 specifies them concretely (entryZscore=0.5; lookback=90; exit=close). The SRC05 PEAD card is the BASIS-rule-compliant first concrete extraction of this insight; SRC02 SKIP stands as accurate for the 2009 source.
```
