# Strategy Card — Chan AT VX-ES Roll-Return Momentum (daily, contango/backwardation-driven 2-leg same-direction trade, Simon-Campasano 2012)

> Drafted by Research Agent on 2026-04-28 from `strategy-seeds/sources/SRC05/raw/ch6_7_pp133-168.txt` lines 1057-1107 (VX-ES roll-return strategy verbatim, Simon-Campasano 2012 derivative) + lines 1085-1091 (causal thesis on roll-return-driven momentum) + Ch 5 Eq 5.11 hedge-ratio reference.
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per QUA-188 waiver v3).

## Card Header

```yaml
strategy_id: SRC05_S09
ea_id: TBD
slug: chan-at-vx-es-roll-mom
status: DRAFT
created: 2026-04-28
created_by: Research
last_updated: 2026-04-28

strategy_type_flags:
  - futures-roll-return-arb                   # NEW VOCAB GAP (shared with S08) — entry mechanism: position direction set by roll-return regime sign on the underlying. S08 goes AGAINST the regime (extract roll return); S09 goes WITH the regime (capture roll-return-driven momentum). Both fall under the same vocab class. Flag NEW per S08; reused here.
  - signal-reversal-exit                      # exit/flip mechanism: position is held 1 day per Simon-Campasano (continuous daily rebalance) — implicitly equivalent to signal-driven entry/exit per bar
  - symmetric-long-short                      # both contango and backwardation directions deployable (mirror entry rules)
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Chan, Ernest P. (2013). Algorithmic Trading: Winning Strategies and Their Rationale. Wiley Trading. Hoboken, NJ: John Wiley & Sons. ISBN 978-1-118-46014-6 (cloth) / 978-1-118-46019-1 (ebk)."
    location: "Chapter 6 'Interday Momentum Strategies', § 'Volatility Futures versus Equity Index Futures: Redux' (PDF pp. 143-144 / printed pp. 143-144). Inline strategy with verbatim entry/exit rules at PDF pp. 143-144. Hedge-ratio derivation at Ch 5 § 'Volatility Futures versus Equity Index Futures' Eq 5.11 PDF p. 131."
    quality_tier: A
    role: primary
  - type: paper
    citation: "Simon, David P., and Jim Campasano. (2012). The VIX Futures Basis: Evidence and Trading Strategies. SSRN Working Paper / Journal of Alternative Investments."
    location: "cited by Chan p. 143 as the source paper for the VX-ES roll-return entry rules. Note: Chan modifies the hedge ratio (uses Eq 5.11 prices-regression slope) vs Simon-Campasano (returns-regression slope) — Chan p. 144"
    quality_tier: A
    role: supplement
```

Raw evidence: `strategy-seeds/sources/SRC05/raw/ch6_7_pp133-168.txt` lines 1057-1107. Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Algorithmic Trading_ Winning St - Ernie Chan.pdf`.

## 2. Concept

A **2-leg same-direction momentum strategy on VX (CBOE Volatility Index futures) + ES (E-mini S&P 500 futures)** that exploits the chronic large-magnitude roll return on VX (~-50% annualized contango) plus the high anti-correlation between VX and ES daily returns (Chan Ch 5 § "Volatility Futures versus Equity Index Futures": correlation reaching -75%). This is a sibling-but-DISTINCT strategy from S08 chan-at-roll-arb-etf: where S08 trades AGAINST the regime (long the spot proxy + short the future under contango to extract the roll return), S09 trades WITH the regime (short BOTH legs under contango — the VX short captures the negative roll return and the ES short hedges spot direction via the VX-ES anti-correlation).

Chan's setup (PDF p. 143):

> "VX is a natural choice if we want to extract roll returns: its roll returns can be as low as −50 percent annualized. At the same time, it is highly anti-correlated with ES, with a correlation coefficient of daily returns reaching −75 percent. In Chapter 5, we used the cointegration between VX and ES to develop a profitable mean-reverting strategy. Here, we will make use of the large roll return magnitude of VX, the small roll return magnitude of ES, and the anticorrelation of VX and ES to develop a momentum strategy."

The verbatim strategy rules from Chan PDF p. 143:

> "This strategy was proposed by Simon and Campasano (2012):
> 1. If the price of the front contract of VX is higher than that of VIX by 0.1 point (contango) times the number of trading days untill settlement, short 0.3906 front contracts of VX and short 1 front contract of ES. Hold for one day.
> 2. If the price of the front contract of VX is lower than that of VIX by 0.1 point (backwardation) times the number of trading days untill settlement, buy 0.3906 front contracts of VX and buy 1 front contract of ES. Hold for one day."

Roll-return interpretation (Chan p. 143):

> "Recall that if the front contract price is higher than the spot price, the roll return is negative (see Figure 5.3). So the difference in price between VIX and VX divided by the time to maturity is the roll return, and we buy VX if the roll return is positive."

Why VX requires its own non-Eq-5.7 signal form (Chan p. 144):

> "Why didn't we use the procedure in Example 5.3 where we use the slope of the futures log forward curve to compute the roll return here? That is because Equation 5.7 doesn't work for VX, and therefore the VX forward prices do not fall on a straight line, as explained in Chapter 5."

The hedge ratio is from Eq 5.11 (Chan PDF p. 131), based on price-level regression rather than returns-regression (which Simon-Campasano used):

> "Notice that the hedge ratio of this strategy is slightly different from that reported by Simon and Campasano: It is based on the regression fit between the VX versus ES prices in Equation 5.11, not between their returns as in the original paper." (p. 144)

The hedge ratio 0.3906 (and the unit conversion -0.3906 × VX × 1000 + $77,150 = ES × 50) means: each 1-point move in VX corresponds to 0.3906 contracts of VX × $1,000/point = $390.60, which equals 1 contract of ES × $50/point × 7.81 points = $390.60. The 2-leg position is therefore *price-neutral* on the regression fit but exposes the non-regression-residual which is the roll-return-driven net direction.

## 3. Markets & Timeframes

```yaml
markets:
  - volatility_futures + equity_index_futures # Chan's deployment: VX (CBOE VIX future) + ES (E-mini S&P 500 future). The strategy specifically exploits the asymmetric roll-return profile (VX large-negative, ES near-zero) plus the anti-correlation
  # V5 Darwinex re-mapping at CTO sanity-check: Darwinex offers VIX-related instruments (VOLX.DWX or similar VIX CFD) and US500.DWX (S&P 500 CFD). However, both are spot/CFD products, not multi-month-expiry futures. The "front contract of VX higher than VIX by 0.1 × DTS" signal requires (a) VIX SPOT price AND (b) front-month VX FUTURE price simultaneously — Darwinex's VIX CFD likely tracks one or the other, not both. CTO confirms at G0; flag dwx_suffix_discipline + darwinex_native_data_only at risk.
timeframes:
  - D1                                        # Chan deploys on daily closes
session_window: end-of-day                    # signals computed on daily close (or end-of-trading-day for VX); entries on next-day open; HOLD = 1 day so daily turnover
primary_target_symbols:
  - "VX (CBOE VIX future, CFE) — 0.3906 front-contract leg"
  - "ES (E-mini S&P 500 future, CME) — 1 front-contract leg"
  - "VIX (CBOE Volatility Index spot) — used for signal generation only (not traded)"
  - "V5 Darwinex mapping: TBD — VIX-spot data feed availability + multi-month-expiry VX future are load-bearing; CTO at G0"
```

## 4. Entry Rules

Pseudocode — verbatim from Chan's Ch 6 inline VX-ES strategy (PDF pp. 143-144).

```text
PARAMETERS (Chan-stated, Simon-Campasano 2012 derivative):
- BAR              = D1                       // Chan deploys on daily closes
- HEDGE_RATIO_VX   = 0.3906                   // contracts of VX per 1 contract of ES;
                                              //   from Eq 5.11 prices-regression slope (Ch 5 p. 131):
                                              //   ES * 50 = -0.3906 * VX * 1000 + $77,150
- THRESHOLD_PER_DAY = 0.1                     // points-of-VX-vs-VIX difference per day-to-settlement;
                                              //   Chan p. 143: "0.1 point (contango) times the number
                                              //   of trading days until settlement"
- HOLD             = 1                        // 1-day holding period; Chan p. 143: "Hold for one day"
- LEG_SIZING       = unit_pair_with_hedge     // 0.3906 VX contracts per 1 ES contract
- DTS              = days_to_settlement       // trading days until VX front contract settlement;
                                              //   "settlement is the day after the contracts expire"
                                              //   (Chan p. 144)

PER-DAY (at daily close, generating signals for next session):
- VX_front(t)  = price of front-month VX future at t close
- VIX(t)       = VIX spot index at t close
- DTS(t)       = trading days remaining until front-month VX expiration

- DIFFERENCE(t) = VX_front(t) - VIX(t)
- THRESHOLD(t) = THRESHOLD_PER_DAY * DTS(t)   // dynamic threshold scales with time-to-settlement

- // Roll-return regime classification (Chan p. 143)
- if DIFFERENCE(t) > THRESHOLD(t):             // CONTANGO (VX above VIX by > 0.1·DTS)
-     // Roll return on VX is large-negative; go-with-regime momentum
-     target_position = (VX_units = -HEDGE_RATIO_VX,    // short 0.3906 VX
-                        ES_units = -1.0)               // short 1 ES
-     // Chan: "short 0.3906 front contracts of VX and short 1 front contract of ES"
- elif DIFFERENCE(t) < -THRESHOLD(t):          // BACKWARDATION (VX below VIX by > 0.1·DTS)
-     target_position = (VX_units = +HEDGE_RATIO_VX,    // long 0.3906 VX
-                        ES_units = +1.0)               // long 1 ES
-     // Chan: "buy 0.3906 front contracts of VX and buy 1 front contract of ES"
- else:                                        // |DIFFERENCE| ≤ THRESHOLD → no trade
-     target_position = (0, 0)

ENTRY:
- At day t close, OPEN target_position at next-session open.
- Position is HELD FOR EXACTLY 1 DAY then closed (Chan: "Hold for one day").
- Daily re-evaluation produces continuous-style trading: each day either re-enters the
  same direction (regime persists) or flips/exits (regime change).
```

## 5. Exit Rules

```text
EXIT (1-day fixed hold):
- Each position is closed at the next-day close (or next-day open after being open for 1
  trading day) per Chan: "Hold for one day."
- Daily rebalance to new target_position based on next-day's closing DIFFERENCE.

NO STOP-LOSS in Chan's stated rules. The strategy relies on:
- The 1-day-hold horizon to bound per-trade risk
- The 2-leg same-direction structure where ES short hedges the VX-short's spot-equity
  exposure (and vice versa)
- V5 framework's QM_KillSwitch + account MAX_DD trip is the catastrophic backstop

Friday Close: standard V5 default applies. 1-day-hold means most positions are intra-week,
but Friday positions held until Monday violate the 1-day-hold spec literally. The
operationally clean interpretation is: skip Friday entries, OR force flat at Friday 21:00
and re-enter Monday open with the new signal — flag friday_close at risk.
```

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults: kill-switch, news filter, MAX_DD trip
- Friday Close: ENABLED (V5 default; flag friday_close at risk per § 12 — 1-day-hold spec
  is broken by weekend gaps; clean interpretation = skip Friday entries OR daily re-eval
  on Monday open)
- pyramiding: NOT allowed (one open 2-leg position per pair; daily rebalance to net target)
- Optional dead-band magnitude filter (P3 sweep axis):
    skip entries when |DIFFERENCE(t)| ≤ THRESHOLD_FACTOR * THRESHOLD(t)
    // THRESHOLD_FACTOR=1.0 is Chan's default; sweep brackets [0.5, 1.0, 1.5, 2.0]
    // Higher factor reduces signal noise but reduces trade count
- Optional VX-front-month-near-expiry guard:
    skip entries when DTS(t) <= MIN_DTS
    // Rationale: as DTS → 0, the dynamic THRESHOLD shrinks to 0 making the signal hyper-
    //   sensitive; settlement-day position is operationally awkward.
    //   Chan does not specify; sweep-derived. MIN_DTS = 2 or 3 trading days reasonable.
- Optional VIX-level regime gate:
    skip entries when VIX > VIX_MAX (e.g., 40)
    // Rationale: in extreme volatility regimes (2008 crisis, March 2020), the VX-VIX
    //   relationship breaks down (Chan p. 144 references regime change post-2008). Defense
    //   against this is a P3 sweep axis.
```

## 7. Trade Management Rules

```text
- one open 2-leg position per pair at any time; daily-rebalanced to net target
- gridding: NOT allowed
- per-leg sizing: 0.3906 VX contracts per 1 ES contract (Chan-stated unit-pair); CTO converts
  to risk-equivalent at sizing-time
- no native stop; catastrophic backstop via kill-switch + MAX_DD
- contract roll: VX front-month must roll to new front-month each cycle (~30 days); Chan
  p. 144: "The settlement is the day after the contracts expire." Pipeline-Operator's
  standard continuous-contract roll convention applies; settlement-day rollover handled
  per the optional VX-near-expiry guard.
- ES front-month also rolls quarterly (March-June-September-December cycle); same standard
  roll convention.
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: hedge_ratio_vx
  default: 0.3906
  sweep_range: [0.30, 0.35, 0.3906, 0.45, 0.50]
                                                # Chan: 0.3906 (Eq 5.11 prices-regression). Simon-Campasano original used returns-regression slope (different value); sweep brackets both
- name: threshold_per_day
  default: 0.1
  sweep_range: [0.05, 0.08, 0.10, 0.15, 0.20]   # points-of-VX-VIX difference per day-to-settlement; Chan: 0.1
- name: hold_days
  default: 1
  sweep_range: [1, 2, 3, 5]                     # Chan: 1; sweep brackets up to 1-week extension
- name: dead_band_factor
  default: 1.0                                  # 1.0 = exactly Chan-spec; >1.0 = wider dead-band, fewer trades
  sweep_range: [0.5, 1.0, 1.5, 2.0]
- name: min_dts
  default: 0                                    # 0 disables the near-expiry guard
  sweep_range: [0, 2, 3, 5]                     # skip entries when days-to-settlement < min_dts
- name: vix_level_max
  default: 100                                  # 100 effectively disables (VIX rarely > 100)
  sweep_range: [40, 60, 80, 100]                # skip entries when VIX > vix_level_max
- name: leg_sizing_form
  default: unit_pair_with_hedge                 # Chan default (0.3906 VX / 1 ES)
  sweep_range: ["unit_pair_with_hedge", "dollar_neutral", "vol_neutral_atr"]
                                                # alternative sizing schemes
```

P3.5 (CSR) axis: the strategy's identity is VX-ES specific (the (large-negative VX roll return) + (near-zero ES roll return) + (high VX-ES anti-correlation) triangle is unique). Generalization to other volatility-vs-equity pairs (e.g., VSTOXX vs Euro Stoxx 50) would require independent validation of the same triangle of properties. For SRC05 this is OUT OF SCOPE; the card is single-pair by construction. P3.5 CSR is reduced to per-period sub-sample stability rather than cross-symbol generalization.

## 9. Author Claims (verbatim, with quote marks)

Strategy entry/exit rules verbatim (PDF p. 143):

> "This strategy was proposed by Simon and Campasano (2012):
> 1. If the price of the front contract of VX is higher than that of VIX by 0.1 point (contango) times the number of trading days untill settlement, short 0.3906 front contracts of VX and short 1 front contract of ES. Hold for one day.
> 2. If the price of the front contract of VX is lower than that of VIX by 0.1 point (backwardation) times the number of trading days untill settlement, buy 0.3906 front contracts of VX and buy 1 front contract of ES. Hold for one day."

Performance verbatim (PDF pp. 143-144):

> "Notice that the hedge ratio of this strategy is slightly different from that reported by Simon and Campasano: It is based on the regression fit between the VX versus ES prices in Equation 5.11, not between their returns as in the original paper. The settlement is the day after the contracts expire. The APR for July 29, 2010, to May 7, 2012 (this period was not used for hedge ratio determination) is 6.9 percent, with a Sharpe ratio of 1. The cumulative return chart is displayed in Figure 6.4."

Causal thesis (PDF p. 143):

> "VX is a natural choice if we want to extract roll returns: its roll returns can be as low as −50 percent annualized. At the same time, it is highly anti-correlated with ES, with a correlation coefficient of daily returns reaching −75 percent. ... we will make use of the large roll return magnitude of VX, the small roll return magnitude of ES, and the anticorrelation of VX and ES to develop a momentum strategy."

Roll-return-from-curvature interpretation (PDF p. 143):

> "Recall that if the front contract price is higher than the spot price, the roll return is negative (see Figure 5.3). So the difference in price between VIX and VX divided by the time to maturity is the roll return, and we buy VX if the roll return is positive."

Why VX needs the non-Eq-5.7 signal form (PDF p. 144):

> "Why didn't we use the procedure in Example 5.3 where we use the slope of the futures log forward curve to compute the roll return here? That is because Equation 5.7 doesn't work for VX, and therefore the VX forward prices do not fall on a straight line, as explained in Chapter 5."

Distinction from MR strategy on same instruments (PDF p. 143, p. 152):

> "There is a different VX versus ES strategy that we can employ, which does not rely on the mean-reverting properties of the spread VX-ES. Because that is a momentum strategy, I will discuss it in the next chapter." (Ch 5 p. 132 forward reference)

## 10. Initial Risk Profile

```yaml
expected_pf: 1.3                              # Chan reports APR 6.9% / Sharpe 1 unlevered; PF ≈ 1.2-1.4 unlevered
expected_dd_pct: 15                           # rough estimate; Sharpe 1 + zero-stop + 1-day-hold + crisis-period sensitivity
expected_trade_frequency: 200/year            # daily evaluation; Chan does not state but daily-bar daily-decision implies high turnover; ~200 trading days/year × signal-frequency (most days produce a +1 or -1 signal in normal regimes)
risk_class: medium                            # daily-bar 2-leg long-short; 1-day-hold limits per-trade risk; tail-risk on volatility-regime breakage (2008-style)
gridding: false
scalping: false                               # daily-bar; 1-day-hold; not scalping
ml_required: false                            # threshold comparison + fixed hedge ratio; classical statistics only
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical (DIFFERENCE(t) vs THRESHOLD(t) comparison + 0.3906 VX / 1 ES position is fully deterministic)
- [x] No Machine Learning required (threshold comparison + fixed hedge ratio)
- [x] If gridding: NOT applicable (one 2-leg position per pair; daily rebalance to net target)
- [x] If scalping: NOT applicable (D1 timeframe, 1-day-hold per Chan)
- [ ] **Friday Close compatibility:** 1-day-hold spec ambiguous over weekends — clean interpretation is "skip Friday entries" OR "force flat at Friday 21:00 and re-evaluate Monday". Net effect TBD at P3.
- [x] Source citation is precise enough to reproduce (chapter + section + verbatim Simon-Campasano-derivative rules + verbatim performance quotes + Eq 5.11 hedge ratio derivation)
- [ ] **No near-duplicate of existing approved card** — distinct from S08 chan-at-roll-arb-etf (which goes AGAINST the regime; this card goes WITH the regime — opposite direction-of-travel relative to roll-return sign), distinct from existing Ch 5 VX-ES MR strategy (which uses the SAME instruments but in MR direction with cointegration spread; this is momentum direction with roll-return signal). DISAMBIGUATION confirmed at extraction.

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "standard V5 default (kill-switch, news filter, MAX_DD trip, Friday-close); optional dead-band, near-expiry guard, VIX-regime gate as P3 sweep axes."
  trade_entry:
    used: true
    notes: "DIFFERENCE(t) = VX_front(t) - VIX(t) vs ±THRESHOLD(t) = ±0.1 × DTS comparison; 0.3906 VX / 1 ES leg sizing"
  trade_management:
    used: true
    notes: "one 2-leg position per pair; 1-day-hold; daily rebalance"
  trade_close:
    used: true
    notes: "1-day fixed exit; daily re-evaluation to next target"
```

```yaml
hard_rules_at_risk:
  - friday_close                              # 1-day-hold spec ambiguous over weekends; clean interpretation is "skip Friday entries" or "force flat at Friday 21:00 + re-evaluate Monday"
  - dwx_suffix_discipline                     # Chan's universe is CFE VX + CME ES + CBOE VIX spot. V5 deploys on Darwinex .DWX symbols. VIX/VX/ES instruments and especially multi-month-expiry contracts may not be in Darwinex universe. CTO confirms at G0; flag dwx_suffix_discipline at risk. Without VIX spot data, the "DIFFERENCE = VX_front - VIX" signal cannot be computed.
  - darwinex_native_data_only                 # Strategy requires (a) VIX SPOT price feed AND (b) VX FRONT-MONTH FUTURE price feed simultaneously. Whether Darwinex provides BOTH (or whether VIX spot is derivable from a Darwinex CFD that tracks it) is a load-bearing G0 question. Likely external data feed (CBOE / Refinitiv) needed for VIX spot; flag at G0.
  - kill_switch_coverage                      # no native stop-loss + 1-day-hold + 2-leg same-direction structure that exposes BOTH legs in same direction. The 2008 financial crisis (regime change in VX-ES anti-correlation) and the March 2020 volmageddon are crisis-slice priors for P5c. Chan p. 144 implicitly references regime change post-2008.
  - enhancement_doctrine                      # 0.3906 hedge ratio (Eq 5.11), 0.1-per-day threshold, 1-day-hold are Chan-stated-with-Simon-Campasano-attribution. Any post-PASS retune is enhancement_doctrine.
  - one_position_per_magic_symbol             # 2-leg simultaneous (VX + ES) violates strict one_position_per_magic_symbol; same root issue as S05/S06/S08. CTO at G0.
  - magic_schema                              # 2-leg = 2 magic numbers per pair OR single aggregate-magic; CTO at G0

at_risk_explanation: |
  friday_close — 1-day-hold spec is broken by weekend gaps. Operationally clean
  interpretations: (a) skip Friday entries (lose ~20% of signal opportunities), (b) force
  flat at Friday 21:00 and re-evaluate Monday open (3-day weekend gap = effective 3-day-hold).
  P3 measures impact of each interpretation.

  dwx_suffix_discipline + darwinex_native_data_only — LOAD-BEARING and may be a G0 BLOCKER.
  The strategy requires VIX SPOT and VX FRONT-MONTH FUTURE simultaneously. If Darwinex offers
  only one (or a single CFD that tracks one or the other), the entry signal cannot be
  computed natively. Resolution paths:
  (i) External data feed (CBOE / Quandl / Refinitiv) for VIX spot; signal pre-computed
      off-platform and fed to EA as CSV / file-watch — adds operational complexity, breaks
      darwinex_native_data_only.
  (ii) Synthetic VIX spot derivation from option-chain data — requires SPX option chain data
       which Darwinex does not provide. Dead end.
  (iii) Defer the card until Darwinex onboards either a VIX-spot data feed OR a multi-month-
        VX-future curve. Out-of-scope for V5 timeline.
  CEO + CTO ratify at G0.

  kill_switch_coverage — no native stop + 1-day-hold + same-direction 2-leg + crisis-period
  regime-change risk (2008-09 collapse, 2010 flash crash, 2018 volmageddon, March 2020 crisis).
  P5c crisis-slice testing is critical for this card; CTO sets test-period priors at G0.

  enhancement_doctrine — Hedge ratio 0.3906 is Chan's Eq 5.11 fit on a specific window;
  Simon-Campasano original used different fit (returns-regression). Sweep covers both.
  Threshold 0.1-per-day-to-settlement is Chan's choice from Simon-Campasano; sweep brackets
  half/double values.

  one_position_per_magic_symbol + magic_schema — same root issue as sibling 2-leg cards
  (S05, S06, S08). V5 framework architectural decision pending CEO + CTO at G0.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                               # standard V5 default; optional dead-band, near-expiry, VIX-regime filters
  entry: TBD                                  # VIX spot feed + VX front-month price feed + threshold comparison + 2-leg simultaneous open. ~120-180 LOC native MQL5 (depends on whether VIX spot data is in-platform or external CSV). External data feed adds 80-120 LOC pipeline.
  management: TBD                             # 2-leg simultaneous open + per-leg sizing (0.3906 VX / 1 ES); daily rebalance to net target
  close: TBD                                  # 1-day fixed exit; daily re-evaluation
estimated_complexity: medium                  # core rule is simple (threshold comparison + fixed hedge ratio); 2-leg + multi-product data plumbing + VIX-spot acquisition adds 1.5-2x complexity vs single-symbol; ~150-300 LOC depending on data-feed approach
estimated_test_runtime: 2-4h                  # P3 sweep is moderate (5×5×4×4×4×4×3 ≈ 19,000 cells); per-cell backtest is fast (D1) but requires aligned VIX spot + VX + ES daily data
data_requirements: custom_volatility_curve    # VIX spot daily close + VX front-month future daily close + ES front-month future daily close, all aligned. CBOE VIX is freely available via Quandl/CBOE direct; VX and ES front-month futures available via CME/CFE. Likely NOT in Darwinex-native data feed; flag at G0 for CTO + Pipeline-Operator data-acquisition planning.
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
- 2026-04-28: SRC05_S09 REUSES the `futures-roll-return-arb` flag from S08 chan-at-roll-arb-etf
  with a momentum-direction-go-with framing. The fundamental mechanic is identical (entry
  direction set by sign of computed futures roll return γ — here measured as VX_front vs VIX
  divided by time-to-settlement); the differentiator is direction-of-travel:
  - S08 (XLE-USO): GO AGAINST THE REGIME. Under contango (γ < 0 on CL), short the future
    (USO/CL) and long the cointegrating spot proxy (XLE) — *extracts* the negative-γ flow.
  - S09 (this card, VX-ES): GO WITH THE REGIME. Under contango (γ < 0 on VX = VX_front
    above VIX by > 0.1·DTS), short BOTH VX and ES — *captures* the negative-γ momentum on
    VX while ES short hedges the spot-equity exposure via the VX-ES anti-correlation.
  Two readings of the V5 vocab discipline:
  (i) ONE flag (`futures-roll-return-arb`) covers both with a `regime_direction: with|against`
      parameter on each card. Cleaner unification.
  (ii) TWO sibling flags (`futures-roll-return-arb` for AGAINST/extraction, `futures-roll-
       return-momentum` for WITH/capture). Matches the V4 sibling-flag-not-generalize
       precedent (cross-sectional-decile-sort MR vs forthcoming cross-sectional-momentum).
  PROPOSAL: ADOPT (i) for now (single flag with direction parameter at the card level), with
  CEO ratification at the SRC05 closeout vocab batch. (ii) is also acceptable; CEO decides.

- 2026-04-28: V5-architecture-fit at the broker-universe layer is challenged differently
  from S08. S08's challenge is the cointegrating-ETF leg (XLE not in Darwinex universe).
  S09's challenge is the VIX SPOT data feed: the entry signal "VX_front > VIX + 0.1·DTS"
  fundamentally requires VIX spot. Darwinex offers a VIX-CFD (or similar volatility CFD)
  but it likely tracks one of {VIX spot, VX front-month future} not both. CTO at G0 confirms.
  If neither is natively available with both data points: the strategy needs an external
  data feed for at least VIX spot (CBOE makes this freely available), violating
  darwinex_native_data_only. PIPELINE-OPERATOR'S off-platform-CSV feed mechanism (used by
  some V4 EAs for news data) is a precedent for this kind of external-data-fed signal.

- 2026-04-28: This card's crisis-slice priors are LOAD-BEARING — far more than typical for
  a Sharpe-1 strategy. The VX-VIX-ES triangle has had MULTIPLE regime changes:
  (i) 2008-09 financial crisis — VX backwardation regime changed; Chan p. 144 references this
      ("there is a regime change in the behavior of VIX and its futures around the time of
      the financial crisis of 2008", though this quote is from the MR strategy at p. 132).
  (ii) February 2018 "Volmageddon" — VIX spike crushed inverse-VIX ETP investors;
       short-VX positioning would have suffered.
  (iii) March 2020 COVID-19 crisis — VIX > 80; threshold dynamics broke down.
  P5c crisis-slice testing must include 2008Q3-Q4, 2018Q1, 2020Q1 at minimum. The Chan-
  reported backtest period (2010-07-29 to 2012-05-07) is calm-regime by construction;
  out-of-sample validation in regime-change windows is the proper test. CEO + CTO at G0
  set the test-period priors.

- 2026-04-28: The 1-day-hold spec is a CRITICAL operational consideration. With ~252 trading
  days/year and a daily-decision regime-driven signal, the strategy can have very high
  turnover (Chan does not report transaction-cost-aware performance). The reported APR 6.9%
  / Sharpe 1 is unlevered before transaction costs; Darwinex spread + commission per VX
  contract + per ES contract on every daily flip would be material. P9b Operational
  Readiness gate is the correct phase to net-of-fees the strategy; if net Sharpe < 0.5, the
  strategy is operationally broken regardless of pre-cost statistics.

- 2026-04-28: Hedge-ratio sensitivity matters. Chan p. 144 explicitly notes his 0.3906 hedge
  ratio differs from Simon-Campasano's reported value because Chan uses Eq 5.11 prices-
  regression slope (which preserves the dollar-amount neutrality at price levels) while
  Simon-Campasano used returns-regression (which preserves correlation structure). Sensitivity
  to this choice should be P3-swept; if performance is brittle to hedge-ratio choice, the
  strategy's robustness is in question. The 0.3906 value is itself derived from a specific
  fitting window and date range; out-of-sample re-fit may produce material differences.
```
