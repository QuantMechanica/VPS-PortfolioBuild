# Konvergenz-Ledger — Claude ⇄ Codex (Ziel: ≥90 % pro MNT-Topic)

> **OWNER-Mandat 2026-07-28:** Iteratives Review, bis Claude und Codex bei **jedem** MNT-Topic zu ≥90 % übereinstimmen, *wie* es gelöst werden soll. Erst dann APPROVED. Codex läuft dauerhaft auf Sol-Max. Dieses Ledger hält pro Topic den Übereinstimmungsgrad und die offenen Dissenspunkte; gepflegt von Claude nach jeder Runde.
>
> **Mirror-Hinweis:** Kanonischer Ort ist der Vault (`Maintenance/Konvergenz-Ledger.md`); G:-Mount war beim Stand 2026-07-29 down (GoogleDriveFS nicht gelaufen), daher Repo-Kopie zuerst. Spiegelung bei nächster G:-Verfügbarkeit.

**Stand:** 2026-07-29 (nach Runde 4) · R1 RECYCLE · R2/R3/R4 **APPROVED** · **✅ KONVERGENZ-MANDAT ERFÜLLT: 46/46 Topics ≥90 %.** Verbleibend: Umsetzung + OWNER-Entscheidungen (unten).

## Runde 4 — Ergebnis (Task 3fbc789c): letzte 10 Topics konvergiert

Alle 10 Positionen 93–99 %, evidenzgebunden (E1–E11 im Positionspapier). Kernpunkte: **MNT-031 P1-Hochstufung akzeptiert (99 %)** mit ancestry-erhaltender Integrationsstrategie (Divergenz inzwischen 4/1751; lokales `main` KEIN sicherer Proxy: 25/2733); MNT-020 alle 4 Claude-Korrekturen akzeptiert, Handle-Cache bleibt korrekt Hypothese bis Same-Source-A/B; MNT-027 beide Matrix-Erweiterungen; MNT-024/025/028 G:-Lauffähigkeitsvertrag + Drei-Zustands-Preflight (`MOUNT_UNAVAILABLE`/`TARGET_MISSING`/`TARGET_INVALID`); MNT-029 Renderer-Defekt real (`render_cockpit.py` schluckt Feed-Fehler; `owner_decisions.json` stale seit 23.07. → Claude-Refresh fällig); MNT-030 Kette 003→030 notwendig-nicht-hinreichend; MNT-032 **zwei Claude-Behauptungen widerlegt und akzeptiert** (Schwelle 150 GB seit 21.07., nicht „>80 GB" — CLAUDE.md war stale, korrigiert); MNT-033 generierte Sicht statt dritter Autorität.

**Incident während Runde 4 (behoben):** Purge-Task (SYSTEM) seit ~01:20 in 0x800710E0-Klasse; D: brannte 208→42,6 GB in ~9 h. Claude-Sofortmaßnahme: kanonische Purge direkt ausgeführt → **240,6 GB frei (198 GB reclaimed)**, aktive Terminals T2/T3/T6 geschützt, 9/9 Worker danach gesund. Scheduler-Heilung hängt an MNT-003-Apply.

## Verbleibende Arbeit (nach Konvergenz)

1. **OWNER-Entscheidungen:** (a) MNT-045 Fail-hard ratifizieren; (b) MNT-043 Requalifikationskonsequenz (`vintage_stale`); (c) MNT-031 Integrationsfenster autorisieren (Merge der 4 main-Commits, dann main-Fast-Forward); (d) Task-Contract-Package interaktiv applyen (PLAN → WhatIf → Apply) — heilt 0x800710E0-Klasse inkl. Purge-/agy-/Mailbox-Lanes.
2. **Claude:** `owner_decisions.json` refresh; Vault-Spiegelung Maintenance-Ordner sobald G: zurück.
3. **Umsetzung je Topic** gemäß konvergierter Contracts (Reihenfolgen: 009→010, 003→002→004, 003→030, 043→017/018/020/044).

## Runde 3 — Ergebnis (Task 6a1811dd)

**WP-1 verifiziert:** 122/122 Tests; Strategy/Neutral-Trennung implementiert (`strategy_verdict_rank`, `latest_run`-Feld, regressed nur auf Strategie-Verdicts); Produktionseffekt 636→374 regressed — mit Codex' korrekter Einsicht, daß 39 Flags zu Recht bleiben (echte Strategie-Regression unter neutralem Latest). Invarianten-Formulierung ersetzt meine „~334"-Konstante.

**WP-2 Positionsrunde MNT-043–046:** Codex-Positionen 82/92/84/86 % — **alle materiellen Dissense von Claude übernommen** (043: Closure-Hash-Provenienz statt mtime, P0-Live-Bill/P1-Requal-Split, `evidence_vintage_stale` bei Binary-Wechsel [Beweis: 9936-Vintage-Bisect 91,5 %/−11,1 % FUND_SCORE]; 044: append-only Adjudication-Overlay statt Rohzeilen-Umschreiben, Register bei Bill-Erstellung frisch [1567/EURUSD hat sich bereits bewegt]; 045: Degrade-Option gestrichen → fail-hard + Pre-Claim/Pre-Spawn-Preflight je Prinzipal, atomarer Bundle-Publisher, Fault-Injection vor „7 Tage grün"; 046: exakte `PHASE_RUNNER_SCRIPTS`-Allowlist statt Glob, Work-Item-/Lineage-Bindung, 2 stabile Null-Scans; Claude-Ergänzung: Near-Match-Prozesse als `REVIEW_REQUIRED` sichtbar ohne Kill). Merged Seiten: `docs/ops/mnt_page_updates_2026-07-28/MNT-043..046.md`. **043→95 % · 044→95 % · 045→95 % · 046→93 % — konvergiert.**

**Offene OWNER-Entscheidungen aus R3:** (a) MNT-045: Fail-hard-Semantik ratifizieren (gemeinsame Empfehlung Claude+Codex: keine Degrade-Option). (b) MNT-043: Requalifikationskonsequenz akzeptieren — Rebuild macht Alt-Evidenz `vintage_stale`, admission-relevante Gates laufen mit neuer SHA neu (Compute-Kosten).

## Runde 2 — Ergebnis (Task 6066746a)

Alle drei Majors verifiziert gefixt: (R1) beide after-XMLs jetzt via `run_in_console_session.ps1 -TargetUser qm-admin`, WaitSeconds/Exit-Code-Kette real (Wrapper-Param existiert auf Kanon seit ed46fff50); Package 8/8 before==Frisch-Export, unexecuted. (R2) pipeline_view latest/best/regressed exakt; P2→Q02-Reihenfolge sicher; Produktionsbeleg 10035/Q04 auf DB-Kopie reproduziert. (R3) PART 5c auf Reboot-Block begrenzt UND ausgeführt (217 Assertions; Nicht-Vakuität per manipulierter Baseline bewiesen; Block byte-identisch zu fa215b3e9). Alle 9 R4-Minors geliefert, Suiten 92+119 grün. **MNT-003 → ~93 % ✅ · MNT-040 → ~90 % ✅.** Damit alle 8 behandelten Topics ≥90 %.

**Neu aus dem adversarialen Review (→ Runde 3, Verfeinerung von Claudes eigener R2-Spec):** INFRA_FAIL (Rang 0, 53.288 Zeilen = häufigste Klasse) als „latest" wird zum Current-Verdict und treibt 334/637 (52 %) der regressed-Flags; 150 Gruppen maskieren ein echtes PASS. Fix: Current-Strategy-Verdict = jüngstes NICHT-neutrales Verdict; regressed nur auf Strategie-Verdicts; Infra-Zustand als separates Feld. Dazu Test-Pins (P2 explizit, lowercase-Legacy-Suffixe P5b/P5c/P9b, current_stage-Doku-Zeile, Package-Test -Exe/Wait≤Limit).

## Runde 1 — Ergebnis (Task 80b9d54d, Brief `CODEX_BRIEF_mnt_review_corrections_2026-07-28.md`)

Verifiziert durch 4 unabhängige Prüfagenten (Seiten, Park-Code, Task-Package, Tests). Codex' Lieferung: 6 korrigierte Seiten, Supervisor-Root-Cause (InteractiveToken-Queue-No-Op, Event 110/325 ohne 200), unexecuted 8-Task-XML-Package, Park-Awareness in 6 Quellen, KS-Dual-Dir-Checks, pipeline_view-Rewrite, 86/88 Tests grün (2 Fails vorbestehend).

| Topic | Übereinstimmung | Status | Offene Dissens-/Restpunkte |
|---|---|---|---|
| MNT-001 | **93 %** | ✅ konvergiert | Minor: Zahlenbrücke 11↔24↔54 in der Seite herleiten (R4) |
| MNT-002 | **92 %** | ✅ konvergiert | Minor: 666→687-Zählerdrift als Meßhinweis vermerken (R4); Session-Starter verifiziert gut |
| MNT-003 | **~93 %** | ✅ konvergiert (R2) | Runde-1-Major behoben: beide Lanes via Console-Wrapper; Rest = Apply-Entscheidung (OWNER/Claude interaktiv, PLAN→WhatIf→Apply) |
| MNT-004 | **~92 %** | ✅ konvergiert | Minor: MAINTENANCE überschreibt Review-Expiry (fail-open-Ecke) → expiry-gewinnt oder OWNER-Entscheid; Präzedenz-Label py↔PS kosmetisch verschieden |
| MNT-017 | **97 %** | ✅ konvergiert | Seite soll klarstellen: Input-Verdrahtung pro EA verifizieren (nur 1116 quell-geprüft; Baskets = anderer Bypass) |
| MNT-018 | **94 %** | ✅ konvergiert | Legacy-Counts (23 / 105) sind Snapshot-Werte, live nicht direkt reproduzierbar — Akzeptanz korrekt invariant-gepinnt |
| MNT-019 | **97 %** | ✅ konvergiert | — |
| MNT-040 | **~90 %** | ✅ konvergiert (R2) | latest/best/regressed geliefert; Runde 3: Neutral-Family-Verfeinerung (Infra-Rauschen raus aus Current/regressed) + Test-Pins |
| 006/007/008/009/010/012/013/015/016/021/036/041 | **~92 %** | ✅ konvergiert (Fold-Ack) | Codex-Lösungen + von Codex explizit acknowledgte Claude-Korrekturen = beidseitige Position; Umsetzung folgt je Topic |
| 005/011/014/022/023/026/034/035/037/038/039/042 | **~93 %** | ✅ konvergiert (Endorsement) | Von Claude im Review ohne Einschränkung bestätigt; Codex = Autor — beidseitig ≥90 % |
| 020/024/025/027/028/029/030/031/032/033 | **96/94/97/98/94/97/98/99/93/97 %** | ✅ konvergiert (R4) | Alle Refinements beidseitig akzeptiert; 031 jetzt P1; 030 P1 solange Lane down; 032 P1-Incident behoben/P2-Härtung |
| 043/044/045/046 | **95/95/95/93 %** | ✅ konvergiert (R3) | Merged Contracts in `docs/ops/mnt_page_updates_2026-07-28/`; 2 OWNER-Entscheidungen offen (s. o.) |

## Querschnittsbefunde Runde 1 (Ehrlichkeit der Evidenz)

- **Major R3:** Evidenzdoc behauptet „Recovery-/Reboot-State-Machine byte-for-byte erhalten" — der Verbatim-Test (PART 5c) lief nie (Baseline-Pfad leer → SKIPPED) und schlägt gegen den echten Vorgänger fehl (Haupt-State-Machine wurde absichtlich umgebaut). Der Reboot-**Ausführungsblock** ist intakt (diff-verifiziert), aber die Behauptung übersteigt das Geprüfte. Muß korrigiert werden — Papierstempel-Doktrin gilt auch für Testbehauptungen.
- Positiv verifiziert: Watchdog-Contract-Check erwartet exakt die after-XMLs (kein „Drift-für-immer" nach Apply); Escalation-Kante (1× nach 3 identischen Zyklen) testbewiesen; Reboot-Abbruchkante intakt; PS5.1-sauber; atomare State-Writer; Package 8/8 before==Live-Frisch-Export, Apply-Skript sicher (PLAN-Default, keine verbotenen Aktionen).
- **OWNER-Hinweis:** Nach Deploy des Branches springt `ks_baseline` sofort ROT (mirror_divergent=54 — alle 54 Baseline-Paare divergieren zwischen T_Live-lokal und Common). Gewollt (echtes Problem wird sichtbar); die 54er-Reconciliation bleibt OWNER-gebunden (MNT-001).

## Regeln

1. Ein Topic gilt als konvergiert bei ≥90 % Übereinstimmung über *Lösungsweg + Akzeptanzkriterien*; Minor-Restpunkte werden notiert und in der nächsten Lieferung mitgezogen.
2. APPROVED erst, wenn alle Topics einer Lieferung konvergiert sind und keine Evidenz-Ehrlichkeitsbefunde offen sind.
3. Scores vergibt Claude nach unabhängiger Verifikation (nie nach Selbstauskunft).
