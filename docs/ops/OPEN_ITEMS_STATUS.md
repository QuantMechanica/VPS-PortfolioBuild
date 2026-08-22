# OPEN_ITEMS_STATUS — vollständiges Bild aller beauftragten Punkte

**Stand:** 2026-08-22 · Stehende Vollmacht §6 (wird jedem Bericht beigefügt)
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
| eigener Plan #3 | Commit-Nachtzeitreihe | Nachtserie vollständig: Peak 108,2/122,6 GB 05:18 UTC bei 3,8 GB phys. frei; Admissions-Gate feuerte korrekt (Reservierungs-Logs aller Worker) — Decke wird durch **In-Flight-Wachstum** erreicht, nicht durch blinde Claims; Pagefile C: zu 97 % voll, C: nur 44 GB frei → Decken-Anhebung braucht D:-Pagefile + Reboot (Wartungsfenster-Vorlage) (`D:\QM
eports\state\commit_sampler.log`, `commit_wave_snapshot_20260820_0553utc.txt`) |
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
| **NEU 21.08.** | **Agenten-Lane stand seit 19.08. still — Ursache gefunden und behoben** | Kein Defekt: Router meldete `no_routable_task` bei **1.520 fertigen Cards**, weil 107 Tasks in REVIEW hingen, **die nur Claude schließt**. 50 review_ea adjudiziert (2 unabhängige Triage-Pässe: Defekte objektiv, Codex-Messlatte konsistent, **kein Fehlurteil**) → 44 RECYCLE / 6 BLOCKED, 47 Quell-Builds mitgezogen; REVIEW jetzt 0 review_ea (`evidence/2026-08-21_review_backlog_closeout.md`, Commit `53adcb524`) |
| **NEU 21.08.** | **agy-Bauwelle: 6 wiederkehrende Template-Defektklassen** | 101 Builds in die gemini-Lane seit 01.08., nur 18 APPROVED; 49/50 Reviews negativ. card-drift 36×, missing-loss-limits 23× (Card 2/2,5/5 % vs. Framework-Default 3.0/0.0), Management-unerreichbar ~20×, broker-time, pip-×10-Doppelkonversion, build-identity — **und 11 Reviews auf Builds, deren strict build_check schon FAIL war**. Hebel = mechanische Build-Gates (Codex `57faa292`), nicht mehr Review; 6 unmechanisierbare Cards → agy `471cffc3` (nur Kartentext, Stilllegung ist erlaubtes Ergebnis) |
| Dir. 21.08. | Subagent-Ökonomie | OWNER: Umsetzung über Codex/Opus/Sonnet-Subagents, Fable nur Orchestrierung/Review — als Feedback-Memory verankert; T4 + Band-Messung laufen bereits so |
| **OWNER 21.08.** | **Orchestrator-Mandat in `CLAUDE.md` verdrahtet** | Rollenzeile nennt jetzt Orchestrator; neuer Abschnitt „Orchestrator Mandate": Claude-ToDos selbst erledigen, Codex-/Antigravity-ToDos **beauftragen**, Routing nach Fähigkeit, Taktung gegen die 5h-/Wochenlimits aller drei Sitze, `review_ea` als exklusive Claude-Pflicht, und die bindende Regel **„ein offener Punkt ohne Router-Task ist nicht beauftragt, sondern nur notiert"**. Session-Start-Regel auf alle vier ToDo-Boards erweitert (Commits `0f352e0ec`, `c85a46b18`) |
| **OWNER 21.08.** | `OWNER-DEC-GATEMANIFEST-Q05` umgesetzt | Q05 heißt im Maschinen-Contract „Gross Full-History Robustness"; Gate-ID, Kriterien, `P*`-Keys, `legacy_aliases` unberührt, v1-Manifest bleibt eingefroren. Der v1/v2-Paritätstest vergleicht jetzt **Topologie** und führt die eine erlaubte Umbenennung namentlich auf — eine unautorisierte Umbenennung eines anderen Gates fällt weiter durch (Commit `5af55bfbf`, 11 Tests grün) |
| **OWNER 21.08.** | `OWNER-DEC-FTMO-SYMBOLPOLICY` beauftragt | Task `9bdfde03`. **Auflage:** der Symbol-Cap wird nicht ersatzlos gestrichen — er ist heute die einzige Konzentrationskontrolle des Builders; die Aggregat-Kontrolle (Korrelation/Cluster + kontoweites Budget) muss ihn **ersetzen**, jedes ausgeschlossene Paar behält einen expliziten Grund, nicht ratifizierte Schwellen werden vorgelegt statt erfunden |
| **NEU 21.08.** | Entscheidungsfläche entrümpelt | `12 ToDo/AI ToDos/OWNER.md` zeigt nur noch Offenes; neun entschiedene Punkte nach `AI ToDos/Archive/Entscheidungen 2026-08-21` verschoben (Archiv heißt erledigt, nicht ungültig). Neu offen dort: `OWNER-DEC-MNT022-INTENT` — der ausgeführte Auftrag meldet, das Ticket sei früher als *bewusst nicht beauftragt* geführt worden |

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
| **Dir. 21.08.** | Masterplan-Rest | T1–T8, T10, T11 geliefert+reviewt. **Alle 5 OWNER-Entscheidungen am 21.08. getroffen und vollzogen** (#4 Pro-Rata `e116d503c`, #6 12 Reruns `a616d3e66`, #7 Hold-Release `51fef5956`, #8 ADR `DL-088`/`b855323a8`, PUBFIELDS konservativ). Offen: T9 (Bug#4 + Fixture-Harness), T12-Programme. Termin MNT-036 = **06.09.** (OWNER-Verschiebung) |
| Masterplan T8 | Pattern-Prädikate 31/32/92/100 | Repariert (Commit `014c214ad`): 3-Bar-THREE_INSIDE, FRACTAL ohne Widerspruchsklausel, QUARTER_END letzte 2 Kalendertage; 35 Tests grün, QM5_21501 kompiliert; MT5-Harness-Lauf als Folge-Messung offen |
| **NEU 21.08.** | **Maintenance-Ledger ist-geprüft und beauftragt** | 46 Punkte gegen den Live-Zustand nachgemessen: **17 erledigt, 2 überholt, 16 teilweise, 11 offen** — ein Drittel war schon abgearbeitet (NO_HISTORY 35→0, Nullsignal-Events ~3017/Tag→3, Seed-Auth 0/69, T5 zurück). **15 Router-Tasks** an Codex/Antigravity dispatcht, 8 bei Claude, 4 beim OWNER. ★Strukturbefund: **kein einziger Router-Task trug je eine `QM-TODO`-ID** — Vault-Häkchen und Fabrik-Aufträge waren getrennte Welten; ab jetzt trägt jeder Task seine ID und jede ToDo-Zeile ihre Task-ID (`evidence/2026-08-21_maintenance_ledger_reverification_and_dispatch.md`) |
| **NEU 21.08.** | **275 `q02_stranded_exhausted_pairs`** | Q02/P2-Paare ohne nicht-infra terminale Disposition, ohne Nachfolger, ≥ 12 Versuche — dieselbe Klasse wie die vier heute befreiten EAs (still gestorben, niemandem aufgefallen). Noch nicht bearbeitet; braucht eine eigene Triage-Welle |
| **NEU 21.08.** | Health-Signal `pump_task_lastresult` FAIL, obwohl der Pump arbeitet | Exit-Code 2147946720 bei laufendem Dispatch (8 aktive Rows, 3–5 Completions/h). Log enthält nur die Python-Zeile „Could not find platform independent libraries <prefix>" → PS-stderr-Trap-Klasse. **Gefahr: ein echter Pump-Ausfall wäre in diesem Dauer-FAIL nicht unterscheidbar** |
| **NEU 21.08.** | `pending_artifact_binding_drift` = 12 (CONTENT_CHANGED, 8 Rows) | Vermutlich Folge der laufenden Codex-Arbeit an `QM_PatternPermission.mqh` (Bug #4, unkommittierte Quelle). **Nach dem Codex-Commit erneut prüfen** — Bindungsdrift kann sonst gesunde Läufe verwerfen |
| **NEU 21.08.** | Rest-Aufräumung hinter dem REVIEW-Stau | 556 RECYCLE bleiben **absichtlich** liegen, bis die Build-Gates stehen (sonst 556 Rebuilds mit denselben 6 Defektklassen); 10 build_ea noch in REVIEW; APPROVED-Limbo in Arbeit |
| **NEU 21.08. (P1)** | **Agent-Capabilities flattern zwischen Checkouts** | `sync_default_registry` überschreibt `agent_registry` bedingungslos, und **mehrere Checkouts** laufen: `C:/QM/repo` schreibt den breiten Satz, `codex-orchestration-1`/`gemini-orchestration-1` den alten schmalen. Gemessen: schmal 12:48:25Z, breit 12:53:40Z, dieselbe DB. **In jedem schmalen Fenster kann die Claude-Lane keinen `ops_issue` annehmen (kein `ops`) und agy keine Video-Analyse (kein `video_analysis`)** — beides still, eine nicht routbare Aufgabe sieht aus wie Rückstau. Beauftragt: Task `cd982cfc` mit Ursache im Payload (`evidence/2026-08-21_agent_registry_capability_flapping.md`) |
| **NEU 21.08.** | Test `test_real_a02_compile_manifest_loads_when_present` schlägt fehl | `ContractError: compile manifest FACTORY_OFF binding drifted` — der Test bindet ein reales Compile-Manifest an die SHA von `FACTORY_OFF.flag`; die Datei existiert bei laufender Fabrik nicht. **Umgebungsabhängiger Test, nicht durch die Q05-Umbenennung verursacht** (660 andere Tests grün). Er schlägt fehl, sobald die Fabrik läuft — d. h. im Normalbetrieb. Braucht eine Entscheidung: Fixture statt Live-Bindung, oder Skip mit Begründung |
| **NEU 21.08.** | `HARNESS_PP_FIXTURE` = 1 pending | Der ausstehende MT5-Fixture-Harness-Lauf für die Pattern-Prädikate steht als Work-Item in der Queue (Masterplan T8, Folge-Messung zu `014c214ad`) — er ist eingereiht, nicht vergessen |
| **NEU 21.08. (QM5_41095)** | WTI Excursion-Imbalance: Q01-Compile + Q02 offen | Nicht-duplizierter source-only Build `b74533ddb`, 12/12 Referenztests und Guardrails PASS; governed compile `c88b39a4-1220-4894-a2c3-9818651c763e` wartet unter `COMPILE_EA_WORKER_ROLLOUT_PENDING`. Q02 blieb ohne Enqueue, weil Q01 noch kein PASS hat und die frische CPU-Serie bis 100% die 97%-Decke überschritt (`2026-08-21_qm5_41095_wti_weekly_excursion_imbalance_source_build_cpu_stop.md`). |
| **NEU 22.08. (QM5_41101)** | XNG Range-Migration: Q01-Compile + Q02 offen | Nicht-duplizierter source-only Build `b2a34ae5f`, 11/11 Referenztests und Guardrails PASS; governed compile `97095c29-b534-4e4c-baf8-aa8d382225eb` wartet unter `COMPILE_EA_WORKER_ROLLOUT_PENDING`. CPU blieb mit max. 93,53% unter der 97%-Decke; Q02 blieb ausschließlich mangels EX5/Q01-PASS ohne Enqueue (`evidence/2026-08-22_qm5_41101_xng_weekly_range_migration_compile_handoff.md`). |
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

## Nachtrag 2026-08-21 · Ultracode-Welle 1 — Codex-Board durch Claude abgearbeitet (Quota-Schonung, OWNER-Auftrag)

| aus | Punkt | Ergebnis in einem Satz |
|---|---|---|
| MNT-009 | Runner-Completion atomar | Fail-closed DB-Trigger + EVIDENCE_UNAVAILABLE-Sentinel live in farm_state.sqlite, 24 Tests grün (b1f959027; Evidenz `2026-08-21_mnt009_infra_fail_evidence_binding.md`) |
| MNT-003 | 0x800710E0-Oszillation | Als benigner IgnoreNew-Overlap bewiesen; Monitore adjudizieren nach Principal/Code, 267014 alarmiert weiter, Task-XML unangetastet (19ae99a42 + e62de0f9e) |
| MNT-026 | Dedup nie CLEAN bei kaputtem Input | Drei fail-closed-Tests gepinnt, 13108-Recheck reproduziert DUPLICATE (e45a42e08, Re-Verifikation 8812cc62a) |
| MNT-012 | R3-Frontmatter 1457/1459 | Beide Karten stimmen auf evidenziertes UNKNOWN überein (Serien fehlen in dwx_symbol_matrix.csv) |
| TODO-201 | Qxx-only Health-Texte | Displaytexte bereinigt, Echo-Sidecar zurückgesetzt, Heartbeat sauber, Vault-Lint PASS (299727da5) |
| TODO-202 | pipeline_state.json | REAKTIVIERT: frischer Snapshot + stündlicher Task `QM_StrategyFarm_PipelineState` (rc=0), vom fail-closed Public-Guard entkoppelt (b9d91741e) |
| TODO-203 | Symbol-List-Seite generieren | Deterministischer Generator + Drift-Test, Seite auf 37 Symbole inkl. SP500; Folgepunkt: `company_manifest.json`-Symbolblock driftet weiter (769d09e6e) |

Alle 7 Router-Tasks APPROVED geschlossen; adversariale Verify-Agents je Task = PASS. Verbleibend auf dem Codex-Board: die Architektur-Brocken MNT-011/-038/-030/-016/-031/-032/-035 und die blockierten -020/-006/-013/-039.

## Nachtrag 2026-08-21 (abends) · Ultracode-Wellen 2/2b/3 — kompletter Maintenance-Ledger reviewt und geschlossen

| aus | Punkt | Ergebnis in einem Satz |
|---|---|---|
| MNT-011 | Dirty-Guard entkoppelt | Doppelreview APPROVED: strukturelle Generated-Klassifikation fail-closed (bfce1fa3a), Pump-Blocking 165→6; Spawn-Beobachtung im generated-only-Fenster folgt beim nächsten natürlich sauberen Baum |
| MNT-038 | Canary-vor-Fanout | Codex-Lieferung + Claude-Härtung nach Review-Bounce: Cross-Asset-Null-Bestätigung, K=3-Infra-Bestätigung, STOPPED-Revival; adversarial APPROVE, live via SweepEnqueue_Hourly (`2026-08-21_mnt038_canary_gate_hardening.md`) |
| MNT-016 | Verdikt-Taxonomie | Abgeleitete ro-TEMP-View, Basisrows byte-intakt, Invariante 0 Verletzungen über 110k Rows, Dashboards lesen die View — APPROVED |
| MNT-032 | Headroom-Governor | Echt gemessener Disk/RAM/Commit-Headroom, drosselt nur Spawns, fail-closed, unplausibler Reclaim → TELEMETRY_ERROR — APPROVED |
| MNT-035 | Ein Health-Vertrag | qm.health.contract.v1 über alle Wächter, 7 Widersprüche als grüne Fixtures, komponiert mit MNT-003 — APPROVED |
| MNT-031 | Worktree-Vertrag | 8 Klauseln + gemessenes 59-Worktree-Inventar, reine Doku/Tooling — APPROVED |
| MNT-013 | Card-Buckets | 365 Karten in benannten Buckets (324/33/8), Summen exakt, kein Sammelbau — APPROVED |
| MNT-030 | Source-Ingestion | Prämisse hielt nicht (gemessen): Pool 12 pending, SLOs getrennt, Intake sauber — APPROVED als Premise-Check |
| MNT-039 | Limbo-Sweeper | PIPELINE-Klasse geliefert (13→BLOCKED, 1 echter Q10-Passer→PASSED, idempotent); Rest kommissioniert als `1d8e74a0` |
| MNT-020 | BarsCalculated-Kohorte | Source-Repair + D6-Linter APPROVED; QM5_20096-Runtime-Beweis kommissioniert als `c010ccb7`, wartet auf OWNER (ROT-Recompile) |
| MNT-006 | 275 Stranded-Paare | Alle 275 klassifiziert+disponiert (bit-identisch reproduziert); Drain kommissioniert als `7333402c`, wartet auf MNT-038-Aktivierung + OWNER |

**Entscheidungsschlange (2):** `OWNER-DEC-MNT020-RECOMPILE` (QM5_20096-Rebuild freigeben) · `OWNER-DEC-MNT006-CANARY` (10-Zeilen-Drain freigeben) — beide in `12 ToDo/AI ToDos/OWNER.md` mit Empfehlung + Cost of Wait.
**Cleanup-Batch:** 5 Review-Notizen als Router-Task `db470d0a` (P40). Das Codex-Board steht auf 18/18 erledigt; der Maintenance-Ledger vom 28.07. ist damit vollständig disponiert.

## Nachtrag 2026-08-21 (spät) · Wellen 4+5 — Programme 002/003/004 geliefert, OWNER-Freigaben ausgeführt

| aus | Punkt | Ergebnis in einem Satz |
|---|---|---|
| TODO-002 | MC-v2-Datenvertrag | `qm.mission_control.v2` + read-only Emitter (Preview-JSON live validiert, exakte DB-Spot-Checks); Renderer = separater Claude-Design-Schritt (`MISSION_CONTROL_V2_DATA_CONTRACT.md`) |
| TODO-003 | Website-Archiv-Vertrag | Staging-only redigierter Vertrag EA→Card→Gate→Report; Security-Verify fing 2334 Pfad- + 5 Mail-Leaks → Redaktion gehärtet (inkl. Hyonix/Dropbox-Token), Re-Scan 0 Treffer über alle Klassen (`WEBSITE_STRATEGY_ARCHIVE_CONTRACT.md`) |
| TODO-004 | Dateisystem-Inventar | Read-only Dry-Run-Tool, T_Live hard-skip; Befunde: 31 SQLite-State-Backups ohne Hash-Sidecar, 244GB unknown→Review (`2026-08-21_filesystem_inventory_dryrun.md`) |
| MNT-020-Beweis | QM5_20096 | Rebuild a343d30a→531e8e75 (0/0), EIN append-only Q02-Canary `256846e2` auf USDCHF; Adjudikationsregel im Close-Verdikt (SHA-Match, zero-trades-alone nie PASS) |
| MNT-006 Phase 1 | 275er-Drain | 2 Row-1-Canaries enqueued (`cc347183` XAUUSD/ONINIT nach Pin-Screen, `6384b2f7` NDX/NO_HISTORY); 3 Klassen regelkonform blockiert (2× identity_mismatch, 1× LOG_BOMB repair_first); Phase 2 = Task `626975ca` |

Beide OWNER-Freigaben (MNT020-RECOMPILE, MNT006-CANARY) sind ausgeführt und im Archiv + owner_decisions.json verbucht. Codex-Board: 21/21 erledigt, 0 offen.

## Nachtrag 2026-08-21 (Nacht) · Neues Zwischenziel „Pipeline leerlaufen", REVIEW-Stau auf 0, Videolane an OWNER

| aus | Punkt | Ergebnis in einem Satz |
|---|---|---|
| **OWNER 21.08.** | **Zwischenziel: erst leerlaufen, dann Buch** | Verankert in `Current Objective` (Zwischenziel-Block) + neues Vault-Programm `12 ToDo/10_Pipeline_Leerlauf`; testbare Definition D1–D5, Census, Wellenplan (`evidence/2026-08-21_pipeline_drain_census_and_programme.md`) |
| Census D1 | **1 470 aktive EA-IDs haben nie ein Gate gesehen** | 963 ohne Verzeichnis, 8 ohne Quelle, 195 Quelle-nie-kompiliert, **304 mit fertiger `.ex5` und null Work-Items** — der teure Teil bezahlt, der billige nie gemacht |
| Census D2 | **1 185 Paare ohne je ein Verdikt** | `failed` auf Infra-Klasse **und** nie ein `done` am selben Gate: Q02 1 010 · Q04 127 · Q07 20 · Q05 16 · Q06 5 · P2 4 · Q03 3 — keine Fehlschläge, **Abwesenheiten** |
| Census D3 | RECYCLE-Klassifikation | Von 384 scheinbar bearbeitbaren Zeilen waren **113 (29 %) längst durch** (EA später gebaut, `done`-Work-Items). Bulk-Requeue hätte 113 Builds umsonst gefahren — Preis der Bulk-Variante ist mit Recovery-814 gemessen (122,4 h für 30,2 % PASS) |
| Welle 1 | angewandt | `reconcile-exits --state APPROVED` (39), 113 veraltete RECYCLE-Zeilen → PASSED mit Begründung, 25 echt ungebaute → TODO. **RECYCLE 567 → 429**, kein Verdikt überschrieben, alles über den Transition-Ledger reversibel |
| **Review-Pflicht** | **REVIEW-Stau 28 → 0** | Alle 28 Zeilen an einem Tag geschlossen: 3 `review_ea` APPROVED, 3 RECYCLE (11533 vier Blocker inkl. Spread-Guard, der den Karten-Exit unterdrückt; 11537 H1-Vertrag; 41002 zwei strict-`build_check`-FAILs), 17 `ops_issue` + 3 `build_ea` + 2 `research_strategy` adjudiziert |
| Beauftragt | 8 Router-Tasks | Codex `4fa07877` Drain-Engine · `a3ba2414` 304 einschleusen · `b2bf2460` DL-089 Batch 2 · `e7cc7b8a` 195 kompilieren · `5c73b39f` Health-Manifest · `8c685237` retirete Karten · `46afeb2b` Phasen-SLO; Claude `6ea89ca8` review_ea 11657 |
| **Videolane** | **an OWNER übergeben** | agy ist video-blind (3× verifiziert, VPS-IP YouTube-blockiert — heute erneut belegt); Liste bewusst **kurz und abschlussorientiert**: 3 XAG-Videos (Revisit-Bedingung eingetreten, QM5_13018 Q04 FAIL 19.07.), 6 Mulham-Videos geparkt bis 13209/13212 ein echtes Q02-Verdikt haben (`12 ToDo/AI ToDos/OWNER Videoanalysen`) |

## Nachtrag 2026-08-21 (Nacht, 2) · Videolane verdrahtet, D1 entschieden, REVIEW 47 → 0

| aus | Punkt | Ergebnis in einem Satz |
|---|---|---|
| **OWNER 21.08.** | **OWNER ist Assignee der `video_analysis`-Lane** | Neue `owner`-Lane **deklariert aber abgeschaltet** (`enabled=false`, `max_parallel=0`); `HUMAN_LANES` + sichtbarer Halt `awaiting_human_lane:owner` mit Payload-Marker und Event, gemeldet **vor** `no_available_agent`; Halt eng gefasst (nur wer die menschlich gehaltene Fähigkeit braucht); kein Head-Block, Queue-Alter und Priorität unberührt; 29 Router-Tests, Live-Beweis Ticket `4b52f1b2` (Commit `bac260780`) |
| **OWNER 21.08.** | **„Die 102 gehören in die Pipeline zum Kompilieren"** | Ursache belegt: `compile_one.ps1` spiegelt den Include-Baum in **jedes** materialisierte Terminalprofil → jeder Ad-hoc-`build_check` rennt gegen laufende Terminals (2× bestätigt, 2 Terminals, 2 Dateien). ★Wichtig: die Race ist **probabilistisch**, nicht hart — dieselben Tage bauen andere Builds erfolgreich, d. h. bei 102 EAs gäbe es Teilerfolg mit Zufallsausfällen und halbgeschriebene Include-Bäume. Beauftragt als `251b9724`: Phase `COMPILE_EA` nach dem `HARNESS_PP_FIXTURE`-Präzedenzfall, ein globaler Mirror-Mutex, Spiegelung nur bei beanspruchtem Terminal (sonst aufgeschoben), **atomarer Per-Datei-Replace**, und Ad-hoc-Compile **verweigert fail-loud** statt zu rennen |
| **D1** | **Alle 963 nie gegateten EA-IDs entschieden** | 759 RETIRE · 191 ADJUDICATE · 8 INVESTIGATE · 5 RECHECK, je mit Grund (`2026-08-21_ea_id_disposition_963.csv`). **D1-Unbekannt 963 → 204.** ★Falle: IDs werden nach Ablehnung **wiederverwendet** (QM5_1136 = `qp-option-exp-sp500` in der Registry, aber `index-close-auction-intraday-momentum` im Rejected-Pool), mehrere mit Magic-Zeilen (1156: 15) → Bulk-Retire hätte die Kollisionsklasse vom 15.08. reproduziert. **Nur stilllegen, wenn der Registry-Slug noch passt.** ★Ausführung blockiert: `farmctl` hat **gar keinen** Retire-Übergang — genau deshalb tragen 446 abgelehnte Karten weiter `active`; beauftragt als `62018dcc` |
| **Review-Pflicht** | **REVIEW 47 → 0** | 44 + 3 + 1 geschlossen. ★**8 von 14 gemini-Builds durchgefallen** auf 5 wiederkehrenden Klassen (MAE-Hook 3×, Framework-Series 2×, doppeltes New-Bar-Gate 2×, uninitialisierter Request 2×, Kartendivergenz 3×) — **keine davon fangen die heute gelandeten D1–D6-Gates** → Gate-Lücke, beauftragt als `19aa9da2` |
| Eigene Messung | **QM5_12923: SPEC deklariert 9 Symbole, es existieren 5 Setfiles** | NDX, UK100, WS30, XAUUSD deklariert und untestbar — stille Verengung; der Code-Review war sauber, recycled wird nur für den SPEC/Sets-Abgleich |
| Eigene Messung | **3 Claude-Lane-Builds waren hohl** | Der Router verweigerte APPROVED mit `artifact_missing`; nachgeprüft: kein `SPEC.md`, kein `sets/`, bei 12931/12932 **nicht einmal eine `.ex5`** — Verdikt beschrieb fertige Arbeit, das Verzeichnis enthielt sie nicht. Gleiche Klasse wie der 28.05.-Befund, gleiche Härte wie bei gemini |
| Klasse | **Builds stoppen auf fehlende Magic-Zeilen, aber niemand alloziert** | 11899 und 12946 an einem Tag, beide **ohne Mutation** gestoppt (korrekt) — Precheck erkennt, Allokation fehlt; beauftragt als `f1a93a6c` |
| D1-Karten | **Welle 1: 25/25 REJECTED — Rate geprüft, hält** | Gründe kartenspezifisch, R4=0 (kein Padding), 3 Duplikate bereits freigegebener Primitive. ★**Meine Rubrik war unvollständig:** `471cffc3` hat am selben Tag 4 von 6 Karten **re-spezifiziert** statt abzulehnen. R2-only + zitierbare Quelle = reparierbar. Welle 2 (`3fb70df8`) hat RESPECIFY als drittes Ergebnis; die drei R2-only-Karten aus Welle 1 (11924/11926/11927) bekommen einen Versuch |

**Ehrlich zur Zahl:** RECYCLE ist von 429 auf **450** gestiegen, nicht gefallen. Das ist erwartet — die Reviews haben 21 Builds als defekt terminiert, statt sie unentschieden liegen zu lassen. Der Drain verschiebt Arbeit zuerst von „unbekannt" nach „bekannt defekt"; das ist Fortschritt in der Klassifikation, auch wenn der Zähler steigt.

**Offen und benannt:** (1) die Review-Lane ist die Decke des Drain-Programms — 268 Rebuilds ≈ zehn Review-Sitzungen; (2) Q09_NEWS steht weiter bei **0 PASS**, Volumen staut sich dahinter; (3) Prioritätsboden: RECYCLE-Build-Zeilen tragen p1–15 und würden nie gezogen, der Requeue normalisiert auf 50 — ob Drain vor Neu-Builds rangiert, ist eine bewusste Reihenfolge-Entscheidung; (4) drei neue OWNER-Entscheidungen auf der Decision-Surface (`OWNER-DEC-GATECONTRACT`, `OWNER-DEC-EVIDENCE-RETENTION`, `OWNER-DEC-FTMO-THRESHOLDS`).
