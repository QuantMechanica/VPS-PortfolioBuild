# OWNER-Vorlage 2026-09-05 — FTMO Positive-Evidence-Abnahmetest (Revision R4)

Status: PENDING (OWNER-Ratifizierung). Klasse: **ROT** (kauf-nah), **kein Auffangregel**.
Autor: Claude (Factory CEO). Bindet: `decisions/2026-09-02_owner_receipts_ceo_asks.md:13` (Zeile 6, FTMO NO-BUY); dieser Test ist **Receipt-Zeile 18** (`decisions/2026-09-02_owner_receipts_ceo_asks.md:28`, PENDING).

> **Revisionsstand R4 (CEO, 2026-09-05).** R3 wurde ein zweites Mal unabhängig geprüft (`docs/ops/evidence/2026-09-05_review2_ftmo_positive_evidence_test.md`, Verdikt **FAIL**; geprüfte R3-Bytes: roh `265cd2587837132e79055a56c5c7450cc406902db139b6a2d8f7d4e8f3ac3285`, LF `9a6c7c43fa7a97198db0e561732ffda4bbe2abda0d1d87d16d48fbdc654ecad3`, 384 Zeilen — in diesem Worktree byte-identisch reproduziert). R4 schließt die drei offenen Befunde: (a) **F3** — die Non-Overlap-Regel ist jetzt eine operative, numerische, vor dem Ergebnis ausrechenbare Bedingung statt einer Behauptung (§C.4 R-2); (b) **neuer Blocker** — der ausgelieferte P7a-Vertrag erklärt Breach/P2/Joint für **INERT**, während R3 sie als Pass-Kriterien band; §D ist an den Vertrag angeglichen und die **ehrliche Konsequenz ist ausgeschrieben** (§D.0); (c) **F5/F6** — alle Anker sind auf dem aktuellen Tip `fb719e703a` neu geprüft, die vier P7a-berührten Module und der Vertrag samt Loader sind versiegelt, alle Digests LF-normalisiert neu berechnet (§E, §G).
>
> **Was R4 NICHT tut:** keine neue Schwelle, keine neue statistische Konstante, kein Entwurf des fehlenden C-6-Schätzers. Wo R4 eine Zahl nennt, ist sie entweder zeilengenau belegt oder aus belegten Zahlen ausgerechnet (Rechnung mitgeliefert). Wo eine echte Wahl bleibt, steht **OWNER-CHOICE**.

---

## 1 · LAGE (Deutsch, eine Seite)

**Der Park-Trigger ist heute undefiniert.** Receipt-Zeile 6 (`decisions/2026-09-02_owner_receipts_ceo_asks.md:13`) hält den FTMO-Kauf auf NO-BUY und re-ankert den Trigger auf „positive OOS/live evidence" (verbatim: „ja, wann kommen wir aber auf FTMO?"). Die Schwester-Analyse benennt die Lücke: „positiv" ist nicht definiert und würde nach dem Ansehen der Ergebnisse zu Ad-hoc-Selektion (`docs/ops/evidence/2026-09-04_astra_ftmo_book_analysis.md:125,:133`). Die Schließung ist eine datierte Entscheidung über Population, Metrik, Unsicherheit und zulässige Evidenzklasse — ratifiziert **bevor** ein Ergebnis gesehen wird.

**Heutiger Messstand (read-only `farm_state.sqlite` + Belege dieses Branches, Tip `fb719e703a`):**

- Population: **8 identitätsgebundene Q08-Tages-PnL-Ströme** (= Q14 `KEEP_INCUMBENT`, 9 Zeilen / 8 Paare, 11421:EURUSD doppelt; `docs/ops/evidence/2026-09-05_news_calendar_timestamp_defect.md:93`). Alle acht Strom-SHA-256 stehen vollständig in `docs/ops/evidence/2026-09-04_fund_score_current_population.md:16,:24-31` (8 requested / 8 bound / 0 refused, Loader verifiziert).
- FUND_SCORE aller 8 Ströme **< 1.0** (Floor 1.0, `tools/strategy_farm/portfolio/build_book_ftmo.py:58`), Buch verweigert; Zähler **8/25** → `BOOK_BUILD_REFUSED` (`tools/strategy_farm/book_build_guard.py:28`, Refusal `:236-238`).
- Der einzige billige Test — ein gültiger 2026-Q1-OOS-Pass (~55 Läufe, ~3 Terminalstunden) — **ist nie gelaufen** (`docs/ops/CEO_AUDIT_2026-09-02.md:45`) und war doppelt blockiert: (i) 15/15 Confirmation-Jobs liefen 2024 statt 2026 (`docs/ops/evidence/2026-09-04_astra_ftmo_book_analysis.md:88`), (ii) das Fenster **2026-01-01..2026-04-06** liegt im Kalender-Loch 2025-05..2026-06 (null Zeilen; `docs/ops/evidence/2026-09-05_news_calendar_timestamp_defect.md:51,:102-103`).
- Die Kalender-Blockade ist **entschieden**: Receipt-Zeile 8 DECIDED YES (`:16`); Zeile 9 ratifiziert **E1 Option A** (nativer MT5-Export, Backfill 2025-05..2026-06, neue Bundle-Identität; Task `0da3dfec`, `:18`); Zeile 11 bindet **E4 `--apply` erst nach dem Backfill** (Task `49a8c88b`, `:20`). Das frühere OQ-3 ist beantwortet.
- Live-Buch (governed-only, die zwei manuellen `magic=0`-Trades ausgeschlossen per Zeile 1, `:8`): **−469 USD über 30 aktive Tage, Sharpe-CI [−6.8, +4.6]** — statistisch nicht informativ (`docs/ops/CEO_AUDIT_2026-09-02.md:14`).
- DSR/Multiple-Testing: **0 Sleeves erreichen DSR ≥ 0.95** bei jedem vertretbaren Trial-Count (`docs/ops/CEO_AUDIT_2026-09-02.md:14`; 0/24 und 0/21 für jedes N ≥ 10, `:43`); E[max SR] unter Null ≈ 1.06–1.44 (`:14`, Herkunft `:42`); die modellierte +2.4-Buch-Sharpe überlebt die Korrektur zu ≈ 0 % (`:14`). Walk-Forward: 82 % PF>1 (`:14`), Held-out-Folds 61/74 PF>1, geo-mean OOS PF 1.47 selektionskonditioniert (`:45`) — lehnt gegen Null-Edge, ist aber nicht kauf-tragend.

**NEU seit R3 — P7a ist GELIEFERT, und das ändert diesen Test in zwei Richtungen.**

Receipt-Zeile 15 (P7a, Task `97a0ed31`, `:24`) ist umgesetzt: `docs/ops/FTMO_PROBABILITY_CORRELATION_CONTRACT_V1_2026-09-05.md` plus versioniertes `tools/strategy_farm/config/ftmo_probability_contract.v1.json` und strikter Loader `tools/strategy_farm/portfolio/ftmo_probability_contract.py` (Implementierungs-Commit `f68ce8f338`, ändert Builder, Timebox-Evaluator, MC und First-Passage).

1. **Die P1-Latte ist damit aufgelöst — zu unseren Gunsten der Strenge.** Der Vertrag bindet **ein einziges Gate: `lower_95 ≥ 0.80`** (`ftmo_probability_contract.v1.json:19`), weil die Bootstrap-Untergrenze per Konstruktion ≤ Punktschätzer ist (`build_book_ftmo.py:474` erzwingt `0 ≤ lower ≤ estimate ≤ 1`); der Rulepack-Punkt ≥ 80 % ist damit **nicht-additiv/dominiert**, die Rulepack-Untergrenze 70 % ist **dominiert**. Der Loader **verweigert** jeden v1-Vertrag mit einer anderen P1-Untergrenze (`ftmo_probability_contract.py:121-122`). **OQ-1 ist damit sachlich beantwortet** — es bleibt eine Bestätigung, keine Arbitrierung (`docs/ops/FTMO_PROBABILITY_CORRELATION_CONTRACT_V1_2026-09-05.md:283`).
2. **Breach, P2-conditional und Joint sind INERT — und das ist der harte Befund.** Beide Gates tragen `enforcement_status = INERT_UNTIL_C6_ENGINE_OWNER_APPROVED` (`ftmo_probability_contract.v1.json:20,:21`); der Loader **verweigert** jeden Vertrag, der sie aktiviert (`ftmo_probability_contract.py:117-120`); der Evaluator veröffentlicht den Status in jedem Ergebnis mit dem Satz „breach/P2/joint cannot pass or fail this result until C-6 is OWNER-approved" (`ftmo_timebox_eval.py:1480-1486`, Statusfeld `:1484`) und creditet nach wie vor **ausschließlich** die P1-Untergrenze (`:1474`). Grund: MC liefert Breach nur als **Unter**grenze (`ftmo_p1_mc.py:30-31`), eine zulässige **Ober**grenze schätzt keine Engine, und für Joint-Credit existiert keine Formel (`docs/ops/FTMO_PROBABILITY_CORRELATION_CONTRACT_V1_2026-09-05.md:40,:79,:81`).

**Drei harte Befunde aus der R4-Nachprüfung (rein arithmetisch bzw. code-belegt, keine neuen Schwellen):**

1. **Das 13-Wochen-Fenster enthält genau EIN nicht überlappendes P1-Fenster.** 2026-01-01..2026-04-06 = **96 Kalendertage**; die P1-Horizontlänge ist 60 Kalendertage (`ftmo_timebox_eval.py:79`; `docs/research/FTMO_BOOK_SPEC_2026-08-02_OWNER_TIMEBOX.md:13`). ⌊96/60⌋ = **1**. Für die volle Zwei-Phasen-Strecke (60+30, `:81` / `:15`) gilt ⌊96/90⌋ = **1**.
2. **Die „37 rollierenden Starts" aus R3 waren für diese Engine falsch — und der wahre Wert ist schlechter.** `rolling_outcomes()` iteriert über **jeden** Tag mit `eligible_start` und verlangt **nicht**, dass der 60-Tage-Horizont noch in die Spanne passt (`ftmo_timebox_eval.py:898-902`); Starts ohne vollen Horizont laufen ins `TIMEOUT` und zählen als Nicht-Pass (`:891-895`, Regel `censoring` `:94`). Auf 96 Tagen sind das **37 Starts mit vollem Horizont und 59 rechts-zensierte Starts** (37+59 = 96): bis zu **61 % der gezählten Starts können strukturell nicht bestehen**. Sie drücken `p1_raw_rate` (`:1146`) nach unten und blähen `p1_hac.n` (`:1147`) auf.
3. **Die Roster-Deckung der einzigen OOS-Quelle ist unvollständig.** `D:/QM/strategy_farm/artifacts/oos_2026_confirmation_v1/campaign_plan.json` (read-only, in R4 erneut selbst ausgezählt) enthält 55 Läufe über **50 verschiedene (EA, Symbol)-Paare** (`run_count` 55, `live_count` 24, `frontier_count` 31, `cost_profile` `DXZ_CANONICAL_REAL_TICKS_V1`, Fenster `full_from_utc` 2026-01-01T00:00:00Z / `full_to_utc` 2026-04-06T23:59:59Z). Davon decken sich **7 der 8** versiegelten Identitäten; **`QM5_11910`:NZDUSD kommt in der Kampagne überhaupt nicht vor** (0 Einträge). Eine Teilablesung der versiegelten Population ist ohne vorab festgelegte Behandlung selbst ein Selektionsrisiko (OQ-6).

**Die unbequeme Rechnung, die R4 sichtbar macht.** Aus der Power-Regel (§C.4 R-1) folgt bei der empfohlenen Zielgröße `p* = 0.90` und der jetzt vertraglich fixierten Latte `bar = 0.80` eine Mindest-ESS von **35**. Operativ heißt das (§C.4 R-2): **35 nicht überlappende 60-Tage-Fenster = 2.100 versiegelte Kalendertage ≈ 5,75 Jahre** OOS — bzw. 3.150 Tage ≈ 8,6 Jahre, wenn auch das Zwei-Phasen-Gate gepowert sein soll. Das vorhandene 96-Tage-Fenster ist um den Faktor **21,9** zu kurz. Diese Zahl ist keine neue Schwelle: sie ist die Multiplikation der belegten Horizontlänge mit der aus belegten Konstanten ausgerechneten ESS.

**Kernpunkt:** Der 25-Paar-Zähler ist eine **Kauf-Vorbedingung**, NICHT der Positive-Evidence-Trigger. Ihn zu bestehen ersetzt den Trigger nicht (`docs/ops/evidence/2026-09-04_astra_ftmo_book_analysis.md:79,:125`).

## 2 · EMPFEHLUNG

1. **NO-BUY beibehalten.** Kein Ergebnis liegt vor, das den Trigger erfüllt.
2. **Diesen vorab-deklarierten, widerlegbaren Abnahmetest in der R4-Fassung ratifizieren** — Population / Metrik / Unsicherheit / **operative Power-Regel** / Evidenzklasse / Refutationsklausel / Siegel —, BEVOR ein Ergebnis gesehen wird.
3. **Die ehrliche Konsequenz mit ratifizieren, nicht wegformulieren:** Selbst ein perfektes Messergebnis kann NO-BUY **heute nicht** aufheben, aus zwei voneinander unabhängigen Gründen — (i) die zulässige Evidenzpopulation existiert noch nicht (§C.4 R-2), (ii) drei der notwendigen Bedingungen sind vertraglich INERT und können weder bestehen noch reißen (§D.0). Wer den Test ratifiziert, ratifiziert damit auch, dass der Weg zu „positive-evidence-met" über **C-6-Scoping + längere versiegelte OOS-Strecke** führt und nicht über eine Ablesung des vorhandenen Diagnosefensters.
4. **Reihenfolge:** E1 Option A ausführen (Zeile 9) → Loch-Backfill → E4 `--apply` (Zeile 11) → **versiegelte, nach §C.4 ausreichend gepowerte** OOS-Messung; parallel **C-6 scopen** (OQ-9), sonst bleibt §D dauerhaft inert. **Das einzelne 96-Tage-Diagnosefenster ist für sich genommen NICHT zulässig.**
5. **Vor der Messung zusätzlich zu klären:** die Kostenklasse. Der Evaluator **verweigert** rohe DXZ-Ströme (`ftmo_timebox_eval.py:1307-1308`, `REFUSED_DXZ_SPREAD_INHERITANCE`) und akzeptiert nur `DXZ_EXECUTION_FTMO_COST_ADJUSTED_V1` (`:54`, Deklarationspflicht `:1310-1312`, Attestierung `:707-708`). Die Kampagne läuft unter `cost_profile = DXZ_CANONICAL_REAL_TICKS_V1`. Ohne FTMO-Kosten-Reattestierung ist ihr Output nicht evaluatorfähig (OQ-7).
6. Kauf, T_Live, AutoTrading, Deployment bleiben **separate, einzeln signierte** OWNER-Zeremonien — dieser Test hebt NO-BUY höchstens auf „positive-evidence-met", nicht auf „gekauft" (Rulepack `:500-505`).

## 3 · ENTSCHEIDUNGSFRAGEN (je mit Rollback + Cost-of-Wait)

| Q | Frage | Klasse | Rollback | Cost-of-Wait |
|---|-------|--------|----------|--------------|
| **Q1** | Diesen Abnahmetest in der **R4-Fassung** ratifizieren (Population / Metrik / Unsicherheit / operative Power-Regel / Evidenzklasse / Refutation / Siegel wie §A–§F) — **einschließlich der Feststellung, dass er NO-BUY heute nicht aufheben kann** (§D.0)? | ROT | Test bleibt unratifiziert; alle Evidenz bleibt erhalten; keine Verdikte berührt. | Jede weitere Messung ohne ratifizierten Test riskiert Ad-hoc-Selektion; der Trigger bleibt undefiniert und blockiert den FTMO-Zeitplan, den OWNER erfragt hat (Zeile 6). |
| **Q2a** | **Zulässige Evidenzpopulation (OQ-2a, blockierend für §D).** Genügt das einzelne korrigierte 96-Tage-Fenster, oder ist eine **nach §C.4 R-2 ausreichend lange versiegelte OOS-Strecke** erforderlich? | ROT | §D bleibt inert; keine Messung zählt als Lift-Quelle. | Ohne Antwort ist der Test nicht entscheidbar; NO-BUY bliebe unbestimmt lange geparkt. |
| **Q2b** | **Zielgröße p\* für die Power-Regel (OQ-2b, blockierend für §D).** Welche wahre P1-Passrate soll der Test zertifizieren können? Aus p\* folgen ESS_min **und** die Mindest-Spanne **rechnerisch** (§C.4 R-1/R-2). **Empfehlung: p\* = 0.90** (→ ESS_min 35 → 2.100 versiegelte Kalendertage). | ROT (Unsicherheit) | §D bleibt inert. | Ohne p\* ist „gepowert" nach dem Ergebnis zuweisbar — genau die Ad-hoc-Selektion, die der Test verhindern soll (Review F3). |
| **Q2c** | **Kopplung der Non-Overlap-Regel (OQ-2c, NEU in R4).** R-2 verlangt `W_min = ESS_min` disjunkte 60-Tage-Fenster (1:1-Kopplung), weil die **Resampling-Einheit des Bootstraps selbst** der 60-Kalendertage-Block ist (`ftmo_timebox_eval.py:994-998,:1020`). Alternative: R-2 nur als Diagnose führen und allein der gemessenen HAC-ESS vertrauen. **Empfehlung: 1:1-Kopplung als harte Bedingung** — die gemessene ESS ist allein nicht sicher (§C.4 R-2b). | ROT (Kriterium) | Reine Vorab-Festlegung. | Ohne Festlegung wiederholt sich exakt der Review-F3-Befund: „gepowert" bliebe eine Wertung nach dem Ergebnis. |
| **Q3** | **P1-Latte bestätigen (OQ-1, jetzt Bestätigung statt Konflikt).** Der ausgelieferte P7a-Vertrag bindet **`lower_95 ≥ 0.80` als einziges Gate** (`ftmo_probability_contract.v1.json:19`, erzwungen `ftmo_probability_contract.py:121-122`); Rulepack-Punkt 80 % ist nicht-additiv, Rulepack-Lower 70 % ist dominiert. Bestätigen? | ROT (Buchregeln) | Versionierte Reconciliation über den Vertrag, nie stille Reklassifizierung. | Der Vertrag selbst steht auf `PENDING_OWNER_RATIFICATION` (`:3`) — ohne Bestätigung läuft der Code auf einer unratifizierten Latte. |
| **Q4** | Evidenzklasse bestätigen: OOS-2026 zählt **erst nach** E1-Reparatur + Backfill + korrigiertem Fenster; die **sieben Evidenz-Kriterien** des Rulepacks sind notwendig (das achte ist die separate Kauf-Zeremonie); Live-Attribution **governed-only**; Live ist **stützend, nicht hinreichend**. | ROT | Kein Rollback nötig — reine Vorab-Festlegung. | Ohne Festlegung misst OOS ohne News und ohne vollständige Intraday-MTM, und Live-Zahlen werden durch die manuellen Trades verzerrt (~76 % des −2.227-USD-Verlusts, `CEO_AUDIT:14`). |
| **Q5** | **Roster-Lücke (OQ-6).** `QM5_11910`:NZDUSD fehlt in der OOS-Kampagne (0 Einträge, selbst ausgezählt). Vorab festlegen: (a) Lücke = Refutation, (b) Lücke wird als Fehlschlag gewertet, oder (c) 11910 wird vor dem Siegel per Nachlauf ergänzt. **Empfehlung: (c), sonst (b).** | ROT (Population) | Keine — reine Vorab-Festlegung. | Nach dem Ergebnis entschieden, ist jede Variante eine Nachselektion (§A Regel c). |
| **Q6** | **C-6-Scoping (OQ-9, NEU in R4 — der eigentliche Engpass für §D).** Breach-Upper-95, P2-conditional und Joint sind INERT; ohne eine OWNER-gescopte, gebaute und abgenommene Schätzmethode kann §D **nie** erfüllt werden. Beauftragen (Methode zuerst, dann Codex-Implementierung, dann OWNER-Abnahme) — oder die drei Gates als „declared, not yet estimable" parken und den Lift-Pfad ausdrücklich auf D.1-ohne-C-6 + D.2 reduzieren? | ROT (Gate-Kriterien) | Der INERT-Status bleibt; kein Buch wird an ihnen bestanden oder gerissen. | Ohne Antwort ist dieser Abnahmetest ein Test, der per Konstruktion nie „bestanden" ausgeben kann — NO-BUY wäre faktisch dauerhaft. |
| **Q7** | **Ratifizierungs-Asymmetrie (OQ-10, = Vertrag C-2).** Der Rulepack trägt `lifecycle_status: RESEARCH_CONTRACT_ONLY` (`FTMO_2S_100K_SWING_V2.json:9`); seine `go_criteria` sind PROPOSED, nicht OWNER-versiegelt. Hebt OWNER sie mit der Ratifizierung dieses Tests auf bindend, oder bleiben sie „declared-but-not-sealed" (blockieren ein Buch, zählen aber nicht als kauf-tragende Evidenz)? | ROT | Reine Statusfestlegung. | Ohne Klärung bindet §D Zahlen, deren Ratifizierungsstatus ungeklärt ist (`docs/ops/FTMO_PROBABILITY_CORRELATION_CONTRACT_V1_2026-09-05.md:36,:284`). |

Alles ROT. **Kein Auffangregel.** Ratifizierung nur durch OWNER (alleinige menschliche Autorität).

---

# ENGLISH CONTRACT — FTMO Positive-Evidence Acceptance Test (predeclared, refutable) — R4

Ratify this contract text verbatim before any evaluation stream is opened. Every threshold below is a path-referenced EXISTING policy value on branch `agents/board-advisor` at commit **`fb719e703a`**; this contract invents none. Where arithmetic is derived from existing values, the derivation is shown. Where no value exists, the item is marked **OWNER-CHOICE** with a recommendation and is not silently filled in.

## §A · Evidence sources and admissibility

**Admissible population (sealed).** Exactly the 8 identity-bound Q08 daily-PnL streams of the current bundle = the Q14 `KEEP_INCUMBENT` rows (9 rows / 8 distinct pairs, 11421:EURUSD twice; `docs/ops/evidence/2026-09-05_news_calendar_timestamp_defect.md:93`). Byte-pinned by SHA-256 in `docs/ops/evidence/2026-09-04_fund_score_current_population.md:24-31` (8 requested / 8 bound / 0 refused, loader verified, `:16`):

| ea_id | symbol | stream SHA-256 | in OOS-2026 campaign? |
|-------|--------|----------------|-----------------------|
| 10706 | GBPUSD | `71fb35b8f8539356f511609a4d1dfb06571f85b19b60de6647e907ec891e34f7` | yes (`QM5_10706`/`GBPUSD.DWX`) |
| 11421 | EURUSD | `e9d0a9ef831f156f0f67e5bf1140d7e57702c3923a4ff47b5548847957d7c0c1` | yes |
| 11422 | USDCAD | `7ce6cc3ec2f1279c18e8601119e3319375d5d3fa1ce4cf95cf33e05eefc33198` | yes |
| 11910 | NZDUSD | `555bbee205432c62f06da96a0a291d14028dc5c88e3fa8b2792ad62bc5d885b0` | **NO — 0 entries** |
| 13054 | XTIUSD | `67d4fe2cef067e041f01d10e5e6c98312a32b43683eee2da3d0bfa9af296955b` | yes |
| 1537  | XAGUSD | `1885c21e4c895827c79ff3d55849308ab4ee5c0db96a7d576cd652dc3eff8658` | yes |
| 20048 | XTIUSD | `a792e2635250bcd6df5aa4a290359b54e6d5ffe8fbe10e34d143b74dfe0e8d55` | yes |
| 21505 | XAGUSD | `243804faaf0050f5482b9a4aac8f9eb0dcd552de1c2c139a486f0bcfa46b94c1` | yes |

Coverage column re-measured read-only in R4 from `D:/QM/strategy_farm/artifacts/oos_2026_confirmation_v1/campaign_plan.json` (55 runs, 50 distinct `(ea_id, symbol)` pairs; the `runs[]` records key on `ea_id` = `QM5_<id>` and `symbol` = `<SYM>.DWX`).

**Admissibility rules (predeclared):**

| # | Rule | Basis |
|---|------|-------|
| a | **Governed-only live attribution.** The two `magic=0` live trades (27.07 NDX 1.00 lot, 24.07 EURUSD 0.43 lot) are OWNER manual trades and are EXCLUDED from every governed track-record read. | `decisions/2026-09-02_owner_receipts_ceo_asks.md:8` (row 1); `docs/ops/CEO_AUDIT_2026-09-02.md:14` (those two ≈ 76 % of the −2,227 USD live loss; governed book alone −469 USD / 30 days, Sharpe CI [−6.8,+4.6]). |
| b | **No manual trades count as evidence** (neither for nor against). | row 1, as above. |
| c | **No re-selection after results are seen.** The roster of 8 identities is frozen at seal; no addition, removal, or substitution after the first result is opened. | `docs/ops/evidence/2026-09-04_astra_ftmo_book_analysis.md:131,:133`. |
| d | **OOS-2026 counts ONLY after the E1 calendar repair AND the 2025-05..2026-06 backfill AND on the corrected window AND only if the source satisfies §C.4 R-1 and R-2.** A single 96-day diagnostic window is NOT admissible on its own. | calendar precondition below; `docs/ops/evidence/2026-09-05_news_calendar_timestamp_defect.md:51,:102-103`. |
| e | **Roster completeness is predeclared, not discovered.** 11910:NZDUSD has no run in the only existing OOS-2026 campaign. The handling of that gap is fixed BEFORE the seal (OQ-6). A population read that silently drops a sealed identity is a contamination event under §E.2. | `campaign_plan.json` roster enumeration (read-only); §A roster table above. |
| f | **Cost class is predeclared.** The evaluator REFUSES a raw `DXZ_Q08_TRADES_V1` stream with `REFUSED_DXZ_SPREAD_INHERITANCE` and accepts only `DXZ_EXECUTION_FTMO_COST_ADJUSTED_V1` under an explicit declaration. The OOS campaign runs `cost_profile = DXZ_CANONICAL_REAL_TICKS_V1`, so its output must first be re-costed and re-emitted under the accepted schema (OQ-7). | `ftmo_timebox_eval.py:53,:54,:58,:1307-1308` (refusal), `:1310-1312` (explicit declaration required); cost attestation `:576-585,:707-708`; `campaign_plan.json cost_profile`. |
| g | **Calendar contiguity is machine-enforced, not assumed.** Every admissible stream must be a gap-free daily calendar series: the loaders raise `REFUSED_NONIDENTICAL_OR_NONCONTIGUOUS_SHARED_CALENDAR` if any row is not exactly `previous_day + 1`. This is what makes the sealed span `D` in §C.4 R-2 a well-defined inclusive calendar count rather than a judgment call. | `ftmo_timebox_eval.py:64,:629-630,:723-724`. |

**Calendar-defect precondition — DECIDED, not open.**

1. **Dispatch/window bug.** 15/15 completed confirmation jobs ran **2024** in both INIs and reports despite 2026 input manifests (`docs/ops/evidence/2026-09-04_astra_ftmo_book_analysis.md:88`). Repaired by commit `1ac9f653d8`; `repair-oos-window --apply` remains DEFERRED, task `1721f3a1` IN_PROGRESS (`docs/ops/evidence/2026-09-05_news_calendar_timestamp_defect.md:103,:138`).
2. **Calendar coverage hole.** 2025-05 through 2026-06 contain **zero rows**; 2025-04 is partial (`...:51`). The window 2026-01-01..2026-04-06 lies inside the hole, so successor runs would measure with no news events at all (`...:102`).
3. **OWNER disposition (already given).** Receipt row 8 is DECIDED YES (`decisions/2026-09-02_owner_receipts_ceo_asks.md:16`). Row 9 ratifies **E1 Option A** — native MT5 export, BLS/Fed anchors for USD, non-USD offset fan or declared gap, backfill 2025-05..2026-06, new bundle identity + repin; task `0da3dfec` (`:18`). Row 11 binds **E4 `--apply` only after the E1 backfill**; task `49a8c88b` (`:20`). The former OQ-3 is therefore **answered** and is retired below.

**Notes.** The OOS-2026 campaign is **diagnostic by design**: `campaign_plan.json` carries `diagnostic_non_admission=true`, `diagnostic_single_window=true`, `single_seed=20250301`, `single_config=deployed`, `t_live_read_only=true`, window `2026-01-01T00:00:00Z .. 2026-04-06T23:59:59Z` (read-only). Because it is non-admitting by its own declaration AND under-powered by §C.4, it is a diagnostic, not a lift source. Live trading is unaffected by the calendar defect — the live news branch reads the native MT5 calendar, not the CSVs. Of the 8 sealed identities, only 10706/GBPUSD (H1, explicit `PRE30_POST30`) is exposed to the timestamp defect; the other 7 are D1 bar-open entries for which the defect is practically inert (`docs/ops/evidence/2026-09-05_news_calendar_timestamp_defect.md:93,:98`).

## §B · Metrics and thresholds (all derived from EXISTING policy — no new numbers)

**Provider rules** (rulepack `tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_SWING_V2.json`, file SHA-256 `298ef1285eca49ea7f010ebc0a9353b5a821fccb40a025be129f5ca5314fd992`, LF-only file so worktree and LF digests coincide; provider snapshot `docs/ops/evidence/2026-09-04_ftmo_official_rules_snapshot.json`):

| Rule | Value | Path |
|------|-------|------|
| Phase-1 profit target | +10 % (USD 10,000 → balance 110,000) | rulepack `:96-105` (percent `:101`) |
| Verification profit target | +5 % (USD 5,000 → balance 105,000) | rulepack `:108-117` (percent `:113`) |
| Max daily loss | 5 % of initial (Prague-midnight balance − USD 5,000), equity incl. open PnL/swaps/commissions, breach `STRICTLY_BELOW_LIMIT` | rulepack `:120-133` (params `:124-132`) |
| Max loss (static floor) | 10 % → USD 90,000 floor | rulepack `:136-148` (floor `:144`) |
| Min trading days | ≥ 4 CE(S)T days with a position OPENED | rulepack `:151-160` (`days:4` `:156`) |
| Pass condition | balance `STRICTLY_GREATER_THAN_TARGET`, 0 positions open | rulepack `:173-181` (operator `:178`) |
| Time limit | none | rulepack `:163-170` (`:168`) |
| Evaluation fee | USD 540, one-time, refundable in full with the first Reward | rulepack `:231-237` (fee `:235`), refund `:239-243` |
| Swing leverage | 1:30 FX / 1:15 metals+oil — **CARRIED_OVER / NOT re-confirmed on 2026-09-04** | rulepack `:254-260` (params `:259`); status snapshot `:724-725,:728-729`, dead URL `:808-816`, scope limit `:824` |

**Rulepack ratification status.** The whole rulepack carries `lifecycle_status: RESEARCH_CONTRACT_ONLY` (`:9`). Its `go_criteria` are therefore **PROPOSED**, not OWNER-sealed — the probability contract records this as decision **C-2** and expressly leaves the elevation to OWNER (`docs/ops/FTMO_PROBABILITY_CORRELATION_CONTRACT_V1_2026-09-05.md:36,:284`). Ratifying §D of this test is one of the two lawful ways to resolve C-2 for these criteria; that consequence is surfaced as **Q7 / OQ-10** rather than taken silently.

**Decision gates — the full `evaluation_profile.go_criteria` set (rulepack `:457-506`).** Seven are **evidence** criteria; the eighth is the separate purchase ceremony and is never implied by "positive-evidence-met" (its own description: "A paid Challenge requires a separate signed OWNER decision after all evidence criteria pass", `:503`).

| # | criterion_id | Threshold | Enforcement status today | Path |
|---|--------------|-----------|--------------------------|------|
| 1 | `ftmo_rule_snapshot_fresh` | official snapshot age ≤ **7 days**, all sources official | evaluable | `:458-463` (`maximum_age_days:7` `:462`); contract `ftmo_probability_contract.v1.json:22` |
| 2 | `ftmo_execution_fidelity_closed` | **0** unadjudicated standalone-to-book entry/exit/timer/ownership mismatches | evaluable | `:464-469` (`unadjudicated_mismatches:0` `:468`) |
| 3 | `ftmo_complete_mtm_evidence` | tick-/event-complete interval minimum equity, Prague anchors, FTMO symbols, costs, swap, margin, pending state; **closed-P&L daily proxy FORBIDDEN**, intratrade equity REQUIRED | evaluable | `:470-475` (params `:474`) |
| 4 | `ftmo_phase1_probability_gate` | rulepack source: point ≥ **80 %** AND lower-95 ≥ **70 %** — **subsumed** by the contract's single binding gate `lower_95 ≥ 0.80` | evaluable (binding form = contract) | `:476-481` (params `:480`); contract `ftmo_probability_contract.v1.json:19` |
| 5 | `ftmo_breach_probability_gate` | upper-95 ≤ **10 %** | **INERT_UNTIL_C6_ENGINE_OWNER_APPROVED** | `:482-487` (params `:486`); contract JSON `ftmo_probability_contract.v1.json:20`; loader refusal `ftmo_probability_contract.py:117-120`; published `ftmo_timebox_eval.py:1484-1485` |
| 6 | `ftmo_two_phase_probability_gate` | P2-conditional ≥ **85 %** AND joint ≥ **65 %** | **INERT_UNTIL_C6_ENGINE_OWNER_APPROVED** | `:488-493` (params `:492`); contract JSON `ftmo_probability_contract.v1.json:21`; loader `ftmo_probability_contract.py:117-120` |
| 7 | `ftmo_free_trial_gate` | ≥ **1** exact-profile Free-Trial/shadow run, **0** operational defects, inside preregistered prediction bands | evaluable | `:494-499` (params `:498`); contract JSON `ftmo_probability_contract.v1.json:23` |
| 8 | `ftmo_owner_purchase_gate` | **separate signed OWNER decision**; automatic purchase forbidden — NOT an evidence criterion | outside this test | `:500-505` (params `:504`) |

Criterion 3 is load-bearing for criteria 4–6: an FTMO rule-breach probability computed on a closed-P&L daily proxy is explicitly not admissible evidence, so complete intratrade MTM must precede any breach-probability claim.

**Builder V2 OWNER_RATIFIED thresholds** (`tools/strategy_farm/portfolio/build_book_ftmo.py`, ratified under `OWNER-DEC-BOOK-V2V4V6-EPOCH-20260904`, receipt `decisions/2026-09-04_owner_receipts_briefing_2_4.md`; ratification stamped in-module at `:95-96`). **P7a changed the provenance of four of these from literals to contract imports** — the values are unchanged, the source of truth moved:

| Item | Value | Path (tip `fb719e703a`) |
|------|-------|------|
| FUND_SCORE floor | **1.0** | `:58` (still a literal) |
| P1 lower-bound floor | **0.80** | `:59-61` — now imported from `ftmo_probability_contract.v1.json:19` |
| DL-083 Q09 marginal-eval reject | 0.40 | `:75-76` (comment only); actually enforced in `ftmo_timebox_eval.py:112-114`, applied `:1115-1117` (`REFUSED_DL083_CORRELATION_AT_OR_ABOVE_0P40` `:61`). *The contract JSON's own citation `ftmo_probability_contract.v1.json:30` says "applied :1092" — stale by ~23 lines; reported under OQ-11.* |
| Max pairwise correlation | 0.50 | `:82-85` — contract-derived (`ftmo_probability_contract.v1.json:30`) |
| Account unit-weight budget | 10.0 | `:86-88` — contract-derived (`...json:38`) |
| Sleeve unit weight | 1.0 | `:89-92` — contract-derived (`...json:38`) |
| min_sleeves | 3 | `:503` |
| min_active_days_per_60d | 4.0 (builder floor, NOT the full Q15 ceremony) | `:504` |
| Source-sleeve risk mode | RISK_FIXED=1000 / RISK_PERCENT=0 hard check | `:531-535` (raise `:533-535`) |
| Correlation estimator | **V4 Layer-A `CERTIFY_A` only**, conservative `abs_upper` consumed; PROVISIONAL/ABSTAIN/absent stay fail-closed UNVERIFIED | `:146-204` (verdict filter `:184`, `abs_upper` `:190`, cap `:194`, label `:200`) |
| Bootstrap sanity | `0 ≤ lower ≤ estimate ≤ 1`; pass iff `lower ≥ 0.80` | `:474`, `:476` |
| C-6 inertness republished by the builder | `breach` / `two_phase` enforcement status echoed into every bootstrap verification block | `:488-491` |

*Note on the contract's own stale line: `ftmo_probability_contract.v1.json:29` still carries `migration_note: "builder currently consumes zeros-DROPPED point Pearson (:184-197); migrate to Layer-A certified CI"`. That migration **already landed** in `f68ce8f338` (`build_book_ftmo.py:146-204`). The note is documentation drift inside the contract file, not a behavioural difference; it is reported here and left to the contract's own version control (OQ-11).*

**FUND_SCORE formula** (`tools/strategy_farm/portfolio/fund_score.py`, 178 lines, unchanged by P7a): `FUND_SCORE = med60_1x / max(2.0, 2.0·|worst_day_1x|, wDD_p90_1x)` — med60 `:94`, |worst_day| `:95`, wDD_p90 `:96`, denominator `:97`, score `:100`, formula string `:103`. Current-population rescore, all < 1.0, NO-BUY unchanged (`docs/ops/evidence/2026-09-04_fund_score_current_population.md:24-31`): 10706:GBPUSD 0.106901, 11421:EURUSD 0.015577, 11422:USDCAD 0.148329, 11910:NZDUSD 0.094695, 13054:XTIUSD 0.024265, 1537:XAGUSD 0.131237, 20048:XTIUSD 0.032985, 21505:XAGUSD 0.123500.

**Book counter:** `MIN_QUALIFIED_PAIRS = 25` (`tools/strategy_farm/book_build_guard.py:28`, refusal `:236-238`); census 8/25 → `BOOK_BUILD_REFUSED`. **The 25-pair counter is a purchase prerequisite, NOT the positive-evidence trigger — passing it cannot substitute for the trigger** (`docs/ops/evidence/2026-09-04_astra_ftmo_book_analysis.md:79,:125`).

**Concentration / tail** (`tools/strategy_farm/config/concentration_tail_limits.v1.json`, `status: OWNER_RATIFIED` `:3` via receipt row 4 `decisions/2026-09-02_owner_receipts_ceo_asks.md:11`): `stop_risk_budget_pct` 2.5 (`:5`); caps as % of budget: symbol 40 (`:7`), asset_class 60 (`:8`), family 50 (`:9`), session WARN 60 (`:10`) / breach 70 (`:11`); tail: `per_sleeve_worst_fraction` 0.05 (`:14`), `joint_sleeve_divisor` 3 (`:15`), `venue_daily_loss_limit_pct` 5.0 (`:16`), `maximum_fraction_of_daily_limit` 0.8 (`:17`). Application to live weights remains a separate OWNER ceremony (`application_authority OWNER_ONLY` `:34`, `deployment_action NONE` `:35`).

**Speed doctrine** (`docs/research/FTMO_BOOK_SPEC_2026-08-02_OWNER_TIMEBOX.md`): P1 horizon **60** calendar days (`:13`), P2 horizon **30** calendar days (`:15`), design bar **P(Phase-1 pass) ≥ 0.80** (`:19`) measured as the moving-block bootstrap **LOWER** bound, never the raw rate (`:25-26`), decided at the conservative end of the spread-penalty band (`:58-61`). Mirrored in `ftmo_timebox_eval.py` `DEFAULT_RULES` (`:76-98`), all four now imported from the probability contract: `design_bar_p1` 0.80 (`:97`); P1/P2 horizons 60/30 (`:79,:81`); `DEFAULT_BOOTSTRAP` (`:100-106`) replicates 2000 (`:101`), seed 20260802 (`:102`), alpha 0.05 (`:103`), 60-day blocks (`:104`), `TWO_SIDED_PERCENTILE_95` (`:105`).

**P1 bar — resolved by the delivered contract, no longer an intersection.** R3 applied the interim intersection `point ≥ 0.80 AND lower-95 ≥ 0.80` pending P7a. P7a has landed. The binding gate is now **`P1_lower_95 ≥ 0.80`, single and alone** (`ftmo_probability_contract.v1.json:19`; enforced at load, `ftmo_probability_contract.py:121-122`, which refuses any v1 contract with a different value). The rulepack's `point ≥ 80 %` is `NON_ADDITIVE_DOMINATED` and its `lower ≥ 70 %` is dominated, because `lower ≤ estimate` is guaranteed (`build_book_ftmo.py:474`) — so `lower_95 ≥ 0.80` implies `point ≥ 0.80` and strictly dominates `lower ≥ 0.70`. **Behaviourally identical to R3's intersection; provenance now versioned.** Two consequences carried forward unchanged: a point estimate of exactly 0.80 can never pass, and §C.4 is defined only for `p* > 0.80`. **The bar is therefore fixed at `bar = 0.80` for this test; the `bar = 0.70` column in §C.4 is retained as dominated documentation only, not as a live option.** Caveat stated plainly: the contract itself is `PENDING_OWNER_RATIFICATION` (`ftmo_probability_contract.v1.json:3`) — Q3 confirms it, it does not rediscover it.

## §C · Sample size, power, and the DSR engine

### §C.1 · What each engine can and cannot establish

| Engine | Establishes | CANNOT establish | Key params / path (tip) |
|--------|-------------|------------------|-------------------|
| `ftmo_p1_mc.py` | Ranks compositions; daily/total-DD breach probabilities as explicit **lower bounds** (rules applied on CLOSED daily P&L; floating intraday DD invisible) | Joint tail dependence — sleeves are resampled INDEPENDENTLY; DSR; an admission-quality bound; **any upper bound on breach** (this is exactly the C-6 gap) | independent resample `:26`; closed-P&L lower bounds `:30-31`; contract-bound horizon 90 trading days `:82-83`; `DIAGNOSTIC_ONLY` `:85`, upward-bias note `:86-89`, 10,000 paths `:91`, seed 20260720 `:92`, role stamped into output `:922` |
| `challenge_firstpassage.py` | First-passage (+10 % before −5 % daily / −10 % total, no deadline) on END-OF-DAY balance; four-opening-day minimum enforced; effective sample size = overlapping starts ÷ median resolution time; preregistered **1x-no-overlay** block (selection-free) | A raw-n confidence read (starts OVERLAP); DSR; stages 1–2 are in-sample-selected and must NOT be the acceptance number | four-day minimum `:33,:76,:183-184,:241`; `DIAGNOSTIC_ONLY` `:64-67`, stamped `:271-272`; preregistered 1x `:381-388`; ESS `:415-418`, Wald half-width `1.96·se` `:419-420`, 0.80 comparison `:425`, lower-bound semantics `:429-431` |
| `ftmo_timebox_eval.py` | Selection-SEALED (`prepare-config` freezes input SHAs before any stream is opened); moving-block bootstrap; HAC effective sample size for autocorrelated overlapping starts; four-opening-day minimum; DL-083 correlation refusal ≥ 0.40; min 20 shared calendar days; gap-free calendar enforcement | Anything on raw DXZ streams — it REFUSES them; refuses DB/farm-state (mutable) inputs; DSR; **any minimum sample size — it reports HAC ESS but enforces no floor**; **breach-upper / P2 / joint — declared INERT** | `DEFAULT_RULES` `:76-98`, `DEFAULT_BOOTSTRAP` `:100-106`, `minimum_shared_calendar_days` 20 `:116-118` enforced `:1063-1069`; mutable refusal `:251-275` enforced `:396-397,:464-465`; DXZ refusal `:1307-1308`; cost attestation `:576-585,:707-708`; HAC `:948-974` (bandwidth 59 `:953`, clamp `:972`), reported as `p1_hac` `:1147` beside `rolling_starts` `:1145` and `trace_calendar_days` `:1158`; credited decision **P1-lower only** `:1474`; INERT publication `:1480-1486` |

None of the three is a DSR engine, and none is a sealed once-only holdout by itself.

### §C.2 · The DSR / multiple-testing engine — and what its multiplicity input actually is

The Deflated Sharpe / E[max SR under the null] correction is computed by the Q08 sub-gate 8.2 engine `framework/scripts/q08_davey/sub_8_2_dsr_mc_fdr.py` (Bailey & López de Prado, ref `:22`), `GATE_NAME "8.2_dsr_mc_fdr"` (`:32`), threshold **`DSR_P_MIN = 0.05`** (`:33`), `_expected_max_sharpe` ≈ `sharpe_std·(√(2 ln N) − γ/√(2 ln N))` (`:93-100`), funnel DSR via normal cdf (`:103-143`). **This module is unchanged by P7a** (last touched `4ca8d87817`); all its anchors below were re-verified at tip.

**`declared_trial_count` is NOT `selection_trial_count`** (Review F2, unchanged in R4 and independently re-confirmed by the delivered contract at `ftmo_probability_contract.v1.json:25`):

- `selection_trial_count` is the number of configurations the evaluated one was **SELECTED FROM**, explicitly **not** the number measured; under the Plan-v2 E0-1 firewall a source-derived pre-registered predicate is selected from **1** candidate even when a census measured 154 (`sub_8_2_dsr_mc_fdr.py:40-46`).
- The lineage emitter records `selection_trial_count` as a field **distinct** from `trial_ledger_declared_count`, supplied explicitly and "never derived from, defaulted to, or collapsed into the measured trial count" (`framework/scripts/emit_q16_lineage.py:16-21`; enforced `:179-187`, emitted `:212`; test `tools/strategy_farm/tests/test_emit_q16_lineage.py:112-119` asserts the two differ).
- `DECLARED_TRIAL_COUNT = 154` (`tools/strategy_farm/opt_census.py:36`) is the DL-089 pattern-WF **census** size — a measurement count, not a selection count.
- The engine's effective-candidate rule (`sub_8_2_dsr_mc_fdr.py:161-176`): a missing, unparseable or `< 2` count leaves the fleet default `N_CANDIDATE_STRATEGIES = 369` (`:34`, `MIN_SELECTION_TRIALS_FOR_DEFLATION = 2` `:47`); an explicit count `c ≥ 2` yields `369 + c − 1` (`:176`). **Feeding 154 therefore silently means 522, not 154.** The contract loader independently refuses any contract that changes N away from 369 (`ftmo_probability_contract.py:123-124`).
- Direction of the test: the gate returns **PASS when `p_value < DSR_P_MIN`** (`:225-228`) and FAIL otherwise (`:243-245`). The correct wording is that the engine **rejects the multiple-testing null**.
- Cohort activation: with fewer than `MIN_COHORT_PEERS = 1` peers (`:54`) the gate returns a trivial PASS with deflation deferred (`:200-210`). **A trivial PASS from the deferred-deflation branch does not satisfy D.2** — see §D.2.

**The two multiplicities this test must seal, both sourced, neither invented:**

1. **Per-identity selection multiplicity** — each sealed identity's own `selection_trial_count`, read from its Q07/Q08/Q16 lineage evidence where present, consumed through the engine's unchanged effective-candidate rule (`:161-176`). Where an identity carries no trial ledger, the fleet default 369 (`:34`) applies untouched. **154 is never substituted.**
2. **Book/read-level selection multiplicity** — the number of candidate identities actually screened to arrive at the read. Existing sourced cohorts on this branch, all report-only (`:103-143`, flag `:133`):
   - `FUNNEL_DISTINCT_EAS = 3,001` (`:38`) and `FUNNEL_DISTINCT_PAIRS = 13,398` (`:39`), both sourced to the read-only farm census of the 2026-09-02 CEO audit (`:35-37`; figures reproduced at `docs/ops/CEO_AUDIT_2026-09-02.md:42`);
   - the OOS-2026 campaign screens **50 distinct (EA, symbol) pairs over 55 runs** (`run_count` 55, `live_count` 24, `frontier_count` 31; `campaign_plan.json`, read-only) — this is the multiplicity that applies if a single campaign result is read as "the positive evidence";
   - the FUND_SCORE legacy comparison population was **24** rows versus the current **8** (`docs/ops/evidence/2026-09-04_fund_score_current_population.md`), consistent with the audit's "0/24 and 0/21 for every N ≥ 10" (`docs/ops/CEO_AUDIT_2026-09-02.md:43`).

   **Which of these is the book-selection multiplicity is not a free choice made after the fact: it is recomputed from the same read-only census at seal time and stamped into the seal receipt** (§E item 9). The report-only funnel rows are recorded alongside; they never set the verdict.

Measured baseline: **0 sleeves reach DSR ≥ 0.95** at any defensible trial count (`docs/ops/CEO_AUDIT_2026-09-02.md:14`; 0/24 and 0/21 for every N ≥ 10, `:43`); E[max SR] under the null ≈ 1.06–1.44 (`:14,:42`); the modeled +2.4 book Sharpe survives correction at ≈ 0 % (`:14`); walk-forward held-out folds show 82 % PF>1 (`:14`) and 61/74 PF>1 with geo-mean OOS PF 1.47, selection-conditioned (`:45`) — leaning against zero edge but not purchase-grade.

### §C.3 · Existing sample floors (all citable, none invented)

| Floor | Value | Path (tip) |
|-------|-------|------|
| Type-I error, bootstrap | alpha = **0.05**, two-sided 95 % percentile CI | `ftmo_timebox_eval.py:103,:105`; validation `0 < alpha < 0.5` `:331-333` |
| Type-I error, DSR gate | p < **0.05** | `sub_8_2_dsr_mc_fdr.py:33` |
| Opening-day floor | ≥ **4** CE(S)T days with a position opened, per phase | rulepack `:151-160` (`:156`); enforced `challenge_firstpassage.py:76,:241`; `ftmo_timebox_eval.py:84` via rule contract, applied `:884` |
| Shared-calendar floor (correlation) | ≥ **20** shared calendar days, else `REFUSED_FEWER_THAN_20_SHARED_CALENDAR_DAYS` | `ftmo_timebox_eval.py:116-118`, enforced `:1063-1069` |
| Gap-free calendar | every stream day exactly `previous + 1`, else `REFUSED_NONIDENTICAL_OR_NONCONTIGUOUS_SHARED_CALENDAR` | `ftmo_timebox_eval.py:629-630,:723-724` |
| **DSR daily-observation floor** | ≥ **60** distinct days with trades, else **INVALID**; below **30** observations the p-value is forced to 1.0 | `sub_8_2_dsr_mc_fdr.py:182-186`; `:149-150`, `:78-79`; per-day aggregation `:58-71` |
| Bootstrap replicate minimum | ≥ **100** replicates | `ftmo_timebox_eval.py:323-327` (contract-derived floor `ftmo_probability_contract.v1.json:15`) — **computational** replication only, NOT a market-sample floor |
| Effective (not raw) n | overlapping starts are HAC-adjusted / divided by median resolution time; report ESS, never the raw start count | `ftmo_timebox_eval.py:948-974,:1147`; `challenge_firstpassage.py:415-418,:429-431` |

**No engine on this branch enforces a minimum market sample.** The evaluator computes and reports `p1_hac.effective_n` (`:1147`) but gates nothing on it (the contract states the same at `ftmo_probability_contract.v1.json:26`: `min_power_floor` is a *label*, `"single 13-week diagnostic window = UNDER_POWERED / NON_LIFTING"`, not an enforced predicate). That gap is what §C.4 closes.

### §C.4 · The predeclared power/precision rule — OPERATIONAL (Review F3 closure)

Review 2 accepted the R-1 arithmetic but refused R-2 as non-operational: R3 called it a binding "floor" without a numeric pass criterion, and inferred failure from `⌊96/60⌋ = 1` even though the evaluator's HAC ESS can range far above the disjoint-window count. **R4 makes R-2 a numeric, predeclared, seal-time-computable criterion with named authority, and states why the measured ESS alone cannot carry the floor.**

**Convention used (existing, not new).** The framework's operative uncertainty statement is a *precision* statement, not a Neyman–Pearson power statement: the decision number is the bootstrap **lower** bound (`FTMO_BOOK_SPEC:25-26,:58-61`; `ftmo_timebox_eval.py:97`), and the existing worked form of that lower bound is a Wald half-width `hw = z·√(p(1−p)/ESS)` with `z = 1.96` at two-sided 95 %, compared against the 0.80 bar (`challenge_firstpassage.py:419-420,:425,:429-431`; matching `DEFAULT_BOOTSTRAP` alpha 0.05 / `TWO_SIDED_PERCENTILE_95`, `ftmo_timebox_eval.py:103,:105`).

**R-1 · Minimum effective sample (binding).** Let `bar` be the operative P1 lower-bound bar (**0.80**, fixed by the delivered contract, §B) and `p*` the OWNER-chosen target effect (OQ-2b). The sealed holdout is adequately precise only if the evaluator's reported `p1_hac.effective_n` satisfies

```
ESS_min = ceil( z² · p*·(1 − p*) / (p* − bar)² )        with z = 1.96
```

**R-2 · Minimum sealed span (binding, numeric, computed before any result is opened).** The moving-block bootstrap's own resampling unit is the **60-calendar-day block** (`ftmo_timebox_eval.py:104` block length; `_resampled_days` draws blocks of `min(n, 60)` at `:994` from `n − block + 1` admissible starts at `:997`; `moving_block_bootstrap` rebuilds `rolling_outcomes` per replicate at `:1020-1022`). One **disjoint** 60-day block is therefore exactly one independent draw the CI can be built from. The sealed span must supply at least as many disjoint blocks as R-1 demands independent observations:

```
W_min  = ESS_min                                   (1:1 coupling — OWNER-CHOICE, OQ-2c; recommended)
D_min  = 60 · ESS_min   calendar days              (P1 only)
D_min_joint = 90 · ESS_min   calendar days         (if the two-phase gate must also be powered; 60+30 = ftmo_timebox_eval.py:79,:81)
```

**How `W_sealed` is computed at seal time — mechanically, with no judgment call.** The evaluator already reports the inclusive calendar span of the aligned trace as `trace_calendar_days` (`ftmo_timebox_eval.py:1158`), and the stream loaders guarantee it is a gap-free day-by-day series (`:629-630,:723-724`, §A rule g). Therefore:

```
D        := statistics.trace_calendar_days          (from the sealed result, no re-derivation)
W_sealed := floor( D / 60 )
PASS(R-2) iff W_sealed >= W_min   AND   D >= D_min
```

Both quantities are properties of the **sealed calendar**, fixed by the prepared config before any stream is opened. Neither can be argued after a result is seen.

**Worked values (arithmetic only; `bar = 0.80`, the contract bar):**

| p\* | ESS_min (=W_min) | D_min, P1 (days) | ≈ years | D_min, joint (days) | ≈ years |
|---|---:|---:|---:|---:|---:|
| 0.82 | 1,418 | 85,080 | 232.9 | 127,620 | 349.4 |
| 0.85 | 196 | 11,760 | 32.2 | 17,640 | 48.3 |
| 0.86 | 129 | 7,740 | 21.2 | 11,610 | 31.8 |
| 0.88 | 64 | 3,840 | 10.5 | 5,760 | 15.8 |
| **0.90 (recommended)** | **35** | **2,100** | **5.75** | **3,150** | **8.6** |
| 0.92 | 20 | 1,200 | 3.3 | 1,800 | 4.9 |
| 0.95 | 9 | 540 | 1.5 | 810 | 2.2 |

*Dominated reference only (`bar = 0.70`, the rulepack's weaker lower bound, superseded by the contract — NOT a selectable option):* ESS_min = 40 / 22 / 19 / 13 / 9 / 6 / 3 at p\* = 0.82 / 0.85 / 0.86 / 0.88 / 0.90 / 0.92 / 0.95, i.e. D_min = 2,400 / 1,320 / 1,140 / 780 / 540 / 360 / 180 days.

The rule is defined only for `p* > bar`; at `p* = bar` the half-width budget is zero and ESS_min diverges. This is why OQ-2b is a real OWNER choice and not a derivable constant.

**R-2b · Why the measured ESS alone cannot carry the floor (the reason R-2 is hard, not diagnostic).** `hac_effective_sample_size()` (`ftmo_timebox_eval.py:948-974`) has a degenerate branch: when the pass/fail flag series is constant, `gamma0 <= 0` and the function returns **`effective_n = n`, the full raw start count**, with an empty `autocorrelations` list (`:956-957`). The final value is additionally clamped up to raw `n` (`:972`). Consequence, stated before any result: a 96-day window in which **every** rolling start passes (or every one fails) reports `p1_hac.effective_n = n` — up to 96 — which would "satisfy" `ESS_min = 35` while the span contains exactly **one** disjoint 60-day block. The measured ESS is therefore fail-open in precisely the all-pass case that would otherwise look like the strongest possible evidence. Predeclared guard, mechanical:

```
IF   p1_hac.autocorrelations == []  AND  p1_hac.n > 0
THEN the reported effective_n came from the degenerate gamma0<=0 branch, is NOT a HAC estimate,
     and is replaced by W_sealed for the purposes of R-1.
```

**R-2c · Bootstrap degeneracy guard (binding, arithmetic).** Because the block length is `min(n, 60)` (`:994`), a sealed span of `D <= 60` admits exactly one block start (`randrange(0, n − block + 1)` = `randrange(0,1)`, `:997`), every replicate reproduces the original trace, and `lower == median == upper == raw rate` (`:1031-1033`). A "lower bound" produced that way is not a lower bound. **A sealed span with `D <= 60` is inadmissible outright.** Under R-2 this is automatically satisfied (the most permissive row demands 540 days), but it is stated so the rule is fail-closed on its own terms.

**R-2d · Applied to the only existing source (all arithmetic, all checkable):**

```
D = 2026-01-01 .. 2026-04-06 inclusive       = 96 calendar days
  weekdays in span                           = 68
  eligible-start days enumerated by the engine (rolling_outcomes :898-902)
        = every day flagged eligible_start, up to 96 -- NOT 96-60+1
  of those, starts with a COMPLETE 60-day horizon = 96 - 60 + 1 = 37
  of those, RIGHT-CENSORED starts (truncated horizon, forced TIMEOUT :891-895, rule :94) = 59
  disjoint 60-day P1 blocks   W_sealed = floor(96/60) = 1
  disjoint 60+30 gauntlets              = floor(96/90) = 1
  bootstrap block length      = min(96,60) = 60 ; blocks per replicate = ceil(96/60) = 2
  distinct block start positions        = 96 - 60 + 1 = 37
```

**One.** At the recommended `p* = 0.90` / `bar = 0.80`, R-2 demands `W_min = 35` and `D_min = 2,100`; the window supplies `W_sealed = 1` and `D = 96`. It is short by a factor of **35** in blocks and **21.9** in days. This now *follows* from a predeclared numeric criterion instead of being asserted. **R3's "37 rolling starts" figure was itself wrong for this engine** and is corrected above: 37 is the count of *full-horizon* starts, while `rolling_starts` (`:1145`) counts every eligible day and therefore includes up to 59 structurally-non-passing censored starts.

**R-3 · DSR observability floor (binding, existing authority).** D.2 is only evaluable if each sealed identity supplies ≥ 60 distinct trading days in the holdout (`sub_8_2_dsr_mc_fdr.py:182-186`), and its p-value is meaningful only above 30 observations (`:149-150,:78-79`). A 96-calendar-day span offers at most 68 weekday sessions; seven of the eight sealed identities are D1 bar-open entries that do not trade daily, so the 60-day floor is expected to bind. **An identity that returns INVALID at sub-gate 8.2 has not passed D.2 and must not be scored as if it had.**

**R-4 · Seeds do not widen the population.** Additional bootstrap seeds resample the same market observations and test Monte-Carlo stability only; they add no independent market data and cannot satisfy R-1 or R-2. Only **additional disjoint sealed windows or a longer sealed OOS span** widen the evidence population. "Multi-seed" is removed as a widening option throughout this contract.

**R-5 · Optional explicit power form (OWNER-CHOICE, not required).** If OWNER prefers a Neyman–Pearson statement with an explicit type-II error, the same quantities give

```
ESS = ( z_α·√(bar(1−bar)) + z_β·√(p*(1−p*)) )² / (p* − bar)²
```

with `z_α = 1.96` (existing, `challenge_firstpassage.py:419-420` / `ftmo_timebox_eval.py:103,:105`). `z_β` has **no existing authority on this branch** — choosing it is a new statistical constant and therefore ROT. Illustrative values at power 0.80 (`z_β = 0.8416`) and 0.90 (`z_β = 1.2816`), with the R-2 span each would imply:

| bar → p\* | power 0.80 (ESS / D_min) | power 0.90 (ESS / D_min) |
|---|---|---|
| 0.80 → 0.90 | 108 / 6,480 d | 137 / 8,220 d |
| 0.80 → 0.92 | 72 / 4,320 d | 89 / 5,340 d |
| 0.80 → 0.95 | 42 / 2,520 d | 51 / 3,060 d |
| 0.70 → 0.85 *(dominated bar)* | 64 / 3,840 d | 82 / 4,920 d |
| 0.70 → 0.90 *(dominated bar)* | 34 / 2,040 d | 42 / 2,520 d |

**Recommendation: adopt R-1 + R-2 (precision form) and do NOT adopt R-5**, because R-1/R-2 need no constant that does not already exist in the codebase, whereas R-5 requires OWNER to mint `z_β`. R-5 is offered only so the choice is visible rather than hidden.

**R-6 · Cost of the chosen bar — now a consequence of R-2, not a separate anchor.** In R3 the ≈ 2,100-day figure was labelled "context only, explicitly not a threshold". With R-2 operational it **is** the threshold at the recommended `p*`. Stated plainly so the price is visible before ratification: certifying a true P1 pass rate of 0.90 against a 0.80 bar requires **≈ 5.75 years of sealed OOS** (≈ 8.6 years if the two-phase gate must also be powered). If OWNER finds that unacceptable, the honest levers are (i) raise `p*` — `p* = 0.95` costs 540 days ≈ 1.5 years; (ii) loosen the R-2 coupling from 1:1 (OQ-2c) and accept the R-2b fail-open risk explicitly; or (iii) accept that FTMO admission is not reachable on OOS evidence alone and re-anchor the trigger. All three are OWNER decisions; none is a silent relaxation. The `bar = 0.70` route is **no longer available** — the contract dominates it away (§B).

## §D · Refutation clause (predeclared, symmetric — evaluated ONCE after the seal)

### §D.0 · Inertness and its honest consequence (Review 2 new blocker — this is the alignment)

The delivered probability contract declares three of §D.1's gate criteria — carried in two conjunct rows (D.1.c, D.1.d) — **INERT**:

- **breach upper-95** — `enforcement_status: INERT_UNTIL_C6_ENGINE_OWNER_APPROVED` (`ftmo_probability_contract.v1.json:20`). MC produces breach only as a **lower** bound (`ftmo_p1_mc.py:30-31`); no engine estimates an admissible upper bound and **no estimator method is defined** (`docs/ops/FTMO_PROBABILITY_CORRELATION_CONTRACT_V1_2026-09-05.md:40,:79`).
- **P2-conditional and joint** — same status (`ftmo_probability_contract.v1.json:21`). The evaluator computes `joint_rate` (`ftmo_timebox_eval.py:1150`) and a P2 leg, but credits **only** `p1_bootstrap['lower']` (`:1474`); no joint-credit formula exists (`docs/ops/FTMO_PROBABILITY_CORRELATION_CONTRACT_V1_2026-09-05.md:81`).
- The loader **refuses to load any v1 contract that activates either gate** (`ftmo_probability_contract.py:117-120`), and every evaluation result republishes the status with the sentence "breach/P2/joint cannot pass or fail this result until C-6 is OWNER-approved" (`ftmo_timebox_eval.py:1480-1486`).

**These three gates are declared NECESSARY conditions of D.1 and are simultaneously unable to pass or fail.** That is not a contradiction to be smoothed over; it is the state of the system, and this test records it rather than assigning decisive meaning to an unestimable number. The honest consequence, ratified together with the rest:

> **While criteria 5 and 6 are INERT, D.1 cannot be satisfied, and therefore this acceptance test CANNOT lift NO-BUY — regardless of how good a measurement is.** No measured result, however strong, converts an inert gate into a passed gate. NO-BUY can only become liftable after the C-6 estimator is (a) method-specified, (b) OWNER-scoped, (c) implemented, and (d) OWNER-approved — **or** after a dated OWNER decision that lawfully changes the status of criteria 5/6 (e.g. removing them from the necessary set, which is a ROT gate-criteria change and is **OQ-9**).

R3's formulation — "§D is INERT until BOTH parts of OQ-2 are resolved" — was incomplete: answering OQ-2a/2b would have made §D operative while three of its conjuncts remained unestimable. The corrected condition:

> **§D is INERT until ALL of:** (i) OQ-2a is resolved (admissible market population), (ii) OQ-2b is resolved (target effect `p*`, from which ESS_min and D_min follow by §C.4), **and** (iii) the C-6 breach/P2/joint estimator is method-specified, implemented and OWNER-approved under the versioned probability contract — or OWNER has lawfully changed the status of criteria 5/6 by dated decision.

The contract asserts that its INERT status and this Vorlage's §D inertness are "identical" (`docs/ops/FTMO_PROBABILITY_CORRELATION_CONTRACT_V1_2026-09-05.md:277`). Under R3 they were **not** identical — R3's inertness would have lifted on OQ-2 alone. Under R4 they are, and that is the change this section makes.

### §D.1 — a valid post-repair OOS pass

On the corrected window (E1 Option A applied per receipt row 9; hole backfilled; E4 `--apply` executed per row 11; window-binding verified plan → INI → report identical), evaluated at the timebox 60/30-day horizons (`ftmo_timebox_eval.py:79,:81`) via the moving-block-bootstrap **LOWER** bound (`:97,:103,:105`), meeting **all** of — with each conjunct's current enforceability marked:

| # | Conjunct | Status |
|---|----------|--------|
| D.1.a | **Power/precision:** the sealed span satisfies §C.4 R-2 (`W_sealed >= W_min` AND `D >= D_min`, computed from `trace_calendar_days` `:1158`), `D > 60` per R-2c, AND the evaluator's reported `p1_hac.effective_n` (`:1147`) ≥ `ESS_min(p*, 0.80)` per R-1, with the R-2b degenerate-ESS substitution applied | **ACTIVE** |
| D.1.b | **P1 lower-95 ≥ 0.80** — the contract's single binding gate (`ftmo_probability_contract.v1.json:19`; `build_book_ftmo.py:59-61,:476`; `ftmo_timebox_eval.py:97`). Point ≥ 0.80 follows automatically (`build_book_ftmo.py:474`) and adds nothing | **ACTIVE** |
| D.1.c | **breach upper-95 ≤ 10 %** (rulepack `:486`) | **INERT** — cannot pass or fail (`ftmo_probability_contract.v1.json:20`) |
| D.1.d | **P2-conditional ≥ 85 % AND joint ≥ 65 %** (rulepack `:492`) | **INERT** — cannot pass or fail (`...json:21`) |
| D.1.e | **The four non-probability evidence criteria:** snapshot freshness ≤ 7 days (`:462`), 0 unadjudicated execution-fidelity mismatches (`:468`), complete intratrade MTM with closed-P&L proxy forbidden (`:474`), ≥ 1 clean Free-Trial/shadow run with 0 operational defects (`:498`) | **ACTIVE** |
| D.1.f | **Cost class:** the streams are `DXZ_EXECUTION_FTMO_COST_ADJUSTED_V1` under an explicit declaration, not raw DXZ (`ftmo_timebox_eval.py:54,:707-708,:1307-1312`), evaluated at the conservative end of the spread-penalty band (`FTMO_BOOK_SPEC:58-61`) | **ACTIVE** |
| D.1.g | **Necessary screen (not the bar):** net expectancy after FTMO costs > 0, with failures/zeros retained and missingness documented (`docs/ops/evidence/2026-09-04_astra_ftmo_book_analysis.md:130`). A break-even or positive window that does NOT clear the criteria above does NOT lift NO-BUY | **ACTIVE** |

**D.1 is met only when every row is met. Two rows cannot currently be met by any measurement (§D.0). D.1 is therefore presently unsatisfiable, and this is a property of the system, not of the data.** An evaluation may still be run and recorded — it just cannot be reported as "D.1 met".

### §D.2 — the DSR / multiple-testing correction rejects the null

Sub-gate 8.2 returns PASS, i.e. `p_value < DSR_P_MIN = 0.05` (equivalently DSR probability > 0.95) (`sub_8_2_dsr_mc_fdr.py:33,:225-228`), computed with:

- each identity's **sealed `selection_trial_count`** from its Q07/Q08/Q16 lineage, consumed through the engine's unchanged effective-candidate rule — fleet default 369 when missing or `< 2`, otherwise `369 + c − 1` (`:34,:47,:161-176`);
- **the 154 measured census arms are NOT substituted for selection multiplicity** (`:40-46`; `emit_q16_lineage.py:16-21`; `opt_census.py:36` is a measurement count; contract `ftmo_probability_contract.v1.json:25`);
- the sealed book/read-level multiplicity of §C.2 item 2, recomputed at seal time, reported alongside with the engine's report-only funnel rows (`:38-39,:103-143`);
- at least 60 distinct trading days per identity, else the gate returns INVALID and D.2 is **not met** (§C.4 R-3, `:182-186`);
- **a PASS from the deferred-deflation branch does not count.** With `n_peers < MIN_COHORT_PEERS = 1` the gate returns a trivial PASS with deflation deferred (`:54,:200-210`). That branch performs no multiple-testing correction, so it cannot satisfy a criterion whose entire purpose is the correction. Predeclared: **D.2 is met only by a PASS from the deflating branch (`:221-228`), never by the deferred branch.**

In-sample PF>1 is never a substitute for D.2.

### §D.3 — supporting input, never sufficient, never able to lift or block alone

Governed-only live attribution (manual `magic=0` trades excluded, receipt row 1 `:8`) is reported alongside with its stated uncertainty. Decisive weight rests on D.1 and D.2. Rationale: governed live is −469 USD / 30 days with Sharpe CI [−6.8, +4.6] — statistically non-informative at this sample (`docs/ops/CEO_AUDIT_2026-09-02.md:14`). Its minimum informative sample and any numeric positive bar are **OQ-5, unresolved**; until then it is corroborative context, not a gate.

### §D.4 — NO-BUY is KEPT (the lift is refuted) if ANY of:

- **criteria 5 or 6 are still INERT** (today: both) — see §D.0;
- OQ-2a, OQ-2b or OQ-2c is unresolved, or the admissible source fails the §C.4 R-1 / R-2 / R-2c floors;
- the reported ESS came from the degenerate `gamma0 <= 0` branch and the R-2b substitution leaves `W_sealed < W_min`;
- any sealed identity fails the §C.4 R-3 DSR observability floor (sub-gate 8.2 INVALID), or D.2's PASS came from the deferred-deflation branch;
- **the sealed roster is not fully read** — e.g. 11910:NZDUSD returns no result — other than in the manner predeclared under OQ-6;
- a fresh `PASS` for another year (e.g. 2024) re-appears — proves the dispatch repair failed;
- the OOS window still measures inside the calendar hole (no news events), i.e. E1 Option A or the backfill did not actually land;
- the streams are raw DXZ rather than FTMO-cost-adjusted, or the evaluator returns any `REFUSED_*` label;
- any date, model, identity, cost-profile or window substitution occurs after the seal;
- any ACTIVE conjunct of D.1 is not met, including net expectancy after FTMO costs ≤ 0;
- the DSR correction does not reject the null at p < 0.05, or the multiplicity actually used is the 154 measured arms rather than a sealed selection count;
- **passing the 25-pair counter alone** — explicitly NOT sufficient to lift NO-BUY.

The cheapest decisive test remains a valid, adequately-powered post-repair OOS pass; the ~55-run / ~3-terminal-hour single-window probe (`docs/ops/CEO_AUDIT_2026-09-02.md:45`) is a diagnostic toward it, not itself the lift source.

## §E · Contamination and seal procedure

**Contamination (predeclared — any one voids the evaluation):**

1. **Look-ahead / mutable input** that changes under evaluation. Precedent: an EV script read a mutable stream dir that shrank from 21 → 5 sleeves, throwing results ≈ 16× off (`docs/ops/CEO_AUDIT_2026-09-02.md:15,:56`). `ftmo_timebox_eval.py` SHA-pins every declared input and REFUSES DB/farm-state references (`:251-275`, enforced `:396-397,:464-465`).
2. **Roster/identity change after results are seen**, including a silent partial read of the sealed 8 (§A rule e).
3. **Calendar re-run, window substitution, or cost-profile substitution after the seal.**
4. **Refitting** leverage/overlay/composition on the scoring sample (`challenge_firstpassage.py` stages 1–2 are in-sample-selected and must NOT be used as the acceptance number; only the preregistered 1x block `:381-388` is selection-free).
5. **Evaluator-code change after the seal.** Demonstrated twice. (i) R2's quoted `ftmo_timebox_eval.py` digest was the working copy of the parent commit `5bac8eaccb^`; the tip commit then modified the module. (ii) P7a (`f68ce8f338`) changed the module **again**, together with `build_book_ftmo.py`, `ftmo_p1_mc.py` and `challenge_firstpassage.py`. `prepare-config` pins inputs, not code (`:461-533`) — which is why item 5 seals the module bytes.
6. **Probability-contract change after the seal — NEW in R4, and not covered by `prepare-config`.** `PROBABILITY_CONTRACT = load_probability_contract()` executes at **module import** (`ftmo_timebox_eval.py:72`), and `DEFAULT_RULES` / `DEFAULT_BOOTSTRAP` / `DEFAULT_CORRELATION` / `INERT_C6_GATES` are built from it (`:76-125`) — including the design bar itself (`:97`). An edit to `ftmo_probability_contract.v1.json` therefore changes the decision bar with an **unchanged config SHA**. The result does stamp `probability_contract.sha256` (`:1482`), so the change is detectable *after the fact* — but only if the seal recorded the expected value. Items 15–16 close this.

**Digest convention (binding, and now demonstrated rather than asserted).** All seal digests are SHA-256 over **LF-normalized bytes** — verified in R4 to equal the git blob content (`git cat-file -p HEAD:<path> | sha256sum` reproduces the LF digest exactly). The working-copy digest is recorded beside it and is **never** the seal identity, because it is checkout-dependent:

> **Two-checkout evidence.** For the identical commit, `C:\QM\repo` and this agent worktree produce **different working-copy digests** for the same four P7a modules while producing **identical LF digests**. Example: `ftmo_timebox_eval.py` → working copy `7282d2b62696b5cfa721e58bcf0867e000e5a9fa3faee459ef3fe35a7e20913e` (main checkout, the value the second review quoted) vs `d04c7fe6dd26acea9fa26add007ef7d9cbd925af6f386d07bf7d9b2e0577c0a3` (this worktree) — LF `c3b2fcd8f00aa28293c67384efff9faa606b8cdb4a4d892356a49b66607c3d20` in both. The same holds for `build_book_ftmo.py`, `ftmo_p1_mc.py` and `challenge_firstpassage.py`. **A seal quoting working-copy digests is not portable; only the LF digest is.**

> **Corollary that touches the engine itself.** `load_probability_contract()` hashes the file's **raw on-disk bytes** (`ftmo_probability_contract.py:147`) and the evaluator stamps that value into every result (`ftmo_timebox_eval.py:1482`). `ftmo_probability_contract.v1.json` is not listed in `.gitattributes` as `-text` (unlike the repo's other raw-byte contracts), so it is LF in `C:\QM\repo` and CRLF in this worktree, and the stamped digest differs accordingly: `54cb80fd…` vs `7328b8b1…`. **The seal therefore records the LF digest as authoritative AND names the canonical runtime host (`C:/QM/repo`) as the path whose raw bytes the engine will stamp.** Normalizing the file via `.gitattributes` is the durable fix and is raised as **OQ-11** (a code/config change, out of scope for this document).

**Seal procedure — before the first result is opened, compute and record a sha256 over each of the following.** Items 5–8 were the Review-F5 extension; **items 15–18 are the R4 extension** binding the delivered P7a dependencies. All digests below were recomputed at tip `fb719e703a`; **LF is authoritative, working copy is the parenthetical.**

| # | Sealed input | Path / digest (LF authoritative) |
|---|--------------|-------------|
| 1 | This contract text (R4) | `docs/ops/OWNER_VORLAGE_2026-09-05_ftmo_positive_evidence_test.md` — digest computed on the ratified bytes |
| 2 | The roster of the 8 identities with their exact stream SHA-256s | `docs/ops/evidence/2026-09-04_fund_score_current_population.md:24-31` (digests reproduced in §A) |
| 3 | Rulepack FILE sha256 `298ef1285eca49ea7f010ebc0a9353b5a821fccb40a025be129f5ca5314fd992` (LF-only file; worktree digest identical) | `tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_SWING_V2.json` — encodes the `go_criteria` numbers (`:462/:468/:474/:480/:486/:492/:498/:504`) and `lifecycle_status` (`:9`) |
| 4 | Provider snapshot `snapshot_sha256` `c199b8f5f528cce5a93f4751f63394de63e5fe832483ac9c4b9d0314732d2905` (LF-only file; identical both ways) | embedded at rulepack `:24`; the page-body snapshot, distinct from item 3 |
| 5 | **Evaluator module** `tools/strategy_farm/portfolio/ftmo_timebox_eval.py` — LF `c3b2fcd8f00aa28293c67384efff9faa606b8cdb4a4d892356a49b66607c3d20` (worktree `d04c7fe6…`) | 1,560 lines; resampling, outcomes, HAC, refusals, INERT publication |
| 6 | **Supporting engines** — LF digests: `ftmo_p1_mc.py` `a4a0a841377083b60bbd5e6da0269920ee395ac3fc452fcbb853c500a559f928`; `challenge_firstpassage.py` `7ff679d6b5afb0d1c440e3fd5c4061ea2e648177110d9d564cd04d543a824cee`; `ftmo_rules_engine.py` `2c79ccd274d00bc1d1c5299c9700cf3ff51185429b99acb5a32497d90f5e7e51`; `ftmo_rule_contract.py` `02adb2ebe566e142ef7e5cb7e22873c365f76f305ff688f94a27fc9264373aad` | the first two were changed by P7a; the last two are unchanged (their R3 values were the working-copy form) |
| 7 | **Builder** `build_book_ftmo.py` LF `f371632eeaca5e6bb5b6136680339349ae19ce40c46c68364b6fed9b76ff99d8`; **scorer** `fund_score.py` LF `cb9c3989923f4370bfb30d8f46b18547afa65414db81f354b8eda5026dd23a56`; **counter** `book_build_guard.py` LF `e3ba47378a605848db2694ba662b64e0eb9a31df1fcab7849e4e0fe66d2f6015` | floors `:58,:59-61`; formula `:94-103`; counter `:28,:236-238` |
| 8 | **DSR engine + multiplicity provenance** — LF digests: `sub_8_2_dsr_mc_fdr.py` `906bef88c9d903c7dccdc01a60a4a9e65c0fcd70ca99879836dd35ac354e8fe1`; `emit_q16_lineage.py` `177313cb0fc58b4f8468a6e0c5d981493beec860c07a2ef28f44405edbd2237f`; `opt_census.py` `1c0ffccd63657611c897b880521332f4135bf3ad5b768afe8b45c5f6f485ebce` | threshold `:33`, effective-count rule `:161-176`; all three unchanged by P7a |
| 9 | **The DSR multiplicity inputs themselves**: every per-identity Q07/Q08/Q16 lineage artifact carrying `selection_trial_count`, by path + sha256; and the book/read-level selection count of §C.2 item 2, recomputed read-only at seal time and stamped with its census timestamp | the value must exist in the receipt BEFORE any result is opened |
| 10 | **The prepared config**: output of `ftmo_timebox_eval.py prepare-config`, by sha256 | pins inventory, fund_scores, cost snapshot, streams and rulepack (`:461-533`) — but **neither the evaluator nor the probability contract**, hence items 5 and 15 |
| 11 | **The exact FTMO cost snapshot** actually consumed, by path + sha256, and its declared class | `DEFAULT_COST_SNAPSHOT` `build_book_ftmo.py:48`, expected digest `:54`; accepted stream class `ftmo_timebox_eval.py:54` |
| 12 | **The concentration/tail policy** `concentration_tail_limits.v1.json` — LF `ef8b10ec564e21863d8ca3706535d1af21b173c1aff15baa771bb82192890d17` (worktree `77a3b673…`, the R3 value) | `status OWNER_RATIFIED` `:3` |
| 13 | **The calendar bundle sha AFTER the E1 Option A repair and the 2025-05..2026-06 backfill**, plus the new bundle identity and repin | receipt rows 9 / 11 (`:18,:20`) |
| 14 | **The resolved OQ answers**: OQ-2a population, OQ-2b `p*`, OQ-2c coupling, and the resulting `ESS_min` / `W_min` / `D_min`; OQ-6 roster-gap handling; OQ-7 cost class; OQ-9 C-6 disposition | recorded as literal values in the receipt, not as references to a pending decision |
| 15 | **Probability contract JSON** `tools/strategy_farm/config/ftmo_probability_contract.v1.json` — LF `54cb80fd4623a8a08d792c0d15b347f7999a7ff3565d373121e01dba3bef7e27` (this worktree's CRLF copy `7328b8b1…`) plus the contract `schema` and `status` strings (`:2,:3`) | **the source of the design bar, horizons, bootstrap params, correlation caps and the INERT statuses**; loaded at evaluator import (`ftmo_timebox_eval.py:72`) and NOT pinned by `prepare-config` |
| 16 | **Contract loader** `tools/strategy_farm/portfolio/ftmo_probability_contract.py` — LF `a8596709844e61d0129da563fd1a6922f6465c973c4b4de5f21c90adb0902805` (worktree `02489acc…`) | enforces C-6 inertness `:117-120`, the 0.80 P1 bound `:121-122`, DSR N = 369 `:123-124`, rulepack parity `:126-143` |
| 17 | **V4 Layer-A correlation producer** `tools/strategy_farm/portfolio/portfolio_correlation.py` — LF `4b3c2888954b6b35170396369c617bffec0d4bddb384c60601a8233499dd26c1` (worktree `fb7cc3b4…`) — **and the correlation artifact it produced**, by path + sha256 | the builder now admits only `CERTIFY_A` pairs and consumes `abs_upper` (`build_book_ftmo.py:146-204`); Layer-A logic `:57-63,:74-77,:87-88,:485-502` |
| 18 | **The probability/correlation contract document** `docs/ops/FTMO_PROBABILITY_CORRELATION_CONTRACT_V1_2026-09-05.md` — LF `e25eceb81dc24a815ec7944b225b92a67f56b88ca5420cdeaf7bc48ca6f611ee` (worktree `72407aae…`) | the ratification instrument for C-1 (P1 bar) and C-6 (inertness) that §B and §D.0 depend on |

Then: run `ftmo_timebox_eval.py prepare-config` so the evaluator input digest is frozen; **OWNER (sole human authority) signs the sealed contract**; write the once-only evaluation receipt AFTER the seal. Any change to items 1–18 after signature voids the evaluation and requires a new seal.

**Who signs:** OWNER only. This is a ROT purchase-adjacent decision; automatic purchase is forbidden (rulepack `:500-505`); T_Live / AutoTrading / deployment stay separate OWNER ceremonies.

## §F · Decision receipt — amend the EXISTING pending row 18 in place

Receipt row 18 already exists and is PENDING (`decisions/2026-09-02_owner_receipts_ceo_asks.md:28`). **Do not append a new row or a second row 18.** Replace the Effect cell of row 18 with:

> Seals population (8 identity-bound Q08 streams, roster + stream SHA-256 in §A), metric+thresholds (the **seven** rulepack evidence criteria `:462/:468/:474/:480/:486/:492/:498` — the eighth `:504` stays the separate signed purchase ceremony — builder floors `:58/:59-61`, FUND_SCORE, concentration, timebox 60/30 lower-bound with the delivered contract's **single binding gate P1 lower-95 ≥ 0.80** (`ftmo_probability_contract.v1.json:19`, point ≥ 0.80 non-additive/dominated), DSR p<0.05 over the **sealed per-identity `selection_trial_count`** — never the 154 measured census arms, and never the deferred-deflation PASS), the **operational power/precision rule** (§C.4: `ESS_min = ceil(1.96²·p*(1−p*)/(p*−0.80)²)` on `p1_hac.effective_n`, PLUS the binding non-overlap floor `W_sealed = floor(trace_calendar_days/60) ≥ ESS_min` i.e. `D ≥ 60·ESS_min` — at the recommended p\*=0.90 that is 35 disjoint windows / 2,100 sealed calendar days; plus the degenerate-ESS substitution, the `D>60` bootstrap-degeneracy guard and the 60-trading-day DSR floor; the single 96-day window supplies W=1 and is short by 21.9×), admissible evidence class (post-repair OOS-2026 after E1 Option A + backfill per rows 9/11, FTMO-cost-adjusted streams only, governed-only live SUPPORTING not sufficient, no re-selection, predeclared roster-gap handling for 11910:NZDUSD), the extended seal (§E items **1–18**, incl. evaluator, DSR multiplicity inputs, **the versioned probability contract JSON + its loader + the V4 Layer-A producer**, LF-normalized digests authoritative); and the symmetric refutation clause. **§D is INERT until OQ-2a, OQ-2b, OQ-2c AND the C-6 breach/P2/joint estimator are resolved — consequence stated explicitly: while criteria 5/6 are INERT this test cannot lift NO-BUY by any measurement (§D.0).** ROT (purchase-adjacent), no Auffangregel; lifting NO-BUY still requires a separate signed OWNER purchase decision.

Row 18 keeps its class: ROT, no Auffangregel.

## §G · Anchor re-verification at tip `fb719e703a` (Review 2 F5/F6 closure)

**Method.** Every operative citation in R3 was re-checked line-by-line on the current tip. P7a (`f68ce8f338`) touched `build_book_ftmo.py`, `challenge_firstpassage.py`, `ftmo_p1_mc.py`, `ftmo_timebox_eval.py` and added `ftmo_probability_contract.v1.json` + `ftmo_probability_contract.py`. **All anchors in those four modules shifted; every anchor outside them was re-verified as still correct.**

**Verified correct and unchanged at tip** (no edit needed): all rulepack anchors incl. the eight `go_criteria` blocks `:458-463/:464-469/:470-475/:476-481/:482-487/:488-493/:494-499/:500-505` and their parameter lines, `:24`, `:156`, `:254-260/:259`, and the file digest `298ef128…`; provider snapshot `c199b8f5…` and `:724-725,:728-729,:808-816,:824`; all `sub_8_2_dsr_mc_fdr.py` anchors (`:22,:32,:33,:34,:38,:39,:40-46,:47,:54,:78-79,:93-100,:103-143,:149-150,:161-176,:182-186,:200-210,:225-228,:243-245`); `emit_q16_lineage.py:16-21,:179-187,:212` + test `:112-119`; `opt_census.py:36`; `fund_score.py:94-103`; `book_build_guard.py:28`; all `concentration_tail_limits.v1.json` line refs incl. `:34,:35`; `FTMO_BOOK_SPEC:13,:15,:19,:25-26,:58-61`; `CEO_AUDIT:14,:15,:42,:43,:45,:56`; receipt rows `:8,:11,:13,:16,:18,:20,:24,:28`; the evidence-doc anchors in `2026-09-04_astra_ftmo_book_analysis.md` and `2026-09-05_news_calendar_timestamp_defect.md`.

**Corrected in R4:**

| R3 anchor / claim | Status at tip `fb719e703a` | R4 |
|---|---|---|
| `build_book_ftmo.py:53` FUND_SCORE floor | now `:58` | corrected §B |
| `build_book_ftmo.py:54` P1 lower floor | now `:59-61`, **contract-derived** | corrected; provenance noted |
| `build_book_ftmo.py:75/:76/:77` corr / budget / unit weight | now `:82-85 / :86-88 / :89-92`, all contract-derived | corrected |
| `build_book_ftmo.py:45/:51` cost snapshot + digest | now `:48 / :54` | corrected §E item 11 |
| `build_book_ftmo.py:68-69` DL-083 comment | now `:75-76`; the 0.40 is actually enforced in `ftmo_timebox_eval.py:112-114`, applied `:1115-1117` | corrected + enforcement site named (the contract JSON's `:30` still says `:1092` — stale, OQ-11) |
| `build_book_ftmo.py:80-81` ratification stamp | now `:95-96` | corrected |
| `build_book_ftmo.py:471/:472` min_sleeves / min_active_days | now `:503 / :504` | corrected |
| `build_book_ftmo.py:498-506` risk-mode check | now `:531-535` (raise `:533-535`) | corrected |
| `ftmo_timebox_eval.py:50` accepted cost class | now `:54` | corrected |
| `ftmo_timebox_eval.py:69-91` DEFAULT_RULES; `:72/:74` horizons; `:90` design bar | now `:76-98`; `:79/:81`; `:97` — all contract-derived | corrected |
| `ftmo_timebox_eval.py:93-99` DEFAULT_BOOTSTRAP (`:94-98`) | now `:100-106` (`:101-105`) | corrected |
| `ftmo_timebox_eval.py:105` shared-day floor, enforced `:1043-1046` | now `:116-118`, enforced `:1063-1069` | corrected |
| `ftmo_timebox_eval.py:77` opening-day floor | now `:84`, applied `:884` | corrected |
| `ftmo_timebox_eval.py:56,:686-693` cost attestation | now `:576-585,:707-708` | corrected |
| `ftmo_timebox_eval.py:233-258,:375-376,:443-444` mutable refusal | now `:251-275`, enforced `:396-397,:464-465` | corrected |
| `ftmo_timebox_eval.py:306-307` replicate floor; `:310-312` alpha validation | now `:323-327`; `:331-333` | corrected |
| `ftmo_timebox_eval.py:482-501` prepare-config pinning | now `:461-533` | corrected |
| `ftmo_timebox_eval.py:927-953` HAC (bandwidth `:932`, `effective_n` `:951`) | now `:948-974` (bandwidth `:953`, clamp `:972`, degenerate branch `:956-957`) | corrected + the degenerate branch is now load-bearing (§C.4 R-2b) |
| `ftmo_timebox_eval.py:1124/:1126` rolling_starts / p1_hac | now `:1145 / :1147`; `trace_calendar_days` `:1158` added as the R-2 input | corrected |
| `ftmo_timebox_eval.py:1286-1290` DXZ refusal | now `:1307-1308`, explicit-declaration requirement `:1310-1312` | corrected |
| *(absent in R3)* INERT publication, credited-lower-only | new at `:1474`, `:1480-1486` (`inert_gates` `:1484`) | added; drives §D.0 |
| `ftmo_p1_mc.py:79/:80/:81` horizon / paths / seed | now `:82-83 / :91 / :92`; `DIAGNOSTIC_ONLY` `:85`, bias note `:86-89`, stamped `:922` | corrected |
| `challenge_firstpassage.py:32-33,:68,:176` four-day | now `:33,:76,:183-184,:241` | corrected |
| `challenge_firstpassage.py:371-377` prereg 1x; `:405-408,:409-410,:415,:419-421` ESS/Wald | now `:381-388`; `:415-418,:419-420,:425,:429-431` | corrected |
| "all eight `go_criteria` in D.1" | criterion 8 is the purchase ceremony, not evidence (rulepack `:503`) | reworded to **seven evidence criteria** throughout (Review 2 F4) |
| "R-2 is a binding non-overlap floor; the single window structurally fails every ESS_min row" | did not follow from `⌊96/60⌋ = 1`, since HAC ESS is clamped up to raw n (`:972`) | §C.4 R-2 is now a **numeric predeclared criterion** with its own authority; the inference is replaced by `W_sealed ≥ W_min` (Review 2 F3) |
| "rolling 60-day starts = 96 − 60 + 1 = 37" | wrong for this engine: `rolling_outcomes` (`:898-902`) enumerates every eligible day; 37 is the *full-horizon* subset, 59 are right-censored | corrected §C.4 R-2d |
| "§D inert until BOTH parts of OQ-2" | incomplete: would make §D operative while criteria 5/6 remain unestimable | §D.0 adds the C-6 condition and states the lift consequence |
| "pending P7a … intersection applies" (§B, OQ-1) | P7a delivered at `f68ce8f338`; single binding gate `lower_95 ≥ 0.80` | §B rewritten; OQ-1 retired to a confirmation |
| Seal items 5–8 / 12 digests | quoted the **working-copy** form, contradicting §E's own "LF authoritative" rule; the four P7a modules also changed bytes | all recomputed LF-first; §E now carries two-checkout evidence |
| Seal list = 14 items | missed the contract JSON, its loader, the V4 Layer-A producer and the contract document | extended to **18** items |

---

## Open questions for OWNER (do not resolve unilaterally)

- **OQ-1 — RETIRED to a confirmation (= decision Q3).** P7a is delivered (`f68ce8f338`). The binding P1 gate is **`lower_95 ≥ 0.80`, single** (`ftmo_probability_contract.v1.json:19`, enforced `ftmo_probability_contract.py:121-122`); rulepack point ≥ 80 % is non-additive/dominated, rulepack lower ≥ 70 % is dominated (`build_book_ftmo.py:474`). Behaviourally identical to R3's intersection. **Open only in this sense:** the contract carrying that resolution is itself `PENDING_OWNER_RATIFICATION` (`:3`). *Recommendation: confirm the contract's C-1 resolution; no new number, no arbitration.*
- **OQ-2a (population, GATES §D).** Accept the single corrected 96-day window as the positive-evidence source, or require a sealed OOS span satisfying §C.4 R-2? Per R-2d the window supplies `W_sealed = 1` against `W_min = 35` at the recommended `p*`. **Multi-seed is explicitly not an option** (R-4). *Recommendation: require the longer sealed span; the single window stays a diagnostic.*
- **OQ-2b (target effect `p*`, GATES §D). OWNER-CHOICE.** Which true P1 pass probability must the test be able to certify? `ESS_min`, `W_min` and `D_min` follow arithmetically from `p*` at the fixed bar 0.80 (§C.4 R-1/R-2 tables). *Recommendation: `p* = 0.90` → ESS_min 35 → 2,100 sealed calendar days ≈ 5.75 years (3,150 d ≈ 8.6 y if the two-phase gate must also be powered). If that span is unacceptable, `p* = 0.95` → 9 → 540 days ≈ 1.5 years is the next defensible row; do not lower the bar instead, it is contract-fixed.*
- **OQ-2c (coupling of R-2, NEW in R4). OWNER-CHOICE.** Bind `W_min = ESS_min` 1:1 (recommended — the bootstrap's own resampling unit is the 60-day block, `ftmo_timebox_eval.py:994-998,:1020`), or keep R-2 diagnostic and rely on the measured HAC ESS alone? The latter is fail-open: a constant flag series returns `effective_n = n` from the `gamma0 <= 0` branch (`:956-957`), so an all-pass 96-day window would report ESS up to 96 and "clear" ESS_min 35 on one disjoint block. *Recommendation: 1:1 coupling, with the R-2b substitution as the guard.*
- **OQ-4 (provider).** Swing leverage 1:30 FX / 1:15 metals+oil is CARRIED_OVER and was NOT re-confirmed on 2026-09-04 (`docs/ops/evidence/2026-09-04_ftmo_official_rules_snapshot.json:724-725,:728-729`; dead URL `:808-816`; scope limit `:824`). Must be re-sourced before any purchase-adjacent decision.
- **OQ-5 (live weighting). OWNER-CHOICE.** Governed-only live is −469 USD / 30 days, Sharpe CI [−6.8, +4.6] (`CEO_AUDIT:14`). Is a live sample this short admissible AT ALL as positive live evidence, or strictly supporting (as §D.3 sets it)? If admissible, what minimum informative sample and numeric positive threshold? *No existing authority. Recommendation: keep strictly supporting.*
- **OQ-6 (roster gap, ROT).** `QM5_11910`:NZDUSD is absent from the only existing OOS-2026 campaign (0 entries out of 50 distinct pairs; re-counted in R4). Predeclare: (a) the gap refutes the lift, (b) the missing identity is scored as a failure, or (c) a make-up run is added before the seal. *Recommendation: (c); failing that, (b). Deciding this after results would be re-selection under §A rule c.*
- **OQ-7 (cost class).** The campaign runs `cost_profile = DXZ_CANONICAL_REAL_TICKS_V1`, but the evaluator refuses raw DXZ streams and accepts only `DXZ_EXECUTION_FTMO_COST_ADJUSTED_V1` (`ftmo_timebox_eval.py:54,:707-708,:1307-1312`). Authorize the FTMO cost re-attestation and re-emission before evaluation, or designate a different admissible stream source. *Recommendation: authorize the re-attestation; without it D.1 is not evaluable at all.*
- **OQ-8 (re-verification at seal).** All R3 anchors were re-verified at tip `fb719e703a` and the stale ones are tabulated in §G. **Re-verify §G once more at seal time**: the evaluator changed twice in three days (`5bac8eaccb`, then `f68ce8f338`), and the probability contract is a new, unpinned, import-time dependency (§E contamination 6).
- **OQ-9 (C-6 scope, ROT — NEW in R4; this is the binding constraint on the whole test).** Breach upper-95, P2-conditional and joint are INERT and cannot pass or fail (`ftmo_probability_contract.v1.json:20,:21`; loader `ftmo_probability_contract.py:117-120`; published `ftmo_timebox_eval.py:1480-1486`). **While that holds, no measurement can lift NO-BUY (§D.0).** Options: (a) commission the C-6 estimator — OWNER scopes the method (barrier definition, how a moving-block bootstrap yields an admissible **upper** bound on breach events, the joint-credit formula), Codex implements, OWNER approves; (b) by dated OWNER decision remove criteria 5/6 from the necessary set, reducing the lift path to D.1-without-C-6 plus D.2 — a ROT gate-criteria change; (c) accept that NO-BUY stays parked. *No method or threshold is proposed here — designing the estimator is outside Claude's authority. Recommendation: (a), scoped as a separate Vorlage, because (b) weakens the strictest existing criterion set and (c) has no end date.*
- **OQ-10 (ratification asymmetry, ROT — NEW in R4; = contract C-2).** The rulepack is `lifecycle_status: RESEARCH_CONTRACT_ONLY` (`:9`), so its `go_criteria` are PROPOSED, not OWNER-sealed (`docs/ops/FTMO_PROBABILITY_CORRELATION_CONTRACT_V1_2026-09-05.md:36,:284`). Does ratifying §D elevate them to binding, or do they remain declared-but-not-sealed? *Recommendation: elevate exactly the seven evidence criteria named in §B and no others, so the elevation is scoped and dated rather than implied.*
- **OQ-11 (contract-file normalization, GRÜN-adjacent, NEW in R4).** `ftmo_probability_contract.v1.json` is not `-text` in `.gitattributes`, so `load_probability_contract()`'s raw-byte digest (`ftmo_probability_contract.py:147`), which the evaluator stamps into every result (`ftmo_timebox_eval.py:1482`), is checkout-dependent (`54cb80fd…` in `C:/QM/repo` vs `7328b8b1…` here). Separately, three of the contract JSON's own citations are already stale against the code it governs: `migration_note` (`:29`) says the builder still consumes zeros-dropped point Pearson, but the Layer-A migration landed in the same commit (`build_book_ftmo.py:146-204`); and `:30` cites `ftmo_timebox_eval.py:103` for `maximum_budget_exclusive` (actual `:112-114`) and "applied `:1092`" (actual `:1115-1117`). None changes behaviour — all are documentation drift inside a ROT contract file, which is exactly the class of drift a seal must not silently inherit. These are Codex fixes, not decisions. *Recommendation: commission a Codex ticket; until then §E item 15 seals the LF digest and names the canonical runtime host.*
- **OQ-3 — RETIRED (answered).** Calendar-repair option E1 is decided: **Option A**, receipt row 9 (`decisions/2026-09-02_owner_receipts_ceo_asks.md:18`, task `0da3dfec`), with E4 `--apply` after the backfill per row 11 (`:20`, task `49a8c88b`).
