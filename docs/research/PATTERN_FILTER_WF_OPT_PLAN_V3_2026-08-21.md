# Pattern-Filter-Optimierung v3 — Walk-Forward-Jahreszensus → Auswahl → Gesamttest → Portfolio

**Status:** VERBINDLICH (OWNER-ratifiziert 2026-08-21 abends, 13 Einzelentscheide im Chat;
Entscheidungsrecord: `decisions/DL-089_pattern_filter_wf_census_v3.md`)
**Autor:** Claude (Orchestrator) · **Vorgänger:** `PATTERN_PERMISSION_FILTER_PLAN_V2_2026-08-13.md` (Messinstrument + A1–A8 bleiben gültig), `DL-088` (Hebelklassen + Q16-Overfit-Vertrag)
**Pilot:** QM5_13213 / USDJPY.DWX (Instrument QM5_21501 existiert, A1-korrigiert)

## 0 · Die Kette in einem Satz

Codex erweitert den Q10-Überlebenden um Pattern-Filter- und numerische Inputs und baut ihn
als `_opt`-Variante; die Fabrik misst **jedes Pattern je Richtung in jedem Einzeljahr**;
die KI wählt daraus per vorregistrierter Walk-Forward-Regel bis zu **3 Buy- und 3
Sell-Filter**; ein **Gesamttest über den maximalen Zeitraum** bestätigt; der bestätigte
Challenger läuft durch **Q15/Q16** (Overfit-Vertrag) und wird für **FTMO und DXZ getrennt**
portfolio-bewertet.

## 1 · OWNER-Entscheide (ratifiziert 2026-08-21, vollständig)

| # | Frage | Entscheid |
|---|---|---|
| 1 | Auswahlregel | **Konsistenz**: Filter qualifiziert nur bei Verbesserung in **≥ 2/3 der Auswahljahre**, je **≥ +5 % relativ** |
| 2 | Erfolgsmaß | **return_to_maxdd** (je Jahr, gegen Baseline desselben Jahres) |
| 3 | OOS-Schutz | **Ankernder/expandierender Walk-Forward**, Mindestfenster 3 Jahre |
| 4 | Kombination | **ODER** (Blacklist: jedes gewählte Pattern sperrt seine Richtung für sich) |
| 5 | Auswahltiefe | bis zu **3 Buy + 3 Sell** (0 = „kein Filter" ist immer Kandidat und Pflicht-Kontrollarm) |
| 6 | Frequenz-Boden | Aktivitätskriterium (≥ 10 Entry-Handelstage je gewertetem Jahr, pro-rata) — **reißt EIN Jahr, ist der Filter unzulässig**, ausgeschlossen VOR der Messung der Rendite |
| 7 | DSR-Trial-Zahl | **154** (77 Muster × 2 Richtungen = Suchraum; Einzeljahre sind wiederholte Messung derselben Hypothese, keine eigenen Trials) |
| 8 | _opt-Umfang | Pattern-Filter-Inputs **und** numerische Parameter-Inputs werden JETZT eingebaut; **optimiert wird in Phase 1 nur der Pattern-Filter** — die numerische Optimierung ist Phase 2 |
| 9 | Pilot | QM5_13213/USDJPY, ein Paar komplett durch, dann Skalierungsentscheid |
| 10 | Portfolio | **beide Bücher getrennt** bewertet (FTMO-Regeln ≠ DXZ-Regeln) |
| 11 | Jahres-Einzeltests | Kernprinzip: jedes Jahr wird einzeln getestet — Konsistenz über Jahre ist der Overfitting-Schutz |
| 12 | Interpretation | die Auswahl trifft die KI (Claude) anhand der Jahresmatrix, streng nach Regel #1/#6 — die Regel steht VOR der Messung fest (dieses Dokument) |
| 13 | Umsetzung | Stück für Stück über Router-ToDos; Codex baut, Fabrik misst, Claude wertet aus |

### Explizite Supersessions (OWNER 2026-08-21, bewusst)

- **E0-1 (Plan v2, „Zensus selegiert nicht")** ist für v3 aufgehoben: die Auswahl IST
  datengetrieben aus der Zensusmatrix. Die Ehrlichkeit wird stattdessen erzwungen durch
  (a) vorregistrierte Auswahlregel, (b) Walk-Forward-Prüfjahre, (c) `declared_trial_count
  = 154` in der DSR-Deflation, (d) versiegeltes Q16-Head-to-Head. |
- **Charter-Kappe „≤ 1 Prädikat/Sleeve"** → **≤ 3 je Richtung** (DL-088-konform).

## 2 · Messmatrix (Pilot)

**Jahre:** Kalenderjahre **2019–2025** (7). 2026 YTD wird NICHT zur Auswahl verwendet
(zu kurz, pro-rata-verzerrt); es bleibt als Beobachtungsfenster im Gesamttest enthalten.

**Zellen je Jahr:** 154 Filterarme (77 Muster × Richtung Buy/Sell, Blacklist-Semantik,
je Arm genau EIN Muster aktiv) **+ 1 Baseline** (kein Filter) = **155**.

**Läufe:** 155 × 7 = **1 085 Einjahres-Backtests** + Walk-Forward-Kombinationsprüfungen
(je Schritt 1 Lauf mit der gewählten Kombination im Prüfjahr, 4 Schritte) + **2
Gesamtläufe** (Kombination + Baseline über den vollen Zeitraum) ≈ **1 091 Läufe**.
Einjahresläufe sind kurz; erwartete Flottenzeit deutlich unter den 46 h des v2-Plans
für 9 Paare. Gemessen wird real im Pilot — das ist Teil seines Zwecks.

**Walk-Forward-Protokoll (ankernd, Mindestfenster 3):**

| Schritt | Auswahl auf | Prüfjahr |
|---|---|---|
| 1 | 2019–2021 | 2022 |
| 2 | 2019–2022 | 2023 |
| 3 | 2019–2023 | 2024 |
| 4 | 2019–2024 | 2025 |

Je Schritt: Regel #1/#6 auf die Auswahljahre anwenden → ≤ 3 je Richtung wählen (Rangfolge
nach Konsistenzgrad, dann mittlerer Relativverbesserung) → Kombination im Prüfjahr laufen
lassen. **Stabilitätskriterium:** die Auswahl gilt als walk-forward-bestätigt, wenn die
Kombination in **≥ 3 der 4 Prüfjahre** return_to_maxdd nicht verschlechtert UND die
finale Auswahl (Schritt 4) in ≥ 2 der 3 Vorschritte identisch oder Teilmenge war.
Die Einzeljahresmatrix wird EINMAL gemessen; die WF-Schritte sind Auswertungsprotokoll
darüber — nur die Kombinationsprüfungen erzeugen neue Läufe.

**Ableitung Selbstauskunft je Zelle:** Trades, Entry-Handelstage (Aktivitätskriterium!),
PF, Netto, MaxDD, return_to_maxdd — aus dem vorhandenen Q02-Selbstreport-Stream; kein
neues Reportformat.

## 3 · Bau-Aufträge (Router-ToDos, Reihenfolge)

**OPT-P0 (Codex) — `_opt`-EA bauen.** `QM5_13213` → neue EA-Identität mit Suffix `_opt`
(eigene ea_id nach Registry-SOP, mirror sibling, Magic-Rows, Resolver-Regen, seriell).
Basis ist das A1-korrigierte Zensus-Instrument QM5_21501 (nebenwirkungsfreier
Straddle-Plan, symmetrisches Veto VOR Platzierung). Inputs: `opt_pp_buy1..3`,
`opt_pp_sell1..3` (Pattern-IDs, 0 = aus) **plus** die numerischen Kandidaten-Parameter
(Stop-Distanz, TP-Verhältnis, Range-Fenster — konkrete Liste aus der Strategy Card,
Phase-2-Nutzung, im Pilot auf Elternwerten fixiert). Kompilieren, `build_check
-EALabel`, 0/0. **Vorbedingung:** MQL5-Fixture-Harness-Verdikt grün (Work-Item
`83b89730`, steht auf Queue-Platz 1) — vorher läuft kein Zensus.

**OPT-P1 (Codex) — Jahresmatrix-Tooling.** Generator für (Jahr × Arm)-Setfiles
(Datumsfenster je Kalenderjahr; ENV=backtest, RISK_FIXED; Pattern-Inputs je Arm) und
Enqueue-Werkzeug, das die 1 085er-Matrix als append-only Work-Items mit eigener
Phase `OPT_CENSUS` einreiht (eigener Pool, zählt NICHT in Q02-Metriken; Ledger mit
`declared_trial_count=154` wird beim Anlegen geschrieben, Schema `qm.opt-census.v1`).
Idempotent: erneutes Enqueue erzeugt keine Duplikate.

**OPT-P2 (Fabrik) — Matrix messen.** Normale Dispatch-/Worker-Strecke.

**OPT-P3 (Claude) — WF-Auswertung + Auswahl.** Regelanwendung exakt nach §2, Ledger
vollständig (jede Zelle, jede Ausschlussursache, jede Schrittauswahl), Empfehlungsbericht
an OWNER mit der gewählten Kombination.

**OPT-P4 (Fabrik) — Gesamttest.** Kombination + Baseline über 2019–2026-max; DSR
(deflationiert mit 154) und PBO nach DL-088 auf der Ledger-Matrix.

**OPT-P5 — Q15/Q16-Anschluss.** Die bestätigte `_opt`-Kombination wird als Q15-Challenger
eingefroren und läuft das bestehende, unveränderte Q16-Head-to-Head gegen den
Amtsinhaber (inkl. unveränderter Q02→Q10-Kaskade als „Gesamttest mit besten Parametern"
im Sinne von DL-088 §3).

**OPT-P6 (Claude) — Portfolio.** Getrennte Bewertung FTMO/DXZ nach deren jeweiligen
Regeln; Vorlage an OWNER (Buch-Aufnahme ist Q11/Q12 = OWNER-Gate).

**Phase 2 (separat, nach Pilot):** numerische Parameter-Optimierung auf denselben
`_opt`-Inputs (AI_PARAM-Hebel, ≤ 5 Werte je Parameter je DL-088, Plateau-Median).

## 4 · Nicht verhandelbar (geerbt)

Kein Lauf vor grünem Fixture-Harness-Verdikt · Q16-Kriterien/Verdikt-Logik unangetastet
(ROT) · alte Zeilen bleiben Evidenz (append-only) · Aktivitätskriterium zählt
Entry-Tage (Goodhart-Schutz) · keine T_Live-Berührung · OPT_CENSUS-Pool getrennt von
Q02-Durchsatzmetriken · Auswahlregel dieses Dokuments ist vor der Messung versiegelt —
eine nachträgliche Regeländerung wäre ROT (neuer OWNER-Entscheid nötig).
