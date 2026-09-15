# Continuous Book Evolution — Canonical Operating Model

**Status:** CURRENT (canonical operating model). **Authority:** OWNER-DEC-CBE-20260915.
**Directive:** `docs/ops/evidence/2026-09-15_continuous_book_evolution/owner_directive_verbatim.md`.
**Decision record:** `decisions/2026-09-15_owner_continuous_book_evolution.md`.
**Supersedes:** WAY-TO-25 as a business target (§3), the fixed 25-candidate book trigger (§4),
the global "drain-everything-first" doctrine (§23), and the mandatory Q17 min-lot / fixed 14-day
burn-in (§10). Historical records of those rules remain available and are marked SUPERSEDED, not
deleted.

This document is the single canonical description of how QuantMechanica builds and evolves its
two production books. Where an older doc conflicts, this document and the decision record win.

---

## 1. North star

QuantMechanica is a systematic trading company, not a backtesting project, an EA collection, a
strategy-count project, or a pipeline-drain project (§73). The objective is **validated expected
economic improvement of the DarwinexZero and FTMO books** — not the number of Strategy Cards,
tested EAs, tickets, AI calls, pipeline rows, or any candidate-count milestone (§0).

Two economic engines:

- **ENGINE A — DarwinexZero (`DXZ_BOOK`)** — LIVE, a production portfolio. Job: sustainable
  returns, controlled drawdown, genuine diversification of risk sources, operational robustness,
  continuous improvement, increasing attractiveness for external allocation / D-Score (§2).
- **ENGINE B — FTMO (`FTMO_BOOK`)** — the payout engine, currently in Demo / validation. Path:
  Demo → serious two-week validation → OWNER purchase decision → 100k 2-Step Challenge →
  (Verification) → funded account → payouts → scale (§11). Acceleration is real but must not
  become gambling on paid challenges: **one paid challenge, passed with the highest realistically
  achievable confidence, beats repeated fast failures** (§2, §14, §15).

## 2. Two permanently evolving books

QuantMechanica operates **two living books**, related through shared research and infrastructure
but **not the same optimization problem** (§5). Every suitable candidate eventually has
independent `DXZ_FITNESS` and `FTMO_FITNESS`; the result of the pair may be DXZ-only, FTMO-only,
both, or neither. Never assume a Darwinex survivor is automatically a good FTMO strategy, and
never force the FTMO portfolio to mirror DXZ (§5).

**The portfolio is the product (§7).** EAs are not optimized in isolation from their portfolio
role. A lower standalone-PF strategy may materially improve diversification, drawdown, tail
behaviour, consistency, or the effective number of independent bets; a high-PF strategy that
duplicates an incumbent may add almost nothing. Evaluate **marginal portfolio contribution**.

## 3. Venue fitness layers (§57)

Each candidate is scored against two explicit venue-fitness layers. Portfolio calculations are
deterministic; the AI interprets the result (§58).

### DXZ_FITNESS
Optimize portfolio-level: sustainable return; drawdown; consistency; diversification; tail
robustness; allocation / D-Score suitability; long-term capital attraction.

### FTMO_FITNESS
Optimize: challenge survival; probability of eventual pass; daily-loss survival; total-loss
survival; stable positive drift; **time-to-target as a secondary objective**; trade density; cost
burden; swap burden; payout suitability. **OWNER priority for FTMO: probability of success first,
speed second** (§15, §57). Scalping (§18) and trailing-stop systems (§19) are expressly allowed
and may be particularly valuable for FTMO; evaluate actual net economics (spread, commission,
slippage, fill realism, stop-distance restrictions, robustness across execution regimes).

FTMO may need **completely different strategies** than DXZ — robust higher frequency, short
holding time, low overnight/swap exposure, controlled intraday risk, predictable stops, rapid
recovery, good opportunity density (§17). A strategy may be valuable for FTMO and irrelevant to
DXZ; that is acceptable.

## 4. Weekly book recomposition (core business process, §6, §61)

Every trading week ends with a portfolio re-evaluation. The relevant question is **not** "did we
receive new strategies?" but **"has the evidence changed enough that the optimal portfolio
decision changed?"** (§6).

**The weekly default is KEEP** — change only when material evidence supports improvement (§6,
§59). Valid weekly outcomes (§6):

`KEEP` · `ADD SLEEVE` · `REMOVE SLEEVE` · `REPLACE SLEEVE` · `CHANGE RISK WEIGHT` ·
`PLACE ON PROBATION` · `PROMOTE` · `RETIRE` · `CONTINUE OBSERVATION` · `NO VALID CHANGE`.

For every proposed DXZ change Fable must answer (§9): what exactly changes; what evidence changed;
what the challenger contributes; which incumbent is displaced; what improves at portfolio level;
what could become worse; is the improvement material; what is the confidence; what is the
operational risk. Do not change the book for cosmetic optimization.

### Weekly company operating rhythm (§61)

- **Mon–Fri:** factory validates candidates; external + internal research progresses; Kimi
  researches; Fable commissions new hypotheses; live and Demo evidence accumulate; blockers are
  repaired; portfolio analytics are updated. Pipeline runs **continuously** — it is not a global
  drain barrier (§23). Two objectives run at once: **frontier progression** (advance promising
  candidates toward book eligibility) and **backlog hygiene** (resolve stale items, infra
  failures, unknown dispositions as capacity permits). Thousands of old early-stage items must
  never globally block a material live portfolio improvement (§23).
- **Friday after market close:** create the **immutable weekly evidence cut**; freeze / reconcile
  the inputs for the weekend portfolio analysis (§61). This is the input-freeze point of the
  recomposition contract (§7 below).
- **Saturday:** compute DXZ incumbent vs challengers, FTMO incumbent vs challengers, portfolio
  alternatives, risk changes, marginal contribution, robustness; cross-review material proposals
  (cross-vendor where possible, §52).
- **Saturday night / Sunday:** Fable produces final venue recommendations and prepares all
  technical artifacts (setfiles, manifests, deployment actions — prepared, not executed).
- **Before market open:** OWNER receives only the required decisions / actions. After OWNER
  action, verify runtime identity and state. Repeat every week.

## 5. Materiality / anti-churn (§59)

Weekly review does **not** imply weekly change. A proposed swap must quantify: expected
improvement; statistical / economic confidence; downside risk; model uncertainty; live
uncertainty; switching cost; operational complexity. Tiny theoretical optimization must not cause
unnecessary portfolio churn.

**The computable materiality framework is Phase E (portfolio engine) — PENDING.** Until the
deterministic materiality spec lands in the continuous portfolio-recomposition engine
(`tools/strategy_farm/portfolio/…`, Phase E), materiality is applied as documented judgment against
the criteria above with the weekly default of KEEP. This section is the contract that Phase E must
make computable: a swap is *material* only when the quantified expected improvement exceeds the
combined switching + operational + uncertainty cost with adequate confidence.

## 6. Marginal-contribution evidence set (§7)

Evaluate at minimum: expected return; realized/simulated volatility; max drawdown; tail loss;
Sharpe or equivalent; marginal Sharpe; correlations; downside correlations; trade overlap;
session overlap; symbol exposure; strategy mechanism; family exposure; regime exposure; trade
frequency; holding time; transaction cost; swap; execution uncertainty; effective number of
independent bets.

**Old static caps are risk inputs, not hard rules (§8).** The former family≤3 / symbol≤2 /
pairwise |r|<0.5 caps are converted to default guardrails / warnings / diagnostics / portfolio
risk inputs. Measure **real economic dependence** — trade overlap, return dependence, tail
dependence, timing dependence, mechanism similarity, common-factor exposure — rather than a
label. Do not replace the old static caps with another arbitrary set of permanent caps;
portfolio-level risk is the real constraint. (Enforcement detail and the ROT_SEALED 0.50
book-admission correlation cap: see `docs/ops/RULE_EFFECTIVENESS_AUDIT_2026-09.md` §4–§6.)

## 7. Weekly recomposition contract (skeleton)

The recomposition is a deterministic process (§58) whose interpretation is done by the AI. Its
computable form is Phase E; this skeleton is the binding contract for that build.

- **Inputs (frozen at the Friday market-close cut):** eligible candidate universe; incumbent DXZ
  and FTMO books; latest pipeline evidence (through the Friday cut); live evidence; Demo evidence;
  trade / equity streams; strategy mechanism; symbol exposure; venue constraints; operational
  readiness. Inputs are **immutable once cut** — the weekend analysis must be reproducible from
  the frozen inputs alone (§70: weekly recomposition is deterministic/reproducible from frozen
  inputs).
- **Outputs (separately for DXZ and FTMO, §58):** `KEEP / CHANGE`; recommended roster; proposed
  weights; additions; removals; replacements; expected portfolio metrics; marginal contribution;
  uncertainty; operational risk. Plus the weekly outcome label from §4.
- **Where artifacts live:** `D:/QM/reports/book_evolution/<ISO-week>/` — e.g.
  `D:/QM/reports/book_evolution/2026-W38/` for the week ending 2026-09-20. Each week's directory
  holds the frozen input manifest (with hashes), the deterministic engine output for both venues,
  the cross-review notes, and the final Fable recommendation package handed to OWNER.
- **Scheduled task names (to be created in Phase H — weekly automation, §68H):**
  `QM_BookEvolution_FridayEvidenceCut` (Fri after close → freeze inputs to the ISO-week dir),
  `QM_BookEvolution_SaturdayAnalysis` (Sat → deterministic engine + cross-review),
  `QM_BookEvolution_SundayRecommendation` (Sun → final Fable recommendation + OWNER handoff),
  and a post-OWNER `QM_BookEvolution_RuntimeVerify` (verify runtime identity/state after OWNER
  action). These names are reserved here; the tasks themselves are Phase H work and do not exist
  yet.

## 8. Q17 as evidence-based live introduction / probation (§10)

The historic universal **mandatory min-lot 14-day** live burn-in is **SUPERSEDED**. Mandatory
min-lot does not automatically produce meaningful evidence, and a fixed 14-day wait must not
automatically prevent weekly portfolio evolution merely because it historically existed.

Q17 is refactored into an **evidence-based live introduction / probation / deployment stage**.
Appropriate initial live risk depends on the following decision inputs (§10):

- amount of validated historical evidence,
- novelty,
- strategy tail risk,
- execution uncertainty,
- broker-equivalence confidence,
- current portfolio risk,
- available live evidence,
- liquidity,
- expected trade frequency.

Valid introduction choices: intended full portfolio weight · reduced probation weight · staged
risk increase · incumbent/challenger parallel observation · no introduction. **Min-lot is one
option, never a procedural checkbox** — any reduced-risk probation must carry an explicit
evidence/risk reason. The KS-test kill-switch and the news-calendar staleness gate are unrelated
safety controls and are retained. See the rewritten Q17/P10 section of
`docs/ops/PIPELINE_V5_SUB_GATE_SPEC.md` and `docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md`.

## 9. Live and money authority (§64)

Fable may autonomously: research; analyze; create hypotheses; route AI tasks; implement approved
reversible system improvements; build portfolio alternatives; recommend final portfolio
composition; prepare setfiles; prepare manifests; prepare deployment actions; prepare FTMO
purchase analysis.

**OWNER retains authority over** (never automated): paid FTMO challenge purchase; buying
additional paid accounts; **live AutoTrading activation**; irreversible live account actions;
other financial purchases unless separately delegated. Purchase and AutoTrading cannot occur
through automation (§70/§71); no AI seat buys, upgrades, or renews any subscription. The desired
operating model: Fable does the work; OWNER receives decision + evidence + recommendation + exact
action, and interaction is kept minimal (§64).

## 10. The Sunday 2026-09-20 ceremony under this model

The book-build "ceremony" is no longer a one-time WAY-TO-25 gate; it is the **first weekly
recomposition under the continuous model** (ISO week `2026-W38`, decision window Fri 2026-09-18
close → Sun 2026-09-20 before Monday open). Concretely for that Sunday:

1. **Friday cut (2026-09-18):** freeze the week's evidence into
   `D:/QM/reports/book_evolution/2026-W38/` — incumbent DXZ live book, incumbent FTMO Demo book,
   the currently valid candidate pool (no fixed 25-count gate — evaluate whatever valid pool
   exists, §4), and the frozen input manifest with hashes.
2. **Saturday:** compute DXZ incumbent vs best current DXZ alternative and FTMO incumbent vs best
   current FTMO alternative (deterministic engine, or documented judgment against §6/§7 until the
   Phase E engine is live); cross-review any material proposal.
3. **Sunday:** Fable produces the two venue recommendations with the §4/§9 answers and the
   materiality/anti-churn justification (§5). The default is **KEEP unless material evidence
   supports improvement** — for DXZ this means keep the live book unless a challenger materially
   improves portfolio-level economics; for FTMO the honest current state is that no frozen
   intended-challenge portfolio has completed a representative rule-faithful two-week demo, so the
   FTMO recommendation is expected to be `CONTINUE DEMO` / `RECOMPOSE` rather than a purchase (see
   `docs/ops/FTMO_DEMO_VALIDATION_CONTRACT.md` and `docs/ops/FTMO_CHALLENGE_READINESS.md`).
4. **Before Monday open:** OWNER receives only the required decisions. The OWNER book-order
   artifacts already exist for both venues (`decisions/2026-09-13_owner_book_order_dxz.md`,
   `decisions/2026-09-14_owner_book_order_ftmo.md`); live activation / AutoTrading / any FTMO
   purchase remain OWNER-only (§9).

Because the fixed-25 trigger is superseded and already satisfied (`qualified_pairs=26`), the
2026-09-20 decision is about **book quality and marginal contribution**, not reaching a count.

## 11. What this model preserves (not weakened)

This operating model does **not** authorize weak validation (§22, §71). The pipeline remains the
validation engine and the final judge: real-tick testing, deterministic execution, IS/OOS
separation, walk-forward, robustness, parameter plateaus, stress testing, multiple seeds where
economically meaningful, statistical validation, news analysis, evidence lineage, operational
verification. Do not lower any criterion to create PASSes; improve efficiency only when the same
evidence quality can be achieved more intelligently (§22). Historical verdicts, trade streams,
decisions, and immutable evidence are never deleted or rewritten (§71).

## 12. Related canonical artifacts

- `decisions/2026-09-15_owner_continuous_book_evolution.md` — the decision record (OWNER-DEC-CBE-20260915).
- `docs/ops/RULE_EFFECTIVENESS_AUDIT_2026-09.md` — per-rule audit and dispositions (§21).
- `docs/ops/FTMO_DEMO_VALIDATION_CONTRACT.md` — the two-week Demo validation contract (§12, §69).
- `docs/ops/FTMO_CHALLENGE_READINESS.md` — the living FTMO readiness view (§62, §69).
- `docs/research/AUTONOMOUS_EDGE_DISCOVERY.md` — internal edge discovery programme (§38–§54, §69).
- `docs/ops/PIPELINE_V5_SUB_GATE_SPEC.md` (Q17/P10 section) and
  `docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md` — evidence-based Q17 introduction.
- Vault: `08 Current State/Current Objective`, Mission Control documentation, `03 Pipeline/Q15..Q17`
  — updated to this model (§65).
