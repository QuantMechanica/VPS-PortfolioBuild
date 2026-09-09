# OWNER Vorlage — Q09/Q10_NEWS: Alt-Builds ohne Kalender-Bundle-Input (zweite, fruehere Legacy-Grenze)

**KORRIGIERT 09.09. (selbe Sitzung):** die urspruengliche Fassung dieser Vorlage schlug faelschlich
ein "deklariertes Residuum" (Option A, analog zum sv-Praezedenzfall) vor. Eine gleichzeitig
laufende Session hat parallel denselben Befund gemacht und nachgewiesen (`QM_NewsFilter.mqh:69-76,
744-763`), dass `qm_news_calendar_bundle_id`/`_expected_sha256`/`_common_relative_path` **kein
reines Provenienz-Echo** sind, sondern in `QM_NewsInitTesterBundle()` den vom Tester tatsaechlich
geladenen Kalender-Bundle-Pfad steuern. Ein Alt-Binary ohne diese Inputs hat keinen Weg, an den
versiegelten Bundle zu binden — es ist nicht nur Evidenz, die fehlt, sondern die Testlauf-Bindung
selbst ist unverifizierbar. Ein "deklariertes Residuum" waere daher keine ehrliche Analogie zum
sv-Fall (dort blieb die zugrunde liegende EA-Ausfuehrung vollstaendig belegt). Diese Fassung
ersetzt Option A durch die von der Parallel-Session dokumentierte, einzig belegte Alternative:
Neubau vs. Parken. Siehe
`docs/ops/evidence/2026-09-08_q09-legacy-logger-sample-20260907_821096ac_execution.md`
("Canary-Ergebnis 2026-09-08 17:32Z") fuer die volle Herleitung.

## Befund (09.09.2026, waehrend Ausfuehrung der bereits erteilten Kalender-Entscheidungen)

Der native B'-Kanari-Rerun fuer 11167/XAUUSD (`6797ed1c-597a-4d44-82f9-7379d45b5e06`, T10,
08.09. 14:56–15:15 UTC) endete erneut `REVIEW_REQUIRED` (`cell_execution_failed`, 8/8 Zellen),
diesmal **nicht** wegen des bereits geloesten `sv`-Feldproblems
(OWNER-DEC-Q09-LEGACY-LOGGER-SAMPLE-20260907 = JA, Code `07af95fcf1`). Der `run_smoke`-Schritt
selbst lief `PASS`. Der Fehler kommt aus einer spaeteren, staerkeren Pruefung in
`q09_news_runner.py::_validate_report_effective_inputs`: `MT5 report effective input
qm_news_calendar_bundle_id mismatch`.

Direkte Inspektion des MT5-Report-HTML (UTF-16, Inputs-Bereich vollstaendig gelesen) zeigt: das
Binary deklariert `qm_news_calendar_bundle_id`, `qm_news_calendar_expected_sha256` und
`qm_news_calendar_common_relative_path` **gar nicht als Input-Parameter**. Es hat stattdessen nur
das aeltere Schema (`qm_news_mode_legacy=0`, `qm_news_stale_max_hours`, `qm_news_min_impact`).

Git-Beleg: dieses Drei-Feld-Input-Schema wurde erst mit Commit `f0102fbcf279329f607be841c54536b69cfe7f47`
("fix(q09): bind sealed calendar inputs in tester", 2026-08-03 00:58:07 +02:00) in
`framework/include/QM/QM_NewsFilter.mqh` eingefuehrt. QM5_11167 wurde am 14.07.2026 gebaut — drei
Wochen vor dieser Grenze. Das ist also eine **zweite, fruehere Legacy-Grenze** als die `sv`-Grenze
(P1-Evidenzintegritaet `6e92c806264d5216c46ba6ad4f8cf8c0641b53f8`, 20.07.2026): jeder Build vor dem
03.08.2026 hat strukturell keine der drei Kalender-Bundle-Input-Felder und kann die aktuelle
Effektiv-Input-Pruefung nie bestehen — unabhaengig vom `sv`-Fix.

**Kohortenbefund (parallele Session, verifiziert):** alle 9 im `legacy_logger_allowlist.v1.json`
registrierten Binaries (11167, 11196, 10148, 10476, 10771, 11179, 1230, 12474, 9573) wurden
zwischen 2026-06-07 und 2026-07-15 committet — **alle vor dem 03.08.** Sofern ihre EAs
`QM_Common.mqh`/`QM_NewsFilter.mqh` einbinden (wie 11167), trifft sie derselbe Mismatch,
unabhaengig vom sv-Logger-Fix. Ob post-sv/pre-08.03-Builds aus der bereits freigegebenen
B'-Kohorte (10145/SP500, 10513/XAUUSD u.a.) ebenfalls betroffen sind, ist ungeklaert.

## Frage

Es gibt **keine belegte Deklarations-Option**: `qm_news_calendar_bundle_id` /
`_expected_sha256` / `_common_relative_path` sind kein Provenienz-Echo, sondern steuern in
`QM_NewsInitTesterBundle()` (`QM_NewsFilter.mqh:744`), welchen Kalender-Bundle der Tester laedt.
Ein Alt-Binary ohne diese Inputs kann nicht nachweislich an den versiegelten Bundle gebunden
werden — die Testlauf-Bindung selbst bleibt unverifizierbar, nicht nur ein Evidenzfeld. Ein
"deklariertes Residuum" wuerde das eigentliche Q10_NEWS-Gate (korrekte Kalenderbindung) aushebeln,
nicht nur eine Nebenpruefung. Damit bleiben nur zwei Wege:

- **B (Neubau):** die betroffenen EAs mit dem aktuellen Template neu bauen (neue Identitaet ab
  Q02, kein Bestandsschutz fuer die alten Q02–Q09-Verdikte) — ROT nach Stehender Vollmacht, keine
  autonome Handlung.
- **C (Parken):** die 9-10 betroffenen Zeilen bleiben dauerhaft `REVIEW_REQUIRED`/ohne
  Prioritaetsspur dokumentiert, bis ein spaeteres Rebuild-Fenster ansteht.

Soll Codex beauftragt werden, (1) den exakten betroffenen Scope zu vermessen (alle pending +
bereits freigegebenen B'-Zeilen gegen die 03.08.-Grenze) und (2) **B (Neubau, beginnend mit
11167)** vorzubereiten — oder soll bis auf Weiteres **C (Parken)** gelten?

## Kosten des Wartens

Ohne Entscheid bleibt jeder Pre-03.08-Build im B'-Zaehlerpfad strukturell unpassierbar; jeder
weitere Claim-Versuch verbrennt einen mehrstuendigen Tester-Slot ohne Endpunkt (11167 hat bereits
zwei solche Slots verbraucht: 07.09. 07:18–16:00Z und 08.09. 14:40–15:15Z). Die B′-Akzeptanz
("erste Adjudikationen enden PASS/FAIL") bleibt fuer diesen Pfad strukturell unerreichbar, bis
Neubau oder Parken entschieden ist. 11196 ist bereits von der Prioritaetsspur genommen und bleibt
es in jedem Fall.

## Empfehlung: B, aber gestuft (11167 zuerst)

Neubau ist der einzig belegte Weg zu einem echten PASS/FAIL-Verdikt fuer diese Kohorte; ein
deklariertes Residuum waere hier — anders als beim sv-Fall — keine ehrliche Analogie, weil die
Kalenderbindung selbst, nicht nur eine Nebenevidenz, unverifizierbar bliebe. Empfehlung: zuerst
nur 11167 neu bauen (kleinster Test des Rebuild-Pfads, bereits mehrfach angefasst), Kohorte danach
nachziehen. Alternativ C, falls OWNER den Rebuild-Aufwand jetzt nicht will.

## Auswirkung JA (Option B, gestuft)

Genau EIN Claude-Auftrag: Codex-Ticket (Scope-Messung aller pending/freigegebenen Q10_NEWS-Zeilen
gegen die 03.08.-Grenze; danach Neubau von QM5_11167 mit aktuellem Template als neue Identitaet ab
Q02 — kein Bestandsschutz fuer die alten Q02–Q09-Verdikte, altes Binary/alte Zeilen bleiben
unveraendert als Evidenz stehen). Kein Repin, kein Publish, kein T_Live, keine Schwelle, kein
Verdict-Overwrite auf bestehenden Zeilen.

## Auswirkung NEIN (Option C)

Betroffene Zeilen bleiben dokumentiert ohne Prioritaetsspur geparkt, bis eine spaetere Entscheidung
faellt; die bereits terminierten post-08.03-B'-Zeilen laufen unveraendert weiter.
