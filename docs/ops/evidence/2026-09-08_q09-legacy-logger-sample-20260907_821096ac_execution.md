# Option A — Legacy-Logger, begrenzter Rollout am 2026-09-08

## Autorität und Status

OWNER hat im Chat ausdrücklich **A** gewählt. Das vorangegangene Briefing begrenzt
die Ausnahme auf exakt identifizierte, nachweislich alte Binaries; ein Dateidatum
allein reicht nicht. Keine zusätzliche Owner-Entscheidung ist für diese Umsetzung nötig.

- Entscheidung: `OWNER-DEC-Q09-LEGACY-LOGGER-SAMPLE-20260907 = YES`.
- Receipt: `821096ac-8f7f-4c28-b0ce-63a09e959de1`.
- Receipt SHA-256: `8a16cacebf51d5208d93d86b6d5c3da3b267ce8fc46a2c2cfb28ae11f6ce8558`.
- Reservierter Ausführungsauftrag: `dfc60103-16e2-5863-80d2-a680a6da2f26`.
- Umsetzung erfolgt lokal in diesem Codex-Thread. Keine weiteren Subagenten gestartet.
- **Code verifiziert, native Canary-Abnahme noch offen. Nicht als vollständig erledigt schließen.**

## Umsetzung

`legacy_logger_policy.py` prüft das reale Owner-Receipt, die freigegebene EA-ID und
EX5-SHA-256, den bytegleichen EX5-Git-Blob und dessen Commit-Abstammung vor
`6e92c806264d5216c46ba6ad4f8cf8c0641b53f8` sowie das Commit-Datum vor 20.07.2026.
Die explizite Magic-Slot-Einstellung muss zur archivierten aktiven Registry-Zeile
für genau dieses Symbol passen. Kein mtime-Fallback, kein generelles Legacy-Flag.

`run_smoke.ps1` erlaubt fehlendes `sv` ausschließlich unter
`-RequireFreshLoggerSample`, exklusivem Tester und Q09-v3-Kontext im aktuellen
Q10_NEWS-Executor. Die beiden eigenständigen Fenster Selection und Holdout brauchen
dieselbe begrenzte Authentifizierung; Full-/Legacy-v2-/Q02-Smokes bekommen sie nicht.
Pre-Run-Archiv, leerer Anfangszustand, Writer-Quieszenz, unveränderte Byte-Präfixe,
genau eine wachsende Datei, vollständige UTF-8-JSONL-Zeilen und alle anderen
Pflichtfelder bleiben erforderlich. EA-ID, Magic, Symbol und Timeframe werden
zusätzlich exakt gebunden. Kein erfundenes `sv`; die Log-Bytes bleiben identisch.

Der Q09-Verbraucher authentifiziert die Ausnahme erneut. Smoke-Summary, Fußnote,
Fenster-/Zell-Receipts, Zell-Evidenz und neuer Aggregate tragen
`logger_sample_authentication=legacy_no_sv`. Entfernte oder widersprüchliche
Deklarationen werden abgelehnt. Die bestehende wirtschaftliche Adjudikation,
Schwellen und Auswahl werden nicht geändert; neue Evidenz erhält ehrliche neue Hashes.

Deterministische Logger-Authentifizierungsfehler sind nicht mehr
`TransientCellError`: kein dreifacher identischer Versuch. Sie bleiben Fehler,
kein PASS und keine Live-Autorisierung.

## Build-Nachweis und Reihenfolge

Neun konkrete Binaries aus dem Sept.-7-Befund wurden am Sept. 8 erneut geprüft:
11167, 11196, 10148, 10476, 10771, 11179, 1230, 12474, 9573. Bei allen stimmen
heutige EX5-Bytes mit einem archivierten Pre-Control-Git-Blob überein. Die exakten
Hashes/Commits stehen in `tools/strategy_farm/config/legacy_logger_allowlist.v1.json`.
Die neun Binaries sind nicht mit neun Warteschlangen-Zeilen gleichzusetzen.

**Nur 11167 ist zunächst aktiviert.** 11196 und die weiteren registrierten Binaries
bleiben `enabled=false`, bis die native Canary-Authentifizierung geprüft wurde.
Unbekannte oder inzwischen neu gebaute Binaries bleiben strikt im normalen Pfad.

11167 aktuelles EX5: `4b349d21060502bd5f4ce3eb7619b1bed75e7e9630ea74eb7d85b06e4795dd99`.
Archiv-Commit: `f1b1abd677694ebb1bb9f455af52eda8759efafd`, 14.07.2026 23:08:03 +02:00.
XAUUSD-Magic im archivierten Registry-Stand: `111670002`, Slot 2.

Alter Q10_NEWS-Lauf bleibt unverändert:
`f625d9aa-da34-44bb-aa9f-0eda284f3f32`, `REVIEW_REQUIRED`.
Sein Aggregate-SHA vor dem Retry:
`17b100b7c3bee61cfcba26a2339304735fe54bcf522349eb46145ffadd3994e4`.
Exakter Q09-PASS-Vorgänger: `e960b158-b9ea-4db5-9d46-cfbb9a51d762`.

## Verifikation, 16:08 Wien

**124 Tests bestanden** (41,89 s): Legacy-Policy, Q09-Runner, Scan-Hardening,
Q09-Schema und -Contract, echte PowerShell-Logger-Funktionen, Empty-Tester-Log,
strikter Schema-v1-Resolver. Negativfälle: fremder/geänderter/post-control Build,
fehlendes/manipuliertes Owner-Receipt, falscher Kontext, falsche Magic/Symbol/TF,
fehlende Felder, nicht frischer oder gemischter Stream, verlorene Deklaration.

Die Suite enthält ausdrücklich den Vergleich der wirtschaftlichen Adjudikation
vor/nach Kennzeichnung; nur die geänderten Evidenz-Hashes dürfen abweichen.

## Noch abzuarbeiten

1. Genau einen kanonischen append-only 11167-Rerun einreihen; alte Zeile nicht ändern.
2. Normalen Autoseal-/Kalender-Scope-/Ressourcenpfad abwarten bzw. exakt reparieren;
   keine laufenden Terminals unterbrechen, keinen Hold blind entfernen.
3. Frische native Selection- und Holdout-Logs samt Receipt/Report/EX5-Bindung prüfen.
4. Erst danach 11196 aktivieren und bestehende Priorität wiederherstellen;
   weitere nachgewiesene Alt-Binaries in bestehender B-prime-Reihenfolge.
5. Vollständiges terminales Gate-Ergebnis separat abnehmen. Ein bestandener
   Infrastrukturtest ist kein bestandenes Strategie-Gate.

## Native Canary eingereiht, 16:12 Wien

- Implementierungs-Commit: `07af95fcf1`.
- Neuer Work-Item: `6797ed1c-597a-4d44-82f9-7379d45b5e06`, angelegt 14:09:36 UTC.
- Genau ein append-only Rerun des alten `f625d9aa`; `priority_track=true` übernommen.
- Autoseal hat um 14:10:33 UTC regulär den neuen 8-Zellen-v3-Plan gebunden.
- Plan-Datei SHA: `347afa7c2f81b1cfb735136c96ecc7d93891e7e7ac9d35f305cf01eb35183157`.
- Input-Manifest SHA: `fa59dfd82b7bc554608122cb15eb691bd0d17fef7bc4255d6da23bee3682f420`.
- Separater Kalender-B′-Guard wurde für diese neue Zeile frisch ausgewertet:
  `ADMISSIBLE`, nur USD-Exposure, D1, 2019-01-01 bis 2026-01-01 exklusiv.
- Assessment SHA: `b7400acdfa5db93b4863931e2b89ef53aab046de5b90621b329b661ac3b01c4f`.
- Unter Factory-Mutationslock und Transaktion wurden über die kanonischen
  `synchronize(..., item_id=...)` / `release_scoped_item(...)`-Funktionen nur diese
  Zeile und ihr Kalender-Hold behandelt. Frischer Marker + Fußnote um 14:12:23 UTC;
  `status`, `verdict`, `evidence_path` blieben unverändert. Kein fremder Hold entfernt.
- Die Backup-API lieferte den wiederverwendeten gültigen Governance-Anker
  `D:/QM/strategy_farm/state/backups/farm_state_before_news_calendar_taint_20260908T134821Z_c6de486b.sqlite`,
  SHA `7df7991d0c91a73e3bdb98693df15b9ecb554f453dd49835e596539f1e3816b6`;
  dies ist kein behaupteter neu erstellter 14:12-Snapshot.

Der Canary war bei der Kontrolle um 14:12:40 UTC **pending**, Plan gebunden,
Kalender-Hold inaktiv, regulärer freier Tester noch ausständig. Schritte 1–2 oben
sind damit erledigt; Schritte 3–5 bleiben offen. Keine weiteren Binaries aktiviert.

Kein Rebuild, Repin, Publish, T_Live-/FTMO-Chartwechsel, AutoTrading-, Konto-,
Order- oder Risiko-Eingriff. Keine historische Evidenz gelöscht oder umgeschrieben.

## Canary-Ergebnis 2026-09-08 17:32Z — REVIEW_REQUIRED, neuer strukturelle Defekt (nicht der sv-Logger)

Der native Canary-Lauf (`6797ed1c-597a-4d44-82f9-7379d45b5e06`) endete
`REVIEW_REQUIRED` / `cell_execution_failed`, 8/8 Zellen — aber **nicht** wegen
eines fehlenden `sv`-Feldes. Fehlerursache lt. `cell_failure.json` (alle 8
Zellen identisch): `RunnerError "MT5 report effective input
qm_news_calendar_bundle_id mismatch"`.

**Root cause (verifiziert, kein Verdacht):** `QM5_11167`'s EX5 wurde am
2026-07-14 committet (`f1b1abd677…`, `git show -s`). Die drei
Provenienz-Echo-Inputs `qm_news_calendar_bundle_id`,
`qm_news_calendar_expected_sha256`, `qm_news_calendar_common_relative_path`
wurden erst am **2026-08-03** durch Commit `f0102fbcf` in
`QM_NewsFilter.mqh` (eingebunden über `QM_Common.mqh`, das `QM5_11167.mq5`
`#include`t) deklariert. Der kompilierte Altbau vom 14.07. kennt diese Inputs
nicht — der Q10_NEWS-Runner schreibt sie dennoch in jede Zell-`.set`
(`q09_news_runner.py:323`) und prüft sie im Tester-Report-Echo
(`_validate_report_effective_inputs`); das Echo bleibt leer → Mismatch. Das
ist exakt die am 2026-08-24 für `QM5_9936` dokumentierte Defektklasse
(`docs/ops/evidence/2026-08-24_qm5_9936_news_provenance_include_revision.md`),
hier reproduziert für `QM5_11167`.

**Kohortenbefund:** alle 9 im `legacy_logger_allowlist.v1.json` registrierten
Binaries (11167, 11196, 10148, 10476, 10771, 11179, 1230, 12474, 9573) wurden
zwischen 2026-06-07 und 2026-07-15 committet — **alle vor dem 03.08.** Sofern
ihre EAs `QM_Common.mqh`/`QM_NewsFilter.mqh` einbinden (wie 11167), trifft sie
derselbe Mismatch unabhängig vom sv-Logger-Fix. Die sv-Ausnahme (07af95fcf1)
war notwendig, aber **nicht hinreichend** — sie löst nur die Logger-Prüfung,
nicht die Report-Input-Prüfung.

**Die einzig belegte Abhilfe ist ein Rebuild dieser EAs** (Recompile in
aktivem Inventar = ROT nach Stehender Vollmacht, keine autonome Handlung).
Ohne Rebuild kann keine dieser 9-10 Zeilen einen PASS/FAIL-Q10_NEWS-Verdikt
erreichen — die B′-Akzeptanzkriterien ("erste Adjudikationen enden
PASS/FAIL") sind für diesen Pfad strukturell unerreichbar, bis eine
Rebuild-Entscheidung getroffen ist.

**Keine Abweichung von der erlaubten Wirkung vorgenommen:** kein Rebuild,
kein Recompile, kein Verdict-Override, kein Hold blind entfernt; `f625d9aa`
und `6797ed1c` bleiben unverändert als Evidenz stehen. Empfehlung an OWNER:
neue Karte "Rebuild pre-08-03-Legacy-Kohorte ja/nein" (Umfang: 11167 zuerst,
dann kohortenweise) vs. Parken dieser 9-10 Zeilen als dauerhaft
`REVIEW_REQUIRED` bis zu einem späteren Rebuild-Fenster. Dieser Fund betrifft
auch die verkettete B-prime- und Counter-Path-Aufträge (bb814520, 60cd31a8) —
Querverweis dort ergänzt.

## Karte gestellt, 2026-09-09 (Orchestrierungszyklus)

Genau die hier empfohlene Karte wurde gestellt: `OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909`
(Vorlage `docs/ops/OWNER_VORLAGE_2026-09-09_q09_legacy_calendar_input.md`, Empfehlung B gestuft
[11167 zuerst] vs. C Parken; kein deklariertes Residuum — die drei Kalender-Bundle-Inputs steuern
laut `QM_NewsFilter.mqh:744` (`QM_NewsInitTesterBundle`) tatsaechlich den geladenen Bundle, sind
also kein reines Provenienz-Echo). Erstfassung faelschlich mit Deklarations-Option, im selben
Zyklus korrigiert (Commits `a65321d94f`/`33dc5a1979`). Aufgabe `dfc60103` bleibt IN_PROGRESS bis
zur OWNER-Antwort; kein Rebuild ausgefuehrt.

## Geprueft 2026-09-09T03:49:25Z (Orchestrierungszyklus) — keine Aenderung

Erneut auf eine OWNER-Antwort zu `OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909` geprueft: keine
gefunden. `G:`-Vault-Laufwerk verweigert weiterhin den Zugriff aus dieser Session (permission
denied), Vault-Spiegel konnte nicht als Zweitquelle geprueft werden. Kein neues Ticket, kein
Rebuild, kein Release ausgeloest. Aufgabe `dfc60103` bleibt IN_PROGRESS, gebunden an dieselbe
OWNER-Entscheidung wie `bb814520`.

## Geprueft 2026-09-09T04:03Z (Orchestrierungszyklus) — keine Aenderung

Erneut auf eine OWNER-Antwort zu `OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909` geprueft: keine
gefunden. `G:`-Vault-Laufwerk weiterhin permission-denied. Kein neues Ticket, kein Rebuild, kein
Release. Aufgabe `dfc60103` bleibt IN_PROGRESS.

## Geprueft 2026-09-09T04:19Z (Orchestrierungszyklus) — keine Aenderung

Erneut auf eine OWNER-Antwort zu `OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909` geprueft: keine
gefunden. `G:`-Vault-Laufwerk weiterhin permission-denied. Kein neues Ticket, kein Rebuild, kein
Release. Aufgabe `dfc60103` bleibt IN_PROGRESS, gebunden an dieselbe OWNER-Entscheidung wie
`bb814520`.

## Geprueft 2026-09-09T04:18Z (Orchestrierungszyklus) — keine Aenderung

Erneut auf eine OWNER-Antwort zu `OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909` geprueft: keine
gefunden (`git log --since=2026-09-09T04:03:00Z` zeigt nur einen fremden Q02-CPU-Stop-Eintrag).
`G:`-Vault-Laufwerk weiterhin permission-denied. Kein neues Ticket, kein Rebuild, kein Release.
Aufgabe `dfc60103` bleibt IN_PROGRESS.

## Geprueft 2026-09-09T04:33Z (Orchestrierungszyklus) — keine Aenderung

Erneut auf eine OWNER-Antwort zu `OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909` geprueft: keine
gefunden (`Test-Path` auf `G:\...\OWNER.md` → `UnauthorizedAccessException`). Kein neues Ticket,
kein Rebuild, kein Release. Aufgabe `dfc60103` bleibt IN_PROGRESS, gebunden an dieselbe OWNER-
Entscheidung wie `bb814520`.

## Geprueft 2026-09-09T04:48Z (Orchestrierungszyklus) — keine Aenderung

Keine OWNER-Antwort zu `OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909` (`G:`-Vault weiterhin
permission-denied, kein neuer Commit). Kein neues Ticket, kein Rebuild, kein Release. Aufgabe
`dfc60103` bleibt IN_PROGRESS.

## Geprueft 2026-09-09T05:03Z (Orchestrierungszyklus) — keine Aenderung

Erneut auf eine OWNER-Antwort zu `OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909` geprueft: keine
gefunden (`git log --since=2026-09-09T04:48:00Z -- docs/ops/ decisions/` zeigt nur eine fremde
Research-Karten-Freigabe). `G:`-Vault-Laufwerk weiterhin nicht erreichbar aus dieser Session.
`farmctl health` dieses Mal: FAIL 14/WARN 18/OK 51 — dasselbe chronische Set
(`codex_zero_activity`, `repo_dirty_build_guard` durch 11 uncommittete Dateien in `C:\QM\repo`
blockiert, ohne Bezug zu dieser Aufgabe). Kein neues Ticket, kein Rebuild, kein Release. Aufgabe
`dfc60103` bleibt IN_PROGRESS, gebunden an dieselbe OWNER-Entscheidung wie `bb814520`.

## Geprueft 2026-09-09T05:08Z (Orchestrierungszyklus) — keine Aenderung

Erneut auf eine OWNER-Antwort zu `OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909` geprueft: keine
gefunden (`git log --since=2026-09-09T05:03:00Z` zeigt nur einen fremden Docs-Commit zu
Kandidatenprioritaeten). `G:`-Vault-Laufwerk weiterhin permission-denied. Kein neues Ticket, kein
Rebuild, kein Release. Aufgabe `dfc60103` bleibt IN_PROGRESS, gebunden an dieselbe OWNER-
Entscheidung wie `bb814520`.

## Geprueft 2026-09-09T05:20Z (Orchestrierungszyklus) -- keine Aenderung

Erneut auf eine OWNER-Antwort zu `OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909` geprueft: keine
gefunden (`git log --since=2026-09-09T05:08:00Z -- docs/ops/ decisions/` zeigt nur den eigenen
vorherigen Zyklus-Log-Commit dieser Aufgabengruppe). `G:`-Vault-Laufwerk weiterhin
permission-denied. Kein neues Ticket, kein Rebuild, kein Release. Aufgabe `dfc60103` bleibt
IN_PROGRESS, gebunden an dieselbe OWNER-Entscheidung wie `bb814520`.

## Geprueft 2026-09-09T05:48Z (Orchestrierungszyklus) — keine Aenderung

Weiterhin keine OWNER-Antwort. Kein neues Ticket, Rebuild oder Release. Kein aktiver Spawn-Lease
auf `dfc60103`. Angesichts der bereits ~10 fast identischen Log-Eintraege oben seit 00:56Z ohne
OWNER-seitige Aenderung wird hier keine weitere ausfuehrliche Wiederholung mehr protokolliert;
siehe Sammelvermerk in `2026-09-07_calendar-criteria-b-prime-20260907_617abd80_execution.md`.
Aufgabe `dfc60103` bleibt IN_PROGRESS.

## Geprueft 2026-09-09T06:17Z (Orchestrierungszyklus) -- keine Aenderung

Weiterhin keine OWNER-Antwort zu OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909 (G:-Vault weiterhin permission-denied). Kein neuer relevanter Commit seit 05:48Z. Kein neues Ticket, Rebuild, Release. Aufgabe bleibt IN_PROGRESS.

## Geprueft 2026-09-09T06:20Z (Orchestrierungszyklus) -- keine Aenderung; Pileup bestaetigt

Dieser und der 06:17Z-Eintrag stammen aus zwei gleichzeitig laufenden Orchestrierungszyklen (bestaetigt
9 parallele `claude.exe`-Prozesse) — konkreter Beleg fuer das bereits mehrfach geflaggte Scheduler-Pileup,
keine neue Handlung ausgeloest. Keine OWNER-Antwort. Aufgabe bleibt IN_PROGRESS.

## Geprueft 2026-09-09T06:39Z (Orchestrierungszyklus) — keine Aenderung

Weiterhin keine OWNER-Antwort auf OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909 (Vorlage-Datei ohne
OWNER-Antwort-Abschnitt geprueft; `G:`-Vault weiterhin nicht erreichbar; kein aktiver Spawn-Lease
auf `dfc60103`). Aufgabe bleibt IN_PROGRESS. Substanzielle Zyklusarbeit fand stattdessen bei Aufgabe
`3032534e` statt (Dukascopy-Reprobe, siehe eigene Evidenzdatei).
