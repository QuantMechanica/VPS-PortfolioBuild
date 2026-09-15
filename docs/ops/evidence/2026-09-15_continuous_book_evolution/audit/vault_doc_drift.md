# Vault / Doc Drift Audit — OWNER Directive 2026-09-15 (Continuous Book Evolution)

**Auditor:** read-only subagent (vault_doc_drift lane) · **Date:** 2026-09-15
**Directive:** `docs/ops/evidence/2026-09-15_continuous_book_evolution/owner_directive_verbatim.md` (§0–§1, §3, §65–§66 governing; supersession sections §3, §4, §8, §10, §12, §15, §23, §24, §37, §60)
**Vault root:** `G:/My Drive/QuantMechanica - Company Reference/`

## Headline (3 lines)

1. The directive supersedes four hard-wired portfolio/pipeline rules that are still written as **binding/non-negotiable** across at least 9 vault pages plus their code/runbook mirrors: the fixed **25-candidate book trigger** (§3/§4), the **family-cap 3 / symbol-cap 2 / pairwise |r|<0.5** static caps (§8), the **Q17 mandatory min-lot + fixed 14-day burn-in** (§10), and the **"drain everything first"** doctrine + **HR16 one-at-a-time** rule (§23/§24).
2. Two directive-named canonical pages **do not exist in the vault** and must be created — **Mission Control documentation** and a **Kimi documentation** page — plus the **"Way to 25"** objective is still the headline in Heartbeat, all 23 Morning Briefings, the Claude ToDo board and `Current Objective`, which §3/§60 orders removed from live surfaces (history preserved).
3. History-preservation is respected: no verdicts, decisions or Morning-Brief archive entries should be rewritten — supersession is by **marking obsolete + updating current guidance**, not deletion.

## Findings (numbered, with evidence path)

1. **Fixed 25-candidate book trigger is written as a fail-closed hard guard in 4 vault pages + the ops workflow + the book-ceremony runbook.** The formula `BOOK BUILD PERMITTED ⇔ (qualified_candidates >= 25) AND (owner_order_artifact …)` appears verbatim in `03 Pipeline/Q15 Final Portfolio Construction.md:29`, `03 Pipeline/Pipeline Overview.md:141`, `03 Pipeline/Gate Manifest v4 Diff.md:91`, `03 Pipeline/Pipeline Operations Workflow.md:144`, and prose at `Q15:79`, `Pipeline Overview:100/198`, `Pipeline Operations Workflow:192`. Repo mirror: `docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md:1,6` (`qualified_pairs >= 25`) and the `book_build_guard` code path. Superseded by **§4** (no OWNER-mandated minimum count) and **§3** (candidate count is a diagnostic, not a gate). Evidence: greps above.

2. **Static portfolio caps are labelled "non-negotiable" / "Hard".** `03 Pipeline/Q15 Final Portfolio Construction.md:132-141` — "Diversification Rules (Hard)": Family Cap Max 3, Symbol Cap Max 2, Pairwise |r| < 0.5, and "These caps are non-negotiable." Mirrored at `03 Pipeline/Pipeline Overview.md:72`. Superseded by **§8** (these are no longer hard rules; convert to default guardrails/warnings/diagnostics/portfolio-risk inputs; measure real economic dependence, do not replace with a new arbitrary cap). Evidence: `Q15…:136-141`, `Pipeline Overview.md:72`.

3. **Q17 mandates min-lot for the full 14 calendar days and a fixed 14-day minimum with "No demo gate".** `03 Pipeline/Q17 Live Burn-In DXZ.md:29,36,58-60,95-97` — "Min-lot only", "Minimum 14 calendar days", "Min-lot for full 14 days", "14-day minimum … OWNER waits the full 14 days", "No demo gate … min-lot live is the validation". Mirrored: `Pipeline Overview.md:74,185,201`, `Pipeline Operations Workflow.md:161`, `Q16 Operational Readiness.md:47,73`, `06 Infrastructure/Risk Conventions.md:22,95-102`. Superseded by **§10** (min-lot rule + fixed 14-day wait superseded; refactor Q17 into an evidence-based live introduction/probation/deployment stage). Actual live activation authority unchanged (§10 tail, §64). Evidence: `Q17…` full read.

4. **"Drain the whole pipeline before building a book" is the standing Zwischenziel and blocks both books.** `08 Current State/Current Objective.md:24-43` — "ZWISCHENZIEL (OWNER 2026-08-21) — erst leerlaufen, dann Buch … kein FTMO-Buch und kein DXZ-Neubuch bis das Drain-Ziel steht". Mirrored: Claude ToDo board `12 ToDo/AI ToDos/Claude.md:29` ("bis zum Drain-Ziel nicht dispatcht"), `12 ToDo/10_Pipeline_Leerlauf.md:6`. Superseded by **§23** (pipeline is continuous, not a global drain barrier; do not let old early-stage backlog block a material live improvement). Evidence: `Current Objective.md:24-43`.

5. **HR16 "one research / one EA at a time" is written as a Hard Rule and enforced in prose.** `01 Identity/Hard Rules.md:1` ("16 Non-Negotiables"), `:87-94` (Rule 16 "Ein Schritt nach dem anderen — Sequenz-Pflicht", "Ein Research zur Zeit", "Wenn der Orchestrator mehrere EAs gleichzeitig in Development pusht, ist das ein HR16-Verstoß"). Mirrored: `04 Processes/Operational Disciplines.md:156,164`, `04 Processes/Determinism Over LLM Calls.md:81,116`, `03 Pipeline/Pipeline Overview.md:202` ("sequential across sources (HR16)"), `04 Processes/Research Methodology.md:13` ("Eine Quelle vollständig abarbeiten, bevor die nächste beginnt"). Superseded by **§24** (controlled parallelism expressly allowed; HR16 no longer binding as an absolute restriction) under stated isolation/compute/quota conditions. Note: the deterministic-tooling spirit of §26 is preserved; only the absolute serialisation is lifted. Evidence: `Hard Rules.md:87-94`.

6. **"Way to 25" is still the primary progress view on live surfaces.** `08 Current State/Heartbeat.md:33-40` ("## Weg zu 25", "Buch-Guard 26 / 25"), all 23 files `10 Morning Briefing/2026-08-24…2026-09-15_morning_brief.md` ("WEG ZU 25 (Q14 terminal)"), Claude board `12 ToDo/AI ToDos/Claude.md:89-90` ("Nordstern: ≥25 vollständig qualifizierte Kandidaten durch Q14 → Buch"), `Current Objective.md:50-52`. Superseded by **§3** (WAY TO 25 abolished as business target; remove from Mission Control / Morning Briefing / dashboards / current-objective docs) and **§60** (replace with Book-Evolution view). Heartbeat/Morning-Brief surfaces are **generator-driven** (`tools/strategy_farm/heartbeat_snapshot.py`, morning-brief generator) — the fix is in the generator, not by hand-editing the overwritten page. Evidence: greps above.

7. **FTMO objective is still "fastest +10% / ≤30 days" and a 60-day first-passage sprint contract.** `08 Current State/Current Objective.md:19-21` ("die meisten und schnellsten Payouts", "+10 % / ≤30 Tage"), `12 ToDo/07_FTMO_Kampagne.md:21` ("P(Phase-1-Pass innerhalb von 60 Tagen) ≥ 0,80"), internal "60/30-Tage-Sprintvertrag" referenced at `Q15…:97`. Superseded by **§15** (success probability > speed; the fastest-+10%/≤30d/60d hard targets must be re-evaluated where they conflict) and **§14** (one paid Challenge at a time; a slower successful Challenge is preferable). Metrics remain valuable evidence, not eternal hard rules. Evidence: `Current Objective.md:19-21`, `07_FTMO_Kampagne.md:21`.

8. **`Current Objective` also still carries the superseded "Challenge-Kauf vertagt bis genug Dichte-Motoren stehen" and portfolio-first density gate.** `08 Current State/Current Objective.md:21,50` — density ≥25 Trades/Jahr/Symbol as the binding FTMO bottleneck. §18 (scalping expressly allowed) and §21 (audit FTMO density rules) reframe density as one input, not a universal gate; §12/§16 make a two-week Demo the pre-purchase evidence gate. Rewrite `Current Objective` to the two-engine continuous-book model (§2, §5, §11). Evidence: `Current Objective.md`.

9. **`_HOME` and `START_HERE` point at the wrong (v2/v3) gate manifest and forbid self-chosen work + ML outright.** `_HOME.md:53` ("Kanonische Quelle ist `…gate_manifest.v2.json`") and `:55` ("Standardweg Q00–Q13 und Optimierungszweig Q14–Q16") contradict runtime truth (v4 linear Q00–Q17 ACTIVE since 2026-08-23; `gate_manifest.v4.json`, `gate_manifest.py DEFAULT_MANIFEST=V4_MANIFEST`). `START_HERE.md:21` (Rule 1 "Nicht selbst Arbeit wählen"), `:27` (Rule 7 "Research nur nachfüllen, wenn ready Strategy Cards < 5"), `:28` (Rule 8 "Kein ML"). Superseded/needs annex by **§37** (Fable may originate strategies), **§38/§49/§50** (autonomous edge discovery is a core objective; external harvest no longer throttled by a reservoir<5 rule alone), **§41/§42** (ML allowed offline, forbidden in EA runtime — HR14 annex already exists at `Hard Rules.md:223`, START_HERE Rule 8 must reference it), and §65 (correct v4 manifest). Evidence: `_HOME.md:53-55`, `START_HERE.md:21,27-28`.

10. **`AI Spend and Quota Governance` predates Kimi entirely (last modified 2026-07-22) and does not mention the Kimi lane or real-quota telemetry.** `06 Infrastructure/AI Spend and Quota Governance.md` steers only Codex+Claude weekly spend; 0 Kimi mentions. §29–§33 (Kimi continuously available; local 40/day-200/week limits are fallback guardrails, not contract limits; discover real quota telemetry) and §65 require this page updated with the Kimi governor + quota-fetcher. Evidence: grep (0 kimi hits), `stat` mtime 2026-07-22.

11. **Directive-named canonical pages that DO NOT EXIST in the vault (must be created).** (a) **Mission Control documentation** — no vault page (only `12 ToDo/AI ToDos/Archive/…pre Mission Control 2026-08-24.md`); Mission Control lives as `D:/QM/strategy_farm/dashboards/cockpit.html` with no canonical vault doc. Required by §60/§65/§69. (b) **Kimi documentation** — no vault page; specs live only in `docs/ops/KIMI_INTEGRATION_ARCHITECTURE.md`, `KIMI_EDGE_DISCOVERY_DESIGN.md`, `INTERNAL_RESEARCH_SOURCE_CONTRACT.md`; §65 explicitly lists "Kimi documentation" as a vault target. (c) **FTMO Campaign** — no page literally named "FTMO Campaign"; closest are `12 ToDo/07_FTMO_Kampagne.md` (program board) and `08 Current State/Strategischer Fahrplan FTMO Payout und DXZ Allocation 2026-08-22.md`. Treat as PARTIAL/needs a canonical current page (§11–§17, §62). Evidence: `find` output.

12. **Already-aligned (no drift, do not re-edit):** `01 Identity/Hard Rules.md:223-251` (HR14 ML-annex 2026-09-15 — matches §41/§42), `04 Processes/Research Methodology.md:125-160` (Pre-Q00 Internal Edge Discovery annex — matches §36/§43/§53), `02 Org/AI Agent Routing and Role Contracts.md` (14 Kimi mentions, video-lane held), `02 Org/Company Structure.md` (6 Kimi mentions), `08 Current State/Current Operating State.md:10-12` (Kimi delta) — all touched 2026-09-15 12:5x. These satisfy the ML-research and Kimi-role portions of §27/§28/§41/§42 already.

## Drift table

| Page / file (vault path) | Quoted sentence (≤200 chars) | Directive § that supersedes | Proposed edit type |
|---|---|---|---|
| `03 Pipeline/Q15 Final Portfolio Construction.md:29` | "BOOK BUILD PERMITTED ⇔ (qualified_candidates >= 25) AND (owner_order_artifact vorhanden & verifiziert)" | §4 (§3) | rewrite — replace with "evaluate any currently valid qualified pool; no fixed minimum"; keep OWNER-order requirement |
| `03 Pipeline/Q15…:79` | "…Pool mindestens 25 Kandidaten enthält und der OWNER den Buchbau ausdrücklich beauftragt." | §4 | rewrite |
| `03 Pipeline/Q15…:132-141` | "Diversification Rules (Hard) … Family Cap Max 3 … Symbol Cap Max 2 … Pairwise \|r\| < 0.5 … These caps are non-negotiable." | §8 | rewrite — convert to default guardrails/warnings/diagnostics + portfolio-risk analysis |
| `03 Pipeline/Q15…:54,58-61,117-121` | "Trigger: OWNER-Auftrag und Pool von mindestens 25 vollständig requalifizierten Kandidaten" / "OWNER-Direktive 2026-08-23: … Kein DXZ-/FTMO-Probe- oder Zielbuch unter 25 …" | §4 | mark superseded + rewrite (keep 2026-08-23 note as history) |
| `03 Pipeline/Pipeline Overview.md:72` | "Family-cap 3 per edge type · symbol-cap 2 per instrument · pairwise \|r\| < 0.5 · target 10-15 EAs" | §8 | rewrite |
| `03 Pipeline/Pipeline Overview.md:74,185,201` | "14 days on DarwinexZero Live account · min-lot …" / "Q16 → Q17 = direct to DXZ Live min-lot. Demo trading is not a meaningful filter" | §10 (§12) | rewrite Q17 to evidence-based introduction; drop "no demo gate" absolute |
| `03 Pipeline/Pipeline Overview.md:100,141,149,198` | "Buch-Trigger (fail-closed): ≥25 qualifizierte Kandidaten UND OWNER-Buchauftrag" | §4 (§3) | rewrite |
| `03 Pipeline/Pipeline Overview.md:202` | "Parallel within source, sequential across sources (HR16) … Next source unlocks only after the previous source's last EA exits" | §24 | rewrite — controlled parallelism allowed under isolation/compute/quota conditions |
| `03 Pipeline/Pipeline Operations Workflow.md:144,192` | "(qualified_candidates ≥ 25) AND (owner_order_artifact …). Unter 25 wird nur gemessen/vervollständigt" / "Buchbau unter 25 Kandidaten … fail-closed verweigert" | §4 | rewrite |
| `03 Pipeline/Pipeline Operations Workflow.md:161` | "Nur OWNER-signiertes Manifest, T_Live, Min-Lot und festgelegte Beobachtungs-/Kill-Regeln." | §10 | rewrite (keep OWNER-manifest + T_Live authority) |
| `03 Pipeline/Gate Manifest v4 Diff.md:91` | "BOOK BUILD PERMITTED ⇔ (qualified_candidates >= 25) AND (owner_order_artifact …)" | §4 | mark superseded (diff doc — annotate, keep historical mapping) |
| `03 Pipeline/Q17 Live Burn-In DXZ.md:29,36,58-60,95-97` | "Duration: 14 days minimum … Min-lot only … Min-lot for full 14 days … 14-day minimum … No demo gate" | §10 (§12) | rewrite — evidence-based probation/introduction stage; risk depends on validated evidence |
| `03 Pipeline/Q16 Operational Readiness.md:47,73` | "Risk parameters set to RISK_PERCENT (per Q11 allocation), min-lot enforced for burn-in" / "burn_in_lot: 0.01 # min-lot for 14d burn-in" | §10 | rewrite (min-lot no longer mandatory default) |
| `06 Infrastructure/Risk Conventions.md:22,95-102` | "OWNER-Entscheid 2026-08-21: Ein EA läuft mindestens 14 Tage live auf Min-Lot, bevor über einen Size-Up entschieden wird." | §10 | mark superseded + rewrite (evidence-based initial live risk) |
| `08 Current State/Current Objective.md:24-43` | "ZWISCHENZIEL (OWNER 2026-08-21) — erst leerlaufen, dann Buch … kein FTMO-Buch und kein DXZ-Neubuch bis das Drain-Ziel steht" | §23 | mark superseded + rewrite to continuous two-book model |
| `08 Current State/Current Objective.md:19-21,50-52` | "+10 % / ≤30 Tage … Challenge-Kauf vertagt, bis genug Dichte-Motoren stehen … Prop-Track-Dichte ≥25 Trades/Jahr/Symbol" | §15 (§14,§18) | rewrite — success-probability-first; two-week Demo before purchase |
| `01 Identity/Hard Rules.md:1,87-94` | "16 Non-Negotiables" / Rule 16 "Ein Research zur Zeit … mehrere EAs gleichzeitig in Development … ist ein HR16-Verstoß" | §24 | append annex — HR16 no longer absolute; controlled parallelism authorized (keep safety framing per §20A) |
| `04 Processes/Operational Disciplines.md:156,164` | "Maximal 1 aktiver EA in Development (HR16)." / "HR16 — Sequenzialität ist die primäre Token-Spar-Maßnahme" | §24 | rewrite |
| `04 Processes/Research Methodology.md:13` | "Eine Quelle vollständig abarbeiten, bevor die nächste beginnt." | §24 (§50) | rewrite — parallel external + internal research programmes allowed |
| `04 Processes/Determinism Over LLM Calls.md:81,116` | "HR16 (Step-by-Step) … ein Workflow, eine Sequenz" / "LLM-Parallelität verbrennt Tokens" | §24 (§25/§26 preserve determinism) | append annex — parallelism allowed; determinism-first spirit retained |
| `08 Current State/Heartbeat.md:33-40` | "## Weg zu 25 … Qualifiziert: 26 / 25 Paare … Buch-Guard 26 / 25" | §3 (§60) | delete from Mission-Control surface — fix generator `heartbeat_snapshot.py`; replace with Book-Evolution block |
| `10 Morning Briefing/2026-08-24…2026-09-15_morning_brief.md` (×23, e.g. `2026-09-15:33`) | "WEG ZU 25 (Q14 terminal)" | §3 | delete from live briefing generator; keep dated files as history (do not rewrite) |
| `12 ToDo/AI ToDos/Claude.md:89-90` | "Nordstern: ≥25 vollständig qualifizierte Kandidaten durch Q14 … → Buch (Book-Guard fail-closed + OWNER-Order)." | §3/§4 | rewrite board Nordstern to continuous-book-evolution |
| `12 ToDo/AI ToDos/Claude.md:29` | "…der bis zum Drain-Ziel nicht dispatcht wird." | §23 | rewrite |
| `12 ToDo/10_Pipeline_Leerlauf.md:6` | "…eigentliche Engpass auf dem Weg zu 25." | §3/§23 | mark superseded |
| `12 ToDo/07_FTMO_Kampagne.md:21` | "P(Phase-1-Pass innerhalb von 60 Tagen) ≥ 0,80 als konservative Bootstrap-Untergrenze" | §15 | rewrite — probability-first, two-week Demo gate; 60d as evidence not hard target |
| `_HOME.md:53` | "Kanonische Quelle ist C:\QM\repo\tools\strategy_farm\config\gate_manifest.v2.json." | §1 truth precedence / §65 | rewrite — point to `gate_manifest.v4.json` (runtime truth) |
| `_HOME.md:55` | "Pipeline Overview — Standardweg Q00–Q13 und Optimierungszweig Q14–Q16." | §65 (drift vs runtime v4) | rewrite — v4 linear Q00–Q17, 3 macro-phases |
| `START_HERE.md:21` | "1. Nicht selbst Arbeit wählen. Arbeit kommt aus Queue/Ticket/OWNER-Auftrag." | §37 (§25) | rewrite/annex — Fable may originate hypotheses & owns prioritisation; Codex/agy still commissioned |
| `START_HERE.md:27` | "7. Research nur nachfüllen, wenn ready Strategy Cards < 5." | §38/§49/§50 | rewrite — autonomous edge discovery + parallel research; measure ROI not a bare reservoir count |
| `START_HERE.md:28` | "8. Kein ML. V5-EAs sind mechanisch und regelbasiert." | §41/§42 | append annex reference — ML allowed offline (HR14 annex 2026-09-15), forbidden in EA runtime |
| `06 Infrastructure/AI Spend and Quota Governance.md` (whole page) | steers only "Codex + Claude weekly spend"; no Kimi | §29–§33 / §65 | append — Kimi governor, real-quota fetcher, fallback-guardrail framing |

## Vault pages the directive NAMES that do not exist (must be created) + last-modified of the pages that do

**Must be created (do not exist):**
- **Mission Control documentation** — no vault page (only archived `12 ToDo/AI ToDos/Archive/…pre Mission Control 2026-08-24.md`). Required by §60/§65/§69.
- **Kimi documentation** — no vault page (specs only in `docs/ops/KIMI_*`). Required by §65.
- **FTMO Campaign** (canonical) — PARTIAL: exists as `12 ToDo/07_FTMO_Kampagne.md` (board) + `08 Current State/Strategischer Fahrplan FTMO Payout und DXZ Allocation 2026-08-22.md`; no single current "FTMO Campaign" reference page (§11–§17, §62).
- **FTMO Challenge Readiness** — new living view required by §62 (directive routes the durable artifact to `docs/ops/FTMO_CHALLENGE_READINESS.md`; a vault mirror should follow).

**Directive-named pages that DO exist (path | last-modified):**
| Page | Last modified |
|---|---|
| `_HOME.md` | 2026-08-21 14:10 |
| `START_HERE.md` | 2026-08-21 14:09 |
| `08 Current State/Current Objective.md` | 2026-08-22 10:44 |
| `01 Identity/Hard Rules.md` | 2026-09-15 12:52 |
| `02 Org/Company Structure.md` | 2026-09-15 12:53 |
| `02 Org/AI Agent Routing and Role Contracts.md` | 2026-09-15 12:53 |
| `04 Processes/Research Methodology.md` | 2026-09-15 12:54 |
| `03 Pipeline/Pipeline Overview.md` | 2026-08-23 17:54 |
| `03 Pipeline/Q15 Final Portfolio Construction.md` | 2026-09-13 22:39 |
| `03 Pipeline/Q16 Operational Readiness.md` | 2026-09-13 22:39 |
| `03 Pipeline/Q17 Live Burn-In DXZ.md` | 2026-09-13 22:39 |
| `04 Processes/Lessons Learned Loop.md` | 2026-08-20 21:15 |
| `04 Processes/Determinism Over LLM Calls.md` | 2026-08-20 21:15 |
| `06 Infrastructure/AI Spend and Quota Governance.md` | 2026-07-22 21:48 |
| `02 Org/Stehende Vollmacht Claude 2026-08-20.md` | 2026-08-20 21:45 |
| `08 Current State/Current Operating State.md` | 2026-09-15 12:54 |
| `08 Current State/Heartbeat.md` | 2026-09-15 14:27 (auto-overwritten) |

## Open questions strictly requiring OWNER

None. Every supersession above is explicitly decided in the directive (§3, §4, §8, §10, §12, §15, §23, §24, §37); §21/§68 instruct implementing the already-decided items without re-approval, and §65 directs marking obsolete rules as superseded. The only judgment calls (exact new guardrail thresholds for the former caps, the evidence-based Q17 risk ladder, the new FTMO probability bar) are §21 RULE_EFFECTIVENESS_AUDIT outputs to be proposed with evidence, not blocking OWNER questions.

## Recommended actions for the implementing phases (concrete file paths)

**Phase B — OWNER policy implementation (vault + doc supersession):**
1. Rewrite the book-trigger blocks (drop fixed `>=25`) in `G:/…/03 Pipeline/Q15 Final Portfolio Construction.md`, `Pipeline Overview.md`, `Pipeline Operations Workflow.md`; annotate (not delete) `Gate Manifest v4 Diff.md:91`. Sync repo: `docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md` and the `book_build_guard` code (portfolio builder assumptions) per §4/§70.
2. Convert the "Diversification Rules (Hard)/non-negotiable" caps in `Q15 Final Portfolio Construction.md:132-141` and `Pipeline Overview.md:72` to default guardrails + portfolio-risk analysis (§8); test that cap warnings do not silently become no-op risk analysis (§70).
3. Refactor `03 Pipeline/Q17 Live Burn-In DXZ.md`, `Q16 Operational Readiness.md:47,73`, `Pipeline Overview.md:74,185,201`, `Pipeline Operations Workflow.md:161`, `06 Infrastructure/Risk Conventions.md:22,95-102` from mandatory min-lot/14-day to evidence-based live introduction/probation (§10); preserve OWNER-only live-toggle language.
4. Mark superseded + rewrite `08 Current State/Current Objective.md` (drain Zwischenziel §23; FTMO speed §15; two-engine continuous-book model §2/§5/§11).
5. Append an HR16 annex to `01 Identity/Hard Rules.md` and rewrite `04 Processes/Operational Disciplines.md:156,164`, `Determinism Over LLM Calls.md:81,116`, `Research Methodology.md:13`, `Pipeline Overview.md:202` for controlled parallelism (§24), keeping the determinism-first framing (§26).
6. Fix `_HOME.md:53-55` (v4 manifest) and `START_HERE.md:1,7,8` (Fable authorship §37, autonomous discovery §38/§49/§50, ML annex reference §41/§42).
7. Update `06 Infrastructure/AI Spend and Quota Governance.md` with the Kimi lane, governor, real-quota fetcher and fallback-guardrail framing (§29–§33).

**Phase D — Mission Control:**
8. Fix the generators that emit "Way to 25": `tools/strategy_farm/heartbeat_snapshot.py` (→ `08 Current State/Heartbeat.md` Book-Evolution block) and the Morning-Brief generator (live template only; dated `10 Morning Briefing/*` files stay as history). Rewrite Claude board Nordstern `12 ToDo/AI ToDos/Claude.md:89-90,29` (§3/§60/§23).
9. Create the **Mission Control** canonical vault page (Book Evolution / FTMO Readiness / Research / Factory sections per §60).

**Phase C / cross-cutting — new canonical pages:**
10. Create a **Kimi documentation** vault page (mirror of `docs/ops/KIMI_INTEGRATION_ARCHITECTURE.md` etc.) per §65.
11. Create/consolidate a canonical **FTMO Campaign** + **FTMO Challenge Readiness** vault page set (§11–§17, §62), linking `docs/ops/FTMO_DEMO_VALIDATION_CONTRACT.md` and `docs/ops/FTMO_CHALLENGE_READINESS.md` (§69).

**Phase (RULE_EFFECTIVENESS_AUDIT, §21):** feed items 1–3,5,7 above into `docs/ops/RULE_EFFECTIVENESS_AUDIT_2026-09.md` with original purpose / current benefit / current cost / safety impact / recommendation / rollback for each superseded rule.
