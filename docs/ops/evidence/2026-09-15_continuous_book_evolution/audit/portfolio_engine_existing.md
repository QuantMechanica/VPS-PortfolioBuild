# Audit — Existing Portfolio Machinery vs. Continuous Recomposition Engine

Task: `portfolio_engine_existing` (directive §5, §7, §8, §57–§59, §68E, §70).
Auditor: read-only subagent, 2026-09-15. Truth precedence per directive §1.
Report: `docs/ops/evidence/2026-09-15_continuous_book_evolution/audit/portfolio_engine_existing.md`.

## Headline

1. A large, mostly-deterministic, test-covered portfolio package already exists
   (`tools/strategy_farm/portfolio/`, ~170 modules) that computes weights, KPIs,
   correlations, marginal contribution, concentration/tail, a DXZ KEEP/CHANGE trigger,
   and an FTMO first-passage/probability engine — the current DXZ v2 28-sleeve book is
   already a deterministic, hash-bound, reproducible proposal
   (`D:/QM/reports/portfolio/dxz_v2_20260913/build_28_r11/analytic_preview_manifest_28_r11.json`).
2. What is missing for §58 is not the primitives but the *composition*: there is no single
   venue-parameterized recomposition entrypoint that ingests a frozen input snapshot and emits
   the full §58 output object for BOTH DXZ and FTMO; two directive-named blockers remain live
   in code — the `MIN_QUALIFIED_PAIRS = 25` hard gate (`book_build_guard.py:31,239`) and the
   `concentration_reject` hard-block (§4/§8/§70) — plus three metric gaps
   (effective-number-of-bets, explicit downside correlation, an FTMO KEEP/CHANGE trigger).
3. §59 materiality exists only as a 2-dimensional DXZ-OOS rule (`dxz_next_book_trigger.py`);
   the full §59 seven-factor anti-churn spec and the §70 "reproducible from frozen inputs"
   snapshot format are not yet implemented as one contract.

## Findings

### 1. The portfolio package is large and layered (inventory)
`tools/strategy_farm/portfolio/` holds ~170 `.py` modules (evidence:
`ls tools/strategy_farm/portfolio/*.py`). The engine-relevant core, grouped:

- **Primitives (deterministic):** `portfolio_common.py` (Trade model, frozen stream bundle
  loader, `to_daily_pnl`/`to_monthly_pnl`, `align`), `portfolio_kpi.py`
  (`portfolio_equity`, `portfolio_metrics`, `inverse_vol_weights`, `max_drawdown_pct`,
  `metrics_from_daily_pnl`), `book_builder_common.py` (`capped_inverse_vol`, `book_metrics`,
  dual-book-roster schema `qm.dual-book-roster/v1`).
- **Risk/diagnostics:** `portfolio_correlation.py` (Pearson, stationary-bootstrap CI,
  circular-rotation null, occupancy/trade-overlap, signed-daily-direction overlap, regime),
  `concentration_tail.py` (symbol/asset-class/family/session caps + common-tail, config
  `config/concentration_tail_limits.v1.json`), `marginal_contribution_eval.py`
  (ΔSharpe/ΔMaxDD/Δworst-day + regime-split correlation of candidate vs book),
  `portfolio_montecarlo.py` (block-bootstrap MC, seeded).
- **Builders/allocators:** `build_book_dxz.py`, `build_book_ftmo.py`, `book_reoptimizer.py`
  (greedy Sharpe selection under pairwise corr ≤0.50), `portfolio_resize.py` (hierarchical
  capped-proportional allocation with group half-space projection), `book_sizing.py`,
  `portfolio_admission.py` (candidate admission classify + challenger-swap evaluation),
  `portfolio_freeze_gate.py` (truth-chain + input-SHA gate), `portfolio_manifest.py`.
- **Venue triggers/comparison:** `dxz_next_book_trigger.py` (BETTER / MATERIAL_BUT_REVIEW /
  NO_MATERIAL_GAIN, OWNER-ratified 2026-07-29), `dxz_live_blend_reweight.py` (backtest/live
  vol blend from a frozen deal export), `dxz_weight_oos_validation.py`.
- **FTMO:** `fund_score.py` (FUND_SCORE facade over `challenge_book_60d.py`),
  `ftmo_book_readiness.py`, `ftmo_probability_contract.py` (loader, contract config
  `config/ftmo_probability_contract.v1.json`), `ftmo_timebox_eval.py` (authoritative
  probability engine), `challenge_firstpassage.py` (two-barrier first-passage P(pass)),
  `ftmo_governor_policy_v2.py`, `ftmo_acceleration_plan.py`, plus ~90 `ftmo_*` research screens.
- **Guards/roster/streams/deploy:** `book_build_guard.py` (fail-closed census + 25-gate),
  `build_qualified_roster.py`, `../assemble_stream_bundle.py` (sealed q08_trades bundle,
  hash-bound to the Q14 terminal verdict identity), `build_tlive_book_profile.py`,
  `deploy_tlive_book.py`, `stage_tlive_presets_risk.py`, `account_portfolio_governor.py`.

### 2. Determinism is already the norm; RNG is seeded and reported, not a gate
`portfolio_montecarlo.simulate` uses `random.Random(seed)` (`portfolio_montecarlo.py:145,153`,
CLI default `--seed 0`). `portfolio_correlation` seeds a *deterministic per-pair* RNG
(`_pair_seed`, `portfolio_correlation.py:477-482`) and its docstring states the bootstrap seed
is "a reported constant, not a gate criterion" (`:103-104`). `marginal_contribution_eval.py`,
`portfolio_kpi.py`, `book_builder_common.py`, `concentration_tail.py`,
`dxz_next_book_trigger.py` contain no randomness. So §58 "portfolio calculations should be
deterministic" is already met at primitive level; the frozen-input contract (§70) is what is
missing (Finding 8).

### 3. Trade-stream / equity artifacts a portfolio engine consumes (DXZ backtest)
Canonical per-(EA,symbol) stream format is JSONL `TRADE_CLOSED` at
`<stream_root>/QM/q08_trades/<ea>_<symbol_dots_as_underscores>.jsonl`
(`assemble_stream_bundle.py:6`, consumed by `book_builder_common.load_daily` →
`portfolio_common.load_streams`, `portfolio_common.py:276`). Example line
(`D:/QM/reports/portfolio/dxz_v2_20260913/streams_v2b/QM/q08_trades/10145_XAUUSD_DWX.jsonl`):
fields `event, money_basis=FULL_POSITION_LIFECYCLE_ACTUAL_V1, magic, side, entry_price,
exit_price, time, entry_time, mae_acct, net, profit, swap, fee, commission,
entry_commission, exit_commission, volume, notional, symbol`. Streams are RISK_FIXED $1000
on 100k (= 1.0 %/trade; noted in the manifest sleeve block). Bundles are sealed and
hash-bound: `assemble_stream_bundle.py` binds each pair to the `ex5_sha256` that carried its
terminal Q14 verdict and to the pinned `content_sha256`
(`dxz_v2_20260913/streams/bundle_manifest.json`). The default incumbent bundle
`D:/QM/reports/portfolio/dxz_final_20260719` is the stale July roster (documented defect D4).

### 4. The current DXZ v2 roster is already a complete, reproducible §58-shaped artifact
`D:/QM/reports/portfolio/dxz_v2_20260913/build_28_r11/analytic_preview_manifest_28_r11.json`
(`schema qm.dxz-book-v2-analytic-preview/v1`) contains: `weighting`
(CAPPED_INVERSE_VOL_DAILY_PNL, total_risk 11.0, sleeve_cap 1.5), `comparison`
(incumbent 24 vs proposal 28 over 1349 days 2019-08-02→2024-12-06: ann 9.17→10.81 %,
maxDD 2.43→2.05 %, Sharpe 2.34→2.53, worst-day −0.858→−0.856 %), `not_worse_gate` PASS,
`concentration`, `risk_totals` (existing 24 at 9.69 %, new 4 at 1.31 %, burn-in split),
28 `sleeves` each with weight/magic/setfile+sha/min-lot/standalone, and a
`reproduce_with` command + `roster_sha256`/`sleeve_list_sha256`. `builder_status`
`APPLY_RECOMMENDED`. This is the DXZ side of §58 minus ENB, downside-corr, and a unified
uncertainty/operational-risk block. Not yet deployed (live book remains the 24-sleeve
`portfolio_manifest_live_24sleeve_20260724.json`).

### 5. Live/demo evidence sources exist for the "live evidence" §58 input
- **DXZ live:** `C:/QM/mt5/T_Live/MT5_Base/MQL5/Files/QM/journal/live_deals_normalized.csv`
  (261 rows since first deposit 2026-04-24; per-deal `logical_magic, symbol, net_actual,
  swap, commission, risk_percent_in_force, net_per_1pct_risk`) plus `account_snapshot.json`
  (equity/balance/daily_pnl/open_positions). A mirror lives at
  `D:/QM/reports/portfolio/live_attribution_20260905_054540/` (`live_deals_normalized.csv`,
  `audit_live_book_inventory.json`, `validation.json`). `dxz_live_blend_reweight.py` already
  consumes a frozen deal export to blend backtest/live vol
  (`alpha=min(live_sessions/42,1)`).
- **FTMO demo:** `D:/QM/reports/ftmo/{clean_book_streams, slippage_stream, bar_exports}`
  feed `ftmo_book_readiness.py` / `ftmo_timebox_eval.py` / cost receipts.

### 6. Family/symbol/correlation caps are already parameterized and OWNER-scaled (§8 partly done)
Static caps are no longer literals: they live in
`config/concentration_tail_limits.v1.json` (`stop_risk_budget_pct 11.0`;
`caps_percent_of_budget` symbol 46 / asset_class 69 / family 57.5 / session_warn 69 /
session 80.5; tail `venue_daily_loss_limit_pct 5.0`, `maximum_fraction_of_daily_limit 0.8`),
OWNER-ratified 2026-09-13 (`OWNER-DEC-CONCENTRATION-SCALE-20260913`,
`OWNER-DEC-BOOK-RISK-11-20260913`) which raised the previous 40/60/50/60/70 set by 15 %.
`book_reoptimizer.py` still hard-codes the pairwise corr constraint `--max-corr 0.50`
(`book_reoptimizer.py:91,111`). **§8 gap:** the caps still *hard-reject* — `build_book_dxz.py`
refuses a proposal when `concentration.get("concentration_reject")` is non-empty
(`build_book_dxz.py:208`), and the config note says "no clean proposal is eligible until
status is OWNER_RATIFIED". §8 wants them converted to guardrails/warnings/risk-inputs, not
absolute blocks (though a separate safety cap may stay hard).

### 7. Test coverage is real and lands on the core (not on a future engine)
`tools/strategy_farm/tests/` covers `test_portfolio_kpi.py`, `test_portfolio_correlation.py`,
`test_portfolio_montecarlo.py`, `test_portfolio_common.py`, `test_portfolio_admission.py`
(+`_dl083_gate`), `test_portfolio_resize.py`, `test_concentration_tail.py`,
`test_book_build_guard.py`, `test_dxz_next_book_trigger.py`, `test_dxz_live_blend_reweight.py`,
`test_fund_score_current_population.py`, `test_ftmo_book_readiness.py`,
`test_assemble_stream_bundle.py`, `test_build_book_dxz_grid_union.py`,
`test_build_qualified_roster.py`, `test_dual_book_builders.py`, `test_marginal_*` via
`test_portfolio_q08_contribution.py`, etc. There is **no** test for a unified recomposition
engine, for the §70 "deterministic/reproducible from frozen inputs" property, or for the
25-gate having become a warning.

### 8. Structural gap vs §58/§7 — the pieces are not composed into one engine
No module ingests {eligible universe, incumbent, latest pipeline evidence, live evidence,
demo evidence, streams, mechanism, symbol exposure, venue constraints, operational readiness}
and emits, *per venue*, {KEEP/CHANGE, roster, weights, adds, removes, replaces, expected
metrics, marginal contribution, uncertainty, operational risk}. Today that output is spread
across `build_book_dxz.py` (DXZ roster/weights/diff), `dxz_next_book_trigger.py` (DXZ
KEEP/CHANGE only), `portfolio_admission.py` (single-candidate admission + swap),
`build_book_ftmo.py` + `ftmo_book_readiness.py` + `ftmo_timebox_eval.py` (FTMO), with no
FTMO KEEP/CHANGE trigger analogous to `dxz_next_book_trigger.py` (confirmed: only
`dxz_next_book_trigger.py` exists). Metric gaps against §7: **effective number of independent
bets** is computed nowhere (grep for `effective_number|diversification_ratio|independent bets`
returns nothing); **downside correlation** is only approximated by regime-split /
high-vol-subset correlation (`portfolio_correlation`, `marginal_contribution_eval`), not an
explicit downside-conditioned correlation; **holding time** is derivable from stream
`entry_time`/`time` but not aggregated into the metric vector; a single **uncertainty** and
**operational-risk** block per §58 does not exist as one object.

### 9. Directive-named hard blocker still live in code (§4, §68B, §70)
`book_build_guard.py:31` `MIN_QUALIFIED_PAIRS = 25`, enforced at `:239-241`
(`if qualified_pairs < MIN_QUALIFIED_PAIRS: reasons.append("qualified_pairs_below_minimum")`),
propagated to `require_book_build_allowed` (`:260-266`) which the DXZ/FTMO builders call. §4
supersedes the fixed 25-candidate trigger; §68B lists "remove fixed 25-candidate book
trigger"; §70 requires a regression test that "Q15 no longer hard-blocked solely by <25" and
that "DXZ portfolio evaluation works with smaller valid pool". Not yet changed.

### 10. No weekly-recomposition contract / automation yet (§6, §68H, §69)
There is no `docs/ops/CONTINUOUS_BOOK_EVOLUTION.md` and no weekly recomposition contract doc
(`ls docs/ops | grep -iE "recompos|CONTINUOUS_BOOK"` → only an unrelated 2026-07-23 mail doc).
No scheduled task implements the Friday-cut → Saturday-analysis → cross-review →
Sunday-recommendation → OWNER-handoff loop. The FTMO side has
`docs/ops/FTMO_ACCELERATION_2026-09-09.md` (a ≤5-pair pilot that explicitly keeps the 25-rule
for the regular builder — now superseded by §4).

## Drift table

| Topic | Doc/Vault/contract says | Runtime / code says | Path |
|---|---|---|---|
| Book-build gate | §4 supersedes the fixed 25-candidate trigger; §68B "remove" | `MIN_QUALIFIED_PAIRS = 25` still hard-rejects | `book_build_guard.py:31,239` vs directive §4/§68B |
| Concentration caps | §8: convert static caps to guardrails/warnings/risk-inputs | `concentration_reject` non-empty → proposal refused | `build_book_dxz.py:208`; `config/concentration_tail_limits.v1.json` note |
| §7 metric set | requires "effective number of independent bets" | not computed anywhere | grep `effective_number|diversification_ratio` → 0 hits |
| §58 KEEP/CHANGE both venues | required for DXZ and FTMO | only `dxz_next_book_trigger.py` exists; no FTMO analog | `ls portfolio/ | grep next_book` |
| Weekly recomposition | §6/§68H core business process + automation | no contract doc, no scheduled loop | `ls docs/ops | grep recompos` → none |
| FTMO probability contract | authoritative engine for FTMO fitness | `status: PENDING_OWNER_RATIFICATION`, `class: ROT` | `config/ftmo_probability_contract.v1.json` |
| Incumbent stream default | current DXZ book | builders default to stale July `dxz_final_20260719` | `assemble_stream_bundle.py:8` (defect D4) |
| DXZ v2 book | proposal `APPLY_RECOMMENDED` (28 sleeves) | live book is still 24-sleeve July manifest | `analytic_preview_manifest_28_r11.json` vs `portfolio_manifest_live_24sleeve_20260724.json` |

## Open questions strictly requiring OWNER

None new. (Two pre-existing ROT items are noted, not raised: ratification of
`ftmo_probability_contract.v1.json` and application of any recomposition output to the live
DXZ book / AutoTrading remain OWNER ceremonies — unchanged by this audit.)

## Recommended actions (for the implementing phases)

**Phase B — remove the superseded hard blocks (test-first, §68B/§70):**
1. Convert `book_build_guard.py:31,239-241` `MIN_QUALIFIED_PAIRS` from a fail-closed gate into
   a graded guardrail: keep `qualified_pairs` in the result, emit a `warnings` entry when
   below a configurable floor, but do not set `allowed=False` on count alone. Preserve all
   other fail-closed reasons (unqualified/invalid pairs still block). Add regression tests
   `tests/test_book_build_guard.py`: "small valid pool builds", "invalid candidate still
   fails closed".
2. In `build_book_dxz.py:208` (and the FTMO builder), demote `concentration_reject` from a
   refusal to a structured `concentration_warnings` block feeding portfolio risk inputs;
   retain a *separate*, explicitly-named hard safety cap (e.g. venue daily-loss tail) that
   still blocks. Add a §70 test: "cap warnings do not silently become a no-op risk analysis".

**Phase E — build the recomposition engine as a thin composition over existing modules.**
Create `tools/strategy_farm/portfolio/recompose/` (new subpackage; reuse, do not reimplement):
- `frozen_snapshot.py` — schema `qm.recompose-frozen-inputs/v1`: pins `as_of`, `venue`,
  `git_commit`, `seed`, and for every input a sha256 (each eligible pair: identity
  `ex5_sha256` + stream `content_sha256` + setfile sha; incumbent roster+weights sha; live
  deal-export sha (T_Live `live_deals_normalized.csv`); demo evidence sha; contract + config
  shas). This is the §70 "reproducible from frozen inputs" object; reuse
  `assemble_stream_bundle.py` binding logic and `portfolio_freeze_gate.py` for the input-SHA
  gate. Test: two runs from the same snapshot produce byte-identical output.
- `metrics.py` — assemble the full §7 vector by calling `portfolio_kpi`,
  `portfolio_correlation`, `concentration_tail`, `marginal_contribution_eval`,
  `dxz_live_blend_reweight`; ADD `effective_number_of_bets` (ENB = 1/Σ wᵢ² on risk
  contributions, or diversification ratio Σwᵢσᵢ / σ_portfolio) and an explicit
  `downside_correlation` (correlation conditioned on book-down days). Add `holding_time`
  aggregation from stream `entry_time`/`time`.
- `dxz_fitness.py` / `ftmo_fitness.py` — §57 venue objective functions (DXZ:
  return/maxDD, consistency, ENB, tail robustness; FTMO: P(pass) via
  `challenge_firstpassage.py` / `ftmo_timebox_eval.py`, daily-loss & total-loss survival,
  drift, density, cost + swap burden).
- `decide.py` — emit the §58 output object per venue {KEEP/CHANGE, roster, weights, adds,
  removes, replaces, expected metrics, marginal contribution, uncertainty, operational risk}.
  Reuse `dxz_next_book_trigger.py` for DXZ KEEP/CHANGE; add `ftmo_next_book_trigger.py`
  (the missing FTMO analog).
- `materiality.py` — the §59 rule as one computable predicate (below).

**§59 materiality / anti-churn as a computable spec** (`materiality.py`). For a proposed
change (swap/add/remove) declare it MATERIAL only when ALL hold; default is KEEP (§6):
- `expected_improvement`: Δ(venue fitness) ≥ τ_improve. Reuse the ratified DXZ rule (OOS
  Sharpe +0.06 AND ΔmaxDD ≤ +0.05 pp — `dxz_next_book_trigger.py`); FTMO: ΔP(pass) ≥ τ_pass.
- `confidence`: block-bootstrap CI of Δ(fitness) excludes 0 at level α (reuse
  `portfolio_montecarlo` / `portfolio_correlation` bootstrap infra, seeded).
- `downside_risk`: Δworst-day ≥ 0 (not worse) AND ΔmaxDD ≤ ε.
- `model_uncertainty`: IS/OOS consistency ≥ threshold (reuse `dxz_weight_oos_validation.py`).
- `live_uncertainty`: if incumbent has live evidence, live-blended vol within X % of
  backtest (reuse `dxz_live_blend_reweight.py`).
- `switching_cost`: estimated turnover cost (spread+commission+swap from streams) <
  expected_improvement over the decision horizon.
- `operational_complexity`: bounded op-risk score (new symbol / new mechanism / new venue
  each add points; above budget ⇒ not material).
- **Economic band:** even if the CI excludes 0, reject churn when |Δfitness| below a minimum
  materiality band (statistical ≠ economic significance).

**What can be computed TODAY (no new data needed):**
- **DXZ:** full 28-sleeve recomposition is already computed and reproducible
  (`analytic_preview_manifest_28_r11.json`, `reproduce_with` command); all §7 metrics except
  ENB and downside-correlation are derivable now from the sealed streams in
  `dxz_v2_20260913/streams_v2b/QM/q08_trades/`; `dxz_next_book_trigger.py` can classify
  KEEP/CHANGE from the OOS comparison; live blend is available from
  T_Live `live_deals_normalized.csv` (261 deals since 2026-04-24). ENB and
  downside-correlation are the only new metrics to add for a complete DXZ §7/§58 output today.
- **FTMO:** `ftmo_book_readiness.py` + `ftmo_timebox_eval.py` + `challenge_firstpassage.py`
  can compute P(pass), first-passage time, and daily/total-loss survival from
  `D:/QM/reports/ftmo/clean_book_streams`; cost/swap from `.../slippage_stream` + native cost
  receipts. Caveat: `ftmo_probability_contract.v1.json` is `PENDING_OWNER_RATIFICATION`
  (ROT) — the numbers are computable but the decision contract is not sealed.

**Phase H — durable outputs (§69):** create `docs/ops/CONTINUOUS_BOOK_EVOLUTION.md` and a
weekly recomposition contract, and a scheduled Friday-cut → Sunday-recommendation task, once
the engine (Phase E) exists.
