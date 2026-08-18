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

## ● OQ-11 · Muss der globale Custom-History-Lease über den ganzen Lauf gehalten werden?

**[MESSUNG] 2026-08-18, 16:01 UTC.** `terminal_worker.py:4467` holt den globalen Lease **vor**
`claim_atomic` und gibt ihn erst im `finally` **nach** `_run_claimed_item` frei. Solange eine Zeile
läuft, kann kein anderes Terminal einen Anspruch versuchen.

| | |
|---|---|
| Lease-Haltedauer | Median **1,1 min** · p90 **12,3 min** · Maximum **54,8 min** (Basket QM5_12712) |
| Lease-Busy je Terminal und Stunde | ~**50** — jede Minute angefragt, praktisch immer abgewiesen |
| letzter Anspruch je Terminal | T9 vor 29 min, **die übrigen neun vor 153 bis 429 min** |
| wartende Zeilen | **2.300** (Q04 1.497, Q02 690), 10 lebende Worker |

**Die Frage.** Copy-on-Claim privatisiert die Historie in das terminaleigene `Bases\Custom`; danach
liest der Lauf nur noch private Dateien. Was der **globale** Lease während des Laufs noch schützt,
ist nicht ersichtlich. Bei Median 1,1 min ist das für gewöhnliche Zeilen folgenlos — bei einem
Basket, der ihn stundenlang hält, steht die gesamte Fabrik.

**Warum ich nichts ändere.** Der Lease ist Teil der OWNER-ratifizierten Variante-A-Containment und
fail-closed konstruiert. Eine Verkürzung seiner Reichweite ist keine Routinereparatur, sondern eine
Änderung an einer Containment-Garantie.

**Was daran hängt:** 6 bis 42 Fabrikstunden im Basket-Anteil des vereinten Batches, und dieselbe
Größenordnung bei jedem künftigen Basket-Lauf.

---

# Was ohne neue Daten nicht schließbar ist

Der Vollständigkeit halber, weil §11 die Endfassung verlangt — diese drei schließen sich durch
**keine** Rechnung auf `3472a5d2e1b5`:

| | warum |
|---|---|
| **Intraday-Amplitude** | verlangt Equity-Snapshots im Lauf. OQ-5 verengt die Schranke, ersetzt die Messung nicht. |
| **Population** | 18 von 91 Paaren haben eine nutzbare Reihe. 61 sind `challenge_engine_ineligible` und werden es durch keinen Re-Run. |
| **Selektion** | verlangt einen Zeitraum, den kein Gate gesehen hat → E-3. |

## ○ OQ-5 · Der überlappungsbeschränkte MAE-Boden — **ausgeführt, Ergebnis gegen die Erwartung**

**Freigabe D-6 erteilt und genutzt.** Ich hatte die Ausnahme mit der Begründung empfohlen, die
Messung könne die Untergrenze **anheben**. **Sie senkt sie.**

| | Schlusskurs | naiver Boden | überlappungsbeschränkt |
|---|---:|---:|---:|
| schlechtester Tag | −6,95 % | −9,32 % | **−11,06 %** |
| Tage ≤ −5 % | 20 | 237 | **501** |
| Quote bei 1,00× | 78 % | 28 % | **10 %** |
| Übereinstimmungsgrenze | — | 0,60× | **0,50×** |

Ursache: dieselbe Rechnung behebt den **zweiten** rev4-Vorbehalt mit. Der naive Boden belastete die
MAE eines mehrtägigen Trades nur am Schlusstag; der neue belastet jeden offenen Tag. Dieser Effekt
überwiegt den Ausschluss nicht-überlappender Trades deutlich. Der neue Boden ist eine **echte**
tagesweise Untergrenze — der alte war keine. Details in `audit_rev6.md` R6-1.

## ○ OQ-6 · Flip-Instabilität am neuen Sizing — **gemessen**

−11 pp bei 0,50× · −3 bei 0,60× · **−8 bei 0,85×** · −3 bei 0,90× · −6 bei 1,00× · −6 bei 1,10×.
**Der Effekt ist nicht sizing-invariant**, die Übertragung des 1,00×-Wertes war unzulässig, und am
Ceiling-Multiplikator ist der Abzug größer als angenommen.

## ◐ OQ-8 · Wer löscht die Work-Item-Verzeichnisse — **kein Retention-Job, ein Ereignis**

**[MESSUNG]** Der Verlust ist **keine rollierende Aufbewahrungsgrenze**:

* bis **2026-07-06** einschließlich: **100 % fehlend**
* 07-07 → 07-10: Rampe 36 % → 30 % → 11 % → 2 %
* ab 07-11: praktisch 0 %, mit zwei diskreten Spitzen am **07-13 (44 %)** und **07-29 (34 %)**
* **das älteste noch existierende Verzeichnis stammt vom 2026-07-07 10:30:00** — davor nichts

**Es ist auf `D:\QM\reports\work_items` beschränkt.** Jeder andere D:-Teilbaum trägt noch April-,
Mai- und Juni-Einträge (`reports\pipeline` ab 05-26, `strategy_farm\logs` ab 05-20, `reports` ab
04-26). Ein Volumen- oder Storage-Sense-Ereignis wäre nicht so chirurgisch.

**Ausgeschlossen, mit Mittel:**
* *Rollierende Retention* — durch das Tagesprofil (eine Wand, keine wandernde Grenze)
* *Die beiden Repo-Pruner* — löschen ausschließlich `*.log`, halten `.json` ausdrücklich
* *Pfad-Drift auf die Legacy-Wurzel* — 45 der 600 Stichproben haben dort ein Verzeichnis,
  **0 davon enthalten `summary.json` oder `aggregate.json`**
* *Windows Storage Sense / `SilentCleanup`* — läuft als `cleanmgr /autocleanstoragesense /d
  %systemdrive%`, also **gegen C:**, nicht D:
* *Ein Skript im Repo* — weder `rmtree` noch `Remove-Item -Recurse` gegen diese Wurzel

**Belegt für eine der drei Spitzen:** `MNT_CONVERGENCE_LEDGER.md` (Commit `94cb6d347`, 2026-07-29)
protokolliert *„Purge-Task (SYSTEM) seit ~01:20 in 0x800710E0-Klasse; D: brannte 208→42,6 GB in ~9 h.
Claude-Sofortmaßnahme: kanonische Purge direkt ausgeführt → 240,6 GB frei (198 GB reclaimed)."*
Das ist der 29.07. **Für die Wand am 07.07. ist der Urheber weiterhin offen.**

**Was daraus folgt:** ein Ereignis dieser Art kann sich wiederholen, und die Batch-Ergebnisse hätten
dasselbe Schicksal. **Schutzmaßnahme umgesetzt** — siehe unten.

## ● OQ-12 · `.ex5`-mtime ist ein Staging-, kein Bau-Zeitstempel

QM5_11288/USDJPY: Binary vom 17.08., Stream von **heute**, trotzdem 0 % `entry_time` über
436 Trades. In `QM_Common.mqh` existiert nur **ein** `TRADE_CLOSED`-Writer (Z. 1717), und der
schreibt `entry_time`, `mae_acct` und `money_basis` immer.

**Regel daraus:** ob ein Paar reiche Streams liefert, entscheidet die **Zeilenform**
(`money_basis` vorhanden), nicht ein Datum. Wer den Batch nach `.ex5`-mtime plant, plant falsch.
**Offen:** warum diese eine Binary poor emittiert.

## ● OQ-13 · Ein Zustandswechsel ohne Beobachter

Die Containment-Notlage war heute **vier Stunden** eingeschaltet, hat neun von zehn Terminals
stillgelegt, und ist nur aufgefallen, weil eine Monitoring-Runde nach der Ursache fehlender Claims
gesucht hat. CLAUDE.md verlangt `enabled:false`, aber **nichts prüft das**.

Ein Alarm auf `enabled:true` — Cockpit-Banner oder FAIL-Digest — kostet fast nichts. Dieselbe
Klasse wie die Mechanismen ohne Aufrufer: ein Zustand, den niemand beobachtet.
