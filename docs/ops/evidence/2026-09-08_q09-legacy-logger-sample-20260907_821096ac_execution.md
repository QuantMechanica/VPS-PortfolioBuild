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

## Geprueft 2026-09-09T~0700Z (Orchestrierungszyklus) — keine Aenderung; weitere ausfuehrliche Eintraege ausgesetzt

Keine OWNER-Antwort (Antwort-Abschnitt weiterhin fehlend); `G:`-Vault weiterhin `Access is denied`.
`2f717775` (Codex, Dukascopy price_scale-Ticket, gehoert zu `3032534e`) weiterhin `APPROVED`/unassigned
seit 01:24:20Z (~5h20m unclaimed) — Codex-Lane wirkt weiterhin blockiert. Bestaetigtes Scheduler-Pileup
(mehrere gleichzeitige `claude.exe`-Orchestrierungszyklen) verbrennt knappes Wochenkontingent (81%
verbraucht) auf redundanten No-Change-Checks ueber diese Aufgabengruppe; kein Fix von innerhalb dieser
Aufgabe ausgeloest (Scheduled-Task-Aenderung braucht OWNER-Autorisierung, ausserhalb dieses Auftrags).
Kein neues Ticket, Rebuild, Release. Aufgabe bleibt IN_PROGRESS.

## Checked 2026-09-09T07:05Z -- keine OWNER-Antwort, keine Aenderung

## Checked 2026-09-09T07:18Z -- no change

Same gate as bb814520 above: no OWNER answer, no live lease, no new ticket/rebuild/release. Task remains IN_PROGRESS.

## Checked 2026-09-09T07:19Z -- no change

No OWNER answer to OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909 (shared gate with `bb814520`). No new ticket, rebuild or release. Task remains IN_PROGRESS.

## Checked 2026-09-09T~0800Z -- OWNER answer found; gating decision unblocked

Router task `46167bd9` (routed 07:37:31Z) now carries `OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909
= YES` (decided 04:18:52Z, receipt `70823296-549a-4fba-8d2d-68ef34607664`, Option B staged:
rebuild `QM5_11167` only as a new identity from Q02; cohort follow-up later). The answer
never appeared in the Vorlage file's `OWNER-Antwort` section (confirmed still absent) — it
was only visible directly in the router's `list-tasks` payload for `46167bd9`, which is why
~15 prior cycles checking the Vorlage file found nothing. Full record:
`2026-09-09_q09-legacy-calendar-input-20260909_70823296_execution.md`. Codex ticket
`b66b5ccc-7826-4c60-9d64-2bb5d3fb09c3` enqueued this cycle (verified in `agent_tasks` via
direct DB read: `state=IN_PROGRESS`, `assigned_agent=codex`) for the scope measurement +
governed 11167-only rebuild.

Note: a concurrent orchestration-cycle session (confirmed pileup, see
`OPEN_ITEMS_STATUS.md`) independently worked the same objective and its own evidence file
claims a second ticket `5088aa6e` — that ID does **not** exist in `agent_tasks` on direct
re-check (twice). Treating it as an unconfirmed concurrent-session claim, not acted on
further; `b66b5ccc` is the one verified ticket in flight. See the correction note in
`46167bd9`'s own execution record for detail.

This task (`dfc60103`) stays gated the same way: its own acceptance criterion ("11167
rerun ends PASS/FAIL, not REVIEW_REQUIRED cell_execution_failed") is structurally
unreachable until the rebuild lands. No release, repin, or verdict change this cycle. Task
remains `IN_PROGRESS`.

## Checked 2026-09-09T09:1xZ (orchestration cycle) — b66b5ccc → REVIEW, Q02 still pending; no action

`b66b5ccc` moved `IN_PROGRESS`→`REVIEW` (09:09:18Z, verdict
`BUILD_PASS_Q02_ADMITTED_TESTER_ECHO_PENDING`); out of scope this cycle (REVIEW, not
IN_PROGRESS/claude). Q02 item `58b36f74` still `pending`. This task's own acceptance ("11167
rerun ends PASS/FAIL") stays unmet. No router state change. Further verbose entries here
suppressed until Q02 or the review actually resolves.

## Checked 2026-09-09T09:45Z (orchestration cycle) — QM5_41394/EURUSD Q02 PASSED; still gated

Q02 work item `58b36f74` now `status=done`/`verdict=PASS` (09:39:06Z) — first gate cleared, but
this task's acceptance ("11167 rerun ends PASS/FAIL") needs a Q10_NEWS adjudication, which
requires Q03-Q09 first and only runs the calendar-echo check this rebuild targets. Full
reasoning in `46167bd9`'s execution record. No release, repin, or verdict change. Task remains
`IN_PROGRESS`.

## Checked 2026-09-09T09:04Z (orchestration cycle) — QM5_41394 compiled, Q02 queued

`QM5_41394` (the governed new-identity rebuild of `QM5_11167` under decision
`OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909`) compiled successfully: work item
`1fb4d6f0` is `status=done`, `.ex5` published in commit `99d6330963` (10:53:45Z), and a Q02
work item `58b36f74` is queued (`status=pending`). Full detail in
`2026-09-09_q09-legacy-calendar-input-20260909_70823296_execution.md`. This is progress on
the rebuild this task is gated on, not on this task's own sv-logger scope directly. No
action taken here beyond the read; Q02 has not run yet, so this task's own acceptance
criterion is still open. Task remains `IN_PROGRESS`.

## Cycle check 2026-09-09T~11:0xZ — remaining 4 symbol legs enqueued; still gated

All five `QM5_41394` intake symbols now have a `Q02` work item (EURUSD PASS→Q04 FAIL
strategy-taxonomy; SP500/USDJPY/XAUUSD/XTIUSD `pending`, created 10:52:59Z) — full detail
in `46167bd9`'s execution record. This is forward motion on the rebuild this task is gated
on, not this task's own sv-logger scope. `farmctl health`: FAIL 13/WARN 17/OK 53, same
chronic set, none referencing this chain. No action taken beyond the read; this task's own
acceptance criterion ("11167 rerun ends PASS/FAIL") is still unmet. Task remains
`IN_PROGRESS`.

## Checked 2026-09-09T11:33Z (orchestration cycle) — b66b5ccc → APPROVED bookkeeping; no new gate result

Same shared gate as `bb814520`: `b66b5ccc` moved `REVIEW`→`APPROVED` (11:19:40Z) confirming
the already-known EURUSD Q02 PASS — not a new gate result and not this task's own symbol
(11167/XAUUSD lineage). The four remaining `QM5_41394` legs are still `Q02 status=pending`.
`2f717775` (this task's own open Codex ticket, non-FX price_scale/point_size — actually
belongs to `3032534e`, cross-referenced only) not touched. No ticket, rebuild, or release
made here. Task remains `IN_PROGRESS`, acceptance criterion still unmet.

## Checked 2026-09-09T11:50Z — no change (direct DB read)

Q02 legs for `QM5_41394` unchanged since 10:52:59Z (SP500/USDJPY/XAUUSD/XTIUSD still
`pending`). Same gate as `bb814520`. Task remains `IN_PROGRESS`.

## Checked 2026-09-09T12:03Z (orchestration cycle) — no change (direct DB read)

Q02 legs for `QM5_41394` still unchanged since 10:52:59Z (SP500/USDJPY/XAUUSD/XTIUSD
`pending`); EURUSD leg remains Q02 PASS/Q04 FAIL (unrelated dead end). farmctl health
overall FAIL (14 FAIL/19 WARN/50 OK), same chronic set as prior cycles; none bear on
this chain. No OWNER-scope work invented, no router command run. Task remains
`IN_PROGRESS`.

## Checked 2026-09-09T12:19Z (orchestration cycle) — USDJPY leg Q02 PASS; this task's own symbol (11167/XAUUSD lineage) still pending

Same gate as `bb814520`: `QM5_41394` `USDJPY.DWX` Q02 moved `pending`→`done`/`PASS` at
12:17:13Z, but that is not this task's own symbol — `XAUUSD.DWX` (11167 lineage) is
still `pending` since 10:52:59Z, no Q03/Q04 spawned for any leg yet. This task's
acceptance ("11167 rerun ends PASS/FAIL") stays unmet. `farmctl health`: overall FAIL,
16 FAIL/19 WARN/49 OK, same chronic set plus a new `disk_scratch_rate_runway` FAIL
(D: free 54.4GB, ~1.96h projected runway) — farm-wide, out of scope for this ticket,
hourly purge already active. Spawn lease `agent_task:dfc60103-16e2-5863-80d2-a680a6da2f26`
reacquired (30 min). No ticket, rebuild, release, or verdict change made here. Task
remains `IN_PROGRESS`.

## Checked 2026-09-09T13:59Z (orchestration cycle) — no change (direct DB read)

`QM5_41394` `XAUUSD.DWX` (this task's own 11167 lineage symbol) still `Q02 pending`
since 10:52:59Z; SP500/XTIUSD also still pending; USDJPY advanced to `Q03 pending`
(13:09:21Z). This task's acceptance criterion stays unmet. Same gate as `bb814520`
(see that file for this cycle's fuller note). No ticket, rebuild, release, or verdict
change made here. Task remains `IN_PROGRESS`.

## Checked 2026-09-09T14:18Z (orchestration cycle) — no change

Same gate as `bb814520`: XAUUSD/SP500/XTIUSD still `Q02 pending` since 10:52:59Z
(~3h25m, unchanged since 13:59Z check). No ticket, rebuild, release, or verdict
change. Read-only this cycle, lease not reacquired. Task remains `IN_PROGRESS`.

## Checked 2026-09-09T14:39Z (orchestration cycle) — no material change

Same gate as `bb814520`: XAUUSD (this task's own 11167 lineage), SP500, XTIUSD still
`Q02 pending` since 10:52:59Z (~3h46m); USDJPY Q03 pending since 13:09:21Z, no Q04
progress. This task's acceptance ("11167 rerun ends PASS/FAIL") stays unmet. No ticket,
rebuild, release, or verdict change; read-only, lease not reacquired. Task remains
`IN_PROGRESS`.

## Checked 2026-09-09T14:49Z (orchestration cycle) — no material change

Same gate as `bb814520`: XAUUSD (this task's own 11167 lineage), SP500, XTIUSD still
`Q02 pending` since 10:52:59Z (~3h56m); USDJPY Q03 pending since 13:09:21Z, no Q04
progress. This task's acceptance ("11167 rerun ends PASS/FAIL") stays unmet. No ticket,
rebuild, release, or verdict change; read-only, lease not reacquired. Task remains
`IN_PROGRESS`.

## Checked 2026-09-09T15:33Z (orchestration cycle) — no change

Same gate as `bb814520` (see that file for the fuller note this cycle): direct DB read shows
`QM5_41394` XAUUSD Q02 still `pending` since 10:52:59Z. No ticket, rebuild, release, or verdict
change. Task remains `IN_PROGRESS`.

## Checked 2026-09-09T15:5xZ (orchestration cycle) -- no change

Same gate as bb814520 (see that file for the scheduler-pileup check this cycle). QM5_41394 XAUUSD Q02 still pending. No ticket, rebuild, release, or verdict change. Task remains IN_PROGRESS.

## Checked 2026-09-09T16:0xZ (orchestration cycle) -- no change, direct DB read

Same gate as `bb814520` (see that file for the fuller direct-DB read this cycle): `QM5_41394` XAUUSD Q02 row still `claimed_by=NULL`/`attempt_count=0`, unclaimed since 10:52:59Z -- ordinary queue depth (755 Q02 rows pending farm-wide), not a stall or error. This task's acceptance ("11167 rerun ends PASS/FAIL") stays unmet. No ticket, rebuild, release, or verdict change. Task remains `IN_PROGRESS`.

## Checked 2026-09-09T16:06Z (orchestration cycle) -- no change

Same gate as `bb814520`. Still unclaimed since 10:52:59Z. No ticket, rebuild, release, or verdict change. Task remains `IN_PROGRESS`.

## Checked 2026-09-09T16:18Z (orchestration cycle) -- no change

Same gate as `bb814520`. Still unclaimed since 10:52:59Z (~5h25m). No ticket, rebuild, release, or verdict change. Task remains `IN_PROGRESS`.

## Checked 2026-09-09T16:17Z (orchestration cycle) -- no change

Same gate. Still unclaimed since 10:52:59Z. No ticket, rebuild, release, or verdict change. Task remains `IN_PROGRESS`.

## Checked 2026-09-09T16:33Z (orchestration cycle) -- no change

Same gate as `bb814520` (direct DB read, ~5h40m unclaimed). No ticket, rebuild, release, or verdict change. Task remains `IN_PROGRESS`.

## Checked 2026-09-09T17:03Z (orchestration cycle) -- no change

Same gate as bb814520. QM5_41394 XAUUSD (11167 lineage) Q02 still pending since 10:52:59Z. No ticket, rebuild, release, or verdict change. Task remains IN_PROGRESS.

## Checked 2026-09-09T17:18Z (orchestration cycle) -- no change

Same gate as bb814520, unchanged since 17:03Z. No ticket, rebuild, release, or verdict change. Task remains IN_PROGRESS.

## Checked 2026-09-09T17:32Z (orchestration cycle) -- no change

Same gate as bb814520 (QM5_41394 XAUUSD/SP500/XTIUSD Q02 still pending since 10:52:59Z). No ticket, rebuild, release, or verdict change. Task remains IN_PROGRESS.

## Checked 2026-09-09T1749Z (orchestration cycle) -- no change

Same gate as bb814520 (QM5_41394 XAUUSD/SP500/XTIUSD Q02 still pending since 10:52:59Z, ~6h56m). Spawn lease agent_task:dfc60103 expired at 14:27Z; not reacquired. No ticket, rebuild, release, or verdict change. Task remains IN_PROGRESS.

## Checked 2026-09-09T1818Z (orchestration cycle) -- no change

Same gate as bb814520 (QM5_41394 SP500/XAUUSD/XTIUSD Q02 still pending/unclaimed since 10:52:59Z, ~7h25m, verified by direct DB read). No new OWNER answer on the pending rebuild-vs-park card. No ticket, rebuild, release, or verdict change. Task remains IN_PROGRESS.

## Checked 2026-09-09T18:30Z (orchestration cycle) -- no change

Same gate as bb814520 (see that file for the fuller note this cycle, incl. confirmed 5-process claude.exe pileup and 88%/12% weekly quota). QM5_41394 XAUUSD Q02 still pending, unchanged since 10:52:59Z. No ticket, rebuild, release, or verdict change. Task remains IN_PROGRESS.

## Checked 2026-09-09T~18:50Z (orchestration cycle) -- no change

Same gate as bb814520. QM5_41394 XAUUSD Q02 still pending since 10:52:59Z (~8h). No ticket, rebuild, release, or verdict change. Verbose entries suppressed per note in bb814520's file. Task remains IN_PROGRESS.

## Checked 2026-09-10T22:25Z (orchestration cycle, first check this session, ~35h32m gap since prior entry) -- gate still unmet, new context

Same gate as `bb814520` (see that file for the fuller note this cycle). QM5_41394 XAUUSD.DWX Q02 (the 11167 lineage row this task's acceptance depends on) still `status=pending`, `claimed_by=NULL`, `updated_at=2026-09-09T10:52:59Z`, ~35h32m static. Sibling row XTIUSD.DWX from the same EA cluster cleared Q02->Q03->Q04 on 2026-09-10 -- the queue is actively draining elsewhere, only SP500/XAUUSD remain stuck on this EA. Not this task's authority to reprioritize (`selected_effect_only`). Weekly quota healthy post-reset (0.1% used) -- the 2026-09-09 quota-pressure suppression driver is gone, but per-cycle logging discipline is kept to avoid re-introducing the same near-duplicate-entry problem. No `update-task` call -- acceptance criterion ("11167 rerun ends PASS/FAIL") still unmet. Task remains `IN_PROGRESS`.
