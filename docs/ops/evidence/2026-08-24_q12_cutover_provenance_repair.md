# Q12-Cutover-Provenienzreparatur — 2026-08-24

**Autorität:** `OWNER-DEC-Q12-PROVENANCE-REPAIR-20260824` in
`decisions/2026-08-24_owner_q12_provenance_and_mission_control.md`  
**Werkzeug:** `tools/strategy_farm/repair_q12_cutover_provenance.py`  
**Betriebsgrenze:** keine Factory-/Terminal-/Deploy-/T_Live-/AutoTrading-Aktion

## Befund

Der v4-Aktivator änderte bei genau drei offenen, bereits payload-gebundenen
v3/Q14-Zeilen nur `work_items.phase` und `gate_contract_version` auf v4/Q12.
Die Payloads blieben korrekt und bytegleich v3/Q14. Damit widersprachen die
DB-Spalten der unveränderlichen Payload-Provenienz; Artefakt-Hashes fehlten
nicht.

| alte Work-Item-ID | EA / Symbol | Payload-SHA-256 | neue v4/Q12-ID |
|---|---|---|---|
| `48183f09-ad48-5c42-b1b6-9e7787b5ac32` | `QM5_10706 / GBPUSD.DWX` | `d0e5dc434008a684ec646a97b8273cfd62a6e4016abde3933ec7b6bd80e18974` | `48c41285-5849-534d-aeac-836deb9a9cb8` |
| `8eda68d9-aae3-509c-a0cc-6e738e1bde99` | `QM5_11421 / EURUSD.DWX` | `0d28f213ab716a1a57e9e71be7a22b5e38f52cae1bca9bfe31bfccb30e03b48a` | `2a2bf134-9832-51f4-96bd-e2116b8fa1dc` |
| `9975987c-d408-5724-8863-f4e49a214d4b` | `QM5_11422 / USDCAD.DWX` | `aeee5e4488e2679b7d0158bbae2bc7cc3aa47488906a84544e0875203fa7b996` | `09c21c5c-1119-52e7-ac02-8cb3ead754c6` |

## Reparaturvertrag

- Alte Payload-Bytes bleiben unverändert.
- Alte Zeilen werden auf v3/Q14 zurückgestellt und als
  `failed / INFRA_FAIL / infra` mit diesem Evidenzpfad abgeschlossen.
- Neue v4/Q12-Zeilen werden append-only erzeugt. Sie binden aktiven
  Manifest-Hash, alte Work-Item-ID, alten Payload-Hash und Cutover-Ledger-Zeit.
- `gate_contract_provenance_repairs` hält die 1:1-Zuordnung append-only.
- Neue DB-Trigger machen `phase` ebenso unveränderlich wie
  `gate_contract_version` und lehnen Spalten/Payload-Widersprüche beim Insert
  oder Update ab.
- Der historische v4-Aktivator blockiert künftig payload-gebundene Relabels mit
  `bound payload provenance requires append-only remint`.

## Dry-run vor Integration

Live-DB read-only, 2026-08-24:

```text
state=READY
target_count=3
payload_provenance_mismatches=3
dependencies=0 je Ziel
active_holds=0 je Ziel
plan_sha256=ee826c21b81045f75bba5d69454d4260b32f2f63611788732cfa44494e706422
```

## Apply und Verifikation

Noch ausstehend. Dieser Abschnitt wird nach Integration und atomarem Apply mit
Receipt-Pfad, finalem Plan-Hash, alten/neuen Zuständen und globalem
Mismatch-Census ergänzt.

