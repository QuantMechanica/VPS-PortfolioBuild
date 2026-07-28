# Konvergenz-Ledger — Claude ⇄ Codex (Ziel: ≥90 % pro MNT-Topic)

> **OWNER-Mandat 2026-07-28:** Iteratives Review, bis Claude und Codex bei **jedem** MNT-Topic zu ≥90 % übereinstimmen, *wie* es gelöst werden soll. Erst dann APPROVED. Codex läuft dauerhaft auf Sol-Max. Dieses Ledger hält pro Topic den Übereinstimmungsgrad und die offenen Dissenspunkte; gepflegt von Claude nach jeder Runde.
>
> **Mirror-Hinweis:** Kanonischer Ort ist der Vault (`Maintenance/Konvergenz-Ledger.md`); G:-Mount war beim Stand 2026-07-29 down (GoogleDriveFS nicht gelaufen), daher Repo-Kopie zuerst. Spiegelung bei nächster G:-Verfügbarkeit.

**Stand:** 2026-07-29 (nach Runde 1) · Runde 2 dispatched (Nachfolger von `80b9d54d`, das mit RECYCLE + Feedback geschlossen wurde).

## Runde 1 — Ergebnis (Task 80b9d54d, Brief `CODEX_BRIEF_mnt_review_corrections_2026-07-28.md`)

Verifiziert durch 4 unabhängige Prüfagenten (Seiten, Park-Code, Task-Package, Tests). Codex' Lieferung: 6 korrigierte Seiten, Supervisor-Root-Cause (InteractiveToken-Queue-No-Op, Event 110/325 ohne 200), unexecuted 8-Task-XML-Package, Park-Awareness in 6 Quellen, KS-Dual-Dir-Checks, pipeline_view-Rewrite, 86/88 Tests grün (2 Fails vorbestehend).

| Topic | Übereinstimmung | Status | Offene Dissens-/Restpunkte |
|---|---|---|---|
| MNT-001 | **93 %** | ✅ konvergiert | Minor: Zahlenbrücke 11↔24↔54 in der Seite herleiten (R4) |
| MNT-002 | **92 %** | ✅ konvergiert | Minor: 666→687-Zählerdrift als Meßhinweis vermerken (R4); Session-Starter verifiziert gut |
| MNT-003 | **~80 %** | 🔄 Runde 2 | **Major R1:** after-XMLs GeminiOrchestration + MailboxSourceIntake = bare SYSTEM, aber agy-Auth = per-User Credential Manager (`gemini:antigravity`) + LOCALAPPDATA → bricht unter SYSTEM; Wrapper wie AgyGovernor nötig oder SYSTEM-Auth beweisen. Evidenzdoc-Matrix nennt AgyGovernor/WorkerDedupe fälschlich „bereits" SYSTEM-Wrapper (ist Soll-, nicht Ist-Zustand) |
| MNT-004 | **~92 %** | ✅ konvergiert | Minor: MAINTENANCE überschreibt Review-Expiry (fail-open-Ecke) → expiry-gewinnt oder OWNER-Entscheid; Präzedenz-Label py↔PS kosmetisch verschieden |
| MNT-017 | **97 %** | ✅ konvergiert | Seite soll klarstellen: Input-Verdrahtung pro EA verifizieren (nur 1116 quell-geprüft; Baskets = anderer Bypass) |
| MNT-018 | **94 %** | ✅ konvergiert | Legacy-Counts (23 / 105) sind Snapshot-Werte, live nicht direkt reproduzierbar — Akzeptanz korrekt invariant-gepinnt |
| MNT-019 | **97 %** | ✅ konvergiert | — |
| MNT-040 | **~85 %** | 🔄 Runde 2 | **Major R2:** Implementierung ist best-verdict-wins (stale PASS maskiert neueren FAIL; 10035/Q04: 1 PASS_SOFT vs ~60 FAILs → zeigt PASS_SOFT) statt latest-wins — widerspricht dem eigenen Vertrag „jüngste kanonische Verdict-Kette". Dazu `Q09_PORTFOLIO` (112 Zeilen) nicht normalisiert (Rang −1); UUID-Fallback kann Phantom-EAs prägen |
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
