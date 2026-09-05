# OWNER-Vorlage 2026-09-05 — FTMO Positive-Evidence-Abnahmetest (Revision R3)

Status: PENDING (OWNER-Ratifizierung). Klasse: **ROT** (kauf-nah), **kein Auffangregel**.
Autor: Claude (Factory CEO). Bindet: `decisions/2026-09-02_owner_receipts_ceo_asks.md:13` (Zeile 6, FTMO NO-BUY); dieser Test ist **Receipt-Zeile 18** (`decisions/2026-09-02_owner_receipts_ceo_asks.md:28`, PENDING).

> **Revisionsstand R3 (CEO, 2026-09-05).** R2 wurde unabhängig geprüft (`docs/ops/evidence/2026-09-05_review_ftmo_positive_evidence_test.md`, Verdikt **FAIL**, Quell-SHA-256 `5697ceec273c716da9e21318d28c885e364466587bd0453c1485a6a679c51f7c`). R3 behebt F1–F6 und geht dort darüber hinaus, wo der Befund es verlangt (F3: die Power-Regel ist jetzt ausgerechnet, nicht nur gefordert). **Alle Anker wurden auf diesem Branch bei Commit `5bac8eaccb` zeilengenau nachgeprüft**; die Marker „[cross-branch — re-verify at seal]" der Vorversion sind ersatzlos entfallen, weil die drei Schwesterdateien und die Receipt-Zeilen 1–18 hier vorliegen. Die dabei gefundenen **stale Zeilenanker der Vorversion sind in §G tabelliert** — sie sind der Grund, warum §E jetzt Modul-SHAs statt Zeilennummern bindet.

---

## 1 · LAGE (Deutsch, eine Seite)

**Der Park-Trigger ist heute undefiniert.** Receipt-Zeile 6 (`decisions/2026-09-02_owner_receipts_ceo_asks.md:13`) hält den FTMO-Kauf auf NO-BUY und re-ankert den Trigger auf „positive OOS/live evidence" (verbatim: „ja, wann kommen wir aber auf FTMO?"). Die Schwester-Analyse benennt die Lücke: „positiv" ist nicht definiert und würde nach dem Ansehen der Ergebnisse zu Ad-hoc-Selektion (`docs/ops/evidence/2026-09-04_astra_ftmo_book_analysis.md:125,:133`). Die Schließung ist eine datierte Entscheidung über Population, Metrik, Unsicherheit und zulässige Evidenzklasse — ratifiziert **bevor** ein Ergebnis gesehen wird.

**Heutiger Messstand (read-only `farm_state.sqlite` + Belege dieses Branches):**

- Population: **8 identitätsgebundene Q08-Tages-PnL-Ströme** (= Q14 `KEEP_INCUMBENT`, 9 Zeilen / 8 Paare, 11421:EURUSD doppelt; `docs/ops/evidence/2026-09-05_news_calendar_timestamp_defect.md:93`). Alle acht Strom-SHA-256 stehen vollständig in `docs/ops/evidence/2026-09-04_fund_score_current_population.md` (8 requested / 8 bound / 0 refused).
- FUND_SCORE aller 8 Ströme **< 1.0** (Floor 1.0, `tools/strategy_farm/portfolio/build_book_ftmo.py:53`), Buch verweigert; Zähler **8/25** → `BOOK_BUILD_REFUSED` (`tools/strategy_farm/book_build_guard.py:28,:235-239`).
- Der einzige billige Test — ein gültiger 2026-Q1-OOS-Pass (~55 Läufe, ~3 Terminalstunden) — **ist nie gelaufen** (`docs/ops/CEO_AUDIT_2026-09-02.md:45`) und war doppelt blockiert: (i) 15/15 Confirmation-Jobs liefen 2024 statt 2026 (`docs/ops/evidence/2026-09-04_astra_ftmo_book_analysis.md:88`), (ii) das Fenster **2026-01-01..2026-04-06** liegt im Kalender-Loch 2025-05..2026-06 (null Zeilen; `docs/ops/evidence/2026-09-05_news_calendar_timestamp_defect.md:51,:102-103`).
- **NEU gegenüber R2 — die Kalender-Blockade ist entschieden, nicht mehr offen.** Receipt-Zeile 8 liegt vor und ist DECIDED YES (`:16`); Zeile 9 ratifiziert **E1 Option A** (nativer MT5-Export, Backfill 2025-05..2026-06, neue Bundle-Identität; Task `0da3dfec`, `:18`), Zeile 11 bindet **E4 `--apply` erst nach dem Backfill** (Task `49a8c88b`, `:20`). Das frühere OQ-3 ist damit **beantwortet**.
- **NEU — die P1-Latten-Vereinheitlichung ist bereits beauftragt.** Receipt-Zeile 15 (P7a: Builder/Timebox/Rulepack angleichen) ist YES, Task `97a0ed31` (`:24`). Bis zur Lieferung gilt in diesem Test die **strenge Schnittmenge**, nicht die lockerere Einzelquelle.
- Live-Buch (governed-only, die zwei manuellen `magic=0`-Trades ausgeschlossen per Zeile 1, `:8`): **−469 USD über 30 aktive Tage, Sharpe-CI [−6.8, +4.6]** — statistisch nicht informativ (`docs/ops/CEO_AUDIT_2026-09-02.md:14`).
- DSR/Multiple-Testing: **0 Sleeves erreichen DSR ≥ 0.95** bei jedem vertretbaren Trial-Count (`docs/ops/CEO_AUDIT_2026-09-02.md:14`; 0/24 und 0/21 für jedes N ≥ 10, `:43`); E[max SR] unter Null ≈ 1.06–1.44 (`:14`); die modellierte +2.4-Buch-Sharpe überlebt die Korrektur zu ≈ 0 % (`:14`). Walk-Forward: 82 % PF>1 (`:14`), Held-out-Folds 61/74 PF>1, geo-mean OOS PF 1.47 selektionskonditioniert (`:45`) — lehnt gegen Null-Edge, ist aber nicht kauf-tragend.

**Drei neue, harte Befunde aus der R3-Nachprüfung (alle rein arithmetisch, keine neuen Schwellen):**

1. **Das 13-Wochen-Fenster enthält genau EIN nicht überlappendes P1-Fenster.** 2026-01-01..2026-04-06 = **96 Kalendertage**; die P1-Horizontlänge ist 60 Kalendertage (`tools/strategy_farm/portfolio/ftmo_timebox_eval.py:72`; `docs/research/FTMO_BOOK_SPEC_2026-08-02_OWNER_TIMEBOX.md:13`). ⌊96/60⌋ = **1**. Für die volle Zwei-Phasen-Strecke (60+30, `:74` / `:15`) gilt ⌊96/90⌋ = **1**. Die 37 rollierenden Starts (96−60+1) sind fast vollständig überlappend. Ein einzelnes Fenster kann die 0.80-Latte deshalb strukturell nicht mit Unsicherheit belegen — unabhängig davon, was gemessen wird.
2. **Die DSR-Engine würde auf diesem Fenster gar kein Verdikt liefern.** `sub_8_2_dsr_mc_fdr.py:182-186` gibt **INVALID** zurück, wenn weniger als **60 Tage mit Handel** vorliegen, und `:149-150` / `:78-79` liefern p = 1.0 unter 30 Beobachtungen. 96 Kalendertage enthalten **68 Wochentage**; sieben der acht Sleeves sind D1-Bar-Open-Einstiege, die nicht täglich handeln. Die ≥60-Schwelle bindet also mit hoher Wahrscheinlichkeit — D.2 wäre auf dieser Quelle nicht einmal auswertbar.
3. **Die Roster-Deckung der einzigen OOS-Quelle ist unvollständig.** `D:/QM/strategy_farm/artifacts/oos_2026_confirmation_v1/campaign_plan.json` (read-only) enthält 55 Läufe über **50 verschiedene (EA, Symbol)-Paare** (`run_count` 55, `live_count` 24, `frontier_count` 31). Davon decken sich **7 der 8** versiegelten Identitäten; **11910:NZDUSD kommt in der Kampagne nicht vor**. Eine Teilablesung der versiegelten Population ist ohne vorab festgelegte Behandlung selbst ein Selektionsrisiko (siehe OQ-6).

**Kernpunkt:** Der 25-Paar-Zähler ist eine **Kauf-Vorbedingung**, NICHT der Positive-Evidence-Trigger. Ihn zu bestehen ersetzt den Trigger nicht (`docs/ops/evidence/2026-09-04_astra_ftmo_book_analysis.md:79`).

## 2 · EMPFEHLUNG

1. **NO-BUY beibehalten.** Kein Ergebnis liegt vor, das den Trigger erfüllt.
2. **Diesen vorab-deklarierten, widerlegbaren Abnahmetest in der R3-Fassung ratifizieren** — Population / Metrik / Unsicherheit / **Power-Regel** / Evidenzklasse / Refutationsklausel / Siegel —, BEVOR ein Ergebnis gesehen wird. **Keine erfundenen Zahlen:** jede Schwelle ist ein bestehender, zeilengenau belegter Policy-Wert; jede abgeleitete Zahl wird mit ihrer Rechnung gezeigt; jede echte Wahl ist als **OWNER-CHOICE** markiert und mit Empfehlung versehen.
3. **Reihenfolge:** E1 Option A ausführen (Zeile 9) → Loch-Backfill → E4 `--apply` (Zeile 11) → **versiegelte, nach §C.4 ausreichend gepowerte** OOS-Messung. Erst dann zählt OOS als Evidenz. **Das einzelne 96-Tage-Diagnosefenster ist für sich genommen NICHT zulässig** — §D bleibt inert, bis OQ-2 (Population **und** Zielgröße p\*) beantwortet ist.
4. **Vor der Messung zusätzlich zu klären:** die Kostenklasse. Der Evaluator **verweigert** rohe DXZ-Ströme (`ftmo_timebox_eval.py:1286-1287`, `REFUSED_DXZ_SPREAD_INHERITANCE`) und akzeptiert nur `DXZ_EXECUTION_FTMO_COST_ADJUSTED_V1` (`:50`, Prüfung `:686-693`). Die Kampagne läuft aber unter `cost_profile = DXZ_CANONICAL_REAL_TICKS_V1`. Ohne FTMO-Kosten-Reattestierung ist ihr Output nicht evaluatorfähig (OQ-7).
5. Kauf, T_Live, AutoTrading, Deployment bleiben **separate, einzeln signierte** OWNER-Zeremonien — dieser Test hebt NO-BUY höchstens auf „positive-evidence-met", nicht auf „gekauft" (Rulepack `:500-505`).

## 3 · ENTSCHEIDUNGSFRAGEN (je mit Rollback + Cost-of-Wait)

| Q | Frage | Klasse | Rollback | Cost-of-Wait |
|---|-------|--------|----------|--------------|
| **Q1** | Diesen Abnahmetest in der **R3-Fassung** ratifizieren (Population / Metrik / Unsicherheit / Power-Regel / Evidenzklasse / Refutation / Siegel wie §A–§F)? | ROT | Test bleibt unratifiziert; alle Evidenz bleibt erhalten; keine Verdikte berührt. | Jede weitere Messung ohne ratifizierten Test riskiert Ad-hoc-Selektion; der Trigger bleibt undefiniert und blockiert den FTMO-Zeitplan, den OWNER erfragt hat (Zeile 6, „wann kommen wir auf FTMO?"). |
| **Q2a** | **Zulässige Evidenzpopulation (OQ-2a, blockierend für §D).** Genügt das einzelne korrigierte 96-Tage-Fenster, oder sind **mehrere nicht überlappende versiegelte Fenster bzw. ein längerer versiegelter OOS-Zeitraum** erforderlich? | ROT | §D bleibt inert; keine Messung zählt als Lift-Quelle. | Ohne Antwort ist der Test nicht entscheidbar; NO-BUY bliebe unbestimmt lange geparkt. |
| **Q2b** | **Zielgröße p\* für die Power-Regel (OQ-2b, blockierend für §D).** Welche wahre P1-Passrate soll der Test zertifizieren können? Aus p\* folgt die Mindest-ESS **rechnerisch** (§C.4) — es ist keine zweite freie Zahl. **Empfehlung: p\* = 0.90.** | ROT (Unsicherheit) | §D bleibt inert. | Ohne p\* ist „gepowert" nach dem Ergebnis zuweisbar — genau die Ad-hoc-Selektion, die der Test verhindern soll (Review F3). |
| **Q3** | Den P1-Latten-Konflikt bestätigen: Builder/Timebox verlangen **Lower ≥ 0.80** (`build_book_ftmo.py:54`, `ftmo_timebox_eval.py:90`), Rulepack verlangt **Punkt ≥ 80 % UND Lower-95 ≥ 70 %** (`FTMO_2S_100K_SWING_V2.json:480`). Bis zur Lieferung von P7a (Zeile 15, Task `97a0ed31`) zitiert dieser Test die **Schnittmenge: Punkt ≥ 0.80 UND Lower-95 ≥ 0.80**. | ROT (Buchregeln) | Versionierte Reconciliation über P7a, nie stille Reklassifizierung. | Ohne Bestätigung könnte ein Ergebnis mit Punkt 0.82 / Lower 0.75 §D „bestehen" und gleichzeitig die Builder-Latte reißen (Review F1). |
| **Q4** | Evidenzklasse bestätigen: OOS-2026 zählt **erst nach** E1-Reparatur + Backfill + korrigiertem Fenster; **alle acht** Rulepack-`go_criteria` sind notwendig (nicht nur die vier Wahrscheinlichkeitskriterien); Live-Attribution **governed-only**; Live ist **stützend, nicht hinreichend**. | ROT | Kein Rollback nötig — reine Vorab-Festlegung. | Ohne Festlegung misst OOS ohne News und ohne vollständige Intraday-MTM, und Live-Zahlen werden durch die manuellen Trades verzerrt (~76 % des −2.227-USD-Verlusts, `CEO_AUDIT:14`). |
| **Q5** | **Roster-Lücke (OQ-6).** 11910:NZDUSD fehlt in der OOS-Kampagne. Vorab festlegen: (a) Lücke = Refutation, (b) Lücke wird als Fehlschlag gewertet, oder (c) 11910 wird vor dem Siegel per Nachlauf ergänzt. **Empfehlung: (c), sonst (b).** | ROT (Population) | Keine — reine Vorab-Festlegung. | Nach dem Ergebnis entschieden, ist jede Variante eine Nachselektion (§A Regel c). |

Alles ROT. **Kein Auffangregel.** Ratifizierung nur durch OWNER (alleinige menschliche Autorität).

---

# ENGLISH CONTRACT — FTMO Positive-Evidence Acceptance Test (predeclared, refutable) — R3

Ratify this contract text verbatim before any evaluation stream is opened. Every threshold below is a path-referenced EXISTING policy value on branch `agents/board-advisor` at commit `5bac8eaccb`; this contract invents none. Where arithmetic is derived from existing values, the derivation is shown. Where no value exists, the item is marked **OWNER-CHOICE** with a recommendation and is not silently filled in.

## §A · Evidence sources and admissibility

**Admissible population (sealed).** Exactly the 8 identity-bound Q08 daily-PnL streams of the current bundle = the Q14 `KEEP_INCUMBENT` rows (9 rows / 8 distinct pairs, 11421:EURUSD twice; `docs/ops/evidence/2026-09-05_news_calendar_timestamp_defect.md:93`). Byte-pinned by SHA-256 in `docs/ops/evidence/2026-09-04_fund_score_current_population.md` (8 requested / 8 bound / 0 refused, loader verified):

| ea_id | symbol | stream SHA-256 | in OOS-2026 campaign? |
|-------|--------|----------------|-----------------------|
| 10706 | GBPUSD | `71fb35b8f8539356f511609a4d1dfb06571f85b19b60de6647e907ec891e34f7` | yes |
| 11421 | EURUSD | `e9d0a9ef831f156f0f67e5bf1140d7e57702c3923a4ff47b5548847957d7c0c1` | yes |
| 11422 | USDCAD | `7ce6cc3ec2f1279c18e8601119e3319375d5d3fa1ce4cf95cf33e05eefc33198` | yes |
| 11910 | NZDUSD | `555bbee205432c62f06da96a0a291d14028dc5c88e3fa8b2792ad62bc5d885b0` | **NO — absent** |
| 13054 | XTIUSD | `67d4fe2cef067e041f01d10e5e6c98312a32b43683eee2da3d0bfa9af296955b` | yes |
| 1537  | XAGUSD | `1885c21e4c895827c79ff3d55849308ab4ee5c0db96a7d576cd652dc3eff8658` | yes |
| 20048 | XTIUSD | `a792e2635250bcd6df5aa4a290359b54e6d5ffe8fbe10e34d143b74dfe0e8d55` | yes |
| 21505 | XAGUSD | `243804faaf0050f5482b9a4aac8f9eb0dcd552de1c2c139a486f0bcfa46b94c1` | yes |

Coverage column measured read-only from `D:/QM/strategy_farm/artifacts/oos_2026_confirmation_v1/campaign_plan.json` (55 runs over 50 distinct (EA, symbol) pairs).

**Admissibility rules (predeclared):**

| # | Rule | Basis |
|---|------|-------|
| a | **Governed-only live attribution.** The two `magic=0` live trades (27.07 NDX 1.00 lot, 24.07 EURUSD 0.43 lot) are OWNER manual trades and are EXCLUDED from every governed track-record read. | `decisions/2026-09-02_owner_receipts_ceo_asks.md:8` (row 1); `docs/ops/CEO_AUDIT_2026-09-02.md:14` (those two ≈ 76 % of the −2,227 USD live loss; governed book alone −469 USD / 30 days, Sharpe CI [−6.8,+4.6]). |
| b | **No manual trades count as evidence** (neither for nor against). | row 1, as above. |
| c | **No re-selection after results are seen.** The roster of 8 identities is frozen at seal; no addition, removal, or substitution after the first result is opened. | `docs/ops/evidence/2026-09-04_astra_ftmo_book_analysis.md:131,:133`. |
| d | **OOS-2026 counts ONLY after the E1 calendar repair AND the 2025-05..2026-06 backfill AND on the corrected window AND only if the source qualifies under OQ-2a/OQ-2b** (§C.4 power rule). A single 96-day diagnostic window is NOT admissible on its own. | calendar precondition below; `docs/ops/evidence/2026-09-05_news_calendar_timestamp_defect.md:51,:102-103`. |
| e | **Roster completeness is predeclared, not discovered.** 11910:NZDUSD has no run in the only existing OOS-2026 campaign. The handling of that gap is fixed BEFORE the seal (OQ-6). A population read that silently drops a sealed identity is a contamination event under §E.2. | `campaign_plan.json` roster enumeration (read-only); §A roster table above. |
| f | **Cost class is predeclared.** The evaluator REFUSES a raw `DXZ_Q08_TRADES_V1` stream with `REFUSED_DXZ_SPREAD_INHERITANCE` and accepts only `DXZ_EXECUTION_FTMO_COST_ADJUSTED_V1` under an explicit declaration. The OOS campaign runs `cost_profile = DXZ_CANONICAL_REAL_TICKS_V1`, so its output must first be re-costed and re-emitted under the accepted schema (OQ-7). | `ftmo_timebox_eval.py:49,:50,:54,:1286-1290`; cost attestation `:56,:686-693`; `campaign_plan.json cost_profile`. |

**Calendar-defect precondition — status changed since R2: DECIDED, not open.**

1. **Dispatch/window bug.** 15/15 completed confirmation jobs ran **2024** in both INIs and reports despite 2026 input manifests (`docs/ops/evidence/2026-09-04_astra_ftmo_book_analysis.md:88`). Repaired by commit `1ac9f653d8`; `repair-oos-window --apply` remains DEFERRED, task `1721f3a1` IN_PROGRESS (`docs/ops/evidence/2026-09-05_news_calendar_timestamp_defect.md:138`).
2. **Calendar coverage hole.** 2025-05 through 2026-06 contain **zero rows**; 2025-04 is partial (`...:51`). The window 2026-01-01..2026-04-06 lies inside the hole, so successor runs would measure with no news events at all (`...:102-103`).
3. **OWNER disposition (already given).** Receipt row 8 is DECIDED YES (`decisions/2026-09-02_owner_receipts_ceo_asks.md:16`). Row 9 ratifies **E1 Option A** — native MT5 export, BLS/Fed anchors for USD, non-USD offset fan or declared gap, backfill 2025-05..2026-06, new bundle identity + repin; task `0da3dfec` (`:18`). Row 11 binds **E4 `--apply` only after the E1 backfill**; task `49a8c88b` (`:20`). The former OQ-3 is therefore **answered** and is retired below.

**Notes.** The OOS-2026 campaign is **diagnostic by design**: `campaign_plan.json` carries `diagnostic_non_admission=true`, `diagnostic_single_window=true`, `single_seed=20250301`, `single_config=deployed`, `t_live_read_only=true`, window `2026-01-01T00:00:00Z .. 2026-04-06T23:59:59Z` (read-only). Because it is non-admitting by its own declaration AND under-powered by §C.4, it is a diagnostic, not a lift source. Live trading is unaffected by the calendar defect — the live news branch reads the native MT5 calendar, not the CSVs. Of the 8 sealed identities, only 10706/GBPUSD (H1, explicit `PRE30_POST30`) is exposed to the timestamp defect; the other 7 are D1 bar-open entries for which the defect is practically inert (`docs/ops/evidence/2026-09-05_news_calendar_timestamp_defect.md:93,:98`).

## §B · Metrics and thresholds (all derived from EXISTING policy — no new numbers)

**Provider rules** (rulepack `tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_SWING_V2.json`, file SHA-256 `298ef1285eca49ea7f010ebc0a9353b5a821fccb40a025be129f5ca5314fd992`; provider snapshot `docs/ops/evidence/2026-09-04_ftmo_official_rules_snapshot.json`):

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
| Swing leverage | 1:30 FX / 1:15 metals+oil — **CARRIED_OVER / NOT re-confirmed on 2026-09-04** | rulepack `:255-260` (params `:259`); status snapshot `:724-725,:728-729`, dead URL `:808-816`, scope limit `:824` |

**Decision gates — the full `evaluation_profile.go_criteria` set (rulepack `:457-506`). All eight are necessary; R2 cited only four.**

| # | criterion_id | Threshold | Path |
|---|--------------|-----------|------|
| 1 | `ftmo_rule_snapshot_fresh` | official snapshot age ≤ **7 days**, all sources official | `:458-463` (`maximum_age_days:7` `:462`) |
| 2 | `ftmo_execution_fidelity_closed` | **0** unadjudicated standalone-to-book entry/exit/timer/ownership mismatches | `:464-469` (`unadjudicated_mismatches:0` `:468`) |
| 3 | `ftmo_complete_mtm_evidence` | tick-/event-complete interval minimum equity, Prague anchors, FTMO symbols, costs, swap, margin, pending state; **closed-P&L daily proxy FORBIDDEN**, intratrade equity REQUIRED | `:470-475` (params `:474`) |
| 4 | `ftmo_phase1_probability_gate` | point ≥ **80 %** AND lower-95 ≥ **70 %** | `:476-481` (params `:480`) |
| 5 | `ftmo_breach_probability_gate` | upper-95 ≤ **10 %** | `:482-487` (params `:486`) |
| 6 | `ftmo_two_phase_probability_gate` | P2-conditional ≥ **85 %** AND joint ≥ **65 %** | `:488-493` (params `:492`) |
| 7 | `ftmo_free_trial_gate` | ≥ **1** exact-profile Free-Trial/shadow run, **0** operational defects, inside preregistered prediction bands | `:494-499` (params `:498`) |
| 8 | `ftmo_owner_purchase_gate` | separate signed OWNER decision; automatic purchase forbidden | `:500-505` (params `:504`) |

Criterion 3 is load-bearing for criteria 4–6: an FTMO rule-breach probability computed on a closed-P&L daily proxy is explicitly not admissible evidence, so complete intratrade MTM must precede any breach-probability claim.

**Builder V2 OWNER_RATIFIED thresholds** (`tools/strategy_farm/portfolio/build_book_ftmo.py`, ratified under `OWNER-DEC-BOOK-V2V4V6-EPOCH-20260904`, receipt `decisions/2026-09-04_owner_receipts_briefing_2_4.md`; ratification stamped in-module at `:80-81`):

| Item | Value | Path |
|------|-------|------|
| FUND_SCORE floor | **1.0** | `:53` |
| P1 lower-bound floor | **0.80** | `:54` |
| DL-083 Q09 marginal-eval reject | 0.40 | `:68-69` (comment), applied via correlation policy |
| Max pairwise correlation | 0.50 | `:75` |
| Account unit-weight budget | 10.0 | `:76` |
| Sleeve unit weight | 1.0 | `:77` |
| min_sleeves | 3 | `:471` |
| min_active_days_per_60d | 4.0 (builder floor, NOT the full Q15 ceremony) | `:472` |
| Source-sleeve risk mode | RISK_FIXED=1000 / RISK_PERCENT=0 hard check | `:498-506` (raise `:501-503`) |

**FUND_SCORE formula** (`tools/strategy_farm/portfolio/fund_score.py`, 178 lines on this branch): `FUND_SCORE = med60_1x / max(2.0, 2.0·|worst_day_1x|, wDD_p90_1x)` — med60 `:94`, |worst_day| `:95`, wDD_p90 `:96`, denominator `:97`, score `:100`, formula string `:103`. *(R2 cited `:59/:62/:65` and asserted no formula string exists at `:94-103`; both statements were stale — see §G.)* Current-population rescore, all < 1.0, NO-BUY unchanged (`docs/ops/evidence/2026-09-04_fund_score_current_population.md`): 10706:GBPUSD 0.106901, 11421:EURUSD 0.015577, 11422:USDCAD 0.148329, 11910:NZDUSD 0.094695, 13054:XTIUSD 0.024265, 1537:XAGUSD 0.131237, 20048:XTIUSD 0.032985, 21505:XAGUSD 0.123500.

**Book counter:** `MIN_QUALIFIED_PAIRS = 25` (`tools/strategy_farm/book_build_guard.py:28`, refusal `:235-239`); census 8/25 → `BOOK_BUILD_REFUSED`. **The 25-pair counter is a purchase prerequisite, NOT the positive-evidence trigger — passing it cannot substitute for the trigger** (`docs/ops/evidence/2026-09-04_astra_ftmo_book_analysis.md:79,:125`).

**Concentration / tail** (`tools/strategy_farm/config/concentration_tail_limits.v1.json`, `status: OWNER_RATIFIED` `:3` via receipt row 4 `decisions/2026-09-02_owner_receipts_ceo_asks.md:11`): `stop_risk_budget_pct` 2.5 (`:5`); caps as % of budget: symbol 40 (`:7`), asset_class 60 (`:8`), family 50 (`:9`), session WARN 60 (`:10`) / breach 70 (`:11`); tail: `per_sleeve_worst_fraction` 0.05 (`:14`), `joint_sleeve_divisor` 3 (`:15`), `venue_daily_loss_limit_pct` 5.0 (`:16`), `maximum_fraction_of_daily_limit` 0.8 (`:17`). Application to live weights remains a separate OWNER ceremony (`application_authority OWNER_ONLY` `:34`, `deployment_action NONE` `:35`).

**Speed doctrine** (`docs/research/FTMO_BOOK_SPEC_2026-08-02_OWNER_TIMEBOX.md`): P1 horizon **60** calendar days (`:13`), P2 horizon **30** calendar days (`:15`), design bar **P(Phase-1 pass) ≥ 0.80** (`:19`) measured as the moving-block bootstrap **LOWER** bound, never the raw rate (`:25-26`), decided at the conservative end of the spread-penalty band (`:58-61`). Mirrored in `ftmo_timebox_eval.py` `DEFAULT_RULES` (`:69-91`): `design_bar_p1` 0.80 (`:90`); P1/P2 horizons 60/30 (`:72,:74`); `DEFAULT_BOOTSTRAP` (`:93-99`) replicates 2000 (`:94`), seed 20260802 (`:95`), alpha 0.05 (`:96`), 60-day blocks (`:97`), `TWO_SIDED_PERCENTILE_95` (`:98`). *(R2 cited `:63,:65,:77,:81-85`; all stale — see §G.)*

**P1 bar — the strict intersection, pending P7a.** (a) builder requires bootstrap LOWER ≥ 0.80 (`build_book_ftmo.py:54`); (b) the timebox evaluator embeds the same design bar 0.80 (`ftmo_timebox_eval.py:90`); (c) the rulepack requires point ≥ 80 % AND lower-95 ≥ 70 % (`FTMO_2S_100K_SWING_V2.json:480`). The unification is **already commissioned** as receipt row 15 / P7a, task `97a0ed31` (`decisions/2026-09-02_owner_receipts_ceo_asks.md:24`). Until it lands, **this test applies the intersection: point ≥ 0.80 AND lower-95 ≥ 0.80.** This introduces no new number — it is the stricter of two existing values on each side. Structural consequence, stated in advance: under the intersection a point estimate of exactly 0.80 can never pass, because a two-sided 95 % lower bound is strictly below the point estimate whenever the estimate is non-degenerate. §C.4 is therefore only defined for p\* > 0.80.

## §C · Sample size, power, and the DSR engine

### §C.1 · What each engine can and cannot establish

| Engine | Establishes | CANNOT establish | Key params / path |
|--------|-------------|------------------|-------------------|
| `ftmo_p1_mc.py` | Ranks compositions; daily/total-DD breach probabilities as explicit **lower bounds** (rules applied on CLOSED daily P&L; floating intraday DD invisible) | Joint tail dependence — sleeves are resampled INDEPENDENTLY, so cross-sleeve correlation is broken; DSR; an admission-quality bound | independent resample `:26`; closed-P&L lower bounds `:30-31`; horizon 90 trading days `:79`, 10,000 paths `:80`, seed 20260720 `:81` |
| `challenge_firstpassage.py` | First-passage (+10 % before −5 % daily / −10 % total, no deadline) on END-OF-DAY balance; four-opening-day minimum enforced; effective sample size = overlapping starts ÷ median resolution time; preregistered **1x-no-overlay** block (selection-free) | A raw-n confidence read (starts OVERLAP); DSR; stages 1–2 are in-sample-selected and must NOT be the acceptance number | four-day minimum `:32-33,:68,:176`; preregistered 1x `:371-377`; ESS `:405-408`, Wald half-width `1.96·se` `:409-410`, lower-bound semantics `:415,:419-421` |
| `ftmo_timebox_eval.py` | Selection-SEALED (`prepare-config` freezes input SHAs before any stream is opened); moving-block bootstrap; HAC effective sample size for autocorrelated overlapping starts; four-opening-day minimum; DL-083 correlation refusal ≥ 0.40; min 20 shared calendar days | Anything on raw DXZ streams — it REFUSES them; refuses DB/farm-state (mutable) inputs; DSR; **any minimum sample size — it reports HAC ESS but enforces no floor** | `DEFAULT_RULES` `:69-91`, `DEFAULT_BOOTSTRAP` `:93-99`, `minimum_shared_calendar_days` 20 `:105` enforced `:1043-1046`; mutable refusal `:233-258`, `:375-376`, `:443-444`; DXZ refusal `:1286-1290`; cost attestation `:56,:686-693`; HAC `:927-953` (bandwidth 59 `:932`, `effective_n` `:951`), reported as `p1_hac` `:1126` beside `rolling_starts` `:1124` |

None of the three is a DSR engine, and none is a sealed once-only holdout by itself.

### §C.2 · The DSR / multiple-testing engine — and what its multiplicity input actually is

The Deflated Sharpe / E[max SR under the null] correction is computed by the Q08 sub-gate 8.2 engine `framework/scripts/q08_davey/sub_8_2_dsr_mc_fdr.py` (Bailey & López de Prado, ref `:22`), `GATE_NAME "8.2_dsr_mc_fdr"` (`:32`), threshold **`DSR_P_MIN = 0.05`** (`:33`), `_expected_max_sharpe` ≈ `sharpe_std·(√(2 ln N) − γ/√(2 ln N))` (`:93-100`), funnel DSR via normal cdf (`:103-143`).

**Correction (Review F2) — `declared_trial_count` is NOT `selection_trial_count`.** R2 fed the pattern-census figure 154 into the DSR multiplicity. That is wrong on this branch and must not be ratified:

- `selection_trial_count` is defined as the number of configurations the evaluated one was **SELECTED FROM**, explicitly **not** the number measured; under the Plan-v2 E0-1 firewall a source-derived pre-registered predicate is selected from **1** candidate even when a census measured 154 (`sub_8_2_dsr_mc_fdr.py:40-46`).
- The lineage emitter records `selection_trial_count` as a field **distinct** from `trial_ledger_declared_count`, supplied explicitly and "never derived from, defaulted to, or collapsed into the measured trial count" (`framework/scripts/emit_q16_lineage.py:16-21`; enforced `:179-187`, emitted `:212`; tests `tools/strategy_farm/tests/test_emit_q16_lineage.py:112-119`).
- `DECLARED_TRIAL_COUNT = 154` (`tools/strategy_farm/opt_census.py:36`) is the DL-089 pattern-WF **census** size — a measurement count, not a selection count.
- The engine's effective-candidate rule (`sub_8_2_dsr_mc_fdr.py:161-176`): a missing, unparseable or `< 2` count leaves the fleet default `N_CANDIDATE_STRATEGIES = 369` (`:34`, `MIN_SELECTION_TRIALS_FOR_DEFLATION = 2` `:47`); an explicit count `c ≥ 2` yields `369 + c − 1`. **Feeding 154 therefore silently means 522, not 154.**
- Direction of the test: the gate returns **PASS when `p_value < DSR_P_MIN`** (`:225-228`) and FAIL otherwise (`:243-245`). The correct wording is that the engine **rejects the multiple-testing null**; R2's "does not reject edge" was directionally wrong.
- Cohort activation: with fewer than `MIN_COHORT_PEERS = 1` peers (`:54`) the gate returns a trivial PASS with deflation deferred (`:200-210`). *(R2 cited `:48-52` as "the DSR minimum"; the constant is at `:54` and its value is 1 — see §G.)*

**The two multiplicities this test must seal, both sourced, neither invented:**

1. **Per-identity selection multiplicity** — each sealed identity's own `selection_trial_count`, read from its Q07/Q08/Q16 lineage evidence where present, consumed through the engine's unchanged effective-candidate rule (`:161-176`). Where an identity carries no trial ledger, the fleet default 369 (`:34`) applies untouched. **154 is never substituted.**
2. **Book/read-level selection multiplicity** — the number of candidate identities actually screened to arrive at the read. Existing sourced cohorts on this branch, all report-only (`:103-143`, flag `:133`):
   - `FUNNEL_DISTINCT_EAS = 3,001` (`:38`) and `FUNNEL_DISTINCT_PAIRS = 13,398` (`:39`), both sourced to the read-only farm census of the 2026-09-02 CEO audit (`:35-37`);
   - the OOS-2026 campaign screens **50 distinct (EA, symbol) pairs over 55 runs** (`run_count` 55, `live_count` 24, `frontier_count` 31; `campaign_plan.json`, read-only) — this is the multiplicity that applies if a single campaign result is read as "the positive evidence";
   - the FUND_SCORE legacy comparison population was **24** rows versus the current **8** (`docs/ops/evidence/2026-09-04_fund_score_current_population.md`), consistent with the audit's "0/24 and 0/21 for every N ≥ 10" (`docs/ops/CEO_AUDIT_2026-09-02.md:43`).

   **Which of these is the book-selection multiplicity is not a free choice made after the fact: it is recomputed from the same read-only census at seal time and stamped into the seal receipt** (§E item 9). The report-only funnel rows are recorded alongside; they never set the verdict.

Measured baseline: **0 sleeves reach DSR ≥ 0.95** at any defensible trial count (`docs/ops/CEO_AUDIT_2026-09-02.md:14`; 0/24 and 0/21 for every N ≥ 10, `:43`); E[max SR] under the null ≈ 1.06–1.44 (`:14`); the modeled +2.4 book Sharpe survives correction at ≈ 0 % (`:14`); walk-forward held-out folds show 82 % PF>1 (`:14`) and 61/74 PF>1 with geo-mean OOS PF 1.47, selection-conditioned (`:45`) — leaning against zero edge but not purchase-grade.

### §C.3 · Existing sample floors (all citable, none invented)

| Floor | Value | Path |
|-------|-------|------|
| Type-I error, bootstrap | alpha = **0.05**, two-sided 95 % percentile CI | `ftmo_timebox_eval.py:96,:98`; validation `0 < alpha < 0.5` `:310-312` |
| Type-I error, DSR gate | p < **0.05** | `sub_8_2_dsr_mc_fdr.py:33` |
| Opening-day floor | ≥ **4** CE(S)T days with a position opened, per phase | rulepack `:151-160` (`:156`); enforced `challenge_firstpassage.py:68,:176`; `ftmo_timebox_eval.py:77` via rule contract |
| Shared-calendar floor (correlation) | ≥ **20** shared calendar days, else `REFUSED_FEWER_THAN_20_SHARED_CALENDAR_DAYS` | `ftmo_timebox_eval.py:105`, enforced `:1043-1046` |
| **DSR daily-observation floor** | ≥ **60** distinct days with trades, else **INVALID**; below **30** observations the p-value is forced to 1.0 | `sub_8_2_dsr_mc_fdr.py:182-186`; `:149-150`, `:78-79`; per-day aggregation `:58-71` |
| Bootstrap replicate minimum | ≥ **100** replicates | `ftmo_timebox_eval.py:306-307` — **computational** replication only, NOT a market-sample floor |
| Effective (not raw) n | overlapping starts are HAC-adjusted / divided by median resolution time; report ESS, never the raw start count | `ftmo_timebox_eval.py:927-953,:1126`; `challenge_firstpassage.py:405-408,:419-421` |

**No engine on this branch enforces a minimum market sample.** The evaluator computes and reports `p1_hac.effective_n` (`:1126`) but gates nothing on it. That gap is what §C.4 closes.

### §C.4 · The predeclared power/precision rule (Review F3 — this is the correction, with arithmetic)

R2 declared a "minimum-power floor" as binding but supplied no rule, so "powered" could have been assigned after results were known. The rule below is fixed **before** results, uses only existing constants, and shows its arithmetic.

**Convention used (existing, not new).** The framework's operative uncertainty statement is a *precision* statement, not a Neyman–Pearson power statement: the decision number is the bootstrap **lower** bound (`FTMO_BOOK_SPEC:25-26,:58-61`; `ftmo_timebox_eval.py:90`), and the existing worked form of that lower bound is a Wald half-width `hw = z·√(p(1−p)/ESS)` with `z = 1.96` at two-sided 95 %, compared against the 0.80 bar (`challenge_firstpassage.py:409-410,:415,:419-421`; matching `DEFAULT_BOOTSTRAP` alpha 0.05 / `TWO_SIDED_PERCENTILE_95`, `ftmo_timebox_eval.py:96,:98`).

**R-1 · Minimum effective sample (binding).** Let `bar` be the operative P1 lower-bound bar (0.80 under the §B intersection; 0.70 if OWNER resolves OQ-1/P7a to the rulepack-only reading) and `p*` the OWNER-chosen target effect (OQ-2b). The sealed holdout is adequately precise only if the evaluator's reported `p1_hac.effective_n` satisfies

```
ESS_min = z² · p*·(1 − p*) / (p* − bar)²        with z = 1.96
```

Worked values (arithmetic only; ⌈·⌉ applied):

| p\* | bar = 0.80 (intersection) | bar = 0.70 (rulepack-only) |
|---|---|---|
| 0.82 | 1,418 | 40 |
| 0.85 | 196 | 22 |
| 0.86 | 129 | 19 |
| 0.88 | 64 | 13 |
| **0.90 (recommended)** | **35** | **9** |
| 0.92 | 20 | 6 |
| 0.95 | 9 | 3 |

The rule is defined only for `p* > bar`; at `p* = bar` the half-width budget is zero and ESS_min diverges. This is why OQ-2b is a real OWNER choice and not a derivable constant.

**R-2 · Non-overlap floor (cross-check, conservative).** Rolling starts overlap almost completely, so the raw start count must never be used. As an order-of-magnitude sanity anchor, a sealed span of `D` calendar days contains at most `⌊D / 60⌋` non-overlapping P1 windows and `⌊D / 90⌋` non-overlapping two-phase gauntlets (60 and 30 from `ftmo_timebox_eval.py:72,:74`). Applied to the only existing source:

```
D = 2026-01-01 .. 2026-04-06 inclusive = 96 calendar days
  weekdays in span                     = 68
  rolling 60-day starts                = 96 − 60 + 1 = 37   (near-fully overlapping)
  non-overlapping 60-day P1 windows    = ⌊96/60⌋ = 1
  non-overlapping 60+30 gauntlets      = ⌊96/90⌋ = 1
```

**One.** Under every row of the ESS_min table, a single 96-day window fails R-1 by one to three orders of magnitude. This is the arithmetic behind the R2 assertion that the diagnostic window is non-lifting; it is now checkable rather than asserted. The binding number at evaluation time remains the evaluator's own `p1_hac.effective_n` (`:1126`); R-2 is the floor cross-check, not a substitute for it.

**R-3 · DSR observability floor (binding, existing authority).** D.2 is only evaluable if each sealed identity supplies ≥ 60 distinct trading days in the holdout (`sub_8_2_dsr_mc_fdr.py:182-186`), and its p-value is meaningful only above 30 observations (`:149-150,:78-79`). A 96-calendar-day span offers at most 68 weekday sessions; seven of the eight sealed identities are D1 bar-open entries that do not trade daily, so the 60-day floor is expected to bind. **An identity that returns INVALID at sub-gate 8.2 has not passed D.2 and must not be scored as if it had.**

**R-4 · Seeds do not widen the population.** Additional bootstrap seeds resample the same market observations and test Monte-Carlo stability only; they add no independent market data and cannot satisfy R-1. Only **additional non-overlapping sealed windows or a longer sealed OOS span** widen the evidence population. "Multi-seed" is removed as a widening option throughout this contract.

**R-5 · Optional explicit power form (OWNER-CHOICE, not required).** If OWNER prefers a Neyman–Pearson statement with an explicit type-II error, the same quantities give

```
ESS = ( z_α·√(bar(1−bar)) + z_β·√(p*(1−p*)) )² / (p* − bar)²
```

with `z_α = 1.96` (existing, `:409-410` / `:96,:98`). `z_β` has **no existing authority on this branch** — choosing it is a new statistical constant and therefore ROT. Illustrative values at power 0.80 (`z_β = 0.8416`) and 0.90 (`z_β = 1.2816`):

| bar → p\* | power 0.80 | power 0.90 |
|---|---|---|
| 0.80 → 0.90 | 108 | 137 |
| 0.80 → 0.92 | 72 | 89 |
| 0.80 → 0.95 | 42 | 51 |
| 0.70 → 0.85 | 64 | 82 |
| 0.70 → 0.90 | 34 | 42 |

**Recommendation: adopt R-1 (precision form) and do NOT adopt R-5**, because R-1 needs no constant that does not already exist in the codebase, whereas R-5 requires OWNER to mint `z_β`. R-5 is offered only so the choice is visible rather than hidden.

**R-6 · Indicative span (context only, explicitly not a threshold).** If the flag series behaved as one independent observation per non-overlapping P1 window, an ESS of `N` would need ≈ `60·N` calendar days — at the recommended `p* = 0.90` / `bar = 0.80` that is ≈ 2,100 days ≈ 5.8 years of sealed OOS. Real HAC ESS on overlapping starts lies between `⌊D/60⌋` and `D − 59`, so the true requirement is lower than this anchor and higher than the non-overlap floor. This figure is stated so the **cost of the chosen bar is visible before ratification**, not as a gate. If OWNER finds the implied span unacceptable, the honest options are (i) raise `p*`, (ii) resolve P7a to the rulepack-only bar (0.70), or (iii) accept that FTMO admission is not reachable on OOS evidence alone and re-anchor the trigger — all three are OWNER decisions, none is a silent relaxation.

## §D · Refutation clause (predeclared, symmetric — evaluated ONCE after the seal)

**§D is INERT until BOTH parts of OQ-2 are resolved:** OQ-2a (admissible market population) and OQ-2b (target effect `p*`, from which ESS_min follows by §C.4 R-1). The single corrected 96-day diagnostic window is NOT admissible as a lift source (§C.4 R-2, R-3). Once OWNER designates the admissible sealed holdout and `p*`, the following applies to the sealed 8-identity population.

**NO-BUY is LIFTED to `positive-evidence-met` ONLY if BOTH necessary conditions D.1 and D.2 hold simultaneously on the admissible sealed holdout.**

**D.1 — a valid post-repair OOS pass** on the corrected window (E1 Option A applied per receipt row 9; hole backfilled; E4 `--apply` executed per row 11; window-binding verified plan → INI → report identical), evaluated at the timebox 60/30-day horizons (`ftmo_timebox_eval.py:72,:74`) via the moving-block-bootstrap **LOWER** bound (`:90,:96,:98`), meeting **all** of:

- **Power/precision:** the evaluator's reported `p1_hac.effective_n` (`:1126`) ≥ `ESS_min(p*, bar)` per §C.4 R-1, and the sealed span satisfies the R-2 non-overlap floor; AND
- **P1 point ≥ 80 % AND P1 lower-95 ≥ 80 %** — the intersection of rulepack `:480` and builder/timebox 0.80 (`build_book_ftmo.py:54`, `ftmo_timebox_eval.py:90`), pending P7a (receipt row 15); AND
- **breach upper-95 ≤ 10 %** (rulepack `:486`); AND
- **P2-conditional ≥ 85 % AND joint ≥ 65 %** (rulepack `:492`); AND
- **the four non-probability `go_criteria`**, without which this is not the strictest existing set: snapshot freshness ≤ 7 days (`:462`), 0 unadjudicated execution-fidelity mismatches (`:468`), complete intratrade MTM with closed-P&L proxy forbidden (`:474`), and ≥ 1 clean Free-Trial/shadow run with 0 operational defects (`:498`); AND
- **cost class:** the streams are `DXZ_EXECUTION_FTMO_COST_ADJUSTED_V1` under an explicit declaration, not raw DXZ (`ftmo_timebox_eval.py:50,:686-693,:1286-1290`), evaluated at the conservative end of the spread-penalty band (`FTMO_BOOK_SPEC:58-61`); AND
- **Necessary screen (not the bar):** net expectancy after FTMO costs > 0, with failures/zeros retained and missingness documented (`docs/ops/evidence/2026-09-04_astra_ftmo_book_analysis.md:130`). A break-even or positive window that does NOT clear the criteria above does NOT lift NO-BUY.

**D.2 — the DSR / multiple-testing correction rejects the null.** Sub-gate 8.2 returns PASS, i.e. `p_value < DSR_P_MIN = 0.05` (equivalently DSR probability > 0.95) (`sub_8_2_dsr_mc_fdr.py:33,:225-228`), computed with:

- each identity's **sealed `selection_trial_count`** from its Q07/Q08/Q16 lineage, consumed through the engine's unchanged effective-candidate rule — fleet default 369 when missing or `< 2`, otherwise `369 + c − 1` (`:34,:47,:161-176`);
- **the 154 measured census arms are NOT substituted for selection multiplicity** (`:40-46`; `emit_q16_lineage.py:16-21`; `opt_census.py:36` is a measurement count);
- the sealed book/read-level multiplicity of §C.2 item 2, recomputed at seal time, reported alongside with the engine's report-only funnel rows (`:38-39,:103-143`);
- at least 60 distinct trading days per identity, else the gate returns INVALID and D.2 is **not met** (§C.4 R-3, `:182-186`).

In-sample PF>1 is never a substitute for D.2.

**D.3 — supporting input, never sufficient, never able to lift or block alone.** Governed-only live attribution (manual `magic=0` trades excluded, receipt row 1 `:8`) is reported alongside with its stated uncertainty. Decisive weight rests on D.1 and D.2. Rationale: governed live is −469 USD / 30 days with Sharpe CI [−6.8, +4.6] — statistically non-informative at this sample (`docs/ops/CEO_AUDIT_2026-09-02.md:14`). Its minimum informative sample and any numeric positive bar are **OQ-5, unresolved**; until then it is corroborative context, not a gate.

**NO-BUY is KEPT (the lift is refuted) if ANY of:**

- OQ-2a or OQ-2b is unresolved, or the admissible source fails the §C.4 R-1 / R-2 floors;
- any sealed identity fails the §C.4 R-3 DSR observability floor (sub-gate 8.2 INVALID);
- **the sealed roster is not fully read** — e.g. 11910:NZDUSD returns no result — other than in the manner predeclared under OQ-6;
- a fresh `PASS` for another year (e.g. 2024) re-appears — proves the dispatch repair failed;
- the OOS window still measures inside the calendar hole (no news events), i.e. E1 Option A or the backfill did not actually land;
- the streams are raw DXZ rather than FTMO-cost-adjusted, or the evaluator returns any `REFUSED_*` label;
- any date, model, identity, cost-profile or window substitution occurs after the seal;
- any of the eight rulepack `go_criteria` in D.1 is not met, including net expectancy after FTMO costs ≤ 0;
- the DSR correction does not reject the null at p < 0.05, or the multiplicity actually used is the 154 measured arms rather than a sealed selection count;
- **passing the 25-pair counter alone** — explicitly NOT sufficient to lift NO-BUY.

The cheapest decisive test remains a valid, adequately-powered post-repair OOS pass; the ~55-run / ~3-terminal-hour single-window probe (`docs/ops/CEO_AUDIT_2026-09-02.md:45`) is a diagnostic toward it, not itself the lift source.

## §E · Contamination and seal procedure

**Contamination (predeclared — any one voids the evaluation):**

1. **Look-ahead / mutable input** that changes under evaluation. Precedent: an EV script read a mutable stream dir that shrank from 21 → 5 sleeves, throwing results ≈ 16× off (`docs/ops/CEO_AUDIT_2026-09-02.md:15,:56`). `ftmo_timebox_eval.py` SHA-pins every declared input and REFUSES DB/farm-state references (`:233-258,:375-376,:443-444`).
2. **Roster/identity change after results are seen**, including a silent partial read of the sealed 8 (§A rule e).
3. **Calendar re-run, window substitution, or cost-profile substitution after the seal.**
4. **Refitting** leverage/overlay/composition on the scoring sample (`challenge_firstpassage.py` stages 1–2 are in-sample-selected and must NOT be used as the acceptance number; only the preregistered 1x block `:371-377` is selection-free).
5. **Evaluator-code change after the seal.** This is not hypothetical, and it is demonstrable to the byte. The independent review quoted `ftmo_timebox_eval.py` = `abe760efc399b74abe48da6d6dadc60bce70c75fbd689d5c55b2ac35dca7c68d`; that digest is exactly the **CRLF working copy of the parent commit `5bac8eaccb^`**. The tip commit `5bac8eaccb` then modified the module (a 2-line change to `_load_ftmo_terms` accepting the `qm.ftmo-current-pool-cost-snapshot/v1` schema), so the same path now hashes to `cbea3b1c…`. `prepare-config` would not have noticed: it pins inputs, not the evaluator (`:482-501`). A post-seal evaluator change can therefore alter a result with an unchanged config — which is why the module bytes are sealed at item 5 below.

**Digest convention (binding).** All seal digests are SHA-256 over **LF-normalized bytes** (git blob bytes), recorded together with the CRLF working-copy digest whenever the two differ. This is not pedantry — the two conventions were mixed inside a single review: `sub_8_2_dsr_mc_fdr.py` (unchanged since `4ca8d87817`) hashes to `d0117db69fded78262194c92b8dd40fbecccd43be21255220d7439043688f019` as CRLF working-copy bytes and to `906bef88c9d903c7dccdc01a60a4a9e65c0fcd70ca99879836dd35ac354e8fe1` LF-normalized, and the review quoted the LF form for that file while quoting the CRLF form for `ftmo_timebox_eval.py` and `build_book_ftmo.py`. All three files carry CRLF in this worktree. A seal that does not state its convention is not a seal; the LF digest is authoritative and the CRLF digest is recorded beside it.

**Seal procedure — before the first result is opened, compute and record a sha256 over each of the following.** Items 5–8 are the Review-F5 extension: the evaluator and the DSR multiplicity inputs were previously unsealed.

| # | Sealed input | Path / note |
|---|--------------|-------------|
| 1 | This contract text (R3) | `docs/ops/OWNER_VORLAGE_2026-09-05_ftmo_positive_evidence_test.md` |
| 2 | The roster of the 8 identities with their exact stream SHA-256s | `docs/ops/evidence/2026-09-04_fund_score_current_population.md` (digests reproduced in §A) |
| 3 | Rulepack FILE sha256 `298ef1285eca49ea7f010ebc0a9353b5a821fccb40a025be129f5ca5314fd992` | `tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_SWING_V2.json` — encodes the `go_criteria` numbers (`:462/:468/:474/:480/:486/:492/:498/:504`) |
| 4 | Provider snapshot `snapshot_sha256` `c199b8f5f528cce5a93f4751f63394de63e5fe832483ac9c4b9d0314732d2905` | embedded at rulepack `:24`; the page-body snapshot, distinct from item 3 |
| 5 | **Evaluator module** `tools/strategy_farm/portfolio/ftmo_timebox_eval.py` — worktree `cbea3b1cd77c4fc801e60710e372bb4b000062495f6d304b79d6528a849ca356`, LF `f138402e71b9ab6fec468ddd527aed3491faed003cd831ae12dcac3f2a9fec45` | implements resampling, outcomes, HAC, refusals |
| 6 | **Supporting engines**: `ftmo_p1_mc.py` `66e7f7d4ba3b224e5a439afa45dacc7973e4e0331452b562b6734fbb08993969`; `challenge_firstpassage.py` `63269e9fcfe3892acff73f76f6a12fe07af3a2381b66ded55e43213e832da9ed`; `ftmo_rules_engine.py` `dd1bd87ec6489d33f399418b0da3fa828e0bc09384a1ed28695e1ca6f548972a`; `ftmo_rule_contract.py` `011ab015ac386c1fde88db95bb779aa2bf1e967eccb572d7405e033977e45e39` | worktree digests; recompute LF digests at seal |
| 7 | **Builder** `tools/strategy_farm/portfolio/build_book_ftmo.py` `255322de5e4d47cc1dde7a0424101e4d3bb28e939c4e60ea48334a71c3dc7bc5`; **scorer** `fund_score.py` `49e281710ab023c9c9e53741971a576bc095ba369ae511ff58c06408fd14d2e0`; **counter** `book_build_guard.py` `48dd38b70bfd0f5e37227eecb401ec94a11b1dc26974ce06ab8e6c35723df71c` | floors `:53,:54`; formula `:94-103`; counter `:28` |
| 8 | **DSR engine + multiplicity provenance**: `sub_8_2_dsr_mc_fdr.py` (LF `906bef88…`, worktree `d0117db6…`); `emit_q16_lineage.py` `d518dee53016ca26f89f8e775c589603d3460e244dbc878c6fa70fbd4687d3cc`; `opt_census.py` `17f19954bc481755788338cf1b2c5ea3c0d2f425c7daa3ebf73fe7b3fcf2ef18` | threshold `:33`, effective-count rule `:161-176` |
| 9 | **The DSR multiplicity inputs themselves**: every per-identity Q07/Q08/Q16 lineage artifact carrying `selection_trial_count`, by path + sha256; and the book/read-level selection count of §C.2 item 2, recomputed read-only at seal time and stamped with its census timestamp | the value must exist in the receipt BEFORE any result is opened |
| 10 | **The prepared config**: output of `ftmo_timebox_eval.py prepare-config`, by sha256 | pins inventory, fund_scores, cost snapshot, streams and rulepack (`:482-501`) — but not the evaluator, hence item 5 |
| 11 | **The exact FTMO cost snapshot** actually consumed, by path + sha256, and its declared class | `DEFAULT_COST_SNAPSHOT` `build_book_ftmo.py:45`, expected digest `:51`; accepted stream class `ftmo_timebox_eval.py:50` |
| 12 | **The concentration/tail policy** `concentration_tail_limits.v1.json` `77a3b67312d199e06ad39c10a4404ab505b4041de0701ce4312a13c8cdf827da` | `status OWNER_RATIFIED` `:3` |
| 13 | **The calendar bundle sha AFTER the E1 Option A repair and the 2025-05..2026-06 backfill**, plus the new bundle identity and repin | receipt rows 9 / 11 (`:18,:20`) |
| 14 | **The resolved OQ answers**: OQ-2a population, OQ-2b `p*` and the resulting `ESS_min`, OQ-6 roster-gap handling, OQ-7 cost class | recorded as literal values in the receipt, not as references to a pending decision |

Then: run `ftmo_timebox_eval.py prepare-config` so the evaluator input digest is frozen; **OWNER (sole human authority) signs the sealed contract**; write the once-only evaluation receipt AFTER the seal. Any change to items 1–14 after signature voids the evaluation and requires a new seal.

**Who signs:** OWNER only. This is a ROT purchase-adjacent decision; automatic purchase is forbidden (rulepack `:500-505`); T_Live / AutoTrading / deployment stay separate OWNER ceremonies.

## §F · Decision receipt — amend the EXISTING pending row 18 in place

Receipt row 18 already exists and is PENDING (`decisions/2026-09-02_owner_receipts_ceo_asks.md:28`). **Do not append a new row 9 or a second row 18.** Replace the Effect cell of row 18 with:

> Seals population (8 identity-bound Q08 streams, roster + stream SHA-256 in §A), metric+thresholds (all eight rulepack `go_criteria` `:462/:468/:474/:480/:486/:492/:498/:504`, builder floors `:53/:54`, FUND_SCORE, concentration, timebox 60/30 lower-bound with the strict **P1 point ≥ 0.80 AND lower-95 ≥ 0.80** intersection pending P7a row 15, DSR p<0.05 over the **sealed per-identity `selection_trial_count`** — never the 154 measured census arms), the **predeclared power/precision rule** (§C.4: `ESS_min = 1.96²·p*(1−p*)/(p*−bar)²` on the evaluator's `p1_hac.effective_n`, plus the non-overlap and 60-trading-day floors; the single 96-day window yields exactly one non-overlapping P1 window and is therefore non-lifting), admissible evidence class (post-repair OOS-2026 after E1 Option A + backfill per rows 9/11, FTMO-cost-adjusted streams only, governed-only live SUPPORTING not sufficient, no re-selection, predeclared roster-gap handling for 11910:NZDUSD), the extended seal (§E items 1–14, incl. evaluator and DSR multiplicity inputs, LF-normalized digests), and the symmetric refutation clause; **§D inert until OQ-2a AND OQ-2b are answered**; ROT (purchase-adjacent), no Auffangregel; lifting NO-BUY still requires a separate signed OWNER purchase decision.

Row 18 keeps its class: ROT, no Auffangregel.

## §G · Anchor re-verification (Review F6) — what was stale in R2 and is corrected here

Every citation in R2 was re-checked on this branch at commit `5bac8eaccb`. Corrections applied:

| R2 claim | Status on this branch | R3 |
|---|---|---|
| Sibling evidence files "[cross-branch — re-verify at seal]" | All three present (`2026-09-04_astra_ftmo_book_analysis.md`, `2026-09-05_news_calendar_timestamp_defect.md`, `2026-09-04_fund_score_current_population.md`) | markers removed; anchors cited directly |
| "receipts file ends at row 6"; "rows 7–8 absent"; "append as row 9" | Rows 1–18 present; row 18 is this test, PENDING (`:28`) | §F amends row 18 in place |
| "receipt row 8 PENDING" (calendar) | Row 8 DECIDED YES (`:16`); row 9 = E1 **Option A**, task `0da3dfec` (`:18`); row 11 = E4 after backfill, task `49a8c88b` (`:20`) | OQ-3 **retired as answered** |
| P1 conflict "unresolved, do not resolve unilaterally" | Unification already commissioned: row 15 / P7a, task `97a0ed31` (`:24`) | OQ-1 reframed: commissioned, not delivered; intersection applies meanwhile |
| `fund_score.py` "111 lines; formula at `:59/:62/:65`; no formula string at `:94-103`" | File is 178 lines; formula computed `:94-100`; formula **string** at `:103` | §B corrected; the R2 parenthetical was inverted |
| `ftmo_timebox_eval.py:77` design_bar; `:63,:65` horizons; `:81-85` bootstrap; `:92` shared days; `:48` cost-attestation; `:218-235,:345-346` mutable refusal | Actual: `:90`; `:72,:74`; `:93-99`; `:105`; `:56`; `:233-258,:375-376,:443-444` | all corrected |
| `challenge_firstpassage.py:32,161` four-day; `:355-361,:378` prereg 1x; `:389-390` ESS | Actual: `:32-33,:68,:176`; `:371-377`; `:405-408,:419-421` | all corrected |
| `sub_8_2_dsr_mc_fdr.py:48-52` = "the DSR minimum" | `MIN_COHORT_PEERS = 1` is at `:54`; `:48-53` is its comment | corrected; value stated |
| `opt_census.py:36` = "declared trial count 154 per identity" for DSR | 154 is a **measurement** census count, not `selection_trial_count` | §C.2 / D.2 rewritten (Review F2) |
| Rulepack go_criteria `:459-464/:477-481/:483-487/:489-493/:495-499` | Actual `:458-463/:476-481/:482-487/:488-493/:494-499`; two further criteria at `:464-469` and `:470-475` were omitted entirely | §B table now lists all eight (Review F4) |
| Swing leverage "rulepack `:255-257`" | Rule at `:254-260`, params `:259`; CARRIED_OVER status lives in the snapshot `:724-725,:728-729,:808-816,:824` | corrected |
| "~3 terminal-hours (`CEO_AUDIT:14`)" | That figure is at `CEO_AUDIT:45` (~55 runs) | corrected |
| Review's own hash for `ftmo_timebox_eval.py` (`abe760ef…`) | Is the CRLF working copy of the **parent** commit `5bac8eaccb^`; the tip commit changed the module, which now hashes `cbea3b1c…` (CRLF) / `f138402e…` (LF) | recorded as the §E.5 contamination precedent; §E item 5 now seals the module bytes |
| Review's hash for `sub_8_2_dsr_mc_fdr.py` (`906bef88…`) | File unchanged since `4ca8d87817`; the digest is the **LF-normalized** form, while the same review quoted CRLF forms for the other two modules | §E digest convention added (LF authoritative, CRLF recorded beside it) |

Anchors re-verified as **correct in R2 and unchanged**: rulepack file sha `298ef128…`; provider snapshot `c199b8f5…` at rulepack `:24`; all provider rule lines in §B; builder `:53/:54/:75/:76/:77/:471/:472`; `book_build_guard.py:28`; all `concentration_tail_limits.v1.json` line refs; `FTMO_BOOK_SPEC:13,:15,:19`; `CEO_AUDIT:14,:15,:43,:56`; receipt row 1 (`:8`) and row 6 (`:13`); `emit_q16_lineage.py` and `opt_census.py` module digests; the eight stream SHA-256 prefixes (now given in full).

---

## Open questions for OWNER (do not resolve unilaterally)

- **OQ-1 (ROT, = decision Q3) — reframed, not new.** Which P1 bar governs: builder/timebox lower ≥ 0.80 (`build_book_ftmo.py:54`, `ftmo_timebox_eval.py:90`) or rulepack point ≥ 80 % AND lower-95 ≥ 70 % (`FTMO_2S_100K_SWING_V2.json:480`)? The unification is **already commissioned** (receipt row 15 / P7a, task `97a0ed31`, `:24`) but not delivered. Until it lands this test applies the **intersection: point ≥ 0.80 AND lower-95 ≥ 0.80**. *Recommendation: confirm the intersection as the interim rule; let P7a deliver the permanent reconciliation.*
- **OQ-2a (population, GATES §D).** Accept the single corrected 96-day window as the positive-evidence source, or require **multiple non-overlapping sealed windows / a longer sealed OOS span**? Per §C.4 R-2 the single window contains exactly one non-overlapping P1 window and cannot satisfy any row of the ESS_min table. **Multi-seed is explicitly not an option** (§C.4 R-4). *Recommendation: require a longer sealed OOS span; the single window stays a diagnostic.*
- **OQ-2b (target effect `p*`, GATES §D).** Which true P1 pass probability must the test be able to certify? `ESS_min` follows arithmetically from `p*` and the operative bar (§C.4 R-1 table) — this is the only free number in the power rule. **OWNER-CHOICE. Recommendation: `p* = 0.90`**, giving ESS_min = 35 at bar 0.80, or 9 at bar 0.70 if OQ-1 resolves to the rulepack reading.
- **OQ-2c (form of the rule, OWNER-CHOICE).** Adopt the precision form R-1 only, or additionally the Neyman–Pearson form R-5? R-5 requires OWNER to mint `z_β`, which has no authority on this branch. *Recommendation: R-1 only.*
- **OQ-4 (provider).** Swing leverage 1:30 FX / 1:15 metals+oil is CARRIED_OVER and was NOT re-confirmed on 2026-09-04 (`docs/ops/evidence/2026-09-04_ftmo_official_rules_snapshot.json:724-725,:728-729`; dead URL `:808-816`; scope limit `:824`). Must be re-sourced before any purchase-adjacent decision.
- **OQ-5 (live weighting).** Governed-only live is −469 USD / 30 days, Sharpe CI [−6.8, +4.6] (`CEO_AUDIT:14`). Is a live sample this short admissible AT ALL as positive live evidence, or strictly supporting (as §D.3 sets it)? If admissible, what minimum informative sample and numeric positive threshold? *No existing authority — OWNER-CHOICE. Recommendation: keep strictly supporting.*
- **OQ-6 (roster gap, ROT — NEW in R3).** 11910:NZDUSD is absent from the only existing OOS-2026 campaign (`campaign_plan.json`, 50 distinct pairs). Predeclare: (a) the gap refutes the lift, (b) the missing identity is scored as a failure, or (c) a make-up run is added before the seal. *Recommendation: (c); failing that, (b). Deciding this after results would be re-selection under §A rule c.*
- **OQ-7 (cost class, NEW in R3).** The campaign runs `cost_profile = DXZ_CANONICAL_REAL_TICKS_V1`, but the evaluator refuses raw DXZ streams and accepts only `DXZ_EXECUTION_FTMO_COST_ADJUSTED_V1` (`ftmo_timebox_eval.py:50,:686-693,:1286-1290`). Authorize the FTMO cost re-attestation and re-emission before evaluation, or designate a different admissible stream source. *Recommendation: authorize the re-attestation; without it D.1 is not evaluable at all.*
- **OQ-3 — RETIRED (answered).** Calendar-repair option E1 is decided: **Option A**, receipt row 9 (`decisions/2026-09-02_owner_receipts_ceo_asks.md:18`, task `0da3dfec`), with E4 `--apply` after the backfill per row 11 (`:20`, task `49a8c88b`).
- **OQ-8 (cross-branch re-verification) — replaces R2's OQ-6.** All R2 anchors have been re-verified on this branch at commit `5bac8eaccb` and the stale ones are tabulated in §G. **Re-verify §G once more at seal time**, because at least one sealed module (`ftmo_timebox_eval.py`) changed in the tip commit itself, after the independent review was written.
