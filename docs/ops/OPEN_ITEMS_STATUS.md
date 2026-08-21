# OPEN_ITEMS_STATUS — vollständiges Bild aller beauftragten Punkte

**Stand:** 2026-08-21 · Stehende Vollmacht §6 (wird jedem Bericht beigefügt)
**Eine Zeile je Punkt. „Geliefert" heißt: Ergebnis steht in einem Dokument und wurde berichtet.**

---

## 1 · Geliefert

| aus | Punkt | Ergebnis in einem Satz |
|---|---|---|
| R7 §1 | EV eines finanzierten Kontos | Break-even-Gebühr 15.555 $ bei 0,50×, auf beiden Messbasen — die erste Aussage der Serie, die die Intraday-Unsicherheit überlebt (`EV_FUNDED_ACCOUNT.md`) |
| R7 §2 | Trichterdiagnose | Q04 lässt 9,1 % durch, Q08 16,7 %; die 24 buchuntauglichen Paare sind 0 Daten- und 24 Frequenzausfälle (`FUNNEL_DIAGNOSIS.md`) |
| R7 §5 | Optimizer-Retarget | Der DD-Hebel ist nicht leer, sondern steht hinter den Gates, die hohe Drawdowns entfernen (`OPTIMIZER_RETARGET.md`) |
| R7 §6.5 | DZ-Buchumfang | Das DZ-Erfolgs-KPI ist im Bestand nicht dokumentiert; drei von sechs Auditgrößen sind übertragbar (`DZ_BOOK_SCOPE.md`) |
| R8 §1 | Aktivitätskriterium, Herkunft | Die 250 ist ein undokumentierter Implementierungsfilter (600→500→250, jede Stufe zur Poolvergrößerung); ihre Korrektur bringt 8 Paare zurück und **verschlechtert** das Buch (`ACTIVITY_CRITERION.md`) |
| R8 §2 | `PASS_LOWFREQ`-Zählung | 109 Paare, null davon buchfähig, nur 4 erfüllen das 10/Jahr-Kriterium (`LOWFREQ_CENSUS.md`) |
| R8 §3 | Negativkontrolle | Entfallen — Stop-Condition-Pfad byteidentisch zum Trip vom 18.08. (`DECISIONS` D-11) |
| R8 §5.1 | Familie × Anlageklasse | Dieselben 497 EAs bestehen Q04 auf Metall mit 20,3 %, auf FX mit 3,9 % (`FAMILY_ASSET_MATRIX.md`) |
| R8 §5.4 | Live-Buch-Ist-Aufnahme | 24 Binaries, 17 emittierend, 20 Sleeves, **10 handeln**, 5 attached ohne je einen Trade (`LIVE_BOOK_INVENTORY.md`) |
| R9 §2 | Zuteilungslogik | `farmctl.py:17532` fällt auf alle 37 Registersymbole zurück (28 davon FX); 75 EAs sind so gelaufen (`ALLOCATION_SHIFT.md`) |
| R10 §1 | Gepaarte Symbolrangfolge | Nur XAUUSD ist bewiesen; GDAXI und XTIUSD fallen gepaart um die Hälfte, USDJPY steigt (`SYMBOL_RANKING_PAIRED.md`) |
| R10 §2 | Kartenherkunft | 864 Karten mit Universum, **488 davon Paar/Basket (nicht änderbar)**; und **604 von 810 Karten deklarieren < 31 Trades/Jahr** (`CARD_UNIVERSE_ORIGIN.md`) |
| R10 §3 | RECYCLE-Stau | Keine vier Wochen Zufluss — 290 nie gebaut, 117 längst gelaufen, **3 verwertbar** (`RECYCLE_BACKLOG.md`) |
| Q14 §1.1 | Inhalt `OPTIMIZER_RETARGET.md` | Berichtet; H3 fällt durch Skaleninvarianz weg, H1 wandert in die Buchkonstruktion, H2 bleibt (`OPTIMIZER_TRACK_STATUS.md`) |
| Q14 §1.2 | Unger-Filter | **Existieren nicht** als Filter — die `unger-*`-Einträge sind EAs nach seinen Vorlagen (`OPTIMIZER_TRACK_STATUS.md`) |
| Q14 §2 | 12-%-Schwelle | Steht nirgends im Code, nur als Verdikt-Text; sperrt **nicht** 25 von 25, fünf haben sie bestanden (`OPTIMIZER_TRACK_STATUS.md`) |
| Q14 §4.3 | Q09-Zerlegung | 197 s Fixkosten je Testerlauf + 0,343 s/Kalendertag; Datumsfenster-Weg scheitert um eine Größenordnung (`Q09_ACCELERATION.md`) |
| Q14 §4.5 | Schätzfehler | Faktor 7 gegen die Evidenzdoku; Zellzeit ist auslastungsabhängig (`Q09_ACCELERATION.md`) |
| Dir. §1 | Verkettungstest | Max-DD exakt rekonstruierbar (17.072,73 beidseitig), Restfehler 0,58 % im Nettogewinn (`Q09_ACCELERATION.md` §7) |
| R9 §1 / Dir. 20.08. | Aktivitätsregel ratifiziert | ≥10 Handelstage je gewertetem Jahr, Zählbasis **Eröffnungstag** (begründet), Teiljahres-Pro-rata als Vorschlag beim OWNER; Zählungen 8 (Schluss) / 10 (Eröffnung) auf der 31er-Kohorte (`ACTIVITY_CRITERION.md` §R) |
| eigener Plan #3 | Commit-Nachtzeitreihe | Nachtserie vollständig: Peak 108,2/122,6 GB 05:18 UTC bei 3,8 GB phys. frei; Admissions-Gate feuerte korrekt (Reservierungs-Logs aller Worker) — Decke wird durch **In-Flight-Wachstum** erreicht, nicht durch blinde Claims; Pagefile C: zu 97 % voll, C: nur 44 GB frei → Decken-Anhebung braucht D:-Pagefile + Reboot (Wartungsfenster-Vorlage) (`D:\QMeports\state\commit_sampler.log`, `commit_wave_snapshot_20260820_0553utc.txt`) |
| Dir. §2 | Seed-Sensitivität | **40 Zellen sind 8 Konfigurationen**; der RNG wird in Q09 nie gezogen (`SEED_SENSITIVITY.md`) |
| Dir. §1 | Kontaminationsprüfung | Timeout-Verluste 0,24–1,4 %, verschieben jede Quote < 0,5 pp, und zwar **entlastend** — die Befunde halten |
| Vollm. §8.2 | Hyonix sichern | Zip 65,2 MB, 2.742 Einträge, SHA256 `722FC306…`, off-host auf `G:\My Drive\QM_Backups\` mit Hash-Sidecar |
| — | Q09-Pilot-Abbruch aufgeklärt | Tester extern bei 98,7 % der Ticks beendet → Null-Statistik-Report; dazu Falsy-Zero-Parserbug; **2 Runner-Fixes committed (a92c0490f), Pilot als append-only Rerun `cba63d44` neu gebunden** |
| R10 §5.1 | Strategy-Files-Inventar: die eine Zahl | **~70 distinkte non-ML/non-ICT Quelltext-Kandidaten + 428 kompilierte Repo-EAs, die die Fabrik nie sah** (`STRATEGY_FILES_INVENTORY.md` §0, jetzt berichtet) |
| R9 §5.4 / R10 §5.3 | Rate je Gate + Queue-Termin | Q04 11,2/h (6h-Fenster); 9/h-Einbruch = 5 von 8 Slots auf Q07/Q08 — OWNERs Transient-These **bestätigt**; Queue-Ende ≈ 26.–27.08. |
| Vollm. §8.1 | Unger-Filter: Parameterkosten | Eingrenzung auf 1 kategorialen Parameter (feste Muster-Bänke) vorgeschlagen — Bericht 19.08. 20:00 |
| Dir. 21.08. (ULTRACODE) | Firmen-Vollaudit + CEO-Masterplan | 8-Agenten-Audit abgeschlossen (`COMPANY_AUDIT_ULTRACODE_2026-08-21.md`); Masterplan T1–T12 im Vault (`12 ToDo/00_CEO_Masterplan_2026-08-21.md`); T1 (T_Live-Authority-Falschdoku „OWNER + Claude" auf 5 Vault-Seiten) sofort korrigiert auf Kanon OWNER-only |
| Masterplan T2 | Identity-Core-Rebuild | Business Model neu (DXZ+FTMO gleichwertig), Hard-Rules-Amendments 2026-08 + Rollen-Modernisierung, Lint-Legacy-Rollen-Check mit 17-Seiten-Debt-Allowlist; Lint PASS |
| Masterplan T3 | Pipeline-Seiten-Rebuild | Q00 R1/R4 (OWNER: R4 bleibt), Q02-Kanon (Rate-Floor), Q05-Rename, **DD-Schwellen-Drift 15→25 % auf Q05/Q06/Q10 gegen Code-Kanon korrigiert**, Q06 tote Multiplikatoren raus, Q09 Zwei-Achsen, Q11 dual-book, Q14 Numerik-Pointer + Fork bei Q10 (OWNER-bestätigt); Lint PASS |
| Masterplan #2 | Fail-Soft Q05/Q06 | **GELIEFERT + AKTIV**: Band 40,3 % → T10 implementiert (Commit `47f751d1d`): Q06 `PASS_SOFT` (PF 0,95–1,00, DD<25, ≥20 Trades) advanct nach Q07; Anti-Stacking q06_soft+EDGE_SOFT terminal am Q08→Q09-Punkt; Dashboard-Chip; 83 Tests grün (Claude-nachgelaufen). Nur neue Läufe — Retro-Kohorten (15 Alt-Decke + 25 Band) = Entscheidungsschlange #6 |
| Messung 21.08. | Nebenbefund Alt-Decken-FAILs | 15 Q06- (und analoge Q05-) `dd_above_ceiling`-FAILs wurden unter der alten 15-%-Decke adjudiziert (`max=15.0` im reason); unter heutiger 25-%-Decke teils PASS → Vorschlag append-only Reruns, Entscheidungsschlange #6 |
| Dir. 21.08. | FTMO-Buch-Symbolregel | **OWNER-Ruling: mehrere EAs/Strategien pro Symbol im FTMO-Buch erlaubt** — Q11-Seite aktualisiert; Code-Drift dokumentiert: `build_book_ftmo.py` erzwingt noch `select_one_per_symbol` (Z. 95/261) → Umbau = Masterplan-T7-Arbeitspaket |
| Dir. 21.08. | Subagent-Ökonomie | OWNER: Umsetzung über Codex/Opus/Sonnet-Subagents, Fable nur Orchestrierung/Review — als Feedback-Memory verankert; T4 + Band-Messung laufen bereits so |

## 2 · Offen

| aus | Punkt | warum noch offen |
|---|---|---|
| **R9 §3** | `BOOK_CONSTRUCTION_RULES.md`: Symbol-/Klassengrenze, Stapelblindheit, Mindesthistorie | braucht die Mindesthistorie aus der Fensterlogik — rechenbar, nicht gerechnet |
| **R9 §5.1** | Watchdog-Schwelle (`MinWorkers = 8` heilt zu spät) | Vorschlag formulierbar, nicht formuliert |
| **R9 §5.2** | SQLite-Lock-Auffanglinie (OQ-22) | Diff nicht geschrieben |
| **R9 §5.3** | Live-Buch-Ist-**Manifest** (die Aufnahme steht, das Manifest fehlt) | Erzeugung aus `audit_live_book_inventory_20260819.json` |
| **Vollm./A+B** | **Q09-Kontrakt v3 (Weg A + B) — vorab genehmigt, in Arbeit** | Kontrakt-Tiefe erfasst (Seed-Statistik + full-Metriken in Adjudikation); v2-Referenz `cba63d44` läuft parallel als Validierungsanker |
| **Vollm. §8.3** | Bug #4 (Kurzhistorien-Sperre) vor Integration beheben | Vorbedingung jeder Pattern-Filter-Integration; kollidiert mit Erstjahr des Aktivitätskriteriums |
| **Vollm. §8.1** | Pattern-Filter als Q14-Hebel formal aufnehmen | braucht Hypothese + Widerlegungskriterium + Frequenzprüfung + Parameterzahl (GELB-Bedingung); Entwurf im Bericht 20:00 |
| **Q14 §3** | Episodendefinition für die Ersatzbedingung | Definition formulierbar; die Survivor-Zahl braucht die Kohorte |
| **Q14 §3.1** | EXIT_SURGERY rückwirkend auf Rendite/Drawdown | die Läufe existieren unter `D:\QM\reports\opt_track\` |
| **Q14 §4.1/4.2/4.4** | Kohortengröße, Reihenfolge vor/nach Q09, Wiederholung je Hebelklasse | §4.2 jetzt mit 2,8 h statt 26 h neu zu rechnen |
| **Q14 §5.3** | `ONINIT_FAILED`-Klasse auszählen und richtig klassifizieren | einzelne Abfrage |
| **Q14 §6** | Ertrag in verdrängten Gate-Läufen | hängt an §4.2 |
| **Q14 §7** | Overlap Optimierungsfenster gegen WF-Falten | Messung auf vorhandenen Artefakten |
| **Dir. §2** | Ursachenanalyse: korreliert `q02_full_runtime_sec` mit der Auslastung? | die Claim-Zeitstempel liegen vor |
| **Dir. §3** | Timeout → Requeue: Diff + 3 retrospektive Zeilen | Prinzip freigegeben, Diff offen |
| **aktuell** | `WALLCLOCK_CONSTANTS.md` | Belege vollständig, Dokument nicht geschrieben |
| **aktuell** | REVIEW-Rückstau: 110 agent_tasks (≈60 build_ea/agy, ≈50 review_ea/codex, seit 17./18.08.) | Batch-Review eingeplant; Intake ist nicht der Engpass (Queue-Ende ≈ 26.–28.08.), aber der Stau verletzt die Review-SLA |
| **Dir. 21.08.** | Masterplan-Rest | T1–T8, T10, T11 geliefert+reviewt (Stufe 0–2 bis auf T9). Offen: T9 (wartet auf #8 + Bug#4), MT5-Pattern-Harness-Lauf (Factory-Fenster, vor Pilot), T12-Programme. Beim OWNER: #4 Pro-Rata, #6 Retro-Reruns, #7 public-data-Holds, #8 Opt-Track v2 — kanonisch in Vault `12 ToDo/AI ToDos/OWNER.md`; Termin MNT-036 = 24.08. |
| Masterplan T8 | Pattern-Prädikate 31/32/92/100 | Repariert (Commit `014c214ad`): 3-Bar-THREE_INSIDE, FRACTAL ohne Widerspruchsklausel, QUARTER_END letzte 2 Kalendertage; 35 Tests grün, QM5_21501 kompiliert; MT5-Harness-Lauf als Folge-Messung offen |
| Masterplan T11 | public-data-Export | **Diagnose statt Fix (korrekt):** Export gesund, Publikation fail-closed hinter 2 Q02-Bypass-Holds vom 29.07.; QM5_20182-Hold = stale Orphan (Remediation belegt), QM5_20172 echt offen (DRAFT_DEFECT) → Entscheidungsschlange #7 (`evidence/2026-08-21_public_snapshot_export_repair.md`, Commit 511d85fea) |

## 3 · Entfallen

| aus | Punkt | warum |
|---|---|---|
| Q14 §0 | „Die Unger-Filter kommen hinzu" | Es gibt keine. Die Vorgabe ist gegenstandslos, §3.2 braucht echte Hebelvorschläge |
| Q14 §1.2 | Unger-Filter beschreiben: Ort, Parameter, Testergebnis, Frequenzwirkung | dito — nichts zu beschreiben |
| Q14 §3 (H3) | Sizing als Optimierungsgröße | Rendite/Drawdown ist skaleninvariant; ein Sizing-Optimierer kann den Quotienten nicht bewegen |
| Q14 §2.1 | Doppellauf zur Ausführungs-Invarianz | OWNER: nicht nötig, solange die Zielgröße nur zum Ranking dient |
| R8 §3 | Negativkontrolle Containment | Commit-Prüfung hat sie ersetzt |
| R9 §2 | Verteilung 30/30/15/25 | zurückgezogen — der Vorrat gibt maximal 15 % Metall her |
| Dir. §4.3 | Datumsfenster-Weg für Q09 | gemessen: 81 % der Tage tragen Ereignisse, Fragmentierung kostet mehr als sie spart |
| Dir. §2 (Weg B) | „3 statt 5 Seeds" | ersetzt durch „1 statt 5" — der Seed ist nachweislich wirkungslos |

## 4 · Vorgeschlagene Reihenfolge für die offenen Punkte

**Zuerst, weil billig und blockierend für anderes:**

1. **R9 §5.4** stabile Rate (ab 19:19 UTC auswertbar) → liefert die Mischrate für R10 §5.3
2. **R10 §5.1** die eine Zahl aus dem Strategy-Files-Inventar — Bericht, keine Messung
3. **Dir. §3** Timeout-Requeue-Diff + die drei retrospektiven Zeilen
4. **Q14 §5.3** `ONINIT_FAILED` auszählen — eine Abfrage

**Dann, weil sie aufeinander aufbauen:**

5. **Dir. §2** Auslastungskorrelation → entscheidet die Reparaturform
6. **`WALLCLOCK_CONSTANTS.md`** mit 3 und 5
7. **Q14 §4.2** Reihenfolge vor/nach Q09, neu mit 2,8 h
8. **Q14 §6** Ertrag in verdrängten Gate-Läufen

**Zuletzt, weil sie eine Entscheidung oder eine Kohorte brauchen:**

9. R9 §1 Aktivitätsregel, R9 §3 Konstruktionsregeln
10. Q14 §3 Episodendefinition, §3.1 EXIT_SURGERY, §7 Overlap
11. R9 §5.1 Watchdog, §5.2 SQLite-Lock, §5.3 Live-Manifest

---

**20:00 UTC:** Die beiden überfälligen Punkte (Strategy-Files-Zahl, Filtersuche) sind berichtet.
Aktive Großbaustelle ist der Q09-Kontrakt v3 (A+B, vorab genehmigt); die v2-Referenzmessung
`cba63d44` läuft parallel und wird zum Validierungsanker der v3-Entscheidungsgleichheit.
