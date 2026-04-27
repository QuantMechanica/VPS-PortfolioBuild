---
source_id: SRC01
parent_issue: QUA-191
authored_by: Research Agent
authored_on: 2026-04-27
status: drafted_pending_ceo_review
budget_summary:
  heartbeats_used: 7                          # scaffolding (1) + App B (1) + App C (1) + App A Strategy 1 (1) + Ch 13 sweep (1) + Ch 3 sweep + remaining-chapter sweep (1) + completion report (1)
  cards_drafted: 5
  cards_passed_g0: 0                          # all DRAFT; awaiting CEO + Quality-Business review
  cards_killed_pre_p1: 0
  yield_ratio_cards_per_heartbeat: 0.71       # 5 / 7 — recompute when G0 ratification lands
---

# SRC01 Completion Report — Davey, *Building Algorithmic Trading Systems*

This report closes out SRC01 per `processes/13-strategy-research.md` § "Per-step responsibilities" Step 5 and § "Exits" (parent close → completion_report.md). All chapters and appendices of the source have been surveyed; five Strategy Cards drafted under V5 schema; one strategy (App A Strategy 1's three monkey-test variants) deferred pending CEO Q1 ratification on Rule-1 strict-vs-intent reading; one strategy (Ch 1 hogs triple-MA) skipped as underspecified-beyond-cardable.

**SRC01 status from Research's side: extraction complete. Awaiting CEO action on (1) the five DRAFT cards (G0 review), (2) the Q1 ruling on App A Strategies 2/3/4, (3) opening SRC02 per QUA-188 waiver v3.**

## 1. Source identity (recap)

```yaml
source_citations:
  - type: book
    citation: "Davey, Kevin J. (2014). Building Algorithmic Trading Systems: A Trader's Journey from Data Mining to Monte Carlo Simulation to Live Trading. Wiley Trading. ISBN 978-1-118-77898-2 (pbk.); ISBN 978-1-118-77891-3 (PDF). Hoboken, NJ: John Wiley & Sons."
    location: full book (25 chapters + 3 appendices, 263 pages)
    quality_tier: A
    role: primary
```

Source-text on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Building Winning Algorithmic Tr - Kevin J. Davey.pdf` (6.3 MB; `pdftotext -layout` extraction-method verified working).

## 2. Strategy harvest

Five strategy cards drafted; full set summarized in the table below. All five carry `status: DRAFT` and are awaiting CEO + Quality-Business G0 review.

| Slot | Card slug | Source location | Strategy character | Author-claim type | Primary `hard_rules_at_risk` |
|---|---|---|---|---|---|
| S01 | `davey-eu-night` | App B pp. 255-258 + Ch 15/18/19 | Mean-reversion overnight on Euro futures (105-min bars; ATR-band limit entries; TR-multiple profit target) | Monte Carlo simulation (25% DD / 52% return / 2.0 R/D from $6,250 start) | `dwx_suffix_discipline`, `friday_close`, `darwinex_native_data_only`, `news_pause_default` |
| S02 | `davey-eu-day` | App C pp. 259-261 + Ch 15/18/19 + Ch 7 | Intraday momentum-gated mean-reversion on Euro futures (60-min bars; xb-bar-extreme + close-vs-close[xb2] gate; $5k effectively-unreachable profit target) | Monte Carlo simulation (23.7% DD / 129% return / 5.45 R/D from $6,250 start) | `dwx_suffix_discipline`, `darwinex_native_data_only`, `news_pause_default` (heavy US-data calendar in window), `kill_switch_coverage`, `enhancement_doctrine` |
| S03 | `davey-baseline-3bar` | App A Strategy 1 pp. 247-249 + Ch 12 | 3-bar mean-reversion + ATR/cap stop, instrument-agnostic baseline (no bar-size or instrument specified) | None — Davey provides no quantified claims; framing is "monkey-test baseline" | `friday_close`, `dwx_suffix_discipline`, `darwinex_native_data_only`, `kill_switch_coverage` (no native time exit) |
| S04 | `davey-es-breakout` | Ch 13 pp. 117-121 + Table 13.1 | Countertrend "breakout" on mini S&P (ES) daily; SHORT on X-day high close, LONG on Y-day low close, fixed dollar stop | Real backtest — Davey explicitly demonstrates as a walk-forward FAILURE example (-$9,938 cumulative OOS 2005-2010) | `friday_close`, `dwx_suffix_discipline`, `darwinex_native_data_only`, `enhancement_doctrine` (highest parameter drift in set) |
| S05 | `davey-worldcup` | Ch 3 pp. 23-31 + Figs 3.1/3.2/3.4 | Trend-following 48-bar close-breakout + 30-bar RSI gate + 3-layer stop + wait rules on 9-instrument futures basket | Real World Cup contest performance — 148%/107%/112% returns with 42%/40%/50% DDs in 2005/2006/2007 (2nd/1st/2nd place) | **`risk_mode_dual` (PRIMARY)** — Davey's contest leverage non-replicable; plus standard set |

**Total: 5 cards, 5 distinct mechanical structures, 5 distinct evidence types.** Reasonable harvest density given Davey's methodology-heavy book.

### Strategy-type-flag distribution (across the 5 drafted cards)

| Flag | S01 | S02 | S03 | S04 | S05 | Count |
|---|---|---|---|---|---|---|
| mean-reversion | ✓ | ✓ | ✓ | ✓ | | 4 |
| intraday | ✓ | ✓ | | | | 2 |
| momentum | | ✓ | | | ✓ | 2 |
| breakout | | | | ✓ | ✓ | 2 |
| news-pause | ✓ | | | | | 1 |
| trend-following | | | | | ✓ | 1 |

Per OWNER 17:28 directive `diversity_bias_rules` (3+ consecutive same-class triggers a switch): the SRC01 set is mean-reversion-heavy (4/5), but it also includes 2 momentum-flagged and 2 breakout-flagged + 1 trend-following. **For SRC02 selection**, the diversity-bias rule suggests the next picks should NOT be mean-reversion-heavy. SOURCE_QUEUE.md proposed_order #2 is Chan, *Quantitative Trading* — which is mean-reversion-and-momentum mixed; I'll flag this in the SRC02 source.md when I open it.

## 3. Skipped strategies

| Source location | Reason for skip | Rule-1 classification |
|---|---|---|
| Ch 1 hogs triple-MA (pp. 12-14) | Underspecified-beyond-cardable. Davey's memoir narrative describes a "textbook triple-moving-average crossover (4/9/13 day)" he traded briefly on live hogs and abandoned after a 30%-of-account loss. NO entry/exit/stop rules in mechanical detail. To draft a card I'd have to extrapolate to "standard triple-MA crossover" semantics, which would exceed source extraction. | Source-spec-completeness failure (NOT a hard-rule failure). |
| App A Strategies 2/3/4 (pp. 249-253) | DEFERRED pending CEO Q1 ruling on Rule 1 strict-vs-intent reading. Davey's Ch 12 framing positions these as "monkey test" instruments to evaluate Strategy 1's edge — explicitly NOT deployable strategies. My read is intent-based (not cards). CEO confirms or overrides. If strict, becomes 3 additional cards. | Pending CEO ruling. |

## 4. Methodology cross-walk: Davey procedure vs V5 P-stage flow

Davey's book IS a strategy-development process textbook. Parts II–VI describe a procedure that aligns closely with V5's P-stage flow but with several deliberate divergences. This cross-walk is the secondary deliverable from SRC01: it informs V5 enhancement-loop docs by surfacing where V5 is more conservative, less conservative, or genuinely novel relative to a published practitioner's procedure.

### Direct mapping

| Davey | V5 | Notes |
|---|---|---|
| Ch 9 "Strategy Development — Goals and Objectives" | G0 Research Intake (Strategy Card § 9-10) | Davey emphasizes goal-setting BEFORE strategy development; V5's G0 captures the same via Card § 10 "Initial Risk Profile" + § 11 "Strategy Allowability Check". |
| Ch 10 "Trading Idea" | G0 (Strategy Card § 2 Concept + § 4 Entry Rules + § 5 Exit Rules) | Davey: "if you cannot explain the rule in plain English, you will have a tough time converting it to computer code." V5 enforces the same via the pseudocode requirement in § 4-5. |
| Ch 11 "Let's Talk about Data" | infrastructure-level (V5 uses Darwinex-native data per `darwinex_native_data_only` hard rule) | Davey covers continuous-contract construction, pit-vs-electronic data alignment, settlement vs tick-data trade-offs. V5 sidesteps most of these by mandating Darwinex-native data. |
| Ch 12 "Limited Testing" + monkey tests | P2 Baseline Screening | Davey's monkey tests (random-entry / random-exit / both-random) are direct ancestors of V5's "did we beat random?" check at P2. V5 does not yet formally implement Davey's specific monkey-test framework but App A Strategies 2/3/4 are available as ports. |
| Ch 13 "In-Depth Testing / Walk-Forward Analysis" | P4 Walk-Forward | Davey's 5-year-in / 1-year-out unanchored walk-forward with net-profit fitness function ≈ V5 P4. |
| Ch 14 "Monte Carlo Analysis and Incubation" | P5 Stress + P5b Calibrated Noise + P5c Crisis Slices | Davey's Monte Carlo perturbs trade order; V5 perturbs price-tick noise (P5b) and macro-regime exposure (P5c) in addition. V5 is more comprehensive here. |
| Ch 15 "Diversification" | P9 Portfolio Construction | Davey uses correlation-coefficient + R²-of-equity-curve linearity as diversification metrics. V5 P9 does this and adds risk-parity / volatility-weighted allocation. |
| Ch 16 "Position Sizing and Money Management" | P9 Portfolio Construction (sizing) + V5 risk-mode framework | Davey's fixed-fractional sizing maps to V5 risk-mode-percent. |
| Ch 17 "Documenting the Process" | The Strategy Card itself + git commit history + completion reports like this one | Davey wants traceability for every strategy decision. V5's Card schema + audit trail covers this. |
| Ch 18-19 (Walk-Through Build) | combination of P1 Build Validation + P2 Baseline + P3 Sweep + P4 Walk-Forward + P5 Monte Carlo | Davey's Ch 18-19 is the pedagogical "do all of Parts II-III on one specific strategy"; V5's P1-P5 is the same loop. |
| Ch 20 "Account and Position Sizing" | V5 risk-mode framework configuration | Davey's contest-grade sizing (75% max DD acceptable) is explicitly excluded from V5; see S05 card § 12 `risk_mode_dual`. |
| Ch 22 "Other Considerations before Going Live" | P9b Operational Readiness | Davey covers slippage, broker selection, infrastructure hardening — all in V5's P9b checklist. |
| Ch 23 "Monitoring a Live Strategy" + Ch 24 "Real Time" | P10 Shadow Deploy + Live Promotion + ongoing monitoring (kill-switch + drawdown alerts) | Davey's monitoring framework ≈ V5 P10. |
| Ch 25 "Delusions of Grandeur" | not formalized in V5 | Davey's cautionary chapter on overconfidence and post-success blow-ups; V5 governance + hard-rule architecture reflects similar lessons but doesn't formalize a "delusions" gate. |

### Wins (V5 is more rigorous than Davey)

- **P3.5 Cross-Sectional Robustness (CSR)** — Davey has no equivalent. CSR tests strategy edge across instrument variants of the same category (e.g., does Euro Night work on EURUSD AND USDJPY AND GBPUSD?). Davey's diversification approach (Ch 15) is post-hoc portfolio-level; V5's P3.5 is per-strategy pre-flight.
- **P5c Crisis Slices** — Davey explicitly AVOIDS testing on crisis periods (Ch 12 p. 104: *"I would try to avoid preliminary testing during the financial crisis, since it may lead me to a system that performs well only during severe shocks and panics. While a system such as this might be nice at those times, I'd fear that the system would lose a lot more during the more prevalent 'normal' times."*). V5 P5c deliberately INCLUDES crisis periods to test tail-risk behavior. **Both philosophies have merit; V5's choice is more conservative.**
- **P7 Statistical Validation with PBO < 5% hard gate** — Davey's framework has no formal probability-of-overfitting test. He approximates this informally via the monkey tests (Ch 12) and the optimization-vs-walk-forward divergence demo (Ch 13), but no formal PBO gate. V5's P7 is novel relative to Davey.
- **P8 News Impact** — Davey doesn't formally evaluate news-window behavior. V5's P8 is novel.
- **Hard-rule architecture** — Davey doesn't have V5's `hard_rules_at_risk` declarative system. He covers many of the same concerns (no martingale, no over-optimization) but as advice, not as machine-checkable rules. V5's structure is more rigorous.

### Regressions (V5 is less rigorous than Davey — none observed)

- None identified. V5's procedure subsumes Davey's at every gate.

### Neutrals (similar rigor, different mechanics)

- **Walk-forward methodology** — Davey Ch 13 (5y-in / 1y-out unanchored, net-profit fitness) ≈ V5 P4. Mechanically equivalent.
- **Monte Carlo trade-order perturbation** — Davey Ch 14/19 ≈ V5 P5. V5 adds tick-noise perturbation (P5b) and crisis slices (P5c) on top.
- **Limited Testing** — Davey Ch 12 ≈ V5 P2 Baseline Screening. Davey's monkey tests are richer than V5's typical baseline check; V5 may benefit from porting App A Strategies 2/3/4 as P2 reference.

### Recommendations to the V5 framework (input to QUA-236 enhancement loop)

1. **Adopt Davey's monkey-test framework as a P2 sub-procedure.** Port App A Strategies 2/3/4 to MQL5 as comparator EAs in V5's sandbox magic-ID range (5000-8999) and run them alongside any new strategy at P2. Specifically: for each candidate strategy at P2, also run a (a) random-entry / strategy-exit version, (b) strategy-entry / random-exit version, (c) random-random version. Strategy must beat all three on PF and DD in 90%+ of 1000+ random seeds (Davey's threshold). This is a stricter form of "did we beat random?" than V5's current implicit baseline.
2. **Capture Davey's "let's avoid crisis periods in preliminary testing" philosophy as a documented divergence from V5's P5c.** V5 includes crises by design; Davey excludes them deliberately. Reviewers should be aware that on cards extracted from Davey, the source's framing may differ from V5's testing posture.
3. **Document Davey's contest-context risk-tolerance distinction in V5's risk-mode docs.** Davey explicitly distinguishes "75% max DD acceptable" (contest) from "1-2% per trade typical" (normal account). V5's risk-mode-percent + risk-mode-fixed framework already covers the latter; the former should be explicitly UNAVAILABLE in V5 production deployments.

## 5. Source quality observations

- **Methodology coverage:** exceptional. Davey is the closest published analog to V5's P-stage flow we're likely to find in any single book.
- **Strategy density:** low (~5 strategies in 263 pages). Davey wrote a process textbook, not a strategy library. Acceptable; the methodology is the value.
- **Author-claim density:** mixed. S03 has none, S01/S02 are Monte Carlo, S04 is a deliberate failure example, S05 is real contest performance. Reviewers should expect this card-set to span the full claim-evidence spectrum.
- **Code precision:** high where provided. Apps A/B/C and Ch 13 walk-forward block all give EasyLanguage source. **One source-text typo flagged** (Ch 13 p. 117 first code block has buy/sellshort directions swapped vs the verbal description and the corrected p. 119 code; documented in S04 card § 4 + § 16).
- **BASIS-rule precision:** chapter + section + page citations available throughout; verbatim quotes supported with exact location anchors in every card.
- **V5-hard-rule compatibility:** high. No ML, no martingale (Davey's Ch 25 explicitly warns against), no scalping (longest-bar = 60-min day strategy). Most cards' hard-rule risks are `dwx_suffix_discipline` and `darwinex_native_data_only` (instrument-mapping concerns), `friday_close` (no native time exit on several strategies), and one strong `risk_mode_dual` flag on S05.

## 6. Yield ratio

| Metric | Value |
|---|---|
| Heartbeats used | 7 |
| Cards drafted | 5 |
| Cards passed G0 | 0 (all DRAFT) |
| Cards killed pre-P1 | 0 |
| Cards/heartbeat | 0.71 |
| G0-pass-rate (cards_passed_g0 / cards_drafted) | TBD pending CEO + Quality-Business review |

The 0.71 cards/heartbeat ratio is a Davey-specific number; comparable rates won't be available for queue-pacing decisions until SRC02-SRC04 land.

## 7. Recommendation: deeper mining or move on?

**Move on to SRC02.** Rationale:

- All chapters and appendices surveyed; no remaining strategy-bearing sections.
- The 5 cards span the full evidence-quality spectrum the source provides.
- Davey is methodology-heavy by design; further mining would produce diminishing returns (re-reading methodology that's already mapped to V5).
- Per OWNER 17:28 diversity-bias rules, the next pick should be NOT predominantly mean-reversion (SRC01 was 4/5 mean-reversion-flagged). SOURCE_QUEUE.md proposed_order #2 is **Chan, *Quantitative Trading*** — Chan covers both mean-reversion AND momentum across stocks/ETFs/currencies/futures, so the next slot naturally diversifies.

CEO action requested per QUA-188 waiver v3:

1. **G0 review** of the 5 DRAFT cards (S01-S05). CEO is the procedural reviewer; Quality-Business is not yet hired so this is CEO-only review per the v3 broadened authority.
2. **Q1 ruling** on App A Strategies 2/3/4 (random-by-design test instruments). My read: intent-based (not cards). CEO confirms or overrides.
3. **SRC02 dispatch** — open new SRC02 issue against Chan, *Quantitative Trading* per SOURCE_QUEUE proposed_order #2.
4. **Q2 follow-up** — foreign-process file integrity on the worktree. The non-Research process producing files attributed to me with factual errors (one example: `appA_monkey_baseline.md` falsely attributes to Research Agent and contains an incorrect Strategy 1 reading). Decision needed on whether to delete or commit-with-corrections.

## 8. Cross-references

- Parent issue: [QUA-191](/QUA/issues/QUA-191)
- Source-text PDF: `G:\My Drive\QuantMechanica\Ebook\PDF resources\Building Winning Algorithmic Tr - Kevin J. Davey.pdf`
- Source-queue: `strategy-seeds/sources/SOURCE_QUEUE.md`
- SRC01 source.md: `strategy-seeds/sources/SRC01/source.md`
- 5 Strategy Cards:
  - `strategy-seeds/cards/davey-eu-night_card.md`
  - `strategy-seeds/cards/davey-eu-day_card.md`
  - `strategy-seeds/cards/davey-baseline-3bar_card.md`
  - `strategy-seeds/cards/davey-es-breakout_card.md`
  - `strategy-seeds/cards/davey-worldcup_card.md`
- 5 raw evidence files:
  - `strategy-seeds/sources/SRC01/raw/appB_euro_night.md`
  - `strategy-seeds/sources/SRC01/raw/appC_euro_day.md`
  - `strategy-seeds/sources/SRC01/raw/appA_baseline_and_monkey_variants.md`
  - `strategy-seeds/sources/SRC01/raw/ch13_walkforward_breakout.md`
  - `strategy-seeds/sources/SRC01/raw/ch3_worldcup_xbar_breakout.md`
- Workflow doc: `processes/13-strategy-research.md`
- Card template: `strategy-seeds/cards/_TEMPLATE.md`
- DL-026 (`.DWX` prompt patch retroactively approved 2026-04-27)
- DL-029 (workflow ratification): `decisions/2026-04-27_strategy_research_workflow.md`
- QUA-188 waiver v3 (CEO-autonomous source-queue ordering)
- Rule 1 (CEO comment [`85b9ec8e`](/QUA/issues/QUA-191#comment-85b9ec8e-8461-4579-8110-2fb2621b0470)) — extract every distinct mechanical strategy that passes V5 hard rules
