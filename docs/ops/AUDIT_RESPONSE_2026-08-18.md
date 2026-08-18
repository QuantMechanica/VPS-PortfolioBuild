# Antwort auf die externe Prüfung — FTMO-Buch und Darwinex-Zero-Buch

**Stand:** 2026-08-18 · **Verfasser:** Factory CEO · **Datenstand:** Snapshot
`farm_state_20260818T130247Z.sqlite`, sha256 `35f44603434f208cdba8a88c40af33efcea91f4ad636a9b5eb3ed04d3697211f`

Kategorien nach Work Order §4.3: **[MESSUNG]** · **[SCHLUSS]** (Ableitungsschritt genannt) ·
**[VERMUTUNG]** · **[NICHT ENTSCHEIDBAR]**.

---

# Executive Summary

**Der Prüfer hat in den Punkten recht, die zählen. Aus heutiger Datenlage ist keines der beiden
Bücher tragfähig — nicht weil die Strategien widerlegt wären, sondern weil die Evidenzbasis die
Aussagen nicht trägt, die auf ihr aufgebaut werden.**

Drei Messungen tragen dieses Urteil:

1. **Die 22-%-Flip-Rate ist vollständig ein Binary-Effekt.** Bei identischer Binary flippt
   **0 von 12** Verdikten. Bei geänderter Binary **12 von 43 = 27,9 %**. Ein PASS ist damit exakt so
   lange gültig, wie seine Binary unverändert ist — und für den größten Teil des Bestands ist
   unbekannt, ob sie es ist.
2. **Das 80-%-Kriterium ist mit dem vorgesehenen Verfahren nicht überprüfbar.** 1.349 Tage
   enthalten **22** nicht überlappende 60-Tage-Fenster, nicht 1.290. Das 95-%-Konfidenzintervall um
   eine geschätzte Bestehensquote von 0,80 lautet **[0,63 – 0,97]**. Es trennt 80 % von nichts.
3. **Die zentrale Kennzahl der Optimierungsspur existiert in der autoritativen Tabelle nicht.**
   `ea_metrics` führt für Q14/Q15/Q16 **null** Drawdown- und **null** Profit-Factor-Werte. Die im
   Prüfdokument genannten 1,18–9,81 % können dort nicht herkommen. Das ist eine Stop-Bedingung, kein
   Befund — siehe `OPEN_QUESTIONS.md` OQ-1.

**Was dagegen trägt:** die Ko-Exzedenz-Messung (20 Sleeves, 2.114 Handelstage) ist echte Evidenz und
liefert eine harte, brauchbare Zahl — der Sizing-Multiplikator ist nach oben auf ≈ 0,44× begrenzt.
Und die Fabrik-Infrastruktur selbst ist nicht das Problem: von 55 vergleichbaren Wiederholungsläufen
reproduzierten die 12 mit unveränderter Binary ihre Verdikte **fehlerfrei**.

**Tragfähig unter welchen Bedingungen:** wenn (a) die Binary-Identität für den gesamten
Kandidatenpool hergestellt und dokumentiert ist, (b) das Bestehenskriterium auf ein Verfahren mit
belastbarem Konfidenzband umgestellt wird, und (c) die Optimierungsspur eine autoritative
Kennzahlenquelle bekommt. Ohne (a) ist der Pool nicht definiert, ohne (b) ist das Ziel nicht
prüfbar, ohne (c) ist die Optimierung nicht bewertbar.

---

# Die drei größten Gründe, warum das scheitert

*Geschrieben zuletzt, platziert zuerst — sie folgen aus den Messungen in Q1–Q8.*

## Grund 1 — Der Kandidatenpool ist nicht definiert, weil Binary-Identität nicht geführt wird

**[MESSUNG]** Flip-Rate nach Binary-Identität, n = 55 Wiederholungsläufe:

| Kohorte | n | Flips | Rate | auf | ab |
|---|---:|---:|---:|---:|---:|
| **C1 — identische Binary** | 12 | **0** | **0,0 %** | 0 | 0 |
| C2 — geänderte Binary, kein Rebuild | 17 | 4 | 23,5 % | 2 | 2 |
| C3 — neu gebaut | 26 | 8 | 30,8 % | 6 | 2 |
| **gesamt** | 55 | 12 | 21,8 % | 8 | 4 |

**[SCHLUSS]** Ableitungsschritt: die Aufteilung erfolgt entlang der vor dem ersten Lauf
eingefrorenen Kohortendatei, nicht nachträglich. Bei unveränderter Binary flippt nichts; die
gesamte beobachtete Instabilität sitzt in der Binary-Änderung. **Ein PASS ist keine Eigenschaft der
Strategie, sondern eines (Strategie, Binary)-Paars.** Der Pool von 91 Paaren ist heute über
Strategien definiert, nicht über Paare — er ist damit keine wohldefinierte Menge.

**Beobachtung, die ihn bestätigt oder widerlegt:** für jedes der 91 Paare den SHA256 der Binary
bestimmen, die sein aktuelles Verdikt erzeugt hat, und mit der Binary auf Platte vergleichen.
**Widerlegt**, wenn ≥ 90 % übereinstimmen. **Bestätigt**, wenn ein nennenswerter Anteil abweicht.
**Kosten:** null Fabrikzeit — ein Join über `payload_json.expected_ex5_sha256` gegen die Dateien.
*Vorbehalt:* in einer Stichprobe der letzten Stunde trugen **4 von 5** Verdikten überhaupt keine
Hash-Bindung. Der Join wird also für einen Teil des Bestands „unbekannt" liefern, und **unbekannt
ist hier gleichbedeutend mit unbestätigt.**

## Grund 2 — Das Zielkriterium ist mit dem vorgesehenen Verfahren nicht überprüfbar

**[MESSUNG]** 1.349 Tage, 60-Tage-Fenster → 1.290 überlappende, **22 nicht überlappende**.

**[SCHLUSS]** Ableitungsschritt: bei überlappenden Fenstern ist die effektive Stichprobe in der
Größenordnung Zeitraum/Fensterlänge. Mit n_eff = 22 gilt für eine geschätzte Bestehensquote p:

| p | SE | 95-%-KI |
|---|---:|---|
| 0,80 | 0,085 | **[0,63 – 0,97]** |
| 0,85 | 0,076 | [0,70 – 1,00] |
| 0,90 | 0,064 | [0,77 – 1,03] |

Selbst bei einer Punktschätzung von 0,90 schließt das Intervall 80 % nicht aus. **Die Vorgabe
„P(Bestehen) ≥ 80 %" ist mit diesem Verfahren nicht falsifizierbar** — jedes Ergebnis zwischen etwa
0,63 und 0,97 ist damit vereinbar.

**Beobachtung:** Block-Bootstrap mit Blocklänge ≥ typische Drawdown-Clusterlänge rechnen und das
Konfidenzband ausweisen. **Widerlegt**, wenn das Band schmaler als ±5 pp wird. **Kosten:** reine
Rechenzeit, keine Fabrikzeit; die Eingangsdaten (Tagesreihen) entstehen ohnehin gerade in 2.3.

## Grund 3 — Die Optimierungsspur hat keine autoritative Kennzahlenquelle

**[MESSUNG]** `ea_metrics`, n = 62.457 Zeilen: `source = "missing"` bei **43.182 (69 %)**,
`parse_error` bei 105. `drawdown_pct` non-null: **Q04 = 0 von 16.490**, **Q08 = 0 von 613**,
**Q14 = 0 von 11**, **Q15 = 0 von 1**, **Q16 = 0 Zeilen**. `sharpe` non-null: 63 von 62.457 (0,1 %).

**[SCHLUSS]** Die DD-Schwelle der Optimierungsspur wird gegen Werte geprüft, die in der
autoritativen Tabelle für die betroffenen Phasen nicht existieren. Damit ist weder „0 von 25
zulässig" noch die Population 1,18–9,81 % aus autoritativer Quelle belegbar.

**Beobachtung:** Herkunft der 1,18–9,81 % benennen. **Widerlegt**, wenn sie aus einem verifizierten
Pfad stammen. **Kosten:** eine Rückfrage. *Dies ist Stop-Bedingung §9 — siehe OQ-1.*

---

# Q1 · Was ist ein PASS wert bei 22 % Flip-Rate?

**[MESSUNG]** siehe Tabelle unter Grund 1. **Getrennt nach Binary-Identität: C1 = 0 %, C2 = 23,5 %,
C3 = 30,8 %.**

**Richtung der 12 Flips: 8 aufwärts, 4 abwärts.** **[SCHLUSS]** Unter H0 „Flips sind symmetrisches
Rauschen" ist P(≥ 8 von 12 aufwärts) = 0,194, zweiseitig ≈ 0,39. **Die beobachtete Asymmetrie ist
bei n = 12 nicht signifikant** — ich behaupte keine Aufwärtsverzerrung. Die Frage des Prüfers nach
Selektionsverzerrung bleibt damit offen, nicht beantwortet.

**Die Folgerechnung, die der Prüfer vermisst.** **[SCHLUSS]**, Ableitungsschritt explizit: wendet man
die gemessene Flip-Rate bei geänderter Binary (27,9 %, n = 43) auf die 91 Kandidatenpaare an, hielten
**etwa 25 Paare** einer Wiederholung nicht stand. Diese Zahl ist **nur** gültig, wenn die 91 Paare
dieselbe Binary-Wechsel-Verteilung haben wie die 43 gemessenen — was nicht geprüft ist. Für Paare mit
identischer Binary wäre die Erwartung 0.

**Antwort auf die Frage:** ein PASS ist bei identischer Binary **vollständig belastbar** (0 von 12
Abweichungen) und bei gewechselter Binary **kein Nachweis**, sondern eine Beobachtung, die zu
27,9 % nicht reproduziert. Der Wert eines PASS hängt nicht am Gate, sondern an der Binary-Bindung.

---

# Q2 · Multiple Testing über den Bestand

**[MESSUNG]** Das tatsächliche Selektionsuniversum:

| | |
|---|---:|
| distinkte EAs | 2.934 |
| distinkte (EA, Symbol)-Paare | **14.358** |
| distinkte (EA, Symbol, Phase)-Tripel | 24.822 |
| **erteilte Verdikte insgesamt** | **107.446** |
| davon allein Q02-Auswertungen | **74.482** |

Beobachtete Durchlassraten je Gate: Q02 17,9 % · Q03 80,4 % · Q04 6,0 % · Q05 41,1 % · Q06 82,4 % ·
Q07 69,1 % · Q08 9,1 %.

**Nicht 3.722, sondern 107.446 ausgewertete Hypothesen** — der Prüfer fragt zu Recht danach.

**[NICHT ENTSCHEIDBAR]** — erwartete Zahl reiner Zufallsüberlebender. Das Produkt der *beobachteten*
Durchlassraten (1,775 · 10⁻⁴) mal 14.358 ergibt 2,55, **aber diese Rechnung ist falsch und ich führe
sie nur, um sie zu verwerfen**: beobachtete Raten enthalten bereits echte Filterwirkung. Für
Zufallsüberlebende braucht man die Durchlassrate **unter H0**, und die produziert die Pipeline
nirgends. Was fehlt: ein Null-Modell je Gate (permutierte oder synthetische Renditereihen durch
dieselben Schwellen). Kosten: ein Permutationslauf je Gate über eine Stichprobe — reine Rechenzeit,
Größenordnung Stunden, keine Fabrikzeit.

**Zur Davey-Prüfung: [SCHLUSS] der Prüfer hat recht.** Q08.2 (DSR/MC/FDR) und Q08.7 (PBO) rechnen
**innerhalb** eines Kandidaten über dessen eigene Parameter- und Trade-Permutationen. Keiner der elf
Sub-Gates sieht die anderen 14.357 Paare. Eine familienweite Korrektur über das Selektionsuniversum
existiert nicht. Deflated Sharpe Ratio ist zusätzlich nicht rechenbar, weil `sharpe` in
`ea_metrics` zu 0,1 % gefüllt ist.

---

# Q3 · Ist der Re-Proof nach Optimierung unabhängig?

**[NICHT ENTSCHEIDBAR]** mit dem, was abfragbar ist. `work_items` führt `from_date`/`to_date` je
Lauf, aber die **Faltengrenzen** der Walk-Forward-Prüfung liegen in Evidenzartefakten, nicht in einer
Spalte. Die geforderte Overlap-Rechnung in Tagen ist damit nicht ausführbar, ohne denselben
Extraktionspfad zu benutzen, den §3.1.3/§3.1.4 als fehlerhaft markieren. Siehe OQ-3.

**Was ich ohne Extraktion sagen kann — [VERMUTUNG], ausdrücklich als solche:** die
Optimierungsgates Q14–Q16 sind nach Q10 angeordnet, und Q10 ist die Voll-Historien-Bestätigung. Wenn
Q14 auf derselben Historie optimiert, auf der Q04 und Q10 bereits geprüft haben, ist Overlap nicht
nur wahrscheinlich, sondern strukturell — das wäre dann kein Bug, sondern ein Designmerkmal, das der
zweite PASS nicht überwindet.

**Welches Holdout-Design den zweiten PASS zählbar machen würde — [SCHLUSS]:** ein Zeitraum, der
**nie** ein Gate gesehen hat. Bei Datenlage bis 2025-12-30 und Q02-Beginn 2017 hieße das, ein
zusammenhängendes Endstück (Größenordnung 12–18 Monate, also ~6–9 nicht überlappende 60-Tage-Fenster)
aus **allen** Gates herauszunehmen und erst nach Abschluss der Optimierung genau einmal zu öffnen.
**Wann es verbraucht ist:** nach der ersten Auswertung. Jede zweite Verwendung macht es zum
Trainingsfenster. **Kosten der Einrichtung:** die Gate-Fensterdefinitionen ändern — das ist nach
§3.3 **eskalationspflichtig** und wird hier nicht eigenmächtig getan.

---

# Q4 · Misst die Optimierungsspur das Falsche?

**[NICHT ENTSCHEIDBAR] — Stop-Bedingung §9 ausgelöst.**

Die Frage setzt die Werte 0/25, Schwelle 12 %, Population 1,18–9,81 % voraus. **In der autoritativen
Tabelle existieren diese Werte nicht** (Q14: 11 Zeilen, 0 mit `drawdown_pct`; Q15: 1 Zeile, 0; Q16: 0
Zeilen). Bevor darauf geantwortet wird, ist die Herkunft der Zahlen zu klären — Work Order §9 verlangt
in diesem Fall ausdrücklich die Korrektur des Prüfdokuments vor der Antwort. Siehe OQ-1.

**Was unabhängig davon prüfbar ist — die Erreichbarkeitsfrage. [SCHLUSS]:** bei
`RISK_FIXED = 1000` auf `ACCOUNT = 100.000` kostet ein ausgestoppter Trade exakt **1,00 %**
(`challenge_book_60d.py:75`; `RISK_FIXED = 1000.0` in 3.699 von 3.722 EAs). Der gemessene
schlechteste Tag je Sleeve ist damit eine **Anzahl gestapelter Verlusttrades**, und sie ist
ganzzahlig: **10 Sleeves stapeln 1, 10 stapeln 2, 1 stapelt 3** (n = 21). Ein Max-DD von 12 %
verlangt also eine Verlustserie von ≈ 12 Trades bei 1×-Sizing. **Ob eine Strategie das erreichen
kann, ohne vorher an Q05 (DD < 25 %) oder am Trade-Floor zu scheitern, ist ohne die Q14-Werte nicht
entscheidbar** — genau deshalb blockiert OQ-1 diese Frage.

**Zum zweiten Teil — „fünf von neun Kohorteneinträgen stehen auf Verdikten, die heute nicht mehr
erteilt würden": [NICHT ENTSCHEIDBAR].** Die Nachzählung verlangt, für jeden Kohorteneintrag das
erzeugende Gate-Regelwerk zum Erteilungszeitpunkt gegen das heutige zu stellen. Eine versionierte
Gate-Regelhistorie existiert nicht als abfragbares Artefakt. Kosten der Beschaffung: Rekonstruktion
aus der Git-Historie der Gate-Module je Erteilungsdatum — machbar, Größenordnung ein Arbeitstag,
keine Fabrikzeit.

---

# Q5 · Trägt die Kombinationsthese?

**[MESSUNG]**, n = **20 von 216** Sleeves (die mit vollständigen `entry_time`-Stempeln), 2.114
Handelstage 2017-10-09 … 2025-12-30. **Selektionsrichtung benannt:** die 20 sind die Sleeves, deren
Streams die *neuere* Emitter-Generation tragen — die Auswahl ist nach Build-Datum verzerrt, nicht
nach Qualität.

Gleichzeitige Verlierer je Tag:

| gleichzeitig verlierende Sleeves | Tage |
|---:|---:|
| 1 | 377 |
| 2 | 443 |
| 3 | 429 |
| 4 | 294 |
| 5 | 181 |
| 6–9 | 199 |
| **10–12** | **13** |

| | % vom Konto, 1× |
|---|---:|
| Summe der je eigenen schlechtesten Tage | −32,33 |
| **tatsächlich schlechtester gemeinsamer Tag** | **−6,86** |
| Verhältnis | **0,21×** |

**[SCHLUSS]** Die Diversifikation ist real und groß: die naive Summe überschätzt den echten
schlechtesten Tag um das **4,7-Fache**. **Aber sie reicht nicht.** −6,86 % am schlechtesten
gemeinsamen Tag steht gegen eine 5-%-Tagesgrenze; **acht Tage in acht Jahren liegen über der
Grenze**. Daraus direkt der zulässige Sizing-Multiplikator: **≤ 3,0/6,86 = 0,44×** gegen ein
3-%-Arbeitslimit, ≤ 0,73× gegen die harte 5-%-Grenze.

**Zur Tail-Abhängigkeit — der Prüfer hat recht. [MESSUNG]:** am 2023-02-03 verloren **11 von 20**
Sleeves gleichzeitig. Eine Pearson-Matrix über alle Tage zeigt das nicht; die Verteilung oben schon.
**[NICHT ENTSCHEIDBAR]** ist die Frage, ob die Korrelation im Drawdown-Regime dieselbe ist wie im
Mittel — dafür braucht es eine regime-bedingte Korrelationsrechnung, die nicht existiert. Kosten:
Rechenzeit auf denselben Tagesreihen, Größenordnung Stunden.

**Unter welchen Bedingungen ergibt eine Menge PF-1,1-Strategien ein besseres Buch:**

| Bedingung | Status |
|---|---|
| Die Einzelrenditen sind positiv erwartungswertig **nach Kosten** | **unterstellt** — das Kostenmodell deckt 19 Symbole, der Pool mehr |
| Die Verluste fallen nicht auf dieselben Tage | **nachgewiesen, aber nur teilweise** — Faktor 4,7 Diversifikation, dennoch 8 Grenzüberschreitungen |
| Die Korrelation bleibt im Stress dieselbe | **unterstellt**, und die 11-von-20-Beobachtung spricht dagegen |
| Die Anzahl unabhängiger Strategien ist groß genug | **nicht gemessen** — Eigenwertspektrum nicht gerechnet |
| Die Einzelverdikte sind stabil | **widerlegt** für gewechselte Binaries (Q1) |

---

# Q6 · Ist das 80-%-Kriterium wohlgestellt?

**Nein. [MESSUNG]** siehe Grund 2: n_eff = 22, 95-%-KI bei p = 0,80 ist **[0,63 – 0,97]**.

**[SCHLUSS]** Ein Kriterium, dessen Konfidenzintervall bei jeder plausiblen Punktschätzung die
Schwelle enthält, ist keine Abnahmebedingung, sondern eine Formulierung. **Der Prüfer hat recht, und
die Größenordnung seines Einwands ist Faktor 59** (1.290 gegen 22).

**Welches Verfahren es wäre:** stationärer Block-Bootstrap auf den Tagesreihen, Blocklänge an der
beobachteten Drawdown-Clusterlänge kalibriert, mit ausgewiesener effektiver Stichprobe. Ein
iid-Bootstrap ist ausgeschlossen — er zerstört genau die Serienkorrelation, die über Drawdowns
entscheidet, und schätzt P(Bestehen) systematisch zu hoch. **Kosten:** Rechenzeit auf den
Tagesreihen aus 2.3; keine Fabrikzeit, keine Gate-Änderung.

---

# Q7 · Außensicht

**[NICHT ENTSCHEIDBAR] mit internen Mitteln, und das ist die ehrliche Antwort.**

Im eigenen Bestand existiert **keine** Basisrate für das Überleben backtest-selektierter Portfolios
im Livebetrieb. Was existiert, ist n = 2: zwei FTMO-Trials mit −8,7 % und −9,9976 %. **Zwei
Fehlschläge sind keine Basisrate**, und sie als eine zu behandeln wäre genau der Fehler, den Work
Order §4.4 verbietet.

**Was wir konkret besser machen als der Durchschnitt — [VERMUTUNG], und ich kennzeichne sie als
schwach:** die Determinismus-Kette (identische Binary → identischer Stream → identisches Verdikt,
0 Abweichungen bei n = 12) ist strenger als das, was in Retail-Backtesting üblich ist. Ob das die
Live-Überlebensrate hebt, ist damit **nicht** gezeigt — es verhindert eine Fehlerklasse, nicht das
Overfitting selbst.

Rückfrage zur externen Recherche: siehe OQ-4.

---

# Q8 · Was fehlt, das wir nicht als fehlend bemerkt haben?

Drei Kandidaten mit konkretem Test, alle **[MESSUNG]** oder **[SCHLUSS]**:

**8.1 — Der Intraday-Equity-Pfad fehlt vollständig.** **[MESSUNG]** Die gesamte Ko-Exzedenz-Rechnung
aus Q5 basiert auf realisierten Tages-P&L, gebucht auf den **Schlusstag** des Trades. FTMO misst den
Tagesverlust gegen den Kontostand zum Tagesbeginn **einschließlich schwebender Positionen**.
**[SCHLUSS]** Damit ist −6,86 % eine **Untergrenze** des wahren schlechtesten Tages und 0,44× eine
**Obergrenze** des zulässigen Multiplikators. *Test:* für einen Sleeve den Intraday-Pfad aus den
Tick-Daten rekonstruieren und mit der Schlusstagsreihe vergleichen; die Differenz ist der
systematische Fehler. *Kosten:* ein Rekonstruktionslauf je Sleeve.

**8.2 — Die Kostenabdeckung ist kleiner als der Pool.** **[MESSUNG]** Das Kostenmodell führt 19
Symbole. Der 91-Paare-Pool enthält Symbole, die dort nicht stehen (u. a. EURJPY, USDCAD, EURGBP,
AUDCAD als Fallback-Fälle). **[SCHLUSS]** Für diese greift ein Klassen-Maximum als Fallback — das ist
konservativ und damit nicht gefährlich, aber es heißt, dass die Kosten für einen Teil des Pools
**nicht gemessen, sondern gedeckelt** sind. *Test:* Deckungsgrad des Kostenmodells über die
Pool-Symbole auszählen. *Kosten:* Minuten.

**8.3 — Die FTMO-Nebenregeln jenseits der drei Hauptlimits sind nirgends modelliert.**
**[MESSUNG]** Gesucht wurde nach Konsistenzregeln, Mindesthandelstagen über die vier hinaus und
News-Restriktionen je Kontotyp; die Simulation kennt `DAILY_CAP = 0.05` und `TOTAL_CAP = 0.10`
(`challenge_book_60d.py:75`) und sonst nichts. **[SCHLUSS]** Eine Konsistenzregel, die einen
einzelnen Tag auf einen Anteil des Gesamtgewinns begrenzt, würde ausgerechnet die Sleeves mit
Stapelfaktor 2–3 treffen. *Test:* das aktuelle FTMO-Regelwerk gegen die simulierten Bedingungen
stellen. *Kosten:* eine Dokumentenprüfung.

**Vierter Kandidat, kürzer — Regime-Abhängigkeit.** **[NICHT ENTSCHEIDBAR]** Die 1.349 Tage laufen
von 2017-10 bis 2025-12. Ob dieser Zeitraum überwiegend ein Regime ist, wurde nie geprüft. *Test:*
Regime-Klassifikation über Volatilität und Zinsniveau, dann Bestehensquote je Regime. *Kosten:*
Rechenzeit.

---

# Methodenanhang

Alle Zahlen aus dem Snapshot `farm_state_20260818T130247Z.sqlite`
(sha256 `35f44603…`), gezogen 2026-08-18T13:0xZ. Off-host gesichert zusammen mit
`ea_metrics_20260818T130304Z.csv` (sha256 `03436029…`, 62.457 Zeilen) und dem Repo-Bundle
`qm_repo_all_refs_20260818T130152Z.bundle` (sha256 `a997d0b9…`, 2,22 GB, alle 74 lokalen Refs).

| Aussage | Query / Quelle | n |
|---|---|---|
| Flip-Rate je Kohorte | `work_items` × `artifacts/book_q08_regeneration_cohorts_20260817.json`, Nicht-Merit-Filter aus `farmctl.py:9081` | 55 |
| Selektionsuniversum | `SELECT COUNT(*) FROM work_items WHERE verdict IS NOT NULL` | 107.446 |
| Durchlassraten je Gate | `GROUP BY phase` auf denselben Zeilen | s. Q2 |
| `ea_metrics`-Abdeckung | `GROUP BY source`, `SUM(<feld> IS NOT NULL)` | 62.457 |
| Ko-Exzedenz | `challenge_book_60d.sleeves`, Netto je Schlusstag / `ACCOUNT` | 20 Sleeves, 2.114 Tage |
| Stapelfaktor | `worst_day_1x` ÷ (`RISK_FIXED`/`ACCOUNT`) | 21 Sleeves |
| n_eff | 1.349 Tage ÷ 60-Tage-Fenster | — |

**Nicht-Merit-Verdikte** (`INFRA_FAIL`, `INVALID`, `WAITING_INPUT`, `PENDING_RUNNER`,
`PENDING_IMPLEMENTATION`) sind aus allen Flip-Zählungen ausgeschlossen. Diese Menge stammt aus dem
Code (`farmctl.py:9081`), nicht aus meiner Einschätzung — ein früherer Zählstand von mir nutzte einen
engeren Filter und wies dadurch **einen Flip zu viel** aus (`FAIL_SOFT → PENDING_RUNNER`); korrigiert.
