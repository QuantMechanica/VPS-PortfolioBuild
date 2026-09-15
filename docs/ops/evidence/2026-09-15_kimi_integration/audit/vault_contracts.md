# CURRENT Binding Contracts — Audit for the ULTRACODE Directive (OWNER 2026-09-15)

**Scope:** Extract the *current* binding contracts relevant to (a) adding Kimi as a provider, (b) ML in research vs in EAs, (c) R1 source attribution, (d) quota/spend governance, (e) determinism-first, (f) research methodology + lessons-learned loop — and identify every place needing an **annex** (not a rewrite; historical evidence untouched).

**Mount / availability:** `G:/My Drive/QuantMechanica - Company Reference/` **is mounted**. Every requested Vault page exists and was read: `_HOME.md`, `START_HERE.md`, `01 Identity/Hard Rules.md`, `02 Org/AI Agent Routing and Role Contracts.md`, `02 Org/Company Structure.md`, `02 Org/Stehende Vollmacht Claude 2026-08-20.md`, `03 Pipeline/Pipeline Overview.md`, `04 Processes/Determinism Over LLM Calls.md`, `04 Processes/Research Methodology.md`, `04 Processes/Lessons Learned Loop.md`, `06 Infrastructure/AI Spend and Quota Governance.md`. Repo files read: `CLAUDE.md`, `tools/strategy_farm/config/gate_manifest.v4.json`, `docs/ops/OPERATING_RULES_2026-07-03.md`, `docs/ops/EDGE_LAB_CHARTER_2026-05-22.md`, `processes/qb_reputable_source_criteria.md`, `tools/strategy_farm/agent_router.py`, `tools/strategy_farm/config/agent_chain.v1.json`.

**Truth precedence applied:** code/runtime > repo contracts/decisions > Company Reference > historical docs. Where the Vault table and code registry cover the same fact, I cite the code and note that they currently agree.

**Read-only confirmation:** No files modified, no SQLite writes, no terminal64/worker actions, no T_Live access. `farm_state.sqlite` was not opened (not needed for a contract audit).

**Directive text itself — NOT FOUND locally.** A grep for `kimi|moonshot` and for a dedicated ULTRACODE decision file returned nothing in `decisions/`, `tools/`, `docs/` or the Vault. I therefore audited the **contracts the directive would amend**, not the directive. Its DL number / signed location is UNKNOWN.

---

## (a) Adding Kimi as a provider

**Kimi is absent everywhere.** `grep -rilE 'kimi|moonshot'` over `tools/ decisions/ docs/` returned only a binary PNG false positive; the Vault has no Kimi mention.

| Contract | Exact quote (≤40 w) | Path | Currently forbids/requires | ULTRACODE change → annex |
|---|---|---|---|---|
| **Code registry (source-of-truth)** | keys: `codex`, `claude`, `gemini`, `owner` | `tools/strategy_farm/agent_router.py:542-614` (`DEFAULT_AGENT_REGISTRY`) | Exactly four lanes exist; `agent_registry` table has fail-closed DB triggers ('requires canonical router generation'). No fifth provider is routable. | Add a `kimi` registry row (capabilities, `max_parallel`, `cost_rank`, `enabled`). Without this code change Kimi is unroutable regardless of Vault edits. |
| **Routing contract table** | "Aktueller Code gewinnt bei Abweichung von dieser Tabelle; die Seite ist dann zu aktualisieren." | `02 Org/AI Agent Routing and Role Contracts.md:22-31` | Canonical 4-row registry (codex/claude/gemini/owner). | Annex a Kimi row + its capability contract. |
| **agent_chain vendors + critic map** | "Seats: claude … codex … agy …" ; `by_creator_vendor` | `tools/strategy_farm/config/agent_chain.v1.json:4-46` | Cross-vendor Creator→Critic→Formatter defines only claude/codex/agy; each vendor has a critic list. | Add a `kimi` vendor block and insert Kimi into every `by_creator_vendor` critic list (and as an eligible creator). |
| **Cross-vendor critic annex** | "Creator … Critic = ein Seat eines ANDEREN Anbieters (Claude-Lane → Codex terra → agy → Claude opus …)" | `02 Org/AI Agent Routing and Role Contracts.md:142-153` | Names the exact vendor fallback chain; Kimi not present. | Extend annex to place Kimi in the cross-vendor rotation. |
| **Company Structure** | "QuantMechanica besteht aus einem OWNER, **drei** capability-basiert eingesetzten AIs …" | `02 Org/Company Structure.md:12-14`, actor table :18-27 | Fixes the org at three AIs (Claude, Codex, Antigravity). | Annex: three → four AIs; add Kimi actor row (Kernbeitrag / Keine Befugnis). |
| **CLAUDE.md roster** | "Codex and Antigravity (agy) are the other working agents; a deterministic capability router coordinates execution across all three." | `C:/QM/repo/CLAUDE.md` (top) | Roster = three agents. | Annex/refresh the roster line to include Kimi. |

**Note:** the code registry and the Vault table **currently agree** (both four lanes), so this is a clean add, not a conflict to reconcile — but all surfaces must move together or the code wins and Kimi "does not exist".

---

## (b) Machine learning — research vs EAs

The current contracts forbid ML **blanket in wording**, but two current documents already carry the exact EA-vs-tool distinction ULTRACODE wants to generalize.

| Contract | Exact quote (≤40 w) | Path | Currently forbids/requires | ULTRACODE change → annex |
|---|---|---|---|---|
| **HR14 (hard rule)** | "ML ist verboten … Machine Learning, Neural Networks, adaptive Parameter — alles verboten. Ausnahme: nur wenn OWNER explizit und schriftlich eine Ausnahme gewährt." | `01 Identity/Hard Rules.md:78-79` | Blanket, EA-agnostic ML ban; OWNER-written exception only. | **OWNER-signed annex** (Amendments-2026-09) scoping HR14 to *ML in EA decision engines*; offline research ML explicitly permitted. Needs a DL (Hard-Rule change ⇒ DL + OWNER). |
| **R4 (card gate, canonical)** | "R4 is binding Hard Rule 14 — not relaxable beyond what's above." (REJECTs neural nets, ONNX, PnL-adaptive params, online/retraining logic) | `processes/qb_reputable_source_criteria.md:26-53` | The strategy's *own logic* must be ML-free/deterministic inside the EA. | Annex clarifying R4 governs the **EA decision engine**; research ML that outputs fixed mechanical rules is out of R4's scope. Keep the in-EA reject list verbatim. |
| **R4 (Vault mirror)** | "R4 No ML (HR14, BINDING) … ML/Neural/Adaptive/Grid-ohne-bounded-worst-case. **Nicht relaxbar.**" | `04 Processes/Research Methodology.md:93` | Same, card-level. | Mirror the R4 annex here. |
| **Edge Lab Charter (already ULTRACODE-shaped)** | "No ML inside the EA (Hard Rule 14): the AIs are the research / development tools, never a model embedded in the EA." | `docs/ops/EDGE_LAB_CHARTER_2026-05-22.md:17-18` | Already states: ML forbidden *inside the EA*; AIs are research tools. | **Precedent, not a blocker** — cite it as the existing basis; no annex needed, possibly a cross-ref from HR14. |
| **START_HERE rule 8** | "Kein ML. V5-EAs sind mechanisch und regelbasiert." | `START_HERE.md` rule 8 | Already EA-scoped. | Light annex/cross-ref for consistency once HR14 is annexed. |
| **Card schema (code)** | frontmatter requires `r4_ml_forbidden` | `agent_router.py` `STRATEGY_CARD_SCHEMA` | Every card must assert ML-free. | Semantics unchanged: a Kimi/research-ML-derived card still sets `r4_ml_forbidden: PASS` because the *EA* is ML-free. No code change; document interpretation in the R4 annex. |

**Reading:** ULTRACODE does not contradict the strongest current statements (Edge Lab Charter, START_HERE, Determinism page) — it **promotes an EA-scoped principle already in repo docs to a Hard-Rule annex**. The only place with genuinely blanket wording is HR14; that is the load-bearing annex.

---

## (c) R1 source attribution for Strategy Cards

R1 **already** admits AI-authored sources; ULTRACODE adds a new artifact URI and Kimi as an author.

| Contract | Exact quote (≤40 w) | Path | Currently forbids/requires | ULTRACODE change → annex |
|---|---|---|---|---|
| **R1 (canonical)** | "AI-originated idea — `source_id: AI-<agent>-<short-tag>-<YYYYMMDD>` … with the AI's prompt/output trail captured in `strategy-seeds/sources/<source_id>/`" | `processes/qb_reputable_source_criteria.md:27-56` | Requires exactly ONE `source_id`; AI-authored is first-class; author track record NOT required. | Annex: register `QM-RESEARCH://<id>` as a valid durable-artifact source form and `kimi` as a valid `<agent>` tag. Fits existing AI-source provision. |
| **R1 (Vault row)** | "R1 Source-Link … Karte zitiert verifizierbare URL/Referenz … REJECT nur wenn Keine Source-Attribution überhaupt." | `04 Processes/Research Methodology.md:90` | REJECT only when there is no attribution at all; needs a verifiable reference. | Annex declaring `QM-RESEARCH://<id>` a verifiable reference type. |
| **Hallucination guard** | "Primärquellen-Zitat (Video-Links von agy gelten NICHT als R1-Beleg — Halluzinations-Präzedenz)" | `docs/ops/OPERATING_RULES_2026-07-03.md:27` | AI-produced citations that are not durable/verifiable are barred. | The QM-RESEARCH:// artifact must be **durable, content-addressed, independently readable** to clear this bar — state this in the annex. |
| **Card schema (code)** | frontmatter requires `r1_track_record` | `agent_router.py` `STRATEGY_CARD_SCHEMA` | Field mandatory (note: naming differs from `source_id` in the criteria file — minor existing inconsistency). | No code change; the annex should note `r1_track_record: UNKNOWN` is valid for internally-authored cards. |

---

## (d) Quota / spend governance

| Contract | Exact quote (≤40 w) | Path | Currently forbids/requires | ULTRACODE change → annex |
|---|---|---|---|---|
| **Spend & Quota page** | "steers **Codex + Claude weekly** spend … Flags: CODEX_LOW_TOKENS.flag / CLAUDE_DISABLED.flag / AGY_LOW_QUOTA.flag … **Backtests are NEVER throttled.**" | `06 Infrastructure/AI Spend and Quota Governance.md:20-34` | Only Codex+Claude weekly limits governed; agy paced separately; no Kimi lane/flag. | Annex a Kimi spend lane + flag (e.g. `KIMI_LOW_TOKENS.flag`) or an explicit statement that Kimi runs under an existing budget line. |
| **agent_chain gates** | gates: `codex_budget_line`, `claude_disabled_flag`, `codex_low_tokens_flag`, `agy_low_quota_flag` | `agent_chain.v1.json:60-65` | Chain respects three throttle flags; no Kimi gate. | Add a Kimi gate so the critic chain honors Kimi throttling. |
| **CLAUDE.md quota section** | "Quota governor (automated) … steers Codex+Claude spend along their **weekly** limits … **Backtests are never throttled.**" | `C:/QM/repo/CLAUDE.md` (Quota Governance) | Same. | Refresh to include Kimi under governance. |

**Risk:** an ungoverned Kimi lane violates the spend-governance contract (the only mechanism enforcing the weekly budget line).

---

## (e) Determinism-first

| Contract | Exact quote (≤40 w) | Path | Currently forbids/requires | ULTRACODE relationship |
|---|---|---|---|---|
| **Determinism principle** | "Das System funktioniert am besten, wenn so wenig wie möglich von KI gemacht wird … Braucht es echtes Reasoning … Erst dann LLM." | `04 Processes/Determinism Over LLM Calls.md:3-5, 26-32` | LLM legitimate only for reasoning/synthesis; everything mechanical is script/lookup; outputs must be reproducible + auditable. | **Frames ULTRACODE:** offline research ML is a "reasoning" use, but its *output feeding the EA* must be deterministic mechanical rules, and the derivation must land in a durable auditable artifact (→ the QM-RESEARCH:// requirement). No annex to this page needed; it is the justification. |
| **Hard Rules architecture note** | "Determinismus statt LLM-Aufrufe … Wenn ein Skript es kann, kein LLM." | `01 Identity/Hard Rules.md:98-100` | Restates it beside the hard rules. | Consistent; no change. |
| **Reproducibility columns** | table: Python "✅ exakt gleicher Output"; LLM "❌ nicht garantiert" | `04 Processes/Determinism Over LLM Calls.md:13-17` | Non-reproducible AI output is not evidence. | Directly motivates why a Kimi-authored strategy needs a frozen, content-addressed artifact, not a chat transcript. |

---

## (f) Research methodology + lessons-learned loop

| Contract | Exact quote (≤40 w) | Path | Currently forbids/requires | ULTRACODE relationship → annex |
|---|---|---|---|---|
| **Depth-first rule** | "Eine Quelle vollständig abarbeiten, bevor die nächste beginnt." | `04 Processes/Research Methodology.md:11-13` | One source fully worked before the next; source "various/unknown" forbidden. | A Kimi-authored strategy is *a source*; it must produce a durable artifact and pass G0/Q00 like any source. Possibly annex the source-category table to list "internal AI-authored (QM-RESEARCH://)". |
| **HR16 sequence** | "**Ein Research zur Zeit.** … Wenn der Orchestrator mehrere EAs gleichzeitig in Development pusht, ist das ein HR16-Verstoß." | `01 Identity/Hard Rules.md:88-94` | Serialized research/build to bound token burn. | Kimi authoring does not relax HR16; still one research at a time. No annex; enforce. |
| **Lessons-Learned Loop** | "Lessons-Learned wandert in Skripte oder Skills, nicht in Memory" ; Hard-Rule changes need DL + OWNER | `04 Processes/Lessons Learned Loop.md:84-88`; `Determinism Over LLM Calls.md:84-85` | Generalizable lessons become scripts/pre-flight checks; a new Hard Rule needs a DL. | Confirms the HR14 annex (b) must be a DL, and any Kimi-onboarding lessons become pre-flight/scripts. No annex to the loop itself. |

---

## Consolidated annex list (no rewrites; historical evidence preserved)

1. **`agent_router.py` `DEFAULT_AGENT_REGISTRY`** — add `kimi` lane (code; source-of-truth). *Required for Kimi to route at all.*
2. **`agent_chain.v1.json`** — add `kimi` vendor block + insert into every `by_creator_vendor` critic list.
3. **`02 Org/AI Agent Routing and Role Contracts.md`** — annex registry row + extend the 2026-09-15 cross-vendor annex.
4. **`02 Org/Company Structure.md`** — "drei AIs" → four; add Kimi actor row.
5. **`CLAUDE.md`** — refresh roster + quota section.
6. **`01 Identity/Hard Rules.md` HR14** — OWNER-signed Amendments-2026-09 annex scoping ML ban to EA decision engines, permitting offline research ML (needs a DL).
7. **`processes/qb_reputable_source_criteria.md`** — R4 EA-scope clarification; R1 add `QM-RESEARCH://<id>` + `kimi` as valid `<agent>`.
8. **`04 Processes/Research Methodology.md`** — mirror R4 clarification + R1 reference-type addition; optionally source-category row.
9. **`06 Infrastructure/AI Spend and Quota Governance.md`** + **`agent_chain.v1.json` gates** — add a Kimi spend lane/flag or an explicit budget-line statement.
10. **(No change) `docs/ops/EDGE_LAB_CHARTER_2026-05-22.md`, `START_HERE.md` rule 8, `04 Processes/Determinism Over LLM Calls.md`** — cite as existing precedent for the EA-vs-tool ML split; cross-ref only.
11. **(No change) `gate_manifest.v4.json`** — carries no R1/ML criteria (gates are function-named); enforcement lives in the criteria file + card schema + Q00, so no gate-manifest annex is implied.

**Do NOT touch:** any dated `decisions/*.md`, `docs/ops/evidence/*`, historical window-sweep/audit artifacts — annexes append, they never alter prior evidence.
