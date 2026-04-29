# Strategy Card — Chan AT Time-Series Momentum on Single Futures (daily, N-day-ago sign comparison + M-day rebalanced overlapping holds)

> Drafted by Research Agent on 2026-04-28 from `strategy-seeds/sources/SRC05/raw/ch6_7_pp133-168.txt` lines 871-946 (Ex 6.1 verbatim MATLAB + TU performance) + Table 6.2 (lines 924-932, BR/HG/TU generalization) + lines 858-870 (Moskowitz-Yao-Pedersen narrative framing) + lines 937-946 (roll-return-threshold variant).
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per QUA-188 waiver v3).

## Card Header

```yaml
strategy_id: SRC05_S07
ea_id: TBD
slug: chan-at-ts-mom-fut
status: DRAFT
created: 2026-04-28
created_by: Research
last_updated: 2026-04-28

strategy_type_flags:
  - time-series-momentum                      # NEW VOCAB GAP — entry mechanism: long if price[t] > price[t-N], short if price[t] < price[t-N], hold for M days, daily-rebalanced 1/M-allocation overlap. Distinct from donchian-breakout (no rolling N-bar extreme; just price-vs-N-ago sign), n-period-max-continuation (no rolling-N-bar-max gate; just sign of N-day return), and ath-breakout (no all-time-high requirement).
  - signal-reversal-exit                      # exit mechanism: position closed/flipped on N-day-ago sign reversal of the N-day-lagged return signal
  - symmetric-long-short                      # both long-momentum and short-momentum directions deployable
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Chan, Ernest P. (2013). Algorithmic Trading: Winning Strategies and Their Rationale. Wiley Trading. Hoboken, NJ: John Wiley & Sons. ISBN 978-1-118-46014-6 (cloth) / 978-1-118-46019-1 (ebk)."
    location: "Chapter 6 'Interday Momentum Strategies', § 'Time Series Strategies' (PDF pp. 137-140 / printed pp. 137-140). Example 6.1 'TU Momentum Strategy' (PDF p. 138 / printed p. 138) is the primary TU two-year-Treasury-Note case. Table 6.2 'Time Series Momentum Strategies for Various Futures' (PDF p. 139 / printed p. 139) gives BR (Brazilian Real) and HG (Copper) generalizations. Roll-return-threshold variant inline at PDF pp. 140 / printed p. 140."
    quality_tier: A
    role: primary
  - type: paper
    citation: "Moskowitz, Tobias J., Yao Hua Ooi, and Lasse Heje Pedersen. (2012). Time series momentum. Journal of Financial Economics, 104(2), 228-250."
    location: "cited by Chan p. 138 as the source paper for the simple sign-of-N-day-return entry rule"
    quality_tier: A
    role: supplement
```

Raw evidence: `strategy-seeds/sources/SRC05/raw/ch6_7_pp133-168.txt` lines 858-946. Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Algorithmic Trading_ Winning St - Ernie Chan.pdf`.

## 2. Concept

A **single-futures time-series-momentum strategy** that takes the sign of the N-day-lagged return as the trade direction and holds for M days, with daily 1/M-overlapping rebalancing so M independent slot-positions co-exist. Chan motivates the strategy from the persistence of the *sign* of the roll return — not the magnitude. From Ch 6 § "Time Series Strategies" (p. 138):

> "Since Table 6.1 shows us that for TU, the 250-25-days pairs of returns have a correlation coefficient of 0.27 with a p-value of 0.02, we will pick this look-back and holding period. We take our cue for a simple time series momentum strategy from a paper by Moskowitz, Yao, and Pedersen: simply buy (sell) the future if it has a positive (negative) 12-month return, and hold the position for 1 month (Moskowitz, Yao, and Pedersen, 2012). We will modify one detail of the original strategy: Instead of making a trading decision every month, we will make it every day, each day investing only one twenty-fifth of the total capital." (p. 138)

Chan's causal explanation for *why* serial-correlation-at-long-time-scale exists for futures (p. 139):

> "Why do many futures returns exhibit serial correlations? And why do these serial correlations occur only at a fairly long time scale? The explanation lies in the roll return component of the total return of futures we discussed in Chapter 5. Typically, the sign of roll returns does not vary very often. In other words, the futures stay in contango or backwardation over long periods of time. The spot returns, however, can vary very rapidly in both sign and magnitude. So if we hold a future over a long period of time, and if the average roll returns dominate the average total returns, we will find serial correlation of total returns." (p. 139)

The entry rule is intentionally minimalist: `longs = cl > backshift(LOOKBACK, cl)` and `shorts = cl < backshift(LOOKBACK, cl)`. The *daily 1/M-overlap mechanic* (Chan's modification of Moskowitz-Yao-Pedersen) means that on each calendar day, M independent paper-positions are stacked: a NEW position opened today, plus the M-1 still-open positions opened on each of the prior M-1 days. This produces a smoothed equity curve approximating Moskowitz et al.'s monthly-rebalance result.

The strategy generalizes to many futures with different optimal (LOOKBACK, HOLD_DAYS) per Table 6.2:

| Symbol | Look-back | Holding days | APR | Sharpe ratio | Max drawdown |
|---|---|---|---|---|---|
| BR (CME)  | 100 | 10 | 17.7% | 1.09 | -14.8% |
| HG (CME)  | 40  | 40 | 18.0% | 1.05 | -24.0% |
| TU (CBOT) | 250 | 25 | 1.7%  | 1.04 | -2.5%  |

Variant — roll-return-threshold gating (Chan p. 140):

> "If we accept the explanation that the time series momentum of futures is due to the persistence of the signs of the roll returns, then we can devise a cleaner and potentially better momentum signal than the lagged total return. We can use the lagged roll return as a signal instead, and go long when this return is higher than some threshold, go short when this return is lower than the negative of that threshold, and exit any existing position otherwise. Applying this revised strategy on TU with a threshold of an annualized roll return of 3 percent yields a higher APR of 2.5 percent and Sharpe ratio of 2.1 from January 2, 2009, to August 13, 2012, with a reduced maximum drawdown of 1.1 percent." (p. 140)

## 3. Markets & Timeframes

```yaml
markets:
  - commodities_futures                       # Chan's deployment: TU (2yr T-Note, CBOT), BR (Brazilian Real, CME), HG (Copper, CME); generalizes to any future with persistent roll-return sign per Table 5.1 (PDF p. 121)
  # V5 Darwinex re-mapping: Darwinex spot/CFD universe includes some commodity proxies (e.g., COPPER.DWX, BRENT.DWX). However, the *roll-return-driven* edge requires actual futures with deterministic roll cycles; spot CFDs are roll-engineered by Darwinex internally (financing-rate adjustments) which may or may not preserve the roll-return persistence Chan cites. CTO confirms at G0 whether the strategy's thesis survives the Darwinex spot-CFD wrapper — flag dwx_suffix_discipline at risk.
timeframes:
  - D1                                        # Chan deploys on daily closes
session_window: end-of-day                    # signals computed on daily close; entries on next-day open
primary_target_symbols:
  - "TU (2yr T-Note future, CBOT) — LOOKBACK=250, HOLD_DAYS=25, default Chan parameters"
  - "BR (Brazilian Real future, CME) — LOOKBACK=100, HOLD_DAYS=10"
  - "HG (Copper future, CME) — LOOKBACK=40, HOLD_DAYS=40"
  - "V5 Darwinex mapping: TBD — candidate proxies COPPER.DWX (HG analogue), USDBRL.DWX (BR analogue), USDJPY.DWX or 2yr-bond CFD (TU analogue if available)"
```

## 4. Entry Rules

Pseudocode — verbatim from Chan's Ch 6 Ex 6.1 MATLAB code (PDF p. 138).

```text
PARAMETERS (Chan-defaults from Ex 6.1 MATLAB code, TU case):
- LOOKBACK    = 250        // trading days; Chan p. 138: "lookback=250"
- HOLD_DAYS   = 25         // trading days; Chan p. 138: "holddays=25"
- BAR         = D1         // Chan deploys on daily closes
- ALLOCATION  = 1/HOLD_DAYS // each daily entry sized at 1/HOLD_DAYS of total capital;
                            //   M=HOLD_DAYS independent paper-positions stacked at any time
                            //   per Chan: "each day investing only one twenty-fifth of the
                            //   total capital" (when HOLD_DAYS=25)

PER-DAY (at daily close, generating signals for next session):
- // Step 1 — compute the binary direction signal from the LOOKBACK-day-ago price
- longs(t)  = (cl(t) > cl(t - LOOKBACK))      // Chan: "longs=cl > backshift(lookback, cl)"
- shorts(t) = (cl(t) < cl(t - LOOKBACK))      // Chan: "shorts=cl < backshift(lookback, cl)"
-
- // Step 2 — accumulate net position from the last HOLD_DAYS daily signals
- pos(t) = sum over h=0..HOLD_DAYS-1 of {
-              +1 if longs(t-h) is true,
-              -1 if shorts(t-h) is true,
-               0 if neither }
- // Chan's MATLAB code:
- //     for h=0:holddays-1
- //         long_lag=backshift(h, longs); pos(long_lag)=pos(long_lag)+1;
- //         short_lag=backshift(h, shorts); pos(short_lag)=pos(short_lag)-1;
- //     end

ENTRY:
- At day t close, OPEN a 1/HOLD_DAYS-sized position at the next-session open in direction:
-     +1 (long) if longs(t) and there is room in the M-slot stack
-     -1 (short) if shorts(t) and there is room in the M-slot stack
- The pos(t) variable is the net of M overlapping slots; the PER-SLOT direction is
-   binary-fixed at slot-open and held for HOLD_DAYS regardless of subsequent signal flips.

VARIANT — ROLL-RETURN-THRESHOLD GATING (Chan p. 140):
- THRESHOLD = 0.03  // annualized roll return threshold (3% in Chan's TU example)
- gamma_ann(t) = annualized roll return of the future (estimated per Ex 5.3 OLS-on-forward-curve)
- enter long  if gamma_ann(t) > +THRESHOLD
- enter short if gamma_ann(t) < -THRESHOLD
- exit any existing position if -THRESHOLD <= gamma_ann(t) <= +THRESHOLD
- // Chan: TU APR 2.5%, Sharpe 2.1, max DD 1.1% with this variant (Jan 2009 - Aug 2012)
```

## 5. Exit Rules

```text
EXIT (Ex 6.1 default — fixed M-day hold):
- Each slot is held for exactly HOLD_DAYS bars and closed at the next-day open after the
  HOLD_DAYS-th bar.
- No discretionary exit; no signal-reversal exit BEFORE HOLD_DAYS expiry.
- The aggregate net position pos(t) varies as new slots open and old ones close; this is
  smoothed by the M-day-overlap mechanic.

EXIT (Roll-return-threshold variant, p. 140):
- Position is exited (or reversed) whenever |gamma_ann(t)| < THRESHOLD.
- Position is REVERSED if gamma_ann(t) crosses zero outside the ±THRESHOLD dead-band.

NO STOP-LOSS in Chan's stated rules. The strategy relies on:
- The ALLOCATION = 1/HOLD_DAYS sizing to bound per-slot risk
- The aggregate pos(t) to mean-revert as signals flip over the HOLD_DAYS window
- V5 framework's QM_KillSwitch + account MAX_DD trip is the catastrophic backstop

Friday Close: standard V5 default applies (force-flat at Friday 21:00 broker time);
HOLD_DAYS = 10-40 trading days will straddle multiple weekends. The Friday-close forced flat
will fragment the M-overlap slot stack — flag friday_close at risk.
```

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults: kill-switch, news filter, MAX_DD trip
- Friday Close: ENABLED (V5 default; flag friday_close at risk per § 12 — HOLD_DAYS=10-40
  positions straddle multiple weekends; forced flat fragments the M-overlap mechanic)
- pyramiding: ALLOWED-BY-CONSTRUCTION (M=HOLD_DAYS overlapping slots is the strategy's
  natural shape; this is NOT discretionary pyramiding. CTO confirms at G0 whether V5
  framework's `one_position_per_magic_symbol` discipline can accommodate the M-overlap
  via M distinct magic numbers per symbol — flag magic_schema at risk if not).
- Optional Hurst-exponent / Variance-Ratio filter (P3 sweep axis):
    skip entries when Hurst(LOOKBACK) < HURST_THRESHOLD (i.e., regime is too mean-reverting)
    // Rationale: Chan p. 137: "the Hurst exponent is 0.44, while the Variance Ratio test
    //   failed to reject the hypothesis that this is a random walk." For TU at the
    //   correlation-significant (250, 25) point, the Hurst test fails despite TS-momentum
    //   working empirically. Optional regime filter as defense.
- Optional MR-blend filter (Chan p. 140 inline CL combination):
    "buy at the market close if the price is lower than that of 30 days ago and is higher
     than that of 40 days ago; vice versa for shorts" (Chan: APR 12%, Sharpe 1.1 on CL).
    This is a momentum-AND-MR filter, parameterizable as (MR_LOOKBACK, MOM_LOOKBACK).
```

## 7. Trade Management Rules

```text
- M=HOLD_DAYS overlapping slots per symbol; each slot binary-fixed direction and lifetime
- gridding: NOT allowed
- per-slot sizing: 1/HOLD_DAYS of total capital; aggregate exposure ≤ 1.0 in either
  direction; pos(t) ranges over [-HOLD_DAYS, +HOLD_DAYS] in slot-count units
- no native stop; catastrophic backstop via kill-switch + MAX_DD
- contract roll: each slot held for HOLD_DAYS calendar trading days; if a contract expires
  within a slot's lifetime, the slot must roll to the next contract at the per-slot
  open-price equivalent — Pipeline-Operator's standard continuous-contract convention applies.
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: lookback
  default: 250
  sweep_range: [25, 60, 100, 120, 250]          # Chan reports 250 (TU), 100 (BR), 40 (HG); sweep brackets the Table 6.1 correlation-significant points
- name: hold_days
  default: 25
  sweep_range: [5, 10, 25, 40, 60]              # Chan reports 25 (TU), 10 (BR), 40 (HG); sweep covers the Table 6.1 holding-period axis
- name: signal_form
  default: price_sign
  sweep_range: ["price_sign", "price_sign_with_mr_filter", "roll_return_threshold"]
                                                # Variant 1: bare cl > cl[t-N] (Ex 6.1 default)
                                                # Variant 2: + Chan's MR-and-momentum CL filter (p. 140 inline)
                                                # Variant 3: roll-return-gamma threshold (p. 140 — TU APR 2.5% / Sharpe 2.1)
- name: roll_return_threshold
  default: 0.03
  sweep_range: [0.01, 0.02, 0.03, 0.05, 0.10]   # only for signal_form == roll_return_threshold; Chan reports 3% on TU
- name: hurst_floor
  default: 0                                    # 0 disables the Hurst filter
  sweep_range: [0, 0.45, 0.50, 0.55]            # filter when measured Hurst < threshold (regime too mean-reverting)
- name: mr_blend_short_lookback
  default: 30
  sweep_range: [10, 20, 30, 40]                 # only for signal_form == price_sign_with_mr_filter
- name: mr_blend_long_lookback
  default: 40
  sweep_range: [30, 40, 60, 90]                 # only for signal_form == price_sign_with_mr_filter
```

P3.5 (CSR) axis: re-run on alternative futures with persistent roll-return sign per Chan Table 5.1 (p. 121) and Table 6.2 (p. 139): IBX (MEFF), KT (NYMEX), SXF (DE), US (CBOT), CD (CME), NG (NYMEX), W (CME) — Chan p. 140 names these as additional candidates. V5 Darwinex availability TBD per CTO at G0.

## 9. Author Claims (verbatim, with quote marks)

Ex 6.1 default — TU 2-year T-Note, LOOKBACK=250, HOLD_DAYS=25:

> "From June 1, 2004, to May 11, 2012, the Sharpe ratio is a respectable 1. The annual percentage rate (APR) of 1.7 percent may seem low, but our return is calculated based on the notional value of the contract, which is about $200,000. Margin requirement for this contract is only about $400. So you can certainly employ a reasonable amount of leverage to boost return, though one must also contend with the maximum drawdown of 2.5 percent. The equity curve also looks quite attractive (see Figure 6.2)." (pp. 138-139)

Table 6.2 generalization (p. 139), verbatim row contents:

> "TABLE 6.2 Time Series Momentum Strategies for Various Futures
> Symbol     Look-back Holding days APR  Sharpe ratio Max drawdown
> BR (CME)   100  10  17.7%              1.09                    −14.8%
> HG (CME)   40   40  18.0%              1.05                    −24.0%
> TU (CBOT)  250  25  1.7%               1.04                    −2.5%"

Causal thesis (p. 139):

> "Why do many futures returns exhibit serial correlations? And why do these serial correlations occur only at a fairly long time scale? The explanation lies in the roll return component of the total return of futures we discussed in Chapter 5. Typically, the sign of roll returns does not vary very often."

Roll-return-threshold variant (p. 140):

> "Applying this revised strategy on TU with a threshold of an annualized roll return of 3 percent yields a higher APR of 2.5 percent and Sharpe ratio of 2.1 from January 2, 2009, to August 13, 2012, with a reduced maximum drawdown of 1.1 percent."

MR-and-momentum CL combination variant (p. 140):

> "One example strategy on CL is this: buy at the market close if the price is lower than that of 30 days ago and is higher than that of 40 days ago; vice versa for shorts. If neither the buy nor the sell condition is satisfied, flatten any existing position. The APR is 12 percent, with a Sharpe ratio of 1.1."

Out-of-sample caution (p. 140):

> "Since there aren't many trades in the relatively limited amount of test data that we used due to the substantial holding periods, there is a risk of data-snooping bias in these results. The real test for the strategy is, as always, in true out-of-sample testing."

## 10. Initial Risk Profile

```yaml
expected_pf: 1.3                              # Sharpe ~1.0-1.1 range across BR/HG/TU = PF 1.2-1.4 unlevered; threshold variant Sharpe 2.1 implies higher PF on TU but small sample
expected_dd_pct: 24                           # max-DD per Table 6.2 ranges from 2.5% (TU) to 24% (HG); rough portfolio estimate
expected_trade_frequency: 25-40 slot-opens/year/symbol  # roughly 1 daily slot-open in either direction during signal-positive regimes; M-overlap means many concurrent slots
risk_class: medium                            # daily-bar futures with no native stop and 10-40-day holds; Sharpe ~1 is honest
gridding: false
scalping: false                               # daily bars; not scalping
ml_required: false                            # cl > cl[t-N] sign-comparison + binary direction; classical statistics only for the optional Hurst/VR filters
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical (`longs = cl > backshift(lookback, cl)` is fully deterministic)
- [x] No Machine Learning required (classical statistics for optional filters; core rule is sign-comparison)
- [x] If gridding: NOT applicable (M-overlap slot mechanic is not gridding — slot positions are NOT averaging-down on adverse moves; each slot is independent unidirectional)
- [x] If scalping: NOT applicable (D1 timeframe, 10-40-day holds)
- [ ] **Friday Close compatibility:** HOLD_DAYS=10-40 straddles multiple weekends; forced flat at Friday 21:00 → re-establish Monday open is operationally awkward and fragments the M-overlap mechanic. Net effect TBD at P3.
- [x] Source citation is precise enough to reproduce (chapter + section + Example number + verbatim MATLAB code + verbatim performance quotes for TU/BR/HG/threshold variant)
- [ ] **No near-duplicate of existing approved card** — distinct from S01/S02/S05/S06 (those are MR; this is momentum), distinct from existing `donchian-breakout` (no rolling-N-bar extreme; just price-vs-N-ago sign), distinct from `n-period-max-continuation` (no rolling-N-bar-max gate, longer hold), distinct from `ath-breakout` (no all-time-high requirement). DISAMBIGUATION confirmed at extraction.

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "standard V5 default (kill-switch, news filter, MAX_DD trip, Friday-close); optional Hurst-floor + MR-blend filters as P3 sweep axes."
  trade_entry:
    used: true
    notes: "binary cl > cl[t-LOOKBACK] sign + 1/HOLD_DAYS-sized slot opening per day; M=HOLD_DAYS overlapping slots per symbol"
  trade_management:
    used: true
    notes: "per-slot direction binary-fixed at slot-open; aggregate pos(t) = sum of M slots"
  trade_close:
    used: true
    notes: "fixed M-day hold per slot OR roll-return-threshold dead-band exit (variant)"
```

```yaml
hard_rules_at_risk:
  - friday_close                              # HOLD_DAYS=10-40 straddles multiple weekends; forced Friday flat fragments M-overlap mechanic
  - magic_schema                              # M overlapping slots per symbol violates strict one_position_per_magic_symbol; CTO confirms at G0 whether V5 supports M magic numbers per symbol (e.g., ea_id*10000 + symbol_slot*100 + slot_index_in_M)
  - one_position_per_magic_symbol             # same root issue as magic_schema; M overlapping slots are NOT discretionary pyramiding but the framework default is one position per magic
  - dwx_suffix_discipline                     # Chan's universe is CME/CBOT futures (TU, BR, HG); V5 deploys on Darwinex .DWX symbols. Roll-return-driven edge requires actual futures with deterministic roll cycles; spot CFDs are roll-engineered by Darwinex internally. CTO confirms at G0 whether the strategy's thesis survives the spot-CFD wrapper.
  - kill_switch_coverage                      # no native stop-loss; catastrophic backstop relies on V5 QM_KillSwitch and account-level MAX_DD trip
  - enhancement_doctrine                      # (LOOKBACK, HOLD_DAYS) values in Table 6.2 (250/25, 100/10, 40/40) are stated-with-hindsight via Chan's Table 6.1 correlation-screen; any post-PASS retune counts as enhancement_doctrine
  - darwinex_native_data_only                 # threshold-variant requires multi-month forward-curve data for γ estimation (per Ex 5.3 estimator); not necessarily in Darwinex-native data feed. Default Ex 6.1 form does NOT need this (uses single-symbol close prices only).

at_risk_explanation: |
  friday_close — HOLD_DAYS=10-40 trading days straddles MANY weekends. Forced flat at
  Friday 21:00 + re-establishment Monday open fragments the M-overlap mechanic and changes
  the average per-slot lifetime. P3 measures the impact; structurally the strategy may
  benefit from a friday_close exception waiver (analogous to S06's request).

  magic_schema + one_position_per_magic_symbol — load-bearing. The strategy's M-overlap
  mechanic is NOT discretionary pyramiding; each slot is an independent unidirectional
  position fixed-direction at slot-open. V5 framework's default `ea_id*10000+symbol_slot`
  schema covers ONE position per (ea_id, symbol). To accommodate M slots, either (a) extend
  to `ea_id*10000+symbol_slot*100+slot_index_in_M` (and sibling cards S03 chan-at-buy-on-gap,
  S07-S11 cross-sectional cards face the same magic-schema challenge) or (b) treat the
  M-overlap as a SINGLE aggregate pos(t) position and rebalance daily to net target. CTO
  decides at G0; CEO-level architecture decision.

  dwx_suffix_discipline — spot CFDs are Darwinex-managed roll instruments with internal
  rate adjustments. The roll-return persistence Chan cites is a property of the open-market
  futures curve (contango/backwardation regimes that don't flip frequently). Whether
  Darwinex's spot-CFD wrapping preserves this property is an empirical question for CTO at
  G0. If NOT, card may need to be either (a) deferred until Darwinex supports actual
  futures contracts with multi-month curves, or (b) tested on FX/index proxies that
  preserve momentum-style serial correlation without the roll-return mechanism.

  kill_switch_coverage — no native stop + 25-day-hold per slot = significant weekend-gap
  exposure even with kill-switch backstop. Slot-level loss capping via kill-switch is the
  catastrophic backstop. Chan's reported max-DD of -24% on HG suggests the strategy can
  experience meaningful drawdown without intervention.

  enhancement_doctrine — Table 6.2 (LOOKBACK, HOLD_DAYS) values come from Chan's Table 6.1
  correlation pre-screen across many lookback/holding pairs (PDF p. 137). This is itself a
  hindsight optimization; P3 sweep brackets the values explicitly, P3.5 CSR tests on additional
  Chan-named candidates (IBX, KT, SXF, US, CD, NG, W; Chan p. 140 Table 6.2 generalization
  list). Any post-PASS retune is enhancement_doctrine.

  darwinex_native_data_only — only binds for the roll-return-threshold variant (p. 140);
  the default Ex 6.1 form uses single-symbol closes only.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                               # standard V5 default; optional Hurst-floor + MR-blend filters
  entry: TBD                                  # cl > cl[t-LOOKBACK] sign + slot stack; M magic numbers per symbol or daily aggregate-rebalance approach. ~120-180 LOC native MQL5 (slot bookkeeping is the main complexity beyond a vanilla single-position EA)
  management: TBD                             # M-overlap slot stack OR aggregate-rebalance simplification
  close: TBD                                  # per-slot fixed HOLD_DAYS expiry OR roll-return-threshold dead-band exit (variant)
estimated_complexity: medium                  # core rule is trivial (sign comparison); slot-stack bookkeeping adds 1.5-2x complexity vs single-position EA
estimated_test_runtime: 2-4h                  # P3 sweep is large (5×5×3×5×4×4×4 ≈ 24,000 cells effective ~6,000) but per-cell backtest is fast (D1 single-symbol)
data_requirements: standard                   # default Ex 6.1 form uses single-symbol daily closes only; threshold variant adds multi-month forward-curve (custom_futures_curve)
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
- 2026-04-28: SRC05_S07 surfaces a NEW `strategy_type_flags` controlled-vocabulary GAP
  (entry side): `time-series-momentum` — entry mechanism: long if price[t] > price[t-N],
  short if price[t] < price[t-N], hold for M days, daily-rebalanced 1/M-allocation overlap.
  Distinct from:
  - `donchian-breakout` (no rolling-N-bar extreme; just price-vs-N-ago sign-comparison).
  - `n-period-max-continuation` (no rolling-N-bar-max gate; just sign of N-day return; longer
    hold M-day fixed).
  - `ath-breakout` (no all-time-high requirement; price-vs-N-ago is local rolling, not global).
  - `vol-expansion-breakout` (no volatility threshold; just sign of N-day return).
  Chan citation: Ch 6 Ex 6.1 PDF p. 138 + Table 6.2 PDF p. 139. Will batch-propose to CEO +
  CTO via the addition-process at the bottom of `strategy_type_flags.md` along with sibling
  flags from S06 (calendar-spread-mr) and forthcoming flags (futures-roll-return-arb,
  cross-sectional-momentum, opening-gap-momentum, event-driven-momentum).

- 2026-04-28: V5-architecture-fit is CHALLENGED at the magic-schema layer. The M=HOLD_DAYS
  overlapping-slots mechanic is NOT discretionary pyramiding (each slot is independent
  unidirectional, fixed at slot-open) but it DOES violate the V5 default
  `one_position_per_magic_symbol`. Two implementation paths:
  (i) Extend the magic schema to `ea_id*10000+symbol_slot*100+slot_index_in_M` so each slot
      has its own magic — clean separation but consumes M magic numbers per symbol.
  (ii) Aggregate the M slots into a SINGLE net pos(t) position and rebalance daily to the
       net-target (e.g., if 18 long-slots and 7 short-slots are open, target net = +11 lots
       in aggregate). This loses per-slot stop-loss granularity but conforms to the
       one_position_per_magic_symbol discipline.
  CTO decides at G0; this is also the architectural pre-requisite for sibling cards S03
  chan-at-buy-on-gap, S10 chan-at-xs-mom-fut, S11 chan-at-xs-mom-stock which face the same
  magic-schema challenge (cross-sectional N-symbol stack).

- 2026-04-28: Two verbatim variants offered by Chan are kept as P3 SWEEP AXES rather than
  separate cards:
  (a) ROLL-RETURN-THRESHOLD GATING (p. 140) — replaces the price-sign signal with the sign
      of estimated annualized roll-return γ outside a ±THRESHOLD dead-band. Chan reports
      TU APR 2.5%/Sharpe 2.1/max-DD -1.1% with THRESHOLD=3%. This is a 2x improvement on
      TU's bare Sharpe 1.04 but small-sample (Jan 2009-Aug 2012); P3 sweep validates.
  (b) MR-and-momentum CL COMBINATION (p. 140) — buys when price < cl[-30] AND price >
      cl[-40] (and vice versa for shorts). Chan reports CL APR 12%/Sharpe 1.1.
  Both variants share the same TS-momentum core and are folded as `signal_form` parameter
  values. Extracted as a SINGLE card per the SRC05 fold-vs-split convention.

- 2026-04-28: Out-of-sample caution from Chan p. 140 (data-snooping risk in TS-momentum
  backtests due to sparse-trade-count from long holds) is a P4 walk-forward consideration:
  the 4-year TU backtest has only ~20 independent (250-day-lookback × 25-day-hold) cycles.
  P4 walk-forward + P5b calibrated-noise stress + P5c crisis-slice (2008 financial crisis,
  2010 flash crash, 2011 EU debt crisis) are critical. CTO sets test-period priors at G0.
```
