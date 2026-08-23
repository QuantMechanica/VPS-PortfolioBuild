# Pipeline Overview — Q-Series, linear, drei Makrophasen (v4)

**Kanonische Quelle (Ziel):** `tools/strategy_farm/config/gate_manifest.v4.json` (linearer
3-Phasen-Vertrag) und `decisions/2026-08-23_owner_gate_manifest_v4_linear.md` im Repo. Diese
Vault-Seite spiegelt den Vertrag für Menschen.

> **Staging-Status 2026-08-23:** v4 ist ein **Design-/Migrations-Entwurf**
> (`gate_manifest.v4.draft.json`, `status=DRAFT_PROPOSAL_NOT_ACTIVATED`, READ_INERT,
> `default_manifest_switch=false`). Der **aktive Runtime-Vertrag bleibt v3**
> (`gate_manifest.v3.json`) bis zur OWNER-Ratifikation der IDs/Fenster (ROT). v4 ändert **keine**
> Kriterien, Schwellen, Seeds oder Fenster — nur Reihenfolge, IDs und Phasengruppierung, und
> entfernt die zwei Nicht-Linearitäten (Q10A-vor-Q09, Rücksprung Q16→Q11). Diff-Tabelle:
> [[Gate Manifest v4 Diff]] · Direktive: [[Pipeline Rebaseline Directive 2026-08-23]].

**Topologie:** streng monotoner Standardweg **Q00 → Q17** in drei sichtbaren Makrophasen.
Jede `next`-Kante ist entweder `null` oder der unmittelbare ordinale Nachfolger; kein Gate
springt auf eine niedrigere Ordinalzahl zurück, keine Anzeige-/Evidenzstufe steht vor ihrer
numerischen Position. **Qxx ist die einzige operatorseitige Bezeichnung.**

Kompatibilitätsbezeichnungen (Legacy-`P*`-Storage-Keys, alte Qxx-IDs in historischen DB-Zeilen)
sind ausschließlich technische Leseadapter und dürfen nicht in Dashboards, Reports oder
Betriebsdokumenten erscheinen. Historische Zeilen behalten ihre Bedeutung über
`gate_contract_version`; alte IDs werden nie stillschweigend mit neuer Semantik gelesen.

---

## Makrophase 1 — Strategie beweist sich (Q00 … Q08)

Build, Baseline, DEV-Stabilität/Kalibrierung, OOS, Full-History-/Stress-/Statistikdossier →
eine target-neutrale, eingefrorene Baseline. IDs und Kriterien **unverändert** gegenüber v3.

| Gate | Name | Owner | Hard PASS criterion |
|---|---|---|---|
| Q00 | Research Intake | OWNER | R1 source + R2 mechanical + R3 data available + R4 no-ML (see [[Q00 Research Intake]]) |
| Q01 | Build & Spec | Codex | `.ex5` compiles · smoke ≥1 trade · spec doc (strategy logic + params + universe + expected behaviour) |
| Q02 | Baseline Screening | Pipeline-Op | **PF > 1.10 (OWNER 2026-07-25, vorher 1.20) ∧ Trades ≥ rate-Floor ∧ DD < 25% (OWNER 2026-07-15, vorher 15%)** per symbol — only PASS symbols advance. Trade-Floor seit 2026-06-26 rate-basiert: max(5 Trades/Jahr × Fensterjahre, absolute Untergrenze in `p2_baseline.py`) — implementiert zugleich den Economics-Frequenz-Floor ≥5/Jahr (Operating Rules 2026-07-03; darunter RETIRE). Per-symbol window: max(2017-01-01, symbol_first_data) → 2022-12-31, min 3yr IS |
| Q03 | Parameter Sweep | Pipeline-Op | ≥50% of grid configs profitable + plateau width ≥ 3 contiguous — use plateau-median params (not best) |
| Q04 | Walk-Forward + Commission | Pipeline-Op | 3 anchored folds (OOS 2023, 2024, 2025) all PF > 1.0 with **$7/lot ECN commission applied** |
| Q05 | Gross Full-History Robustness | Pipeline-Op | Full history 2017→present on Q03 plateau-median params, GROSS (no cost stress — re-ratified 2026-07-05, see Q05 page) → PF > 1.0, DD < 25% (OWNER 2026-07-15), ≥20 trades. DD-Bruch bei PF>1.0 = `FAIL_DD_PORTFOLIO_REVIEW` (Park, DL-082 §4) |
| Q06 | Stress HARSH | Pipeline-Op | **Einzige implementierte Stress-Dimension: geseedete 10%-Trade-Rejection** (re-ratifiziert 2026-07-06; Kostenmultiplikatoren waren nie implementiert) → PF > 1.0, DD < 25%, ≥20 trades |
| Q07 | Multi-Seed | Pipeline-Op | 5 seeds (42, 17, 99, 7, 2026) · PF variance < 20% (2. Achse: [20%,40%) wenn worst-seed PF ≥ 1.10) · no seed PF < 1.0 |
| Q08 | Davey Statistical Validation | Pipeline-Op | All 11 sub-gates (8.11 MC-Shuffle-DD ergänzt; see [[Q08 Davey Statistical Validation]]) → eingefrorene, target-neutrale Baseline |

---

## Makrophase 2 — Strategie wird optimiert / requalifiziert (Q09 … Q14)

Pre-News-Gesamtlauf → News + FTMO-Empfehlung → Incumbent-Confirmation → Pattern-Filter →
Parameter-Optimierung/Freeze → versiegelter Vorher-/Nachher-Head-to-Head. Terminiert in einem
Requalifikationsverdikt; `KEEP_INCUMBENT` (keine Verbesserung) ist gültig.

| Gate | Name | Owner | Hard PASS criterion |
|---|---|---|---|
| Q09 | Baseline Full Run | Pipeline-Op | Pre-news Full-History-Baseline je (EA,Symbol). Regel: hash-gebundene Q08-Baseline reusen, sonst Baseline-Lauf (fail-closed, nie aus Verdikt inferiert). Fixiert die Referenz für den Q14-Vergleich |
| Q10 | News Impact + FTMO Recommendation | Pipeline-Op (automated); Claude (adjudication-review) + OWNER (live-consumption approval) | Versiegelte A/B-Empfehlung auf **zwei Achsen** (temporal `QM_NewsTemporalMode` 0–6 + Compliance NONE/DXZ/FTMO) → Verdikt `CONFIG_LOCKED` / `REVIEW_REQUIRED` / `INVALID_EVIDENCE`. Portfolio-Arm (`Q10_PORTFOLIO`) informational (OWNER E1). Default-Apply Mode 3 RETIRED 2026-08-04; kein algorithmisches Best-PF-Picking |
| Q11 | Incumbent Full-History Confirmation | Pipeline-Op | Full available history per symbol with locked news config → **PF > 1.0 ∧ DD < 25%**. Dependency-Gate: News `CONFIG_LOCKED` Pflicht. Per-(EA,Symbol) Confirmation des Incumbent |
| Q12 | Pattern Filter Selection | Pipeline | Verpflichtender linearer Schritt. Vorregistrierte DL-089-Auswahl, **Cap 3 Filter je Richtung**; **null Filter = gültiges Pass-Through**. `OPT_ELIGIBLE` / `OPT_REJECTED` |
| Q13 | Parameter Optimization & Freeze | Development | neue EA-Identität · DEV/IS-only Auswahl · Plateau statt Bestwert · Default-OFF-Äquivalenz · Parameterfreeze · Challenger durchläuft Q02→Q11 |
| Q14 | Best-Settings Head-to-Head + Holdout | Pipeline | **Terminales Phase-2-Gate (`next = null`).** Versiegelter OOS-Vergleich vs. **Q09-Baseline UND Incumbent-Q11** inkl. No-Change-Kontrolle, Holdout und Portfolio-Marginalbeitrag → `CHALLENGER_PROMOTED` / `KEEP_INCUMBENT` |

---

## Makrophase 3 — Strategie wird zum Buch bewertet (Q15 … Q17)

Portfolio-Konstruktion → Operational Readiness → Live Burn-In. **Eintritt nur über den
fail-closed Buch-Trigger** (§ Buch-Trigger unten), nie über eine per-EA-`next`-Kante.

| Gate | Name | Owner | Hard PASS criterion |
|---|---|---|---|
| Q15 | Final Portfolio Construction | OWNER | Family-cap 3 per edge type · symbol-cap 2 per instrument · pairwise \|r\| < 0.5 · target 10-15 EAs. **Eintritt nur via Buch-Trigger.** Dual-book DXZ/FTMO (Storage `Q15_DXZ`/`Q15_FTMO`) |
| Q16 | Operational Readiness | OWNER | Compile proof · setfile audit · symbol suffix check · binary timestamp matches source · **DXZ Live routing OK** · 11-Punkte-Checkliste |
| Q17 | Live Burn-In on DXZ Live | OWNER | 14 days on **DarwinexZero Live account** (T_Live terminal) · min-lot · Myfxbook monitoring · KS-test kill-switch. T_Live AutoTrading toggle = **OWNER only** (HR). Pipeline-Ende |

---

## Linearer Pfad (ASCII)

```
Makrophase 1 — Strategie beweist sich
Q00 Research Intake            ← OWNER
Q01 Build & Spec               ← Codex
Q02 Baseline Screening         ← Pipeline-Op   (IS 2017-01 → 2022-12)
Q03 Parameter Sweep            ← Pipeline-Op   (IS 2017-2022)
Q04 Walk-Forward + Commission  ← Pipeline-Op   (OOS 2023/2024/2025)
Q05 Gross Full-History Robust. ← Pipeline-Op   (Full history)
Q06 Stress HARSH               ← Pipeline-Op   (Full history)
Q07 Multi-Seed                 ← Pipeline-Op   (Full history)
Q08 Davey Statistical Valid.   ← Pipeline-Op   (Full history, 11 sub-gates)

Makrophase 2 — Strategie wird optimiert / requalifiziert
Q09 Baseline Full Run          ← Pipeline-Op   (pre-news Full-History-Baseline)
Q10 News Impact + FTMO Rec.    ← Pipeline-Op   (Claude adjudication + OWNER live approval)
Q11 Incumbent Full-Hist Conf.  ← Pipeline-Op   ← per-(EA,Symbol) Confirmation
Q12 Pattern Filter Selection   ← Pipeline      (DL-089, Cap 3/Richtung, 0 Filter = Pass-Through)
Q13 Parameter Optimization&Frz ← Development   (Challenger Q02→Q11)
Q14 Best-Settings Head-to-Head ← Pipeline      ← TERMINAL (next=null), KEEP_INCUMBENT gültig

── Buch-Trigger (fail-closed): ≥25 qualifizierte Kandidaten UND OWNER-Buchauftrag ──

Makrophase 3 — Strategie wird zum Buch bewertet
Q15 Final Portfolio Constr.    ← OWNER         (dual-book DXZ/FTMO)
Q16 Operational Readiness      ← OWNER
Q17 Live Burn-In on DXZ Live   ← OWNER         ← T_Live terminal, 14 days
→   Full Live                  ← OWNER approval after burn-in
```

---

## Mapping-Tabelle v3 → v4

`gate_contract_version` trägt den Diskriminator: eine historische Zeile behält ihre v3-Bedeutung;
eine v4-Zeile ist ein v4-Gate. Die Äquivalenzspalte ist die *explizite* Übersetzung für Anzeige
und Evidenz-Wiederverwendung — nie eine stille Neuinterpretation.

| v3 ID | v3 Rolle | → v4 ID | Makrophase | Reuse-Regel |
|---|---|---|---|---|
| Q00–Q08 | Research…Davey | Q00–Q08 | 1 | REUSE, ID unverändert (hash-gebunden ab Q02) |
| Q10A | Baseline Full Run (Evidenzrolle) | **Q09** | 2 | RENUMBER + PROMOTE zu echtem Gate; reuse nur hash-gebundene Q08-Baseline |
| Q09 (`Q09_NEWS`/`Q09_PORTFOLIO`) | News Impact + FTMO Rec. | **Q10** (`Q10_NEWS`/`Q10_PORTFOLIO`) | 2 | RENUMBER; Portfolio-Arm informational |
| Q10 | Incumbent Full-History Confirmation | **Q11** | 2 | RENUMBER |
| Q14 | Pattern Filter Selection (DL-089) | **Q12** | 2 | RENUMBER; jetzt verpflichtend linear, 0 Filter = Pass-Through |
| Q15 | Parameter Optimization & Freeze | **Q13** | 2 | RENUMBER |
| Q16 | Best-Settings Head-to-Head | **Q14** | 2 | RENUMBER; terminal `next=null`, entfernt Rücksprung Q16→Q11 |
| Q11 (`Q11_DXZ`/`Q11_FTMO`) | Final Portfolio Construction | **Q15** (`Q15_DXZ`/`Q15_FTMO`) | 3 | RENUMBER; Eintritt nur via Buch-Trigger |
| Q12 | Operational Readiness | **Q16** | 3 | RENUMBER |
| Q13 | Live Burn-In DXZ | **Q17** | 3 | RENUMBER; `next=null` |

Legacy-`P*`-Storage-Keys werden beim UNION-Lesen mitgeführt (Migration-only) und erscheinen nie
auf Operator-Flächen. Details: [[Gate Manifest v4 Diff]].

---

## Buch-Trigger (Phase-3-Eintritt, fail-closed — OWNER-Direktive 2026-08-23)

Q15 ist ausschließlich über einen expliziten Guard erreichbar — nie über eine per-EA-Kante
(`Q14.next = null`). Der Guard verweigert (raises), er überspringt nicht still:

```
BOOK BUILD PERMITTED  ⇔  (qualified_candidates >= 25)  AND  (owner_order_artifact vorhanden & verifiziert)
```

- **qualified_candidates:** Paare mit `highest_contiguous_valid_gate == Q14` und terminalem
  Requalifikationsverdikt (`CHALLENGER_PROMOTED`/`KEEP_INCUMBENT`). Kanonische Einheit
  `(EA, Symbol)`; zusätzlich distinct EAs und Strategie-Familien ausweisen.
- **owner_order_artifact:** signiertes `decisions/YYYY-MM-DD_owner_book_order_<venue>.md`,
  `venue ∈ {dxz, ftmo}`.
- Der frühere Q11-Auto-Trigger bei 5 Q10-Paaren ist aufgehoben. Unter 25 nur messen/vervollständigen.

---

## Fail-Soft- und Park-Pfade (vollständige Liste)

Die Pipeline ist grundsätzlich hard-kill. Es existieren genau **vier** dokumentierte
Nicht-Hard-Kill-Pfade — alles andere ist FAIL:

| Pfad | Gate | Bedingung → Wirkung |
|---|---|---|
| **Q05-Salvage-Lane** (OWNER 2026-07-05) | Q05 | `dd_above_ceiling` bei gross PF > 1.0 → direkt-zu-Q08 auf Probation-Gewichten |
| **`FAIL_DD_PORTFOLIO_REVIEW`** (DL-082 §4) | Q05 | DD-Bruch bei PF > 1.0 → geparkt für Portfolio-Marginalbewertung, kein Auto-RETIRE |
| **`EDGE_SOFT`** (DL-072) | Q08 | Cost-Cushion 1–2× worst-case Commission → weiter zu Q09/Q10 als Soft-Edge |
| **Q06 `PASS_SOFT` / `probation:q06_soft`** (OWNER Option A 2026-08-21, Commit `47f751d1d`) | Q06 | Gross-profitabler EA (Q05-PASS Vorbedingung), dessen PF unter der geseedeten 10%-Trade-Rejection nur marginal in das Band `PF ∈ [0.95, 1.0)` rutscht, während DD ≤ Ceiling und Trades ≥ Floor hart bestehen → advance zu Q07 als `PASS_SOFT` mit persistentem `probation:q06_soft`-Marker |

Der PASS_SOFT-Pfad ist auf **Q06** live (OWNER Option A 2026-08-21,
`framework/scripts/q06_stress_harsh.py:44-51,218-220`; Band bei 40,3 % gemessen,
`docs/ops/evidence/2026-08-21_q06_fail_soft_band_sizing.md`). Eine analoge
PASS_SOFT-Weiterleitung für **Q05** ist damit noch nicht aktiviert (ROT, OWNER).

---

## Data Window Reference

| Gate (v4) | Window | Purpose |
|---|---|---|
| Q02, Q03 | **2017-01-01 → 2022-12-31 (IS only)** | Development and parameter discovery — OOS data NEVER touched here |
| Q04 | Anchored, **OOS 2023, 2024, 2025** (3 × 12mo folds) | First OOS exposure; new fold for OOS 2026 auto-adds in Jan 2027 |
| Q05, Q06, Q07, Q08 | Full history 2017 → present | Stress, seed-robustness, statistical validation across all regimes |
| Q09 | Full history, pre-news | Baseline Full Run (Referenz für Q14) |
| Q10 | Full history, Zwei-Achsen-Zellen (temporal 0–6 × Compliance) | Versiegelte News-Config-Adjudikation → `CONFIG_LOCKED` |
| Q11 | **Full available history per symbol** with chosen news mode | Incumbent Confirmation — per-(EA, symbol) |
| Q12 | Keine neue Auswahl auf OOS | DL-089-Pattern-Filter-Auswahl |
| Q13 | DEV/IS endet vor dem ersten versiegelten Vergleichsfenster | Challenger bauen, DEV-only auswählen, Parameter einfrieren |
| Q14 | Vorregistrierte gemeinsame OOS-Fenster + Holdout | versiegelter Head-to-Head vs. Q09-Baseline und Incumbent-Q11 |
| Q17 | Live, 14 days from deployment date | Real DXZ Live execution |

---

## Pipeline Rules (Hard)

| Rule | Detail |
|---|---|
| **Qxx-only operator surfaces** | Dashboards, Reports, EA-Detailseiten und Cockpit zeigen ausschließlich Q-Gates. Technische Kompatibilitätswerte werden vor der Anzeige normalisiert. |
| **OOS embargo (Q04→Q17)** | OOS data (anything after 2022-12-31) must NEVER be analysed during Q02/Q03. Embargo violation = Q04 Hard Fail. |
| **Per-symbol promotion** | An EA does not pass or fail as a whole — each (EA, symbol) pair has its own verdict at every gate. Symbols that FAIL at Q02 do not enter Q03 for that EA. |
| **Q02 → Q14: pipeline-op automated** | Codex/orchestration runs these gates autonomously per parallel-within-source rule. No OWNER intervention required to flow through. |
| **Q15 → Q17: OWNER only** | Portfolio composition, operational readiness, live toggle. Keine AI (Codex/Claude/Antigravity) kann in Q15 oder darüber hinaus promoten. |
| **Q14 ist terminal; Phase 3 nur über Buch-Trigger** | Kein per-EA-`next`-Edge in Phase 3. Der Rücksprung Q16→Q11 aus v3 ist entfernt. Buch-Eintritt = ≥25 Kandidaten + OWNER-Auftrag. |
| **T_Live AutoTrading = OWNER only (HR)** | Only OWNER may flip AutoTrading on the T_Live terminal — no AI seat, Claude included. Claude verifies pre-flight. Q17 deployment requires explicit OWNER approval and recorded decision under `decisions/`. |
| **No fallbacks** | The pipeline never falls back to "earlier attempt's data" to mask a failed gate. If a run failed, the row is FAIL — no synthetic recovery. |
| **No demo gate** | Q16 → Q17 = direct to DXZ Live min-lot. Demo trading is not a meaningful filter for execution-sensitive EAs. |
| **Parallel within source, sequential across sources (HR16)** | All EAs from one approved card-batch race through Q01→Q17 in parallel. Next source unlocks only after the previous source's last EA exits (PASS or terminal FAIL). |
| **Filesystem is truth** | If `state.json` or DB disagrees with what's actually on disk, disk wins. Always verify report files exist before classifying. |

---

## Davey Statistical Validation (Q08) — 11 sub-gates

All sub-gates must PASS for Q08 to advance. Detail in [[Q08 Davey Statistical Validation]].

| Sub | Name | Hard criterion |
|---|---|---|
| 8.1 | Correlation vs existing portfolio | Pairwise \|r\| < 0.50 against current Q15+ survivors |
| 8.2 | Deflated Sharpe + MC + FDR | DSR p < 0.05 (Tier 1) OR Benjamini-Hochberg FDR pass (Tier 2) |
| 8.3 | Tail Dependence | Correlation under top/bottom 5% market moves ≤ baseline |
| 8.4 | Seasonal | All 12 calendar months net profit > 0 |
| 8.5 | Neighborhood Stability | ±10% parameter perturbation: PF > 1.0, DD < 1.5× baseline |
| 8.6 | **Chopping Block (Davey)** | Remove top 5% most-profitable trades → PF > 1.0 |
| 8.7 | PBO (CSCV) | PBO < 0.40 |
| 8.8 | Edge Decay | Rolling 12m PF decline < 40% over full history |
| 8.9 | Runs Test (Wald-Wolfowitz) | p > 0.05 on win/loss sequence · top-20% months ≤ 70% of total profit |
| 8.10 | Regime + Crisis | Profitable in low/normal/high ATR regimes. Crisis slices (COVID-2020, SNB-2015, Ukraine-2022) **informational only — never block** |
| 8.11 | MC-Shuffle Drawdown | Monte-Carlo-Trade-Shuffle-DD innerhalb Toleranz (EDGE_SOFT-fähig, Non-Merit-Allowance mit 8.4/8.6/8.10) |

---

## Phase Detail Pages

**Makrophase 1 — Strategie beweist sich**
- [[Q00 Research Intake]]
- [[Q01 Build & Spec]]
- [[Q02 Baseline Screening]]
- [[Q03 Parameter Sweep]]
- [[Q04 Walk-Forward + Commission]]
- [[Q05 Gross Full-History Robustness]]
- [[Q06 Stress HARSH]]
- [[Q07 Multi-Seed]]
- [[Q08 Davey Statistical Validation]]

**Makrophase 2 — Strategie wird optimiert / requalifiziert**
- [[Q09 Baseline Full Run]]
- [[Q10 News Impact + FTMO Recommendation]]
- [[Q11 Incumbent Full-History Confirmation]]
- [[Q12 Pattern Filter Selection]]
- [[Q13 Parameter Optimization & Freeze]]
- [[Q14 Best-Settings Head-to-Head]]

**Makrophase 3 — Strategie wird zum Buch bewertet**
- [[Q15 Final Portfolio Construction]]
- [[Q16 Operational Readiness]]
- [[Q17 Live Burn-In DXZ]]
