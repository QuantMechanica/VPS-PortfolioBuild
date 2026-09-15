# Strategy Eligibility V2 — style-agnostic admission doctrine

**Authority:** OWNER-DEC-D3-20260915 (directive 3, sections 14–22, 37, 43D).
Verbatim: `docs/ops/evidence/2026-09-15_continuous_book_evolution/owner_directive_3_max_factory_utilization_verbatim.md`.
**Status:** BINDING doctrine for **new** strategy intake. Historical verdicts, sealed
evidence and dated decisions are untouched.
**Canonical vault projection:** `01 Identity/Strategy Eligibility & Tail-Risk Doctrine.md`
(hand-written) + Hard Rules annex 2026-09-15 (D3).
**Machine gate:** `tools/strategy_farm/card_intake_prescreen.py` +
`tools/strategy_farm/strategy_risk_contract.py` +
`tools/strategy_farm/config/strategy_risk_contract.v1.json`.

---

## 1. The doctrine in one line

**Strategy style alone is never a rejection reason. Uncontrolled ruin risk is.**

QuantMechanica historically rejected or discouraged entire strategy *styles* at intake.
Directive 3 §14 supersedes that. The pipeline (Q02–Q14) and the portfolio risk layer are
the judges of an EA; intake only screens for the things that are knowable at intake and that
are genuine integrity or bounded-risk requirements.

## 2. The only questions intake asks about a style (§14)

For every candidate, regardless of style:

1. **Is the strategy mechanical?** (finite, bounded parameters; executable from its spec alone)
2. **Is it testable?** (at least one DWX instrument; deterministic; sealed dev/OOS)
3. **Is its risk measurable?** (a tail-amplifying mechanism must expose a risk contract, §18)
4. **Is its risk bounded sufficiently for the intended portfolio?** (no uncontrolled ruin, §18/§20)
5. **Does the evidence support positive portfolio value?** (the pipeline decides, not the label)

## 3. Explicitly allowed strategy families (§17)

All of the following are valid research and strategy candidates and must **not** be rejected
because old QuantMechanica doctrine disliked the style:

scalping · high-frequency-enough mechanical intraday trading · trailing-stop systems ·
positive pyramiding (adding to winners) · negative pyramiding (adding to losers) · martingale ·
reverse / anti-martingale · bounded grid systems · bounded recovery systems · multiple
simultaneous positions · basket management · partial exits · break-even logic · time exits ·
session strategies · pattern filters · price-action filters · volatility filters · regime
filters · portfolio hedges · hybrids of the above.

Evidence decides. The controlled `mechanism_flags` vocabulary that encodes these lives in
`strategy_risk_contract.MECHANISM_FLAGS`.

## 4. The Machine Learning boundary remains (§15, Hard Rule 14)

- ML / advanced statistics **MAY** be used **offline** by the research system to discover
  mechanical relationships (clustering, feature importance, regime detection, hypothesis
  generation, cross-experiment analysis).
- ML remains **prohibited in the EA's trading decision engine.** Before a candidate enters
  Q00 it must be reduced to explicit mechanical rules: finite bounded parameters, deterministic
  entry/exit/risk/filter logic, **no** inference API, **no** model file, no online learning,
  no retraining, no adaptive black box. The final EA must be executable from its mechanical
  spec alone.
- This is unchanged by V2. Intake still fails closed with `PROHIBITED_MECHANICS:ML` on a
  card whose *runtime* uses ML (frontmatter `r4_ml_forbidden:false` / `ml_required:true`, or
  an affirmative ML term outside a `## Research provenance` section). ML-assisted *research
  provenance* is explicitly not an R4/HR14 concern.

## 5. No external source is required (§16)

A strategy does **not** require a book, video, paper, trader, website, or external author.
Original strategies from Fable, Kimi, OWNER, another authorized agent, or internal statistical
research are valid. **Provenance is still required** — do not confuse "no external source"
with "no provenance". Internally originated strategies use the `QM-RESEARCH://…` mechanism
(`docs/ops/INTERNAL_RESEARCH_SOURCE_CONTRACT.md`), which is source-agnostic on author and
fail-closed on a resolvable, hash-verified artifact. Intake continues to fail closed with
`INTERNAL_SOURCE_UNRESOLVED` on an internal card without a resolvable artifact.

## 6. The tail-risk contract (§18) — formal schema

Martingale-like logic is **not** automatically prohibited. **Uncontrolled ruin risk is
prohibited.** A *tail-amplifying* mechanism — **martingale, grid, negative pyramiding,
recovery, unbounded multi-position** — must expose a deterministic risk contract.

Formal schema: `tools/strategy_farm/config/strategy_risk_contract.v1.json`
(`schema: "qm.strategy-risk-contract/v1"`). Required fields:

| Field | Meaning |
| --- | --- |
| `tail_amplifying` (bool) | Declares the mechanism amplifies adverse exposure. |
| `max_levels` (int ≥ 1) | Max averaging/grid/scale-in levels per basket. `0` or `levels_unbounded:true` = infinite → rejected. |
| `sizing_progression` {type, multiplier} | flat / linear / geometric / custom + per-level multiplier. |
| `max_open_positions` (int ≥ 1) | Hard cap on simultaneous legs. |
| `max_basket_exposure` | Max aggregate basket exposure (lots / declared unit). |
| `max_gross_notional` | Max gross notional across legs (account currency). |
| `max_margin_pct` (0 < x ≤ 100) | Max margin consumption. |
| `max_basket_loss_pct` (0 < x ≤ 100) | Hard account-loss bound — the **ruin bound**. |
| `emergency_exit` {type, equity_stop_pct, rule} | Deterministic flatten rule. `type:none` with no loss bound → rejected. |
| `gap_sensitivity` | Behaviour through weekend/news gaps (or `NOT_EVALUATED`). |
| `spread_slippage_sensitivity` | Degradation under Q06 HARSH spread/slippage (or `NOT_EVALUATED`). |
| `worst_historical_sequence` {max_adverse_levels, max_drawdown_pct, evidence} | Worst observed adverse run. |
| `stress_sequence` {scenario, result_pct, evidence} | Preregistered stress result. |

**Hard rules encoded (§18):**
- **No infinite recovery sequence.** `max_levels ≤ 0` or `levels_unbounded:true` →
  intake `UNBOUNDED_RECOVERY`.
- **No "eventually price must return" without a bounded account-loss condition.** No equity
  stop (`emergency_exit.type == none`) **and** no positive account-loss bound
  (`equity_stop_pct` or `max_basket_loss_pct`) → intake `UNBOUNDED_RECOVERY`.
- A **hard portfolio-level safety boundary may substitute for individual-trade SLs** where the
  design requires basket management (a positive `max_basket_loss_pct` counts as the bound).

**Fail-closed intake reasons** (new, `card_intake_prescreen.py`):
- `RISK_CONTRACT_MISSING` — a tail-amplifying flag is declared (frontmatter `mechanism_flags`)
  or affirmatively described in the rules, without a valid contract (absent / unloadable /
  structurally invalid all fail closed identically).
- `UNBOUNDED_RECOVERY` — the contract loads and validates but declares infinite levels or no
  equity stop.

A card references its contract via frontmatter `risk_contract:` (a path, resolved relative to
the card). The sealed `strategy_card_v3` may additionally carry the additive `mechanism_flags`
+ `risk_contract` fields (§8 below).

## 7. Diversification must be proven, not assumed (§19) → wave-2 tail-risk engine

The OWNER wants QuantMechanica to investigate whether multiple individually aggressive
strategies (martingale / pyramiding / grid / recovery) can form a **safer, profitable total
portfolio through genuine diversification**. Do **not** assume this effect — normal-period
correlation alone is insufficient. The measurement design is
`docs/research/PORTFOLIO_TAIL_RISK_RESEARCH.md`. Diversification is accepted only when the
evidence supports it.

## 8. One EA must not be able to destroy the account (§20) — portfolio-layer requirements

Regardless of style, a single sleeve must not create uncontrolled account-terminating risk.
This is more valuable than banning a style label. The portfolio risk layer must be capable of:

| §20 capability | Existing code / config | Status |
| --- | --- | --- |
| limit sleeve risk | `portfolio/book_sizing.py`, `portfolio/portfolio_resize.py`; `concentration_tail` per-sleeve worst-fraction 0.05 | EXISTS |
| limit simultaneous basket risk | `portfolio/concentration_tail.py` (joint-tail divisor, common-tail); intake `max_open_positions`/`max_basket_exposure` bounds | PARTIAL — no cross-sleeve basket-escalation guard (wave-2) |
| limit account-wide open risk | `concentration_tail_limits.v1.json` venue daily-loss 5% × 0.8 fraction; `portfolio/risk_diagnostics.py` surviving hard guard | EXISTS |
| detect risk escalation | intake `max_levels` (declared), Q06 HARSH stress | PARTIAL — no runtime cross-sleeve escalation detector (wave-2) |
| stop further additions | EA-level fail-closed at `max_levels` (framework); risk contract declares the rule | PARTIAL — framework enforcement; portfolio-level stop is wave-2 |
| apply venue-specific constraints | `portfolio/ftmo_rule_contract.py`, `portfolio/ftmo_rules_engine.py`, venue daily-loss limit | EXISTS |

The PARTIAL items are the scope of the wave-2 tail-risk engine
(`PORTFOLIO_TAIL_RISK_RESEARCH.md` §5).

## 9. Positive vs negative pyramiding are distinct mechanisms (§21)

Never collapse the two into one generic "pyramiding" label — they are different mechanisms
with different tails and must be researched and flagged separately.

- **Positive pyramiding** (`positive_pyramiding`) — add to *winning* positions. Convex trend
  capture; risks are late-trend concentration and giveback. **Not tail-amplifying**; needs no
  risk contract.
- **Negative pyramiding** (`negative_pyramiding`) — add to *losing* positions. Mean-reversion
  capture, improved average price; risks are nonlinear tail exposure, margin escalation,
  regime failure. **Tail-amplifying**; requires a bounded risk contract.

Encoded as distinct tokens in `strategy_risk_contract.MECHANISM_FLAGS`; only
`negative_pyramiding` is in `TAIL_AMPLIFYING_FLAGS`. A direction-less "pyramiding" mention in
prose is deliberately **not** auto-flagged — the author must declare the direction.

## 10. Pattern filters are modular overlays (§22, policy)

Pattern filters are tested as **modular overlays** on a base strategy, not as monolithic
rejections. The measurement contract (base vs base+filter vs justified combinations; trade
reduction; expectancy; DD; regime effect; portfolio effect; proper ablation; a null/no-filter
baseline; multiple-testing control) is the fresh pattern-filter programme
(`docs/research/PATTERN_FILTER_CATALOG.md`, produced by directive §40/§44 — a sibling slice).
**Do not keep an arbitrary old "max N filters" rule as a Hard Rule unless evidence supports
it.** The existing DL-089 pattern-filter census (`docs/research/PATTERN_FILTER_WF_OPT_PLAN_V3_2026-08-21.md`)
is the current implementation; its selection rule remains ROT and is unchanged by this doctrine.

## 11. SUPERSEDED — where the old style prohibitions lived

The following carried style-based prohibitions. Each is superseded by OWNER-DEC-D3-20260915 to
the extent it rejected a *style*; the runtime-ML boundary (HR14) and bounded-risk requirement
survive.

| Location | Old text | Disposition |
| --- | --- | --- |
| `tools/strategy_farm/card_intake_prescreen.py` `_affirmative_prohibited_mechanics` | `PROHIBITED_MECHANICS` for HFT / GRID / MARTINGALE / AVERAGING_INTO_LOSERS | **SUPERSEDED-implemented (this slice)** — removed; ML kept; replaced by `RISK_CONTRACT_MISSING`/`UNBOUNDED_RECOVERY`. |
| `processes/qb_reputable_source_criteria.md` R4 ("no martingale runaway" default) | "No martingale-style runaway sizing" (DL-081 basket-stop exception) | **SUPERSEDED-implemented (this slice)** — append-only Annex 2026-09-15 (D3) generalizes DL-081 to the risk-contract requirement; runtime-ML unchanged. |
| `01 Identity/Hard Rules.md` (vault) | style prohibitions implied under HR14 family | **SUPERSEDED-implemented (this slice)** — Hard Rules annex 2026-09-15 (D3). |
| `docs/ops/EDGE_LAB_CHARTER_2026-05-22.md` line ~36 | "No prohibited techniques: no martingale, no grid, no averaging into losers." | **SUPERSEDED-annotated (this slice)** — banner added pointing here; historical text retained. |
| `tools/strategy_farm/governed_magic_allocator.py:374` | build-preflight `prohibited_technique:grid` | **NOT changed (out of slice scope)** — build-time allocator guard; revisit when the risk-contract-aware build path is wired (noted in slice report). |
| `tools/strategy_farm/agent_router.py:2351` | research brief text "no ML/grid/martingale" | **NOT changed (out of slice scope)** — a discouraging research prompt, not a rejection; noted in slice report. |
| `framework/V5_FRAMEWORK_DESIGN.md` risk table | already permissive (gridding/scalping/pyramiding allowed with constraints) | **No prohibition to remove** — the framework was already style-agnostic at the code level (grid ≤1% cycle risk, one-position-per-magic + opt-in AddToPosition). |

## 12. What is NOT changed

- Gate INTEGRITY rules (evidence integrity, provenance, look-ahead protection, holdout
  separation, deterministic execution, data validity) and verdict semantics.
- The runtime-ML boundary (HR14).
- Q13 optimization freeze, Q14 head-to-head, and the DL-089 pattern-filter selection rule.
- T_Live / FTMO / AutoTrading / live deployment / FTMO purchase authority (OWNER-only).
- Historical verdicts, sealed artifacts, dated decisions.
