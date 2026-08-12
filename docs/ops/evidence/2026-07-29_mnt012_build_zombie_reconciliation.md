# MNT-012 Build-Zombie reconciliation — 2026-07-29

Disposition: **PARTIAL / TASK APPLY EXECUTED**
Run-ID: `MNT012-20260729-BLOCKED-BUILD-ZOMBIES-01`

## Ergebnis

Die Wiederholungsursache ist im Source geschlossen: aktive Blockmarker in
einem Pending-Build-Payload sind nicht mehr dispatchbar, und explizite
R2-R4-Widersprüche zwischen Frontmatter und Kartenkörper schlagen fail-closed.
Für die zwei bekannten Runtime-Zombies wurde der atomare, hashgebundene
`pending→blocked`-Korrekturplan nach einem driftfreien Read-only-Forecast
ausgeführt. Die Runtime-Karten blieben byte-identisch; ihr fachlicher
R3-/G0-Fix bleibt OWNER-/Research-gebunden.

## Reproduzierte Runtime-Fakten

Read-only SQLite-Zugriff auf
`D:\QM\strategy_farm\state\farm_state.sqlite`:

```sql
SELECT id, kind, status, card_id, updated_at, payload_json
FROM tasks
WHERE id IN (
  '76b745d5-fe8d-4f63-900e-aa8c6743f551',
  '08cfd80b-c78c-4527-9143-e650cdc847d1'
);
```

| EA / Task | Status | Payload SHA-256 | aktive Evidenz |
|---|---|---|---|
| `QM5_1457` / `76b745d5-fe8d-4f63-900e-aa8c6743f551` | `pending` | `764f05833019d37e9b3ccd5b51c93b6fa2ddef541a584abb80a21d4784247bb7` | `blocked_at_utc=2026-06-28T07:48:17+00:00`; `non_dwx_rates_inputs_required_by_card` |
| `QM5_1459` / `08cfd80b-c78c-4527-9143-e650cdc847d1` | `pending` | `5330987959dfa5cb84723974a5b5d1e5139dbd77296085e760bf87f335c5deef` | `blocked_at_utc=2026-07-25T11:49:18+00:00`; `r3_missing_lumber_and_ief_dwx_series` |

Für beide EAs existiert kein Work-Item. Die einzige Task-Eventzeile je Zombie
ist das Erstellungsereignis; es fehlt eine dauerhafte Blocktransition. Ältere
Sibling-Tasks sind bereits als `permanent_blocked_retries_exhausted` terminal
und bestätigen dieselben Datenbarrieren.

### Karten- und Source-Evidenz

| EA | Karte SHA-256 | Frontmatter / Body | `.mq5` SHA-256 | Source-Zustand |
|---|---|---|---|---|
| `QM5_1457` | `9c3960b2ad7618da0483f414790a2a1a84a6da2d0f52af8fca0b9aa31a796db8` | `R3 PASS / UNKNOWN` | `4444789e25475af4040b8cfef1832763b19a8e110ad3a891314ff3e7e972a7ce` | Auto-generated skeleton, Entry konstant `false` |
| `QM5_1459` | `8b55ff8e229fa988e4e07d3ebc4ce4517bbae051d1805d525cf75d8f55f36259` | `R3 PASS / UNKNOWN` | `08e37143feb0c0623a54d3ada67823888082efcc27065efcc025c945b8752c1b` | Auto-generated skeleton, Entry konstant `false` |

Die `QM5_1457`-Karte verlangt Treasury-Yield, IEF, BIL und DBC. Die
`QM5_1459`-Karte verlangt Lumber und IEF/Treasury. Die vorhandenen DWX-Proxies
reichen nicht für eine mechanisch identische Umsetzung. Das frühere
QM5_1459-Evidence-Dokument behauptet zwar eine ausgeführte Blocktransition;
die aktuelle, direkt gelesene SQLite-Zeile widerlegt deren Persistenzzustand.

## Implementierte Guards

`tools/strategy_farm/farmctl.py` enthält jetzt:

- `strategy_card_r_gate_consistency`: liest explizite R1-R4-Tabellenzeilen;
  R2-R4 ungleich PASS und Frontmatter-/Body-Drift sind harte Fehler;
- `_build_task_claim_guard`: blockiert aktive Payload-Marker und terminale
  Tombstones, prüft die aktuelle genehmigte Karte und bewahrt
  `last_blocked_reason` ohne aktiven Zeitstempel als Retry-Historie;
- Guard-Aufrufe in Codex-/Gemini-Selektion, Claude-Selektion, vor und nach dem
  Dispatch-Claim sowie vor Result-Aufnahme einer Pending-Zeile;
- denselben Body-/Frontmatter-Abgleich in Prebuild, Auto-Build-Erkennung und
  G0-Approval. Approval bricht vor jeder Kartenmutation ab.

## Exakter Forecast

Manifest:
`docs/ops/evidence/2026-07-29_mnt012_build_zombie_reconciliation_manifest.json`

Read-only-Bindungen zum Forecast-Zeitpunkt:

- DB-Datei SHA-256:
  `b147327029c27ec8f3f3fafcc8d661d4fcb6ecb9fe0e440aa1d8d0ebb941382b`
- logischer SQLite-State SHA-256:
  `b147327029c27ec8f3f3fafcc8d661d4fcb6ecb9fe0e440aa1d8d0ebb941382b`
- Factory-OFF SHA-256:
  `09cc4f83e8d5f384f03bc51306beff2cdd165108559a00dbf665097c60b47f1c`
- Manifest SHA-256:
  `e4c25b4dfc14067822b9d918eddab6f4856e370cac195d17a4317a1fd6c23013`
- Forecast-Ergebnis: `ready_to_apply=true`, beide Operationen ohne Mismatch,
  `mutated=false`.
- Karten- **und** `.mq5`-Hashes werden durch Forecast und Apply verifiziert;
  die `source_diagnostic`-Felder sind keine bloße Dokumentation.

Forecast-Kommando:

```powershell
python tools/strategy_farm/reconcile_blocked_build_tasks.py forecast `
  --manifest docs/ops/evidence/2026-07-29_mnt012_build_zombie_reconciliation_manifest.json `
  --db D:\QM\strategy_farm\state\farm_state.sqlite `
  --factory-off-flag D:\QM\strategy_farm\state\FACTORY_OFF.flag
```

Das Werkzeug öffnet die DB im Forecast ausschließlich mit `mode=ro` und
`PRAGMA query_only=ON`.

## Root-Apply — ausgeführt

Unmittelbar vor Apply meldete der erneut ausgeführte Forecast
`ready_to_apply=true`. Danach wurde das folgende gebundene Kommando ausgeführt:

```powershell
python tools/strategy_farm/reconcile_blocked_build_tasks.py apply `
  --manifest docs/ops/evidence/2026-07-29_mnt012_build_zombie_reconciliation_manifest.json `
  --db D:\QM\strategy_farm\state\farm_state.sqlite `
  --factory-off-flag D:\QM\strategy_farm\state\FACTORY_OFF.flag `
  --expected-manifest-sha256 e4c25b4dfc14067822b9d918eddab6f4856e370cac195d17a4317a1fd6c23013 `
  --confirm-run-id MNT012-20260729-BLOCKED-BUILD-ZOMBIES-01 `
  --snapshot D:\QM\strategy_farm\state\snapshots\farm_state_mnt012_pre_20260729T113000Z.sqlite
```

Ergebnis: beide Tasks stehen auf `blocked`; Ledger-Sequenzen `1` und `2`.
Snapshot SHA-256:
`87a141d9e7c051570c653ec795bd1612b6bc5589d50e740ff58868f933d445ba`.
Der logische SQLite-State wechselte von
`b147327029c27ec8f3f3fafcc8d661d4fcb6ecb9fe0e440aa1d8d0ebb941382b`
auf `96ccc557ce8beb3e96f0b6507a79c92871613c06eaf673bd3ae4e39bfff910a6`.
Ein zweiter identischer Apply endete als `apply_idempotent_noop`, ohne zweites
Event oder Taskmutation. Das vollständige maschinenlesbare Receipt liegt in
`docs/ops/evidence/2026-07-29_mnt012_build_zombie_reconciliation_apply.json`.

## Tests

Ausgeführt:

```text
python -m pytest -q
  tools/strategy_farm/tests/test_mnt012_build_guards.py
  tools/strategy_farm/tests/test_mnt012_reconciliation.py
  tools/strategy_farm/tests/test_auto_build_routing.py
  tools/strategy_farm/tests/test_factory_off_build_interlock.py
  tools/strategy_farm/tests/test_levelup_cohort0.py
  tools/strategy_farm/tests/test_basket_work_items.py

69 passed, 12 subtests passed
```

Zusätzlich: `python -m py_compile` für `farmctl.py` und das
Reconciliation-Werkzeug sowie `git diff --check` für alle MNT-012-Quellen.

## Sicherheitsgrenzen

- Factory blieb absichtlich OFF und wurde nicht geschaltet.
- Ausschließlich die zwei manifestgebundenen Tasktransitionen, zwei Events und
  zwei append-only Ledgerzeilen wurden geschrieben.
- Keine Karte unter `D:\QM` geändert.
- Keine EA-Source, kein Registry-Eintrag und kein Work-Item geändert.
- T_Live, MT5 und AutoTrading nicht berührt.
- MNT-012 bleibt auch nach der Taskkorrektur bis zum separaten OWNER-/Research-
  Card-Fix PARTIAL: Beide Runtime-Karten sind weiterhin byte-identisch und
  tragen noch Frontmatter `R3=PASS` bei Body `R3=UNKNOWN`.
