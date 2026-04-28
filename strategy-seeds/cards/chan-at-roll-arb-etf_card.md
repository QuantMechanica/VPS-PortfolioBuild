# Strategy Card — Chan AT Future-vs-ETF Roll-Return Arbitrage (daily, sign-of-roll-return-driven cross-instrument long-short)

> Drafted by Research Agent on 2026-04-28 from `strategy-seeds/sources/SRC05/raw/ch6_7_pp133-168.txt` lines 990-1044 (XLE-USO inline strategy verbatim) + lines 1006-1023 (GLD-GC negative-result control case) + Ch 5 Ex 5.3 spot/roll-return γ-estimation methodology backreference.
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per QUA-188 waiver v3).

## Card Header

```yaml
strategy_id: SRC05_S08
ea_id: TBD
slug: chan-at-roll-arb-etf
status: DRAFT
created: 2026-04-28
created_by: Research
last_updated: 2026-04-28

strategy_type_flags:
  - futures-roll-return-arb                   # NEW VOCAB GAP — entry mechanism: position direction set by sign of computed futures roll return γ; long the spot-tracking ETF + short the future when γ < 0 (contango); mirror when γ > 0 (backwardation). Distinct from carry-direction (carry sets direction on a SINGLE instrument; roll-return-arb pairs a future with a non-future-carrying instrument and trades the difference) and from cointegration-pair-trade (no cointegration test — direction comes from γ sign, not from spread Z-score).
  - signal-reversal-exit                      # exit/flip mechanism: position is held until γ sign flips (contango ↔ backwardation regime change)
  - symmetric-long-short                      # both contango and backwardation directions deployable
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Chan, Ernest P. (2013). Algorithmic Trading: Winning Strategies and Their Rationale. Wiley Trading. Hoboken, NJ: John Wiley & Sons. ISBN 978-1-118-46014-6 (cloth) / 978-1-118-46019-1 (ebk)."
    location: "Chapter 6 'Interday Momentum Strategies', § 'Extracting Roll Returns through Future versus ETF Arbitrage' (PDF pp. 141-143 / printed pp. 141-143). Inline strategy at PDF pp. 141-142 (XLE-USO); GLD-GC negative-result control case at PDF p. 141; γ-estimation methodology at Ch 5 Ex 5.3 PDF pp. 119-122."
    quality_tier: A
    role: primary
```

Raw evidence: `strategy-seeds/sources/SRC05/raw/ch6_7_pp133-168.txt` lines 990-1044. Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Algorithmic Trading_ Winning St - Ernie Chan.pdf`.

## 2. Concept

A **cross-instrument long-short strategy that extracts the futures roll-return component** by pairing a spot-tracking instrument (an ETF that holds the underlying physical commodity, OR an ETF of commodity-producing companies that cointegrates with the underlying) against the corresponding futures contract. Position direction is set by the sign of the estimated annualized roll return γ (computed from the term structure of the futures forward curve per Chan's Ex 5.3 methodology):

> "If futures' total returns = spot returns + roll returns, then an obvious way to extract roll return is buy the underlying asset and short the futures, if the roll return is negative (i.e., under contango); and vice versa if the roll return is positive (i.e., under backwardation). This will work as long as the sign of the roll return does not change quickly, as it usually doesn't." (p. 141)

The thesis is *roll-return capture* via a quasi-arbitrage: by holding the spot-tracking proxy long and the future short (under contango), the position is hedged against spot-price moves, and the residual return is the sustained negative roll-return component flowing TO the future-short side. This contrasts with single-instrument momentum/MR strategies that mix spot and roll components.

Chan's primary case is the XLE-USO-CL triangle (PDF p. 142):

> "One good example is the arbitrage between the energy sector ETF XLE and the WTI crude oil futures CL. Since XLE and CL have different closing times, it is easier to study the arbitrage between XLE and the ETF USO instead, which contains nothing but front month contracts of CL. The strategy is simple:
> Short USO and long XLE whenever CL is in contango.
> Long USO and short XLE whenever CL is in backwardation.
> The APR is a very respectable 16 percent from April 26, 2006, to April 9, 2012, with a Sharpe ratio of about 1." (pp. 141-142)

Note the substitution: USO (front-month CL ETF) replaces the future itself to neutralize the close-time asynchronicity between XLE (4:00 PM ET equity close) and CL (1:30 PM ET futures close). The economic position is still ETF-of-producers vs front-month-future on the same underlying.

The GLD-GC variant is presented as a NEGATIVE-result control (PDF p. 141):

> "Such ETFs can be found for many precious metals. For example, GLD actually owns physical gold, and thus tracks the gold spot price very closely. Gold futures have a negative roll return of −4.9 percent annualized from December 1982 to May 2004. A backtest shows that holding a long position in GLD and a short position in GC yields an annualized return of 1.9 percent and a maximum drawdown of 0.8 percent from August 3, 2007, to August 2, 2010. This might seem attractive, given that one can apply a leverage of 5 or 6 and get a decent return with reasonable risk, but in reality it is not. Remember that in contrast to owning futures, owning GLD actually incurs financing cost, which is not very different from 1.9 percent over the backtest period! So the excess return of this strategy is close to zero." (p. 141)

The GLD-GC variant is informative as a sensitivity-warning: the strategy's gross-return looks attractive but the financing cost on the long-ETF leg can wash out the entire edge. This is a critical implementation consideration for V5 deployment where Darwinex spot-CFD financing ≠ open-market ETF financing.

## 3. Markets & Timeframes

```yaml
markets:
  - commodities_futures + cointegrating_etf   # Chan's Ch 6 deployment: XLE (energy sector ETF) vs USO (front-month CL ETF) — proxy for the XLE-CL arbitrage
  - precious_metals_etf + future              # Chan's negative-control: GLD (physical gold ETF) vs GC (gold futures) — included for completeness; financing cost wash-out caveat
  # V5 Darwinex re-mapping at CTO sanity-check is LOAD-BEARING: this strategy fundamentally requires (a) a future or front-month-future-tracking ETF, AND (b) a cointegrating spot/proxy for the underlying. Darwinex offers spot CFDs (e.g., OIL.DWX = WTI Crude spot CFD ≈ front-month CL proxy) but the COINTEGRATING-ETF leg (XLE-equivalent — energy-sector basket of producer stocks) may NOT be in the Darwinex universe. CTO confirms at G0 whether a Darwinex-native long-short can replicate Chan's strategy structure — flag dwx_suffix_discipline at risk.
timeframes:
  - D1                                        # Chan deploys on daily closes
session_window: end-of-day                    # signals computed on daily close; entries on next-day open
primary_target_symbols:
  - "XLE (Energy Select Sector SPDR ETF, NYSE Arca) — Chan's primary case (long leg under contango)"
  - "USO (United States Oil Fund LP, NYSE Arca) — Chan's primary case (short leg under contango; front-month CL proxy)"
  - "CL (WTI Crude Oil future, NYMEX) — only used for γ-sign signal generation (not traded directly)"
  - "GLD (SPDR Gold Trust, NYSE Arca) — Chan's negative-control case (long leg)"
  - "GC (Gold future, COMEX) — Chan's negative-control case (short leg)"
  - "V5 Darwinex mapping: TBD — closest analogues likely OIL.DWX (USO/CL proxy) but NO clean energy-sector-basket equivalent of XLE; CTO at G0"
```

## 4. Entry Rules

Pseudocode — verbatim from Chan's Ch 6 inline XLE-USO strategy (PDF pp. 141-142) and Ex 5.3 γ-estimation methodology (PDF pp. 119-122).

```text
PARAMETERS (Chan-stated, XLE-USO case):
- BAR              = D1                       // Chan deploys on daily closes
- GAMMA_LOOKBACK   = 5_nearest_contracts      // Ex 5.3: OLS regression on log(F) vs T using
                                              //   the 5 nearest-maturity contracts to estimate γ
- GAMMA_FORM       = ols_slope_log_forward    // Ex 5.3: γ = -12 * OLS_slope(log(F), months-to-expiry)
                                              //   annualized; negative slope of log-forward curve
                                              //   (contango = positive slope = negative γ)
                                              //   Chan p. 119-121 derivation
- SIGNAL_REGIME    = sign_of_gamma            // contango (γ < 0) → SHORT future-proxy / LONG spot-proxy
                                              // backwardation (γ > 0) → LONG future-proxy / SHORT spot-proxy
- LEG_SIZING       = unit_pair                // Chan does not specify dollar-neutral / vol-neutral / unit;
                                              //   default Ch 6 inline implementation is unit-pair (one
                                              //   share/contract per leg), which CTO can convert to
                                              //   risk-equivalent at sizing-time

PER-DAY (at daily close, generating signals for next session):
- // Step 1 — estimate γ from the underlying future's term structure (per Ex 5.3, p. 121)
- F[1..5] = log(closing prices of 5 nearest-maturity contracts of the underlying future)
- T[1..5] = months-to-expiry for each contract
- gamma_ann(t) = -12 * OLS_slope(F vs T)      // annualized roll return; Chan Eq 5.7-5.11
-
- // Step 2 — set position direction from sign of γ
- if gamma_ann(t) < 0:                         // CONTANGO regime (front contracts higher than far)
-     target_position = (long_etf_proxy_units = +1, short_future_proxy_units = -1)
-     // Chan: "Short USO and long XLE whenever CL is in contango."
- elif gamma_ann(t) > 0:                       // BACKWARDATION regime
-     target_position = (long_etf_proxy_units = -1, short_future_proxy_units = +1)
-     // Chan: "Long USO and short XLE whenever CL is in backwardation."
- else:                                        // |γ| ≤ small dead-band (optional, parameterizable)
-     target_position = (0, 0)
-
- // Step 3 — rebalance toward target_position at next-day open

ENTRY:
- At day t close, OPEN target_position at next-session open.
- Position is held until γ sign flips (signal-reversal exit; see § 5).
- DEAD-BAND optional: |γ| < THRESHOLD → stay flat (P3 sweep axis); reduces whipsaws near
  contango/backwardation regime transitions but reduces total trade-count.
```

## 5. Exit Rules

```text
EXIT (signal-reversal):
- Position is closed when sign(gamma_ann(t)) ≠ sign(gamma_ann(t-1)) — i.e., when CL transitions
  from contango to backwardation or vice versa.
- On signal-reversal, position is FLIPPED (close current, open opposite at next-session open).
- DEAD-BAND optional (per § 4): exit-and-flat when |γ| < THRESHOLD, only re-enter when |γ|
  exceeds threshold in either direction.

NO STOP-LOSS in Chan's stated rules. The strategy relies on:
- The sign-persistence of γ (regime changes are infrequent — Chan p. 141: "the sign of the
  roll return does not change quickly")
- The cross-instrument long-short structure that hedges spot-price moves
- V5 framework's QM_KillSwitch + account MAX_DD trip is the catastrophic backstop

Friday Close: standard V5 default applies. Holding period is REGIME-driven (could be days to
months in a single direction), so positions WILL straddle weekends. Forced flat at Friday
21:00 → re-establish 2-leg position Monday open is operationally awkward — flag friday_close
at risk.
```

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults: kill-switch, news filter, MAX_DD trip
- Friday Close: ENABLED (V5 default; flag friday_close at risk per § 12 — regime-driven holds
  span weekends; forced flat re-establishes 2-leg position Monday)
- pyramiding: NOT allowed (one open 2-leg position per pair)
- Optional γ-magnitude filter (P3 sweep axis):
    skip entries / exit-to-flat when |gamma_ann(t)| < THRESHOLD
    // Rationale: dead-band reduces whipsaws near regime transitions where γ sign flickers.
    //   Chan does not specify a threshold; sweep-derived.
- Optional cointegration-self-test (P3 sweep axis):
    skip entries when 252-day rolling ADF p-value on (XLE_log - β·USO_log) > THRESHOLD
    // Rationale: the strategy's hedge thesis assumes XLE-USO cointegrate (so XLE tracks
    //   the spot side of CL and offsets the spot-return component). If cointegration breaks
    //   (e.g., during a sector-specific shock), the long-short structure is no longer a
    //   roll-return-capture strategy and becomes directional sector vs commodity exposure.
- Optional financing-cost guard for the long-ETF leg (operational filter):
    skip entries when ETF_financing_rate_annualized > |gamma_ann(t)|
    // Rationale: Chan's GLD-GC counter-example (p. 141) — even when γ is favorable, if
    //   the long-ETF leg's financing cost equals or exceeds the gross roll-return, the
    //   net edge is zero. This is a Darwinex-deployment-critical filter; CTO at G0 sets
    //   the financing-rate-data plumbing for live use.
```

## 7. Trade Management Rules

```text
- one open 2-leg position per pair at any time
- gridding: NOT allowed
- per-leg sizing: unit-pair default; risk-equivalent conversion at CTO sizing-time
- no native stop; catastrophic backstop via kill-switch + MAX_DD
- contract roll: USO is constructed by USO sponsor as an ETF that ROLLS its CL holdings
  internally (so USO-side roll is automatic); for the GC-future side of GLD-GC variant,
  Pipeline-Operator's standard continuous-contract roll convention applies.
- close-time asynchronicity HANDLED by Chan's substitution USO ← CL (footnote p. 142):
  "Since XLE and CL have different closing times, it is easier to study the arbitrage
   between XLE and the ETF USO instead, which contains nothing but front month contracts
   of CL."
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: gamma_estimator
  default: ols_5_nearest
  sweep_range: ["ols_3_nearest", "ols_5_nearest", "ols_8_nearest"]
                                                # number of nearest contracts in OLS γ fit; Chan uses 5 (Ex 5.3 p. 121)
- name: gamma_dead_band_pct
  default: 0
  sweep_range: [0, 0.01, 0.02, 0.03, 0.05]      # |γ_ann| dead-band (annualized); 0 disables; Chan does not specify
- name: cointegration_filter_p
  default: 0
  sweep_range: [0, 0.05, 0.10, 0.20]            # rolling-ADF p-value threshold for ETF-future cointegration self-test; 0 disables
- name: financing_cost_guard_bps
  default: 0
  sweep_range: [0, 50, 100, 150, 200]           # require |γ_ann| - financing_rate > guard_bps; 0 disables
- name: leg_sizing_form
  default: unit_pair
  sweep_range: ["unit_pair", "dollar_neutral", "vol_neutral_atr"]
                                                # unit pair (Chan default), dollar-neutral, ATR-vol-neutral
- name: cointegration_lookback
  default: 252
  sweep_range: [126, 252, 504]                  # rolling window for the optional cointegration self-test
```

P3.5 (CSR) axis: re-run on alternative future-vs-cointegrating-ETF triangles. Chan p. 142 names XLE-USO-CL as the cleanest case but the same construction applies to: GDX (gold-miners ETF) vs GLD (gold ETF) for gold-future analog, AGRI-sector ETFs vs corn/wheat futures, mining-sector ETFs vs base-metal futures. V5 Darwinex availability for these triangles is the load-bearing question for CTO at G0.

## 9. Author Claims (verbatim, with quote marks)

XLE-USO primary case (PDF pp. 141-142):

> "One good example is the arbitrage between the energy sector ETF XLE and the WTI crude oil futures CL. Since XLE and CL have different closing times, it is easier to study the arbitrage between XLE and the ETF USO instead, which contains nothing but front month contracts of CL. The strategy is simple: Short USO and long XLE whenever CL is in contango. Long USO and short XLE whenever CL is in backwardation. The APR is a very respectable 16 percent from April 26, 2006, to April 9, 2012, with a Sharpe ratio of about 1." (pp. 141-142)

Causal thesis (p. 141):

> "If futures' total returns = spot returns + roll returns, then an obvious way to extract roll return is buy the underlying asset and short the futures, if the roll return is negative (i.e., under contango); and vice versa if the roll return is positive (i.e., under backwardation). This will work as long as the sign of the roll return does not change quickly, as it usually doesn't. This arbitrage strategy is also likely to result in a shorter holding period and a lower risk than the buy-and-hold strategy discussed in the previous section, since in that strategy we needed to hold the future for a long time before the noisy spot return can be averaged out."

GLD-GC negative-control (p. 141):

> "GLD actually owns physical gold, and thus tracks the gold spot price very closely. Gold futures have a negative roll return of −4.9 percent annualized from December 1982 to May 2004. A backtest shows that holding a long position in GLD and a short position in GC yields an annualized return of 1.9 percent and a maximum drawdown of 0.8 percent from August 3, 2007, to August 2, 2010. This might seem attractive, given that one can apply a leverage of 5 or 6 and get a decent return with reasonable risk, but in reality it is not. Remember that in contrast to owning futures, owning GLD actually incurs financing cost, which is not very different from 1.9 percent over the backtest period! So the excess return of this strategy is close to zero."

ETF-future asynchronicity caveat (Ex 1.1 backreference, also p. 141):

> "the settlement or closing prices of GC are recorded at 1:30 p.m. ET, while those of GLD are recorded at 4:00 p.m. ET. This asynchronicity is a pitfall that I mentioned in Chapter 1. However, it doesn't matter to us in this case because the trading signals are generated based on GC closing prices alone."

ETF-future cointegration thesis (Chan p. 142):

> "ETFs containing commodities producing companies often cointegrate with the spot price of those commodities, since these commodities form a substantial part of their assets. So we can use these ETFs as proxy for the spot price and use them to extract the roll returns of the corresponding futures."

## 10. Initial Risk Profile

```yaml
expected_pf: 1.4                              # Chan reports XLE-USO APR 16% / Sharpe ~1 unlevered; PF ≈ 1.3-1.5; Darwinex deployment may compress this materially due to financing-cost on long-ETF leg
expected_dd_pct: 20                           # rough estimate; Sharpe 1 + zero-stop + regime-driven multi-month holds implies meaningful DD; XLE-USO no max-DD reported
expected_trade_frequency: 4-12/year/pair      # γ sign flips infrequently — Chan p. 141: "the sign of the roll return does not change quickly". CL has been in contango ~75% of the time per Ch 5 stats (p. 122)
risk_class: medium                            # daily-bar 2-leg long-short with no native stop and regime-driven holds; financing-cost-aware sizing required
gridding: false
scalping: false                               # daily bars; not scalping
ml_required: false                            # OLS regression for γ + sign-comparison; classical statistics
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical (γ estimation via OLS + sign-based direction selection is fully deterministic)
- [x] No Machine Learning required (classical statistics)
- [x] If gridding: NOT applicable (one 2-leg position per pair)
- [x] If scalping: NOT applicable (D1 timeframe, regime-driven holds)
- [ ] **Friday Close compatibility:** regime-driven holds straddle many weekends; forced flat at Friday 21:00 → re-establish 2-leg position Monday open is operationally awkward. Net effect TBD at P3.
- [x] Source citation is precise enough to reproduce (chapter + section + verbatim strategy rules + verbatim performance quotes for XLE-USO and GLD-GC + Ex 5.3 γ-estimator backreference)
- [ ] **No near-duplicate of existing approved card** — distinct from S05 chan-at-fx-coint-pair (FX cointegration pair, no future, no roll-return signal) and S06 chan-at-cal-spread (intra-future calendar spread of SAME underlying; this is INTER-instrument arb between future and cointegrating ETF). Sibling-but-distinct-from S09 chan-at-vx-es-roll-mom (which is roll-return MOMENTUM go-with the contango/backwardation magnitude rather than this card's roll-return ARBITRAGE go-against the regime). DISAMBIGUATION confirmed at extraction.

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "standard V5 default (kill-switch, news filter, MAX_DD trip, Friday-close); optional γ-magnitude dead-band, cointegration-self-test, financing-cost-guard as P3 sweep axes."
  trade_entry:
    used: true
    notes: "γ-sign-driven 2-leg long-short on D1 close; regime-flip-driven entry/exit"
  trade_management:
    used: true
    notes: "one 2-leg position per pair; no native stop; catastrophic backstop via kill-switch"
  trade_close:
    used: true
    notes: "γ-sign-flip exit-and-flip; optional dead-band exit-to-flat"
```

```yaml
hard_rules_at_risk:
  - friday_close                              # regime-driven multi-month holds straddle many weekends; forced Friday flat is operationally awkward
  - dwx_suffix_discipline                     # LOAD-BEARING. Chan's universe is NYSE Arca ETFs (XLE, USO, GLD) + COMEX/NYMEX futures (CL, GC). V5 deploys on Darwinex .DWX symbols. Cointegrating-ETF leg (XLE-equivalent — energy-sector basket of producer stocks) may NOT exist in Darwinex universe. CTO confirms at G0; if not, card is V5-architecture-CHALLENGED with potential paths: (a) substitute a Darwinex-native sector index CFD if available, (b) defer until Darwinex onboards sector-ETF CFDs, (c) G0 SKIP with rationale.
  - darwinex_native_data_only                 # γ-estimation requires multi-month forward-curve prices (5 nearest contracts per Ex 5.3). Likely NOT in Darwinex-native data feed; flag for CTO at G0. Either external-data-feed or curve-derived signal pre-computation outside the EA.
  - kill_switch_coverage                      # no native stop-loss. Catastrophic backstop relies on V5 QM_KillSwitch and account-level MAX_DD trip.
  - enhancement_doctrine                      # γ-estimation methodology (5-contract OLS) is from Chan's Ex 5.3 worked example; XLE-USO triangle is Chan's hindsight-selected best example. P3.5 CSR on alternative triangles is the strategy's first proper out-of-sample test; any post-PASS retune is enhancement_doctrine.
  - one_position_per_magic_symbol             # the strategy is naturally 2-leg simultaneous (long XLE + short USO at the same time); same root issue as S05/S06 multi-leg cards. CTO confirms at G0 whether V5's `one_position_per_magic_symbol` accommodates 2-leg via 2 magic numbers or single-aggregate-position framing.
  - magic_schema                              # 2-leg simultaneous = 2 magic numbers per pair OR single aggregate-magic representing the spread; CTO decides at G0

at_risk_explanation: |
  friday_close — γ sign-persistence is multi-month-scale; forced flat at Friday 21:00 + 2-leg
  re-establish Monday open fragments the regime-capture mechanic. P3 measures impact;
  structurally may benefit from friday_close exception waiver.

  dwx_suffix_discipline — LOAD-BEARING and may be a G0 BLOCKER. Darwinex universe likely lacks
  XLE-equivalent sector-ETF CFD. Without a producer-basket leg, the strategy degenerates to
  futures-roll-return-direct (long/short the future based on γ sign) which loses the
  cointegrating-spot hedge and exposes pure futures spot+roll return. CTO at G0 confirms
  Darwinex universe; CEO ratifies the substitution path or G0 SKIP.

  darwinex_native_data_only — γ estimation needs multi-month forward-curve prices. Whether
  Darwinex provides multi-month-expiry CL/oil-future data simultaneously is a P9b operational
  question. If only spot+front-month available, γ must be sourced from external data feed
  (CME / Quandl / Refinitiv) and signal pre-computed off-platform — adds operational complexity.

  kill_switch_coverage — no native stop-loss + multi-month holds + 2-leg long-short structure
  that hedges spot but not regime-shift risk. The 2008-2014 oil-price collapse, 2020 negative
  oil-future episode, and any sector-specific event in energy would test the strategy's
  catastrophic-loss profile. CTO sanity-checks at P5c crisis-slice testing.

  one_position_per_magic_symbol + magic_schema — same root issue as sibling 2-leg cards
  (S05, S06, S09). V5 framework architectural decision pending CEO + CTO at G0; this card's
  existence depends on the resolution.

  enhancement_doctrine — Chan's XLE-USO triangle is hindsight-selected (he names it as "one
  good example"); P3.5 CSR on alternative future-cointegrating-ETF triangles is the proper
  out-of-sample test. Any post-PASS instrument-retune is enhancement_doctrine.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                               # standard V5 default; optional γ-dead-band, cointegration-self-test, financing-cost-guard
  entry: TBD                                  # γ estimation (OLS on multi-contract forward curve) + sign-based 2-leg direction. ~150-220 LOC native MQL5 (multi-contract data plumbing dominates); or off-platform signal pre-compute + CSV-based read-in (~80 LOC EA + external pipeline)
  management: TBD                             # 2-leg simultaneous open + per-leg sizing (unit-pair default)
  close: TBD                                  # γ-sign-flip exit-and-flip; optional dead-band exit-to-flat
estimated_complexity: large                   # multi-contract data plumbing + 2-leg long-short structure on different broker symbols + financing-cost-aware sizing is 2-4x complexity of single-symbol strategy; ~200-400 LOC
estimated_test_runtime: 4-8h                  # P3 sweep is moderate (3×5×4×5×3×3 ≈ 2,700 cells); per-cell backtest is fast (D1) but multi-symbol requires pair-aligned data; P3.5 CSR axis on alternative triangles adds 4-6 multiplier
data_requirements: custom_futures_curve       # multi-month forward-curve daily prices for γ estimation; LIKELY NOT in Darwinex-native data feed — flag at G0 for CTO + Pipeline-Operator data-acquisition planning. ALSO required: 2-leg simultaneous data alignment (XLE NYSE 4PM ET vs USO NYSE 4PM ET — both ETFs, same close time, so simpler than the original XLE-CL pairing)
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
- 2026-04-28: SRC05_S08 surfaces a NEW `strategy_type_flags` controlled-vocabulary GAP
  (entry side): `futures-roll-return-arb` — entry mechanism: position direction set by sign
  of computed futures roll return γ; long the spot/cointegrating-ETF + short the future when
  γ < 0 (contango); mirror when γ > 0 (backwardation). Distinct from:
  - `carry-direction` (carry sets direction on a SINGLE instrument; roll-return-arb pairs a
    future with a non-future-carrying instrument and trades the difference between them).
  - `cointegration-pair-trade` (no cointegration test triggers entry — direction comes from
    γ sign, not from spread Z-score crossing).
  - `calendar-spread-mr` (S06 — intra-future calendar spread of SAME underlying; this card
    is INTER-instrument between future and cointegrating ETF/proxy).
  Chan citation: Ch 6 PDF pp. 141-143. Will batch-propose to CEO + CTO via the addition-
  process at the bottom of `strategy_type_flags.md` along with sibling flags from S06/S07/
  forthcoming S09 (where futures-roll-return-arb is reused with momentum framing).

- 2026-04-28: V5-architecture-fit is CHALLENGED at the broker-universe layer. Chan's XLE
  (Energy Select Sector SPDR ETF) leg is a basket of US-listed energy-producer stocks; it is
  not obviously available in the Darwinex spot/CFD universe. The cointegrating-ETF leg is the
  STRATEGIC-EDGE leg (the cointegrating proxy is what hedges the spot-price-noise; without
  it, the strategy degenerates to bare futures-roll-return capture which IS a different
  strategy with different risk profile). Three resolution paths:
  (i) Direct substitution — find a Darwinex-native energy-sector index CFD or basket-CFD
      that cointegrates with WTI front-month future. UNCERTAIN AT EXTRACTION.
  (ii) Defer card — wait until Darwinex onboards US sector-ETF CFDs. Out-of-scope.
  (iii) G0 SKIP — Research extracted the strategy per Rule 1 (every distinct mechanical
       strategy gets a card); CEO + CTO at G0 review can SKIP based on V5-architecture-fit.
  CEO ratifies at G0; this is a structurally identical situation to SRC02 chan-pca-factor's
  multi-stock-universe architecture-pending status.

- 2026-04-28: Chan's GLD-GC NEGATIVE-CONTROL case (p. 141) is a critically important
  BASIS-rule data point: the gross strategy LOOKS profitable (1.9% APR + 5x leverage =
  attractive headline) but the long-ETF financing cost wash-out destroys the edge. This
  is ALREADY captured in the V5 P9b Operational Readiness gate framework (per Pipeline
  doc § P9b), but it surfaces here at the Strategy Card level: any roll-return-arbitrage
  card MUST include a financing-cost guard at sizing-time, not just at edge-screening. The
  card flags this as a P3 sweep axis (financing_cost_guard_bps) and as a load-bearing
  caveat in § 12 hard_rules_at_risk.darwinex_native_data_only — the financing rate of
  Darwinex CFDs differs from open-market ETF financing, so even after CTO confirms the
  ETF-leg availability, the financing-cost-guard parameter must be DARWINEX-FINANCING-RATE-
  CALIBRATED for live deployment.

- 2026-04-28: This card is a SIBLING-DISTINCT to S09 chan-at-vx-es-roll-mom — both use the
  `futures-roll-return-arb` flag but the entry direction logic differs:
  - S08 (this card): GO AGAINST THE REGIME. Under contango (γ < 0), short the future (USO)
    and long the cointegrating spot proxy (XLE) to extract the negative-γ roll-return
    flowing TO the short side.
  - S09 (chan-at-vx-es-roll-mom, Chan p. 143-144): GO WITH THE REGIME. Under contango (γ < 0
    on VX), short BOTH VX and ES (long-roll-return-positioning on VX + the anti-correlation
    between VX and ES) — Simon-Campasano 2012 momentum derivative.
  Both share the underlying mechanic (roll-return-driven direction on a 2-leg long-short
  pair) and properly belong to the same vocab class. The DIRECTION-OF-TRAVEL relative to
  the regime is the differentiator: arbitrage (against) vs momentum (with). S09 is built on
  S08's vocab flag with a `direction_with_regime: true` parameter or sibling-flag
  `futures-roll-return-momentum` if the V5 vocab discipline prefers separate flags. This
  card LEAVES the resolution to S09 extraction — proposal in the SRC05 completion report.

- 2026-04-28: The strategy's edge is structurally REGIME-PERSISTENT rather than
  EVENT-PERSISTENT. CL has been in contango ~75% of the time over the long historical record
  (Chan Ch 5 p. 122). The strategy benefits from regime persistence AND signal sign-flips
  (each flip is a fresh entry); no flip means no trade. Trade-count is therefore LOW
  (Chan reports 6-year backtest implies maybe 4-12 entries depending on regime-flip frequency).
  P4 walk-forward and P5c crisis-slice MUST cover at least one full regime-flip; otherwise
  results are not statistically meaningful. CTO sets test-period priors at G0.
```
