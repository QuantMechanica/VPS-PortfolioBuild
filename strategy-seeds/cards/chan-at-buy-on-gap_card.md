# Strategy Card — Chan AT Cross-Sectional Buy-on-Gap MR on SPX Stocks (top-N most-negative gap-down screen + 20-day MA filter, open-to-close hold)

> Drafted by Research Agent on 2026-04-28 from `strategy-seeds/sources/SRC05/raw/ch4_5_pp87-132.txt` lines 1074-1162 (Ex 4.1 verbatim MATLAB + 6-year SPX performance + Chan's commentary on long-only nature, capacity, and short mirror).
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per QUA-188 waiver v3).

## Card Header

```yaml
strategy_id: SRC05_S03
ea_id: TBD
slug: chan-at-buy-on-gap
status: DRAFT
created: 2026-04-28
created_by: Research
last_updated: 2026-04-28

strategy_type_flags:
  - cross-sectional-decile-sort                 # existing (extended): universe = SPX stocks; ranking_metric = prior-low-to-open-gap-return-most-negative; weighting_scheme = top-N-screen (long-only top-N most-extreme-negative-gap names, NOT decile-rank long-short). Sibling extension to the same flag — parameterizes the existing flag for the top-N-screen specialization (same architecture: universe ranking + relative selection; different selection rule). Vocab note in §16 below.
  - trend-filter-ma                              # existing — Chan's "Rule 2": today.open must be > 20-day-MA-of-close (lagged 1 bar) for the long; this is a regime overlay (no buy if stock is already in downtrend below its MA)
  - time-stop                                    # exit mechanism: liquidate at session close on the same bar; open-to-close hold (≤ 1 day duration)
  - symmetric-long-short                         # short-mirror also profitable per Chan p. 95: APR 46%, Sharpe 1.27 over the same period (gap-up + below-MA → SHORT at open)
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Chan, Ernest P. (2013). Algorithmic Trading: Winning Strategies and Their Rationale. Wiley Trading. Hoboken, NJ: John Wiley & Sons. ISBN 978-1-118-46014-6 (cloth) / 978-1-118-46019-1 (ebk)."
    location: "Chapter 4 'Mean Reversion of Stocks and ETFs', § 'A Mean-Reverting Strategy on Stocks: Buy-on-Gap Model on SPX Stocks' (PDF pp. 93-96 / printed pp. 93-96). Example 4.1 'Buy-on-Gap Model on SPX Stocks' (PDF p. 94 / printed p. 94) is the primary case with full MATLAB code (download = bog.m), 6-year SPX-universe performance, and Chan's discussion of the short-mirror, long-only-risk caveat, and capacity limitation."
    quality_tier: A
    role: primary
```

Raw evidence: `strategy-seeds/sources/SRC05/raw/ch4_5_pp87-132.txt` lines 1074-1162 (extracted via `pdftotext -layout` 2026-04-28). Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Algorithmic Trading_ Winning St - Ernie Chan.pdf`.

## 2. Concept

A **cross-sectional intraday gap-fade strategy** on the SPX universe: each session at the open, screen all SPX stocks for ones that gap DOWN below their prior-bar-low by at least 1·σ of their 90-day close-to-close stdev AND are still trading above their 20-day MA, then BUY the top-N most-negative-gap names at the open and liquidate them at the close. The trade thesis is that a gap-DOWN below the prior-bar-low in an otherwise-still-uptrending name (above 20-day MA) is over-extended and likely to mean-revert intraday. From Ch 4 § "A Mean-Reverting Strategy on Stocks: Buy-on-Gap Model" — the strategy intuition (paraphrased; verbatim MATLAB below):

The complete source rule, **verbatim** from Ex 4.1 MATLAB (p. 94):

```matlab
topN=10; % Max number of positions
entryZscore=1;
lookback=20; % for MA

stdretC2C90d=backshift(1, smartMovingStd(calculateReturns(cl, 1), 90));
buyPrice=backshift(1, lo).*(1-entryZscore*stdretC2C90d);
retGap=op-backshift(1, lo))./backshift(1, lo);
pnl=zeros(length(tday), 1);
positionTable=zeros(size(cl));
ma=backshift(1, smartMovingAvg(cl, lookback));

for t=2:size(cl, 1)
    hasData=find(isfinite(retGap(t, :)) & op(t, :) < buyPrice(t, :) & op(t, :) > ma(t, :));
    [foo idxSort]=sort(retGap(t, hasData), 'ascend');
    positionTable(t, hasData(idxSort(1:min(topN, length(idxSort)))))=1;
end

retO2C=(cl-op)./op;
pnl=smartsum(positionTable.*(retO2C), 2);
ret=pnl/topN;
ret(isnan(ret))=0;
```

The two-condition cross-sectional screen at each session open is:

1. **Gap-down trigger:** `today.open < prev_bar.low * (1 - 1.0 * 90d_stdret)` — the open price gaps below prior-bar-low by at least 1σ (where σ = 90-day close-to-close stdev of returns)
2. **Trend filter (Rule 2):** `today.open > prev_bar.20-day-MA` — the stock is still in uptrend (above its lagged 20-day moving average)

Names passing BOTH conditions are sorted by `retGap(t,:) = (today.open - prev_bar.low) / prev_bar.low` *ascending* — the most-negative gap-down (deepest gap) is selected first. Top-10 (`topN=10`) names are bought at the open and liquidated at the close. PnL accounts the open-to-close return `(cl - op) / op` for each held name, divided by `topN` for capital normalization.

Chan's commentary on the long-only-side asymmetry (p. 95):

> "I have traded a version of it quite profitably in my personal account as well as in a fund that I comanaged. Unfortunately, that version does not include rule 2, and it suffered from diminishing returns from 2009 onward. The long-only nature of the strategy also presents some risk management challenges. Finally, the number of stocks traded each day is quite small, which means that the strategy does not have a large capacity." (p. 95)

Chan's comment on the short-mirror (p. 95):

> "What about the mirror image of this strategy? Can we short stocks that gap up a standard deviation but are still lower than their 20-day moving average? Yes, we can. The APR is 46 percent and the Sharpe ratio is 1.27 over the same period. Despite the seemingly higher return than the long-only strategy, the short-only one does have steeper drawdown (see Figure 4.2), and it suffered from the same short-sale constraint pitfall discussed before." (p. 95)

Chan's commentary on the **opening-price implementation pitfall** (p. 95) — relevant to V5 P1 build validation:

> "The astute reader may wonder how we can use open prices to determine the trading signals for entry at the open and be filled at the official open prices. The short answer is, of course: We can't! We can, however, use the preopen prices (for example, at ARCA) to determine the trading signals. The signals thus determined will not exactly match the ones determined by the actual open prices, but the hope is that the difference will not be so large as to wipe out the returns. We can call this difference signal noise. Also, note the pitfall of backtesting this strategy using consolidated prices versus primary exchange prices, as explained in Chapter 1." (p. 95)

Chan's broader thesis (p. 96):

> "the important message is: Price series that do not exhibit mean reversion when sampled with daily bars can exhibit strong mean reversion during specific periods. This is seasonality at work at a short time scale." (p. 96)

## 3. Markets & Timeframes

```yaml
markets:
  - stocks                                      # SPX universe (~500 stocks; survivorship-biased per Chan p. 94)
  # V5 Darwinex re-mapping: Darwinex universe is heavily forex / index-CFD / commodity-CFD oriented, with limited single-name US-stock-CFD coverage. Chan's SPX-universe deployment maps approximately to:
  #   - US500.DWX (broad-market index proxy) — but a single-symbol index removes the cross-sectional ranking dimension that is the load-bearing edge
  #   - subset of liquid US-listed-CFD names (AAPL.DWX, MSFT.DWX, etc., if Darwinex universe expands to include them)
  #   - V5-architecture-CHALLENGED: same status as SRC02 chan-khandani-lo-mr / chan-pca-factor — the strategy requires a cross-sectional N-symbol portfolio framework, not the V5 default single-symbol-or-pair magic schema.
timeframes:
  - D1                                          # daily-bar entries on session open, exits on session close
session_window: open-to-close                   # exchange-session-open ENTRY → exchange-session-close EXIT
primary_target_symbols:
  - "SPX universe (Chan's source case): all S&P 500 stocks; daily open / high / low / close; T × N arrays where T = days, N = stocks"
  - "V5 Darwinex mapping: TBD — V5-architecture-CHALLENGED (cross-sectional universe). Candidate paths: (a) full single-name US-stock-CFD universe if/when Darwinex expands; (b) substitute SPX with liquid sector-ETF universe (XLK.DWX, XLF.DWX, etc.) on a smaller N; (c) defer until V5 portfolio-of-N-symbols framework lands. Current path: card drafted regardless per DL-033 Rule 1; V5-architecture-fit blocking is a downstream concern at G0/P1."
```

## 4. Entry Rules

```text
- on each new daily bar's session open, for EACH stock s in the universe:
    let stdretC2C90d_s = stdev_of_close_to_close_returns(close[s], lookback=90, shifted_back_1_bar)
    let buyPrice_s = prev_bar[s].low * (1 - entryZscore * stdretC2C90d_s)
    let retGap_s   = (today[s].open - prev_bar[s].low) / prev_bar[s].low
    let ma_s       = sma(close[s], lookback=20, shifted_back_1_bar)
    if isfinite(retGap_s) AND today[s].open < buyPrice_s AND today[s].open > ma_s:
        s passes the screen with gap_score = retGap_s

- after iterating all symbols on bar t, sort the passing-screen set by retGap_s ASCENDING (most-negative-gap first)
- BUY at market on open the top-N=10 most-negative-gap names (or fewer, if < 10 names pass screen)
- equal capital allocation per held name = (total_strategy_capital) / topN
- entryZscore = 1.0 (Chan's source default; §8 sweeps higher / lower)
- 90d stdret = close-to-close stdev of arithmetic returns over 90 prior bars, lagged 1 bar to avoid look-ahead
- 20d MA = simple moving average of close over 20 prior bars, lagged 1 bar
- prev_bar.low = the prior session's actual low (lagged 1 bar)
- not in news blackout window per QM_NewsFilter (V5 framework default)
- not in framework Friday-Close window per V5 framework default
```

## 5. Exit Rules

```text
- exit at session close on the same bar (today's close), regardless of intraday excursion direction
- pnl per held name = (today[s].close - today[s].open) / today[s].open
- divide by topN for capital normalization
- no SL or TP referenced in the source; intraday excursion is not gated → time-stop = session close is the only exit
- no trailing stop in source rule (positions held flat-through to close)
- Friday Close enforced (default per V5 framework — no Fri exchange-close → Mon exchange-open weekend hold; intraday lifecycle is naturally Friday-Close-compatible)
- explicit MQL5 V5 mapping: optional `QM_StopRules.QM_StopAbsolute(stop_loss_price = some-multiple-of-90d-stdret-as-disaster-stop)` to bound runaway intraday-news outliers; documented as enhancement-doctrine candidate, not in source rule
```

## 6. Filters (No-Trade module)

```text
- "Rule 2" 20-day MA filter: today.open must be > 20-day-MA-of-close (lagged 1 bar). Chan p. 95 documents that excluding Rule 2 caused diminishing returns from 2009 onward.
- entryZscore=1.0 σ-threshold on the gap-down (vs gap-down magnitude / 90d_stdret) — small gaps don't qualify
- isfinite(retGap_s) — exclude names with missing prior-bar-low or missing today-open data
- topN=10 — even if 50 names pass the screen, only the 10 most-extreme-negative-gap names are traded; this caps capital concentration but also bounds capacity
- V5 framework defaults (kill-switch + news-pause + Friday Close) apply
- (V5 enhancement candidate, NOT in source rule) — survivorship-bias correction: Chan p. 94 explicitly flags "but one that has survivorship bias" — V5 P5/P5c stress should include a survivorship-corrected universe re-test
- (V5 enhancement candidate, NOT in source rule) — primary-vs-consolidated open-price discipline (Chan p. 95): use ARCA preopen for signal computation, primary-exchange open for fill modeling
```

## 7. Trade Management Rules

```text
- one position per stock per session (default V5 one-position-per-magic-symbol); the cross-sectional architecture means topN simultaneous positions across topN distinct symbol-magic-slots
- pyramiding: NOT allowed (default V5 one-position-per-magic-symbol)
- gridding: NOT allowed (default V5)
- no break-even-move during the intraday hold (source rule is hold-flat-through-close)
- no partial close at intraday level (source rule is single-leg open-to-close)
- equal capital allocation across the held topN names; no within-name pyramiding
- the position carries a single direction (long-only in primary form; symmetric-short-mirror in alt form per §9 Author Claims) set at session open and is closed at session close — no intraday flips
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: entryZscore
  default: 1.0
  sweep_range: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
  notes: "Chan's source default = 1.0 (gap of at least 1·σ below prior bar low). Higher values produce fewer but more-extreme triggers; lower values trade more days but with weaker selection."
- name: vol_lookback
  default: 90
  sweep_range: [30, 60, 90, 120, 250]
  notes: "Chan uses 90-day close-to-close stdev of returns, lagged 1 bar."
- name: ma_lookback
  default: 20
  sweep_range: [10, 15, 20, 30, 50, 100]
  notes: "Chan's 'Rule 2' is 20-day MA filter. Removing this filter (Rule 2 OFF) is documented to cause diminishing returns from 2009 (Chan p. 95) — keep filter ON in baseline; ablation as separate sweep dimension."
- name: topN
  default: 10
  sweep_range: [5, 10, 15, 20, 30]
  notes: "Chan's source default = 10. Higher topN dilutes the most-extreme-gap selection edge; lower topN concentrates risk."
- name: direction_mode
  default: "long-only"
  sweep_range: ["long-only", "short-only", "symmetric-long-short"]
  notes: "Chan p. 95 documents short-mirror APR 46% / Sharpe 1.27 (vs long-only APR 8.7% / Sharpe 1.5) over the same period — the short side has steeper DD. Symmetric long-short is a CTO-discretion variant at G0."
- name: include_rule_2_ma_filter
  default: true
  sweep_range: [true, false]
  notes: "Ablation: turn off Rule 2 to validate Chan's p. 95 claim of post-2009 diminishing returns without it."
```

Conditional / V5-architecture-pending parameters (CTO + CEO discretion at G0):

```yaml
- name: universe_size
  default: "SPX (~500)"
  sweep_range: ["SPX (~500, survivorship-biased)", "SPX (~500, survivorship-corrected)", "Darwinex single-name CFD universe (TBD size)", "Sector-ETF universe (~10 XLK/XLF/etc.)"]
  notes: "V5-architecture-CHALLENGED (cross-sectional universe). Initial baseline likely runs on a sector-ETF subset until full single-name CFD universe lands. CTO confirms at G0."
- name: open_price_signal_source
  default: "primary-exchange open"
  sweep_range: ["primary-exchange open", "ARCA preopen indication"]
  notes: "Chan p. 95: signals use preopen ARCA prices, fills use primary-exchange opens; V5 may approximate via Darwinex tick-data start-of-bar."
```

## 9. Author Claims (verbatim, with quote marks)

```text
"This strategy has an annual percentage rate (APR) of 8.7 percent and a Sharpe ratio of 1.5 from May 11, 2006, to April 24, 2012." (p. 94)

"What about the mirror image of this strategy? Can we short stocks that gap up a standard deviation but are still lower than their 20-day moving average? Yes, we can. The APR is 46 percent and the Sharpe ratio is 1.27 over the same period. Despite the seemingly higher return than the long-only strategy, the short-only one does have steeper drawdown (see Figure 4.2), and it suffered from the same short-sale constraint pitfall discussed before." (p. 95)

"I have traded a version of it quite profitably in my personal account as well as in a fund that I comanaged. Unfortunately, that version does not include rule 2, and it suffered from diminishing returns from 2009 onward. The long-only nature of the strategy also presents some risk management challenges. Finally, the number of stocks traded each day is quite small, which means that the strategy does not have a large capacity." (p. 95)

"The astute reader may wonder how we can use open prices to determine the trading signals for entry at the open and be filled at the official open prices. The short answer is, of course: We can't! We can, however, use the preopen prices (for example, at ARCA) to determine the trading signals. The signals thus determined will not exactly match the ones determined by the actual open prices, but the hope is that the difference will not be so large as to wipe out the returns. We can call this difference signal noise. Also, note the pitfall of backtesting this strategy using consolidated prices versus primary exchange prices, as explained in Chapter 1." (p. 95)

"the important message is: Price series that do not exhibit mean reversion when sampled with daily bars can exhibit strong mean reversion during specific periods. This is seasonality at work at a short time scale." (p. 96)

"This strategy is actually quite well known among traders, and there are many variations on the same theme. For example, you can obviously trade both the long-only and short-only versions simultaneously. Or you can trade a hedged version that is long stocks but short stock index futures. You can buy a larger number of stocks, but restricting the number of stocks within the same sector. You can extend the buying period beyond the market open. You can impose intraday profit caps." (p. 95-96)
```

## 10. Initial Risk Profile

```yaml
expected_pf: 1.5                              # Sharpe 1.5 → rough PF ≈ 1.5-1.7 for daily intraday cross-sectional MR strategy
expected_dd_pct: 12                           # rough estimate from 6-year Sharpe-1.5 daily intraday MR; long-only side typical 10-15% MaxDD; short-mirror is steeper per Chan p. 95
expected_trade_frequency: 250/year_per_topN_slot  # ~252 sessions × ~80% pass-screen-rate per topN slot ≈ 200/year × 10 slots = 2000 stock-trades/year (≈ 250 per slot)
risk_class: medium                            # cross-sectional MR on SPX-class universe; no scalping; long-only by default with optional short-mirror; long-only has cited capacity limits per Chan
gridding: false
scalping: false
ml_required: false
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical — full MATLAB rule, fully discretionary-judgment-free
- [x] No Machine Learning required — pure rule-based screen + sort + select
- [x] Friday Close compatibility — strategy is intraday open-to-close, fully compatible
- [x] Source citation precise — Chan AT (2013), Ch 4 Ex 4.1, PDF p. 94
- [ ] No near-duplicate of existing approved card — **NEAR-DUPLICATE-CHECK**: SRC02 `chan-khandani-lo-mr` (SRC02_S03) is a cross-sectional daily MR but on prior-day-return-deviation-from-market-mean as the ranking metric (continuous-distance weighting), NOT prior-low-to-open-gap-magnitude (top-N-screen weighting). Different ranking metric + different gap-mechanic → DISTINCT card. Disambiguation also vs `chan-january-effect` (calendar-annual cycle, not daily intraday) and `chan-yoy-same-month` (year-ago-same-month cycle, not daily intraday). DISTINCT confirmed.
- [x] No gridding, no scalping, no ML
- [x] V5-architecture-CHALLENGED status acknowledged — same as SRC02_S03 chan-khandani-lo-mr; pipeline G0 review may defer P1 build until V5 cross-sectional framework lands

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "framework defaults (kill-switch + news-pause + Friday-Close) plus the strategy-internal Rule 2 (20-day MA filter) as a regime overlay; named-stock survivorship-bias caveat per Chan p. 94 documented as a P5c stress-test variant"
  trade_entry:
    used: true
    notes: "Strategy_EntrySignal: at session open, for each symbol s, screen on (today[s].open < prev_bar[s].low * (1 - 1.0·90d_stdret)) AND (today[s].open > 20d_MA_close[s]); sort passing symbols by retGap ASCENDING (most-negative-gap first); BUY topN=10 at market on open"
  trade_management:
    used: false
    notes: "no break-even / trail / partial-close in source rule; positions are single-leg open-to-close per held name"
  trade_close:
    used: true
    notes: "Strategy_ExitSignal: time-stop at session close for each held name; exit signal is purely time-based, not price-based; cross-sectional rebalance reuses the same close-bar"
```

```yaml
hard_rules_at_risk:
  - dwx_suffix_discipline                     # Chan source universe is SPX (~500 US stocks); V5 deployment requires Darwinex single-name CFD universe (currently limited) or substitute (sector-ETF universe / forex-cross-sectional universe). Cross-sectional architecture is V5-default-incompatible at the magic_schema level.
  - magic_schema                              # cross-sectional N-symbol portfolio architecture conflicts with V5 default ea_id*10000+symbol_slot — same architectural-pending status as SRC02 chan-khandani-lo-mr / chan-pca-factor / chan-january-effect / chan-yoy-same-month. Card is drafted regardless per Rule 1; V5 magic-schema treatment is downstream P1/CTO concern.
  - one_position_per_magic_symbol             # topN=10 simultaneous positions across topN distinct symbol-magic-slots is per-symbol single-position (compliant), but across-symbols-aggregate is N-positions which is the cross-sectional treatment; CTO confirms at G0 whether existing magic-schema covers this or whether a per-strategy-magic-prefix extension is needed
at_risk_explanation: |
  dwx_suffix_discipline: SPX-universe → Darwinex spot-CFD universe is a non-trivial substitution.
  Chan p. 94 explicitly notes the universe was 'one that has survivorship bias' — survivorship is a
  separate concern. Even on a survivorship-corrected SPX, the Darwinex universe lacks broad single-
  name US-stock CFDs (currently). Substitute paths: (a) full Darwinex single-name CFD universe if/
  when expanded; (b) sector-ETF universe (XLK.DWX, XLF.DWX, XLE.DWX, etc.) on smaller N; (c) defer
  to V5 portfolio-of-N-symbols framework. CTO selects path at G0.

  magic_schema: Cross-sectional architecture requires either (i) an N-symbol multi-magic-slot
  framework with shared signal-computation upstream, or (ii) a single-magic-EA that internally
  manages N symbols through a custom symbol-iteration loop, treating each symbol-position as a
  separate trade with a per-symbol-suffixed magic ID. SRC02 chan-khandani-lo-mr / chan-pca-factor
  hit the same architectural decision; whichever path V5 picks for SRC02 propagates here. Strategy-
  Card-level note: same V5-architecture-CHALLENGED status; pipeline G0/P1 review may defer build
  until SRC02 cross-sectional cards land first.

  one_position_per_magic_symbol: per-symbol the strategy holds ONE position at a time (compliant);
  across-symbols-aggregate it holds topN=10 simultaneous positions (cross-sectional architecture).
  CTO confirms whether the V5 magic-schema covers this through the existing slot-allocation or
  whether a per-strategy-magic-prefix extension (e.g., ea_id*100000 + symbol_slot*100 + position_index)
  is needed. Same status as SRC02 chan-khandani-lo-mr.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                               # 20-day MA filter implementation; survivorship-corrected universe selection at strategy-init
  entry: TBD                                  # cross-sectional iteration over universe; topN selection; per-symbol-magic-slot allocation
  management: TBD
  close: TBD                                  # time-stop at session close per held name
estimated_complexity: medium                  # cross-sectional architecture is non-default for V5; single-symbol cards are small
estimated_test_runtime: TBD                   # cross-sectional sweep is O(N_universe × N_param_combos × N_bars) — substantially larger than single-symbol
data_requirements: standard                   # SPX-style daily OHLC × N stocks; Darwinex-native equivalents; survivorship-bias correction is enhancement (P5c)
```

## 14. Pipeline History (per `_v<n>` rebuild)

| version | date | rebuild reason | P-stage reached | verdict |
|---|---|---|---|---|
| _v1 | 2026-04-28 | initial build (h3 SRC05 batch) | TBD | TBD |

## 15. Pipeline Phase Status (current `_v<n>`)

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-04-28 | DRAFT | this card |
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
- 2026-04-28: VOCAB extension — `cross-sectional-decile-sort` is reused with weighting_scheme=top-N-screen and ranking_metric=prior-low-to-open-gap-return rather than introducing a new flag. Pattern: existing cross-sectional flag accommodates discrete-decile (chan-january-effect / chan-yoy-same-month), continuous-distance (chan-khandani-lo-mr), pca-rank-decile (chan-pca-factor), and now top-N-screen (this card). Sibling parameterization keeps the flag count small while preserving the architectural commonality (universe ranking + relative selection). NO new flag proposed for SRC05 closeout from this card; if subsequent SRCs introduce a different flavor (e.g., factor-tilt-screen), Research will revisit.
- 2026-04-28: This card's gap-DOWN→BUY (FADE) direction is the OPPOSITE of `gap-fade-stop-entry` (which is calendar-pattern + gap-through stop-entry placed BACK at a prior price) and the OPPOSITE of S12 `chan-at-fstx-gap-mom` (`opening-gap-momentum` go-with). Together S03 + S12 form a clean gap-FADE / gap-MOMENTUM pair on cross-sectional-stocks vs single-symbol-futures-or-currencies — the V5 controlled vocabulary captures the architectural difference (cross-sectional-decile-sort vs opening-gap-momentum) and the direction differences via per-card flags + parameters.
- 2026-04-28: The short-mirror APR 46% / Sharpe 1.27 (vs long-only 8.7% / 1.5) reported by Chan p. 95 is a meaningful asymmetry. Chan acknowledges short-side has steeper DD; this is a P5c crisis-slice testing target (2008-09 crisis, where short-only stocks were limited by short-sale-constraint per Chan).
- 2026-04-28: Chan's p. 95 commentary on opening-price implementation (preopen ARCA signals vs primary-exchange-open fills) is a P1 build-validation note: the EA must be careful not to introduce look-ahead bias by computing the signal on the same bar as the fill. V5 `model4_every_real_tick` discipline addresses this in principle — CTO confirms at G0 whether the start-of-bar tick handling treats open-price-known-at-tick correctly or requires preopen-tick approximation.
- 2026-04-28: Survivorship-bias caveat per Chan p. 94 ("but one that has survivorship bias") is a P5c stress-test variant. V5 framework default does not auto-correct for survivorship; if survivorship-corrected re-test is required, that's a Strategy-Card-level extension flag.
```
