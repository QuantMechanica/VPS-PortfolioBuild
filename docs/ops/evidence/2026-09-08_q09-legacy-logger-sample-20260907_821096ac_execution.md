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

Kein Rebuild, Repin, Publish, T_Live-/FTMO-Chartwechsel, AutoTrading-, Konto-,
Order- oder Risiko-Eingriff. Keine historische Evidenz gelöscht oder umgeschrieben.
