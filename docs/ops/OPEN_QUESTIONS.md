# OPEN_QUESTIONS — was offen bleibt, und was es je kosten würde

**Stand 2026-08-18, Snapshot `3472a5d2e1b5`.** Endfassung nach Work Order Runde 5 §11.

Angelegt in Runde 1 als Liste blockierender Rückfragen. Jetzt zusätzlich das, was §3 ausdrücklich
verlangt: **Messungen, die etwas ändern würden, notiert statt ausgeführt.** Keine Zeile hier wird
durch eine plausible Zahl ersetzt.

**Legende:** ● offen · ◐ teilweise beantwortet · ○ geschlossen

---

## ◐ OQ-1 · Die DD-Werte des Prüfdokuments stammen nicht aus `ea_metrics` *(Eskalation E-1)*

**Status seit Runde 5: die Ursache ist jetzt belegt, nicht mehr nur eingegrenzt.**

`ea_metrics.py:_extract_q04` schreibt `"drawdown_money": None, "drawdown_pct": None` **als
Konstante**; `_extract_q08` ebenso. Q14/Q15 laufen als `unknown_phase` durch. Die Tabelle konnte die
Werte also nie enthalten — es ist kein Datenverlust, sondern ein nie geöffneter Pfad.

**Was OWNER entschieden hat:** Werte neu erzeugen. Ausgeführt wird das über E-2 zuerst
(`INVALIDATION_MATRIX.md` §3), weil sonst ein defektes Werkzeug eine vollständige Neubefüllung
erzeugt.

**Kosten, jetzt beziffert:** für Q08 **null Rechenzeit** — der DD steht als `mc_maxdd_p95_pct` im
Aggregat, und **81 von 91 Pool-Paaren** haben diese Datei noch. Für Q04 eine Dateiöffnung je Fold,
abhängig von OQ-7.

**Audit-Frage 4 bleibt bis zur Vollextraktion NICHT ENTSCHEIDBAR.**

## ○ OQ-2 · Gilt `ea_metrics` trotz 69 % Lücke als autoritativ? *(Eskalation E-2)*

**Geschlossen durch OWNER-Entscheidung (Extraktor reparieren und nachziehen) und durch die Messung,
die die Frage neu stellt:** die 69 % sind **gelöschte Evidenz**, kein Extraktionsfehler — 100 % der
Mai- und Juni-Zeilen, 0 % der August-Zeilen, und in 389 von 393 Stichproben fehlt das
Work-Item-Verzeichnis vollständig (`EXTRACTOR_FIX_REPORT.md` §0).

**Damit ist die ursprüngliche Rückfrage gegenstandslos:** eine Reparatur erreicht diese Zeilen nicht.
Was sie erreicht, sind die 19.275 lesbaren Zeilen, und dort ist sie wertvoll.

## ● OQ-3 · Fenster-Datumsbereiche für Audit-Frage 3

Unverändert offen. Die Faltengrenzen liegen in den Q04-Evidenzdateien, nicht in einer abfragbaren
Spalte. **Neue Einschränkung aus Runde 5:** für **34 der 91 Paare** ist die Q04-Evidenz gelöscht —
die Overlap-Rechnung ist dort auch mit einem perfekten Parser nicht mehr möglich.

**Kosten:** ein Parserlauf nach E-2, für die 54 Paare mit lesbarer Q04-Evidenz. Keine Fabrikzeit.

## ● OQ-4 · Externe Basisraten für Audit-Frage 7 — Quellenfreigabe?

Unverändert offen. Im eigenen Bestand existieren sie nicht (n = 2 eigene Trials sind keine Basisrate).
**Kosten:** eine Freigabeentscheidung, dann Recherche über die agy-Lane mit Zitierpflicht.

---

# Neu in Runde 5

## ● OQ-5 · Der überlappungsbeschränkte MAE-Boden — **die eine Messung, für die ich eine Freigabe empfehle**

**Was.** Der MAE-Boden addiert die Exkursionen aller an einem Tag schließenden Trades und unterstellt
damit **perfekte Gleichzeitigkeit**. Das ist die Annahme, die 28 % erzeugt, und sie ist nachweislich
zu pessimistisch.

**Warum es jetzt geht.** Die Streams tragen `entry_time` und `time` als **minutengenaue**
Epoch-Sekunden. rev4s Satz „Datums-, keine Zeitstempel" war eine Aussage über die Engine
(`challenge_book_60d.py:157` ruft `.date()`), nicht über die Daten. **Zwei Trades können nur dann
gemeinsam zu einem Intraday-Tief beitragen, wenn ihre Offen-Intervalle sich überschneiden** — und das
ist aus dem vorhandenen Bestand prüfbar.

**Was es ändern würde.** Es verengt die Untergrenze von 28 % nach oben, und zwar genau in dem
Sizing-Bereich, in dem rev5 die Spanne als handlungsbestimmend ausweist. Es könnte den
Grenz-Multiplikator von 0,60× nach oben verschieben — die einzige billige Messung, die das kann.

**Kosten:** unter einer Stunde, kein MT5-Slot, kein Recompile. Auf demselben Harness, der die
rev4-Anker reproduziert.

**Nicht ausgeführt**, weil §3 den Rechenstopp auf dem alten Bestand setzt. **Ich empfehle
ausdrücklich, für diese eine Messung eine Ausnahme zu erteilen** — sie ist der einzige Punkt, an dem
§3 und der Erkenntnisgewinn auseinanderfallen.

## ● OQ-6 · Flip-Instabilität am neuen Sizing

rev4 misst −6 pp im Median und ein 17-pp-Band **bei 1,00×**. rev5 empfiehlt 0,60×. **Bei 0,60× ist
die Flip-Sensitivität nicht gemessen**, und es gibt keinen Grund anzunehmen, dass sie dieselbe ist:
bei niedrigerem Sizing scheitern Fenster eher am Ziel als am Limit, und der Ausfall eines Sleeves
wirkt anders.

**Kosten:** dieselbe 1.000-Ziehungen-Rechnung wie R4-5, Minuten. **Nicht ausgeführt** (§3).

## ● OQ-7 · Überleben die Q04-Fold-Summaries?

Der Q04-Drawdown liegt nicht im Aggregat, sondern in der je Fold referenzierten `summary_path`. Ob
diese Dateien der Aufbewahrungsgrenze entgangen sind, ist **nicht gemessen** — es ist die einzige
offene Zahl in `INVALIDATION_MATRIX.md`.

**Wer misst:** Codex, im Zuge des E-2-Tickets `59c2e32c`. **Kosten:** ein Stat-Lauf über die
Fold-Referenzen von 54 Paaren, Minuten.

**Warum es zählt:** davon hängt ab, ob Q04-DD 4.833 Zeilen kostenlos liefert oder gar nicht.

## ● OQ-8 · Wer löscht die Work-Item-Verzeichnisse?

**Gemessen:** 43.182 Evidenzverzeichnisse sind weg, mit sauberem Altersprofil (100 % Mai/Juni, 0 %
August). **Nicht gemessen: von wem.**

Die beiden bekannten Aufräum-Jobs sind es nicht — `prune_workitem_logs.py` und
`reports_log_purge.ps1` löschen ausschließlich `*.log` und halten `.json` ausdrücklich. Ein Job, der
ganze Verzeichnisse entfernt, ist im Repo **nicht auffindbar**: weder `rmtree` noch
`Remove-Item -Recurse` gegen `reports\work_items`.

**Warum es zählt:** solange der Urheber unbekannt ist, ist auch unbekannt, ob die **neuen** Läufe des
vereinten Batches dasselbe Schicksal erwarten. Ein Batch, dessen Evidenz in sechs Wochen still
verschwindet, ist ein Batch, der zweimal bezahlt wird.

**Kosten:** ein Suchlauf über Scheduled Tasks, Dienste und Nicht-Repo-Skripte; Stunden, keine
Fabrikzeit. **P1 vor dem Batch, nicht danach.**

## ● OQ-9 · Laufzeitaufschlag der Equity-Telemetrie

Der Modulkopf begründet, warum der Aufschlag klein sein sollte (Per-Tick nur Equity-Lesen und ein
Vergleich; der `O(PositionsTotal)`-Scan nur beim Emittieren). **Gemessen ist er nicht.**

**Kosten:** der Pilot aus `BATCH_SPEC_MERGED.md` §7 — ein Sleeve, gegen seinen bestehenden Lauf
gestellt. **Nicht verhandelbar vor dem Vollbatch.**

## ● OQ-10 · Der `q08_degenerate_neighborhood_baseline`-Cluster

6 von 72 Batch-Zeilen. Setfile-Integrität und Rebuild-Hypothese sind **falsifiziert**; die Ursache
ist offen. Unverändert seit Runde 4.

---

# Was ohne neue Daten nicht schließbar ist

Der Vollständigkeit halber, weil §11 die Endfassung verlangt — diese drei schließen sich durch
**keine** Rechnung auf `3472a5d2e1b5`:

| | warum |
|---|---|
| **Intraday-Amplitude** | verlangt Equity-Snapshots im Lauf. OQ-5 verengt die Schranke, ersetzt die Messung nicht. |
| **Population** | 18 von 91 Paaren haben eine nutzbare Reihe. 61 sind `challenge_engine_ineligible` und werden es durch keinen Re-Run. |
| **Selektion** | verlangt einen Zeitraum, den kein Gate gesehen hat → E-3. |
