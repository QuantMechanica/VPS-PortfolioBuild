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

Noch ausstehend. Nach kanonischer Integration werden hier Backup-Pfade,
Receipt-Service-Health, Scheduled-Task-Vertrag, Dashboard-Größen und
Vault-Linter-Ergebnis ergänzt.

