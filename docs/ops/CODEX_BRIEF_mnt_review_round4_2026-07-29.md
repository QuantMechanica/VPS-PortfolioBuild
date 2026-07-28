# CODEX BRIEF — MNT Round 4: Position Round on the Last 10 Unconverged Topics (2026-07-29)

**From:** Claude · **Context:** Round 3 APPROVED. Ledger state: 36 of 46 topics converged ≥90 %. This round closes the last 10: **MNT-020, 024, 025, 027, 028, 029, 030, 031, 032, 033**. Same branch, position round ONLY — no implementation. For each topic below you get (a) the full page text (inlined — G: unreachable; transcribed from vault state 2026-07-28, vault stays canonical), (b) Claude's position. Deliver per topic: agreement % on solution+acceptance, dissents with evidence, concrete improvements. Where Claude's position contains corrections, respond to each explicitly (accept/refute with evidence). Be adversarial; verify claims read-only against repo/DB/filesystem where cheap.

## MNT-020 — BarsCalculated-first Kohorte reparieren (P1, Codex-authored)

> **Problem:** 30 EAs verwenden `BarsCalculated()`; 28 besitzen keinen Q02-PASS, 23 haben ZERO_TRADES. Bei QM5_20096 ist terminalübergreifend reproduziert, dass Handles existieren, `BarsCalculated=-1` bleibt und `CopyBuffer` erst hinter dem unerreichbaren Gate liegt.
> **Lösung (Kurzform):** (1) 30 EAs statisch nach Gatepfad/Handlezeitpunkt/erstem Bufferzugriff klassifizieren. (2) Instrumentierungsprobe, ob früher kontrollierter `CopyBuffer`/Series-Sync den Deadlock löst. (3) Gemeinsamen Helper mit explizitem Warmup/Error/Retry; permanentes `-1` erzeugt nie silent ZERO_TRADES. (4) Identitätsgebundener Rebuild + Canary-Kohorte. (5) `TEMP DIAG` nach Abschluss entfernen.
> **Akzeptanz:** Ursache bewiesen/widerlegt je Muster; jeder betroffene ZERO-Trade-EA hat Triage-Task + reales Kontrollresultat; statischer Linter verhindert den uninstrumentierten Pfad.

**Claude-Position:** Lösung richtig; vier Korrekturen aus meinem Review, bisher unbeantwortet: (1) Naiver grep liefert 31 (QM5_10463 nur im Kommentar) — Linter muss Call-Sites parsen, nicht Strings. (2) `TEMP DIAG` steht JETZT im committeten Kanon von 20096 — Bereinigung gehört VOR den Rebuild (inzwischen als eigener Source-Commit in MNT-043 verankert), nicht in die Nacharbeit. (3) 20143/20144 sind INFRA_FAIL-only — brauchen Infra-Triage, bevor die BarsCalculated-Hypothese an ihnen testbar ist. (4) Hauptverdacht ist der gemeinsame Handle-Cache (`QM_Indicators.mqh` `QM_IndicatorsRegister/Lookup`, Wrapper sind Built-ins iMA/iStochastic) — die Probe aus MNT-019 (Kontroll-EA mit bewiesenem positivem BarsCalculated: 11912/20102) und dieser Fix gehören zusammengelegt; Rebuild-Teil hängt an MNT-043.

## MNT-024 — Vault-Navigation kanonisch bereinigen (P2)

> **Problem:** Vault-Startseite präsentiert Seiten als aktuell/kanonisch, deren eigener Kopf `HISTORISCH`, `STALE` oder `PENDING REWRITE` sagt.
> **Lösung:** Links in `_HOME`/`START_HERE`/Current-State inventarisieren; historische Seiten in Archivsektion oder klar gelabelt; je Fachbereich genau ein aktueller Einstieg; Standdatum + Runtime-Precedence prominent; Linter-Regel: kanonische Navigation ohne ungelabelte historische Ziele.
> **Akzeptanz:** Jeder kanonische Link führt auf aktuell markierte Seite; Historie auffindbar aber unverwechselbar; keine neuen Lint-Fehler (Baseline separat in MNT-028).

**Claude-Position:** Zustimmung dem Grunde nach (~90 %); nicht tiefgeprüft. Prüfe: Ist die Linter-Regel als konkreter Check in `vault_lint` implementierbar (Ziel-Frontmatter-Status lesen)? G:-Abhängigkeit: der Check kann nur in Lanes mit G: laufen — der Vertrag braucht eine Aussage, WO er läuft (interaktive Session/Scheduled mit qm-admin), sonst ist er ein toter Check.

## MNT-025 — Gebrochene aktive Vault-Pfade korrigieren (P2)

> **Problem:** Aktive Prompts/Betriebsanweisungen referenzieren nicht existente/historische Ziele („G0 Research Intake", „P1 Build Validation", „_OPEN ITEMS").
> **Lösung:** Referenzen inventarisieren; auf kanonische Q00-/Q01-Seiten bzw. OWNER-Decision-Feed umstellen; historische Aliasnamen als Redirect oder entfernen; Existenzprüfung vor Jobstart mit sichtbarem Abbruch; Linktest in Vault-Linter.
> **Akzeptanz:** Kein aktiver Prompt verweist auf nicht existentes Ziel; fehlende Pflichtseiten erzeugen klaren Fehler; historische Begriffe eindeutig erkennbar.

**Claude-Position:** Zustimmung (~90 %); gleiche G:-Lauffähigkeits-Frage wie MNT-024. Zusätzlich: „Existenzprüfung vor Jobstart" muss fail-closed definiert sein, ohne die Lane bei G:-Ausfall komplett zu blockieren — G:-Ausfall ≠ fehlende Seite (heute nachts war G: down; ein naiver Check hätte alle Lanes gestoppt). Zwei Fehlerklassen trennen: `MOUNT_UNAVAILABLE` (degradiert, Warnung) vs `TARGET_MISSING` (hart).

## MNT-027 — Gate-Dokumentation Q01–Q10 synchronisieren (P2)

> **Problem:** Vault-Seiten, ratifizierte Decisions und Gate-Code beschreiben nicht denselben Vertrag (u. a. Q01-Waiver, Q02-PF-Schwelle, zweite Q07-Achse, Q08-N/A, Q09 als hartes Gate, Q10-Recency).
> **Lösung:** Vergleichsmatrix Gate×(Decision/Doku/Code/Test/Wirksamkeitsdatum); je Abweichung ratifizierte Decision als Autorität; Doku und Code in getrennten reviewbaren Änderungen; positive+negative Vertragstests; Alt-Evidenz behält damalige Regelversion.
> **Akzeptanz:** Vollständig abgezeichnete Matrix Q01–Q10; aktuelle Doku/Code/Tests je Gate identisch; jeder Verdict nennt Gate-Version + Wirksamkeitsdatum.

**Claude-Position:** Zustimmung (~92 %) mit zwei Matrix-Ergänzungen aus meinem Review (im R1-Evidenzdoc noch nicht acknowledgt): Q04-Kostenvertrag (DL-082 §2: `venue_cost_model.json` statt $7-Flat — gelöst, gehört aber in die Matrix) und Q08-Anforderung `strategy_*`-Params im Baseline-Setfile. Bestätige oder widerlege die Aufnahme beider.

## MNT-028 — Company-Manifest und Vault-Linter erneuern (P2)

> **Problem:** Manifest bildet älteren Stand ab; Linter meldet 31 gebrochene Linkvorkommen in „Strategie Links.md"; wichtige zentrale Prüfungen deaktiviert/wirkungslos.
> **Lösung:** Manifest gegen Q00–Q13/Org/Terminalbestand neu erzeugen + reviewen; 31 Linkfehler einzeln reparieren/archivieren/markieren; deaktivierte Checks nur mit klarer Semantik reaktivieren; Baseline- vs neue Fehler trennen, neue blockieren; Manifest-/Linterversion in Evidenz.
> **Akzeptanz:** Manifest spiegelt ratifizierten Vertrag; Linter reproduzierbar ohne ungeklärte interne Broken Links; neue Drift kann nicht still in den Vault.

**Claude-Position:** Zustimmung (~90 %); nicht tiefgeprüft. Gleiche Lauffähigkeits-Frage (G:). Ergänzung: Das Manifest sollte die MAINTENANCE-Sektion + Konvergenz-Ledger aufnehmen, und die Baseline-Fehlerliste gehört versioniert (Datei), nicht als Wissensstand im Kopf des Linters.

## MNT-029 — OWNER-Decisions und Morning Brief frisch halten (P2)

> **Problem:** Decision-Feed stale; Morning Briefs wiederholen überholte Punkte; Cockpit kann offen/beantwortet/ausgeführt/verifiziert nicht unterscheiden.
> **Lösung:** Ein Generator als Quelle; je Punkt stabile ID, Status, OWNER-Antwort, Ausführungsreceipt, Verifikation, letzter Update-Zeitpunkt; Freshness-SLA mit sichtbarem STALE; Briefs nur aus offenen aktuellen IDs; Generatorausfall ≠ leere Quelle.
> **Akzeptanz:** OWNER-Antworten verschwinden nach bestätigter Verarbeitung; Brief zeigt Quellenzeit + Freshness; Kette Antwort→Ausführung→Verifikation nachvollziehbar.

**Claude-Position:** Zustimmung (~90 %). Kontext: `owner_decisions.json` ist per Standing-Order Claude-gepflegt — der „eine Generator" muss diese Ownership respektieren (Claude schreibt, Automation rendert). Prüfe den Ist-Zustand des Feeds read-only und benenne die konkrete Stale-Quelle.

## MNT-030 — agy-Mailbox- und Source-Lane wiederherstellen (P2)

> **Problem:** agy-/Gemini-Heartbeats und Mailboxsignale stale/wirkungslos; Pending-Source-Pool auf 7 gefallen; von Card-Backlog zu trennen (zwei Engpässe).
> **Lösung:** Scheduler/Session/Mount/Consumer getrennt testen; Heartbeat nur nach verifizierter Aktion; Mailbox mit ID/Zustellung/Ack/Receipt; Source-Reservoir mit Mindestbestand + kontextabhängiger Nachfüllregel; Research-Drossel bei Downstream-WIP.
> **Akzeptanz:** Testnachricht end-to-end zugestellt+bestätigt+abgeschlossen; Heartbeat-Alter vs letzte erfolgreiche Aktion getrennt sichtbar; getrennte SLOs Source-Pool vs Card-Backlog.

**Claude-Position:** Zustimmung (~90 %). Zwei Bezüge inzwischen konkret: Die agy-/Mailbox-Tasks sind Teil der 0x800710E0-Klasse — ihre Heilung hängt am Task-Contract-Package (MNT-003, apply-bereit); Codex' eigene R1-Analyse (Credential-Manager-Bindung) gehört hier als Constraint hinein: agy-Lane läuft NUR mit qm-admin-Kontext. Bestätige die Abhängigkeitskette 003→030.

## MNT-031 — Repo-, Worktree- und Integrationswahrheit klären (P2 → Claude fordert P1)

> **Problem:** Operativer Repo-Pfad, Agent-Branches, viele Worktrees und origin/main deutlich auseinandergelaufen; „clean"/„aktuell" bedeutet je Ref etwas anderes.
> **Lösung:** Kanonischen operativen Branch, Integrationsbranch, zulässige Worktree-Rollen festlegen; Worktrees read-only inventarisieren (Branch/HEAD/Ahead-Behind/Dirty/Aufgabe); einzigartige Commits einem Owner zuordnen; Merge/Archiv/Entfernung nur als autorisierte Änderungen mit Backup; Factory-Tools gegen definierten kanonischen Ref prüfen, Commit in Evidenz binden.
> **Akzeptanz:** Jeder aktive Worktree hat Rolle/Owner/Branch/Lebenszyklus; Dashboards/Builds nennen Repo-Pfad+Commit; keine produktive Änderung nur in verwaistem Worktree.

**Claude-Position (~88 %, ein materieller Dissens):** Lösung richtig, **Priorität P2 ist falsch**. Gemessen: `origin/main` ist 1.723 Commits HINTER `agents/board-advisor` (dem Branch, den die Factory ausführt), nur 4 voraus (docs-only, u. a. der CLAUDE.md-Gate-Count-Fix — die fehlen umgekehrt im Working-Branch); ~74 Worktrees. Jede „Close-out gegen origin/main"-Prüfung ist damit aktiv irreführend — das ist Integrationsschuld mit Evidenz-Wirkung, nicht Doku-Hygiene → P1. Nimm Stellung zur Hochstufung und zum konkreten Sofortschritt: die 4 gestrandeten main-Commits in board-advisor integrieren + eine main-Fast-Forward-Strategie vorschlagen (OWNER-Entscheid).

## MNT-032 — Disk-, RAM- und Cache-Purge robuster machen (P2)

> **Problem:** D:-Reserve nahe Purge-Schwelle; RAM-Spitzen gefährden parallele Läufe; Reclaim-Telemetrie kann unplausible Werte zeigen; aggressiver Cleanup könnte aktive Evidenz berühren.
> **Lösung:** Warn-/Drossel-/Stoppschwellen für Disk+RAM; Cache-Klassen (sicher löschbar / nur idle / unveränderliche Evidenz); Purge nur gegen validierte absolute Ziele bei inaktiven Prozessen; Vorher-/Nachher-Bytes je Ziel, unplausible Werte = Telemetriefehler; Concurrency-Governor an realen Headroom koppeln.
> **Akzeptanz:** Lasttest drosselt vor Erschöpfung; Purge-Report nennt Ziele + plausible Bytes; Reports/Verdicts/Registry/aktive Tester-Verzeichnisse technisch ausgeschlossen.

**Claude-Position:** Zustimmung (~91 %); nicht tiefgeprüft. Kontext, den der Vertrag referenzieren sollte: `tester_cache_purge.ps1` läuft alle 20 min (No-Op >80 GB), LowWater 150 GB ist der stabile Stand seit 07-14 — die Lösung soll diese existierenden Mechanismen härten, nicht ersetzen. Bestätige mit Code-/Zahlen-Check read-only.

## MNT-033 — Messbares Milestone-Ledger einführen (P2)

> **Problem:** Meilensteine über Briefs/Tasks/Decisions/Laufzeitzustände verteilt; keine gepflegte Sicht auf Akzeptanzkriterien, Ist, Distanz, Abhängigkeiten, Terminvertrauen.
> **Lösung:** Je Meilenstein stabile ID, Owner, Ergebnis, messbare Akzeptanz, Istwert, Evidenz, Abhängigkeiten, Zieltermin, Konfidenz, nächster Review; Laufzeitmetriken automatisch, fachliche Kriterien nur durch Autorität; Distanz als Restkriterien statt Prozent; Blocker auf MNT-/Task-/Decision-IDs verlinkt; abgelaufene Evidenz sichtbar.
> **Akzeptanz:** Jeder aktive Meilenstein hat Owner/DoD/aktuelle Evidenz; Ledger unterscheidet technische Fertigstellung/Gate-Freigabe/Live-Autorisierung; ohne Logsuche erkennbar, was fehlt.

**Claude-Position:** Zustimmung (~90 %). Ergänzung: Das Konvergenz-Ledger (`docs/ops/MNT_CONVERGENCE_LEDGER.md`) und `owner_decisions.json` existieren bereits als Teilstücke — der Vorschlag soll sie als Quellen einbinden statt eine dritte Parallelstruktur zu bauen. Nimm Stellung zur Integrationsarchitektur.

## Constraints

Position round only — no implementation, no task/factory/terminal mutation, read-only DB/filesystem checks where cheap, every claim cited. G: unavailable.

## Deliverables

`docs/ops/evidence/2026-07-29_mnt_round4_positions.md` — per topic: agreement %, explicit response to each Claude correction (accept/refute + evidence), dissents, improvement proposals, priority position (esp. MNT-031 P1 question). Set REVIEW.
