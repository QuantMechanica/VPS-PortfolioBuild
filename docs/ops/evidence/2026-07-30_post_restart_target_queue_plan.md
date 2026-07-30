# Post-Restart Target-Queue-Plan — source-only

**Erstellt:** 2026-07-30 13:41:56Z

**Source:** `0dead3ff978b2c7b9790c4e6988c39e9a8fece46`

**Runtime execution:** `NONE`

**Factory_ON authorization:** `false`
**Book-ready claim:** `false`

Die maschinenlesbare Fassung ist
[`2026-07-30_post_restart_target_queue_plan.json`](./2026-07-30_post_restart_target_queue_plan.json).
Dieser Plan beschreibt ausschließlich eine bedingte Reihenfolge nach einem separat
autorisierten und nachweislich stabilen Factory-Start. Er schaltet die Factory nicht ein,
ändert keine DB und gibt weder ein FTMO-Buch noch eine bezahlte Challenge frei.

## 1. Drei strikt getrennte Spuren

1. **FTMO-Target-Spur:** Im gebundenen Snapshot existiert kein aktuelles pending
   FTMO-Target. Erster Canary ist genau ein identity-preserving Infra-Retry von
   `QM5_20039 / NDX.DWX / Q06`.
2. **Normale Factory-Queue:** bleibt unverändert und unabhängig. Der rohe Selector hatte
   2.175 eligible Rows; darin sind die drei noch unheld 20181-Cascade-Rows enthalten.
   Der zulässige driftfreie Pfad ist `2.175 -> 2.172` nach deren verpflichtendem Hold
   und danach voraussichtlich `2.179` bei Freigabe exakt der sieben Restart-Holds.
   `2.182` war nur die unzulässige Vergleichssimulation „sieben freigeben, ohne vorher
   die drei Cascades zu halten“ und ist kein geplanter Post-ON-Stand. Ressourcen-,
   History-, Symbol- und Multisymbol-Regeln bestimmen die wirkliche Claim-Reihenfolge;
   diese Queue ist kein FTMO-Target-Nachweis.
3. **DXZ-Requalifikation:** bleibt ebenfalls separat. Der aktuelle Prioritätskopf ist
   `QM5_11422`, danach `QM5_11421`. Der weitere Tail darf nur aus einem aktuellen,
   versiegelten DXZ-Receipt/Ledger stammen; fehlt er, wird gestoppt statt aus FTMO- oder
   Factory-Reihenfolgen geraten. `QM5_11422` fehlen weiterhin Q09_NEWS und eine
   admissionsfähige Q08-v3-Lineage.

Snapshot-Bindung: produktive DB SHA-256
`98286548cc6bd2745c842d4eb6c6d8bd71d6cbc5010574989361afbb3f134394`,
LastWrite `2026-07-30T13:14:02.7017523Z`. Jede spätere Aktion muss den dann aktuellen
Zustand neu lesen und in einem eigenen Receipt binden.

## 2. Einziger erster FTMO-Canary

| Feld | Vertrag |
|---|---|
| EA / Symbol / Phase | `QM5_20039 / NDX.DWX / Q06` |
| bestehende Work-Item-ID | `4381a4bc-a8bd-4e58-862f-83dd05cda5ce` |
| Aktion | exakt ein identity-preserving Infra-Retry; keine neue Parallel-ID |
| Parent | Q05 PASS `2a3c9631-88a8-4b93-86b5-d1d841b1ff37` |
| Terminal | T6 bevorzugen; T4 nicht verwenden; ist T6 nicht bereit: Stop/Replan |
| Ressourcen | 8 GiB, Timeout 120 min, erwartet ca. 13–20 min; früher 17,9 min |
| PASS | PF `> 1.0`, DD `<= 25%`, Trades `>= 20`, vollständige Identity-/History-/Report-Evidence |

Die bestehende PASS-Lineage bleibt exakt erhalten: Q02
`4a5a1dbd-938e-49f7-b3dc-6d65e7923105`, Q03
`45634cb7-de3d-4fce-be2c-1935a0e15b0a`, Q04
`9ebe99ec-b150-4efa-8fa6-3caa83f5f9d0`, Q05
`2a3c9631-88a8-4b93-86b5-d1d841b1ff37`.

Die Retry-Identity bindet:

- EX5 `05a6bb8a2417db92c9400e17aacdfc4ec8687c7e0809f11277db1734bafe77b1`
- MQ5 `99958c1a93e26abb3617136bbf10d767cef997c21310f8510abbfa8a1e08ad50`
- Set `319eacdd42002033928ff66a32340b4da4c0dc0a92cfeed033c37eb38be1e8ca`

Für diese Werte gilt `hash_scope: CANONICAL_PHYSICAL_BYTES_AT_SNAPSHOT`: Es sind
Raw-Byte-Hashes des kanonischen Runtime-Roots `C:\QM\repo`. Der isolierte Plan-Worktree
ist Git-inhaltlich gleich, checkt die MQ5-Datei
aber mit anderer EOL-Darstellung aus (Raw-SHA
`f688281e24cbb1f1b0cd1f2eb899caf66995a81ff303af467cd8601f7dc7fbc4`). Ein späteres
Retry-Receipt muss daher die dann tatsächlich verwendeten kanonischen Raw-Bytes erneut
binden und darf Checkout-Hashes nicht still austauschen.

Der vorhandene Q06-Befund ist `INFRA_FAIL` mit
`invalid_summary:BARS_ZERO,EMPTY_EXPERT,EMPTY_SYMBOL,HISTORY_CONTEXT_INVALID,INCOMPLETE_RUNS,M0_1970_PERIOD,NO_HISTORY,RUN_STATUS_INVALID`.
Kommt dieselbe Infra-Signatur wieder, endet die Spur zur Diagnose; kein dritter Versuch.
Ein Strategie-`FAIL` beendet sie ebenfalls. Bei Hash-, Parent-, Terminal- oder
History-Abweichung wird der Retry verweigert.

Erst ein receiptiertes Q06-PASS darf den Pump Q07 erzeugen lassen. Q07/Q08/Q09/Q10-IDs
existieren für diese Target-Spur derzeit nicht und dürfen ausschließlich aus späteren
Apply-/Pump-Receipts übernommen werden — niemals vorab erfunden.

## 3. Folgegates

- **Q07:** Seeds `42,17,99,7,2026`; je mindestens 20 Trades; kein Seed PF `< 1.0`;
  Varianz `<20%` oder `<40%` bei Minimum-PF `>=1.10`. 8 GiB, typisch etwa 56 min,
  beobachteter Cap 120 min.
- **Q08:** Nur `PASS` erfüllt die strikte FTMO-Kette. `FAIL_HARD` stoppt; `INVALID`
  erlaubt nur Setup-Reparatur. `FAIL_SOFT` darf Research-gewichtbar bleiben, ist aber
  keine strikte FTMO-Admission und wird nicht force-promoted. 8 GiB, Timeout 368 min;
  Kohortenmedian etwa 39 min, P75 etwa 65 min.
- **Zeitbudget:** durch Q08 grob 1,5–3 Stunden, begrenzt durch die konfigurierten
  Phasen-Timeouts.

Q09_NEWS bleibt wegen MNT-050 runtime-deferred. Vor Ausführung braucht es einen
SHA-gebundenen `CONFIG_LOCKED`-Plan mit exakt 40 MT5-Zellen: fünf
`CONTROL_OFF/OFF/NONE`-Zellen und 35 `POLICY_ON/FTMO`-Zellen aus fünf Seeds mal sieben
Modi (`OFF`, `PRE30`, `PRE60`, `PRE30_POST30`, `PRE60_POST60`, `SKIP_DAY`,
`CLOSE_ALL_PRE`). Gebunden werden mindestens Q08-Evidence, EX5, Set, Include-Closure,
Kalender-Manifest plus Common-Copy, vollständige Full-/Selection-/Holdout-Fenster,
Tester-Modell, Kostenprofil und Output-Root. Q10 braucht authentifiziertes Q09_NEWS
plus Q09_PORTFOLIO und besteht nur mit PF `>1`, DD `<=25%`, mindestens 20 Trades und
exakter Chosen-Mode-/Hash-Bindung.

## 4. Holds bleiben Holds

| Scope | Work-Item-ID | Snapshot | Erforderlich |
|---|---|---|---|
| Book3 V2 R2 / `QM5_13108 Q02` | `034a2bcd-1a69-5437-9654-6e4b3e9b0ff9` | active hold | held, `release_on_restart=false` |
| Book3 V2 J2 / `QM5_20181 Q02` | `e98e8b96-2e92-59a2-aa8e-15f4140c1289` | active hold | held, `release_on_restart=false` |
| 20181 Cascade Q03 | `f8a90af2-a21e-40a0-883d-8d4446831b62` | noch kein active hold | active hold vor Factory_ON, `release_on_restart=false` |
| 20181 Cascade Q03 | `50ada76a-321d-4749-a4ec-c3ad424bc9e6` | noch kein active hold | active hold vor Factory_ON, `release_on_restart=false` |
| 20181 Cascade Q04 | `9ca73d45-b0b3-4074-b9ed-b773b22858d1` | noch kein active hold | active hold vor Factory_ON, `release_on_restart=false` |

Grundlage sind der
[`Stage-1-SETUP_BLOCKED-Closeout`](./2026-07-30_ftmo_book3_v2_stage1_setup_blocked.md)
(Receipt-SHA `b3fa3b23f973e22925bab1a6c035bcbddefee3faf84021eec3d50c2a06e3bc43`)
und das
[`20181-Cascade-Hold-Manifest`](./2026-07-30_qm5_20181_cascade_hold_manifest.json)
(kanonische Raw-Byte-SHA; `hash_scope: CANONICAL_PHYSICAL_BYTES_AT_SNAPSHOT`
`3d9170a2a8dd9264211a66e530ff79bd811fb54481624e4a517b248a3ae3e3f0`). Der isolierte
CRLF-Checkout derselben Git-Inhalte hat Raw-SHA
`b7eecb4a469fc77ff6dd0b014ad2013c1d590c9e25c641fc72abe374fb0c9783`.
Dieser Plan autorisiert auch dieses Manifest nicht. Alle übrigen FTMO-Holds bleiben
unverändert non-releasing. Damit ist der Hold-Gate im Snapshot noch
`BLOCKED_UNTIL_THREE_CASCADE_HOLDS_HAVE_A_SEPARATELY_AUTHORIZED_APPLY_RECEIPT`.

## 5. Kein Gate-Bypass für 13036 oder 12969

- `QM5_13036 / GDAXI.DWX`: kein manuelles Q03. Die jüngste Q02-ID
  `8bac496f-128f-4cea-a2bc-2465b00581ce` hatte zwar 647 Trades und 7,82% DD, aber PF
  0,92 und Net Profit `-4600.96`. Der Promoter verlangt positiven Net Profit und hat
  Q03 korrekt nicht erzeugt. Späteres positives Full-Horizon-Q08 heilt dieses
  Selection-Problem nicht; Status bleibt Research/Shadow bis zu prospektiver,
  versiegelter Evidence.
- `QM5_12969 / USDJPY.DWX`: halten bis zur aktivierten target-aware Q08-v3-Admission.
  Q08 `74a089c5-194d-466f-ba0f-0536fdf32641` ist `FAIL_SOFT` wegen nur zehn
  profitabler Monate und PBO `42.857% > 40%`; außerdem stammt Q02–Q07 aus einer älteren
  EX5-Identity. Kein deterministischer Sofort-Rerun und keine parallele Neuqueue aller
  Phasen; später seriell unter dem neuen Target-Vertrag.

## 6. FTMO-Money-Gate

`book_ready_claim` bleibt `false`, bis mindestens alle folgenden Punkte erfüllt sind:
offizieller Regel-Snapshot höchstens sieben Tage alt; null ungeklärte
Execution-Fidelity-Mismatches; event-/tick-kompletter MTM-Pfad mit Prague-Ankern,
Pending Orders, Margin, Kosten und Swap; Phase-1-Schätzer `>=80%` und untere
95%-Grenze `>=70%`; obere 95%-Grenze für offiziellen Breach `<=10%`; bedingte
Phase-2-Chance `>=85%` und gemeinsame Zwei-Phasen-Chance `>=65%`; mindestens ein
Exact-Profile-Free-Trial/Shadow ohne Operationsfehler. Eine bezahlte Challenge braucht
danach nochmals eine separate OWNER-Signatur.

Geschlossene-PnL-Proxies, Hold-Freigaben, DB-Mutationen, Factory_ON, Deployment,
AutoTrading und Challenge-Kauf sind ausdrücklich nicht Gegenstand dieses Plans.
