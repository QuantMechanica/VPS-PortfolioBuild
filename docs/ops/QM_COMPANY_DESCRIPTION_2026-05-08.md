# QuantMechanica V5 — Gesamtbeschreibung der Paperclip Company

**Stand:** 2026-05-08  
**Erstellt durch:** Board Advisor (synthetisiert aus Notion, lokalen Docs, VPS-Live-State)  
**Zweck:** Review-Dokument für OWNER — vollständige Beschreibung der Firma, Struktur, Prozesse und aktueller Stand

---

## 1. Identität & Mission

**QuantMechanica V5** ist eine AI-betriebene Strategie-Mining-Factory für algorithmischen Forex/CFD-Handel auf Darwinex. Sie ist keine klassische Handelsfirma — sie ist eine fiktive AI-Company, die als YouTube-Build-in-Public-Projekt öffentlich dokumentiert wird.

**Gründer & Final Authority:** Fabian Grabner (OWNER)  
**Board Member:** Claude-Assistant (Opus 4.7 1M)  
**Betrieb:** Vollständig durch Paperclip-Agenten (kein manueller Handel)

### Mission (aus Project Charter)

> Rebuild the QuantMechanica strategy-mining factory on clean infrastructure, operated by a revised Paperclip multi-agent company, fully documented on YouTube as the Build-in-Public series. End-goal: a profitable, publicly-tracked live portfolio of mechanical trading strategies by month 12.

### Warum V5 (Neustart)?

V1–V4 auf dem lokalen PC haben über 6 Monate technische Schulden angehäuft: Drive-Stream-Bugs, Paperclip-Abstürze, Mass-Delete-Incidents, veraltete State-Files. V5 startet sauber:

- Neuer dedizierter VPS (Hetzner AX42)
- Neues Paperclip-Unternehmen (kein Import alter QUAA-Issues)
- Neues DarwinexZero-Konto (frische Track Record)
- Neues GitHub-Repo
- Überarbeitete Agenten-Prompts mit explizit eingebetteten V1-Learnings

**V5 behält:** Die Learnings (10 harte Regeln aus V1–V4)  
**V5 wirft weg:** Den Ballast (alle V4 SM_XXX Sleeves, alten State, stale Konfigurationen)

---

## 2. Geschäftsmodell & Monetarisierung

| Einnahmekanal | Beschreibung | Zeithorizont |
|---------------|--------------|--------------|
| **DXZ Algo Fund** | Performance Fees aus dem DarwinexZero Fund (Hauptziel) | Monat 6–12 |
| **YouTube / Build-in-Public** | Kanal-Wachstum, Buy-me-a-coffee, Episode-Packs | Laufend |
| **Newsletter** | Buttondown, Ziel ≥1000 Subscriber | Monat 3–6 |
| **Kostentransparenz** | 100% der Kosten öffentlich im Expense Log | Laufend |

### 12-Monats-Erfolgskriterien

| Dimension | Ziel | Messung |
|-----------|------|---------|
| Live Portfolio | ≥5 live EAs, PF ≥1.3, Max DD ≤15% | Myfxbook / DarwinexZero |
| Research | ≥10 Quellen, ≥100 EA-Kandidaten getestet | Pipeline DB + Git |
| YouTube | ≥20 Episoden publiziert | youtube.com/@quantmechanica |
| Community | ≥1000 Newsletter-Sub, ≥500 YT-Sub | Buttondown + YT Analytics |
| Transparenz | 100% Kosten geloggt | Expense Log |
| Board-Cadence | Wöchentlich Board Review, monatlich Phase Gate | Meeting Notes |

---

## 3. Infrastruktur

### VPS-Layout

| Komponente | Pfad | Zweck |
|------------|------|-------|
| Repo | `C:\QM\repo` | Git-Wahrheit, alle Docs, Framework, Skills |
| Paperclip | `C:\QM\paperclip` | Agenten-System, Kanban, Dashboards |
| Live Terminal | `C:\QM\mt5\T_Live` | **OFF LIMITS** — nur für live Trading |
| Factory Terminals | `D:\QM\mt5\T1` … `T5` | Backtests und Sweeps |
| Reports | `D:\QM\reports\pipeline\` | Pipeline-Evidenz pro EA |
| Data | `D:\QM\data` | Tick-Daten, News-Calendar |

### Broker & Daten

- **Broker:** Darwinex / DarwinexZero MT5
- **Serverzeit:** New York Close Konvention — GMT+2 außerhalb US-DST, GMT+3 während US-DST
- **Daten:** Ausschließlich Darwinex CFD-Feed (kein Bloomberg, keine externen APIs)
- **Symbole:** `.DWX`-Suffix auf Custom Symbols — `bases/`-Ordner NIEMALS löschen
- **Tick-Daten:** Via Tick Data Suite (lokale Cache als Fallback)
- **39 kanonische Symbole** (ohne `NDXm.DWX`, `GDAXIm.DWX` — leere Relikte)

### MT5-Terminal-Architektur

```
T1 (D:\QM\mt5\T1)  ─┐
T2 (D:\QM\mt5\T2)  ─┤
T3 (D:\QM\mt5\T3)  ─┼── Factory (Backtests, P1-P8) — Agenten dürfen schreiben
T4 (D:\QM\mt5\T4)  ─┤
T5 (D:\QM\mt5\T5)  ─┘
T6 (C:\QM\mt5\T_Live) ── Live/Demo — OWNER-only, AutoTrading nur nach Manifest
```

---

## 4. Org-Struktur der Paperclip Company

### Hierarchie

```
OWNER (Fabian Grabner) — Final Authority
Board Advisor (Claude Code) — Board Member, VPS Assistant
            │
      Paperclip CEO
      /    |    |    \    \
  CTO  Research  DevOps  Pipeline-Op  Documentation-KM
   |       |
  Dev   Quality-Tech
           |
     Quality-Business
```

### Aktive Agenten (Stand 2026-05-08)

| Wave | Rolle | Status | Adapter | Agent-ID |
|------|-------|--------|---------|----------|
| 0 | CEO | **Live (idle)** | claude_local | `7795b4b0-...` |
| 0 | CTO | **Live (running)** | codex_local | `241ccf3c-...` |
| 0 | Research | **Live (idle)** | claude_local | `7aef7a17-...` |
| 0 | Documentation-KM | **Live (idle)** | claude_local | `8c85f83f-...` |
| 1 | DevOps | **Live (running)** | codex_local | `86015301-...` |
| 1 | Pipeline-Operator | **Live (running)** | codex_local | `46fc11e5-...` |
| 1+ | Development | **Live (idle)** | codex_local | `ebefc3a6-...` |
| 1+ | Quality-Tech | **Live (idle)** | claude_local | `c1f90ba8-...` |
| 1+ | Quality-Business | **Live (idle)** | claude_local | `0ab3d743-...` |
| def | Chief-of-Staff | Idle/deferred | claude_local | `38f933cd-...` |

### Wave-Plan (Hire-Trigger)

| Wave | Rollen | Trigger |
|------|--------|---------|
| **Wave 0** | CEO, CTO, Research, Doc-KM | Bereits live |
| **Wave 1** | DevOps, Pipeline-Operator | Bereits live |
| **Wave 2** | Quality-Tech → Development → Quality-Business | Framework Step 25 PASS + ≥1 APPROVED Card |
| **Wave 3** | Controlling, Observability-SRE | ≥3 EAs in P10 ODER Live-Trading begonnen |
| **Wave 4** | LiveOps | T6 Runbook operational + DXZ funded |
| **Wave 5** | R-and-D | Pipeline produziert ≥10 PASS EAs/Monat |
| **Wave 6** | Chief-of-Staff | **Indefinitely deferred** |

### Rollen im Detail

**CEO** — Strategische Führung, Gate-Entscheidungen (PASS/FAIL), Hire-Genehmigung (autonomous per DL-017/023), Research-Queue-Freigabe, Eskalation zu OWNER. Heartbeat: 30min.

**CTO** — MQL5-Review, Framework-Architektur, EA-vs-Card-Review, Pipeline-Spec-Autorenschaft, DL-054-Gates-Wiring. Adapter: Codex. Heartbeat: 60min.

**Research** — Depth-first Source Mining, Strategy Card Extraction, G0-Vorbereitung. Eine Quelle vollständig, dann nächste. Adapter: Claude. Event-driven (keine feste Cadence).

**Documentation-KM** — Notion↔Git-Sync, Lessons-Learned, Skills-Library-Pflege, Episode-Artefakte, Public/Private-Grenze. Heartbeat: 2h.

**DevOps** — VPS-Infra, Cron-Jobs, Public-Snapshot-Export, Drive-Sync-Hygiene, Dashboard-Rendering. Adapter: Codex. On-demand.

**Pipeline-Operator** — MT5-Factory-Prozesse (T1-T5), Baseline-Sweeps, Aggregator-Loop, P2-P8-Runner. **Niemals T6.** Adapter: Codex. Heartbeat: 10min.

**Development** — MQL5-EA-Implementierung aus APPROVED Strategy Cards, Build-Scripts, Compile-Verification. Adapter: Codex. On-demand.

**Quality-Tech** — Statistische Reviews, Overfit-Checks, Walk-Forward-Audit, Report-Audit, Code-Review. On-demand.

**Quality-Business** — Portfolio-Fit, Narrative-Verteidigbarkeit, FTMO/DXZ-Compliance, Public-Claim-Review. On-demand.

### Capability-Routing (Claude vs. Codex)

| Aufgabe | Bevorzugtes Modell | Grund |
|---------|-------------------|-------|
| Web-Research, Synthesis, Narrative | Claude Opus 4.7 | Besser für Research + Narrative |
| Code, Repo, MQL5, Automation | Codex (gpt-5.3-codex) | Besser für deterministischen Code |
| Strategy Card Extraction | Claude Opus 4.7 | Lesefähigkeit + Zitations-Disziplin |
| Quality-Tech Review | Codex primär | Code/Stat-Artefakte |
| Quality-Business Review | Claude Opus 4.7 | Portfolio-Reasoning + Kommunikation |
| Dashboard Build+Deploy | Codex (Build) + Claude (Design) | Code plus Brand/Narrative |

---

## 5. Die Pipeline (15 Phasen, V2.1)

**Kanonische Quelle:** `docs/ops/PIPELINE_PHASE_SPEC.md` (Notion-Version ist superseded)

```
G0  Research Intake
P1  Build Validation
P2  Baseline Screening          (IS: 2017-2022 only)
P3  Parameter Sweep
P3.5 Cross-Sectional Robustness  (V2.1 additive)
P4  Walk-Forward                (OOS beginnt hier)
P5  Stress Test                 (Full History beginnt hier)
P5b Calibrated Noise Add-on    (V2.1 additive)
P5c Crisis Event Slices        (optional, report-first)
P6  Multi-Seed
P7  Statistical Validation
P8  News Impact (7 Modi)
P9  Portfolio Construction      (manuell, OWNER)
P9b Operational Readiness       (manuell, OWNER)
P10 Live Burn-In Window         (manuell, OWNER — 14 Tage Minimum-Lot live)
→   Full Live (nach OWNER-Approval, Position-Size Expansion)
```

### Phase-Gating-Tabelle

| Phase | Name | Gate-Kriterium | Entscheider |
|-------|------|----------------|-------------|
| G0 | Research Intake | R1-R4 PASS (QB Reputable Source Criteria) | CEO |
| P1 | Build Validation | `.ex5` compiles, smoke ≥1 Trade, kein Missing File | Pipeline-Op (auto) |
| P2 | Baseline Screening | PF >1.30, Trades >200, DD <12%, Model 4, Fixed Risk | CEO (mit QT) |
| P3 | Parameter Sweep | >50% profitable Configs, Plateau-Check | CEO |
| P3.5 | Cross-Sectional Robustness | Orthogonale Asset-Class Robustheit | Pipeline-Op (auto) |
| P4 | Walk-Forward | Min 6 Folds, DEV→HO Embargo, Regime Labels | Quality-Tech |
| P5 | Stress Test | PF >1.0 nach Stress, Full History | Quality-Tech |
| P5b | Calibrated Noise | ≥70% Proxy Compliance (MC Noise/Latency/Jitter) | Quality-Tech |
| P5c | Crisis Slices | Optional — nur Report, kein Gate | Research |
| P6 | Multi-Seed | 5-Seed Stabilität (Seeds: 42, 17, 99, 7, 2026) | Quality-Tech |
| P7 | Statistical Validation | DSR + MC + FDR, **PBO <5% Hard Gate** | Quality-Tech |
| P8 | News Impact | Mode-Selektion für Deploy-Verhalten | CEO |
| P9 | Portfolio Construction | Family Cap 3, Symbol Cap 2, ENB + Marginal Sharpe | OWNER |
| P9b | Operational Readiness | Compile/Deploy/Risk/News/Commission Checks | OWNER |
| P10 | Live Burn-In | 14 Tage live auf T6/DXZ, Min-Lot, KS-Test Kill-Switch | OWNER |

### Wichtige Pipeline-Regeln

- **IS-Fenster (P2/P3):** 2017–2022 (Development only, OOS bleibt sauber)
- **OOS beginnt bei P4** — niemals davor berühren
- **Smoke ≠ Baseline-Equivalent** — kein Portable-Smoke als BL-Ersatz (SM_261-Lektion: 320x Divergenz)
- **NO_REPORT (Size-0 .htm) ≠ EA-Schwäche** — immer Dateigröße prüfen zuerst
- **SETUP_DATA_MISMATCH / MISSING** sind Setup-Fehler, nie Strategy-FAIL
- **Filesystem ist Wahrheit** — tracker state.json kann lügen
- **Kein Demo-Account zwischen Backtest und Live** — P10 ist die erste Live-Exposition

---

## 6. Research-Methodik (V2 — Depth-First)

**Die wichtigste Prozess-Änderung in V5.** V1 lief breadth-first über 81+ "Edge-Types" mit schwammiger Attribution. V2 ersetzt das durch strikte Tiefensuche.

### Die Regel

> **Eine Quelle vollständig abarbeiten, bevor die nächste beginnt.**

### Workflow

1. **Source Selection** — Research schlägt vor, CEO genehmigt (spezifisch: Buch/Paper/URL/Video)
2. **Exhaustive Extraction** — Alle Strategien aus der Quelle als Strategy Cards erfassen
3. **G0 Review** — CEO bewertet gegen R1-R4 (QB Reputable Source Criteria):
   - R1: Autor hat verifizierbaren Track Record (kein Anonymous, kein Blog-only)
   - R2: Entry/Exit/Stop/Sizing explizit mechanisch beschrieben
   - R3: Alle Daten im Darwinex CFD-Feed verfügbar
   - R4: EA_ML_FORBIDDEN nicht verletzt, 1-Position-per-Magic kompatibel
4. **EA Build** — Development implementiert genehmigte Cards einzeln (sequential)
5. **Source Completion Report** — Nach allen Cards: Report über Quellen-Qualität
6. **Dann erst:** Nächste Quelle

### Anti-Patterns (verboten)

- Strategien ohne Quell-Zitat
- 5 Bücher parallel anreißen
- Strategy Card überspringen → direkt zu Code
- 3 EAs parallel aus einer Quelle
- Source "unknown" oder "various"

---

## 7. EA-Framework

**Kanonische Quelle:** `framework/V5_FRAMEWORK_DESIGN.md`

Jeder EA in V5 ist ein `QM5_<NNNN>_<slug>.mq5` im Framework:

```
framework/
  EAs/
    QM5_<NNNN>_<slug>/
      QM5_<NNNN>_<slug>.mq5     # Quellcode
      QM5_<NNNN>_<slug>.ex5     # Kompilat
      sets/                      # .set-Dateien pro Symbol
  include/
    QM_*.mqh                    # Shared Headers
  registry/
    magic_numbers.csv           # Magic-Number-Kollisionsschutz
  scripts/
    p2_baseline.py              # P2 Runner
    gen_setfile.ps1             # .set-File Generator
    run_smoke.ps1               # P1 Smoke Runner
    dl054_gates.py              # DL-054 Pre-Launch-Gates
```

**Magic-Number-Schema:** `ea_id * 10000 + symbol_slot` — Kollision = Hard Abort

**Modulare Architektur:**
- No Trade (Filter-Layer)
- Trade Entry
- Trade Management
- Trade Close
- News Filter (P8)

**Verboten:** Machine Learning, Sub-Minute-Execution, Griding ohne strict worst-case Fallback

---

## 8. Operating System der Company

### Core Management System

| Prozess | Owner | Cadence | Output |
|---------|-------|---------|--------|
| Project Management | CEO | täglich/event-driven | Priorisiertes Issue Board, Milestone-Status |
| Milestones | CEO + CTO | wöchentlich | Milestone Review, Next-Gate-Decision |
| Process Roadmap | Doc-KM | stündlich public / wöchentlich review | Public Process Roadmap + Internal Registry |
| Checklists | Process Owner | jede Ausführung | Signed Checklist mit Evidence Links |
| Reviews | Quality-Tech + Quality-Business | per Gate | PASS / FAIL / NEEDS_WORK |
| Lessons Learned | Doc-KM | nach Incident/Gate/Video | Kept/Changed/Discarded Entry |
| Risk Register | CEO + Controlling | wöchentlich / event-driven | Risk State + Mitigation Owner |
| Public Reporting | Controlling + Doc-KM | stündlich/täglich | Website Snapshot, Episode Artefakte |

### Milestone-Modell

| Milestone | Beschreibung | Exit-Evidenz |
|-----------|--------------|--------------|
| M0 | Foundation: VPS, Repo, Docs, erste Agenten, T1-T6 | Setup-Screenshots, Repo-Skeleton, Prompt-Export |
| M1 | Operating System: Process Registry, Issue Board, Snapshot-Schema | Process Roadmap Page, erster stündlicher Snapshot |
| M2 | Strategy Factory MVP: erste Quelle → erster EA → erste Baseline | Strategy Card, EA, Baseline-Report |
| M3 | Public Dashboard MVP: echte Daten auf quantmechanica.com | Stündliches JSON, Dashboard Page, Stale-Alert |
| M4 | Demo Portfolio MVP: erster approved EA auf T6 Demo | Manifest, Screenshot-Proof, 7-Tage-Health |
| M5 | DarwinexZero Live-Test MVP: erste echte kleine Allokation | OWNER-Approval, Risk Cap, Live Monitoring |
| M6 | Portfolio Expansion: EAs/Symbole schrittweise hinzufügen | Jede Addition mit Manifest + Review |

### Gate-Regel

> Keine Strategie, kein EA, kein Deploy, keine öffentliche KPI und keine Live-Portfolio-Aktion wird akzeptiert, weil ein Agent sagt, sie ist fertig. Sie wird akzeptiert, wenn die Process-Checkliste vollständig ist und die erforderliche Evidenz existiert.

### Kanban & Task-System

- **Kanban CSV:** `C:\QM\paperclip\kanban\company_kanban.csv` (Master-Wahrheit)
- **Task-Abholung:** `python C:/QM/paperclip/tools/ops/next_task.py --agent <role> --json`
- **Abschluss:** `python C:/QM/paperclip/tools/ops/mark_done.py --task <QM-NNNNN> --agent <role> --evidence "<pfad>"`
- **Paperclip API:** `http://127.0.0.1:3100/api` (loopback, kein Auth nötig)

---

## 9. Skills Library (13 QM Skills)

Alle Skills liegen in `C:\QM\repo\skills\qm\` und sind in Paperclip importiert und allen Agenten zugewiesen.

| Skill | Pipeline-Gate | Owner-Rolle |
|-------|--------------|-------------|
| `qm-g0-review` | G0 Strategy Card Verdict | CEO |
| `qm-strategy-card-extraction` | G0 Research Intake | Research |
| `qm-build-ea-from-card` | P1 EA Build | Development / CTO |
| `qm-new-setfiles` | P1 Set-File Generation | Pipeline-Operator |
| `qm-p2-baseline` | P2 Baseline Sweep | Pipeline-Operator |
| `qm-p3-sweep` | P3 Parameter Sweep | Research + Pipeline-Op |
| `qm-run-pipeline-phase` | P3.5, P5, P5b, P5c, P6, P7, P8 | Pipeline-Operator |
| `qm-p4-montecarlo` | P4 Monte Carlo Validation | Research + CTO |
| `qm-t6-deploy-verification` | P9b / P10 Deployment | LiveOps / DevOps (interim) |
| `qm-zero-trades-recovery` | Zero-Trades Diagnose | Pipeline-Operator |
| `qm-validate-custom-symbol` | Custom Symbol Validation | DevOps |
| `qm-pipeline-status` | Pipeline-Status Überblick | CEO / DevOps |
| `qm-render-dashboard` | Dashboard Regenerierung | DevOps |

---

## 10. Entscheidungsrechte

| Entscheidung | Final Authority | Board Input | Veto |
|-------------|-----------------|-------------|------|
| Live Deploy (echtes Geld) | **OWNER** | Board Advisor, CEO | OWNER |
| Infrastruktur-Spend >€200 | **OWNER** | Board | OWNER |
| Agent Hire/Fire | CEO (per DL-017) | Board | OWNER |
| Strategy PASS/FAIL | CEO | Quality-Tech | OWNER |
| Sweep/Research Dispatch | CEO (per DL-023) | — | OWNER |
| YouTube Episode Publish | **OWNER** | Board | OWNER |
| Website-Änderungen | **OWNER** | Board | OWNER |
| T6 AutoTrading ON | **OWNER only** | Board Advisor | OWNER |

### CEO Autonomie-Grenzen (DL-017 + DL-023)

CEO handelt autonom bei:
1. Hires (alle Rollen aus dem Katalog, ohne per-hire OWNER-Ratifizierung)
2. Technische Implementierungs-Choices im Framework (Adapter, Library-Struktur, Scripts)
3. Operative Entscheidungen für non-T6-Deploys (Dateipfade, Scheduler, Log-Rotation)
4. Interne Prozess-Choices (Heartbeat-Cadence, Issue-Tree-Shape, Sub-Issue-Spawning)

CEO muss OWNER eskalieren bei:
- T6-Änderungen (auch read-only über Inspektion hinaus)
- Öffentlichen Claims / KPIs / Portfolio-Entscheidungen
- Architektur-Änderungen mit Impact auf Live-Trading
- Spend >€200

---

## 11. Harte Regeln (Non-Negotiables aus V1–V4)

1. **Filesystem ist Wahrheit** — tracker state.json kann veraltet oder falsch sein
2. **T6 bleibt isoliert** — T1-T5 sind Factory, T6 ist Live — niemals vermischen
3. **Model 4 (Every Real Tick)** auf allen Backtests — kein Model 1/2
4. **Fixed Risk $1K** für BL-Baseline, Percent Risk für Live
5. **Magic-Number-Schema** — Kollision = Hard Abort
6. **NO Magic-Delete** — `bases/`-Ordner niemals löschen
7. **NO_REPORT ≠ EA-Schwäche** — Dateigröße prüfen zuerst
8. **SETUP_DATA_MISMATCH/MISSING** — kein Strategy-FAIL, sondern Setup-Problem
9. **Enhancement Doctrine** — Exit-only Änderungen OK, Entry-Filter-Änderungen killen Trades
10. **Smoke ≠ BL-Equivalent** — kein Portable-Smoke als Baseline-Ersatz
11. **Filesystem-Bestätigung vor jedem EA/Sleeve-Approval** (DL-054)
12. **Kein AutoTrading ohne OWNER-signiertes Manifest**
13. **DST/Timezone-Fehler sind SETUP_DATA_MISMATCH**, keine Strategy-Failures
14. **ML ist verboten** (EA_ML_FORBIDDEN) — nur mechanische Regeln
15. **CEO nutzt 2-Phase-Close** — claim done → verify → archive (kein Single-Step-Close)

---

## 12. Aktueller Stand der Pipeline (2026-05-08)

### EAs im System

| EA | Phase | Status | PASS Symbole |
|----|-------|--------|--------------|
| QM5_1003 davey-baseline-3bar | P3 | Sweep läuft (AUDCHF + EURNZD) | EURUSD, GBPUSD, + weitere |
| QM5_SRC04_S03 lien-fade-double-zeros | P2 | .ex5 existiert, P2-Report vorhanden | Review ausstehend |
| QM5_1017 chan_pairs_stat_arb | P2 | Geblockt (D1-Setfiles fehlen) | — |
| QM5_1004 (US500) | P2 Redeploy | Geblockt (US500.DWX Setfiles fehlen) | — |
| SRC04 S04–S11 (10 Lien-Strategien) | P1 | Todo, Development zugewiesen | — |
| davey-worldcup, davey-eu-day, davey-eu-night | P1 | Bau ausstehend | — |

### Strategy Archive (28 Karten)

28 Strategy Cards sind in `public-data/strategy-archive.json` — davon:
- **G0 APPROVED:** davey-baseline-3bar, lien-fade-double-zeros, chan-pairs-stat-arb, + weitere
- **G0 PENDING/REJECTED:** Verschiedene SRC-Karten in Review

### Paperclip-Issue-Stand (nach Heute-Unblocking)

| Status | Anzahl |
|--------|--------|
| Done | 125 |
| In Progress | 16 |
| Todo | 31 |
| Blocked | **0** (von 29 auf 0 heute bereinigt) |
| Cancelled | 24 |

---

## 13. Dashboard & Public Reporting

### Lokale Dashboards (nicht in Git)

| Datei | Inhalt |
|-------|--------|
| `C:\QM\paperclip\dashboards\current.html` | Ops-Dashboard: Kanban, EA-Pipeline-Lifecycle, Issue-Summary |
| `C:\QM\paperclip\dashboards\strategies.html` | Strategy Archive: alle Strategien, Quellen, SVG-Symbol-Charts |

### Public Data (in Git, für Website)

| Datei | Inhalt |
|-------|--------|
| `public-data/public-snapshot.json` | Ops-Snapshot (stündlich) |
| `public-data/strategy-archive.json` | 28 Strategy Records (öffentlich) |
| `public-data/process-roadmap.json` | Prozess-Status (öffentlich) |

### Website (quantmechanica.com)

Aktuell: Statische Astro-Site. Dashboard-Integration kommt in Monat 3–4.  
Rendering: Lokal via `render_dashboard.py` und `render_strategies.py`.

---

## 14. Governance & Entscheidungslog

### Wichtige Decisions (DL-NNN)

| DL | Inhalt | Datum |
|----|--------|-------|
| DL-017 | CEO Hire-Approval Waiver (autonomous hires) | 2026-04-27 |
| DL-023 | Broadened CEO Autonomy v2 | 2026-04-27 |
| DL-028 | Per-Agent Worktree Isolation Standard | 2026-04-27 |
| DL-029 | Strategy Research Workflow | 2026-04-27 |
| DL-030 | Execution Policies v1 | 2026-04-27 |
| DL-031 | Projects Formalization + Issue Routing | 2026-04-27 |
| DL-034 | CEO Heartbeat 30min (1800s) | 2026-04-28 |
| DL-038 | Seven Binding Backtest Rules | 2026-04-28 |
| DL-054 | Pre-Launch Gates (G1 HCC, G2 Tester Defaults, G5 Symbol) | 2026-05-05 |

### Entscheidungslog-Prinzip

Alle dauerhaften Entscheidungen landen in `decisions/` im Repo als `YYYY-MM-DD_dl0NN_<slug>.md`. Notion ist nur ein Mirror — Git ist kanonisch.

---

## 15. Offene Fragen / Review-Punkte für OWNER

Diese Punkte sind noch nicht final entschieden oder brauchen OWNER-Input:

1. **Research Wake Condition:** Research schläft bis Pipeline auf 1 EA runter ist. Ist das noch korrekt, oder soll Research parallel neue Karten extrahieren?

2. **QM5_1017 setfiles:** CTO muss D1-Setfiles für QM5_1017 generieren. Ist das priorisiert?

3. **SRC04 Build-Reihenfolge:** S04, S05, S06, S07, S08, S09, S11 alle in Todo. Welche Reihenfolge bevorzugt OWNER?

4. **QM5_SRC04_S03 P2-Verdict:** EA hat .ex5 und P2 ran — Board Advisor hat kein abschließendes PASS/FAIL gesehen. CEO sollte den P2-Report lesen und entscheiden.

5. **Dashboard online:** Wann soll quantmechanica.com/strategies online gehen? (Lokal fertig, Astro-Integration ausstehend)

6. **DL-055 Token-Burn Alarm:** Placeholder-Cap, noch nicht wirklich konfiguriert. Soll ein konkretes monatliches Token-Budget pro Agent gesetzt werden?

7. **Quality-Business Rolle:** Aktuell idle — welche konkreten Tasks soll QB als nächstes übernehmen?

8. **Observability-SRE:** Noch nicht eingestellt (Wave 3). Bis dahin: Wer monitort T6-Health aktiv?

9. **Founder-Comms (Gmail-Integration):** Deferred indefinitely — ist das noch korrekt, oder soll das früher angegangen werden?

10. **Erste YouTube-Episode:** Wann? M2 (erste Baseline) wäre der natürliche Trigger. Sind wir bereit?

---

## 16. Referenzen (Kanonische Quellen)

| Dokument | Pfad | Zweck |
|---------|------|-------|
| Pipeline Phase Spec | `docs/ops/PIPELINE_PHASE_SPEC.md` | 15-Phasen-Pipeline |
| Pipeline Sub-Gate Spec | `docs/ops/PIPELINE_V5_SUB_GATE_SPEC.md` | Gate-Thresholds |
| Org Self-Design Model | `docs/ops/ORG_SELF_DESIGN_MODEL.md` | Org-Struktur |
| Agent Skill Matrix | `docs/ops/AGENT_SKILL_MATRIX.md` | Skills pro Rolle |
| V5 Framework Design | `framework/V5_FRAMEWORK_DESIGN.md` | EA-Framework |
| Branding Guide | `branding/QM_BRANDING_GUIDE.md` | Brand Tokens |
| CLAUDE.md | `CLAUDE.md` | Board Advisor Regeln |
| Paperclip Operating System | `docs/ops/PAPERCLIP_OPERATING_SYSTEM.md` | API-Patterns |
| Skills Library | `skills/qm/` | 13 Pipeline Skills |
| Strategy Cards | `strategy-seeds/cards/` | Alle Strategie-Karten |
| Magic Registry | `framework/registry/magic_numbers.csv` | EA-Symbol-Mapping |

---

*Dieses Dokument wurde erstellt am 2026-05-08 durch Board Advisor, synthetisiert aus Notion (Paperclip V2 Company Design, Project Charter, V5 Pipeline Design, Research Methodology V2, Company Operating System), lokalen VPS-Docs und aktuellem Live-State der Paperclip Company.*
