# Konvergenz-Ledger — Claude ⇄ Codex (Ziel: ≥90 % pro MNT-Topic)

> **OWNER-Mandat 2026-07-28:** Iteratives Review, bis Claude und Codex bei **jedem** MNT-Topic zu ≥90 % übereinstimmen, *wie* es gelöst werden soll. Erst dann APPROVED. Codex läuft dauerhaft auf Sol-Max. Dieses Ledger hält pro Topic den Übereinstimmungsgrad und die offenen Dissenspunkte; gepflegt von Claude nach jeder Runde.
>
> **Mirror-Hinweis:** Kanonischer Ort ist der Vault (`Maintenance/Konvergenz-Ledger.md`); G:-Mount war beim Stand 2026-07-29 down (GoogleDriveFS nicht gelaufen), daher Repo-Kopie zuerst. Spiegelung bei nächster G:-Verfügbarkeit.

**Stand:** 2026-07-29 (nach Runde 2) · Runde 1 (`80b9d54d`) = RECYCLE mit Feedback · Runde 2 (`6066746a`) = **APPROVED** (alle 3 Majors unabhängig verifiziert gefixt; Evidenz `docs/ops/evidence/2026-07-29_mnt_review_round2.md`, Commit `31c51587a`) · Runde 3 dispatched (Neutral-Family-Verfeinerung + Positionsrunde MNT-043–046).

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
| 006/007/008/009/010/012/013/015/016/021/036/041 | Position übernommen | 🟡 Fold-Ack | Alle Minor Folds im Evidenzdoc explizit acknowledged (= Übereinstimmung mit der Korrektur); Voll-Lösungs-Konvergenz je Topic folgt in späteren Runden |
| 005/011/014/020/022–035/037–039/042 | — | ⚪ ausstehend | Noch nicht Gegenstand einer Runde |
| 043/044/045/046 | — | ⚪ ausstehend | Von Claude verfaßt; Codex-Gegenposition steht aus |

## Querschnittsbefunde Runde 1 (Ehrlichkeit der Evidenz)

- **Major R3:** Evidenzdoc behauptet „Recovery-/Reboot-State-Machine byte-for-byte erhalten" — der Verbatim-Test (PART 5c) lief nie (Baseline-Pfad leer → SKIPPED) und schlägt gegen den echten Vorgänger fehl (Haupt-State-Machine wurde absichtlich umgebaut). Der Reboot-**Ausführungsblock** ist intakt (diff-verifiziert), aber die Behauptung übersteigt das Geprüfte. Muß korrigiert werden — Papierstempel-Doktrin gilt auch für Testbehauptungen.
- Positiv verifiziert: Watchdog-Contract-Check erwartet exakt die after-XMLs (kein „Drift-für-immer" nach Apply); Escalation-Kante (1× nach 3 identischen Zyklen) testbewiesen; Reboot-Abbruchkante intakt; PS5.1-sauber; atomare State-Writer; Package 8/8 before==Live-Frisch-Export, Apply-Skript sicher (PLAN-Default, keine verbotenen Aktionen).
- **OWNER-Hinweis:** Nach Deploy des Branches springt `ks_baseline` sofort ROT (mirror_divergent=54 — alle 54 Baseline-Paare divergieren zwischen T_Live-lokal und Common). Gewollt (echtes Problem wird sichtbar); die 54er-Reconciliation bleibt OWNER-gebunden (MNT-001).

## Regeln

1. Ein Topic gilt als konvergiert bei ≥90 % Übereinstimmung über *Lösungsweg + Akzeptanzkriterien*; Minor-Restpunkte werden notiert und in der nächsten Lieferung mitgezogen.
2. APPROVED erst, wenn alle Topics einer Lieferung konvergiert sind und keine Evidenz-Ehrlichkeitsbefunde offen sind.
3. Scores vergibt Claude nach unabhängiger Verifikation (nie nach Selbstauskunft).
