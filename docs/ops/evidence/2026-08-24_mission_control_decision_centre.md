# Mission Control Decision Centre + kompakte Frontier — 2026-08-24

**Autorität:** `OWNER-DEC-MISSION-CONTROL-DECISION-CENTRE-20260824` in
`decisions/2026-08-24_owner_q12_provenance_and_mission_control.md`  
**Betriebsgrenze:** Dokumentation ja; Factory-/Deploy-/T_Live-/AutoTrading-
Ausführung nein.

## Ergebnisvertrag

- `owner_decisions.json` wird von Legacy-Schema 1 auf
  `qm.owner-decisions/v2` migriert. Die 28 historischen, großteils bereits
  entschiedenen Feed-Zeilen bleiben als bytegleiche Archivdatei erhalten.
- Der aktuelle Feed startet mit sechs echten Entscheidungen: A1-Zähleinheit,
  A2-Optimierungspflicht, Backfill-Tranche 1, Risk-Freeze-Baseline,
  Q12-Admission und vertagte MQL5-Kandidatenwahl.
- Jede Entscheidung enthält stabile ID, Status, genaue Frage, Empfehlung,
  JA-/NEIN-Folge, Cost-of-Wait, Kontext und Evidenz.
- Mission Control zeigt alle `OPEN`/`DEFERRED`-Items ohne 5er-Cap und bietet
  `JA`, `NEIN`, `VERTAGT` plus OWNER-Notiz.
- Der Intake bindet nur `127.0.0.1:8765`, akzeptiert nur Origin `null`
  (`file://`) und einen lokalen 256-bit Token. Er schreibt zuerst ein
  append-only JSONL-Receipt, danach Feed und Vault.
- Jedes Receipt enthält `execution_authorized=false` und
  `execution_boundary=DOCUMENT_ONLY`. Ein Klick startet keinen weiteren Job.
- Terminale Antworten verschwinden aus der offenen Queue; `VERTAGT` bleibt mit
  Receipt und Notiz wiedervorlegbar. Der Vault enthält den generierten offenen
  Spiegel und ein Tagesarchiv der Antworten.

## Frontier

Der vollständige Live-Census umfasst beim Dry-run **14.639** EA/Symbol-Paare.
Mission Control berechnet weiterhin alle Aggregate aus dem Vollbestand, rendert
im letzten Top-Level-Block aber nur maximal 30 handlungsnahe Paare und hält die
Detailtabelle geschlossen. `linear_frontier.html` enthält den vollständigen,
such- und nach Aktion filterbaren Drill-down. Der getestete Haupt-HTML-Umfang
sank auf rund 72 KB statt mehrerer MB.

## Verifikation vor Integration

```text
pytest selected: 61 passed, 1 skipped
live contract with v2 seed: pair_count=14639
main frontier preview_count=30
pair_detail_truncated=true
frontier_is_last=true
frontier_details_open=false
bootstrap state=READY
legacy_feed_items=28
new_feed_items=6
bootstrap_plan_sha256=e636187bd0ee24eeb3abf61b8da9dddb0f30fbb6364926e9112e58e8e4aeffc4
```

## Live-Migration / Service / Render

Kanonischer Commit: `d30c82bbb` auf `agents/board-advisor`.

```text
bootstrap_plan_sha256=627646e18dd5c412158d89e4a2a88f2a95ca04b73d9184e80afd5b74e8d4c5b1
bootstrap_applied=true
feed_schema=qm.owner-decisions/v2
feed_revision=1
feed_statuses=OPEN:5,DEFERRED:1
```

Bytegleiche Backups vor der Migration:

- `D:/QM/reports/state/archive/owner_decisions_v1_pre_v2_20260824.json`
- `G:/My Drive/QuantMechanica - Company Reference/12 ToDo/AI ToDos/Archive/OWNER pre Mission Control 2026-08-24.md`
- `G:/My Drive/QuantMechanica - Company Reference/12 ToDo/AI ToDos/Archive/_INDEX pre Mission Control 2026-08-24.md`

Der Task-Scheduler-Start mit InteractiveToken wurde vom bekannten Hostvertrag
`0x800710E0` verweigert und der ausschließlich für diesen Versuch neu angelegte
Task wieder entfernt. Der finale, zum gemounteten G:-Vault passende
Sitzungsvertrag ist:

```text
HKCU\Software\Microsoft\Windows\CurrentVersion\Run\QMOwnerDecisionIntake
  = "C:\Python311\pythonw.exe" "C:\QM\repo\tools\strategy_farm\owner_decision_service.py"
current_process_pid=1664
listener=127.0.0.1:8765
health.ok=true
health.mode=DOCUMENT_ONLY
health.open_count=6
health.revision=1
CORS file-origin preflight=204, Allow-Origin:null
```

Der bestehende 2-Minuten-Cockpit-Renderer ruft `render_cockpit_v2.main()` nach
dem Advanced-Render auf; kein zweiter Dashboard-Task wurde angelegt.

Live-Artefakte nach dem expliziten Render:

```text
cockpit_v2.html=67,366 bytes (latest scheduled render)
cockpit.html SHA == cockpit_v2.html SHA
owner_cards=6
max_5_text=false
intake_token_embedded_matches_state=true
linear_frontier_summary="30 handlungsnahe Frontiers · Vollbestand 14639 im Drill-down"
linear_frontier_is_last_section=true
linear_frontier_details_open=false
linear_frontier.html=4,233,516 bytes
linear_frontier_full_rows=14,639
linear_frontier_search=true
```

Vault-Verifikation: generierte Queue-Marker vorhanden, 6 IDs, kein `max 5`,
Index trägt `ohne Cap`; Company-Reference-Linter **PASS**. Es wurde keine echte
OWNER-Antwort simuliert oder vorweggenommen. Der End-to-End-POST-Vertrag wurde
gegen temporäre Feed-/Receipt-/Vault-Fixtures getestet; die Live-Prüfung blieb
read-only (`GET /health`, CORS-Preflight).

Kanonischer Abnahmelauf nach Cherry-pick: **61 passed, 1 skipped** in 8,16 s.
