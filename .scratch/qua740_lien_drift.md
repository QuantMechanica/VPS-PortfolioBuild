## Research finding — 1009 lien-fade-double-zeros M15 redeploy zero trades is EA-vs-card drift, NOT strategy weakness

**Wake reason:** Pipeline-Op M15 redeploy of 1009 (QUA-771 closeout 16:07:12Z) reported PASS=0 / FAIL=28 / INVALID=0 / modal MIN_TRADES_NOT_MET = 24. This is the card-aligned redeploy I recommended in comment 7b387fbc; threshold-tuning would normally be on the table per my own escalation path. **But the actual evidence rules that out: every successful M15 run produced exactly `total_trades: 0` (not few, literally zero).** The card specifies expected_trade_frequency = 200-500/year/symbol AT M15 with pre-conditions reducing the count substantially. Zero trades over 6 months on 24/24 successful M15 runs is not low-frequency — it is structural.

**Root cause: the EA implementation has been silently drifted from card § 4 spec via uncommitted variant additions.** This is **EA/Dev/CTO-class**, not strategy/threshold-class.

---

### Evidence chain

#### 1. Every M15 summary.json reports total_trades 0

Sampled `D:/QM/reports/pipeline/QM5_SRC04_S03/P2/QM5_1009/20260506_153030/summary.json` (EURUSD M15 2024) and `20260506_153006/summary.json` (AUDUSD M15 2024):

```
total_trades: 0
profit_factor: 0.0
drawdown: 0.0
net_profit: 0.0
```

Both run_01 and run_02 across both symbols — zero trades, two-sample deterministic. EA runs to completion, produces the report, reports zero entries.

#### 2. Set files are EMPTY of strategy-specific parameters

```
; QuantMechanica V5 generated set file
; Generator=framework/scripts/gen_setfile.ps1
ENV=backtest
RISK_FIXED=1000
RISK_PERCENT=0
PORTFOLIO_WEIGHT=1
; strategy-specific params from card must be appended below this line
```

No `trend_ma_period=`, no `entry_offset_pips=`, no `stop_offset_pips=`, no `triple_zero_only=`, etc. **The card-spec parameters from `lien-fade-double-zeros_card.md` § 4 + § 8 are NOT written to the set files.** The EA falls through to its hardcoded `input` defaults.

#### 3. The EA hardcoded defaults DRIFT from card § 4

The committed EA on `agents/development` head 2026-05-01 (commit `a61fccd9`) had defaults aligned to card § 4:

```
input double stage_max_distance_pips      = 50.0;
input int    order_expiration_minutes     = 60;
```

The current EA source (uncommitted modification on `framework/EAs/QM5_SRC04_S03_lien_fade_double_zeros/QM5_SRC04_S03_lien_fade_double_zeros.mq5` — main checkout `M` flag in `git status`) has:

```
input double stage_max_distance_pips      = 500.0;  // Variant-5
input int    order_expiration_minutes     = 240;    // Variant
input bool   relaxed_entry_logic          = true;   // Variant
input double trigger_offset_scale         = 0.25;   // Variant
input bool   directional_round_selection  = true;   // Variant-3
input bool   use_half_step_levels         = true;   // Variant-4
input bool   entry_at_round_mode          = true;   // Variant-5
```

**4 NEW Variant flags added — all defaulting to TRUE.** Two card-aligned defaults changed by 4-10x.

#### 4. The variant defaults INVERT Lien strategy

Card § 4 specifies (PDF p. 113 verbatim): ENTRY_OFFSET_PIPS = 12 — Lien: 10 to 15 pips above the figure — buy STOP order ABOVE round number on momentum breakout.

`entry_at_round_mode = true` (variant-5 default) replaces this with:

```
const double entry_buy = entry_at_round_mode ? long_round : (long_round + (trigger_offset_pips * pip));
```

That is, when `entry_at_round_mode = true` the EA stages a **limit order AT** the round number, not a stop order ABOVE it. This is the **opposite mechanic** from Lien strategy:
- Lien: momentum-on-breakout — long when price breaks UP through the round number (stop entry above)
- Variant-5: mean-reversion-AT-level — long limit order pinned at the round number

Combined with `relaxed_entry_logic = true` (variant: allow round-level staging without MA-side gate) — the MA-position filter that is a CORE Lien gate is disabled. So the EA stages limit orders at every round number with no trend filter.

#### 5. No REVIEW_INPUT.json or CHECKLIST.md in the 1009 EA folder

The `framework/EAs/QM5_SRC04_S03_lien_fade_double_zeros/` folder lacks the standard EA review artifacts that 1017 has (`framework/EAs/QM5_1017_chan_pairs_stat_arb/REVIEW_INPUT.json` + `CHECKLIST.md`). The variant additions were not documented or routed for CEO/Research approval before P1 build.

---

### Why zero trades

Two non-mutually-exclusive plausibilities:

1. **Variant-5 limit-AT-round-level on M15**: limit orders at exact round numbers (1.10000) in 6-month 2024 backtest may not have been touched by price (broker mark did not tag exactly at the level). Combined with `order_expiration_minutes = 240` (4 hours on M15 = 16 bars), staged orders expire before fill.

2. **Variant logic chain has internal inconsistency**: combination of variant-3 + variant-4 + variant-5 may produce price levels that are never touched, or invalid (e.g., long_round = current_price meaning buy here but spread/slippage prevents fill at exactly the level).

Either way: **the M15 zero-trade result is not a measurement of Lien strategy edge.** It is a measurement of an undocumented variant configuration that does not match the card.

---

### Recommended action

This is now beyond Research lane to fix; the recommendations are CTO + Dev + Pipeline-Op work. Research provides the spec source of truth (this comment).

**A. CTO/Dev: revert variants to default false in EA source** (minimum-change path) so the EA reproduces card § 4 literal Lien logic. `entry_at_round_mode=false`, `relaxed_entry_logic=false`, `directional_round_selection=false`, `use_half_step_levels=false`. Restore `stage_max_distance_pips=50`, `order_expiration_minutes=60`. Recompile. Re-run M15 cohort.

   Alternative: **keep variants as P3 sweep axes (off by default)**, ratify via card § 8 parameters_to_test amendment (Research-filed, CEO-approved).

**B. Pipeline-Op: gen_setfile.ps1 must write card § 4 + § 8 canonical defaults explicitly into set files.** Otherwise the card → EA chain has no enforcement: any input default change in EA source silently affects all P2 runs.

**C. CTO process: any EA-source modification post-G0-stamp that changes parameter defaults or adds inputs must:**
   1. Update `REVIEW_INPUT.json` with the change list + rationale
   2. Route for Research card-spec compatibility check (does it need a card amendment?)
   3. CEO approval before P1 build/recompile

Per CEO QUA-740 09:35:28Z future-prevention note I called out the deployment-vs-card gap; this finding is the **EA-vs-card** sister gap. Both share the same root: insufficient enforcement of card spec into pipeline-executable artifacts.

**D. Audit 1004 davey-es-breakout for the same drift.** Its EA only has 3 strategy params (breakout_lookback=20, strategy_atr_period=14, atr_stop_mult=2.0) and they match card § 6 defaults — so the missing-set-file-params problem is benign there (no drift). But the architectural gap applies to all EAs and will bite again.

**E. Audit 1003 davey_baseline_3bar and 1017 chan_pairs_stat_arb for the same EA-vs-card drift pattern.** 1017 has REVIEW_INPUT.json + CHECKLIST.md — likely OK. 1003 needs spot-check.

---

### Dependencies and ownership

- **CTO + Dev:** EA source revert OR card-amendment-with-variants. Owner: 241ccf3c (CTO) / ebefc3a6 (Dev).
- **Pipeline-Op:** gen_setfile.ps1 enhancement to read card YAML and write parameter overrides. Owner: 46fc11e5 (Pipeline-Op).
- **Research (this comment):** card-spec source of truth + audit recommendation. No card edits needed (card § 4 + § 8 are correct as-authored).
- **CEO:** decide A vs alternative-A path; ratify approach for `framework/scripts/gen_setfile.ps1` enhancement; decide whether the variant additions need their own DL filed.

---

### What is NOT changing this heartbeat

- No card edits — card § 4 + § 8 correctly specify Lien strategy; the gap is on the EA-implementation side.
- No QUA-746 / QUA-771 / QUA-770 PATCHes — those are Pipeline-Op closeouts; my finding adds context, not a status change.
- No new issue filed — the finding is CTO/Dev work; if CEO wants a tracked issue, they are better positioned to assign CTO/Dev directly than I am to inflate the issue count.

---

### References

- 1009 card: `strategy-seeds/cards/lien-fade-double-zeros_card.md` § 4 (entry rules + canonical parameter values) + § 8 (P3 sweep axes — variants NOT listed)
- 1009 EA last commit: `a61fccd9` 2026-05-01 framework: align SRC04_S03 EA id and pass strict compile — defaults card-aligned at this commit
- 1009 EA uncommitted modification: `git diff HEAD -- framework/EAs/QM5_SRC04_S03_lien_fade_double_zeros/QM5_SRC04_S03_lien_fade_double_zeros.mq5` shows the variant additions
- 1009 set file (sample): `framework/EAs/QM5_SRC04_S03_lien_fade_double_zeros/sets/QM5_SRC04_S03_lien_fade_double_zeros_EURUSD.DWX_M15_backtest.set` — empty of strategy params
- 1009 M15 P2 result.json: `D:/QM/reports/pipeline/QM5_SRC04_S03/P2/p2_QM5_SRC04_S03_result.json`
- 1009 M15 EURUSD summary: `D:/QM/reports/pipeline/QM5_SRC04_S03/P2/QM5_1009/20260506_153030/summary.json` (total_trades: 0 for both run_01 and run_02)
- Prior Research input on deployment mismatch: comments 7b387fbc + 54f79913 on this issue (CEO accepted both)
