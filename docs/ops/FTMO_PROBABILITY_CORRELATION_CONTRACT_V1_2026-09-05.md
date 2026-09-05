# FTMO Probability & Correlation Contract — V1 (2026-09-05)

Status: **PENDING (OWNER ratification).** Klasse: **ROT** (Gate-Kriterien / Buchregeln / Zahlen). **Kein Auffangregel.**
Autor: Claude (Factory CEO), Drafter-Lane. Task 97a0ed31 (Decision P7a, receipt row 15).
Typ: **DOKUMENT + versionierter JSON-Schema-Vorschlag** (Codex implementiert später). Dieses Dokument definiert **keine neuen Zahlen** — jede Schwelle ist ein bestehender, zeilengenau belegter Policy-Wert; wo zwei ratifizierte Werte kollidieren, wird der Konflikt als **explizite OWNER-Wahl** mit Empfehlung vorgelegt.
Bindet / referenziert: `docs/ops/OWNER_VORLAGE_2026-09-05_ftmo_positive_evidence_test.md` (Abnahmetest — dessen §B/§C/§D-Schwellen sind identisch mit diesem Vertrag oder explizit hier abgeleitet); `decisions/2026-09-04_owner_receipts_briefing_2_4.md` (OWNER-DEC-BOOK-V2V4V6-EPOCH-20260904); `decisions/2026-09-02_owner_receipts_ceo_asks.md` (concentration_tail-Ratifizierung); `docs/research/SPARSE_D1_ORTHOGONALITY_STANDARD_2026-09-03.md` (V4-Korrelationsstandard).

---

## 1 · LAGE (Deutsch, eine Seite)

Fünf Engine-Familien entscheiden heute über FTMO-Buch-Admission mit **unterschiedlichen Wahrscheinlichkeits- und Korrelationskriterien**, die nie zu einem Vertrag zusammengeführt wurden:

- **Builder** (`build_book_ftmo.py`) gated **nur** die P1-Bootstrap-**Untergrenze ≥ 0.80** (`:54`) und eine paarweise Korrelation ≤ 0.50 (`:75`) auf dem **rohen, vorzeichenbehafteten** Wert (`:283`). Breach, P2 und Joint werden **im Baupfad nie geprüft** (`:547`, nur FUND_SCORE + P1-Lower).
- **Rulepack** (`FTMO_2S_100K_SWING_V2.json`) verlangt **Punkt ≥ 80 % UND Lower-95 ≥ 70 %** (`:480`), Breach Upper-95 ≤ 10 % (`:486`), P2-conditional ≥ 85 % UND Joint ≥ 65 % (`:492`) — **aber der ganze Rulepack ist `lifecycle_status: RESEARCH_CONTRACT_ONLY`** (`:9`); jedes Kriterium ist `INTERNAL_DECISION_CRITERION` bzw. `PROPOSED_FOR_CALIBRATION`. Diese Zahlen sind **vorgeschlagen, nicht ratifiziert**.
- **Timebox** (`ftmo_timebox_eval.py`) ist die versiegelte, SHA-gepinnte, kosten-attestierte Engine: Design-Bar = Bootstrap-**Lower ≥ 0.80** (`:90`), Horizonte 60/30 Kalendertage (`:72/:74`), Moving-Block-Bootstrap 2000/seed 20260802/alpha 0.05/60-Tage-Block/two-sided-95 (`:94-98`). **Stimmt mit dem Builder überein, widerspricht dem Rulepack.**
- **MC** (`ftmo_p1_mc.py`) und **First-Passage** (`challenge_firstpassage.py`) benutzen **abweichende Horizonte** (90 Handelstage bzw. unbegrenzt) und resampeln Sleeves **unabhängig** — brechen also Kreuzkorrelation und liefern Breach nur als **Untergrenze**. Sie sind Diagnostik, keine Admissionsquelle.
- **Korrelation:** drei Caps koexistieren — **0.50** (Builder roh / Q15 `|r|<0.50` absolut, ROT-sealed), **0.40** (DL-083 Q09 Marginal-Reject / Timebox max), **0.15** (Timebox „strong"). Zusätzlich konsumiert der Builder einen **zeros-dropped Punkt-Schätzer** (`portfolio_correlation.py:184-197`), obwohl der **adoptierte V4-Standard** zeros-kept mit Block-Bootstrap-CI + ABSTAIN ist (`:57-77`). Der Builder konsumiert also **nicht** seinen eigenen Standard.
- **Tail/Konzentration:** `concentration_tail_limits.v1.json` (OWNER_RATIFIED) ist ein **Stop-Risk-%-Budget** (2.5 %, symbol/class/family-Split); der Builder-`account_weight_budget` = 10.0 ist ein **Sleeve-Zähl-Deckel**; der Rulepack trägt einen **parallelen, nur vorgeschlagenen** Tail-Satz. Diese sind **orthogonale Schichten**, kein reduzierbarer Einzelwert.

**Kernpunkt:** Die Provider-Regel-Schicht ist bereits einquellig (`ftmo_rule_contract.py`, seit `bc7e3b81`). Nur die **Entscheidungs-/Wahrscheinlichkeits-Schicht** und die **Korrelations-Schicht** divergieren. Dieser Vertrag vereinheitlicht genau diese zwei Schichten — er ändert **keine Ratifizierungs-Statuswerte** und erfindet keine Zahlen.

## 2 · EMPFEHLUNG

1. **Diesen Vertrag ratifizieren** als den einen, versionierten Wahrscheinlichkeits-/Korrelations-Vertrag, den jede Engine konsumiert (§A–§H des englischen Teils).
2. **Timebox als autoritative Entscheidungs-Engine** für die P1/P2-Pass-Wahrscheinlichkeit (versiegelt, SHA-gepinnt, kosten-attestiert, 60/30-Horizont). MC und First-Passage bleiben **Diagnostik**. DSR (`sub_8_2_dsr_mc_fdr.py`, p<0.05) bleibt die **orthogonale Multiple-Testing-Korrektur**.
3. **Korrelation:** V4 sparse-D1 **zeros-kept Block-Bootstrap-CI mit ABSTAIN/PROVISIONAL** (`portfolio_correlation.py:57-77`) als **einziger** Schätzer. `|r| < 0.50` als harter Admissions-Gate (**absolut**); 0.40 als engerer Q09-Marginal-/Timebox-Reject; 0.15 als Timebox-„strong"-Warnband. Der Builder-zeros-dropped-Punktschätzer wird zum **Migrationselement** (Codex).
4. **Tail:** die **ratifizierte** `concentration_tail_limits.v1.json` ist die einzige Tail-Autorität; die vorgeschlagenen Rulepack-Guardrails sind **suspendiert**, bis OWNER sie ratifiziert.
5. **Keine neuen Zahlen. Keine stille Reklassifizierung.** Der strengste bestehende ratifizierte Wert gilt. Die P1-Bar ist **kein** echter Konflikt: Die ratifizierte Lower ≥ 0.80 subsumiert das Rulepack-P1-Gate (Lower ≤ Punkt garantiert), OWNER bestätigt nur. Wo zwei **ratifizierte** Werte tatsächlich kollidierten, käme es als OWNER-Wahl — in diesem Vertrag tritt keiner auf.

## 3 · ENTSCHEIDUNGSFRAGEN — explizite OWNER-Wahlen (je mit Empfehlung; ROT, kein Auffangregel)

| # | Frage | Konflikt | Empfehlung (keine neue Zahl) |
|---|-------|----------|------------------------------|
| **C-1** | **P1-Latte (kein echter Konflikt — durch Konstruktion aufgelöst).** Builder/Timebox verlangen Bootstrap-**Lower ≥ 0.80** (RATIFIZIERT, `build_book_ftmo.py:54`, `ftmo_timebox_eval.py:90`); Rulepack verlangt **Punkt ≥ 80 % UND Lower-95 ≥ 70 %** (PROPOSED, `...V2.json:480`). | Scheinkonflikt: Die Bootstrap-Lower ist **per Konstruktion ≤ Punktschätzer** (`ftmo_timebox_eval.py:1008-1010` — `lower = percentile(α/2) ≤ median`; im Builder hart erzwungen `:447` — `0 ≤ lower ≤ estimate ≤ 1`). | **Ein einziges bindendes Gate: Lower-95 ≥ 0.80.** Weil Lower ≤ Punkt garantiert ist, **subsumiert** die ratifizierte 0.80-Lower das gesamte Rulepack-P1-Gate — sowohl dessen Punkt ≥ 80 % (folgt automatisch aus Lower ≥ 0.80) als auch dessen **schwächere** Lower ≥ 70 %. Der Rulepack-Punkt-80-Test ist damit **nicht-additiv** (kann nie zusätzlich binden); er wird nur als Doku der dominierten Rulepack-Absicht geführt. **Keine OWNER-Arbitrierung nötig** — der Strengster-bindet-Grundsatz löst C-1 vollständig. |
| **C-2** | **Ratifizierungs-Asymmetrie.** Rulepack-go_criteria (Breach ≤ 10 %, P2 ≥ 85 %, Joint ≥ 65 %, Freshness 7 d, Shadow-Run) sind `RESEARCH_CONTRACT_ONLY`/`INTERNAL_DECISION_CRITERION` (`:9`), also **nicht** OWNER-versiegelt. | Nur Builder-Floors, `concentration_tail_limits.v1.json` und Q15 `|r|<0.50` sind ratifiziert. | OWNER **hebt** die Rulepack-Entscheidungszahlen auf ratifiziert, damit der Vertrag sie **binden** kann — ODER sie bleiben **declared-but-not-sealed** Gates, die ein Buch blockieren, aber noch nicht als kauf-tragende Evidenz zählen. Nicht durch Claude auflösbar. |
| **C-3** | **Korrelations-Cap-Unifikation.** Drei sealed/ratifizierte Caps: 0.50, 0.40, 0.15; plus signed-vs-absolut-Methodensplit (Builder `:283` roh vs. Q15/Timebox `:106` absolut). | Ein Buch-Admissions-Cap vs. stufenspezifische Caps. | `|r| < 0.50` **absolut** als einziger harter Admissions-Gate; 0.40 als Q09-Marginal-/Timebox-max-Reject; 0.15 als Timebox-„strong"-Warnband. Geschichtet, nicht ein Wert. Builder auf **absolut** migrieren. |
| **C-4** | **Korrelations-Schätzer.** Builder konsumiert zeros-dropped Punkt-Pearson (`portfolio_correlation.py:184-197`); adoptierter V4-Standard ist zeros-kept CI + ABSTAIN (`:57-77`). | Modul-Output widerspricht dem Modul-eigenen adoptierten Standard. | V4 Layer-A **zeros-kept Block-Bootstrap-CI** als einziger Schätzer; CERTIFY_A iff ganze CI < 0.50, sonst ABSTAIN. Builder-Migration = größtes methodisches Element (Codex). |
| **C-5** | **Horizont.** Vier Konventionen: 60/30 Kalender (Timebox), 90 Handelstage (MC), unbegrenzt (First-Passage), extern (Builder-M1). | Welcher Horizont bindet den P1-Pass-Estimand? MC-90-Handelstage ≈ 126 Kalendertage vs. autoritative 60 Kalendertage (≈ 43 Handelstage) — **≈ 3× längeres Fenster**. | Timebox **60/30 Kalendertage** autoritativ (versiegelt, SHA-gepinnt, FTMO-Speed-Doktrin); MC/First-Passage nur Diagnostik. **Richtung der Verzerrung:** Das längere MC-Fenster gibt mehr Zeit, das +10-%-Ziel zu treffen → MC-Pass-Wahrscheinlichkeit ist **strukturell OPTIMISTISCH (aufwärts verzerrt)** gegenüber dem 60-Kalendertage-Estimand und darf **nie** als Beruhigung gegen eine niedrigere Timebox-Untergrenze gelesen werden. |
| **C-6** | **Breach/Joint/P2-Enforcement-Lücke.** Rulepack verlangt sie, aber **keine** Engine im Baupfad liefert eine admissible Schätzung (Builder gated nur P1; MC-Breach ist Lower-Bound; Timebox creditet nur P1-Lower `:1412`). | Gates existieren auf Papier ohne autoritative Engine — und ohne definierte Schätzmethode (wie erzeugt ein Moving-Block-Bootstrap eine **Obergrenze** auf Breach-Events? wie wird Joint-Credit berechnet?). | Diese drei Gates sind **INERT** (können ein Buch weder bestehen noch reißen lassen), BIS (a) OWNER die C-6-Engine scoped, (b) Codex sie baut (Timebox-Erweiterung: credited Breach-Upper + Joint aus den bereits berechneten `joint_rate`/P2-Legs, Methode noch zu spezifizieren) und (c) OWNER sie abnimmt. Der Abnahmetest-Vorlage-`§D` ist aus demselben Grund bereits **inert** (`OWNER_VORLAGE…:§D inert until OQ-2a AND OQ-2b`) — beide Dokumente tragen **identischen INERT-Status**. |

Alles **ROT**. **Kein Auffangregel.** Ratifizierung nur durch OWNER.

---

# ENGLISH CONTRACT — FTMO Probability & Correlation Contract V1

Ratify this text verbatim. Every threshold is a path-referenced EXISTING policy value; this contract invents none. Where two ratified values conflict, the conflict is presented as an explicit OWNER choice (§3 above; OQ list below) with a recommendation — never silently reclassified.

## §A · Scope, authority, and the ratification-status matrix

This contract governs the **probability layer** (P1/P2 pass, breach, joint estimation) and the **correlation/tail layer** of the FTMO book-build and evaluation path. It does **not** touch the provider-rule layer, which is already single-sourced through `ftmo_rule_contract.py` (`FtmoTwoStepContract`, `:36-39`, `load_two_step_contract` `:59-90`, introduced `bc7e3b81`) and is consumed identically by timebox, first-passage and MC.

**Ratification-status matrix (the asymmetry OWNER must resolve — decision C-2):**

| Layer / value | Source | Status |
|---------------|--------|--------|
| FUND_SCORE floor 1.0; P1 lower floor 0.80; max pairwise 0.50; account weight budget 10.0; sleeve weight 1.0; min_sleeves 3; min_active_days 4.0; RISK_FIXED check | `build_book_ftmo.py:53,54,75,76,77,471,472,500-506` | **OWNER_RATIFIED** (OWNER-DEC-BOOK-V2V4V6-EPOCH-20260904, `decisions/2026-09-04_owner_receipts_briefing_2_4.md:21,24-30`) |
| Timebox design_bar_p1 0.80; horizons 60/30; bootstrap 2000/seed20260802/alpha0.05/block60/two-sided95 | `ftmo_timebox_eval.py:90,72,74,94-98` | **RATIFIED** via FTMO_BOOK_SPEC speed doctrine (`docs/research/FTMO_BOOK_SPEC_2026-08-02_OWNER_TIMEBOX.md:19,26,59`) |
| Q15 hard rule `|r| < 0.50` (absolute, single external gate constant) | `portfolio_correlation.py:77` | **ROT / sealed** |
| concentration_tail_limits.v1.json (stop-risk 2.5 %, symbol/class/family caps, tail block) | `concentration_tail_limits.v1.json` | **OWNER_RATIFIED** (receipt `decisions/2026-09-02_owner_receipts_ceo_asks.md:42-49`, CEO-ASK-20260902-4) |
| DSR gate p<0.05 (DSR ≥ 0.95); DSR-Fleet-Default-Trial-Count **N = 369** (`sub_8_2_dsr_mc_fdr.py:34`); Optimierungs-Track-Selektion erweitert auf `N + selection_trial_count − 1` (`:168-178`) | `sub_8_2_dsr_mc_fdr.py:34,168-178` | **RATIFIED** (DL-089). *154 (`opt_census.py:36`) ist der Opt-Census-**Deklarationszähler** (Messung, „not selection", `sub_8_2_dsr_mc_fdr.py:42-45`) — **NICHT** der DSR-Selektionspool.* |
| Rulepack go_criteria: P1 point ≥ 80 / lower ≥ 70; breach upper-95 ≤ 10; P2-cond ≥ 85 / joint ≥ 65; freshness 7 d; shadow ≥ 1 clean / 0 defects | `FTMO_2S_100K_SWING_V2.json:480,486,492,462,498` | **PROPOSED** — `lifecycle_status: RESEARCH_CONTRACT_ONLY` (`:9`), each is `INTERNAL_DECISION_CRITERION` |
| Rulepack internal tail guardrails (0.999-quantile / 3 % / 2 % buffer; 7 % total-DD; 1.5 % cluster) | `FTMO_2S_100K_SWING_V2.json:299-350` | **PROPOSED** — `PROPOSED_FOR_CALIBRATION` (`:275` etc.) |
| V4 correlation knobs (FDR alpha 0.05, lambda* 1.5, caution band 0.05, COS overlaps, signed min co-days 20, bootstrap B 4000 / seed 20260903, saturation 0.50) | `portfolio_correlation.py:82-106` | **WORKING_DEFAULT_OPEN_OWNER_ITEM** — proposed, ROT-once-ratified, NOT yet ratified |

**Rule of construction:** the **strictest existing RATIFIED value** binds. Where a ratified and a proposed value differ, the ratified value binds and the proposed value is carried as a **declared-but-not-yet-sealed** gate (blocks a book, does not yet count as purchase-grade) until OWNER elevates it (C-2) — UNLESS the ratified value already **subsumes** the proposed one (as at the P1 gate, C-1: `lower_95 ≥ 0.80` implies `point ≥ 0.80` and dominates `lower ≥ 0.70`, so the proposed rulepack P1 gate adds nothing and is documentation-only). Two genuinely **ratified** values in conflict = OWNER choice — none arises in this contract (C-1 is ratified-vs-proposed and resolves by subsumption; the correlation caps C-3 are layered, not conflicting).

## §B · Probability definitions (single authoritative estimator)

**B.1 · Authoritative engine.** The **timebox evaluator** (`ftmo_timebox_eval.py`) is the single authoritative decision engine for the P1/P2 pass-probability estimand. It is selection-sealed (prepare-config freezes input SHAs before any stream opens), refuses mutable DB/farm-state inputs (`:218-235,:345-346`), and is FTMO-cost-attested (`REFUSED_FTMO_COST_ATTESTATION` on DXZ streams). MC (`ftmo_p1_mc.py`) and first-passage (`challenge_firstpassage.py`) are **diagnostics only** and may never be the acceptance number.

**B.2 · Bootstrap method and horizon.** Moving-block bootstrap on daily rates: replicates 2000 (floor enforced ≥ 100, `:306-307`), seed 20260802, alpha 0.05, block length 60 calendar days, two-sided 95 % percentile CI — `lower = percentile(alpha/2)`, `median`, `upper = percentile(1-alpha/2)` (`:1010-1012`). Horizons: **Phase-1 = 60 calendar days** (`:72`), **Phase-2 = 30 calendar days** (`:74`). (Decision C-5: 60/30 calendar is authoritative; MC's 90 trading days and first-passage's unlimited horizon are diagnostic conventions and do not bind the estimand.) **Directional bias, not just mismatch:** MC's 90 trading days ≈ 126 calendar days vs the authoritative 60 calendar days (≈ 43 trading days) is a ≈ 3× longer window; more time to reach the +10 % target makes the MC pass-probability **structurally OPTIMISTIC (upward-biased)** relative to the 60-calendar-day estimand. A high MC pass number is therefore **never** reassurance against a lower timebox bound (`ftmo_p1_mc.py:79` = 90 trading; `ftmo_timebox_eval.py:72` = 60 calendar).

**B.3 · Lower-bound convention.** The pass-probability decision is read on the **moving-block-bootstrap LOWER bound**, never the raw pass rate (`build_book_ftmo.py:449`, `ftmo_timebox_eval.py:90,1412-1414`, first-passage `:415,421`). `<<` semantics: the lower bound alone clears the bar; `<` the point estimate only.

**B.4 · P1 pass gate (single binding gate; decision C-1 resolved by construction).** The one binding gate is **`P1_lower_95 >= 0.80`** (ratified, `build_book_ftmo.py:54`, `ftmo_timebox_eval.py:90`). Because the moving-block-bootstrap lower bound is by construction **≤** the point estimate (`ftmo_timebox_eval.py:1008-1010`: `lower = percentile(α/2) ≤ median`; enforced in the builder at `:447`: `0 ≤ lower ≤ estimate ≤ 1`), a passing `lower_95 >= 0.80` **already implies `point >= 0.80`**. The ratified lower ≥ 0.80 therefore **subsumes the entire rulepack P1 gate** — both its `point >= 80` (automatic) and its **weaker** `lower >= 70` (dominated). The rulepack's `point >= 80` (`:480`) is kept only as documentation of the rulepack's dominated intent and is explicitly **non-additive**: it can never add a binding constraint on top of `lower_95 >= 0.80`. No OWNER arbitration is required for C-1.

**B.5 · Breach probability — INERT until the C-6 engine exists (decision C-6).** Breach probability is the probability of a daily-loss or total-loss barrier hit, to be read as an **UPPER 95 bound** for a rejection gate: `breach_upper_95 <= 0.10` (rulepack `:486`, PROPOSED). **No engine can estimate this today, and no estimator method is yet defined:** MC produces breach only as a **lower** bound (rules on closed daily P&L; intraday floating DD invisible, `:30-31,709-710`) and is structurally unable to satisfy an upper-95 gate; the timebox does not compute a breach upper bound at all. How a moving-block bootstrap yields an admissible **upper** bound on breach events is an unresolved method question (barrier definition, upper-bound construction) that Codex must not decide unilaterally. This gate is therefore **INERT**: it can neither pass nor fail a book until (a) OWNER scopes the C-6 estimator, (b) Codex implements it, and (c) OWNER approves it. Its enforcement status is **identical to the acceptance-test Vorlage's §D, which is likewise inert** until OQ-2a/2b are answered.

**B.6 · Joint / P2-conditional probability — INERT until the C-6 engine exists (decision C-6).** `P2_conditional >= 0.85` **AND** `joint_two_phase >= 0.65` (rulepack `:492`, PROPOSED). The timebox already computes `joint_rate` (`:1129`) and a P2 30-day leg (`:894-904`), but the credited decision currently reads only `p1_bootstrap['lower']` (`:1412`), and **no joint-credit formula is yet specified** (how the P2-conditional and joint two-phase probabilities are constructed as admissible bounds). Like B.5, this gate is **INERT** — it neither passes nor fails a book — until the C-6 engine is scoped, built, and OWNER-approved. Enforcement status is kept **identical** between this contract and the Vorlage: neither document may pass or fail on an unestimable gate.

**B.7 · Sample-size / abstention (predeclared, from existing policy).**
- Error rate: bootstrap alpha 0.05 two-sided (`:96`); DSR p < 0.05 (`sub_8_2_dsr_mc_fdr.py:33`).
- Opening-day floor: ≥ 4 CE(S)T days with a position opened per phase (rulepack `:151-160`; enforced `challenge_firstpassage.py:158`).
- Effective (not raw) n: HAC effective sample size for autocorrelated overlapping starts (`ftmo_timebox_eval.py:927`); first-passage divides overlapping starts by median resolution time and reports ESS with a Wald half-width (`:395,419-420`) — report ESS, never the raw start count.
- **Minimum-power floor (binding):** a single diagnostic OOS window (13 weeks, one seed, one config, mostly D1-entry sleeves) does NOT meet the floor and is declared **UNDER-POWERED / NON-LIFTING on its own** (identical to Vorlage §C). Widening to a multi-seed / multi-window sealed holdout is the OWNER OQ-2 choice.
- **Abstention regimes (unified surface):** timebox → `NO_ADMISSIBLE_COMPOSITION` (`:1424`), `REFUSED_SENSITIVITY` on non-monotone spread bootstrap (`:1385-1387`); builder → `CLUSTER_CORRELATION_UNVERIFIED` fail-closed when any pair correlation is unknown (`:278-282`); V4 correlation → ABSTAIN when the block-bootstrap CI straddles 0.50, PROVISIONAL inside the caution band 0.05 (`portfolio_correlation.py:61-63,87`). All three are fail-closed: **absence of an admissible estimate blocks, never passes.**

**B.8 · DSR / multiple-testing correction (orthogonal, not one of the three portfolio engines).** Deflated Sharpe / E[max SR under the null] is computed by `framework/scripts/q08_davey/sub_8_2_dsr_mc_fdr.py` (Bailey & López de Prado): acceptance `DSR_P_MIN = 0.05` (DSR ≥ 0.95, `:33`), `E[max SR] ≈ sqrt(2 ln N)` over the DSR fleet default **`N_CANDIDATE_STRATEGIES = 369`** (`:34`). For optimization-track selections the count is expanded to `N + selection_trial_count − 1` (`:168-178`) — the sleeve competes against the fleet cohort AND its own sibling configurations. **The 154 (`opt_census.py:36`) is the opt-census DECLARATION count — a census measurement, explicitly "not selection" (`sub_8_2_dsr_mc_fdr.py:42-45`) — and is NOT the DSR selection pool.** (An earlier draft mis-anchored 154 as the DSR trial count; corrected here to the engine's real fleet default 369. Changing 369 itself is a ROT change to a live gate constant and would need its own dated OWNER decision — it is not touched here.) This is a **necessary, separate gate** alongside the probability gate — in-sample PF>1 never substitutes for it.

## §C · Correlation and tail semantics (single standard)

**C.1 · Single correlation estimator (decision C-4).** The adopted **V4 sparse-D1 two-layer standard** (`docs/research/SPARSE_D1_ORTHOGONALITY_STANDARD_2026-09-03.md`, encoded in `portfolio_correlation.py:57-77`) is the single standard:
- **Layer A (ZK-SBB, primary certifier):** zeros-KEPT daily-return Pearson on the exogenous Mon–Fri business-day grid over the common-support intersection, with a stationary block-bootstrap 95 % CI. **CERTIFY_A iff the whole CI lies inside `|r| < 0.50`, else ABSTAIN** (never a raw point pass); PROVISIONAL inside the caution band 0.05 (`:61-63,87`).
- **Layer B (COS, supplementary flag only):** trade-level open-position co-occupancy; an additive flag, never a certifier.

The builder currently consumes the **zeros-DROPPED active-only point Pearson** matrix (`portfolio_correlation.py:184-197`, min_overlap 60 `:117`) — this contradicts the module's own adopted standard and is the **primary migration item** (§F).

**C.2 · Correlation caps (layered, absolute; decision C-3).** Three ratified/sealed caps compose as **stage-specific layers**, not one number, all on the **ABSOLUTE** value:
- `|r| < 0.50` — the single **hard book-admission** gate (Q15 `portfolio_correlation.py:77`, ROT/sealed; the builder's `0.50` `:75` is the same cap but must be migrated from raw-signed `:283` to absolute).
- `|r| >= 0.40` — the tighter **Q09 marginal-eval / timebox budget** reject, **enforced solely in the timebox** (`ftmo_timebox_eval.py` `DEFAULT_CORRELATION.maximum_budget_exclusive = 0.40`, `:103`, applied `:1092`). `build_book_ftmo.py:68-69` is only a **provenance comment** ("DL-083 sets the Q09 marginal-eval reject at 0.40"); the builder itself enforces **only** the 0.50 cap (`:75`, gate at `:283`) — it does not enforce 0.40.
- `|r| >= 0.15` — the timebox **"strong" warning band** (`strong_budget_exclusive` `:102`), advisory not blocking.

Timebox `effective_correlation` = MAX of full-window and high-volatility-subset (quantile 0.75) pairwise absolute Pearson, minimum 20 shared calendar days (`:104-106`).

**C.3 · Tail / concentration composition (orthogonal layers).** Four distinct concepts compose; they are **not reducible to one number**:
1. **Stop-risk budget** — `concentration_tail_limits.v1.json` (OWNER_RATIFIED): 2.5 % budget split by symbol 40 / asset_class 60 / family 50 (% of budget), session WARN 60 / breach 70; tail per_sleeve_worst_fraction 0.05, joint_sleeve_divisor 3, venue_daily_loss_limit_pct 5.0, maximum_fraction_of_daily_limit 0.8. Applied via `concentration_tail.evaluate` (`build_book_ftmo.py:519-529`). `application_authority OWNER_ONLY`, `deployment_action NONE`.
2. **Account weight budget** — builder `account_weight_budget = 10.0` unit weights, each **sleeve** 1.0 (`:76,77`): a sleeve-COUNT ceiling (≤ 10 unit-weight sleeves), a different dimension from the stop-risk %.
3. **Q15 discrete count caps (OWNER_RATIFIED, same epoch decision)** — `family <= 3`, `symbol <= 2`, target **10–15 EAs** (`build_book_ftmo.py:60,66`, under OWNER-DEC-BOOK-V2V4V6-EPOCH-20260904). A distinct concentration dimension from both the % budget and the weight budget. **Unreconciled numeric tension (OWNER item, OQ-9):** the 10.0 unit-weight budget admits at most **10** sleeves, but the Q15 target is **10–15 EAs** — 10 unit-weight sleeves cannot reach 15. This is only consistent if a **sleeve ≠ an EA** (e.g. multiple EAs share a sleeve, or the weight budget is CLI-raised for a wider book). The sleeve-vs-EA unit must be clarified by OWNER before the two count-based controls can both bind; this contract does **not** silently pick one. No new number is proposed either way.
4. **Rulepack internal tail guardrails** (`FTMO_2S_100K_SWING_V2.json:299-350`, PROPOSED_FOR_CALIBRATION): the ratified `concentration_tail_limits.v1.json` **supersedes** these for the tail dimension; the rulepack guardrails are **suspended** until OWNER ratifies them.

## §D · Versioning and change control (ROT)

- This is **contract version `v1`** (`ftmo_probability_contract.v1.json`). Any change to a definition, threshold, estimator, horizon, correlation cap, tail composition, or ratification-status binding is a **ROT** change requiring a dated OWNER decision and a version bump (`v1 → v2`). No silent reclassification; no in-place threshold edit.
- The contract **imports** thresholds by path+line reference from the ratified sources; it never restates a number as an independent literal that could drift. A migration (§F) that moves an engine onto the contract must keep the imported value byte-identical or bump the version with an OWNER decision.
- **Unit / type conversion (rulepack → contract).** The rulepack stores its probability go_criteria as decimal **percent STRINGS** (`"80"`, `"70"`, `"10"`, `"85"`, `"65"`; `numeric_encoding: NON_INTEGRAL_AS_DECIMAL_STRING`, `FTMO_2S_100K_SWING_V2.json:12`), whereas this contract and its schema (§E) express them as **float fractions** (`0.80`/`0.10`/`0.85`/`0.65`). The conversion is exactly **`float(string) × 0.01`** (so rulepack `"10"` → `0.10`, never `10.0`). The "imported byte-identical" claim is only verifiable after this conversion; a parity test (§F, rulepack row) must assert each schema value equals its rulepack source × 0.01 so the percent→fraction step cannot silently drift.
- The **acceptance-test Vorlage** (`OWNER_VORLAGE_2026-09-05_ftmo_positive_evidence_test.md`) must carry thresholds **identical** to this contract or explicitly derived from it. Where the Vorlage cites stale line anchors (its timebox `:63/:65/:77/:83/:85/:92` and `fund_score.py:94-103`), this contract's corrected anchors govern (timebox horizons `:72/:74`, design_bar `:90`, bootstrap `:94-98`, min-shared `:105`; fund_score computed `:59-65`, no formula string at `:94-103`). Re-verify all cross-branch anchors at seal (Vorlage §E, OQ-6).

## §E · Embedded JSON schema proposal (code block, NOT written as a file)

The following is the proposed `tools/strategy_farm/config/ftmo_probability_contract.v1.json`. It is presented here as a **specification for Codex to implement**; per this task it is **not written to disk**. Numbers are imports carried from the ratified sources with their provenance; no value is invented.

```json
{
  "schema": "qm.ftmo-probability-correlation-contract/v1",
  "status": "PENDING_OWNER_RATIFICATION",
  "class": "ROT",
  "auffangregel": false,
  "supersedes": null,
  "binds_vorlage": "docs/ops/OWNER_VORLAGE_2026-09-05_ftmo_positive_evidence_test.md",
  "construction_rule": "STRICTEST_EXISTING_RATIFIED_VALUE_BINDS; ratified-vs-proposed => ratified binds, proposed carried as declared-not-sealed additive gate; ratified-vs-ratified conflict => OWNER_CHOICE",
  "probability": {
    "authoritative_engine": {
      "module": "tools/strategy_farm/portfolio/ftmo_timebox_eval.py",
      "role": "AUTHORITATIVE_DECISION",
      "selection_sealed": true,
      "refuses_mutable_inputs": true,
      "cost_attested": true
    },
    "diagnostic_engines": [
      {"module": "tools/strategy_farm/portfolio/ftmo_p1_mc.py", "role": "DIAGNOSTIC_ONLY", "note": "independent sleeve resample breaks cross-correlation; breach is a LOWER bound"},
      {"module": "tools/strategy_farm/portfolio/challenge_firstpassage.py", "role": "DIAGNOSTIC_ONLY", "note": "unlimited-horizon first-passage; stages 1-2 in-sample-selected"}
    ],
    "bootstrap": {
      "method": "MOVING_BLOCK",
      "replicates": 2000,
      "replicates_floor": 100,
      "seed": 20260802,
      "alpha": 0.05,
      "block_calendar_days": 60,
      "ci": "TWO_SIDED_PERCENTILE_95",
      "source": "ftmo_timebox_eval.py:94-98,1010-1012"
    },
    "horizon": {
      "phase1_calendar_days": 60,
      "phase2_calendar_days": 30,
      "authoritative": "TIMEBOX_60_30_CALENDAR",
      "diagnostic_conventions": {"mc_trading_days": 90, "firstpassage": "UNLIMITED"},
      "source": "ftmo_timebox_eval.py:72,74; ftmo_p1_mc.py:79; challenge_firstpassage.py:263"
    },
    "lower_bound_convention": "MOVING_BLOCK_BOOTSTRAP_LOWER, never raw rate",
    "gates": {
      "p1_pass": {
        "binding_gate": "lower_95_min",
        "lower_95_min": 0.80,
        "lower_95_status": "RATIFIED",
        "lower_95_source": "build_book_ftmo.py:54; ftmo_timebox_eval.py:90",
        "point_min": 0.80,
        "point_status": "NON_ADDITIVE_DOMINATED",
        "point_source": "FTMO_2S_100K_SWING_V2.json:480",
        "subsumption": "lower<=point is guaranteed (ftmo_timebox_eval.py:1008-1010; build_book_ftmo.py:447 enforces 0<=lower<=estimate<=1), so lower_95>=0.80 implies point>=0.80 AND dominates the rulepack's weaker lower>=0.70; the whole rulepack P1 gate is subsumed",
        "owner_choice": "C-1 resolved by construction: single binding gate lower_95>=0.80; no OWNER arbitration required; point>=0.80 kept as documentation only, never additive"
      },
      "breach": {
        "upper_95_max": 0.10,
        "status": "PROPOSED",
        "enforcement_status": "INERT_UNTIL_C6_ENGINE_OWNER_APPROVED",
        "source": "FTMO_2S_100K_SWING_V2.json:486",
        "enforcement_gap": "C-6: MC breach is a LOWER bound; no engine estimates an admissible UPPER bound and no estimator method is yet defined; INERT (cannot pass or fail a book) until OWNER scopes + Codex builds + OWNER approves the C-6 engine; status identical to Vorlage inert-§D"
      },
      "two_phase": {
        "p2_conditional_min": 0.85,
        "joint_min": 0.65,
        "status": "PROPOSED",
        "enforcement_status": "INERT_UNTIL_C6_ENGINE_OWNER_APPROVED",
        "source": "FTMO_2S_100K_SWING_V2.json:492",
        "enforcement_gap": "C-6: timebox computes joint_rate/P2 leg but credits only p1 lower (:1412); no joint-credit formula specified; INERT until the C-6 engine exists and is OWNER-approved; status identical to Vorlage inert-§D"
      },
      "snapshot_freshness_days_max": {"value": 7, "status": "PROPOSED", "source": "FTMO_2S_100K_SWING_V2.json:462"},
      "shadow_run": {"minimum_runs": 1, "operational_defects_allowed": 0, "status": "PROPOSED", "source": "FTMO_2S_100K_SWING_V2.json:498"}
    },
    "dsr_correction": {
      "engine": "framework/scripts/q08_davey/sub_8_2_dsr_mc_fdr.py",
      "role": "NECESSARY_SEPARATE_GATE",
      "dsr_p_min": 0.05,
      "dsr_prob_min": 0.95,
      "expected_max_sr": "sqrt(2 ln N)",
      "fleet_default_trial_count_N": 369,
      "optimization_track_expansion": "N + selection_trial_count - 1 when selection_trial_count>=2 (sub_8_2_dsr_mc_fdr.py:168-178)",
      "trial_count_override": "sealed per-identity selection_trial_count where present",
      "note_154": "154 (opt_census.py:36) is the opt-census DECLARATION count (census measurement, 'not selection', sub_8_2_dsr_mc_fdr.py:42-45); NOT the DSR selection pool",
      "status": "RATIFIED",
      "source": "sub_8_2_dsr_mc_fdr.py:34,168-178; opt_census.py:36"
    },
    "sample_size": {
      "opening_days_floor_per_phase": 4,
      "effective_n": "HAC_ESS for overlapping starts; report ESS not raw count",
      "min_power_floor": "single 13-week diagnostic window = UNDER_POWERED / NON_LIFTING",
      "abstention": "fail-closed: NO_ADMISSIBLE_COMPOSITION / CLUSTER_CORRELATION_UNVERIFIED / ABSTAIN block, never pass",
      "source": "FTMO_2S_100K_SWING_V2.json:151-160; ftmo_timebox_eval.py:306,927,1424; build_book_ftmo.py:278-282"
    }
  },
  "correlation": {
    "estimator": {
      "standard": "V4_SPARSE_D1_TWO_LAYER",
      "layer_a": {"name": "ZK-SBB", "method": "ZEROS_KEPT_MONFRI_GRID_PEARSON_BLOCK_BOOTSTRAP_CI", "decision": "CERTIFY_A iff whole CI < 0.50 (absolute) else ABSTAIN; PROVISIONAL in caution band"},
      "layer_b": {"name": "COS", "role": "SUPPLEMENTARY_FLAG_ONLY"},
      "caution_band": 0.05,
      "source": "portfolio_correlation.py:57-77,87; docs/research/SPARSE_D1_ORTHOGONALITY_STANDARD_2026-09-03.md",
      "migration_note": "builder currently consumes zeros-DROPPED point Pearson (:184-197); migrate to Layer-A certified CI"
    },
    "caps_absolute_layered": {
      "hard_book_admission": {"value": 0.50, "status": "ROT_SEALED", "source": "portfolio_correlation.py:77 (Q15); build_book_ftmo.py:75"},
      "q09_marginal_timebox_reject": {"value": 0.40, "status": "RATIFIED", "enforced_in": "ftmo_timebox_eval.py:103 (DEFAULT_CORRELATION.maximum_budget_exclusive), applied :1092", "provenance_comment_only": "build_book_ftmo.py:68-69 (DL-083) is a comment; the builder enforces only the 0.50 cap, not 0.40", "source": "ftmo_timebox_eval.py:103,1092"},
      "timebox_strong_warning": {"value": 0.15, "status": "ADVISORY", "source": "ftmo_timebox_eval.py:102"},
      "signed_vs_absolute": "ALL ABSOLUTE; builder must migrate from raw-signed (:283) to absolute"
    },
    "effective_correlation": {"definition": "MAX(full_window, high_vol_subset q0.75) pairwise ABSOLUTE Pearson", "min_shared_calendar_days": 20, "source": "ftmo_timebox_eval.py:104-106"}
  },
  "tail": {
    "authoritative": "concentration_tail_limits.v1.json",
    "status": "OWNER_RATIFIED",
    "orthogonal_layers": {
      "stop_risk_budget_pct": {"value": 2.5, "caps_pct_of_budget": {"symbol": 40, "asset_class": 60, "family": 50, "session_warn": 60, "session": 70}, "tail": {"per_sleeve_worst_fraction": 0.05, "joint_sleeve_divisor": 3, "venue_daily_loss_limit_pct": 5.0, "maximum_fraction_of_daily_limit": 0.8}, "source": "concentration_tail_limits.v1.json:5-17"},
      "account_weight_budget": {"value": 10.0, "sleeve_unit_weight": 1.0, "dimension": "SLEEVE_COUNT_CEILING (<=10 unit-weight sleeves)", "source": "build_book_ftmo.py:76,77"},
      "q15_discrete_count_caps": {"family_max": 3, "symbol_max": 2, "ea_target_range": [10, 15], "status": "OWNER_RATIFIED", "decision": "OWNER-DEC-BOOK-V2V4V6-EPOCH-20260904", "dimension": "DISCRETE_COUNT", "unreconciled_tension_OQ9": "10.0 unit-weight budget admits <=10 sleeves but Q15 targets 10-15 EAs; consistent only if sleeve != EA; OWNER must clarify sleeve-vs-EA unit before both bind; no new number proposed", "source": "build_book_ftmo.py:60,66"},
      "rulepack_internal_guardrails": {"status": "SUSPENDED_PROPOSED", "note": "concentration_tail_limits.v1.json supersedes for tail dimension until OWNER ratifies", "source": "FTMO_2S_100K_SWING_V2.json:299-350"}
    },
    "application_authority": "OWNER_ONLY",
    "deployment_action": "NONE"
  },
  "change_control": {
    "class": "ROT",
    "version_bump_requires": "dated OWNER decision",
    "no_silent_reclassification": true,
    "thresholds_imported_by_reference": true
  },
  "open_owner_choices": ["C-1", "C-2", "C-3", "C-4", "C-5", "C-6"]
}
```

## §F · Migration table (engine-by-engine — what changes, what tests)

| Engine / module | Current behavior | Target under this contract | What changes (Codex) | Tests required |
|-----------------|------------------|----------------------------|----------------------|----------------|
| `build_book_ftmo.py` | Gates FUND_SCORE + P1 lower ≥ 0.80 only (`:547,449`); pairwise corr on RAW SIGNED value ≤ 0.50 (`:283`); consumes zeros-dropped point-Pearson matrix | Consume V4 Layer-A certified CI; add point ≥ 0.80 additive gate (C-1); add breach/joint gates once estimable (C-6); corr on ABSOLUTE value | Switch corr source to Layer-A CERTIFY_A/ABSTAIN; abs() the corr comparison at `:283`; wire point/breach/joint gates | Golden test: raw-signed vs absolute corr rejection parity; ABSTAIN-blocks-admission; point-gate additivity; unchanged FUND_SCORE math |
| `ftmo_timebox_eval.py` | Credits only `p1_bootstrap['lower']` (`:1412`); computes but does not credit `joint_rate`/P2 leg | Remain authoritative; breach/joint/P2 gates stay **INERT** until a C-6 estimator is (a) method-specified, (b) OWNER-scoped, (c) implemented, (d) OWNER-approved | **Do not implement until the C-6 method is specified and OWNER-approved** (barrier definition, bootstrap UPPER-bound construction, joint-credit formula are undefined and are OWNER/design calls, not a Codex judgment). Then add credited breach-upper + joint estimators in the decision block | New unit tests for breach-upper monotonicity, joint credit (only once the method exists); unchanged 60/30 horizon + bootstrap params; seal-determinism |
| `ftmo_p1_mc.py` | Reports pass/breach as LOWER bounds; **90 trading-day** horizon (`:79`) ≈ 126 calendar days vs authoritative 60 calendar → pass-prob structurally **OPTIMISTIC / upward-biased**; independent sleeve resample | Diagnostic only; labeled non-authoritative; horizon banner states the UPWARD bias direction, never just "mismatch" | Tag output `role: DIAGNOSTIC_ONLY`; add a horizon-bias banner ("90 trading ≈ 126 calendar > 60 calendar → optimistic; never a lower reassurance") | Assert MC output never enters the credited decision path; assert the banner carries the bias DIRECTION |
| `challenge_firstpassage.py` | Unlimited-horizon first-passage; stages 1-2 in-sample-selected; preregistered 1x block selection-free | Diagnostic only; only preregistered 1x block reportable, never the acceptance number | Tag `role: DIAGNOSTIC_ONLY`; guard stages 1-2 out of any acceptance read | Assert stages 1-2 excluded from acceptance; ESS reported not raw n |
| `portfolio_correlation.py` | Scalar output = zeros-DROPPED active-only Pearson (`:184-197`); V4 standard present in docstring but not the emitted scalar | Emit V4 Layer-A certified CI (CERTIFY_A iff CI < 0.50 else ABSTAIN) as the consumed estimand | Make the certified CI the default emitted scalar the builder loads | Parity test zeros-kept vs zeros-dropped on fixtures; ABSTAIN on straddling CI; PROVISIONAL in caution band |
| `ftmo_rule_contract.py` | Single-sourced provider fractions only (no probability/corr numbers) | Unchanged — provider layer stays single-sourced | None | Regression: projected fractions unchanged |
| `FTMO_2S_100K_SWING_V2.json` | `RESEARCH_CONTRACT_ONLY`; go_criteria PROPOSED, probabilities stored as decimal **percent STRINGS** (`numeric_encoding` `:12`) | Elevated to ratified only by OWNER (C-2); internal tail guardrails suspended by ratified concentration config; imported into the contract via `float(str) × 0.01` → fraction | If C-2 = elevate: flip `lifecycle_status`; else keep PROPOSED and mark gates declared-not-sealed. Import step must apply `× 0.01` (percent-string → fraction), never treat `"10"` as `10.0` | Schema validation; status-consistency assert; **parity test: each imported schema fraction == source percent-string × 0.01** (so §D's "imported byte-identical" is verifiable) |
| `sub_8_2_dsr_mc_fdr.py` | DSR p<0.05, fleet-default trial count **N = 369** (`:34`), optimization expansion `N + selection_trial_count - 1` (`:168-178`) | Unchanged — orthogonal necessary gate; the engine already uses 369 (only the contract's prior mis-anchor to 154 is corrected, no code change) | None (code unchanged) | Regression: DSR threshold + N=369 fleet default + selection-expansion binding unchanged; assert 154 (opt-census declaration) is never used as the selection pool |
| `concentration_tail_limits.v1.json` | OWNER_RATIFIED, application OWNER_ONLY | Single tail authority; supersedes rulepack guardrails | None (config already ratified) | Assert rulepack guardrails are not applied while this is authoritative |

## §G · Cross-reference to the acceptance-test Vorlage

`docs/ops/OWNER_VORLAGE_2026-09-05_ftmo_positive_evidence_test.md` (**R3**, canonical branch commit `a0fa292e91`/`5bac8eaccb`) is either **identical to** or **explicitly derived from** this contract. Where an earlier draft said "identical" without derivation, the derivation is now stated so OWNER can see exactly which number each document operatively enforces:

- **P1 bar — derived, and now in lockstep (not naively "identical").** The rulepack SOURCE values are `point >= 80 % AND lower-95 >= 70 %` (Vorlage §B criterion 4, `:118`; rulepack `:480`). But the Vorlage's **operative go-criterion** is not 70: its §D (`:272`) and §F seal (`:344`) enforce the **intersection `point >= 0.80 AND lower-95 >= 0.80`** pending P7a. Under this contract's C-1 (§B.4) the single binding gate is `lower_95 >= 0.80`, which — because `lower <= point` always (`ftmo_timebox_eval.py:1008-1010`; `build_book_ftmo.py:447`) — subsumes both the rulepack's `point >= 80` and its weaker `lower >= 70`. The Vorlage acknowledges the same construction at its §C.4 (`:148`: a point of exactly 0.80 can never pass because the lower is strictly below it). **Net: both documents operatively bind `lower_95 >= 0.80`; they are in lockstep at the 0.80 intersection, not at 70.** The rulepack's `point 80 / lower 70` is carried in both only as the PROPOSED source, non-additive.
- §B builder floors (FUND_SCORE 1.0, P1 lower 0.80, corr 0.50, weight budget 10.0) = this contract §A ratified block.
- §B speed doctrine (60/30, design bar 0.80 lower) = this contract §B.2–B.3. (The Vorlage R3 already carries the corrected timebox anchors `:72/:74/:90/:94-98` and tabulates the stale-anchor drift in its own §G; R2's stale `:63/:65/:77/:81-85` are gone.)
- **DSR — corrected in lockstep.** This contract §B.8 now anchors the DSR fleet default at **N = 369** (`sub_8_2_dsr_mc_fdr.py:34`) with per-identity `selection_trial_count` expansion, and treats 154 as the opt-census declaration only. The Vorlage R3 already states the same: DSR "over the sealed per-identity `selection_trial_count` — never the 154 measured census arms" (`:344`). The two are consistent; a document still citing 154 as the DSR pool would be the drift, and neither now does.
- §C minimum-power floor (single 96-day / one non-overlapping P1 window = non-lifting) = this contract §B.7 (Vorlage §C.4 / R-1).
- §B concentration/tail = this contract §C.3 (including the Q15 `family<=3 / symbol<=2 / 10–15 EAs` caps and the OQ-9 weight-vs-EA-count tension).
- **Breach/joint/P2 enforceability — identical INERT status.** This contract marks these gates INERT until the C-6 engine exists and is OWNER-approved (§B.5/B.6); the Vorlage's §D is likewise inert ("§D inert until OQ-2a AND OQ-2b are answered", `:344`). Neither document can pass or fail on an unestimable gate.

Any future edit must keep the two documents in lockstep or bump both under one OWNER decision (§D). If OWNER moves the P1 bar off the 0.80 intersection (e.g. resolves P7a to the rulepack-only 0.70 reading), **both** documents must be re-issued together under that one decision.

## §H · Open questions for OWNER (do not resolve unilaterally)

- **OQ-1 (= C-1, ROT — resolved by construction, confirmation only):** P1 bar. The ratified builder/timebox bootstrap **lower ≥ 0.80** is the single binding gate; because `lower ≤ point` always (`ftmo_timebox_eval.py:1008-1010`; `build_book_ftmo.py:447`), it **subsumes** the rulepack's `point ≥ 80` (automatic) and its weaker `lower ≥ 70` (dominated). No genuine conflict, no arbitration — OWNER need only **confirm** that `lower_95 ≥ 0.80` is the operative P1 gate and that the rulepack `point 80 / lower 70` is documentation-only. No new number.
- **OQ-2 (= C-2, ROT, blocks binding of breach/joint/P2/freshness):** Does OWNER elevate the rulepack go_criteria from `RESEARCH_CONTRACT_ONLY` to ratified so the contract binds them, or do they remain declared-but-not-sealed gates? Not resolvable by Claude.
- **OQ-3 (= C-3, ROT):** Correlation cap unification — 0.50 hard admission (absolute), 0.40 Q09/timebox marginal reject, 0.15 timebox strong warning; layered, not one number; builder migrated to absolute.
- **OQ-4 (= C-4):** Migrate the builder from zeros-dropped point Pearson to the V4 Layer-A certified CI (biggest methodological gap) — confirm as the migration item.
- **OQ-5 (= C-5):** Confirm timebox 60/30 calendar as the authoritative horizon; MC 90-trading-day and first-passage unlimited as diagnostics only.
- **OQ-6 (= C-6):** Breach/joint/P2 enforcement — mandate the timebox breach-upper/joint extension (Codex) before these gates bind, or park them as declared-but-not-yet-estimable? Needs OWNER scoping.
- **OQ-7 (tail composition):** Confirm the three tail layers (concentration_tail 2.5 % stop-risk, builder 10.0 weight budget, rulepack guardrails) are orthogonal, with the ratified concentration config superseding the proposed rulepack guardrails.
- **OQ-8 (anchor drift):** The Vorlage's stale line anchors are corrected here; re-verify all cross-branch anchors at seal (Vorlage §E / OQ-6).
- **OQ-9 (concentration unit — sleeve vs EA, ROT):** The ratified `account_weight_budget = 10.0` (unit weight 1.0) admits at most **10** sleeves, but the ratified Q15 target is **10–15 EAs** (`build_book_ftmo.py:60,66`). These reconcile only if a **sleeve ≠ an EA**. OWNER must clarify the sleeve-vs-EA unit (or raise the weight budget under a dated decision) before both count-based controls can bind. This contract proposes no new number and picks neither reading unilaterally.

---

*Provenance: builder OWNER-DEC-BOOK-V2V4V6-EPOCH-20260904 (`decisions/2026-09-04_owner_receipts_briefing_2_4.md`); concentration ratification (`decisions/2026-09-02_owner_receipts_ceo_asks.md:42-49`); V4 standard (`docs/research/SPARSE_D1_ORTHOGONALITY_STANDARD_2026-09-03.md`); rulepack `FTMO_2S_100K_SWING_V2.json` (RESEARCH_CONTRACT_ONLY).*
*Anchor-verification scope (honest split): the **engine anchors** — `build_book_ftmo.py`, `ftmo_timebox_eval.py`, `ftmo_p1_mc.py`, `challenge_firstpassage.py`, `portfolio_correlation.py`, `sub_8_2_dsr_mc_fdr.py`, `opt_census.py`, `concentration_tail_limits.v1.json`, the rulepack — were re-verified line-by-line **against live files in this worktree** on 2026-09-05 and are correct as cited. The **§G cross-reference to `OWNER_VORLAGE_2026-09-05_ftmo_positive_evidence_test.md`** could NOT be verified here: that file does not exist on this worktree branch (it is present only on `agents/board-advisor` / `main`, R3 at commit `a0fa292e91`). Its §D/§F/§C.4/§G anchors are cited **`[cross-branch — re-verify at seal]`** (adopting the Vorlage's own convention); the sealing step must re-confirm them on the branch that carries both documents.*
