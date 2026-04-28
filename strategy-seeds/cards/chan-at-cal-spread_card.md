# Strategy Card — Chan AT Futures Calendar-Spread Mean-Reversion (daily, long-far / short-near with roll-return Z-score signal)

> Drafted by Research Agent on 2026-04-28 from `strategy-seeds/sources/SRC05/raw/full_text.txt` lines 5758-5897 (Ex 5.4 verbatim) + Ex 5.3 spot/roll return estimation methodology lines 5583-5694.
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per QUA-188 waiver v3).

## Card Header

```yaml
strategy_id: SRC05_S06
ea_id: TBD
slug: chan-at-cal-spread
status: DRAFT
created: 2026-04-28
created_by: Research
last_updated: 2026-04-28

strategy_type_flags:
  - calendar-spread-mr                        # NEW VOCAB GAP — entry mechanism: cross-maturity futures spread (long far + short near or vice versa) with signal = Z-score of estimated roll return γ over halflife-derived lookback. Distinct from cointegration-pair-trade (mean reversion of the roll-return component, not of a cointegrated linear combo)
  - zscore-band-reversion                     # signal mechanism: Z-score of γ vs its own moving statistics
  - mean-reach-exit                           # exit when γ Z-score returns to mean (sign flip + exit on next contract roll)
  - symmetric-long-short                      # both calendar-spread directions (long-far / short-near AND vice versa) deployable
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Chan, Ernest P. (2013). Algorithmic Trading: Winning Strategies and Their Rationale. Wiley Trading. Hoboken, NJ: John Wiley & Sons. ISBN 978-1-118-46014-6 (cloth) / 978-1-118-46019-1 (ebk)."
    location: "Chapter 5 'Mean Reversion of Currencies and Futures', § 'Trading Futures Calendar Spread' + § 'Do Calendar Spreads Mean-Revert?' (PDF pp. 115-127 / printed pp. 115-127). Example 5.4 'Mean Reversion Trading of Calendar Spreads' (PDF pp. 123-127) is the primary CL 12-month-spread case. VX back/front-ratio variant is described inline at PDF pp. 126-127."
    quality_tier: A
    role: primary
```

Raw evidence: `strategy-seeds/sources/SRC05/raw/ch4_5_pp87-132.txt` + `strategy-seeds/sources/SRC05/raw/full_text.txt` lines 5583-5897. Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Algorithmic Trading_ Winning St - Ernie Chan.pdf`.

## 2. Concept

A **mean-reversion strategy on the futures calendar spread**, where the trading signal is the Z-score of the estimated roll return γ rather than the spread price itself. Chan's Equation 5.7 (p. 118) proposes that for many commodities, F(t,T) = S(t)·exp(γ·(t-T)), making the LOG calendar spread (T₁-T₂)·γ — i.e., the calendar spread depends ONLY on the roll return γ and the time-to-expiry difference. Chan p. 123: "the calendar spread trading signal does not depend at all on the spot price, only on the roll return!" If γ is itself mean-reverting (Chan ADF-tests this for CL and finds 99% probability of stationarity with 36-day half-life), then the calendar spread is a clean mean-reversion vehicle that isolates the roll-return component while neutralizing the spot return component.

The strategy holds a 12-month calendar spread (long contract expiring 12 months later vs short contract expiring 1 month later, or 91 trading days apart) and flips position sign based on the Z-score of γ:

> "positions(zScore > 0, :)=-positions(zScore > 0, :);" (Ex 5.4 MATLAB code, p. 125)

The default position is *long far / short near* (which is positive-roll-return-positioning — beneficial in backwardation); when γ Z-score crosses above 0, the position is flipped to *short far / long near* (beneficial in contango). Roll discipline: positions are held for ~3 months (61 trading days) and rolled forward 10 days before the near contract's expiration.

The card folds two source variants:

- **Variant A (Ex 5.4 default, PDF p. 124):** CL 12-month calendar spread on Crude Oil futures. APR 8.3%, Sharpe 1.3 (Jan 2008 - Aug 2012).
- **Variant B (Ex 5.4 inline, PDF p. 126-127):** VX back/front ratio mean-reversion (volatility futures calendar spread, but using ratio rather than log-spread because Equation 5.7 doesn't hold for VX since VIX is not a tradeable underlying — Chan p. 126). APR 17.7%, Sharpe 1.5 (Oct 2008 - Apr 2012).

Chan's verbatim summary of Variant A:

> "This results in an attractive unlevered APR of 8.3 percent and a Sharpe ratio of 1.3 from January 2, 2008, to August 13, 2012." (p. 125-126)

Chan's verbatim summary of Variant B:

> "If we apply our usual linear mean-reverting strategy using ratio as the signal (and with a 15-day look-back for the moving average and standard deviations), VX yields an APR of 17.7 percent and a Sharpe ratio of 1.5 from October 27, 2008, to April 23, 2012 (see Figure 5.8 for a plot of its cumulative returns), though it performed much more poorly prior to October 2008." (p. 127)

## 3. Markets & Timeframes

```yaml
markets:
  - commodities_futures                       # Chan's default: CL (WTI Crude Oil futures, NYMEX)
  - volatility_futures                        # Chan's variant: VX (CBOE Volatility Index futures, CFE)
  # V5 Darwinex-native fit is CHALLENGED: Darwinex offers spot CFDs on commodities (e.g., OIL.DWX for crude) but typically not multi-month-expiry futures contracts. CTO confirms at G0 whether calendar-spread structure can be approximated on Darwinex (e.g., spot vs CFD that tracks the front-month future). If not, the card is V5-architecture-CHALLENGED — flag dwx_suffix_discipline + darwinex_native_data_only at risk.
timeframes:
  - D1                                        # Chan deploys on daily closes
session_window: end-of-day                    # signals computed on daily close; entries/exits on next-day open
primary_target_symbols:
  - "CL (WTI Crude Oil future, NYMEX), 12-month calendar spread (default Variant A)"
  - "VX (CBOE Volatility Index future, CFE), back/front ratio (Variant B)"
  - "V5 Darwinex mapping: TBD — calendar-spread structure may require multi-contract subscription unavailable on Darwinex spot CFDs"
```

## 4. Entry Rules

Pseudocode — verbatim from Chan's Ch 5 Ex 5.4 (Variant A default, PDF pp. 123-126) and Ex 5.4 inline VX section (Variant B, p. 126-127).

```text
PARAMETERS (Chan-defaults from Ex 5.4 MATLAB code):
- HALFLIFE       = 36         // halflife of γ time series, computed via OLS regression on
                              //   Δγ vs γ_lag (Variant A CL); Chan p. 124: "The half-life is
                              //   found to be about 36 days."
- LOOKBACK       = HALFLIFE   // Chan p. 124: "the look-back set equal to the half-life, as
                              //   demonstrated in Example 2.5"
- HOLD_DAYS      = 63         // 3 months × 21 = 63 trading days; Chan: "The holding period for
                              //   a pair of contracts is 3 months (61 trading days)" (p. 124)
- ROLL_FORWARD   = 10         // days before near-contract expiration to roll into next pair;
                              //   Chan p. 124
- SPREAD_MONTHS  = 12         // months between far and near contracts; Chan default
- SIGNAL_FORM    = log_gamma_z // Variant A (CL): Z-score of γ; Variant B (VX): ratio back/front
                              //   with 15-day lookback (override below)

PER-DAY (at daily close, generating signals for next session):
- // Step 1 — pick the pair of contracts to trade per Chan's three rules (p. 124):
- //   a) hold each pair for HOLD_DAYS (=63); b) roll forward to next pair ROLL_FORWARD (=10)
- //      days before current near contract's expiry; c) far and near are SPREAD_MONTHS (=12)
- //      apart in expiration.
- // Default initial position: short near, long far (positive-roll-return-positioning;
- // beneficial in backwardation).
-
- // Step 2 — estimate the roll return γ as in Ex 5.3 (PDF p. 119-122): pick the trailing
- //   5 nearest-maturity contracts each day, fit log(F) vs T (months-to-expiry); slope = γ.
- gamma(t) = -12 * OLS_slope(log(F[t, :]), [1..5]')   // annualized γ (Eq 5.11 with sign convention)
-
- // Step 3 — compute Z-score of γ over its own LOOKBACK = HALFLIFE moving statistics
- ma_gamma  = MovingAverage(gamma, LOOKBACK)
- std_gamma = MovingStd(gamma, LOOKBACK)
- z_gamma(t) = (gamma(t) - ma_gamma) / std_gamma

ENTRY/POSITION-FLIP (Variant A default):
- if z_gamma(t) <= 0  then HOLD default position: SHORT near + LONG far
- if z_gamma(t) >  0  then FLIP position: LONG near + SHORT far
- Chan's MATLAB code: positions(zScore > 0, :) = -positions(zScore > 0, :)

ENTRY (Variant B alternative — VX back/front ratio):
- LOOKBACK_VX = 15  // override, Chan: "with a 15-day look-back" (p. 127)
- ratio(t) = price[VX_back][t] / price[VX_front][t]
- ma_ratio = MovingAverage(ratio, LOOKBACK_VX)
- std_ratio = MovingStd(ratio, LOOKBACK_VX)
- z_ratio(t) = (ratio(t) - ma_ratio) / std_ratio
- numUnits(t) = -z_ratio(t)   // linear MR on the ratio
- positions(t, :) = numUnits(t) .* [-1, +1] .* price[VX_pair][t]   // long-back / short-front by sign
```

## 5. Exit Rules

```text
EXIT (Variant A default — natural roll-cycle exit):
- Position is held for HOLD_DAYS (=63) by construction; or until ROLL_FORWARD (=10) days
  before the near contract's expiration.
- At each ROLL event, the strategy closes the current calendar spread and opens the next pair
  (1 year apart, 3 months hold).
- Z-score-driven SIGN flip is continuous within the hold period.

EXIT (Variant B — linear MR on ratio):
- numUnits(t) = -z_ratio(t) is rebalanced each bar (continuous); when z returns to 0,
  position naturally goes to 0.

NO STOP-LOSS (Chan's anti-stop-loss disposition Ch 6 p. 153):
- "stop losses are not consistent with mean-reverting strategies, because they contradict
  mean reversion strategies' entry signals."
- V5 framework's QM_KillSwitch + account MAX_DD trip is the catastrophic backstop.

Friday Close: standard V5 default applies (force-flat at Friday 21:00 broker time);
calendar-spread positions held for 63 days WILL straddle MANY weekends. The Friday-close
forced flat at the calendar-spread level is operationally awkward (re-establish 2-leg position
Monday open) — flag friday_close at risk.
```

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults: kill-switch, news filter, MAX_DD trip
- Friday Close: ENABLED (V5 default; flag friday_close at risk per § 12 — calendar-spread
  positions held 63 days straddle many weekends)
- pyramiding: NOT allowed (one open calendar-spread position at a time per pair-cycle)
- Optional cointegration self-test for γ stationarity (P3 sweep axis):
    skip entries when ADF p-value on trailing γ window > THRESHOLD (Variant A); skip when
    ADF p-value on trailing back/front ratio > THRESHOLD (Variant B)
    // Rationale: Chan p. 123: "We run the ADF test for 12-month log calendar spread of CL,
    //   and discovered that it is indeed stationary with 99 percent probability". If the
    //   stationarity assumption breaks, the strategy thesis collapses.
- Optional contract-liquidity filter:
    skip entries when far-contract open interest < MIN_OI or far-contract volume < MIN_VOL
    // Rationale: liquid near-contracts are easy; far contracts (12 months out) can be thin.
```

## 7. Trade Management Rules

```text
- one open calendar-spread position at any time (no pyramiding within a pair-cycle)
- gridding: NOT allowed
- contract roll: each pair held for HOLD_DAYS=63 trading days; rolled forward ROLL_FORWARD=10
  days before near contract's expiry to the next 12-month pair
- position size per leg: maps to V5 risk-mode framework at sizing-time;
  catastrophic risk handled by kill-switch since strategy has no native stop
- Variant A default: discrete SIGN flips (+1 or -1 of the spread); position direction
  changes intra-cycle but quantity stays at unit magnitude
- Variant B: continuous numUnits = -z_ratio (linear MR), unbounded magnitude
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: halflife_lookback
  default: 36
  sweep_range: [14, 21, 36, 60, 90]            # Chan reports 36 days (CL-derived); sweep brackets typical commodity-spread halflife range
- name: hold_days
  default: 63
  sweep_range: [21, 42, 63, 84, 126]           # Chan reports 63 (3 months); sweep brackets 1mo-6mo holding
- name: roll_forward
  default: 10
  sweep_range: [5, 10, 15, 20]                 # Chan reports 10; days-before-expiration roll trigger
- name: spread_months
  default: 12
  sweep_range: [3, 6, 9, 12, 15, 18]           # Chan default 12; tighter spread = lower roll-return signal-to-noise
- name: signal_form
  default: log_gamma_z                         # Variant A
  sweep_range: ["log_gamma_z", "back_front_ratio_z", "log_back_front_z"]
                                              # Variant A (CL log-gamma) vs Variant B (VX ratio) vs hybrid (log of ratio)
- name: lookback_v_ratio
  default: 15                                  # Variant B specific
  sweep_range: [5, 10, 15, 20, 30]
- name: gamma_estimator
  default: ols_5_nearest
  sweep_range: ["ols_5_nearest", "ols_3_nearest", "ols_8_nearest"]
                                              # number of nearest contracts used for Eq 5.7 OLS fit; Chan uses 5
- name: stationarity_filter_p
  default: 0
  sweep_range: [0, 0.05, 0.10, 0.20]           # ADF p-value threshold; 0 disables filter
```

P3.5 (CSR) axis: re-run on alternative commodity futures with strong roll-return profiles. Candidates per Chan Table 5.1 (p. 121): BR (Brazilian Real, γ=10.8% annualized), C (Corn, γ=-12.8%), HG (Copper, γ=3.2%), TU (2-year T-Note, γ=7.7%). VX is Variant B canonical case. V5 Darwinex availability TBD.

## 9. Author Claims (verbatim, with quote marks)

Variant A (Ex 5.4 default) — CL 12-month calendar spread, daily bars, halflife=lookback=36, 3-month hold:

> "This results in an attractive unlevered APR of 8.3 percent and a Sharpe ratio of 1.3 from January 2, 2008, to August 13, 2012." (p. 125-126)

Theoretical framing for the calendar-spread MR thesis (p. 123):

> "the calendar spread trading signal does not depend at all on the spot price, only on the roll return!"

> "We run the ADF test for 12-month log calendar spread of CL, and discovered that it is indeed stationary with 99 percent probability, and a half-life of 36 days. Furthermore, if we apply our usual linear mean-reverting strategy to the log calendar spread for CL, we do get an APR of 8.3 percent and a Sharpe ratio of 1.3 from January 2, 2008, to August 13, 2012." (p. 123)

Variant B (Ex 5.4 inline VX section) — VX back/front ratio, 15-day lookback:

> "If we apply our usual linear mean-reverting strategy using ratio as the signal (and with a 15-day look-back for the moving average and standard deviations), VX yields an APR of 17.7 percent and a Sharpe ratio of 1.5 from October 27, 2008, to April 23, 2012 (see Figure 5.8 for a plot of its cumulative returns), though it performed much more poorly prior to October 2008." (p. 127)

Why VX requires a different signal form than CL (p. 126):

> "It turns out that Equation 5.7 works only for a future whose underlying is a traded asset, and VIX is not one. (If you scatter-plot the log VX futures prices as a function of time-to-maturity as we did in Figure 5.4 for CL, you will find that they do not fall on a straight line.) ... we can rely on only our empirical observation that an ADF test on the ratio back/front of VX also shows that it is stationary with a 99 percent probability."

Performance qualifier on VX (p. 127):

> "though it performed much more poorly prior to October 2008. ... there is a regime change in the behavior of VIX and its futures around the time of the financial crisis of 2008"

Anti-stop-loss disposition (Ch 6 p. 153):

> "stop losses are not consistent with mean-reverting strategies, because they contradict mean reversion strategies' entry signals."

## 10. Initial Risk Profile

```yaml
expected_pf: 1.4                              # Chan's Variant A APR 8.3% / Sharpe 1.3 implies ~PF 1.3-1.5 unlevered; Variant B
                                              # APR 17.7% / Sharpe 1.5 implies higher PF post-2008. Realistic Darwinex futures-CFD
                                              # spreads will compress this; P9b confirms.
expected_dd_pct: 18                           # rough estimate; Sharpe 1.3-1.5 + zero-stop + multi-month holds implies meaningful DD
expected_trade_frequency: 4-6/year/pair       # 3-month hold cycle = 4 cycles/year per active pair; signal-flips within cycle add to count
risk_class: medium                            # daily-bar futures-MR with no native stop and multi-month holds
gridding: false
scalping: false                               # 63-day hold; not scalping
ml_required: false                            # OLS regression for γ + Z-score is classical statistics, no fitted-function approximator
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical (γ estimation via OLS + Z-score threshold-crossing is fully deterministic)
- [x] No Machine Learning required (classical statistics)
- [x] If gridding: not applicable (one open calendar-spread position per pair-cycle)
- [x] If scalping: not applicable (D1 timeframe, 63-day hold)
- [ ] **Friday Close compatibility:** 63-day calendar-spread holds straddle MANY weekends; flag `friday_close` at risk (§ 12). Forced flat at Friday 21:00 → re-establish 2-leg position Monday is operationally awkward. Net effect on backtest TBD at P3.
- [x] Source citation is precise enough to reproduce (chapter + section + Example number + verbatim MATLAB code + verbatim performance quotes + Equation 5.7-5.11 derivation)
- [ ] **No near-duplicate of existing approved card** — distinct from S01/S02/S05 chan-at-{bb,kf,fx-coint}-pair (those are spread-of-two-instruments; this is calendar-spread-of-same-instrument-different-maturities — different mechanism class). DISAMBIGUATION confirmed at extraction.

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "standard V5 default (kill-switch, news filter, MAX_DD trip, Friday-close); optional ADF stationarity filter on γ + contract-liquidity filter as sweep axes."
  trade_entry:
    used: true
    notes: "γ Z-score threshold (Variant A) or ratio Z-score (Variant B) on D1 close; one calendar-spread position at a time per pair-cycle"
  trade_management:
    used: true
    notes: "Variant A: discrete SIGN flips on z_gamma crossing 0 within the 63-day hold cycle; Variant B: continuous numUnits = -z_ratio rebalance"
  trade_close:
    used: true
    notes: "Variant A: cycle-based exit at HOLD_DAYS=63 + roll forward 10 days before expiry; Variant B: numUnits → 0 as z → 0"
```

```yaml
hard_rules_at_risk:
  - friday_close                              # 63-day calendar-spread holds straddle many weekends; forced Friday flat is awkward
  - dwx_suffix_discipline                     # Chan's universe is CME/CBOT/NYMEX/CFE futures (CL, VX); V5 deploys on Darwinex .DWX symbols.
                                              # Calendar-spread structure requires MULTIPLE expiry contracts simultaneously — Darwinex
                                              # typically offers spot/CFD on the front-month future only; multi-month-expiry coverage
                                              # is limited. CTO confirms at G0 whether the calendar-spread structure is buildable on
                                              # Darwinex (e.g., synthetic via two contract-rollovers, or via multiple simultaneous CFDs).
                                              # If not, V5-architecture-CHALLENGED — flag escalation to CEO.
  - darwinex_native_data_only                 # roll-return γ estimation requires multi-month forward-curve prices (5 nearest contracts
                                              # per Chan's Ex 5.3 setup). May not be in Darwinex-native data feed; flag if not.
  - kill_switch_coverage                      # no native stop-loss (Chan's anti-stop-loss disposition Ch 6 p. 153). Catastrophic backstop
                                              # relies on V5's QM_KillSwitch and account-level MAX_DD trip.
  - enhancement_doctrine                      # halflife=36 derived from CL ADF; lookback=halflife; hold=63 days; roll-forward=10 days; spread=12 months — all Chan-stated-with-hindsight; any post-PASS retune counts as enhancement_doctrine event.

at_risk_explanation: |
  friday_close — 63-day calendar-spread holds straddle MANY weekends. Forced flat at Friday
  21:00 + re-establishment of 2-leg position Monday open is operationally awkward and adds
  transaction-cost burden. Net backtest impact TBD at P3; structurally the strategy may
  require a friday_close exception waiver (analogous to SRC02 chan-pairs-stat-arb's request).

  dwx_suffix_discipline + darwinex_native_data_only — load-bearing. Calendar-spread structure
  needs multi-month forward-curve prices simultaneously. Darwinex typically offers only spot
  CFDs (e.g., OIL.DWX = WTI Crude spot CFD ≈ front-month CL proxy) and may NOT offer 12-month-
  ahead synthetic forward exposure. If unavailable: card is V5-ARCHITECTURE-CHALLENGED and may
  need either (a) rejection at G0 with rationale, (b) instrument substitution to a Darwinex-
  native multi-asset proxy (e.g., commodity-vs-equity arb similar to S08 chan-at-roll-arb-etf),
  or (c) deferral until Darwinex onboards futures-curve data. CEO ratification at G0.

  kill_switch_coverage — no native stop-loss + 63-day-hold strategy = significant
  weekend-gap exposure even with kill-switch backstop. CTO sanity-checks at P5.

  enhancement_doctrine — All key parameters are Chan-stated-with-hindsight (halflife from
  CL-specific ADF; 12-month spread from CL-curve-shape observation; 3-month hold somewhat
  arbitrary). P3 sweep is the strategy's first proper out-of-sample tuning; any post-PASS
  retune is enhancement_doctrine.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                               # standard V5 default; optional ADF filter + contract-liquidity filter
  entry: TBD                                  # γ estimation via OLS on 5 nearest contracts (Eq 5.11) + Z-score on rolling 36-day window + sign-based position. ~150-250 LOC native MQL5 (regression + multi-contract data plumbing)
  management: TBD                             # 63-day hold cycle + roll-forward 10 days before near expiry + intra-cycle sign-flip on z=0
  close: TBD                                  # cycle-based exit at HOLD_DAYS or roll-forward trigger; no native stop
estimated_complexity: large                   # multi-contract data plumbing + OLS γ estimation + roll-cycle management is 3-5x complexity of a single-symbol strategy; ~250-450 LOC native MQL5
estimated_test_runtime: 6-12h                 # P3 sweep is large (5×5×4×6×3×5×3×4 ≈ 36,000 cells effective ~10,000); multi-month historical data per backtest day adds disk I/O burden
data_requirements: custom_futures_curve       # multi-month forward-curve daily prices (5 nearest contracts simultaneously); NOT standard single-CFD data — flag at G0 for CTO + Pipeline-Operator data-acquisition planning
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
- 2026-04-28: SRC05_S06 surfaces a NEW `strategy_type_flags` controlled-vocabulary GAP
  (entry side): `calendar-spread-mr` — entry mechanism: cross-maturity futures spread
  (long far + short near or vice versa) where the trading signal is the Z-score of the
  estimated roll return γ over a halflife-derived lookback. Distinct from:
  - `cointegration-pair-trade` (mean reversion of a stationary linear combination of two
    different instruments; calendar spread is mean reversion of the roll-return component
    of the SAME instrument's term structure, mathematically different).
  - `zscore-band-reversion` (single-leg own moving statistics on PRICE; calendar spread
    is on derived γ or back/front ratio, not on a price level).
  - `futures-roll-return-arb` (SRC05_S08 inline strategy; that flag is for ETF-vs-future
    cross-instrument arbitrage based on roll-return SIGN; calendar-spread-mr is
    intra-curve, single-instrument calendar arbitrage based on roll-return Z-SCORE).
  V4 had no calendar-spread-MR SM_XXX EAs per `strategy_type_flags.md` Mining-provenance
  table. Chan citation: Ch 5 Ex 5.4 pp. 123-127. Will batch-propose to CEO + CTO via
  the addition-process at the bottom of `strategy_type_flags.md`.

- 2026-04-28: V5-architecture-fit is CHALLENGED. The strategy requires multi-month
  forward-curve data (5 nearest contracts simultaneously per Ex 5.3 γ-estimator) and
  multi-leg simultaneous calendar-spread positions, which are NOT the standard Darwinex
  spot/CFD profile. CTO confirms at G0 whether the structure is buildable on Darwinex; if
  not, card may require (a) instrument substitution, (b) Darwinex futures-curve data
  onboarding (out-of-scope for V5 timeline), or (c) G0 SKIP with rationale. This is the
  FIRST SRC05 card with a structural V5-architecture-fit problem at the data layer (S03,
  S04 face universe-cardinality challenges, but those are at the magic-schema layer; S06
  is at the data-feed layer).

- 2026-04-28: Variant A vs Variant B fold decision. Variant A (CL log-γ Z-score) and
  Variant B (VX back/front ratio Z-score) share the same VOCAB CLASS (`calendar-spread-mr`)
  but use different signal forms because Equation 5.7 doesn't hold for VX (whose underlying
  VIX is not a tradeable asset, p. 126). Two readings:
  (i) Two separate cards (Variant A vs Variant B) — clean separation by signal form.
  (ii) ONE card with `signal_form` parameter — fold-by-PARAMETER per the SRC03 fold-pattern
       precedent.
  CARD ADOPTS (ii) because: Chan's Ch 5 narrative treats them as the same strategy class
  with different signal forms; the trading mechanic is identical (long-far/short-near
  calendar spread with sign-flip on Z-score crossing 0); only the SIGNAL form differs.
  CEO sanity-checks at G0 whether to split.

- 2026-04-28: This is a multi-LEG strategy (long contract X expiry month, short contract X
  expiry month + 12). Magic-schema implications: V5 default `one_position_per_magic_symbol`
  may NOT cover multi-leg correctly. CTO sanity-checks at G0 whether the V5 framework
  handles 2-leg simultaneous positions on the same underlying with different magic numbers
  (one per leg) — this is the FIRST SRC05 card with multi-leg same-underlying positions.
  Sister cards SRC02 chan-pairs-stat-arb / SRC05 S01 chan-at-bb-pair / SRC05 S02
  chan-at-kf-pair / SRC05 S05 chan-at-fx-coint-pair are also 2-leg but on DIFFERENT
  underlyings; same-underlying multi-leg is structurally distinct.
```
