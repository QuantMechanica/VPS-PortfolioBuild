---
title: Two-Regime Trend Following Rules (Zakamulin & Giner 2023)
slug: two-regime-trend-following
source_url: https://paperswithbacktest.com/strategies/optimal-trend-following-rules-in-two-state-regime-switching-models
source_paper_url: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4497739
source_paper_title: Optimal Trend Following Rules in Two-State Regime-Switching Models
source_paper_authors: Zakamulin V., Giner J.
source_paper_year: 2023
asset_class: multi
timeframe: D1
suitability: GO
sm_id_assigned:
pipeline_status: research
---

## 1. Economic Thesis

Zakamulin & Giner (2023) start from a well-known empirical fact about equity index returns: they are better described as a mixture of two unobserved states than as a single stationary process. The two states — commonly labelled "bull" (positive drift, lower volatility, higher autocorrelation) and "bear" (zero or negative drift, higher volatility, mean-reverting) — are recoverable from the price series itself by fitting a two-state Markov-switching model (MS-AR or equivalently a 2-state Gaussian HMM) on log-returns. The paper's contribution is **not** the regime detector (that is standard econometrics since Hamilton 1989); it is the derivation of the *optimal trend-following rule conditional on the posterior regime probability*. The headline result: the utility-maximising rule in the bull state is slower / wider (ride the trend), the utility-maximising rule in the bear state is faster / tighter or flat (cut losers early, do not chase), and a regime-agnostic single-MA rule (classic 10-month SMA) is dominated across the parameter space once transaction costs are included.

Three drivers make this transfer to our Darwinex D1 universe:

1. **Two-state structure is scale-invariant.** Markov-switching fits on monthly equity data reproduce on weekly and daily data (Guidolin & Timmermann 2006, Ang & Bekaert 2002 for FX). The states reshape — D1 bull/bear regimes are shorter (weeks-to-months rather than years) and noisier — but the two-mode Gaussian-mixture likelihood remains higher than a single-Gaussian null on liquid D1 macro-asset return series. The paper's *method* is not monthly-equity-specific; only its empirical calibration is.
2. **Regime-conditional optimal trend rules already exist implicitly in our portfolio.** We already deploy "RegimeFiltered" EAs (SM_186 / SM_237 / SM_370) and vol-ratio regime switches (SM_104 / SM_110). Those are heuristic gates — they multiply or suppress a fixed entry rule. Zakamulin-Giner goes one step further: the rule itself changes across regimes, not just its risk multiplier. That is what this spec adds that the existing family does not (see Section 9).
3. **Posterior probabilities, not regime labels, drive the rule.** The paper does not flip between two discrete rules at a hard boundary; it blends signals weighted by the posterior `P(bull | data_t)`. This gives a smoother, cost-friendlier policy than an if/else gate. On D1 this matters: hard-gate regime classifiers (our existing EvaluateRegimeV1) produce clustered flip-flops at transition points that show up as whipsaw losses in P2 baseline.

**Translation to our adaptation (FX / indices / gold on Darwinex D1):**

- Keep the two-state MS estimation but run it on D1 log-returns rather than monthly log-returns. Re-fit the HMM parameters incrementally (rolling window, re-estimate every `K` bars) so the state means and transition matrix track regime shifts rather than anchoring on the full-sample in-distribution assumption.
- Keep the posterior-probability-weighted signal blending, but express the bull and bear rules as two separate SMA-based trend signals with different MA lengths, not as the closed-form utility-maximising rule from the paper (which presumes log-utility over a fixed horizon and would need recalibration per symbol).
- Retain long-and-short symmetry. Unlike equity indices (where the secular drift argues long-only), FX cross-rates and most Darwinex commodity/index symbols on D1 do not have secular drift over the DEV window, so the bear-state rule must be allowed to go short, not merely flat.
- Do not chase the paper's Sharpe=1.14 headline on our universe. That was monthly U.S. equities with secular drift. We expect a smaller Sharpe on D1 FX/indices/gold but a materially better PF than the existing heuristic regime gates, because the rule adapts instead of just gating.

The residual thesis we carry to pipeline: **on liquid Darwinex D1 universes (FX majors, XAUUSD, equity indices, energy), a 2-state HMM-on-returns regime detector combined with a posterior-probability-weighted blend of a slow-MA (bull) and fast-MA (bear) trend signal produces a positive-expectancy trade distribution at P2 gate levels (PF > 1.30, DD < 12%) on a subset of symbols, and specifically dominates the existing heuristic `RegimeFiltered` family on the same symbols in a direct P3.5 comparison.** If the last clause fails the family has no incremental value and should be dropped rather than deployed.

## 2. Failure Hypothesis (Pipeline V2.1 G0 gate)

The edge breaks if any of the following become true:

- **Two-state fit is not informative on D1.** The 2-state Gaussian HMM is only useful if the two-state log-likelihood meaningfully exceeds the single-state null on the DEV window. If the per-symbol BIC-improvement of 2-state over 1-state is below a threshold (`ΔBIC < 10`, standard "positive evidence" cutoff per Raftery 1995), the regime detector is fitting noise and the posterior probabilities are unreliable. Must be checked in P1 smoke as a data-fit diagnostic before any trade-level evaluation — failing symbols are dropped from the universe, not forced through.
- **Regime persistence too short on D1.** The utility of a regime-conditional rule depends on state dwell-times exceeding the rule's reaction lag. If mean dwell-time in either state is shorter than `max(slow_MA_len, fast_MA_len) / 2` bars, the rule flips direction before the MA has responded and the method degenerates into an expensive noise-chaser. Detectable via fitted transition-matrix diagonals (`p_{bb}`, `p_{ss}` both > 0.95 on D1 = 20-bar average dwell, acceptable; < 0.9 = 10-bar = fail). Flag at P1 per symbol.
- **HMM degenerates to single-state on flat FX crosses.** On strongly mean-reverting symbols (e.g. AUDNZD, EURGBP over parts of the DEV window) the 2-state fit can collapse with two nearly identical means. The EM algorithm will return technically-valid parameters but posterior probabilities near 0.5 throughout. The EA must detect this (state means within `0.2 * pooled_std`) and treat it as "no regime structure — stand down" rather than trading a degenerate signal.
- **Posterior-blend is weaker than hard-gate on realised cost structure.** The blending argument assumes near-zero transaction cost per signal change. On D1 with Darwinex spreads and commissions, continuous partial rebalancing (`target_exposure = P(bull) * long_signal + (1 - P(bull)) * short_signal`, valued in `[-1, +1]`) may incur more round-trip cost than a hard flip-only rule. If mean per-trade-cost on DEV exceeds `0.3 * R-multiple`, either discretise the blend (see Section 3) or reject the family. Must be checked in P2.
- **Net-new claim fails vs existing RegimeFiltered family.** The entire justification for running this spec alongside SM_186/237/370 is that the adaptive-rule structure beats the heuristic-gate structure. If P3.5 direct comparison shows PF and Sharpe within noise of RegimeFiltered on the shared subset of symbols, the family is duplicative and should be dropped — not promoted into portfolio per Hard Rule 11 (count unique edges, not EA+symbol combos).
- **Look-ahead bias via in-sample HMM calibration.** The standard academic convention of fitting the HMM on the full sample and then "backtesting" is lookahead. Our implementation MUST fit only on data available at bar `t` and use posteriors from that fit for the `t+1` signal. Any P1 smoke run that uses full-sample-fitted posteriors will produce fantasy numbers — treat as a P1 kill if the implementation is found to do this.

## 3. Entry Rules

Strategy is a **two-state regime classifier driving a posterior-weighted blend of two trend signals**, with long and short legs each gated by the resulting target exposure.

### Stage A — Regime classifier (D1, on the bar-close of bar `t`)

A 2-state Gaussian Hidden Markov Model is fit to the rolling window of D1 log-returns `r_i = log(Close[i] / Close[i-1])` for `i ∈ [t - HMM_Window, t]`.

Model structure (standard 2-state HMM with Gaussian emissions):

- Hidden states `s ∈ {0, 1}` — **conventionally state 0 = bear (lower mean), state 1 = bull (higher mean)**. Identification is enforced post-fit by swapping labels if `μ_1 < μ_0`, so the "bull = state 1" ordering is not fit-order-dependent.
- Emissions: `r_t | s_t = j ~ N(μ_j, σ_j²)`.
- Transition matrix `A` with entries `a_{ij} = P(s_{t+1} = j | s_t = i)`.
- Initial state distribution from steady-state of `A`.

Fit procedure: **incremental EM**.

1. At the first bar where `t >= HMM_Window + HMM_Burnin`, run a full EM fit (forward-backward + parameter update, 20 iterations or convergence at `|ΔlogL| < 1e-6`) on the in-sample window.
2. On subsequent bars, re-fit every `HMM_RefitEvery` bars (default 20) to track regime drift. Between refits, use the previous fit's parameters and run a single forward pass to update posteriors as new bars arrive.
3. At each bar `t`, compute the filtered posterior `P(s_t = 1 | r_{1:t}) ≡ p_bull_t`. This is the decision variable for the signal stage.

Required diagnostics, logged per refit:

- `BIC_1` (single-Gaussian fit), `BIC_2` (2-state fit). Require `BIC_1 - BIC_2 >= 10` else flag "no regime structure — stand down" for this refit cycle.
- Transition diagonals `a_{00}, a_{11}`. Require both `>= 0.9` else flag "regimes too short — stand down".
- State-mean separation: `|μ_1 - μ_0| >= 0.2 * sqrt((σ_0² + σ_1²)/2)` else flag "degenerate fit — stand down".

"Stand down" semantics: EA holds no position, computes no entries, until the next refit restores all three diagnostics.

### Stage B — Trend signals (two, one per regime)

Two independent SMA-based trend signals, evaluated on the completed D1 bar `t`:

- **Bull-state signal** `z_bull_t ∈ {-1, 0, +1}`: `+1` if `Close[t] > SMA(BullMA_L)[t]`; `-1` if `Close[t] < SMA(BullMA_L)[t]`; `0` if the two are within `0.1 * ATR(14)` (dead-zone to avoid flip noise at crossover).
- **Bear-state signal** `z_bear_t ∈ {-1, 0, +1}`: same rule with a shorter MA `BearMA_L`.

Intuition: in the bull state the optimal rule is slow / wide (ride the trend), so we compare to a long-lookback MA (default 200) which only fires once a multi-month direction is established. In the bear state the optimal rule is fast / tight, so we compare to a short-lookback MA (default 50) that responds to the shorter bear-regime swings.

### Stage C — Posterior-weighted target exposure

`target_exposure_t = p_bull_t * z_bull_t + (1 - p_bull_t) * z_bear_t`, clipped to `[-1, +1]`.

**Discretisation (load-bearing for cost control per Section 2):**

- `TargetMode = "continuous"`: trade towards `target_exposure_t` at every bar (rebalance). Not the default — expensive and only used for a P3 ablation axis.
- `TargetMode = "discretised"` (default): map `target_exposure_t` to discrete `{-1, 0, +1}` with hysteresis bands to avoid flip-flop. Specifically: go `+1` (long) if `target_exposure >= +EnterThreshold`; go `-1` (short) if `<= -EnterThreshold`; exit to `0` if `|target_exposure| <= ExitThreshold`. Require `ExitThreshold < EnterThreshold` (strict).

Entry is taken at **Open[t+1]** after the decision is formed on the close of bar `t`. No pyramiding — a single open position at any time per symbol.

### Parameters

| Parameter | Default | P3 sweep grid | Notes |
|---|---|---|---|
| `HMM_Window` | 504 | {252, 504, 1008} | ~2Y default D1 rolling window for HMM fit. 252 = 1Y (lower variance on estimation but less robust); 1008 = 4Y (slower to adapt). |
| `HMM_Burnin` | 20 | fixed | First 20 bars after a window becomes available are still used for the first fit but posteriors during burnin are not traded. |
| `HMM_RefitEvery` | 20 | {10, 20, 60} | 20 D1 bars ≈ 1 calendar month. Shorter = more adaptive, more compute; longer = more stable posteriors. |
| `BullMA_L` | 200 | {120, 200, 252} | Slow trend MA for bull regime. |
| `BearMA_L` | 50 | {20, 50, 100} | Fast trend MA for bear regime. `BearMA_L < BullMA_L` enforced at init. |
| `EnterThreshold` | 0.30 | {0.20, 0.30, 0.50} | Minimum `|target_exposure|` to open a position. |
| `ExitThreshold` | 0.10 | {0.05, 0.10, 0.20} | Below this, flatten. `ExitThreshold < EnterThreshold` enforced. |
| `DeadZone_ATR` | 0.10 | {0.00, 0.10, 0.25} | Stage-B dead-zone on MA comparison (in units of ATR(14)). 0 disables the dead-zone. |
| `TargetMode` | "discretised" | {"discretised", "continuous"} | Continuous is an ablation axis per Section 2 cost concern. |
| `EnableLongs` | true | {true, false} | Leg ablation. |
| `EnableShorts` | true | {true, false} | Leg ablation. Equity-bias argument does not apply on our FX/commodity universe. |

Rule constraints (enforced at `OnInit`, EA refuses to start if violated):
- `BearMA_L < BullMA_L`.
- `ExitThreshold < EnterThreshold`.
- `HMM_Window >= 2 * HMM_RefitEvery`.

## 4. Exit Rules

| Trigger | Rule |
|---|---|
| Target-exposure reversal (primary) | If position is long and `target_exposure_t <= -ExitThreshold`, close at Open[t+1] (and if `<= -EnterThreshold`, flip short in the same bar). Short is symmetric. This is the core method — exits are driven by the same posterior-blended signal that drives entries. |
| Regime "stand down" (safety) | If any Stage-A diagnostic (BIC gap, transition diagonal, state-mean separation) fails on a refit, all open positions are closed at Open[t+1] and no new entries are taken until the next refit restores the diagnostics. |
| ATR hard stop (catastrophic backstop) | `ATRHardStop_Mult * ATR(14)[entry]`, frozen at entry. Default `ATRHardStop_Mult = 4.0`. This is a safety net for gap-through events where the posterior-based exit has not yet updated (weekend/rollover); it is NOT the main exit mechanism. |
| Hard TP | None. The method is horizon-adaptive by construction; a fixed TP destroys the bull-regime "ride-the-trend" rule. |
| Time stop | None. Regime-adaptive by design. |
| Breakeven | None in V1. V2 optional (exit-only, pre-registered per `feedback_enhancement_doctrine`): tighten the ATR hard stop to entry after `+2 * ATR(14)` favourable move. |
| News / session | Deferred to P8 News Impact gate (OFF / PAUSE / SKIP_DAY per standard pipeline). |

**Design note on the "stand-down" behaviour.** This is the primary safeguard against over-trading on a degenerate fit and is the main structural difference from existing heuristic RegimeFiltered EAs (which have no intrinsic self-invalidation mechanism). It is load-bearing — do not remove it in "simplification" passes.

## 5. Position Sizing

Per Hard Rule 6, both sizing modes supported:

- `RISK_PERCENT` — percent-of-equity risk per trade (live-deploy default 0.50%, configurable).
- `RISK_FIXED` — fixed $1,000 risk per trade (DEV baseline per `feedback_fixed_risk_methodology`).

Stop distance for sizing: `StopLossDistance = ATRHardStop_Mult * ATR(14)[entry]` (the hard backstop, because the posterior-exit distance is not a fixed geometric distance and cannot be used for sizing).

`lots = RiskAmount / (StopLossDistance * TickValuePerLot)`, rounded down to broker `lotStep`, clipped to `[minLot, maxLot]`. If the computed lot is below `minLot`, log-skip as `SKIP_MIN_LOT` — do not silently size up.

**No pyramiding.** A single open position per symbol at any time. If the target exposure changes sign while a position is open, the EA flips in a single round-trip (close + open) at Open[t+1].

Magic number: `SM_<id>*10000 + symbol_slot` per Hard Rule 8 / `feedback_deploy_magic_numbers`.

## 6. Required Indicators / Data

All MT5-native — no external data sources, Hard Rule 12 compliant:

| Indicator / data | MT5 source | Notes |
|---|---|---|
| Log-returns | `iClose` on PERIOD_D1 + in-EA log-diff | Input to the HMM. Fit on the last `HMM_Window` returns. |
| 2-state Gaussian HMM | Native MQL5 implementation (this EA, no external libs) | Forward-backward + EM update, 20-iteration cap, double precision. See §9 for implementation path. |
| SMA(BullMA_L), SMA(BearMA_L) | `iMA` with `MODE_SMA` on PERIOD_D1 | Two handles, one per regime. |
| ATR(14) | `iATR` on PERIOD_D1 | Dead-zone, hard stop, and sizing. |
| Tick data | Darwinex native D1 (Model 4 Every Real Tick per Hard Rule 6) | No external market API. |

**Universe (Darwinex .DWX tick-data symbols, D1):**

- **Tier 1 (primary, regime-structure expected):** `XAUUSD.DWX`, `GDAXI.DWX`, `NDX.DWX`, `WS30.DWX`, `XTIUSD.DWX`, `SPX.DWX` — macro-asset D1 return series where the 2-state likelihood typically dominates 1-state (reference: Guidolin & Timmermann 2006 for equity indices; our own P1 BIC-diagnostic confirms per symbol).
- **Tier 2 (macro-FX majors, expected to pass BIC gate on subsets of the window):** `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`, `NZDUSD.DWX`.
- **Tier 3 (likely BIC-fail, included for universe completeness):** `XAGUSD.DWX`, `XBRUSD.DWX`, `UK100.DWX`, `JPN225.DWX`.
- **Explicitly excluded:** `EURGBP.DWX`, `AUDNZD.DWX`, `EURCHF.DWX` — strongly mean-reverting crosses with no expected regime structure. Excluded to keep P2 trade-count honest (and as a sanity check — if the EA *does* produce edge here, the method is capturing something other than what the spec claims).
- **Crypto excluded** per Hard Rule 12.

## 7. Backtest Scope

- **DEV window:** 2017-01-01 → 2022-12-31 (Pipeline V2.1 standard).
- **HO window:** 2023-01-01 → present.
- **Tester model:** Model 4 — Every Real Tick (Hard Rule 6).
- **Baseline gate targets (P2):** PF > 1.30, Trades > 200 over DEV, DD < 12%.
- **Primary symbols for P2 baseline scan:** Tier 1 (6 symbols) + Tier 2 (6 symbols) = 12 symbols. Tier 3 dropped from baseline; can be revived in P3.5 for CSR class members if needed.
- **P3 sweep axes:** `HMM_Window (3) × HMM_RefitEvery (3) × BullMA_L (3) × BearMA_L (3) × EnterThreshold (3) × ExitThreshold (3) × TargetMode (2) × EnableLongs (2) × EnableShorts (2)` = 2916 configs nominal. **Reduced via staged sweep:** Stage 1 — freeze TargetMode="discretised", EnableLongs=EnableShorts=true, sweep HMM axes + MA lengths + thresholds = 243 configs, ranked by DEV Sharpe. Stage 2 — top-20 Stage-1 configs × 4 leg/target ablations = 80 configs. Total 323 configs across two batched stages, consistent with bounded-48-config-batches convention.
- **P3.5 CSR classes:** (a) Tier 1 commodities + indices vs (b) Tier 2 USD-FX majors. Gate: PF > 1.0 on both classes, Sharpe drop < 40% between classes.

**Trade-count expectation.** With discretised exposure + hysteresis bands, expected annual signal rate is ~6-15 round-trips per symbol per year on D1 (regime flips are monthly-scale). Over the 6-year DEV window, per-symbol trade count should comfortably exceed the T > 200 P2 floor when aggregated with moderately active symbols — but may fall short on very persistent-regime symbols (e.g. XAUUSD 2018-2020 was a single long bull regime). If per-symbol T < 100, aggregate the Tier 1 universe into a single "portfolio-baseline" run for the PF / DD gate evaluation rather than lowering the gate itself. CTO to confirm at P2 spawn.

**Mandatory P3.5 side-by-side vs existing heuristic family.** This spec's core claim is net-new value over `RegimeFiltered` (SM_186 / SM_237 / SM_370). P3.5 MUST include a direct comparison on the shared Tier 1 + Tier 2 universe: this EA vs. the best of those three on identical symbols, identical window, identical risk mode. If PF and Sharpe are within 10% on both, the spec is declared redundant and the family is not promoted to P4, per Section 2 failure hypothesis.

## 8. Original Source

Primary source URL (paperswithbacktest.com editorial):

> https://paperswithbacktest.com/strategies/optimal-trend-following-rules-in-two-state-regime-switching-models

R1 catalog (row #115): *Optimal Trend Following Rules in Two-State Regime-Switching Models*, Zakamulin & Giner 2023, Equities (monthly), Sharpe 1.14 reported, summary: "Strategy adapts trend-following rules based on two distinct market regimes to optimize returns."

R2 suitability (ranked table row #4 GO, combined 8/10, plausibility 4, implementation ease 4, GO_TRANSFER): *"Two-regime adaptive trend rules; D1 reformulation viable; overlap-with-RegimeFiltered"* — the overlap note is explicitly addressed in Section 9 of this spec.

**Underlying paper (primary source):**

- Zakamulin, V., & Giner, J. (2023). *Optimal Trend Following Rules in Two-State Regime-Switching Models.* SSRN working paper, https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4497739 (to be verified — if SSRN abstract ID differs, CTO to update before D1 merge).
- Paper backtest scope: U.S. equity indices (primarily S&P 500), monthly data, mid-20th-century to present. Bull-state optimal rule is slower; bear-state optimal rule is faster. Regime-aware rule dominates classic 10-month SMA on Sharpe and maximum drawdown after cost.

**Reported source-page performance** (paperswithbacktest editorial, monthly equity index):

| Metric | Value |
|---|---|
| Sharpe | 1.14 |
| Asset class | Equities (monthly) |

Not an applicable target for our Darwinex D1 adaptation — different asset class, different frequency, different regime-dwell statistics. Pipeline P2 on our universe is authoritative.

## 9. Implementation Notes (CTO)

### Contrast with existing RegimeFiltered / regime-switch EA family (net-new vs. duplication)

This is the load-bearing Section-9 question per the issue brief. Existing regime-related EAs in the registry:

| SM | Name | Regime mechanism | What it does |
|---|---|---|---|
| SM_069 | RegimeGatedLDN | Heuristic session/regime gate | Blocks trades outside a permitted regime state. |
| SM_086 | VolRatioRegime | ATR-short / ATR-long ratio bucket | Risk multiplier based on vol bucket. |
| SM_104 | VRRegimeSwitch | Vol-ratio classifier | Switches between two fixed rules at a vol threshold. |
| SM_110 | RiskRegimeSwitch | Vol-ratio classifier | Scales risk per bucket; entry rule unchanged. |
| SM_141 | ATRRegimeMR | ATR percentile | Gates mean-reversion entries to low-ATR regime only. |
| SM_186 | RegimeFiltered | `g_base.EvaluateRegimeV1` (GREEN/YELLOW/RED gate + risk multiplier) | Base strategy with regime gate; RED = block, YELLOW = half-risk, GREEN = full. |
| SM_237 | RegimeFiltered | same as SM_186 on a different base strategy | Gate pattern. |
| SM_370 | RegimeFiltered | same pattern, third base strategy | Gate pattern. |

**What is net-new in Zakamulin-Giner and this spec:**

1. **Statistically-grounded regime estimator, not a heuristic threshold.** The existing family uses vol ratios or `EvaluateRegimeV1` which are engineered decision trees over ATR / HLR / time-of-day features. Zakamulin-Giner uses a 2-state Markov-switching maximum-likelihood fit on the return series itself. The posterior `P(bull | data)` is a principled probability, not a threshold-crossing indicator.
2. **The rule itself changes, not just its gate.** Existing family: one entry rule, gated on or off / up or down by the regime classifier. This spec: two separate trend rules (bull uses slow MA, bear uses fast MA), blended by posterior probability. This is a structurally different policy — "two strategies trading through one EA, weighted by regime belief" — not "one strategy with a regime mask".
3. **Self-invalidating diagnostics.** The EA monitors BIC gap, transition-matrix diagonals, and state-mean separation at every refit, and stands down when any fails. The heuristic family has no such intrinsic check — if the vol-ratio detector produces noise, the EA happily trades on noise.
4. **Continuous posterior, not discrete state.** The heuristic family is inherently discrete (GREEN/YELLOW/RED). The posterior is a real number in `[0, 1]` and feeds either a discretised signal (default, with hysteresis) or a continuous-exposure ablation. The discretisation is explicit and tunable, not architectural.

**Required P3.5 ablation:** this EA vs. SM_186 / SM_237 / SM_370 on the shared Tier 1 + Tier 2 universe — per Section 7. **The family is promoted to P4 only if this comparison shows material improvement (PF uplift > 15% on at least half the shared symbols OR aggregate Sharpe uplift > 0.15).** Otherwise the family is rejected as duplicative per Hard Rule 11 (count unique edges, not EA+symbol combos).

### Monthly → D1 reformulation justification (issue-required)

The paper operates on monthly U.S. equity log-returns. Our reformulation:

- **Frequency:** D1 instead of monthly. Justified because the 2-state Gaussian HMM is stationary-invariant under time-scale change — the fit procedure is identical; only the fitted `μ`, `σ`, and transition matrix change. Guidolin & Timmermann (2006) and Ang & Bekaert (2002) have demonstrated 2-state fits at weekly and daily equity/FX frequencies. The D1 fit produces shorter-dwell regimes (20-60 bars vs. 20-60 months), reflected in the required `a_{ii} >= 0.9` diagnostic threshold (looser than the monthly equivalent would be).
- **Estimator choice — HMM (EM), not EMA or SMA-cross proxy.** The issue brief lists "EMA/HMM" as candidate regime detectors. We deliberately pick the full HMM with incremental EM, not an EMA-cross proxy, because:
  - (a) An EMA-cross proxy would collapse this spec into "a trend-filter over a trend-strategy", which is structurally identical to the existing heuristic family and destroys the net-new claim from the first subsection of §9 above.
  - (b) The paper's contribution is specifically the posterior-probability-weighted blend, which requires an actual probability — an EMA-cross produces only a binary indicator.
  - (c) Implementation cost of incremental EM on 2-state Gaussian in MQL5 is 150-250 lines of code; manageable, and amortised via the `HMM_RefitEvery` cadence.
  - (d) An EMA-cross regime proxy is, however, a legitimate **P3 ablation axis** (see design question 2 below). If that ablation shows the EMA-cross surrogate performs within 5% of the HMM, we have saved implementation and compute cost and the spec degrades gracefully.

### CTO implementation checklist

- **Inherit** `Include/FTMO/FTMO_Strategy_Base.mqh` per Hard Rule 6.
- **SM-ID:** allocate next free via `Company/data/ea_registry.json` auto-bump; register one logical EA (Hard Rule 11).
- **Magic number:** `SM_<id>*10000 + symbol_slot` (Hard Rule 8).
- **HMM implementation:** native MQL5, no external libs. Components required:
  - Forward-backward on a 2-state Gaussian HMM (vectorised over the rolling window).
  - EM parameter update (closed form for Gaussian emissions + transition counts).
  - Label-swap enforcement post-fit (`state 1 == bull` always).
  - Diagnostics: BIC comparison 1-state vs 2-state; transition diagonals; state-mean separation.
  - All double precision. Numerical care: work in log-space for forward probabilities; clamp transition probabilities to `[1e-6, 1 - 1e-6]` to prevent sticky-state absorption.
- **Incremental vs full refit:** default schedule — full EM refit every `HMM_RefitEvery` bars; single forward pass per bar between refits to update filtered posteriors. EA must log the posterior at each bar for P1 smoke audit.
- **Non-lookahead discipline:** at bar `t`, the HMM is fit ONLY on `r_{t-HMM_Window+1 .. t}` (closed bar `t` is included; bar `t+1` is not available). The signal for bar `t+1` entry is formed at close of bar `t`. Any implementation that leaks `r_{t+1}` into the fit is a P1 kill.
- **Stand-down handling:** if any diagnostic fails on a refit, close open positions at Open[t+1] and block new entries until the next refit restores diagnostics. Log the stand-down event with reason.
- **Hysteresis on discretised target:** go long if `target_exposure >= +EnterThreshold` (from flat or short); exit long to flat if `target_exposure <= +ExitThreshold` (not if it falls between); flip to short if `<= -EnterThreshold`. Strictly `ExitThreshold < EnterThreshold`.
- **Leg ablation flags** exposed as inputs for P3.
- **Under-sized signal handling:** `SKIP_MIN_LOT` category, log-skip only, no silent rounding.
- **Symbol suffix `.DWX`** per `TERMINAL_SETUP_GUIDE §7 / L-013`, stripped only on VPS deploy per Hard Rule 7.
- **Smoke test:** deterministic-seed P1 smoke on XAUUSD D1 2017-01 → 2019-12 must produce identical trade logs across two runs. Since EM is iterative but initialisation is deterministic (fixed seed: `μ_0 = percentile(returns, 25)`, `μ_1 = percentile(returns, 75)`, equal variances, transition matrix init `[[0.95, 0.05], [0.05, 0.95]]`), determinism is achievable without RNG.

### Determinism of EM fit (load-bearing for P1 / P6)

EM is sensitive to initialisation. To guarantee determinism across P6 seeds (which operate on slippage RNG, not on the HMM itself) and across P1 reruns:

- Initialise `μ_0 = quantile(returns, 0.25)`, `μ_1 = quantile(returns, 0.75)`, `σ_0² = σ_1² = var(returns)`, `A = [[0.95, 0.05], [0.05, 0.95]]`, `π = [0.5, 0.5]`.
- Run fixed 20 iterations or converge at `|ΔlogL| < 1e-6`, whichever first.
- Post-fit: if `μ_1 < μ_0`, swap labels and transpose `A`.

This gives byte-identical posteriors across runs for the same input window, which is required for the P1 determinism check and P6 seed-variance interpretation.

### Open design questions for CTO (answer before D1 merge)

1. **Full HMM vs. EM-lite.** Is the 150-250-line native MQL5 implementation worth it, or do we prefer a precomputed-labels approach (Python fits HMM weekly, writes CSV, EA reads)? The CSV path has Hard-Rule-12 implications (external computation on internal data — grey area). **Proposed default: native MQL5 HMM.** CTO to confirm implementation effort is acceptable; if not, propose the CSV-ingestion path with explicit Hard-Rule-12 sign-off.
2. **EMA-cross ablation axis for regime detection.** Add `RegimeDetector ∈ {"HMM", "EMA_cross"}` as a hidden P3 ablation axis. The EMA-cross variant would produce a binary regime label (no posterior), mapping to `p_bull ∈ {0, 1}` discretely. If this ablation shows equivalent performance to the HMM on DEV, the simpler detector wins on cost. CTO to confirm the two-code-path complexity is manageable, or defer the ablation to V2.
3. **HMM refit frequency on volatile symbols.** The default `HMM_RefitEvery = 20` bars (~1 month) may be too slow on rapid-regime-shift symbols (XTIUSD around 2020 oil crash). Consider a condition-triggered refit (refit if posterior has been saturated `>0.95` or `<0.05` for > `K` bars, suggesting a state transition). Deferred as V2 enhancement; V1 uses fixed cadence.
4. **Rollover / gap handling on commodity D1 returns.** Same concern as QUAA-238 (Turtle) and QUAA-239 (ATH). Rollover days on `XTIUSD.DWX` / `XBRUSD.DWX` produce outlier log-returns that distort HMM fit means and variances. Confirm `FTMO_Strategy_Base.mqh` or an auxiliary utility filters rollover bars from the return series used for HMM fitting. If not, add a log-return Winsorisation at `±5σ` before EM fit as a preprocessing step.

## 10. Pipeline Results

*Empty at spec time. Auto-populated post P2 / P3 / P3.5 by Controlling agent.*

| Phase | Symbol | PF | Trades | DD | Verdict | Date | Report |
|---|---|---|---|---|---|---|---|
| P2 | — | — | — | — | — | — | — |
| P3 | — | — | — | — | — | — | — |
| P3.5 | — | — | — | — | — | — | — |
| P3.5 vs SM_186/237/370 | — | — | — | — | — | — | — |
| P4 | — | — | — | — | — | — | — |
