# MNT-052 — Legacy-v1 Restore-Intent Guard

Status: **SOURCE IMPLEMENTED / RUNTIME DEFERRED**
Datum: 2026-07-29

## Defekt und Sicherheitsentscheidung

Die gesetzte Runtime-Flag ist ein Legacy-Record ohne gespeicherten Task-Intent:

```json
{"off_at":"2026-07-29T07:27:38Z","codex_parallel_before":"0"}
```

SHA-256:
`09cc4f83e8d5f384f03bc51306beff2cdd165108559a00dbf665097c60b47f1c`.

Der vorherige Upgradepfad las für alle `QM_QUIESCENCE_TASKS` den aktuellen
Scheduled-Task-Zustand. Diese Tasks wurden während der manuellen Quiescence
bereits deaktiviert; `false` wäre deshalb ein Post-OFF-Befund und keine
rekonstruierte Pre-OFF-OWNER-Absicht. Der neue Vertrag verbietet diese
Inference vollständig.

## Vertrag

Bei vorhandener Legacy-v1-Flag ohne `task_enabled_before` gilt:

1. Ohne `Factory_OFF.ps1 -RestoreIntentManifest <path>` erfolgt ein Abbruch vor
   dem ersten Write beziehungsweise Scheduler-/Prozesszugriff.
2. Das Manifest muss `qm.factory-restore-intent/v1` erfüllen.
3. `legacy_off_flag.path` muss auf exakt die gelesene Flag zeigen und
   `legacy_off_flag.sha256` deren aktuelle Bytes binden. Direkt vor dem ersten
   Interlock-Write werden sowohl Flag- als auch Manifest-Bytes erneut gegen die
   vom Validator attestierten SHA-256-Werte geprüft.
4. `owner_authorization` verlangt `authority=OWNER`, autorisierende Identität,
   einen echten UTC-Zeitpunkt (`Z` oder Offset `00:00`; andere Zeitzonen werden
   trotz Offset abgelehnt), die feste Decision
   `RESTORE_EXACT_PRE_OFF_TASK_INTENT`, eine nichtleere Decision-Referenz und
   den Scope `QM_QUIESCENCE_TASKS_RESTORE_INTENT`.
5. `task_enabled_before` muss exakt dieselben 21 Keys wie
   `$QM_QUIESCENCE_TASKS` enthalten. Jeder Wert muss ein echtes JSON-Boolean
   sein. Duplicate Keys, Missing, Extra, `0/1`, Strings oder `null` sind Fehler.
6. Ein bereits schema-v2-fähiger Record verwendet ausschließlich seinen
   gespeicherten exakten State; ein mitgeliefertes Legacy-Manifest wird dort
   als Fehlbedienung abgelehnt. Bei einem frischen OFF ohne vorhandene Flag ist
   ein Restore-Manifest ebenfalls unzulässig.
7. `Factory_ON.ps1` wiederholt die Exact-Key-/Boolean-Prüfung am gespeicherten
   schema-v2-Record vor `Enter-FactoryMutationLock` und vor dem Flag-Release.
   Damit können manuell driftende Missing-/Extra-Keys sowie String- oder
   `null`-Werte nicht über den früheren `[bool]`-Cast in Restore-Aktionen
   gelangen.

Der Parser verwendet `object_pairs_hook`, damit doppelte JSON-Keys nicht durch
„last value wins“ verborgen werden. Das Template führt alle 21 Keys auf, setzt
ihre Werte aber bewusst auf `null`. Es ist damit eine Ausfüllhilfe, niemals
eine Restore-Autorisierung oder behauptete Taskentscheidung.

## Self-Elevation

Der nicht-administrative Einstieg bildet eine vollständig single-quoted
Invocation, codiert sie als UTF-16LE-Base64 und startet PowerShell mit
`-EncodedCommand`. `-RestoreIntentManifest` und `-NoPause` werden explizit
weitergereicht. Dadurch kann ein Pfad mit Leerzeichen oder PowerShell-
Metazeichen nicht in zusätzliche Argumente oder Befehle zerfallen.

## Verifikation

Ausgeführt, ohne die Factory-Skripte aufzurufen:

```text
python -m pytest -q
  tools/strategy_farm/tests/test_factory_quiescence.py
  tools/strategy_farm/tests/test_factory_restore_intent.py

22 passed
```

Zusätzlich wurden `Factory_OFF.ps1`, `Factory_ON.ps1`,
`qm_tasks.manifest.ps1` und `Test-FactoryRestoreIntent.ps1` ausschließlich mit
dem PowerShell-AST-Parser geprüft. Das PowerShell-Testskript führt nur den
read-only Python-Validator gegen temporäre Dateien aus; der negative Fall
bestätigt, dass die Legacy-Flag unverändert bleibt. Aus `Factory_ON.ps1` wird
für die vier adversarialen Missing-/Extra-/String-/Null-Fälle ausschließlich
die Validator-Funktions-AST geladen; der Script-Body wird nicht ausgeführt.

## Nicht ausgeführt / offen

- Kein OWNER-Restore-Manifest mit tatsächlichen Taskentscheidungen erzeugt.
- Bestehende Runtime-Flag weder ersetzt noch neu formatiert.
- `Factory_OFF.ps1` und `Factory_ON.ps1` nicht ausgeführt.
- Keine Scheduled Task gestartet, gestoppt, aktiviert oder deaktiviert.
- Kein Prozess und keine Runtime-DB verändert.
- T_Live und AutoTrading nicht berührt.
- Echter OWNER-freigegebener OFF/ON-E2E und MNT-046-Runtime-Evidence bleiben
  Exit-Gate.
