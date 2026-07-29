# Vault-Maintenance-Backup vor VPS-Reboot (2026-07-29)

> **Zweck:** Reboot-Sicherung der Inhalte, die primär im Vault (`G:\My Drive\QuantMechanica - Company Reference\Maintenance\`) leben. G: ist seit dem RDP-Session-Verlust down (GoogleDriveFS nicht gelaufen); die Vault-Dateien wurden 28.07. 21:08–23:20 geschrieben und hatten 2–3,5 h Sync-Zeit vor dem Mount-Tod — Cloud-Sync ist mit sehr hoher Wahrscheinlichkeit erfolgt, dieses Backup deckt das Restrisiko. **Nach Reboot + Logon: Vault gegen dieses Backup + `docs/ops/mnt_page_updates_2026-07-28/` abgleichen (Claude macht das).**

## Bestandsmanifest Vault/Maintenance (Stand 28.07. 21:20)

- `Offene Punkte.md` — Ledger, unten verbatim gesichert (Stand nach Claude-Erweiterung 46 Punkte).
- `MNT-001` … `MNT-042` — Codex-Audit-Seiten (21:08–21:20 geschrieben, je ~1,1–1,5 KB, strukturvalidiert 42/42). Substanz vollständig im Repo gespiegelt: 6 korrigierte Fassungen + MNT-004-Neufassung in `docs/ops/mnt_page_updates_2026-07-28/`, 10 Volltexte im Runde-4-Brief, 4 Volltexte im Runde-3-Brief, alle übrigen in Problem/Lösung/Kritik-Form im Review (unten) und im Konvergenz-Ledger.
- `MNT-043` … `MNT-046` — Claude-Seiten; **superseded** durch die konvergierten Fassungen in `docs/ops/mnt_page_updates_2026-07-28/MNT-043..046.md` (Repo = aktueller Stand).
- `Review Claude 2026-07-28.md` — unten verbatim gesichert.
- `Konvergenz-Ledger.md` — wurde nie in den Vault geschrieben (G: fiel vorher); kanonisch im Repo: `docs/ops/MNT_CONVERGENCE_LEDGER.md`.
- `_HOME.md` — enthält seit 28.07. Zeile 87 den Maintenance-Link (eine Zeile, trivial wiederherstellbar).

---

## Verbatim-Sicherung 1: `Maintenance/Offene Punkte.md` (Endstand 28.07.)

# Maintenance — Offene Punkte

> **Stand:** 2026-07-28 · **Status:** 46 PUNKTE OFFEN · **Lösungsideen:** MNT-001–042 von **Codex** (read-only Factory-/Vault-Audit 28.07.2026), MNT-043–046 von **Claude** (Review-Audit 28.07.2026). Die Seiten sind Vorschläge und keine Ausführungs- oder OWNER-Freigabe.
>
> **Review:** [[Review Claude 2026-07-28]] — 8-Agenten-Verifikation der Faktenbehauptungen (fast alle exakt bestätigt), Kommentare zu den Lösungen, Root-Cause-Korrekturen (u. a. MNT-001/002/017/018/019/040) und Prioritätsvorschläge. Wichtigster Querschnittsbefund: 13128/NDX (live) steht auf ungeprüfter Q07-Evidenz → [[MNT-044 Q06-Q07-Altlast re-adjudizieren]].

Diese Seite ist das zentrale Maintenance-Ledger. `P0` schützt Live-Betrieb oder Evidenzintegrität, `P1` stellt Factory- und Gate-Verlässlichkeit wieder her, `P2` beseitigt Governance-, Dokumentations- und Kapazitätsschulden.

## P0 — zuerst schließen

- [ ] [[MNT-001 Live KS-Baselines wieder aktivieren]] — 0/24 Sleeves mit gültig geladener Baseline.
- [ ] [[MNT-002 Live-Supervisor und Task-Contract reparieren]] — Supervisor stale, Relaunch-Kette wirkungslos.
- [ ] [[MNT-003 Interaktive Scheduled Tasks stabilisieren]] — sieben Tasks mit `0x800710E0`.
- [ ] [[MNT-004 FTMO-Monitoring park-aware machen]] — absichtlich geparkter Terminal erzeugt Daueralarme.
- [ ] [[MNT-005 Legacy-Q02-Reaper progress-aware machen]] — laufende Tests werden trotz Fortschritt beendet.
- [ ] [[MNT-006 Q02-Stranding und Health-Semantik korrigieren]] — 221 echte infra-only Paare; Health zählt valide Zero-/Invalid-Fälle falsch.
- [ ] [[MNT-007 Infra-Graveyards Q03 bis Q08 aufarbeiten]] — besonders großer ungeklärter Q04-Bestand.
- [ ] [[MNT-043 Flottenweite Recompile-Schuld begleichen]] — 96 % der Factory-Binaries älter als die Fix-Welle; Live-Halt-Kanal tot. *(Claude)*
- [ ] [[MNT-044 Q06-Q07-Altlast re-adjudizieren]] — 43 % der Q07-PASS ohne Evidenzdatei; 13128/1567 live auf ungeprüfter Evidenz. *(Claude)*

## P1 — Factory und Gates verlässlich machen

- [ ] [[MNT-008 NO_HISTORY-Restbestand schließen]] — 35 Paare ohne reales Resultat und ohne Nachfolger.
- [ ] [[MNT-009 Null-Verdicts und Evidence-Bindung bereinigen]] — 832 terminale Null-Verdicts; 109 frische INFRA-Zeilen ohne kanonischen Evidence-Pfad.
- [ ] [[MNT-010 Logische Backtest-Task-Zombies schließen]] — Parent-Tasks bleiben pending, obwohl Kinder terminal sind.
- [ ] [[MNT-037 Safe-Defer darf nicht PASS werden]] — aufgeschobene Reparaturen können fälschlich als bestanden erscheinen.
- [ ] [[MNT-011 Repo-Dirty-Guard dauerhaft entkoppeln]] — generierte/ungetrackte Dateien blockieren Builds.
- [ ] [[MNT-012 Buildtask-Zombies und R3-Widersprüche schließen]] — zwei unbaubare Tasks blockieren; ein gebauter Task hängt im falschen Zustand.
- [ ] [[MNT-013 Approved-Card-Buildbacklog kontrolliert abbauen]] — 445 Cards warten auf Build oder Auto-Build.
- [ ] [[MNT-039 Agent-Task-Limbo bereinigen]] — rund 509 alte RECYCLE-, Pipeline- und Approved-Kontexte ohne klare Disposition.
- [ ] [[MNT-014 RECYCLE-Backlog nach Disposition auflösen]] — kein pauschales `RECYCLE -> TODO`.
- [ ] [[MNT-015 Wiederholte Nullsignal-Events deduplizieren]] — tausende identische Events ohne neue Information.
- [ ] [[MNT-016 Verdict-Metadaten und Taxonomie säubern]] — alte Failure-Felder kontaminieren spätere PASS/FAIL/ZERO-Verläufe.
- [ ] [[MNT-017 Q05-Q06 Stress-Provenance authentifizieren]] — 14 verdächtig identische Stressläufe ohne Hash-Bindung.
- [ ] [[MNT-018 Q07 Seed-Authentifizierung reparieren]] — effektiver Seed ist mindestens einmal nicht nachgewiesen.
- [ ] [[MNT-019 T5 mit einer echten A-B-Probe diagnostizieren]] — T5-spezifische Ursache ist nicht belegt.
- [ ] [[MNT-020 BarsCalculated-first Kohorte reparieren]] — terminalübergreifender Implementationsverdacht bei 30 EAs.
- [ ] [[MNT-038 Adaptive Symbol-Fanout Stopregeln]] — deterministische Fehler fächern unnötig auf ganze Symbolkohorten auf.
- [ ] [[MNT-021 Q12- und Live-Kandidatenregister reconciliieren]] — Live-, Ready-, Stale- und Missing-Zustände widersprechen sich.
- [ ] [[MNT-022 FTMO Step-2 und Trial-Gates abschließen]] — Fidelity, Slotwahl, Joint Replay, Estimator und Governor-Parität offen.
- [ ] [[MNT-023 DXZ Next-Book-Trigger messbar machen]] — „significantly better" besitzt keinen numerischen Vertrag.
- [ ] [[MNT-045 Tester-Kalenderabhängigkeit entschärfen]] — 86 % der EAs tester-hart am News-Seed; OWNER-Semantikentscheidung offen. *(Claude)*
- [ ] [[MNT-046 Factory_OFF muss Phase-Runner reapen]] — verwaiste q07/q10-Runner überleben OFF und respawnen Terminals. *(Claude)*
- [ ] [[MNT-034 Recovery-814 kontrolliert abschließen]] — Restkohorte erst nach Reaper-Fix beenden und adjudizieren.
- [ ] [[MNT-035 Health-Oberflächen zu einem Vertrag zusammenführen]] — Farm, Silent Monitor und Live Pulse widersprechen sich.
- [ ] [[MNT-040 Pipeline-Statusaggregator korrigieren]] — ältere Build-/Reviewzustände überdecken spätere Gate-Evidenz.

## P2 — Vault, Governance und Betriebshygiene

- [ ] [[MNT-024 Vault-Navigation kanonisch bereinigen]] — historische Seiten werden als aktuell indexiert.
- [ ] [[MNT-025 Gebrochene aktive Vault-Pfade korrigieren]] — Prompts referenzieren nicht existierende G0-/P1-/Open-Items-Seiten.
- [ ] [[MNT-026 Dedup-Checks fail-closed und UTF-8-fest machen]] — falscher Vault-Pfad kann False-CLEAN erzeugen.
- [ ] [[MNT-027 Gate-Dokumentation Q01-Q10 synchronisieren]] — Vault-Regeln widersprechen ratifizierten Decisions.
- [ ] [[MNT-028 Company-Manifest und Vault-Linter erneuern]] — Manifest vom Mai, 31 gebrochene Links, wichtige Checks deaktiviert.
- [ ] [[MNT-029 Owner-Decisions und Morning Brief frisch halten]] — Cockpit-Feed ist stale und wiederholt überholte Punkte.
- [ ] [[MNT-030 agy-Mailbox- und Source-Lane wiederherstellen]] — Heartbeats stale, Source-Pool auf sieben gefallen.
- [ ] [[MNT-031 Repo-Worktree- und Integrationswahrheit klären]] — Kanon, Agent-Branch und `origin/main` driften stark.
- [ ] [[MNT-032 Disk-RAM- und Cache-Purge robuster machen]] — geringe Reserve und unklare Reclaim-Telemetrie.
- [ ] [[MNT-033 Messbares Milestone-Ledger einführen]] — Owner, Akzeptanz, Ist, Evidenz und Distanz fehlen.
- [ ] [[MNT-041 T5-Kapazität sichtbar machen]] — 9/9 enabled verbirgt den zehnten, deaktivierten Designslot.
- [ ] [[MNT-036 Probation Review 2026-08-24 vorbereiten]] — feste Review-Evidenz für 1556, 10706 und 13128 vorbereiten.
- [ ] [[MNT-042 Quartals-Re-Q08 2026-10-01 vorbereiten]] — Scope, Inputs und Compute für den festen Wiederprüfungstermin einfrieren.

## Pflegevertrag

1. Eine Seite wird nur geschlossen, wenn ihre Akzeptanzkriterien mit dauerhafter Evidenz erfüllt sind.
2. Jede Zustandsänderung verlinkt den ausführenden Task, Commit, Report und die relevante OWNER-Entscheidung.
3. Runtime/Filesystem/SQLite bleiben gegenüber diesem Vault die höhere Wahrheit.
4. Neue Befunde erhalten eine neue `MNT-NNN`-Seite; bestehende Befunde werden nicht still umgedeutet.

---

## Verbatim-Sicherung 2: `Maintenance/Review Claude 2026-07-28.md`

*(Vollständiger Inhalt — siehe auch die daraus abgeleiteten, weiterentwickelten Artefakte: `MNT_CONVERGENCE_LEDGER.md` und die Runde-1-Briefkorrekturen, die den Review-Inhalt in aktualisierter Form tragen.)*

**Gesamturteil:** Codex' Audit substantiell exzellent; fast alle Zahlenbehauptungen exakt reproduziert (832 Null-Verdicts, 42 Parent-Zombies, 509=433+61+15, 445 Cards, 21 Event-EAs, 35 NO_HISTORY-Paare, 7 Tasks 1:1, KS 0/24 = 9/4/11, BarsCalculated 30/28/23, Q12-Register 17/2/3). Schwächen systematisch: Symptom korrekt, Root Cause teils verfehlt (Runner- statt EA-seitig, falscher Aggregator, falsches Verzeichnispaar), gekoppelte Ausfälle als Einzeltickets, Live-Geld-Fälle untergewichtet.

**Wichtigster Einzelbefund:** QM5_13128/NDX schwächste Live-Position — gleichzeitig MNT-036-Probation, MNT-021 EVIDENCE_STALE, MNT-001 Baseline-defekt, und Q07-„PASS" = parse_error-Backfill-Stempel (work_item 37308752, nie ein Lauf). MNT-018 nannte nur QM5_1116 (nicht im Buch); 1567/EURUSD (live) ebenfalls betroffen.

**Verifikationsmatrix:** Exakt bestätigt: 001, 002, 003, 004, 007, 009, 010, 012, 013, 015(21 EAs), 016, 018(1116), 019, 020, 021, 036(Datum), 039, 040, 041. Beweglich/fensterabhängig: 006 (242/221→251/230, Delta konstant 21=18 ZT+3 INV), 008 (35 exakt bei Cold-Cache-Cap 3), 015 (3017=Kalendertag vs rollierend 5741), 039 (479 im Band 466–483). Untertrieben: 017 (18 Paare/13 EAs statt 14), 009 (Evidence-Lücke 99,4 % = 44.607/44.874, Pfade im Payload), 018 (23 Alt-PASS Varianz 0,00 + 105/243 ohne aggregate.json + 13128-Stempel).

**Kernkommentare** (vollständig in Runde-1-Brief `CODEX_BRIEF_mnt_review_corrections_2026-07-28.md` §WP-A + Minor-Folds): MNT-001 zwei divergierende Baseline-Verzeichnisse + Pulse-Lücke · MNT-002 zweiter Watchdog 666 Kicks ohne Heartbeat → Schritt 0 nötig · MNT-003 SYSTEM-Migration nicht für T_Live_AtLogon/SessionSupervisor; LogonType-Filter im Akzeptanzquery · MNT-004 Watchdog relauncht aktiv (37 fails), zweiter Beobachter ftmo_trial_pulse, QM_FTMO_AtLogon 0x2 · MNT-006/008 Invarianten statt Absolutzahlen, valid_zero→RETIRE-Spur, 446 P2-Zeilen unsichtbar · MNT-007 requeue-Tool existiert, Q04 wächst 1106→1550, Q08 35/40 invalid_report nie requeuen · MNT-009/010 Sequenz 009→010, Backfill über Gesamtkorpus · MNT-012 Cards intern widersprüchlich (Frontmatter PASS vs Body UNKNOWN), 20062-Binary im Repo-Baum · MNT-013 Begründung widerlegt (alle 445 READY) · MNT-015 Lifetime 296.667 = 92 % der events-Tabelle · MNT-016 bidirektionale Kontamination + verdict_reason auf PASS-Zeilen + INFRA-Status-Split (8377 done/44874 failed) · MNT-017 EA-seitige Root Cause (fehlende Inputs, 10440-Gegenbeispiel), retroaktiver Scope · MNT-018 fail-closed existiert (WP-10), Lücke=Altlast, unveränderte Binaries prinzipiell beweisunfähig · MNT-019 kein gültiger Kontrollarm (20096 identisch auf T2/T3/T10, 11144 ohne PASS), Verdacht QM_Indicators-Handle-Cache · MNT-020 Call-Site-Parsing (31 vs 30), TEMP DIAG vor Rebuild, 20143/20144 Infra-Triage zuerst · MNT-021 Register-Duplikate (11132 dreifach, 10715 doppelt) · MNT-036 Probation-Anker 2026-07-13 · MNT-040 Ziel farmctl pipeline_view (nicht pipeline_state.json), blind für ~94 % · MNT-041 „cap"-Misattribution + Status muss WARN treiben · MNT-031 P2 untergewichtet (origin/main 1723 hinter board-advisor).

**Kleinere Korrekturen:** MNT-027-Matrix + Q04-Kostenvertrag (DL-082) + Q08-strategy_*-Params · poison_pill_quarantine verdrahtet aber 0 Zeilen bei 53k INFRA_FAILs · claim_atomic-Starvation erledigt (claim_class_ledger) · Pump-Auto-Commits ziehen Framework-Sourcen in Artifact-Commits.

**Prioritätsvorschläge:** MNT-043/044 als P0; MNT-031 P2→P1; Ketten 003→002→004, 009→010, 043→017/018/020/044.

*(Weiterentwicklung dieses Reviews: alle Punkte wurden in den Konvergenzrunden 1–4 verhandelt und sind im Konvergenz-Ledger mit Endständen dokumentiert — das Ledger ist die aktuellere Wahrheit.)*
