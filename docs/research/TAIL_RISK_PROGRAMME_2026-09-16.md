# TAIL_RISK Programme — aggressive strategy families (research + specification)

**Authority:** OWNER-DEC-D3-20260915 (directive 3 §17 allowed families, §18 risk contract,
§19 diversification must be proven, §20 one EA must not destroy the account, §21 positive vs
negative pyramiding, §43-F tail-risk engine); OWNER interim directive §7–§8 (TAIL_RISK
programme for aggressive strategy families; joint-tail protocol), executed under Kimi's
interim OWNER_DIRECT_SESSION_DELEGATION (2026-09-15).
Verbatim: `docs/ops/evidence/2026-09-15_continuous_book_evolution/owner_directive_3_max_factory_utilization_verbatim.md`.
**Status:** RESEARCH + SPECIFICATION. No EA implementation, no economic validation, no
verdict/gate/DB writes. Nothing here approves, sizes, deploys, or authorizes any weight.
**Companion doctrine (binding, merged ba6-3 2026-09-15):**
`docs/research/PORTFOLIO_TAIL_RISK_RESEARCH.md` (10 metrics, 4-part acceptance rule, wave-2
engine contract) and `docs/research/STRATEGY_ELIGIBILITY_V2.md` (§18 risk contract schema).
**Machine-readable companion:** `tools/strategy_farm/config/tail_risk_families.v1.json`
(schema `qm.tail-risk-families/v1`), schema-tested hermetically by
`tools/strategy_farm/tests/test_tail_risk_families_config.py`.

---

## 1. Purpose and alignment

Directive 3 §17 explicitly allows positive pyramiding, negative pyramiding, martingale,
bounded grid and bounded recovery as research families; §18 requires every tail-amplifying
mechanism to expose a deterministic bounded risk contract; §19 forbids *assuming*
diversification across aggressive sleeves — it must be measured, and until the wave-2 engine
exists an aggressive multi-sleeve book is `EVIDENCE_MISSING`, never "diversification proven".

This programme is the family-level input to that measurement system. It defines:

1. a family schema `qm.research-tail-risk-family/v1` (§3);
2. four fully-specified aggressive families, each carrying a complete deterministic risk
   contract in the existing `qm.strategy-risk-contract/v1` schema (§4–§7);
3. a joint-tail protocol (§8) specifying exactly how multiple aggressive sleeves are tested
   for hidden common ruin modes, aligned metric-by-metric with
   `PORTFOLIO_TAIL_RISK_RESEARCH.md` §2/§4/§5;
4. the machine-readable config + stress matrix consumed by the future wave-2 engine (§9).

Boundaries (unchanged from the doctrine): read-only over sealed evidence + demo journal; no
farm-DB writes, no terminal starts, no book construction, no live weights; FTMO demo and
T_Live are read-only inputs. Any threshold in this document or its config is a §30
economic-selection change: **proposed, pending OWNER ratification** — counterfactual first,
versioned contract, tests, reversible; never a gate-integrity change.

## 2. Live-book context (why these bounds)

Reference frame: `D:\QM\reports\state\book_evolution_dxz.json` (2026-W38) — incumbent
`live_24`, 24 sleeves, all currently passive-style, total planned stop risk 9.7499% against
the ratified 11.0% stop-risk budget (`concentration_tail_limits.v1.json`, OWNER-ratified
2026-09-13). Venue budgets: DXZ daily-loss limit 5.0% × 0.8 fraction = **4.0% effective
joint daily-loss budget**; per-sleeve worst fraction 0.05 → 0.55% planned worst-case stop
risk per sleeve. The FTMO pocket is the session-flat H-CW style (`QM5_41475`,
`strategy-seeds/sources/QM-RESEARCH-2026-0002/H_CW_card.md`: zero overnight exposure, hard
daily −1%/weekly −2% breaker, fail-closed news filter).

Consequences used throughout this programme:

- Every family basket-loss bound is set **inside** the venue budgets (max 2.0%), so one
  terminal basket event cannot by itself reach the 4.0% effective daily-loss budget — the
  residual headroom is exactly what the passive book and same-day P&L consume.
- FTMO evaluation is admissible **only** for session-flat variants (no gap/weekend tail);
  martingale is excluded from FTMO at programme stage entirely.
- Unit convention: family contracts are symbol-agnostic. `risk_unit` = the equity risk of
  the initial leg at its reference stop (≤ 0.25% of equity); per-symbol lot translation
  happens at card/intake time. `max_basket_exposure`/`max_gross_notional` are expressed in
  aggregate level-lot units relative to the initial leg.

## 3. The family schema — `qm.research-tail-risk-family/v1`

Each family object (machine form in the config; prose form below) carries:

| Field | Meaning |
| --- | --- |
| `schema` | Const `qm.research-tail-risk-family/v1`. |
| `family_id` | `positive_pyramiding` / `negative_pyramiding` / `bounded_martingale` / `bounded_grid_recovery`. |
| `research_status` | `SPECIFICATION_ONLY_NO_EA` — no EA exists for any family; evidence fields are `EVIDENCE_MISSING` **by design**, not by oversight. |
| `mechanism_flags` | Tokens from `strategy_risk_contract.MECHANISM_FLAGS`; tail-amplifying families draw only from `TAIL_AMPLIFYING_FLAGS`. |
| `tail_amplifying` | Mirrors the doctrine: false only for positive pyramiding (§21 of the directive; Eligibility V2 §9). |
| `contract` | A **complete** `qm.strategy-risk-contract/v1` object (all §18 required fields, structurally valid per `strategy_risk_contract.validate_contract`, `is_unbounded == False`). |
| `mechanics` | Deterministic research spec: entry trigger, add trigger, size progression, exposure cap, basket stop, trailing logic, time bounds. |
| `expected_mechanism` | Why the family could make money. |
| `regime_of_failure` | The market regime in which the family's tail realizes. |
| `portfolio_role` | FTMO vs DXZ role and admission conditions. |
| `stress_scenarios` | References into the config stress matrix (§9). |
| `invalidation_criteria` | The explicit conditions under which the family is declared **dead**. |
| `evidence_status` | `SPECIFICATION_ONLY`. |

A complete JSON family example (Family C, trimmed notes) is given in §6; the other three
families follow the identical shape in the config file.

## 4. Family A — positive pyramiding (add to winners)

**One line:** add to winning positions in *decreasing* increments behind a never-widening
trailing giveback stop — convex trend capture whose tail is late-trend concentration, not
ruin.

| Aspect | Specification |
| --- | --- |
| Max levels | 3 |
| Size progression | 1.0 / 0.75 / 0.5 of the initial leg (custom), aggregate 2.25 legs |
| Exposure cap | ≤ 2.25 initial legs; ≤ 5% margin; initial leg ≤ 0.25% equity at reference stop |
| Basket stop | Hard 0.5% equity adverse bound **or** giveback of 50% of peak open basket profit, whichever first |
| Trailing logic | After level 2 fills, stop trails to breakeven-plus-costs; thereafter 1.0×ATR(14) behind peak favourable close; never widens |
| Expected mechanism | Exposure concentrates only after the tape confirms direction; expectancy = letting confirmed winners run, monetized by the giveback stop |
| Regime of failure | Trend exhaustion: parabolic reversal right after level 3 prints converts the largest position at the worst prices; choppy sessions cause repeated small giveback stops (death by sequence) |
| Stress test | `s01, s04, s05, s06, s08` (gap ×1, spread ×2/×3+slippage, news shock, combined) |
| Portfolio role | **FTMO primary** (session-flat envelope removes the gap tail a built-out basket fears most; stacks inside the 4% budget with the daily −1% breaker); DXZ valid but subordinate — the passive book already captures trend |
| Invalidation (family dead) | (a) sealed OOS + Q06 HARSH-class expectancy < +0.10R/basket or PF < 1.20; (b) simulated worst-day p95 > 2.5% equity at 0.25% initial risk or MC P(4% daily budget hit within 60d) > 2%; (c) giveback stop realizes more often than the profit target with no regime explanation; (d) joint-tail protocol shows its worst days coincide with the passive book's worst days |

Doctrine note: positive pyramiding is **not** tail-amplifying (Eligibility V2 §9) and needs
no contract at intake; the contract is carried anyway for programme uniformity and because
the joint-tail engine needs declared bounds for every sleeve it measures.

## 5. Family B — negative pyramiding (add to losers, hard-bounded)

**One line:** average into losers in *decreasing* increments (anti-martingale sizing) inside
a hard 1.0% equity basket bound — mean-reversion capture whose tail is regime change.

| Aspect | Specification |
| --- | --- |
| Max levels | 3 (hard bound) |
| Size progression | 1.0 / 0.75 / 0.5 — the worst price carries the *smallest* weight; deliberately the opposite of martingale |
| Exposure cap | ≤ 2.25 initial legs; ≤ 10% margin; hard 1.0% equity basket-loss bound |
| Basket stop | Hard 1.0% equity realized via `emergency_exit` (basket_sl); no "price must return" assumption survives it |
| Trailing logic | Recovery TP = blended average + 0.5×ATR(14); basket stop moves to breakeven at +0.5% equity open P&L; never widens |
| Expected mechanism | In range regimes adverse excursions are transitory; the bounded ladder monetizes reversion with an improved blended average |
| Regime of failure | Sustained directional trend: every add improves the average price but grows exposure exactly when reversion probability collapses; terminal loss realized at the 1.0% bound; a gap through the bound realizes *more* than 1.0% — that overrun is the family kill test |
| Stress test | `s01–s03, s04, s05, s06, s08` including the gap ×2/×3 overrun cases |
| Portfolio role | **DXZ primary research venue** (no FTMO daily-loss rule; ≤ 2 sleeves of this family at full bound inside the 11% budget); FTMO research-only via a session-flat variant with the daily breaker |
| Invalidation (family dead) | (a) ANY sealed stress realizing loss beyond bound + 0.25% allowance — the bound is not trustworthy; (b) terminal bound hit in > 5% of baskets on sealed data; (c) expectancy < 0 after Q06 HARSH-class costs; (d) joint-tail protocol: materially positive lower-tail dependence with the passive book's trend sleeves |

## 6. Family C — bounded martingale (finite levels, hard equity stop)

**One line:** a finite 4-level geometric ladder (1×/2×/4×/8×) whose terminal failure is
*defined in advance*: level 4 + adverse continuation flattens everything at a hard 2.0%
equity loss, and the family is banned from FTMO.

```json
{
  "schema": "qm.research-tail-risk-family/v1",
  "family_id": "bounded_martingale",
  "mechanism_flags": ["martingale"],
  "tail_amplifying": true,
  "research_status": "SPECIFICATION_ONLY_NO_EA",
  "contract": {
    "schema": "qm.strategy-risk-contract/v1",
    "tail_amplifying": true,
    "max_levels": 4,
    "sizing_progression": {"type": "geometric", "multiplier": "2"},
    "max_open_positions": 4,
    "max_basket_exposure": "15",
    "max_gross_notional": "15",
    "max_margin_pct": 15.0,
    "max_basket_loss_pct": 2.0,
    "emergency_exit": {
      "type": "account_equity_stop",
      "equity_stop_pct": 2.0,
      "rule": "TERMINAL FAILURE: level 4 filled + adverse trade -> flatten ALL legs, realize <= 2.0% equity; same-session circuit breaker, no re-entry until next session. The sequence is finite; 'eventually price must return' is not an argument anywhere in this contract."
    },
    "gap_sensitivity": "NOT_EVALUATED",
    "spread_slippage_sensitivity": "NOT_EVALUATED",
    "worst_historical_sequence": {"max_adverse_levels": "EVIDENCE_MISSING", "max_drawdown_pct": "EVIDENCE_MISSING", "evidence": "EVIDENCE_MISSING"},
    "stress_sequence": {"scenario": "s08_combined_worst at level 4", "result_pct": "NOT_EVALUATED", "evidence": "EVIDENCE_MISSING"}
  }
}
```

| Aspect | Specification |
| --- | --- |
| Max levels | 4 (inside the programme's 3–5 finite envelope); there is no level 5 by construction |
| Size progression | geometric ×2 → level lots 1×/2×/4×/8×, aggregate 15 base units |
| Exposure cap | ≤ 15 base units sized so the **terminal realized loss incl. preregistered slippage allowance stays ≤ 2.0%** under `s08`; ≤ 15% margin |
| Basket stop | Recovery TP = blended average + 0.25×ATR(14); **terminal failure condition** as declared in `emergency_exit` |
| Trailing logic | Recovery TP tightens toward the blended average as levels fill; the equity boundary never moves |
| Expected mechanism | In bounded-oscillation regimes the ladder recovers on modest reversion; a regime filter must make full-ladder events rare while their cost stays pre-bounded |
| Regime of failure | The terminal condition itself: > 4×ATR(14) unilateral move without reversion; trend regimes and news shocks are the systemic carriers; cross-sleeve correlation of terminal events is the portfolio ruin mode |
| Stress test | `s02, s03, s05, s06, s07, s08` (gap ×2/×3, HARSH execution, news shock, margin spike, combined) |
| Portfolio role | **DXZ sole venue, max ONE sleeve at full bound** (two correlated ladders would consume 4% of the 11% budget); **FTMO excluded at programme stage** — a 2% terminal event plus same-day passive P&L can breach the 4% effective daily-loss budget |
| Gap/spread stress assumptions | gap = 2×/3× the sealed 99.5th-percentile symbol-class gap through the level-4 stop; spread ×3 with stop-overrun slippage on every forced exit; margin ×1.5 spike at max depth |
| Invalidation (family dead) | (a) terminal condition realized in > 2% of sealed baskets; (b) ANY sealed scenario realizing loss beyond 2.0% + 0.5% allowance (bound proven non-binding → dead, unbounded-recovery class); (c) margin cap breached before level 4 completes on any sealed path; (d) joint-tail protocol shows terminal events coincide across aggressive sleeves beyond independence |

## 7. Family D — bounded grid / recovery (ATR-spaced, finite, equity-bounded)

**One line:** a finite equal-unit recovery grid at 1.0×ATR(14) spacing with three ordered
exits — blended recovery TP, hard 1.5% equity boundary, 5-session time stop — first hit
wins.

| Aspect | Specification |
| --- | --- |
| Max levels | 5 grid levels, spacing 1.0×ATR(14), equal unit per level (flat) |
| Size progression | 1.0 / 1.0 / 1.0 / 1.0 / 1.0 — equal sizing keeps the tail linear (not geometric) so the equity boundary is reachable and meaningful |
| Exposure cap | ≤ 5 base units; ≤ 12% margin; hard 1.5% equity boundary; 5-session time stop |
| Basket stop / basket exit | Recovery TP = blended average + 0.25×ATR(14); equity boundary 1.5%; time stop 5 sessions; no weekend carry in the session-flat variant |
| Trailing logic | Recovery TP ratchets toward the blended average as deeper levels fill; the equity boundary never moves |
| Expected mechanism | Oscillating regimes: the grid harvests the range around the blended average; the recovery exit monetizes reversion-to-mean |
| Regime of failure | Unilateral trend traversal of all 5 levels (max exposure at max adverse prices, 1.5% boundary realizes; gap through the boundary realizes the overrun); same-symbol grids across sleeves stack into one deep synthetic basket |
| Stress test | `s01–s06, s08` |
| Portfolio role | **DXZ primary** alongside B (≤ 2 grid sleeves per symbol class with cross-sleeve grid-depth limits from the joint-tail engine); FTMO **conditional** — session-flat variant only |
| Invalidation (family dead) | (a) boundary realized in > 4% of sealed baskets, or ANY scenario realizing > 1.5% + 0.4% allowance; (b) median time-in-basket at max depth exceeds the 5-session time stop (grid becomes forced-loss inventory); (c) expectancy < 0 after Q06 HARSH-class costs or swap > 10% of gross P&L (H-CW convention); (d) joint-tail protocol: same-symbol grid depth breaches the common-symbol exposure budget under joint escalation |

## 8. Joint-tail protocol — do multiple aggressive sleeves diversify?

This is the exact procedure the wave-2 engine (directive §43-F; f1/f2 assigned to Fable per
`docs/ops/KIMI_INTERIM_HANDOFF_2026-09-18.md`) must implement. It tests the §19 question —
can individually aggressive sleeves form a safer total portfolio — against the 4-part
acceptance rule of `PORTFOLIO_TAIL_RISK_RESEARCH.md` §4. Normal-period correlation alone is
never sufficient; a Gaussian-copula baseline is a diagnostic, **never a safety argument**.

**Step 0 — data inputs (all read-only; farm DB via read-only handle):**
per-sleeve sealed trade streams (Q08 stress + Q14 head-to-head streams under
`D:/QM/strategy_farm/` + `D:/QM/exports`); interval equity / daily net per sleeve
(`portfolio/interval_equity_export.py`, `portfolio/ftmo_daily_net_export.py`); declared
bounds from each sleeve's `strategy_risk_contract.v1` + this config; news/gap windows from
`D:/QM/data/news_calendar` (factory evidence only, never a live source); FTMO demo journal
(read-only). **Known evidence gap (documented, not guessed):** intra-basket per-level state
is not universally captured in current sealed streams; basket depth is reconstructed by
open-position reconstruction from the trade stream, or the EA must emit a basket-depth
telemetry column (`PORTFOLIO_TAIL_RISK_RESEARCH.md` §3).

**Step 1 — per-sleeve tail objects.** From sealed streams: daily return series, worst-N=10
days, drawdown series, basket-depth path (reconstructed), margin consumption path.

**Step 2 — empirical joint tails.** For each pair and jointly: co-exceedance counts
P(R_i ≤ q_a, R_j ≤ q_a) at a ∈ {0.05, 0.025, 0.01} (metrics 1–2, 9 of the research doc).

**Step 3 — lower-tail dependence λ_L.** Non-parametric estimator from the empirical
co-exceedance function (CFG/log-periodogram class). A high λ_L at low Pearson r is the
common-ruin warning and a primary acceptance-rule-2 input.

**Step 4 — worst-day overlap.** Cross-sleeve coincidence of worst-N days vs an independence
permutation baseline (2000 seed-pinned permutations). Observed overlap materially worse
than the 95th permutation percentile fails part 2 (metric 8).

**Step 5 — correlation convergence, tail vs body.** Rolling pairwise correlation in
calm windows vs shock windows (bottom decile of an aggregate market-factor return); test
H0: ρ_tail ≤ ρ_body vs HA: ρ_tail > ρ_body per pair (metric 2). Divergence that survives
shock windows is the dangerous kind.

**Step 6 — block bootstrap of joint paths.** Circular block bootstrap of the joint daily
return matrix, block = 10 days, 2000 seed-pinned replications (mirrors the book-evolution
convention already ratified in `book_evolution_dxz.json`); emits the joint worst-day and
worst-sequence account-loss distribution vs the 4.0% effective daily-loss budget and the
11% stop-risk budget (metric 10 + acceptance part 1).

**Step 7 — joint basket escalation (the core aggressive-strategy metric).** From
reconstructed basket-depth paths: probability and depth of ≥ 2 sleeves at ≥ 60% and at 100%
of `max_levels` simultaneously, plus implied joint account loss vs each sleeve's
`max_basket_loss_pct` (metrics 1, 10). **Simultaneous recovery escalation:** P(one sleeve's
terminal/recovery escalation starts within ±2 sessions of another's).

**Step 8 — common exposure and margin.** Per bar: net + gross same-symbol exposure across
sleeves, worst simultaneous same-symbol basket depth (metric 3); common-session and
common-volatility buckets (metric 4); joint `max_margin_pct` consumption path with peak
under `s07`/`s08` (metric 6).

**Step 9 — gap and news scenarios, jointly.** Apply `s02`/`s03` across sleeves sharing a
symbol class or session: do baskets sit open into the same weekend/news gap; joint realized
loss vs the 4% budget (metric 5).

**Step 10 — DD clustering.** Inter-drawdown dispersion index vs the exponential (Poisson)
independence baseline; overdispersion = bunching (metric 7).

**Step 11 — Gaussian-copula tail comparison (baseline only).** Fit a Gaussian copula
(implied λ_L = 0); report divergence from empirical λ_L as a non-Gaussian-tail-dependence
diagnostic. Explicitly: no diversification claim may rest on it.

**Step 12 — acceptance evaluation.** All four parts of `PORTFOLIO_TAIL_RISK_RESEARCH.md` §4
must hold on sealed + demo data; proposed thresholds (pending OWNER ratification, §30, in
the config): λ_L ≤ 0.15 at α = 0.05; worst-day overlap ≤ independence p95; joint-escalation
probability ≤ 1% per quarter of simulation; joint worst-day ≤ 4.0% of equity; correlation
convergence Δ(tail − body) ≤ 0.2. Outcomes: PASS / FAIL / EVIDENCE_MISSING — with
EVIDENCE_MISSING the standing state until the engine exists. The engine additionally emits
the `tail_risk_reject` hard guard (joint-tail / venue-daily-loss breach = refusal;
per-dimension concentration advisory; data-validity fail-closed `unknown_report`).

## 9. Machine-readable config, stress matrix, and test

`tools/strategy_farm/config/tail_risk_families.v1.json` (schema `qm.tail-risk-families/v1`)
carries: the four family objects (each a full `qm.research-tail-risk-family/v1` with an
embedded, gate-valid `qm.strategy-risk-contract/v1`); the unit convention and the
read-only copy of the ratified book budgets; the **stress matrix** (base quantities
measured from sealed streams only: `base_gap` = 99.5th-percentile sealed symbol-class gap,
`base_spread` = 20-day median spread, slippage model `stop − max(1×spread, 0.1×ATR)`;
scenarios `s01`–`s08` with per-family application and pass criteria referencing each
family's own contract bounds; per-family slippage allowances); and the `joint_tail_protocol`
block (§8 as data: inputs, methods, proposed thresholds, acceptance rule, output contract).

`tools/strategy_farm/tests/test_tail_risk_families_config.py` — 16 hermetic tests (no DB,
no network): schema consts; exactly the four expected families; canonical mechanism flags
with correct tail-amplifying alignment (positive vs negative pyramiding distinct, per
directive §21); every embedded contract passes the **machine gate's own**
`strategy_risk_contract.validate_contract` and `is_unbounded`; finite levels everywhere;
progression shapes per family semantics; loss/margin bounds inside the book budgets;
invalidation criteria present; stress-matrix well-formedness (unique scenario ids, gap
ladder ×1/×2/×3, combined-worst applies to all families, family references resolve);
slippage allowances declared; joint-tail protocol read-only with all eleven methods,
copula flagged baseline-only, acceptance four-part, thresholds marked proposed; budgets
reference matches the ratified `concentration_tail_limits.v1.json`; and a negative test
that the config carries no verdict/gate/deploy keys. **Result: 16/16 pass** (`python -m
pytest tools/strategy_farm/tests/test_tail_risk_families_config.py -v`).

## 10. What this programme deliberately is NOT (and next actions)

**Not done here, by design:** no EA implementation for any family (cards + governed build
lanes come later, per family, after OWNER ratifies the family specs); no economic
validation (no backtest, no expectancy claims — all evidence fields are `EVIDENCE_MISSING`
until sealed runs exist); no engine implementation — the wave-2 tail-risk engine is
directive §43-F, f1/f2 for **Fable**; no DB writes, no verdicts, no gates, no book changes.

**Next actions (f1/f2 slot):**
1. *f1 (Fable):* wave-2 engine `portfolio/tail_risk_engine.py` per
   `PORTFOLIO_TAIL_RISK_RESEARCH.md` §5, consuming this config's family contracts + stress
   matrix for scenario definitions and the joint-tail protocol for its metric procedures;
   emit `D:/QM/reports/state/portfolio_tail_risk.json` with the `tail_risk_reject` hard guard.
2. OWNER ratification pass over the proposed thresholds (§30 procedure) before any PASS/FAIL
   is ever reported against them.
3. Family card authoring (one card per family, house format with provenance +
   `risk_contract:` reference) only after ratification; H-CW conventions (session-flat
   envelope, fail-closed news filter, shock/spread filters) are the style template.
4. Sealed stress runs (Q06 HARSH-class) per family to fill `stress_sequence`/`worst_historical_sequence`,
   then the joint-tail protocol over any candidate multi-sleeve aggressive set.
5. Until 1–4 exist: any aggressive multi-sleeve book remains `EVIDENCE_MISSING` for §19
   diversification and must not be presented as "diversification proven".
