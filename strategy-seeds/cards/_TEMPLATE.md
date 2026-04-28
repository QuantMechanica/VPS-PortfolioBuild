# Strategy Card — TEMPLATE

> **V5 source:** authored 2026-04-26 from `docs/ops/RESEARCH_METHODOLOGY_V2.md` § Step 2 + V5 Hub Fragenkatalog conventions.
> **Owner:** Research Agent (Wave 0)
> **Review:** CEO + Quality-Business

This is the canonical template for V5 Strategy Cards. Research extracts every distinct strategy from an approved source and produces one card per strategy. Cards are reviewed by CEO + Quality-Business; on APPROVE they become Development's input.

**Filename convention.** New cards use `strategy-seeds/cards/<slug>_card.md` — `slug` is allocated at extraction (lowercase kebab-case ≤ 16 chars). `ea_id` is allocated later by CEO + CTO at APPROVED stage and lives only inside the card's Header, not in the filename. This replaces the prior `QM5_NNNN_<slug>_card.md` pattern; existing cards keep their current filenames, only new cards follow the new pattern.

Copy this file to `strategy-seeds/cards/<slug>_card.md` and fill in. Do not delete unfilled fields — leave them as `TBD` so reviewers can see what is missing.

---

## Card Header

```yaml
strategy_id: SRC{source_id}_S{n}            # e.g., SRC001_S03 = source 1, strategy 3
ea_id: TBD                                   # allocated by CEO + CTO at approval (1000-9999 production, 5000-8999 sandbox)
slug: TBD                                    # lowercase kebab-case ≤ 16 chars (e.g., "breakout-atr"); becomes the card filename
status: DRAFT                                # DRAFT / IN_REVIEW / APPROVED / REJECTED / IN_BUILD / IN_PIPELINE / DEPLOYED / RETIRED
created: YYYY-MM-DD
created_by: Research
last_updated: YYYY-MM-DD

strategy_type_flags: []                      # MULTI. Controlled vocabulary; allowed values per
                                             #   `strategy-seeds/strategy_type_flags.md` (forthcoming, QUA-236 child 3 — Research V4 taxonomy mining).
                                             # Examples (non-exhaustive until vocab lands): martingale, grid, scalping,
                                             #   breakout, trend-following, mean-reversion, momentum, carry, seasonality,
                                             #   news-pause, others. Pick all that apply.
```

## 1. Source

`source_citations:` is **multi**. A strategy that combines insights from two or more papers/books cites BOTH (or all). One entry per source. The first entry should be the primary source; subsequent entries supplement.

```yaml
source_citations:
  - type: book | paper | article | video | forum_post | other
    citation: "Author Last, First. (Year). Title. Edition. Publisher / DOI / URL."
    location: "page 123-127" | "section 4.2" | "00:23:45-00:31:10" | "comment thread quote"
    quality_tier: A | B | C    # A = peer-reviewed / known author; B = blog of credible practitioner; C = forum / unknown
    role: primary              # primary | supplement (the inefficiency comes from this source vs. this source refines it)
  # repeat the block for additional sources:
  # - type: paper
  #   citation: "..."
  #   location: "..."
  #   quality_tier: A
  #   role: supplement
```

## 2. Concept

2-3 sentences in plain English. What is the market inefficiency this strategy claims to exploit? What's the cause-and-effect story?

## 3. Markets & Timeframes

```yaml
markets:                                     # which the source recommends
  - forex
  - indices
  - commodities
  - crypto
timeframes:                                  # which the source recommends
  - M15
  - H1
  - H4
primary_target_symbols: []                   # specific symbols the source mentions, if any
```

## 4. Entry Rules

Pseudocode form. One bullet per condition. Use indicator names exactly as in the source.

```text
- if RSI(14) < 30 on closed bar
- and price > SMA(200) on closed bar
- and not in news blackout window (per QM_NewsFilter)
- then BUY at market with QM_StopRules.QM_StopATR(period=14, mult=1.5)
```

## 5. Exit Rules

```text
- TP at QM_StopRules.QM_TakeRR(rr=2.0)
- SL handled by entry stop
- Trailing stop after +1R: QM_TM_TrailATR(period=14, mult=1.5)
- Time stop after 5 days
- Friday Close enforced (default per V5 framework)
```

## 6. Filters (No-Trade module)

Trading-allowed conditions. Strategy-specific in addition to framework defaults (kill-switch, news filter, friday close).

```text
- only trade during London-NY overlap (12:00-16:00 broker time)
- skip first hour after market open
- skip if ATR(14) < <some threshold>
- skip if EUR-USD correlation > 0.8 already long EURUSD
```

## 7. Trade Management Rules

Beyond entry/exit. Position-lifecycle behavior.

```text
- if position +1R: move SL to break-even via QM_TM_MoveToBreakEven(trigger_pips=N, buffer_pips=M)
- if position +2R: close 50% via QM_TM_PartialClose(reason=QM_EXIT_STRATEGY)
- pyramiding: NOT allowed (default V5 one-position-per-magic-symbol)
- gridding: NOT allowed (or: allowed with strict 1%-cap fallback per V5 stance)
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: rsi_period
  default: 14
  sweep_range: [9, 12, 14, 18, 21]
- name: sma_period
  default: 200
  sweep_range: [100, 150, 200, 250]
- name: atr_mult
  default: 1.5
  sweep_range: [1.0, 1.25, 1.5, 1.75, 2.0]
```

## 9. Author Claims (verbatim, with quote marks)

Quote the source exactly. Do not paraphrase performance numbers.

```text
"The strategy produced an annualized return of 18.4% with a maximum drawdown of 9.2% over 2010-2018 on EURUSD H1." (page 127)
"In my live experience over 3 years, win rate has been around 52-55%." (chapter 4 closing remark)
```

## 10. Initial Risk Profile

```yaml
expected_pf: 1.3                             # rough estimate from author claims
expected_dd_pct: 12                          # rough estimate
expected_trade_frequency: 50/year            # rough estimate
risk_class: low | medium | high              # operator's read
gridding: false
scalping: false
ml_required: false                           # hard-fail in V5 if true
```

## 11. Strategy Allowability Check (V5 framework)

Before submitting card to CEO:

- [ ] Strategy concept is mechanical (no discretionary judgment)
- [ ] No Machine Learning required (V5 ban — `EA_ML_FORBIDDEN`)
- [ ] If gridding: strict 1%-cap fallback documented per V5 stance
- [ ] If scalping: P5b stress with realistic VPS latency calibration must be planned
- [ ] Friday Close compatibility: confirm strategy survives forced flat at Friday 21:00 broker time, OR document why disable is required
- [ ] Source citation is precise enough to reproduce (page/timestamp, not "general knowledge")
- [ ] No near-duplicate of existing approved card (Research checks against `strategy-seeds/cards/index.md`)

## 12. Framework Alignment

Map this strategy onto the V5 4-Module pattern + flag any V5 Hard Rule that is at risk. Research fills this; CTO sanity-checks at APPROVED stage. See `framework/V5_FRAMEWORK_DESIGN.md` for module hooks and inherited V4 rules.

```yaml
modules_used:
  no_trade:           # Strategy_NoTrade — strategy-specific gating beyond framework defaults
    used: true | false
    notes: "e.g., skip first hour of London open, ATR floor, correlation guard"
  trade_entry:        # Strategy_EntrySignal — required for any strategy
    used: true
    notes: "e.g., RSI(14)<30 + price>SMA(200)"
  trade_management:   # Strategy_ManageOpenPosition — trailing, BE, partial close, pyramiding
    used: true | false
    notes: "e.g., move-to-BE at +1R, ATR trail after +1R"
  trade_close:        # Strategy_ExitSignal — strategy-specific exit beyond SL/TP/trailing
    used: true | false
    notes: "e.g., exit on RSI cross 50, exit on regime flip, time-stop after 5 days"
```

```yaml
hard_rules_at_risk:                          # MULTI. Mark every Hard Rule this strategy could
                                             # plausibly stress so CTO + Quality-Tech know what to
                                             # validate. Allowed values:
  # - friday_close                           # strategy holds positions across Fri 21:00 broker time
  # - risk_mode_dual                         # any non-standard sizing path (RISK_PERCENT / RISK_FIXED)
  # - dwx_suffix_discipline                  # references symbols without the .DWX suffix
  # - model4_every_real_tick                 # strategy assumes a tick model other than Model 4
  # - magic_schema                           # any deviation from ea_id*10000+symbol_slot
  # - enhancement_doctrine                   # entry-side parameters likely to change post-PASS
  # - darwinex_native_data_only              # references external market-data feeds
  # - ml_forbidden                           # uses ML-trained component (V5 hard-fail)
  # - one_position_per_magic_symbol          # pyramiding / multiple stacked positions
  # - grid_1pct_cap                          # grids/martingales — per-cycle risk must stay <1%
  # - scalping_p5b_latency                   # scalper — needs P5b VPS-realistic latency calibration
  # - kill_switch_coverage                   # any pattern that could mask DD from QM_KillSwitch
  # - news_pause_default                     # strategy claims edge during high-impact news windows
at_risk_explanation: |
  Free text: for each flag above, one sentence on why it's at risk and how the strategy plans to
  comply (or where the strategy proposes a documented exception per V5 Hard Rules).
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                              # additional Strategy_NoTrade conditions beyond framework
  entry: TBD                                 # Strategy_EntrySignal implementation notes
  management: TBD                            # Strategy_ManageOpenPosition implementation notes
  close: TBD                                 # Strategy_ExitSignal implementation notes
estimated_complexity: small | medium | large
estimated_test_runtime: <hours per BL sweep>
data_requirements: standard | custom_news | other
```

## 14. Pipeline History (per `_v<n>` rebuild)

One row per rebuild of this strategy under the QUA-236 enhancement loop. `_v1` is the original build; `_v2` is the first rebuild after a P-stage failure or post-APPROVED enhancement; etc. Pipeline-Operator appends a row whenever a new `_v<n>` is opened or a verdict lands. See QUA-236 child 4 (enhancement loop) for trigger criteria.

| version | date | rebuild reason | P-stage reached | verdict |
|---|---|---|---|---|
| _v1 | YYYY-MM-DD | initial build | TBD | TBD |
| _v2 | TBD | TBD | TBD | TBD |

Rebuild reasons (controlled phrasing): `initial build` / `failed P<n> — <one-line cause>` / `enhancement: <one-line goal>` / `data refresh` / `framework upgrade`.
Verdicts: `IN_PROGRESS` / `PASS` / `FAIL` / `RETIRED` / `SUPERSEDED`.

## 15. Pipeline Phase Status (current `_v<n>`)

Per-phase tracker for the **current** rebuild only. Pipeline-Operator + CEO update as each phase completes; reset / re-baseline whenever a new row is added to § 14.

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | YYYY-MM-DD | APPROVED | this card |
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

When this strategy hits a phase boundary, add a one-line note here that may become a Learnings Archive entry:

```text
- 2026-MM-DD: <observation>
```
