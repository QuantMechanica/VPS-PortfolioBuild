---
title: Good Carry, Bad Carry (Bekaert & Panayotov 2018)
slug: good-carry-bad-carry
source_url: https://paperswithbacktest.com/strategies/good-carry-bad-carry
source_paper_url: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2516907
source_paper_title: Good Carry, Bad Carry
source_paper_authors: Bekaert G., Panayotov G.
source_paper_year: 2018
asset_class: forex
timeframe: D1
suitability: GO
sm_id_assigned:
pipeline_status: research
---

## 1. Economic Thesis

Bekaert & Panayotov (2018) start from the well-documented carry-trade anomaly in G10 FX: long high-interest-rate currencies, short low-interest-rate currencies, and collect the average positive excess return that standard asset-pricing models cannot explain. Their contribution is to argue that the carry premium is **not a single edge**. It is the *average* of two very different sub-populations: "good carry" trades (positive Sharpe, mild negative skew, modest drawdowns) and "bad carry" trades (negative expected Sharpe, severe crash risk, large drawdowns that wipe out months of carry accrual in days — canonically, the 2008 unwind). Sorting carry trades ex-ante into these two buckets using a **skew-based crash-risk filter** (the paper uses 1-month risk-reversal implied volatilities from FX options) dominates the plain-carry benchmark on every risk-adjusted metric they report, and removes most of the peso-problem tail.

Three drivers make this transferable to our Darwinex D1 universe, **after one load-bearing methodological substitution** (detailed in Section 9):

1. **The carry signal itself is natively available on MT5.** `SymbolInfoDouble(SYMBOL_SWAP_LONG/SHORT)` exposes the broker's overnight interest-rate differential — this is the same information the paper uses (interest-rate differentials from forward-spot parity), expressed as a broker-quoted swap rather than a LIBOR/OIS differential. We already deploy four EAs that use this primitive (SM_076 CarryDivergence on AUDUSD/USDJPY M15; SM_1341/1342/1343/1363 generic carry filters). Carry measurement is not the problem. Hard Rule 12 is satisfied on the carry leg without caveat.
2. **The skew filter is what is distinctive — and it does not transfer cleanly.** The paper's skew signal is the **1M risk-reversal implied vol** of each G10 currency vs. USD, a forward-looking options-market measure of how the market prices crash insurance. That data is not available on Darwinex MT5 spot. A *realized-skewness* proxy (computed from the spot return series itself) is MT5-native but is a **fundamentally different signal**: backward-looking crash history, not forward-looking crash pricing. Both carry tail-risk information, but by different mechanisms. Building the EA on a realized proxy is legitimate research — there is independent academic support for realized-skewness as a cross-sectional risk factor (Amaya/Christoffersen/Jacobs/Vasquez 2015 for equities; Chang/Christoffersen/Jacobs 2013 for higher-moment risk premia) — but it **is not the Bekaert-Panayotov strategy**. It is a named-resemblance variant. The thesis degrades; it does not fully collapse.
3. **R2 explicitly flagged this as "reducible to single-pair directional".** The paper operates cross-sectionally across 10 currencies each month. Rather than build a G10 multi-symbol aggregator (complex and outside our single-EA-per-symbol convention), the per-pair reduction is: on each D1 bar per symbol, form a directional decision from (a) sign of the carry differential (long if positive carry, short if negative) and (b) current realized-skew regime of that pair's returns (trade only when the skew is in the "good carry" regime; stand down in the "bad" regime). This is the R2-ranked formulation and is what this spec builds.

**Translation to our adaptation:**

- Single-pair, single-EA, D1. Universe: seven G10 crosses where Darwinex exposes non-trivial overnight swaps (see §6).
- Carry signal: sign and magnitude of the broker's swap-differential, smoothed over a rolling window to avoid broker-session noise at the 00:00 GMT swap tick.
- Skew proxy: rolling realized skewness of D1 log-returns over a 60-bar window, with sign-conditional interpretation (a long position is "good-carry" only when realized skew is *above* a threshold — i.e. recent return distribution has been right-skewed, meaning crash-to-the-downside has not been the dominant tail).
- Entry only when both signals agree on a direction and the skew is in the favourable regime for that direction; otherwise stand down.

**Residual thesis carried to pipeline:** on the seven G10 Darwinex crosses, a rule that trades in the direction of broker-swap carry **only when realized-skew is in the non-crash regime** produces a positive-expectancy D1 trade distribution meeting P2 gate levels (PF > 1.30, T > 200, DD < 12%), **and** outperforms the existing SM_076 CarryDivergence and SM_1341-series carry EAs on the shared pair subset in a direct P3.5 comparison. **If the P3.5 does not show a material uplift over the existing carry family, the spec is rejected as duplicative per Hard Rule 11** (count unique edges, not combinations). The skew filter is the net-new axis; without it, there is no net-new edge.

## 2. Failure Hypothesis (Pipeline V2.1 G0 gate)

The edge breaks if any of the following become true:

- **Realized-skew proxy does not separate good from bad carry.** The paper's implied-skew filter has a 2008-style rationale: options markets priced crash risk *before* it materialised. A realized-skew proxy can only detect crashes *after* they have begun shaping the recent-return distribution. If the proxy fails to produce a meaningful in-sample difference between carry trades entered under favourable vs. unfavourable skew regimes (e.g., in-sample PF uplift under "good regime" < 20%), the proxy is not capturing crash-risk information and the filter is noise. Detectable at P2 by running the same base-carry rule with and without the skew filter on the same window and comparing.
- **Broker swap rates are too noisy / asymmetric to anchor the carry direction.** Darwinex overnight swaps are quoted in broker-specific units and may be updated infrequently, reflect wide bid/ask spreads on the underlying IRS market, and are asymmetric (swap-long ≠ -swap-short even when fundamentals say it should be). If the swap-differential-sign flips more than ~8 times per year per pair on the DEV window (carry direction should be a macro-scale fact, not a high-frequency signal), the anchor is unreliable. Detectable at P1 smoke via swap-sign stability audit.
- **Overlap with existing CarryDivergence family is total.** If P3.5 shows this EA's trade set is ≥ 80% overlap with SM_076 on the shared AUDUSD/USDJPY subset **and** the PF differential is < 10%, the skew filter is a no-op and the family is duplicative per Hard Rule 11. Promote to P4 only if skew filter produces either (a) ≥ 15% PF uplift on majority of shared pairs OR (b) materially different trade set (overlap < 50%) with comparable PF.
- **Regime switch destroys trade count.** If the "good skew regime" fires on < 30% of bars per pair, the EA trades too rarely to accumulate T > 200 over the DEV window per symbol. Counter-fix: either relax the skew threshold (at cost of the filter's selectivity) or aggregate across the seven-pair universe into a portfolio-baseline run (CTO to confirm at P2 spawn, same decision as QUAA-239 / QUAA-240).
- **Broker swap rates are a live-deploy-only phenomenon — backtest uses broker-fixed static swap.** MT5 Strategy Tester uses the **current** broker swap rate applied uniformly across the backtest window, not historical swap rates. This means the backtest sees a *constant* carry signal per pair over the entire DEV window, not the time-varying signal the paper uses. The rule degrades to "if current carry is positive, always trade long when skew is good; else always trade short when skew is good" — a near-time-invariant policy. This is a real limitation of MT5 backtesting for this family (also affects existing SM_076 / SM_1341 series) and is the single most important thing CTO must confirm at D1 spec review. If swap history cannot be replayed, we are validating direction stability + skew filter, not the paper's time-varying carry sort.
- **Weekend-gap contamination on realized-skew window.** FX D1 bars that span weekends absorb Monday-open gaps as D1 returns, which inject artificial negative skew into the rolling window over months containing many weekends. If not handled, the proxy will systematically classify *every* pair as "bad carry" simply because weekend-gap skew dominates. Must be detected at P1 by inspecting the skew distribution per pair; if the rolling skew is pinned ≤ -0.5 throughout, weekend-gap contamination is confirmed and the proxy must Winsorize weekend bars before computing skew.
- **Look-ahead bias via full-sample skew threshold.** The skew-regime threshold (e.g., "trade long only if rolling skew > 0.0") must be a fixed parameter set at EA init, not a quantile of the full-sample skew distribution. A `quantile(skew_series, 0.5)` threshold computed in-sample is look-ahead and a P1 kill.

## 3. Entry Rules

Strategy is a **direction-anchoring carry filter with a realized-skew regime gate**. Both signals evaluate at D1 bar-close; entry at next-bar open.

### Stage A — Carry direction

Carry differential at bar `t`, per symbol:

`carry_diff_t = smooth(SWAP_LONG_t, CarrySmoothBars) − smooth(SWAP_SHORT_t, CarrySmoothBars)`

where `SWAP_LONG/SHORT_t` come from `SymbolInfoDouble(_Symbol, SYMBOL_SWAP_LONG)` and `SymbolInfoDouble(_Symbol, SYMBOL_SWAP_SHORT)`, normalised to a common unit (broker-dependent — CTO verifies at D1; typical is "points per lot per day"). `smooth` is a simple moving average over `CarrySmoothBars` bars to suppress day-of-week swap quirks (Wednesday triple-swap, broker-fixed weekends).

Direction:

- `carry_dir_t = +1` (long bias) if `carry_diff_t > +CarrySignThresh`
- `carry_dir_t = −1` (short bias) if `carry_diff_t < −CarrySignThresh`
- `carry_dir_t = 0` (no signal) otherwise

`CarrySignThresh` is a non-zero deadband to avoid flipping on swap-rate rounding noise. Default `0.05` in broker swap units (CTO verifies unit compatibility at D1; may need per-broker scaling).

**Stability audit (P1 requirement).** Count sign flips of `carry_diff_t` over the DEV window per pair. Flag pairs with > 8 flips per year ("flippy carry") as non-viable — carry anchor is then noise.

### Stage B — Realized-skew regime

On the D1 bar `t`, compute rolling realized skewness of log-returns:

`r_i = log(Close[i] / Close[i−1])` for `i ∈ [t − SkewWindow + 1, t]`, **excluding weekend-gap bars** (first bar after a market close of > 48h) per the weekend-gap concern in §2.

`skew_t = (1/N) * Σ ((r_i − mean(r)) / std(r))^3`

with N = number of non-excluded bars in the window (requires `N ≥ 0.5 * SkewWindow` else defer to next bar).

Skew-regime classifier (direction-dependent):

- For `carry_dir_t = +1` (long bias): "good-regime" iff `skew_t >= +SkewGoodThresh_Long`. Intuition: a recent-return distribution that has been right-skewed (more upside surprises than downside) suggests the crash-to-the-downside tail is not currently being realised, and a long carry trade is in the favourable regime.
- For `carry_dir_t = −1` (short bias): "good-regime" iff `skew_t <= −SkewGoodThresh_Short`. Intuition: symmetric — recent left-skewed distribution (downside surprises dominant) makes a short carry trade (collecting negative carry against the low-rate currency) the favourable side.
- For `carry_dir_t = 0`: no signal regardless.

Defaults: `SkewGoodThresh_Long = 0.00`, `SkewGoodThresh_Short = 0.00`. Non-zero defaults introduce a skew-dead-zone where NEITHER direction is favourable — tunable in P3.

### Stage C — Entry decision

Enter at Open[t+1]:

- **Long** if `carry_dir_t = +1` AND `skew_t >= +SkewGoodThresh_Long` AND flat.
- **Short** if `carry_dir_t = −1` AND `skew_t <= −SkewGoodThresh_Short` AND flat.
- **Stay flat** otherwise.

No pyramiding. Single open position per symbol.

### Parameters

| Parameter | Default | P3 sweep grid | Notes |
|---|---|---|---|
| `CarrySmoothBars` | 5 | {1, 5, 10} | Smoothing window for swap differential. 1 = raw daily swap; 10 = ~2 weeks. |
| `CarrySignThresh` | 0.05 | {0.00, 0.05, 0.10} | Deadband on smoothed carry differential. Broker-unit-dependent. |
| `SkewWindow` | 60 | {30, 60, 120} | Rolling window for realized skew, in non-weekend D1 bars. |
| `SkewGoodThresh_Long` | 0.00 | {−0.30, 0.00, +0.30} | Minimum rolling skew for a long entry. |
| `SkewGoodThresh_Short` | 0.00 | {−0.30, 0.00, +0.30} | Mirror for shorts (threshold is a negative number: require `skew ≤ −thresh`). |
| `SkewWinsorSigma` | 5.0 | {3.0, 5.0, none} | Winsorisation of input returns at ±Nσ before skew compute. Defends against single-day outliers dominating the skew statistic. |
| `EnableLongs` | true | {true, false} | Leg ablation. |
| `EnableShorts` | true | {true, false} | Leg ablation. |
| `ATRHardStop_Mult` | 3.0 | {2.0, 3.0, 5.0} | Catastrophic backstop. |

Rule constraints (enforced `OnInit`, EA refuses to start if violated):
- `SkewWindow >= 20` (skew statistic unstable below this).
- `CarrySmoothBars >= 1`.
- At least one of `EnableLongs`, `EnableShorts` is true.

## 4. Exit Rules

| Trigger | Rule |
|---|---|
| Carry direction reversal | If long and `carry_dir_t` flips to `−1` or `0` for ≥ 2 consecutive closes, close at Open[t+1]. Short is symmetric. The "≥ 2 consecutive" debounce avoids single-bar swap-quote glitches forcing an exit. |
| Skew-regime exit to bad regime | If long and `skew_t < +SkewGoodThresh_Long` for ≥ 3 consecutive closes, close at Open[t+1]. Short symmetric. Longer debounce than carry direction because rolling skew is slower-moving. |
| ATR hard stop | `ATRHardStop_Mult * ATR(14)[entry]`, frozen at entry. Catastrophic backstop for 2008-style overnight peso-event unwinds that the skew proxy cannot anticipate (core failure mode of the paper's own thesis, amplified here because our proxy is backward-looking). |
| Hard TP | None. Carry + skew method is horizon-adaptive; fixed TP destroys the "ride the good regime" rule. |
| Time stop | Optional `MaxHoldBars = 252` (1Y) as a sanity cap. Default off; available as P3 ablation. |
| Breakeven | None in V1. V2 optional (exit-only, pre-registered per `feedback_enhancement_doctrine`): tighten hard stop to entry after `+2 * ATR(14)` favourable move. |
| News / session | Deferred to P8 News Impact (OFF / PAUSE / SKIP_DAY). |

**Design note on the debounced regime exit.** The 3-bar debounce on skew exits is load-bearing for trade-count — without it, single-day return outliers on any pair flip the rolling-skew sign and force premature exits, killing the "ride the favourable regime" mechanic. Do not remove in simplification passes.

## 5. Position Sizing

Per Hard Rule 6, both sizing modes supported:

- `RISK_PERCENT` — percent-of-equity risk per trade (live-deploy default 0.50%).
- `RISK_FIXED` — fixed $1,000 per trade (DEV baseline per `feedback_fixed_risk_methodology`).

Stop distance for sizing: `StopLossDistance = ATRHardStop_Mult * ATR(14)[entry]` (the hard backstop — Carry/Skew exits are not fixed geometric distances and cannot size).

`lots = RiskAmount / (StopLossDistance * TickValuePerLot)`, rounded down to broker `lotStep`, clipped to `[minLot, maxLot]`. Below `minLot` → log `SKIP_MIN_LOT`, no silent sizing up.

**No pyramiding.** Single open position per symbol.

**Carry-accrual credit (informational).** The swap P&L accrues daily while the position is open and is part of the realised trade result at exit. This is MT5-native — no bookkeeping added by the EA — but CTO confirms that Strategy Tester Model 4 applies broker-fixed swap through the backtest (this is the §2 caveat repeated: swap-rate history is not replayed, current-broker swap is applied).

Magic number: `SM_<id>*10000 + symbol_slot` per Hard Rule 8.

## 6. Required Indicators / Data

All MT5-native — Hard Rule 12 compliant:

| Indicator / data | MT5 source | Notes |
|---|---|---|
| Swap rates | `SymbolInfoDouble(sym, SYMBOL_SWAP_LONG)` / `SYMBOL_SWAP_SHORT` | Carry anchor. Broker-fixed in Strategy Tester — see §2 / §5 caveat. |
| Log-returns | `iClose` on PERIOD_D1 + in-EA log-diff | Input to realized-skew statistic. |
| Weekend-gap detection | `iTime` on PERIOD_D1 + delta-t check > 48h | Exclude gap bars from skew window per §2. |
| Realized skew | In-EA (vectorised over rolling buffer, double precision) | Single pass over the SkewWindow buffer; O(N) per bar. |
| ATR(14) | `iATR` on PERIOD_D1 | Hard stop + sizing. |
| Tick data | Darwinex native D1 (Model 4 per Hard Rule 6) | No external API. |

**Universe (Darwinex .DWX tick-data symbols, D1):**

- **Tier 1 (macro G10 crosses with non-trivial and relatively stable swap differentials):** `AUDUSD.DWX`, `NZDUSD.DWX`, `USDJPY.DWX`, `AUDJPY.DWX`, `NZDJPY.DWX`. These are the canonical carry trades on G10; broker swap is meaningfully positive on one side over the DEV window.
- **Tier 2 (USD-majors with smaller but non-zero carry differential):** `EURUSD.DWX`, `GBPUSD.DWX`, `USDCAD.DWX`. Carry signal may be weak; included for universe completeness + overlap audit with SM_076.
- **Explicitly excluded:** `EURCHF.DWX` (negative-rate regime 2015-2022, broker-swap unreliable), `EURGBP.DWX` (near-zero rate differential over DEV), crosses not covered by Darwinex D1 feed.
- **Crypto, commodities, indices:** excluded — no carry concept under the paper's framework.

Final P2 universe: 8 pairs. CTO confirms each has non-trivial `SWAP_LONG` + `SWAP_SHORT` values on Darwinex before D1 merge (see Open Question 1 in §9).

## 7. Backtest Scope

- **DEV window:** 2017-01-01 → 2022-12-31 (Pipeline V2.1 standard).
- **HO window:** 2023-01-01 → present.
- **Tester model:** Model 4 — Every Real Tick (Hard Rule 6).
- **Baseline gate targets (P2):** PF > 1.30, Trades > 200, DD < 12%.
- **Primary symbols for P2 baseline scan:** Tier 1 (5) + Tier 2 (3) = 8 pairs.
- **P3 sweep axes:** `CarrySmoothBars (3) × CarrySignThresh (3) × SkewWindow (3) × SkewGoodThresh_Long (3) × SkewGoodThresh_Short (3) × EnableLongs (2) × EnableShorts (2)` = 972 configs nominal. **Staged sweep:** Stage 1 — freeze leg ablations (both on) and `CarrySignThresh = 0.05`, sweep carry-smooth + skew-window + both skew thresholds = 81 configs ranked by DEV Sharpe. Stage 2 — top-15 Stage-1 configs × 4 leg/threshold ablations = 60 configs. Total 141 across two batches, within bounded-48-batch convention.
- **P3.5 CSR classes:** (a) JPY-crosses (`USDJPY`, `AUDJPY`, `NZDJPY`) vs (b) non-JPY G10 (`AUDUSD`, `NZDUSD`, `EURUSD`, `GBPUSD`, `USDCAD`). Gate: PF > 1.0 on both classes, Sharpe drop < 40%.

**Trade-count expectation.** With two gating conditions (carry direction + skew regime), expected entry rate is ~4-10 round-trips per pair per year on D1. Over 6-year DEV per pair, trade count likely in [24, 60], **failing the T > 200 per-symbol P2 floor**. Two options per Hard Rule 11 / prior-art:

1. **Aggregate 8-pair portfolio baseline** for the P2 PF/DD gate (decision identical to QUAA-239 ATH Breakout and QUAA-240 Two-Regime Trend Following). CTO/CEO confirm at P2 spawn.
2. **Relax the skew threshold** in Stage-1 sweep to accept ~15-20 round-trips per pair per year — but this also weakens the filter, which is the whole point.

Option 1 is recommended. Flag explicitly at P2 dispatch.

**Mandatory P3.5 side-by-side vs existing carry family.** This spec's core claim is net-new value over existing `SM_076 CarryDivergence` (AUDUSD/USDJPY) and the generic `SM_1341` / `SM_1342` / `SM_1343` / `SM_1363` carry filters. P3.5 MUST include a direct comparison on the shared pair subset: this EA vs. the best of those four on identical symbols, identical window, identical risk mode. **Kill gates** per §2 failure hypothesis:

- Trade-set overlap ≥ 80% AND PF differential < 10% → reject as duplicative.
- Otherwise promote to P4 if gate criteria met.

## 8. Original Source

Primary source URL (paperswithbacktest.com editorial):

> https://paperswithbacktest.com/strategies/good-carry-bad-carry

R1 catalog (row #73): *Good Carry, Bad Carry*, Bekaert & Panayotov 2018, Currencies (monthly), Sharpe 1.74 reported, summary: "Distinguishes between good and bad carry trades from G-10 currencies based on Sharpe ratios and return skewness characteristics."

R2 suitability (ranked GO table row #5, combined 8/10, plausibility 4, implementation ease 4): *"Skew-filtered G10 FX carry signal; reducible to single-pair directional; overlap-with-CarryDivergence"* — all three notes are explicitly addressed: per-pair reduction in §3, skew proxy in §6 / §9, overlap audit in §7 / §9.

**Underlying paper (primary source):**

- Bekaert, G., & Panayotov, G. (2018/2019). *Good Carry, Bad Carry.* Journal of Financial and Quantitative Analysis forthcoming at the time; SSRN preprint: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2516907 (to be verified — if SSRN abstract ID differs, CTO updates before D1 merge).
- Paper scope: G10 currencies vs USD, monthly data 1990-2014. Skew signal = 1M risk-reversal implied volatility differential from OTC FX options. "Good carry" portfolio = high-carry currencies whose skew signal indicates low crash risk; "bad carry" = the complement. Good-carry long-short portfolio Sharpe 0.99 vs. plain-carry 0.44; max drawdown cut roughly in half.

**Reported source-page performance** (paperswithbacktest editorial, monthly G10 FX):

| Metric | Value |
|---|---|
| Sharpe | 1.74 |
| Asset class | Currencies (monthly) |

Not applicable as a target for our D1 per-pair adaptation — different frequency, different skew measure, different universe structure. P2 on our universe is authoritative.

**Supporting literature for the proxy substitution:**

- Amaya, D., Christoffersen, P., Jacobs, K., & Vasquez, A. (2015). *Does realized skewness predict the cross-section of equity returns?* Journal of Financial Economics, 118(1). Evidence that realized higher moments carry risk premia — justifies realized-skew as a *distinct* signal, not merely a degraded options proxy.
- Chang, B. Y., Christoffersen, P., & Jacobs, K. (2013). *Market skewness risk and the cross-section of stock returns.* Journal of Financial Economics 107(1).

## 9. Implementation Notes (CTO)

### Hard Rule 12 decision: GO with proxy, not NO_GO

Per the issue brief ("If the skew filter REQUIRES options data, flag NO_GO on Hard Rule 12 grounds"), the threshold question is whether an OHLC-derived substitute is clean enough to carry the thesis. The verdict in this spec is **GO**, for these reasons:

1. **Both inputs are MT5-native.** Carry via `SymbolInfoDouble(SYMBOL_SWAP_LONG/SHORT)` (precedent: SM_076, SM_1341/1342/1343/1363, all compile-clean and in registry). Realized skew via in-EA rolling moment of log-returns. No external market data required; Hard Rule 12 satisfied on both legs.
2. **Realized skew is not a weaker options-skew — it is a different signal with independent academic support.** Amaya et al. (2015) and Chang/Christoffersen/Jacobs (2013) establish realized higher-moment risk premia as a distinct phenomenon from options-implied skew. The EA therefore is not a "Bekaert-Panayotov implemented with worse data"; it is "a carry-direction rule gated by a realized-higher-moment regime filter", inspired by Bekaert-Panayotov. This is a legitimate research variant and is how the spec is framed.
3. **Honest in framing.** The spec does not claim paper-equivalence. Section 1 explicitly says "named-resemblance variant" and "thesis degrades". The P3.5 kill gate is the enforcement mechanism: if the realized-skew filter does not add value over plain carry, the family dies in pipeline; no fantasy-number promotion.

**If CTO / CEO disagree and want this rejected on Hard Rule 12 grounds**, the rejection rationale is one-liner: "Bekaert-Panayotov formally requires options-implied skew which is not MT5-native; realized-skew is an inspired-variant, not the paper's strategy; overlap risk with SM_076 makes the inspired variant low-priority." That is a defensible position; this spec recommends the weaker position (try it, kill fast if it fails) because the incremental implementation cost is low and the filter-vs-no-filter P2 ablation is cheap signal either way.

### Net-new-edge argument vs existing carry family

| SM | Name | Mechanism | What this spec adds |
|---|---|---|---|
| SM_076 | CarryDivergence (AUDUSD, USDJPY; M15) | Intraday divergence between pair price and swap-differential signal; session-specific | No skew-regime gate; different TF; narrow universe. This spec: D1 (not M15), 8-pair universe, adds realized-skew gate. |
| SM_1341 / 1342 / 1343 / 1363 | Generic carry filters | Binary: only take trades aligned with positive broker-swap on that side | No skew gate; takes every carry-aligned signal. This spec: adds the good/bad-regime filter that is the whole point. |

**What is net-new in this spec:** the realized-skew regime gate. That is the whole incremental claim. If the gate does not survive P3.5 (kill gates per §7), the family has no net-new value — reject per Hard Rule 11.

### Load-bearing CTO confirmations needed

1. **Swap-rate units per Darwinex symbol.** `SYMBOL_SWAP_LONG` returns a broker-specific numeric that depends on `SYMBOL_SWAP_MODE`. On Darwinex this is typically `SYMBOL_SWAP_MODE_POINTS` (points per lot per night) but must be verified per pair. The `CarrySignThresh` default of 0.05 assumes points-units; will need per-broker rescaling if not. **CTO runs a one-shot script reading swap values for all 8 pairs before D1 merge and confirms units are consistent; adjust threshold default accordingly.**
2. **Strategy Tester swap handling.** MT5 Strategy Tester uses the **current, live** broker swap for the entire backtest window — swap history is **not** replayed. This is a real limitation for this family, acknowledged in §2 and §5. The carry direction therefore is near-static over the DEV window per pair (whatever sign it has now, it has throughout). This reduces the carry signal to "does this pair currently have positive carry, yes/no, all else equal"; the skew filter is doing most of the time-variation work. CTO confirms this understanding before D1 merge — this is the single most important methodological caveat.
3. **Weekend-gap exclusion in skew window.** CTO confirms the existing `FTMO_Strategy_Base.mqh` or an auxiliary utility provides a "is this bar the first after a market-close of > 48h" flag. If not, add inline `iTime` delta check. The §2 contamination concern is real; without exclusion, proxy is biased toward "bad regime" across all pairs.
4. **Numerical stability of rolling skew.** Skewness is notoriously unstable for short windows. The default `SkewWindow = 60` is the shortest defensible value; below that the statistic is dominated by 1-2 outlier bars. The `SkewWinsorSigma = 5.0` default is a safety net. Variance computation must use two-pass (Welford) to avoid catastrophic cancellation at small means; one-pass `E[X^2] − E[X]^2` is a P1 kill for this statistic.

### CTO implementation checklist

- **Inherit** `Include/FTMO/FTMO_Strategy_Base.mqh` per Hard Rule 6.
- **SM-ID:** allocate next free via `Company/data/ea_registry.json` auto-bump; register one logical EA (Hard Rule 11).
- **Magic number:** `SM_<id>*10000 + symbol_slot` (Hard Rule 8).
- **Carry signal:**
  - Read `SYMBOL_SWAP_LONG` and `SYMBOL_SWAP_SHORT` once per D1 close; cache into a 10-bar rolling buffer; apply SMA over `CarrySmoothBars`.
  - Compute `carry_diff` and classify into `+1 / 0 / -1` using `CarrySignThresh`.
  - Log sign flip count per pair for the P1 audit required by §2.
- **Skew signal:**
  - Maintain rolling buffer of log-returns, sized `SkewWindow + 5` (safety margin for weekend excludes).
  - On each D1 close: exclude weekend-gap bar if present; Winsorize at `±SkewWinsorSigma * std` (computed from the un-Winsorized pass, two-pass); compute realized skew with Welford's online variance + third-moment accumulator.
  - Log skew distribution summary stats per pair over the DEV window (for P1 proxy-validity audit).
- **Entry logic:** strict AND of carry direction + skew regime (direction-dependent threshold). Single position per symbol.
- **Exit logic:** debounced (2-bar carry-flip, 3-bar skew-exit) — load-bearing per §4.
- **Look-ahead discipline:** at bar `t`, the skew stat uses only `r_{t−SkewWindow+1 .. t}`; entry decision forms at close of `t`; entry fill at Open[t+1]. No full-sample quantile thresholds — all thresholds are fixed parameters at init.
- **P1 smoke:** deterministic D1 2017-2019 on AUDUSD and USDJPY. Byte-identical trade logs across two runs. No RNG anywhere in this EA.
- **Symbol suffix** `.DWX` in research/backtest; stripped only on VPS deploy (Hard Rule 7).
- **SKIP_MIN_LOT** handling: log-skip only, never silent round-up.

### Open design questions for CTO (answer before D1 merge)

1. **Swap-rate unit verification.** See confirmation 1 above. One-shot script output + confirmation in issue comment before merge.
2. **Strategy Tester swap-history handling.** See confirmation 2 above. If there is any broker/tester option to enable time-varying swap, flag it; otherwise confirm the static-swap limitation is acknowledged and P2 results interpreted accordingly.
3. **Realized skew vs. range-based skew (Yang-Zhang-style) as an ablation axis.** Range-based skew (e.g., using intrabar High/Low/Open/Close) uses more information per bar than return-based skew and may be more robust on D1. Consider adding as hidden P3 axis `SkewEstimator ∈ {"returns", "HLOC_range"}`. Defer to V2 if two code paths are judged too complex for V1.
4. **Carry-direction debounce length.** The default 2-bar debounce on carry-flip may be too short if broker swap rates update intra-bar. Consider escalating to 3-bar if P1 audit shows > 3 flips/year per pair even after 5-bar smoothing. Monitor in P1.

## 10. Pipeline Results

*Empty at spec time. Auto-populated post P2 / P3 / P3.5 by Controlling agent.*

| Phase | Symbol | PF | Trades | DD | Verdict | Date | Report |
|---|---|---|---|---|---|---|---|
| P1 proxy-validity audit | — | — | — | — | — | — | — |
| P2 | — | — | — | — | — | — | — |
| P3 | — | — | — | — | — | — | — |
| P3.5 CSR | — | — | — | — | — | — | — |
| P3.5 vs SM_076/1341/1342/1343/1363 | — | — | — | — | — | — | — |
| P4 | — | — | — | — | — | — | — |
