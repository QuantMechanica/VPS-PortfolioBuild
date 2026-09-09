# OWNER Vorlage — Q09/Q10_NEWS: Alt-Builds ohne Kalender-Bundle-Input (zweite, fruehere Legacy-Grenze)

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

**Betroffener Umfang noch nicht abschliessend gemessen.** Bekannt betroffen: 11167 (Build
14.07.). Wahrscheinlich betroffen (gleiche Pre-sv-Kohorte, Baudatum zu pruefen): 10148, 10476,
10771 (2x), 11179, 11196, 1230 (2x), 12474, 9573. Ob post-sv/pre-08.03-Builds aus der bereits
freigegebenen B'-Kohorte (10145/SP500, 10513/XAUUSD u.a.) ebenfalls betroffen sind, ist ungeklaert
und Teil von Schritt 1 unten — unabhaengig von der OWNER-Wahl.

## Frage

Darf `q09_news_runner.py::_validate_report_effective_inputs` fuer EX5-Builds vor dem
03.08.2026-Commit (`f0102fbcf2`, git-archiviert, Baudatum exakt geprueft) das Fehlen der drei
Kalender-Bundle-Input-Felder als deklariertes Residuum akzeptieren (Option A, analog zum
`sv`-Praezedenzfall: alle anderen Effektiv-Input-Pruefungen — RISK_FIXED/RISK_PERCENT, Seed,
News-Temporal/-Compliance, Stale-Max — bleiben scharf; Receipt-Feld
`calendar_input_authentication=legacy_no_bundle_binding`), statt Neubau (B, neue Identitaet ab
Q02) oder Parken (C)?

## Kosten des Wartens

Ohne Entscheid bleibt jeder Pre-03.08-Build im B'-Zaehlerpfad strukturell unpassierbar; jeder
weitere Claim-Versuch verbrennt einen mehrstuendigen Tester-Slot ohne Endpunkt (11167 hat bereits
zwei solche Slots verbraucht: 07.09. 07:18–16:00Z und 08.09. 14:40–15:15Z). 11196 ist bereits von
der Prioritaetsspur genommen und bleibt es.

## Empfehlung: A

Gleiche Begruendung wie beim `sv`-Praezedenzfall: das Residuum ist git-archiviert, exakt
baudatumsgebunden und ehrlich deklariert, kein erfundener Wert. Neubau (B) ist der teuerste Weg
fuer Strategien, die inhaltlich bereits Q02–Q09 bestanden haben. Schritt 1 (exakter Scope: welche
Builds genau, inkl. bereits freigegebener B'-Zeilen) ist unabhaengig von der OWNER-Wahl notwendig
und wird in jedem Fall zuerst ausgefuehrt.

## Auswirkung JA (Option A)

Genau EIN Claude-Auftrag: Codex-Ticket (Scope-Messung aller pending/freigegebenen Q10_NEWS-Zeilen
gegen die 03.08.-Grenze; Guard-Erweiterung in `_validate_report_effective_inputs` nur fuer exakt
git-archivierte Pre-`f0102fbcf2`-Builds unter der bestehenden Legacy-Autorisierungskette, mit
Tests; Receipt-Feld + Fussnote), danach genau ein 11167-Rerun (append-only, gleiche Kette wie der
bisherige) und — nur bei PASS/FAIL-terminalem Ergebnis — Rueckgabe der Prioritaetsspur an 11196 in
bestehender B'-Reihenfolge. Kein Repin, kein Publish, kein T_Live, keine Schwelle, kein
Verdict-Overwrite auf bestehenden Zeilen.

## Auswirkung NEIN (keine Wahl / C)

Betroffene Zeilen bleiben dokumentiert ohne Prioritaetsspur geparkt, bis eine spaetere Entscheidung
faellt; die bereits terminierten post-08.03-B'-Zeilen laufen unveraendert weiter.
