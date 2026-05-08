# Strategy Card — Chan AT Leveraged-ETF Rebalance Momentum (DRN intraday MOC return-threshold momentum, exit at close)

> Drafted by Research Agent on 2026-05-08 from `strategy-seeds/sources/SRC05/raw/full_text.txt` lines 7319-7370 (inline § "Leveraged ETF Strategy" verbatim rule + DRN Oct-2011 → Oct-2012 performance + Chan's causal explanation of the LETF-rebalance-flow mechanism).
> Heartbeat trigger: [QUA-783](/QUA/issues/QUA-783) — OWNER directive via Board Advisor [QUA-740](/QUA/issues/QUA-740) comment `3d7e598e` (2026-05-08T04:33Z) — extract ≤3 cards from current chan-family SRC under DL-057 self-continuing loop. This card lifts SRC05_S14 from "DRAFT-PENDING-or-SKIP" (prior Research policy at SRC05 first-pass closeout) to **DRAFT** with `darwinex_native_data_only` and `dwx_suffix_discipline` Hard Rules at-risk surfaced for QB G0 verdict.
> Submitted for Quality-Business G0 review per [QUA-783](/QUA/issues/QUA-783) action plan.

## Card Header

```yaml
strategy_id: SRC05_S14
ea_id: TBD
slug: chan-at-lev-etf-rebal
status: DRAFT
created: 2026-05-08
created_by: Research
last_updated: 2026-05-08

strategy_type_flags:
  - leveraged-etf-rebalance-momentum            # NEW VOCAB GAP — entry mechanism: close-of-day momentum on a 3× leveraged sector ETF, conditioned on the deterministic LETF rebalance flow near MOC. Entry trigger: cumulative return from prev_close to (close − 15 min) crosses ±2% absolute threshold. Sibling proposal under SRC05 first-pass vocab batch (per `strategy-seeds/sources/SRC05/source.md` § 6 vocab-gap proposal #8). Distinct from `time-series-momentum` (which is daily-bar with N-day lookback; this is intraday with a fixed 15-min-before-close return-threshold trigger and is leveraged-ETF-instrument-specific).
  - time-stop                                   # exit mechanism: positions liquidated at session close (≤ 15 minutes hold from entry trigger to exit, at most one bar)
  - symmetric-long-short                        # both sides deployable from the same source rule (buy if return > +2%, sell if return < -2%)
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Chan, Ernest P. (2013). Algorithmic Trading: Winning Strategies and Their Rationale. Wiley Trading. Hoboken, NJ: John Wiley & Sons. ISBN 978-1-118-46014-6 (cloth) / 978-1-118-46019-1 (ebk)."
    location: "Chapter 7 'Intraday Momentum Strategies', § 'Leveraged ETF Strategy' (PDF pp. 163-164 / printed pp. 163-164). Inline strategy specification (no numbered Example block); embedded in Chan's narrative around the constant-leverage-rebalancing momentum hypothesis. Cross-references Example 8.1 (PDF p. 173+) for the constant-leverage methodology that motivates the strategy."
    quality_tier: A
    role: primary
  - type: paper
    citation: "Cheng, Minder and Madhavan, Ananth. (2009). The Dynamics of Leveraged and Inverse Exchange-Traded Funds. Journal of Investment Management, Vol. 7, No. 4."
    location: "cited by Chan, p. 164: 'It was reported that the total AUM of leveraged ETFs (including both long and short funds) at the end of January 2009 is $19 billion (Cheng and Madhavan, 2009).'"
    quality_tier: A
    role: supplement
```

Raw evidence: `strategy-seeds/sources/SRC05/raw/full_text.txt` lines 7319-7370 (extracted via `pdftotext -layout` 2026-04-28). Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Algorithmic Trading_ Winning St - Ernie Chan.pdf`.

## 2. Concept

A **single-instrument intraday momentum strategy** on a 3× leveraged sector ETF (DRN — 3× US REIT, source case), exploiting the deterministic end-of-day rebalance flow that LETF sponsors must execute to maintain constant leverage. When the underlying index moves materially during the session, the LETF sponsor must transact in the same direction near MOC (sell on big-down days, buy on big-up days) to preserve the 3× leverage target — and that flow is the momentum signal. Chan's framing (p. 163):

> "Now suppose you are actually the sponsor of an ETF, and that portfolio of yours is none other than a 3× leveraged ETF such as DRN (a real estate ETF), and its equity is over a hundred million dollars. If you think that this rebalancing procedure (selling the component stocks when the portfolio's return is negative, and vice versa) near the market close would generate momentum in the market value of the portfolio, you would be right." (p. 163)

The economic mechanism is the **constant-leverage-mandated rebalance** hypothesis: a 3× LETF sponsor's mark-to-market daily-rebalance to maintain leverage produces a same-direction flow on the underlying near MOC. Chan, p. 164:

> "We use the leveraged ETFs as trading instruments simply to magnify the effect."

And on the underlying mechanism scaling with assets-under-management (Cheng and Madhavan, 2009 cited by Chan p. 164):

> "It was reported that the total AUM of leveraged ETFs (including both long and short funds) at the end of January 2009 is \$19 billion. These authors also estimated that a 1 percent move of SPX will necessitate a buying or selling of stocks constituting about 17 percent of the market-on-close volume." (p. 164)

The sign of LETF rebalance flow is **always same-direction-as-the-day's-move for both long-and-short-LETF families** (Chan p. 163, parenthetical), so the strategy's signal direction does not depend on the LETF being long-leveraged or short-leveraged.

## 3. Markets & Timeframes

```yaml
markets:
  - stocks                                      # PRIMARY — DRN (3× US REIT ETF; symbol "DRN" on NYSE Arca; tracks MSCI US REIT index "RMZ"); Chan p. 163; not a Darwinex-native instrument (see § 11)
timeframes:
  - intraday                                    # primary signal computed from prev_close → (today_close - 15min) cumulative return
  - D1                                          # daily-bar signal aggregation; one entry/exit per day at most
session_window: t-15min-to-close                # signal evaluated 15 minutes before close; entry at next available tick after threshold; exit at session close (15-minute hold, at most)
primary_target_symbols:
  - "DRN (Direxion Daily MSCI Real Estate Bull 3X Shares; 3× leveraged US REIT ETF) — primary source case (Chan p. 163)"
  - "Other 3× leveraged sector ETFs from the Direxion / ProShares family (e.g., BGU/TNA tracking Russell-1000 / 2000; per Chan p. 162 sidebar reference) — generalize at G0 with CEO + CTO ratification"
  - "V5-architecture mapping: NO clean Darwinex equivalent. Darwinex spot/CFD universe does not include 3× leveraged sector ETFs. CTO + CEO ratify substitution path at G0 (option A: synthetic 3×-leverage proxy on US500.DWX or country-index-CFD; option B: defer until V5 acquires US-equity-ETF broker access)"
```

## 4. Entry Rules

```text
- on each new daily bar, 15 minutes before session close (e.g., 15:45 ET for US equity sessions):
    let return_C2T = (price_at_T_minus_15min - prev_close) / prev_close
    if return_C2T > +0.02 then BUY DRN at market
    if return_C2T < -0.02 then SELL DRN at market
    otherwise no trade today
- threshold = ±0.02 (Chan's source default = 2%; §8 sweeps higher / lower thresholds and other LETFs)
- prev_close is yesterday's session-close price for DRN
- price_at_T_minus_15min is DRN's price 15 minutes before today's close (nominally 15:45 ET)
- not in news blackout window per QM_NewsFilter (V5 framework default)
- not in framework Friday-Close window per V5 framework default
```

Verbatim source rule (Chan p. 163-164):

> "We can test this hypothesis by constructing a very simple momentum strategy: buy DRN if the return from previous day's close to 15 minutes before market close is greater than 2 percent, and sell if the return is smaller than −2 percent. Exit the position at the market close." (p. 163-164)

## 5. Exit Rules

```text
- exit at session close (today's close), regardless of intraday excursion direction
- one position per session per symbol; liquidated at close before next bar's signal computation
- maximum hold ≈ 15 minutes (entry at T-15min, exit at T)
- no SL or TP referenced in the source; intraday excursion is not gated → time-stop = session close is the only exit
- no trailing stop in source rule (positions held flat-through to close; the close-vs-(close-15min) PnL accounting is unmodified)
- Friday Close enforced (default per V5 framework — strategy is intraday, fully Friday-close-compatible since no overnight or weekend hold)
```

## 6. Filters (No-Trade module)

```text
- |return_C2T| > 0.02 absolute threshold is the PRIMARY filter (most session-days for DRN have intraday returns < 2% by close-15min)
- 3× leverage on DRN amplifies underlying RMZ moves — the 2% DRN trigger corresponds roughly to ~0.67% RMZ underlying move (large-but-not-extreme regime)
- V5 framework defaults (kill-switch + news-pause + Friday Close) apply
- (V5 enhancement candidate, NOT in source rule) — skip the entry on FOMC / NFP / CPI calendar days where macro-news-driven intraday returns may overwhelm the LETF-rebalance-flow signal; not in Chan's rule
- (V5 enhancement candidate, NOT in source rule) — scale the threshold to current DRN realized-volatility regime (e.g., 2% → 1.5·sigma_C2T_90d) to maintain trigger-density across vol regimes; not in Chan's rule
```

## 7. Trade Management Rules

```text
- one position per session per symbol (default V5 one-position-per-magic-symbol)
- pyramiding: NOT allowed (default V5 framework)
- gridding: NOT allowed (default V5 framework)
- no break-even-move during the 15-minute hold (source rule is hold-flat-through-close)
- no partial close at intraday level (source rule is single-leg T-15min-to-close)
- the position carries a single direction set 15 minutes before close and is closed at session close — no intraday flips
- total hold duration ≤ 15 minutes per trade (very short; arguably scalping-adjacent — flagged in § 11)
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: return_threshold
  default: 0.02
  sweep_range: [0.01, 0.015, 0.02, 0.025, 0.03, 0.04, 0.05]
  notes: "Chan's source default = 2% absolute. Higher thresholds reduce trade frequency (only on big-move days when LETF rebalance flow is largest); lower thresholds expand to medium-move days. Asymmetric ranges (long vs short) candidate at CEO discretion since LETF-rebal flow is symmetric per Chan p. 163."
- name: signal_horizon
  default: "T - 15 min"
  sweep_range: ["T - 5 min", "T - 10 min", "T - 15 min", "T - 30 min", "T - 60 min"]
  notes: "Chan's source default = 15 min before close. Earlier signal (T-30 / T-60) increases hold duration (lower scalping risk) but loses some MOC-rebalance-flow specificity; later signal (T-5) catches more flow but requires faster execution."
- name: trading_instrument
  default: "DRN (3× US REIT)"
  sweep_range: ["DRN (3× REIT)", "BGU (3× Russell-1000)", "TNA (3× Russell-2000)", "TQQQ (3× NDX)", "UPRO (3× SPX)"]
  notes: "Chan p. 162-163: 'exchange-traded fund (ETF) sponsor Direxion has been marketing triple leveraged ETFs BGU and TNA tracking these indices.' Chan p. 164: 'A more updated analysis was published by Rodier, Haryanto, Shum, and Hejazi, 2012.' Sweep tests whether the LETF-rebalance-flow signal generalizes across LETF families."
- name: short_letf_inclusion
  default: false                                 # Chan source uses LONG LETF only (DRN); long-only test
  sweep_range: [false, true]
  notes: "Chan p. 163 inline: 'A large change in the market index generates momentum in the same direction for both leveraged long or short ETFs.' Sweep tests whether including the inverse 3× LETF (DRV for REIT bear, BGZ for Russell-1000 bear) doubles the strategy's available trade-days without doubling the signal noise."
```

Conditional / V5-architecture-pending parameters (CTO + CEO discretion at G0):

```yaml
- name: substitution_universe
  default: "DRN (3× US REIT — Chan source case; NOT Darwinex-native)"
  sweep_range:
    - "DRN (Chan source case)"
    - "Synthetic 3×-leverage overlay on US500.DWX (compute the same return_C2T threshold on US500 underlying, scale position-size to match 3× leverage exposure)"
    - "Direct broker-offered 3× LETF on US-equity-ETF subaccount (if V5 acquires this access)"
  notes: "PRIMARY G0 BLOCKER. Chan's primary instrument is DRN (Direxion 3× REIT ETF); Darwinex spot stack does not include 3× LETFs. CEO + CTO ratify substitution path at G0: (a) defer until V5 acquires US-equity-ETF broker access, (b) accept synthetic 3×-leverage overlay on US500.DWX with documented signal-degradation, OR (c) SKIP the strategy with rationale."
- name: intraday_data_resolution
  default: "1-minute or 5-minute bars on DRN — required to compute T-15min price"
  sweep_range:
    - "1-minute bars (preferred — exact 15-min snapshot)"
    - "5-minute bars (acceptable — 3-bar lookback for T-15min)"
    - "15-minute bars (degraded — 1-bar lookback; may miss intra-15min flow timing)"
  notes: "PRIMARY G0 BLOCKER (jointly with substitution_universe). DRN intraday bar data is required to compute return_C2T at T-15min. Darwinex-native data feed includes intraday bars on Darwinex-listed instruments only; DRN is not on Darwinex. CEO + CTO ratify the data-feed path at G0; documented as `darwinex_native_data_only` Hard Rule at-risk in § 11."
```

## 9. Author Claims (verbatim, with quote marks)

```text
"We can test this hypothesis by constructing a very simple momentum strategy: buy DRN if the return from previous day's close to 15 minutes before market close is greater than 2 percent, and sell if the return is smaller than −2 percent. Exit the position at the market close." (p. 163-164)

"The APR of trading DRN is 15 percent with a Sharpe ratio of 1.8 from October 12, 2011, to October 25, 2012." (p. 164)

"Naturally, the return of this strategy should increase as the aggregate assets of all leveraged ETFs increase. It was reported that the total AUM of leveraged ETFs (including both long and short funds) at the end of January 2009 is $19 billion (Cheng and Madhavan, 2009). These authors also estimated that a 1 percent move of SPX will necessitate a buying or selling of stocks constituting about 17 percent of the market-on-close volume. This is obviously going to have significant market impact, which is momentum inducing." (p. 164)

"A large change in the market index generates momentum in the same direction for both leveraged long or short ETFs. If the change is positive, a short ETF would experience a decrease in equity, and its sponsor would need to reduce its short positions. Therefore, it would also need to buy stocks, just as the long ETF would." (p. 163)

"Note that this momentum strategy is based on the momentum of the underlying stocks, so it should be affecting the near-market-close returns of the unlevered ETFs such as SPY as well. We use the leveraged ETFs as trading instruments simply to magnify the effect." (p. 164)

"There is of course another event that will affect the equity of an ETF, leveraged or not: the flow of investors' cash. A large inflow into long leveraged ETFs will cause positive momentum on the underlying stocks' prices, while a large inflow into short leveraged ('inverse') ETFs will cause negative momentum. So it is theoretically possible that on the same day when the market index had a large positive return many investors sold the long leveraged ETFs (perhaps as part of a mean-reverting strategy). This would have neutralized the momentum. But our backtests show that this did not happen often." (p. 164)
```

## 10. Initial Risk Profile

```yaml
expected_pf: 1.6                              # Sharpe 1.8 → rough PF ≈ 1.6-1.9 for very-short-hold MOC strategy
expected_dd_pct: 8                            # rough estimate from 12-month Sharpe-1.8 LETF intraday performance — Chan does not state max-DD verbatim; very-short-hold MOC strategies typically see 5-10% MaxDD on liquid LETFs
expected_trade_frequency: 30/year             # rough estimate — daily 2% move-by-T-15min on DRN occurs ~10-15% of session-days (3× leverage × ~0.67% RMZ trigger × normal vol regime); 252 sessions × 12% ≈ 30 trade-days/year
risk_class: medium                            # 3× leverage exposure raises notional risk per trade but very-short-hold (15 min) intraday hold; symmetric long/short; not pyramided
gridding: false
scalping: true                                # 15-minute hold is scalping-adjacent — P5b VPS-realistic latency calibration MANDATORY (see § 11)
ml_required: false
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical — return_C2T threshold rule is fully discretionary-judgment-free
- [x] No Machine Learning required — pure absolute-threshold momentum signal
- [x] Friday Close compatibility — strategy is intraday with ≤ 15-minute hold; fully compatible
- [x] Source citation precise — Chan AT (2013), Ch 7 § "Leveraged ETF Strategy", PDF p. 163-164
- [ ] **No near-duplicate of existing approved card** — distinct mechanism (LETF-rebalance-flow exploitation) from S12 chan-at-fstx-gap-mom (overnight gap go-with) and S07 chan-at-ts-mom-fut (daily TS momentum). Closest sibling is S12 (intraday momentum) but trigger logic and instrument class are different (S12: prev-bar high/low + 90d_stdret σ-band on futures; S14: absolute 2% threshold on 3× LETF intraday).
- [x] No gridding, no ML
- [ ] **`scalping` flag is TRUE** — 15-minute hold puts this in scalping-class; P5b VPS-realistic latency calibration MANDATORY before P10 promotion (see § 12)
- [ ] **`darwinex_native_data_only` Hard Rule AT RISK (PRIMARY G0 BLOCKER) — see § 12**
- [ ] **`dwx_suffix_discipline` Hard Rule AT RISK (3× LETFs not in Darwinex spot/CFD universe) — see § 12**

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "framework defaults (kill-switch + news-pause + Friday-Close) apply; PRIMARY no-trade gate is `|return_C2T| < 0.02` (most session-days)"
  trade_entry:
    used: true
    notes: "Strategy_EntrySignal: at T-15min, compute return_C2T = (price_at_T_minus_15min - prev_close) / prev_close; if > +0.02 → BUY at market; if < -0.02 → SELL at market"
  trade_management:
    used: false
    notes: "no break-even / trail / partial-close in source rule; position is single-leg 15-min hold to close"
  trade_close:
    used: true
    notes: "Strategy_ExitSignal: time-stop at session close; exit signal is purely time-based, not price-based; hold ≤ 15 minutes"
```

```yaml
hard_rules_at_risk:
  - darwinex_native_data_only                   # PRIMARY G0 BLOCKER. Strategy requires intraday DRN bar data (1-min or 5-min resolution) to compute return at T-15min. DRN is a US-listed Direxion 3× LETF; not in Darwinex spot/CFD universe; intraday data not available from Darwinex feed.
  - dwx_suffix_discipline                       # PRIMARY G0 BLOCKER. Chan's primary instrument is DRN (Direxion 3× US REIT ETF); Darwinex spot/CFD universe does not include 3× LETFs. CTO + CEO ratify substitution path at G0.
  - scalping_p5b_latency                        # PRIMARY OPERATIONAL RISK. 15-minute hold is scalping-adjacent; V5 P5b stress with realistic VPS latency calibration is MANDATORY. The strategy's signal horizon (15 min) is small enough that ~1-3 second execution latency on Darwinex DXZ live-only path may degrade fill quality measurably.
  - kill_switch_coverage                        # 3× leverage on the trading instrument (DRN) creates 3× notional exposure per position; QM_KillSwitch DD coverage must be calibrated for 3× per-position-DD volatility. CTO + CEO calibrate at G0.
  - enhancement_doctrine                        # `return_threshold`, `signal_horizon` are entry-side parameters likely to change post-PASS based on LETF AUM regime (per Chan p. 164 "the return of this strategy should increase as the aggregate assets of all leveraged ETFs increase"); flagged for enhancement-doctrine documentation discipline.
at_risk_explanation: |
  darwinex_native_data_only (PRIMARY): Intraday DRN bar data (1-min or 5-min) is required to
  compute return_C2T at T-15min. DRN is a US-listed Direxion 3× LETF; Darwinex feed does not
  include this instrument's intraday data. CEO + CTO ratify the data-feed path at G0:
  (a) accept the external-LETF-data dependency (paid intraday-equity feed: Polygon, Alpaca,
  IEX, etc.) with documented data-quality fallback, OR (b) SKIP the strategy with rationale.

  dwx_suffix_discipline (PRIMARY, jointly with above): Chan's primary instrument is DRN (3×
  REIT LETF); Darwinex spot/CFD universe does not include 3× LETFs. CEO + CTO ratify
  substitution path at G0: (a) defer until V5 acquires US-equity-ETF broker access,
  (b) accept synthetic 3×-leverage overlay on US500.DWX (compute return_C2T threshold on
  US500 underlying, scale position-size to 3× leverage exposure) with documented edge
  degradation (the 3×-leverage-overlay synthetic loses the LETF-rebalance-flow specificity that
  is the strategy's economic basis — likely substantial signal degradation), OR (c) SKIP the
  strategy with rationale. SUBSTITUTION-PATH HEALTH WARNING: per Chan's own framing (p. 164),
  "we use the leveraged ETFs as trading instruments simply to magnify the effect" — the
  underlying-stocks momentum is the actual signal, but the 3× LETF amplifies the realized
  return. A US500.DWX synthetic overlay would replicate the unleveraged signal but lose the 3×
  amplification; CEO + CTO assess whether unleveraged signal alone is large enough to justify
  V5 deployment.

  scalping_p5b_latency (PRIMARY OPERATIONAL): 15-minute hold from entry to exit at close puts
  this in scalping-class on the V5 disambiguation. P5b stress with calibrated 1-3 second
  execution-latency VPS scenario is MANDATORY. The signal-horizon-to-execution-latency ratio
  needs to be > 50× to maintain edge integrity (15 min / 3 sec = 300×; PASSES rough check at
  default but P5b confirms with calibrated noise overlay).

  kill_switch_coverage: 3× leverage instrument creates 3× per-position notional risk; V5's
  default QM_KillSwitch DD calibration assumes 1× exposure. CTO recalibrates at G0 (e.g.,
  tighter MAX_DD trip ~5% per-position vs default 10%).

  enhancement_doctrine: return_threshold and signal_horizon are entry-side parameters; Chan
  explicitly notes (p. 164) that strategy effectiveness scales with LETF AUM ("the return of
  this strategy should increase as the aggregate assets of all leveraged ETFs increase"),
  implying threshold tuning over time as AUM evolves. Documented for enhancement-doctrine
  discipline.
```

**Forward-looking flag per [QUA-740](/QUA/issues/QUA-740) audit comment `312aef75` (2026-05-08T03:02Z) and [QUA-783](/QUA/issues/QUA-783) extraction constraint:** This card has NO D1 training_lookback (signal is computed from prev_close alone — single-bar dependency). V5 P2 6-month default window is sufficient; QM-00086 Path X1 dependency is **NOT** binding for this card. The dominant risk is intraday-data-availability (`darwinex_native_data_only`) and instrument-substitution (`dwx_suffix_discipline`), not test-window length.

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD
  entry: TBD
  management: TBD
  close: TBD
estimated_complexity: medium                   # single-symbol entry rule but external intraday data dependency + 3× leverage exposure + scalping-class P5b latency calibration
estimated_test_runtime: TBD
data_requirements: other                       # PRIMARY: intraday LETF bar data (DRN or substitute); requires non-Darwinex-native data path
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
- 2026-05-08: Card lifted from "DRAFT-PENDING-or-SKIP" (SRC05 first-pass closeout policy) to DRAFT under [QUA-783](/QUA/issues/QUA-783) DL-057 OWNER directive. Prior policy was "draft only if CEO ratifies darwinex_native_data_only + dwx_suffix_discipline exception (instrument-substitution path)"; OWNER directive's "Hand to QB for G0 review" is interpreted as authorizing the draft with explicit § 11 / § 12 at-risk flagging, with QB G0 as the verdict gate on the data + symbol exception.
- 2026-05-08: VOCAB-GAP candidate `leveraged-etf-rebalance-momentum` proposed (per SRC05 source.md § 6 batch). Distinct from `time-series-momentum` (this is intraday with absolute return-threshold, leveraged-ETF-instrument-specific, with rebalance-flow economic mechanism). Sibling extension on V5 vocabulary; subordinate to broader closing-flow / MOC-flow flag family if CEO + CTO prefer to generalize at vocab review time.
- 2026-05-08: Substitution-path health warning documented in § 12 — synthetic 3×-leverage overlay on US500.DWX would replicate the underlying-stocks momentum but lose the 3× LETF-rebalance-flow amplification that is Chan's explicit causal mechanism (p. 164: "we use the leveraged ETFs as trading instruments simply to magnify the effect"). CEO + CTO assess whether unleveraged signal alone is large enough to justify V5 deployment; if not, the recommended path is SKIP and revisit when V5 acquires US-equity-ETF broker access.
- 2026-05-08: scalping_p5b_latency flagged PRIMARY OPERATIONAL — 15-min hold places this in scalping class; P5b stress with calibrated 1-3 second execution-latency VPS scenario is MANDATORY before P10 promotion. Signal-horizon-to-latency ratio at 300× (15min / 3sec) is comfortable but P5b confirms.
```
