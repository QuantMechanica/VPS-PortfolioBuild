# Strategy Card — Chan Cointegration Pair Stat-Arb (z-score mean-reversion on a cadf-cointegrated pair)

> Drafted by Research Agent on 2026-04-27 from `strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md` (verbatim quotes + MATLAB code from Examples 3.6, 7.2, 7.3, 7.5 + Ch 7 Stationarity & Cointegration narrative).
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per QUA-188 waiver v3).

## Card Header

```yaml
strategy_id: SRC02_S01
ea_id: TBD
slug: chan-pairs-stat-arb
status: DRAFT
created: 2026-04-27
created_by: Research
last_updated: 2026-04-27

strategy_type_flags:                          # SRC02 batch ratified by CEO 2026-04-28 (QUA-275 closeout, back-port QUA-332)
  - cointegration-pair-trade                  # entry mechanism: cadf-cointegrated 2-leg spread crosses ±N·σ z-score (Engle-Granger / APT thesis)
  - mean-reach-exit                           # exit mechanism: spread returns inside [-M·σ, +M·σ] band (mean-reach not stop-out)
  - time-stop                                 # OU half-life (Ex 7.5) used as max-hold; Chan recommends time-stop OR mean-reach, whichever fires first
  - symmetric-long-short                      # both legs deployable; spread can be long or short with symmetric thresholds
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Chan, Ernest P. (2009). Quantitative Trading: How to Build Your Own Algorithmic Trading Business. Wiley Trading. ISBN 978-0-470-28488-9 (cloth). Hoboken, NJ: John Wiley & Sons."
    location: "Example 3.6 'Pair Trading of GLD and GDX', pp. 55-59 (mechanical structure: hedge-ratio fit, z-score thresholds, train/test split, Sharpe claims) + Chapter 7 'Stationarity and Cointegration' narrative pp. 126-127 (mean-reversion rationale, Figure 7.4 spread plot) + Example 7.2 'How to Form a Good Cointegrating (and Mean-Reverting) Pair of Stocks', pp. 128-130 (cointegrating augmented Dickey-Fuller test cadf, hedge-ratio derivation) + Example 7.3 'Testing the Cointegration versus Correlation Properties between KO and PEP', pp. 131-133 (counterexample: KO/PEP correlated but not cointegrated; pair filter is cadf, not corrcoef) + Example 7.5 'Calculation of the Half-Life of a Mean-Reverting Time Series', pp. 141-142 (Ornstein-Uhlenbeck half-life as time-stop)."
    quality_tier: A
    role: primary
```

Raw evidence: `strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`. Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Quantitative Trading_ How to Bu - Ernest P. Chan.pdf`.

## 2. Concept

A **two-leg cointegration pair-trade** that goes long the spread when it deviates negatively from its training-set mean (long asset 1 + short hedge-ratio·asset 2) and short the spread when it deviates positively, exiting when the spread mean-reverts back into a band around its mean. The cause-and-effect story is straight from Engle-Granger / arbitrage-pricing theory: when two securities are cointegrated by a cadf augmented Dickey-Fuller test, their linear-combination spread is stationary (I(0)) and any temporary deviation must, by the test's null-rejection, revert. The strategy harvests these reversions.

Chan's verbatim framing (Ch 7, p. 126):

> Traders have long been familiar with this so-called pair-trading strategy. They buy the pair portfolio when the spread of the stock prices formed by these pairs is low, and sell/short the pair when the spread is high—in other words, a classic mean-reverting strategy.

The edge is **statistical-arbitrage**, not technical pattern-matching: cadf rejects the unit-root null at the chosen significance level → the spread is provably stationary in-sample → mean-reversion is the data-generating process, not just a pattern.

## 3. Markets & Timeframes

```yaml
markets:                                      # Chan's deployment universe + V5 Darwinex re-mapping candidates
  - us_etfs                                   # Chan's primary example: GLD (gold ETF) vs GDX (gold-miners ETF)
  - currency_futures_or_spot                  # Chan's generalization, p. 133: "the Canadian dollar / Australian dollar (CAD/AUD) cross-currency rate is quite stationary"
  - commodity_futures_calendar_spreads        # Chan's generalization, p. 133: "long and short futures contracts of the same underlying commodity but different expiration months"
  - fixed_income_pairs                        # Chan's generalization, p. 133: "long and short bonds by the same issuer but of different maturities" (out of V5 scope)
timeframes:
  - D1                                        # Chan's example uses daily adjusted close (`adjcls`) on GLD/GDX
  # Strategy generalizes to lower timeframes if the cadf test passes on intraday spreads, but Chan's
  # claim-set and OU half-life of ~10 days is calibrated on D1.
primary_target_symbols:
  - "GLD + GDX (Chan's example, US-listed ETFs) — V5 architecture-incompatible (no Darwinex equivalent for the gold-miners ETF GDX)"
  - "AUDCAD.DWX — single-symbol Darwinex spot proxy of Chan's CAD/AUD generalization (spread between AUD-implicit and CAD-implicit gives a single mean-reverting series)"
  - "any cadf-passing Darwinex pair (e.g., AUDUSD.DWX vs NZDUSD.DWX, EURUSD.DWX vs GBPUSD.DWX, GOLD.DWX vs SILVER.DWX) — selected at P3 sweep / P3.5 CSR via cadf scan"
session_window: 24-hour                        # daily-bar evaluation; no intraday session restriction
```

## 4. Entry Rules

Pseudocode — verbatim where possible from Chan's MATLAB code in Example 3.6; structural translation where MATLAB-specific (`fillMissingData`, `lag1`, `ols`) needs spelling out.

```text
PARAMETERS (Chan defaults; refined defaults from p. 59 in §B.3 of raw evidence):
- TRAINING_LOOKBACK = 252                    // days; Chan: trainset = 1:252
- ENTRY_Z          = 2.0                     // default; Chan also reports a refined 1.0 with better Sharpe
- EXIT_Z           = 1.0                     // default; Chan also reports a refined 0.5 with better Sharpe
- COINTEGRATION_SIGNIFICANCE = 0.05          // i.e. require cadf t-statistic <= 5% critical value (-3.343 for 2-var case)

ONE-TIME PRECOMPUTE (in-sample / training-set anchor, then frozen):
- run cadf(asset1[trainset], asset2[trainset], 0, 1)         // cointegrating augmented Dickey-Fuller
- if t_stat > -3.343 then ABORT_DEPLOY (pair fails cadf at 5%) // Ex 7.3 KO/PEP counterexample: t = -2.14 → REJECT
- hedgeRatio  = ols(asset1[trainset], asset2[trainset]).beta // OLS regression of asset 1 on asset 2
- spread_full = asset1.adjclose - hedgeRatio * asset2.adjclose
- spreadMean  = mean(spread_full[trainset])
- spreadStd   = std(spread_full[trainset])

EACH-BAR (D1 close):
- spread_t  = asset1.adjclose[t] - hedgeRatio * asset2.adjclose[t]
- zscore_t  = (spread_t - spreadMean) / spreadStd

ENTRY:
- if zscore_t <= -ENTRY_Z and not in position
  then OPEN_LONG_SPREAD = { long 1 unit asset1, short hedgeRatio units asset2 }
- if zscore_t >= +ENTRY_Z and not in position
  then OPEN_SHORT_SPREAD = { short 1 unit asset1, long hedgeRatio units asset2 }

NOTE (Chan's MATLAB convention, Ex 3.6 §B.2):
- positions(longs,  :) = repmat([ 1 -1], ...);              // long-spread = +1 asset1, -1 asset2 (then scaled by hedgeRatio downstream)
- positions(shorts, :) = repmat([-1  1], ...);              // short-spread = -1 asset1, +1 asset2
- existing positions are carried forward across bars unless an exit signal fires (Chan: `fillMissingData(positions)`)
```

## 5. Exit Rules

Two exit triggers, whichever fires first. Chan's verbatim guidance (Ex 7.5, p. 142): "This target price [the mean spread μ] can be used together with the half-life as exit signals (exit when either criterion is met)."

```text
EXIT (whichever fires first):
- MEAN-REACH:       abs(zscore_t) <= EXIT_Z      (Ex 3.6 §B.2 — "exit any spread position when its value is within 1 standard deviation of its mean")
- TIME-STOP:        bars_held >= OU_HALFLIFE     (Ex 7.5 §E — "halflife = -log(2)/theta"; ≈10 days for GLD/GDX; pair-specific)

OU half-life precompute (one-time, on training-set spread):
- prevz   = lag1(spread_full[trainset])
- dz      = spread_full[trainset] - prevz
- theta   = ols(dz, prevz - mean(prevz)).beta
- halflife = -log(2) / theta                  // ≈ 10 for GLD/GDX

NO STOP-LOSS:
- Chan, Ch 7 p. 143 (Exit Strategy section): "a stop loss in this case [reversal model] often means you are exiting at the worst possible time. ... it is much more reasonable to exit a position recommended by a mean-reversal model based on holding period or profit cap than stop loss"
- This is a hard claim from the source. V5 framework default behaviour (kill-switch + drawdown alerts) provides the catastrophic backstop without injecting a per-trade stop. § 12 lists kill_switch_coverage as the relevant Hard Rule.

NO TRAILING STOP / NO BREAK-EVEN.
```

## 6. Filters (No-Trade module)

```text
- only deploy on pairs where cadf t-stat passes COINTEGRATION_SIGNIFICANCE (default 5%) on the most recent TRAINING_LOOKBACK bars; re-run cadf at every walk-forward boundary
- skip any pair where the OU half-life from §5 exceeds DEPLOYMENT_HALFLIFE_CAP (recommended cap: 30 days; longer half-lives indicate weak mean-reversion / borderline cointegration and capital-efficiency-deficit per Ch 2 capital-availability discussion)
- standard V5 framework defaults: kill-switch, news filter, MAX_DD trip
- friday-close: DISABLED for this strategy (see § 12 hard_rules_at_risk → friday_close); pair-trade carries weekend gap risk inherent to a multi-day-half-life mean-reverter
- pyramiding NOT allowed (one open spread position at a time per pair)
```

## 7. Trade Management Rules

```text
- one open spread per pair at any time (no pyramiding); enforce via the magic-formula registry's symbol-slot allocation
- two simultaneous orders coordinate (one on each leg); both must fill at the same bar close to enter the position. If one leg fails to fill, ABORT and flat the filled leg next bar.
- position size: Chan's example uses unit-share allocation (1 share asset1 vs hedgeRatio shares asset2). V5 maps this to the framework's risk-mode-percent at sizing-time: total spread risk = stop-equivalent if the spread fails to mean-revert and breaches a calibrated catastrophic threshold (e.g., 4·spreadStd from entry); CTO calibrates at APPROVED stage.
- gridding: NOT allowed
- Friday Close OVERRIDE: required; the strategy's 10-day-half-life thesis is incompatible with weekly forced-flat. See § 11 allowability checklist.
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: training_lookback
  default: 252
  sweep_range: [126, 189, 252, 378, 504]      # 0.5y / 0.75y / 1y / 1.5y / 2y
- name: entry_z
  default: 2.0
  sweep_range: [1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5]   # Chan reports 1.0 outperforms 2.0 in §B.3 — sweep span includes both
- name: exit_z
  default: 1.0
  sweep_range: [0.0, 0.25, 0.5, 0.75, 1.0, 1.25]        # Chan reports 0.5 outperforms 1.0 in §B.3
- name: cointegration_significance
  default: 0.05
  sweep_range: [0.01, 0.05, 0.10]              # Ex 7.2 reports 1%/5%/10% cadf critical values; tighter = fewer pairs, lower false-positive
- name: deployment_halflife_cap_days
  default: 30
  sweep_range: [10, 20, 30, 60]                # cap to prevent borderline-cointegration drift; also caps capital-tie-up time
- name: time_stop_multiplier
  default: 1.0                                 # multiplier on OU half-life
  sweep_range: [0.5, 1.0, 1.5, 2.0, 3.0]       # Chan's verbatim half-life recommendation = 1.0; sweep validates
```

P3.5 (CSR) axis: pair selection itself — re-run cadf on a candidate-pair grid (e.g., all 28 G7 currency-pair combinations on Darwinex, or all 6 metal-pair combinations) and validate the strategy passes on multiple cadf-eligible pairs, not just one.

## 9. Author Claims (verbatim, with quote marks)

GLD/GDX, training set = first 252 daily bars from 2006-05-23 onwards, default thresholds (entry_z = 2.0, exit_z = 1.0):

> "the Sharpe ratio on the training set should be about 2.3" (Example 3.6 MATLAB comment, p. 58)
>
> "the Sharpe ratio on the test set should be about 1.5" (Example 3.6 MATLAB comment, p. 58)

Refined thresholds (entry_z = 1.0, exit_z = 0.5):

> "Let's see what happens if we change the entry thresholds to 1 standard deviation and exit threshold to 0.5 standard deviation. In this case, the Sharpe ratio on the training set increases to 2.9 and the Sharpe ratio on the test set increases to 2.1. So, clearly, this set of thresholds is better." (p. 59)

OU half-life:

> "halflife = 10.0037 ... The program finds that the half-life for mean reversion of the GLD-GDX is about 10 days, which is approximately how long you should expect to hold this spread before it becomes profitable." (Example 7.5, pp. 141-142)

Transaction-cost note:

> "I have not incorporated transaction costs (which I discuss in the next section) into this analysis. ... Since this strategy doesn't trade very frequently, transaction costs do not have a big impact on the resulting Sharpe ratio." (p. 59)

Cointegration filter (KO/PEP counterexample):

> "The cointegration result shows that the t-statistic for the augmented Dickey-Fuller test is -2.14, larger than the 10 percent critical value of -3.038, meaning that there is a less than 90 percent probability that these two time series are cointegrated." (Example 7.3, p. 132)

> "Stationarity is not limited to the spread between stocks: it can also be found in certain currency rates. For example, the Canadian dollar / Australian dollar (CAD/AUD) cross-currency rate is quite stationary, both being commodities currencies. Numerous pairs of futures as well as well as fixed-income instruments can be found to be cointegrating as well." (p. 133)

## 10. Initial Risk Profile

```yaml
expected_pf: 1.6                              # rough estimate from Sharpe ≈ 1.5-2.1 on test set; PF ~ 1+1/sqrt(2pi)*Sharpe + cumulants ≈ 1.5-1.8 for SR ≈ 2 with annual frequency 25-50 trades
expected_dd_pct: 15                           # rough estimate; Chan does not publish DD numbers for this strategy explicitly
expected_trade_frequency: 25-50/year/pair     # rough estimate from Ex 3.6 figures: ~10-day half-life + ~2σ entry threshold → ~25-50 entries per year per pair
risk_class: medium                            # statistical-arbitrage edge with modest leverage; DD-driver is regime-shift breaking the cointegration (Ch 2 p. 24-25 regime-shift discussion)
gridding: false
scalping: false
ml_required: false                            # no ML — cadf and OLS are classical statistics, not ML per strategy_type_flags.md § E
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical (cadf-test + OLS hedge-ratio + z-score thresholds + half-life time-stop are all deterministic formulas)
- [x] No Machine Learning required (cadf is classical hypothesis testing; OLS is closed-form linear regression)
- [x] If gridding: not applicable (one open spread per pair)
- [x] If scalping: not applicable (D1 bar-frequency)
- [ ] **Friday Close compatibility: DOES NOT survive forced flat at Friday 21:00 broker time.** Strategy's mean-reversion thesis depends on holding the spread for ≈10 days (OU half-life). Forcing a Friday flat would close winning positions before they reach mean and re-open them on Monday, materially destroying the edge. **Card requires explicit `friday_close` Hard Rule waiver per V5 framework docs.** This is the load-bearing exception flagged in § 12.
- [x] Source citation is precise enough to reproduce (chapter + example + page; Chan's MATLAB code at `epchan.com/book/example3_6.m` and `example7_2.m`)
- [x] No near-duplicate of existing approved card (`strategy-seeds/cards/index.md` shows only Davey-family + Grimes-pullback as of 2026-04-27)

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "cadf significance gate at deployment (and at every walk-forward boundary); OU-half-life cap at deployment; standard kill-switch + news filter from V5 default. Friday-close: NOT used (waived; see hard_rules_at_risk)."
  trade_entry:
    used: true
    notes: "z-score crossing thresholds: long-spread on z <= -ENTRY_Z, short-spread on z >= +ENTRY_Z. Two simultaneous orders, one per leg."
  trade_management:
    used: false
    notes: "no trailing stop, no break-even, no partial close, no pyramiding"
  trade_close:
    used: true
    notes: "z-score crossing back into [-EXIT_Z, +EXIT_Z] band (mean-reach exit), OR bars_held >= OU_HALFLIFE (time-stop), whichever fires first"
```

```yaml
hard_rules_at_risk:
  - friday_close                              # PRIMARY — strategy holds positions across multi-week windows; OU half-life ~10 days makes weekly forced-flat structurally incompatible. Card asks for Hard Rule WAIVER, documented per V5 framework HARD_RULES doc. Without waiver: G0 KILL.
  - dwx_suffix_discipline                     # Chan trades GLD + GDX (US-listed ETFs); V5 deploys on Darwinex `.DWX` suffixes. GLD ≈ GOLD.DWX (spot gold proxy); **GDX has NO Darwinex equivalent (gold-miners ETF basket).** Card therefore CANNOT be deployed on Chan's exact pair; CTO + Quality-Tech confirm a Darwinex-eligible pair (e.g., AUDCAD.DWX as the CAD/AUD generalization, or AUDUSD.DWX-vs-NZDUSD.DWX, or GOLD.DWX-vs-SILVER.DWX) at G0 / P3.5 stage.
  - darwinex_native_data_only                 # daily adj-close required; standard Darwinex feeds provide tick-level, roll-up to D1 is straightforward. No external data feeds required for the chosen Darwinex pair.
  - one_position_per_magic_symbol             # **strategy holds simultaneous coordinated positions on TWO symbols** (one long leg + one short leg). Magic-formula registry needs an explicit two-symbol allocation: this strategy occupies TWO `ea_id*10000+symbol_slot` magics rather than the typical one. CTO sanity-check at G0.
  - enhancement_doctrine                      # entry/exit thresholds (entry_z, exit_z) are the load-bearing parameters; Chan reports the refined 1.0/0.5 outperforms the default 2.0/1.0. P3 sweep + walk-forward determine the live values; any mid-deployment re-tune is a `enhancement_doctrine` event.
  - kill_switch_coverage                      # strategy has NO native stop-loss (Chan, Ch 7 p. 143 explicitly argues against stop-loss for reversal models). Catastrophic-loss backstop relies entirely on V5's QM_KillSwitch and account-level MAX_DD trip. CTO confirms the QM_KillSwitch sizing is appropriate for a multi-day-half-life pair-trade at P5.
at_risk_explanation: |
  friday_close — strategy structurally incompatible with weekly forced-flat. Card requests
  documented Hard Rule waiver per V5 framework docs. If waiver denied at G0, this card REJECTS.

  dwx_suffix_discipline — the canonical GLD/GDX pair has no Darwinex equivalent because GDX
  (gold-miners ETF basket) is not in Darwinex's symbol set. The strategy itself is
  Darwinex-deployable on different cadf-eligible pairs (CAD/AUD spot, AUDUSD-vs-NZDUSD spot,
  GOLD-vs-SILVER spot, AUDUSD-vs-NZDUSD spot, etc.); Research recommends CTO + Pipeline-Operator
  run cadf at P3.5 over a Darwinex-eligible candidate-pair grid to select live deployment pairs.
  GLD/GDX serves as the V5 cross-walk reference but cannot itself deploy.

  darwinex_native_data_only — no external data feed required once a Darwinex pair is chosen;
  daily adj-close rolls up from native tick data. Not a binding risk for live deployment.

  one_position_per_magic_symbol — strategy is INHERENTLY two-symbol; cannot be split across two
  EAs because the entry/exit signal depends on the JOINT spread. Magic-formula registry must
  allocate two symbol-slots to one ea_id for this strategy; CTO confirms convention at APPROVED.

  enhancement_doctrine — load-bearing on entry_z and exit_z. Chan's own data shows the choice
  between 2.0/1.0 (default) and 1.0/0.5 (refined) materially changes Sharpe (1.5 → 2.1 on test
  set). P3 sweep + walk-forward set live values; any mid-deployment retune is enhancement.

  kill_switch_coverage — no native stop-loss is the load-bearing risk for this card. Per Chan's
  own Ch 7 argument, a stop-loss on a reversal model often "means you are exiting at the worst
  possible time." V5 framework's account-level kill-switch + MAX_DD trip is the correct catastrophic
  backstop. CTO sanity-checks the kill-switch sizing covers the worst-case "cointegration breaks"
  scenario (regime shift à la Ch 3 p. 24-25 — e.g., 2008-style commodity-currency divergence).
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                               # cadf-significance gate (call out to a portable cadf implementation — MATLAB ols/cadf has no MQL5 equivalent; need MQL5 port or external precompute)
  entry: TBD                                  # z-score crossing logic; two simultaneous orders coordination (atomic-fill or abort)
  management: TBD                             # n/a (no trailing / BE / partial)
  close: TBD                                  # mean-reach OR time-stop, whichever first
estimated_complexity: medium                  # cadf and OLS are non-trivial in MQL5; either port them natively or precompute training-set hedgeRatio + spreadMean + spreadStd + halflife offline and load as EA inputs
estimated_test_runtime: 2-4h                  # P3 sweep (5×7×6×3×4×5 = 12,600 cells) over 5+ years of D1 data on multiple Darwinex pairs; manageable
data_requirements: standard                   # daily adj-close on Darwinex .DWX symbols; no external news / earnings / macro feed
```

## 14. Pipeline History

| version | date | rebuild reason | P-stage reached | verdict |
|---|---|---|---|---|
| _v1 | 2026-04-27 | initial build | TBD | TBD |

## 15. Pipeline Phase Status (current `_v1`)

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-04-27 | DRAFT (awaiting CEO + Quality-Business review) | this card |
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
- 2026-04-27: SRC02_S01 surfaces TWO `strategy_type_flags` controlled-vocabulary GAPS:
   (a) `cointegration-pair-trade` (entry mechanism) — V4 had no statistical-arbitrage / cointegration EAs per `strategy_type_flags.md` Mining-provenance table; the cleanest descriptor for Chan's pair-trade family does not yet exist in the V5 vocabulary. Research proposes adding it via the addition-process documented at the bottom of `strategy_type_flags.md` (Research issue + Chan citation + CEO/CTO ratification). Chan citation: Ex 3.6/7.2/7.3 + Ch 7 narrative pp. 126-133.
   (b) `mean-reach-exit` (exit mechanism) — exit-when-spread-returns-inside-band is structurally distinct from `signal-reversal-exit` (which describes a value-flip, not a band-return) and from `time-stop` (clock-only). Chan's combined mean-reach OR time-stop construction (Ex 7.5 p. 142) is the primary mechanism. Research proposes adding `mean-reach-exit` via the same addition-process. Chan citation: Ex 3.6 §B.2 + Ex 7.5 §E.3.
   Until ratified, this card uses the closest available flags (`signal-reversal-exit`, `time-stop`, `symmetric-long-short`) and explicitly notes the gap.
- 2026-04-27: Chan strongly disclaims stop-losses on reversal models (Ch 7 p. 143 verbatim). V5 framework's kill-switch + account MAX_DD trip is the authoritative catastrophic backstop for this card; per-trade stops would degrade the strategy. CTO confirms kill-switch sizing at P5.
- 2026-04-27: GLD/GDX (Chan's canonical pair) is **not Darwinex-deployable** because GDX (gold-miners ETF) has no Darwinex equivalent. The strategy is deployable on cadf-eligible pairs that ARE on Darwinex (CAD/AUD spot, AUDUSD-NZDUSD spot, GOLD-SILVER spot, etc.). Research recommends Pipeline-Operator run a cadf scan over the Darwinex-eligible candidate-pair grid at P3.5 to select live pairs; GLD/GDX is the cross-walk reference for V5 framework correctness, not a live target.
- 2026-04-27: Friday-close incompatibility (10-day OU half-life vs weekly forced-flat) is the load-bearing G0 risk. Without explicit Hard Rule waiver this card REJECTS at G0; with waiver, it advances. Research escalates to CEO + CTO for the waiver decision.
```
