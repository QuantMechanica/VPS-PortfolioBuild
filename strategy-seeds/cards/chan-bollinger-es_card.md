# Strategy Card — Chan Bollinger ES Mean-Reversion (single-symbol M5 ±2σ entry / ±1σ exit on E-mini S&P)

> Drafted by Research Agent on 2026-04-27 from `strategy-seeds/sources/SRC02/raw/bollinger_es_inline.md` (verbatim Ch 2 quote + mechanical-structure derivation + cardability verdict).
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per QUA-188 waiver v3).

## Card Header

```yaml
strategy_id: SRC02_S02
ea_id: TBD
slug: chan-bollinger-es
status: DRAFT
created: 2026-04-27
created_by: Research
last_updated: 2026-04-27

strategy_type_flags:                          # closest existing values from strategy_type_flags.md;
                                              # entry-side vocabulary gap (no Section-A flag for z-score-band MR on a single-leg series).
                                              # See § 16 for the gap-filling proposal.
  - signal-reversal-exit                      # closest available exit flag — exit fires when z crosses back inside ±1σ band (i.e. entry-trigger reverses)
  - symmetric-long-short                      # both directions deployable; ±2σ is symmetric
  - scalping                                  # M5 average-hold ≈ 1-3 bars — qualifies as "very-short-hold" per strategy_type_flags.md § E definition; mandates P5b VPS-latency calibration
  # *vocabulary-gap flag proposed for CEO + CTO ratification per strategy_type_flags.md addition-process (see § 16):
  #   - zscore-band-reversion                  # entry mechanism: single-leg price crosses ±N·σ band of its own moving statistics
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Chan, Ernest P. (2009). Quantitative Trading: How to Build Your Own Algorithmic Trading Business. Wiley Trading. ISBN 978-0-470-28488-9 (cloth). Hoboken, NJ: John Wiley & Sons."
    location: "Chapter 2 'Fishing for Ideas', § 'How Will Transaction Costs Affect the Strategy?', pp. 22-23 (inline mechanical example, NOT labeled Example 3.x by Chan; transitions immediately into the Example 3.7 cross-reference at p. 23 bottom)."
    quality_tier: A
    role: primary
  - type: book
    citation: "Bollinger, John A. (2001). Bollinger on Bollinger Bands. McGraw-Hill. ISBN 978-0-07-137368-8."
    location: "Chapter 4 'Bollinger Bands' (textbook 20-bar default lookback; standard convention adopted in this card's parameter defaults since Chan does not specify a lookback)."
    quality_tier: A
    role: supplement
```

Raw evidence: `strategy-seeds/sources/SRC02/raw/bollinger_es_inline.md`. Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Quantitative Trading_ How to Bu - Ernest P. Chan.pdf`.

## 2. Concept

A **classical Bollinger-band mean-reversion strategy on E-mini S&P 500 futures** evaluated each M5 bar close. When the close pierces the upper band (price > MA + 2σ over lookback N), the strategy goes short, betting on reversion to the mean. When the close pierces the lower band (price < MA − 2σ), it goes long. The position closes when the price returns to within ±1σ of the moving average. The thesis is short-horizon noise-driven reversion: the index over-shoots its moving average due to liquidity-driven imbalances, and the over-shoot tends to reverse over a small number of M5 bars.

Chan introduces this strategy explicitly as a **deliberate transaction-cost failure example**: pre-cost Sharpe is ≈ +3 (very high), but a 1 bp/trade cost collapses post-cost Sharpe to ≈ −3. The very high entry frequency at the ±2σ threshold means the strategy churns through transaction costs even though the per-trade reversion edge is real. This card is drafted per DL-033 Rule 1 (every distinct mechanical strategy that passes V5 hard rules gets a card; pipeline gates do the filtering); the appropriate gate to surface the failure is **P9b Operational Readiness**, where realistic Darwinex `US500.DWX` spreads (typically 1-4 bp on a ~5000 quote) replicate or exceed Chan's 1 bp assumption.

Chan's verbatim framing, p. 23:

> "consider this simple mean-reverting strategy on ES. It is based on Bollinger bands: that is, every time the price exceeds plus or minus 2 moving standard deviations of its moving average, short or buy, respectively. Exit the position when the price reverts back to within 1 moving standard deviation of the moving average. If you allow yourself to enter and exit every five minutes, you will find that the Sharpe ratio is about 3 without transaction costs—very excellent indeed! Unfortunately, the Sharpe ratio is reduced to −3 if we subtract 1 basis point as transaction costs, making it a very unprofitable strategy."

## 3. Markets & Timeframes

```yaml
markets:
  - index_futures                             # Chan's deployment: ES (E-mini S&P 500 futures, CME)
  # V5 Darwinex re-mapping at CTO sanity-check: candidate proxy is US500.DWX (CFD on the S&P 500 index)
timeframes:
  - M5                                        # Chan: "If you allow yourself to enter and exit every five minutes"
session_window: 24-hour                       # ES trades nearly 24/5; intraday holds typical, no specific session restriction by Chan
primary_target_symbols:
  - "ES (E-mini S&P 500 futures, CME) — Chan's deployment"
  - "US500.DWX — V5 Darwinex spot/CFD proxy (proposed; CTO confirms tick-size + spread profile)"
```

## 4. Entry Rules

Pseudocode — verbatim from Chan's Ch 2 p. 23 narrative; structural translation where Chan leaves a parameter unspecified.

```text
PARAMETERS (Chan-defaults plus textbook-defaults for the unspecified lookback):
- N           = 20         // moving-average / std-dev lookback in BARS; Chan does NOT specify;
                          //   Bollinger (2001) textbook default = 20. P3 sweep axis.
- ENTRY_K     = 2.0        // Chan: "plus or minus 2 moving standard deviations"
- EXIT_K      = 1.0        // Chan: "within 1 moving standard deviation of the moving average"
- BAR         = M5         // Chan: "every five minutes"

EACH-BAR (M5 close):
- MA_t  = SimpleMovingAverage(Close, N) at bar t
- SD_t  = StandardDeviation(Close, N)   at bar t                // sample std (N-1 denominator)
- z_t   = (Close[t] - MA_t) / SD_t                              // z-score of current close

ENTRY (only when not in position):
- if z_t >= +ENTRY_K then OPEN_SHORT at next bar's open (or at close if continuous fill)
- if z_t <= -ENTRY_K then OPEN_LONG  at next bar's open (or at close if continuous fill)

NOTE: Chan does not specify whether the entry trigger reads "Close > MA + ENTRY_K * SD"
      vs "MAX(High) > MA + ENTRY_K * SD" within the bar. The card adopts CLOSE-based
      triggering as the conservative reading (one signal per M5 close, no intra-bar
      stop-out). Tighter intra-bar logic is a separate strategy variant.
```

## 5. Exit Rules

```text
EXIT (only when in position):
- if abs(z_t) <= EXIT_K then CLOSE position at next bar's open (or at close if continuous fill)
  // Chan p. 23 verbatim: "Exit the position when the price reverts back to within 1 moving
  // standard deviation of the moving average"

NO STOP-LOSS:
- Chan, Ch 7 p. 143 (Exit Strategy section): "a stop loss in this case [reversal model]
  often means you are exiting at the worst possible time. ... it is much more reasonable
  to exit a position recommended by a mean-reversal model based on holding period or
  profit cap than stop loss."
- Default per Chan: no native per-trade stop-loss. V5 framework's kill-switch + account
  MAX_DD trip is the catastrophic backstop.

NO TIME-STOP / NO TRAILING / NO PARTIAL CLOSE.
- The strategy holds until z reverts inside the ±EXIT_K band; if the spread expands further
  (z grows in magnitude), the position is held — Chan does not specify a max-hold.
- Friday Close: standard V5 default applies (force-flat at Friday 21:00 broker time);
  short M5 hold makes this rarely binding, but a Friday-evening trigger could leave a
  position open into the weekend gap. Card respects the default; no waiver required.
```

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults: kill-switch, news filter, MAX_DD trip
- Friday Close: ENABLED (V5 default; no waiver)
- pyramiding: NOT allowed (one open position per direction at a time)
- Optional ATR floor (P3 sweep axis): skip entries when SD_t < ATR_FLOOR_BPS · MA_t
  // Rationale: at very low realised volatility, the ±2σ band is so tight that signal-to-
  // noise collapses. Chan does not include this filter; sweep validates whether it helps.
```

## 7. Trade Management Rules

```text
- one open position per direction at any time (no pyramiding)
- position size: maps to V5 risk-mode framework at sizing-time;
  catastrophic risk handled by kill-switch since strategy has no native stop
- gridding: NOT allowed
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: lookback_n
  default: 20
  sweep_range: [10, 15, 20, 30, 50, 100]      # Chan does not specify; Bollinger textbook default = 20; sweep brackets typical retail use
- name: entry_k
  default: 2.0
  sweep_range: [1.5, 1.75, 2.0, 2.25, 2.5, 3.0]   # Chan reports 2.0; cointegration cousin (S01) sweeps 1.0-2.5; symmetric range here
- name: exit_k
  default: 1.0
  sweep_range: [0.0, 0.25, 0.5, 0.75, 1.0, 1.25]  # Chan reports 1.0; lower exit = faster turnover; 0 = fully revert to MA
- name: bar
  default: M5
  sweep_range: [M1, M5, M15, M30, H1]          # Chan reports M5; lower bars amplify cost-failure (which is the load-bearing test in this card)
- name: atr_floor_bps
  default: 0                                   # disabled by default
  sweep_range: [0, 10, 25, 50]                 # bps of MA; 0 disables filter
```

P3.5 (CSR) axis: re-run on related Darwinex single-symbol indices (`US500.DWX`, `US100.DWX` Nasdaq-100 CFD, `GER40.DWX` DAX CFD, `UK100.DWX` FTSE CFD) — does the Bollinger MR edge survive across index variants? Per Chan's broader Ch 7 narrative pp. 117 ("financial researchers ... have constructed a very simple short-term mean reversal model that is profitable (before transaction costs) over many years"), the edge generalizes to most indices.

## 9. Author Claims (verbatim, with quote marks)

ES (E-mini S&P 500 futures), M5 bars, default thresholds (entry_k = 2.0, exit_k = 1.0), lookback unspecified by Chan:

> "If you allow yourself to enter and exit every five minutes, you will find that the Sharpe ratio is about 3 without transaction costs—very excellent indeed!" (p. 23)

Same setup with 1 bp/trade transaction cost:

> "Unfortunately, the Sharpe ratio is reduced to −3 if we subtract 1 basis point as transaction costs, making it a very unprofitable strategy." (p. 23)

Reference transaction-cost levels Chan cites elsewhere on p. 22:

> "If you are trading ES, the E-mini S&P 500 futures, the transaction cost will be about 1 basis point."
>
> "If you are trading S&P 500 stocks, for example, the average transaction cost (excluding commissions, which depend on your brokerage) would be about 5 basis points (that is, five-hundredths of a percent). ... a round trip will cost 10 basis points in this example."

Anti-stop-loss disposition (Ch 7 p. 143, applied to this strategy via § 5):

> "a stop loss in this case [reversal model] often means you are exiting at the worst possible time."

## 10. Initial Risk Profile

```yaml
expected_pf: 0.7                              # Chan's framing: post-cost Sharpe ~ -3 → expected profit factor < 1 on Darwinex spreads.
                                              # Pre-cost Sharpe ~ +3 → would translate to PF > 2 on noise-free data, but P9b will apply
                                              # realistic spreads. Listed at 0.7 to reflect Chan's deliberate-failure framing; pipeline confirms.
expected_dd_pct: 25                           # rough estimate; Chan does not publish DD numbers
expected_trade_frequency: 50-200/day          # at M5 with ±2σ trigger, expected 50-200 entries per session per index
risk_class: high                              # high-frequency churn under realistic spreads = expected to be unprofitable; THIS IS THE LOAD-BEARING TEST
gridding: false
scalping: true                                # M5 with ~1-3 bar holds = scalping per strategy_type_flags.md § E definition
ml_required: false                            # classical SMA + sample std + threshold logic
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical (SMA + sample-std + threshold-crossing is fully deterministic)
- [x] No Machine Learning required (classical statistics, no fitted parameters at run-time except the rolling MA + std)
- [x] If gridding: not applicable (one open position per direction)
- [ ] **If scalping: P5b stress with realistic VPS latency calibration MUST be planned.** This card formally raises this gate; per V5 framework `scalping` is allowed but mandates P5b. Card is Darwinex-friendly until P5b confirms latency-realistic Sharpe.
- [x] Friday Close compatibility: M5-with-quick-revert holds rarely cross Friday 21:00 broker time; V5 default Friday-close applies cleanly. No waiver required.
- [x] Source citation is precise enough to reproduce (chapter + section + page + verbatim quotes; Bollinger 2001 supplement for the lookback default)
- [x] No near-duplicate of existing approved card (`strategy-seeds/cards/index.md`: only Davey-family + grimes-pullback + chan-pairs-stat-arb as of 2026-04-27)

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "standard V5 default (kill-switch, news filter, MAX_DD trip, Friday-close). Optional ATR floor on the σ value (sweep axis); off by default."
  trade_entry:
    used: true
    notes: "z-score crossing ±ENTRY_K on the close of M5 bars; one signal per direction at a time"
  trade_management:
    used: false
    notes: "no trailing, no break-even, no partial close, no pyramiding"
  trade_close:
    used: true
    notes: "z-score reversion inside ±EXIT_K band; no time-stop, no native stop-loss"
```

```yaml
hard_rules_at_risk:
  - scalping_p5b_latency                      # PRIMARY — M5 with ~1-3 bar average hold qualifies as scalping per strategy_type_flags.md § E. P5b VPS-realistic latency calibration is mandatory before this card can advance past P5.
  - dwx_suffix_discipline                     # Chan's universe is ES (CME futures); V5 deploys on Darwinex .DWX symbols. Candidate map: US500.DWX. CTO confirms tick-size + spread profile at G0; CSR (P3.5) tests on US100.DWX, GER40.DWX, UK100.DWX as variant axes.
  - kill_switch_coverage                      # no native stop-loss (Chan's anti-stop-loss disposition Ch 7 p. 143 applies). Catastrophic backstop relies entirely on V5's QM_KillSwitch and account-level MAX_DD trip. CTO sanity-checks kill-switch sizing for an M5 churn-style strategy at P5.
  - enhancement_doctrine                      # load-bearing on the unspecified lookback parameter N (Chan provides no value; card defaults to Bollinger textbook 20). Any post-PASS retune of N counts as an enhancement_doctrine event.
  - news_pause_default                        # at high-impact-news windows, σ inflates and the ±2σ band widens, but the strategy still fires on noise spikes inside the inflated band. Standard V5 P8 news-blackout applies; Chan does not address this explicitly.

at_risk_explanation: |
  scalping_p5b_latency — load-bearing. M5 with ~1-3 bar holds + 50-200 entries/day per index
  + 1 bp transaction-cost sensitivity makes this a textbook P5b candidate. Per V5 framework, the
  card cannot advance past P5 without P5b VPS-realistic latency calibration confirming the post-
  latency Sharpe profile. Chan's own framing already predicts a negative-Sharpe outcome under
  realistic costs — P5b should make that prediction concrete.

  dwx_suffix_discipline — ES (CME) maps to US500.DWX. Tick-size, contract-size, and spread
  profile differ; CTO confirms the mapping at G0 and CSR runs P3.5 on related Darwinex CFD
  indices to validate generalization.

  kill_switch_coverage — no native stop-loss. V5 account-level kill-switch is the catastrophic
  backstop. CTO sanity-checks at P5 that kill-switch sizing covers the worst-case "σ explodes
  and the ±2σ band breaches without reversion" scenario (e.g., 2010 Flash Crash, 2020 COVID
  crash on intraday timeframes).

  enhancement_doctrine — Chan does not specify the lookback N. Bollinger 2001 textbook default
  of 20 is adopted as initial value; P3 sweeps [10, 15, 20, 30, 50, 100]. Once a live N is fixed
  at deployment, any subsequent retune is enhancement.

  news_pause_default — V5 P8 news-blackout applies at high-impact macro events. Chan does not
  address this; standard framework gating handles it.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                               # standard V5 default; optional ATR floor as sweep axis
  entry: TBD                                  # SMA + sample-std + threshold-crossing on M5 close — straightforward MQL5 implementation
  management: TBD                             # n/a (no trailing / BE / partial)
  close: TBD                                  # z-score reversion inside ±EXIT_K band
estimated_complexity: small                   # textbook Bollinger band MR; ~50-100 LOC in MQL5
estimated_test_runtime: 4-8h                  # P3 sweep (6×6×6×5×4 = 4,320 cells) over 5+ years of M5 data per index = bigger sweep than typical D1 cards
data_requirements: standard                   # M5 OHLC on Darwinex .DWX index symbols; no external feeds
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
- 2026-04-27: SRC02_S02 surfaces a THIRD `strategy_type_flags` controlled-vocabulary GAP (entry side):
  `zscore-band-reversion` — entry mechanism: a single-leg price (or log-return) crosses ±N·σ
  band of its own moving statistics. Distinct from `cointegration-pair-trade` (S01 proposed flag,
  TWO-leg spread instead of single-leg) and from `n-period-min-reversion` (uses N-bar MIN rather
  than MA + Nσ). V4 had no Bollinger-band SM_XXX EAs per `strategy_type_flags.md` Mining-provenance
  table. Chan citation: Ch 2 pp. 22-23 (this card's primary source) + Ch 7 pp. 117 ("financial
  researchers ... very simple short-term mean reversal model that is profitable").
  Combined with S01's `cointegration-pair-trade` and `mean-reach-exit` proposals, the count of
  SRC02-surfaced vocabulary gaps is now THREE. Research will batch-propose all three to CEO + CTO
  via the addition-process documented at the bottom of `strategy_type_flags.md` once the SRC02
  extraction pass surfaces a stable set (next 2-3 heartbeats).

- 2026-04-27: This card is Chan's deliberate FAILURE EXAMPLE for the transaction-cost effect
  (Ch 2 pp. 22-23). Pre-cost Sharpe +3 collapses to post-cost Sharpe −3 at 1 bp/trade. Card is
  drafted per Rule 1; expected to fail at P9b Operational Readiness once realistic Darwinex
  spreads are applied. Pipeline G0 / P2 / P3 may pass on noise-free data; P9b is the genuine
  gate. This mirrors SRC01 S04 davey-es-breakout (Davey Ch 13 walk-forward FAILURE example,
  -$9,938 cumulative OOS) — both are explicit "this strategy doesn't work, but here's what it
  teaches us" demonstrations from the source author. Cross-walk note for completion_report.md:
  Chan and Davey both use deliberate-failure examples to illustrate methodology gates; V5 P9b
  is structurally aligned with this pedagogy.

- 2026-04-27: Lookback period N is Chan-unspecified. Defaulted to Bollinger 2001 textbook value
  of 20 bars (cited as `role: supplement` in § 1). P3 sweeps [10, 15, 20, 30, 50, 100]. Any
  post-PASS retune of N is an `enhancement_doctrine` event, NOT a fresh strategy.

- 2026-04-27: Friday-close compatibility is GOOD (unlike S01 chan-pairs-stat-arb which requires
  a Hard Rule waiver). M5 holds with quick reversion rarely cross weekly forced-flat. The
  per-card friday_close risk profile is the natural disambiguation between "intraday MR" and
  "multi-day cointegration MR" — both Chan-family strategies, but with materially different V5
  framework-fit profiles.
```
