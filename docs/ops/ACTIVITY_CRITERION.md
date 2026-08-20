# ACTIVITY_CRITERION — Herkunft der 250, und was ihre Korrektur wert ist

**Stand:** 2026-08-19 · Work Order Runde 8 §1
**Erzeuger:** `tools/strategy_farm/portfolio/audit_activity_criterion.py`,
`audit_activity_contribution.py`, `audit_activity_marginal.py`
**Artefakte:** `artifacts/audit_activity_criterion_20260819.json`,
`artifacts/audit_activity_contribution_20260819.json`,
`artifacts/audit_activity_marginal_20260819.json`

---

## 0 · Die Antwort in drei Sätzen

> **Die 250 ist ein undokumentierter Implementierungsfilter** — sie steht in keiner
> ratifizierten Spezifikation, sondern wurde in zwei Schritten von 600 über 500 auf 250 gesenkt,
> jedes Mal ausdrücklich, um den Pool zu vergrößern. Ihre Korrektur ist ein Bugfix, keine
> Schwellenänderung.
>
> **Sie zurückzunehmen bringt acht Paare zurück** — und **verschlechtert das Buch**: am
> pessimistischen Intraday-Boden fällt die Finanzierungsrate von 26 % auf 16 %.
>
> **Die Ursache ist Konzentration, nicht Frequenz.** Fünf der acht sind dasselbe Symbol. Nimmt man
> nur die drei auf anderen Symbolen, steigt die Rate auf 30 %.

---

## 1 · Herkunft — §1.1 beantwortet

### 1.1 Wo die 250 steht

| Fundstelle | Rolle |
|---|---|
| `tools/strategy_farm/portfolio/challenge_book_60d.py:83` | `MIN_DAYS, MIN_TRADING_DAYS, DORMANCY_DAYS = 250, 4, 30` — die Definition |
| `challenge_book_60d.py:161` | `if len({c for _, c, _, _ in ev}) < MIN_DAYS: continue` — die Anwendung |
| `challenge_book_60d.py:259` | Pool-Ausgabe, beschriftet als „>=250 trading days" |
| `tools/strategy_farm/portfolio/dormancy_exposure.py:40` | `MIN_DAYS = 250  # same close-day floor as challenge_book_60d.py` — Kopie |
| `challenge_overlay.py:198` | `("unlimited (FTMO 2024+)", 250)` — **andere Bedeutung**, ein Horizont-Etikett, kein Filter |

**Was der Filter tatsächlich zählt:** `len({c for ...})` über die **Schlusstage** — die Zahl
verschiedener Tage, an denen eine Position *geschlossen* wurde. Nicht die Spanne, nicht
Kalendertage.

### 1.2 Kontraktkriterium oder Implementierungsentscheidung — eindeutig Letzteres

Der Code dokumentiert seine eigene Herkunft, `challenge_book_60d.py:78–82`:

> *„250 rather than 500: the 500-day floor was inherited from the sprint-era work, where a long
> window was needed for stability. A 60-day KPI resolves in ~43 trading days, so a 250-day sleeve
> still yields ~200 starts. **Halving the floor more than doubles the pool, 7 -> 15, and admits
> 10128 and 10145**, the only two sleeves ever marked challenge_ready."*

Und eine Stufe davor, `docs/ops/CODEX_BRIEF_ftmo_next_step_2026-07-27.md:70`:

> *„`MIN_DAYS` was lowered 600 -> 500 specifically to admit …"*

**Die Kette ist 600 → 500 → 250, und jede Stufe wurde damit begründet, dass sie bestimmte Sleeves
hereinlässt.** Das ist eine Stellschraube für die Poolgröße, kein Zulassungskriterium eines Venues.
Keine Fundstelle in `decisions/`, keiner Spezifikation, keinem OWNER-Beschluss.

**Damit ist §1.1 beantwortet: undokumentierter Implementierungsfilter.** Seine Korrektur fällt
nicht unter §3.3.

### 1.3 Wo das echte Kriterium steht — und der Befund dahinter

Das von OWNER genannte Kriterium „mindestens 10 Handelstage pro Jahr" ist **im Bestand nicht als
geschriebene Regel auffindbar.** Was auffindbar und erstquellenbelegt ist, steht in
`docs/ops/evidence/2026-07-27_ftmo_phase2_and_funded_rules.md`:

| Regel | Wert | Status |
|---|---|---|
| Minimum Trading Days je Challenge-Phase | **4** | erstquellenbelegt (FTMO Trading Objectives) |
| Definition Trading Day | Tag mit **mindestens einer neu eröffneten** Position; Schließen allein zählt nicht | erstquellenbelegt |
| Inaktivitäts-/Dormanz-Schwelle | — | **`NOT ESTABLISHED`** |
| Funded Account: Minimum Trading Days | **existiert nicht** | erstquellenbelegt |

**Drei Konsequenzen, und die zweite ist die unbequeme:**

1. **Die 4-Tage-Regel ist bereits korrekt implementiert** — `challenge_book_60d.py:229`,
   `traded >= MIN_TRADING_DAYS` mit `MIN_TRADING_DAYS = 4`, geprüft *innerhalb* des Fensters. Der
   250-Filter ist also nicht die Umsetzung des Venue-Kriteriums; das steht daneben und stimmt.
2. **Der 250-Filter ist gar kein Zulassungskriterium, sondern eine Stichprobenanforderung** — er
   entscheidet, ob ein Sleeve genug Historie hat, um daraus ein Buch zu *messen*. Ihn zu senken
   lässt keine Sleeves ins Buch, sondern in die **Messung**, mit dünnerer Statistik je Sleeve.
3. **Das 10-pro-Jahr-Kriterium ist bisher nur OWNER-Wissen.** Das ist selbst ein Befund: die
   Zahl, gegen die die Angebotsplanung rechnen soll, steht nirgends. → **OQ-18**.

Der Widerspruch aus §1.1.4 existiert nicht als Datumsfrage — es gibt keine zwei konkurrierenden
Beschlüsse, sondern einen Code-Filter ohne Beschluss und ein Kriterium ohne Niederschrift.

---

## 2 · Neuauszählung gegen ≥ 10 Handelstage pro Jahr — §1.2

**[MESSUNG]** 218 Streams, jahrweise ausgewertet, nicht als Durchschnitt. Jahre innerhalb der
Spanne ohne Stream-Zeilen zählen als null Handelstage; angebrochene erste und letzte Kalenderjahre
werden nicht gegen das Vollkriterium gehalten.

| | |
|---|---|
| Streams geprüft | 218 |
| heute zugelassen (Gates + Coverage + 250) | **23** |
| **nur** durch `MIN_DAYS` blockiert | **42** |
| davon ≥ 10 Handelstage in **jedem** vollen Jahr (Schlusstag-Basis) | **8** |
| dieselbe Prüfung auf Eröffnungstag-Basis (die FTMO-Definition) | **10** |
| bleiben ausgeschlossen | 34 |

Die acht zurückgewonnenen Paare:

| Paar | Trades | Schlusstage | Spanne | schwächstes Jahr |
|---|---:|---:|---:|---:|
| 11422:USDCAD | 195 | 195 | 7,8 J | 19 |
| 11708:EURUSD | 173 | 166 | 7,5 J | 16 |
| 12708:XAUUSD | 87 | 87 | 7,7 J | 11 |
| 12710:XTIUSD | 82 | 82 | 7,2 J | 10 |
| 12855:XTIUSD | 169 | 143 | 7,1 J | 17 |
| 13140:XTIUSD | 134 | 80 | 7,1 J | 10 |
| 13144:XTIUSD | 134 | 82 | 7,2 J | 11 |
| 13146:XTIUSD | 132 | 82 | 7,1 J | 10 |

**Aufspaltung der 34, die draußen bleiben (§1.2.4):** **0 Datenproblem, 34 Frequenzproblem.**
Keines scheitert an zu kurzer Historie — alle haben mindestens drei Jahre Spanne und verfehlen das
10-pro-Jahr-Kriterium in mindestens einem Jahr. Das bestätigt die Aufspaltung aus Runde 7 §2
auf der größeren Grundgesamtheit: die Ursache ist Konstruktion, nicht Daten.

---

## 3 · Was die zurückgewonnenen Paare beitragen — §1.3, gemessen

**[MESSUNG]** Sizing 0,50×, 50 Fensterstarts, beide Messbasen, dieselbe Phasen-Engine wie
`EV_FUNDED_ACCOUNT.md`.

| | Buch | P1 | finanziert |
|---|---:|---:|---:|
| **Schlusskursbasis** | 23 Sleeves | 0,580 | 0,340 |
| | 31 Sleeves | 0,620 | 0,340 |
| **Überlappungsboden** | 23 Sleeves | 0,460 | **0,260** |
| | 31 Sleeves | 0,420 | **0,160** |

> **Auf der Basis, die diese ganze Serie als die belastbare ausgewiesen hat, kostet die
> Erweiterung zehn Punkte Finanzierungswahrscheinlichkeit.**

**Antwort auf §1.3.3, klar gesagt:** der 250-Filter ist **faktisch richtig, nur falsch begründet.**
Er verhindert etwas Schädliches, aber nicht aus dem Grund, der im Kommentar steht.

### 3.1 Die Gegenprobe, die den Befund umdreht

Die naheliegende Erklärung — „niederfrequente Sleeves sind schlecht" — ist **falsch.** Jedes der
acht Paare wurde einzeln zum Buch addiert:

| hinzugefügt | P1 | ΔP1 | finanziert | Δfin. |
|---|---:|---:|---:|---:|
| 11422:USDCAD | 0,500 | +0,040 | 0,280 | **+0,020** |
| 11708:EURUSD | 0,460 | 0,000 | 0,280 | **+0,020** |
| 12708:XAUUSD | 0,460 | 0,000 | 0,300 | **+0,040** |
| 12710 / 12855 / 13140 / 13144 / 13146 : XTIUSD | 0,460 | 0,000 | 0,260 | 0,000 |

**Kein einziges schadet einzeln. Drei helfen. Gemeinsam kosten sie zehn Punkte.**

Der Grund steht in der Symbolverteilung: **fünf der acht sind XTIUSD**, und das Buch enthält
bereits zwei XTIUSD-Sleeves. Die Erweiterung hebt XTIUSD von 2 auf 7 von 31 Sleeves. Am
überlappungsbeschränkten Boden wird die ungünstigste gleichzeitige Auslenkung gezählt — sieben
Sleeves auf demselben Instrument laufen an denselben Tagen gemeinsam ins Minus.

| Variante | Sleeves | P1 | finanziert |
|---|---:|---:|---:|
| Bestand | 23 | 0,460 | 0,260 |
| **+ die 3 auf anderen Symbolen** | **26** | **0,500** | **0,300** |
| + 3 andere + 1 XTIUSD | 27 | 0,480 | 0,260 |
| + nur die 5 XTIUSD | 28 | 0,440 | 0,220 |
| + alle 8 | 31 | 0,420 | 0,160 |

> **Der Befund ist ein Konzentrationsbefund, kein Frequenzbefund.** Die Rückgewinnung ist
> wertvoll, wenn sie über eine Symbolgrenze läuft, und schädlich, wenn sie fünf Sleeves auf ein
> Instrument stapelt.

### 3.2 Was diese Zahlen nicht hergeben

* **Statistisch getrennt sind sie nicht.** 0,260 gegen 0,160 sind 13 gegen 8 finanzierte Läufe von
  50; die Wilson-Bänder ([0,159–0,396] gegen [0,083–0,285]) überlappen deutlich. Die **Richtung**
  ist der Befund, nicht der Abstand.
* **Die Steigung aus `SUPPLY_TARGET.md` §1 (+2,3 pp je Sleeve) gilt hier nicht** — sie wurde an
  den vorhandenen 21 gemessen. Genau davor warnt §1.3.2 der Work Order, und die Warnung trifft zu:
  die acht folgen ihr nicht.
* **Größenreferenz:** ein auf 15 Sleeves verkleinertes Buch (die acht dünnsten Bestandssleeves
  entfernt) liefert P1 0,480 / finanziert 0,200. Die Buchgröße allein erklärt den Verlust also
  nicht — 15 Sleeves stehen besser da als 31.

---

## 4 · Empfehlung

**Den Filter nicht auf 10/Jahr absenken. Ihn durch eine Symbolgrenze ersetzen — und beides
dokumentieren.**

1. **Die 250 als Stichprobenanforderung kennzeichnen**, nicht als Aktivitätskriterium. Ein
   Kommentar, der die eigene Herkunft dokumentiert, ist besser als der heutige, der eine
   Poolvergrößerung als Begründung angibt.
2. **Die drei Paare auf USDCAD, EURUSD, XAUUSD aufnehmen** — sie heben die Finanzierungsrate
   messbar (26 → 30 %), jedes einzeln positiv gemessen.
3. **Die fünf XTIUSD-Paare nicht aufnehmen**, solange keine Symbolgrenze existiert. Das ist
   dieselbe Klasse wie der bestehende Symbol-Cap (XAU 4-breit, seit 12.08.), nur für die
   Buchzusammenstellung statt für die Fabrikbelegung.
4. **Das 10-pro-Jahr-Kriterium niederschreiben** — es steuert Produktionsplanung und steht bisher
   nirgends. → OQ-18.

**Nichts davon ist ausgeführt.** Der Filter steht unverändert auf 250; dieses Dokument ist die
Vorlage, nicht die Änderung.

---

## R · RATIFIZIERT — OWNER-Directive 2026-08-20 (schließt OQ-18)

**Regel:** Ein Paar qualifiziert, wenn es in **jedem gewerteten Jahr mindestens 10 verschiedene
Handelstage** aufweist. Die Verteilung innerhalb des Jahres ist ausdrücklich irrelevant — keine
Monatsbedingung. Die 10 ist ein Mindestvolumen je Jahr, kein Rhythmusmaß.
Quelle: OWNER-Directive 2026-08-20 §1 („absolute Untergrenze … Verteilung egal").

**Zählbasis (festgelegt): Eröffnungstag.** Begründung: (1) Eröffnungen sind die Entscheidungen der
Strategie selbst; Schlusstage sind Artefakte des Exit-Managements (SL/TP/Friday-Close können
Schlusstage erzeugen oder verschmelzen). (2) Die Optimierungsspur (EXIT_SURGERY, Q14) verändert
Exits — auf Schlusstag-Basis könnte eine Exit-Optimierung das Aktivitätskriterium bewegen, ohne
dass sich die Signalfrequenz ändert. Eröffnungstag ist Goodhart-resistent gegen die eigene
Optimierung. (3) Es ist zugleich die FTMO-Definition — eine Zählweise für OWNER-Regel und
Venue-Prüfung. **Zahl je Basis (Bestandskohorte 31 Paare): Schlusstag 8 · Eröffnungstag 10.**

**Teiljahre (VORSCHLAG, nicht gesetzt):** Anteilig mit Mindestabdeckung — ein Randjahr wird
gewertet, wenn es ≥ 3 abgedeckte Monate hat, mit skalierter Anforderung
`ceil(10 × abgedeckte_Monate / 12)` Handelstagen; unter 3 Monaten wird es ausgelassen.
Begründung: nutzt alle Evidenz, ist startdatum-robust (volle Wertung eines Rumpfjahres würde
qualifizierte Kandidaten je nach Startdatum aussortieren), und bleibt ein Volumenmaß im Geist der
Regel (10/12 ≈ 0,83 Tage je Monat). **Kopplung Bug #4:** „Abgedeckt" beginnt am ersten Bar, an dem
der EA handeln DARF — eine Filter-Warmlaufphase (lookbackBars) zählt nicht als Abdeckung. Damit
kann weder das Startdatum noch ein Warmlauf einen Kandidaten disqualifizieren; unabhängig davon
wird Bug #4 (Kurzhistorien-Sperre) vor jeder Integration behoben.
