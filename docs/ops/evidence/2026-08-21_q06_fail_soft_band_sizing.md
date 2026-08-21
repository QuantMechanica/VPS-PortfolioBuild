# Q06 PASS_SOFT band sizing — read-only measurement

**Date:** 2026-08-21
**Auftrag:** READ-ONLY Messauftrag, Fail-Soft Option A (OWNER-genehmigt 2026-08-21).
Sizing-Query der OWNER-Vorlage `docs/ops/Q05_Q06_FAIL_SOFT_VORLAGE_2026-08-21.md`,
Option A Schritt 1. Ziel: Größe des `PASS_SOFT`-Kandidatenbands bei Q06 messen —
Anteil historischer Q06-FAILs mit Post-Stress-PF in **[0.95, 1.00)**.
Aktivierungsschwelle: Band **≥ 2 %** der Q06-FAILs.
**Klassifizierung:** GRÜN (read-only). Kein DB-Write, keine Factory-Interaktion,
kein git commit. Einzige Schreibaktion = diese Evidenzdatei.

---

## 1. Phase-Key-Mapping (Storage ↔ Operator-Gate)

Quelle: `tools/strategy_farm/phase_ids.py` + `PRAGMA`/`GROUP BY phase` auf der Live-DB.

| Operator-Gate | Storage-Key (`work_items.phase`) | Legacy-P-Key |
|---|---|---|
| **Q06 Stress HARSH** | `Q06` | **keiner** — Q06 ist ein durch den 2026-05-23-Rewrite neu eingeführtes Gate und hat bewusst keinen erfundenen Legacy-P-Alias (phase_ids.py Z. 20, 82). Storage ist end-to-end Qxx. |
| **Q05 Stress MEDIUM** | `Q05` | Legacy-Alias `P5` (nur Rückwärts-Shim; neuer Code emittiert `Q05`). |

DB-weite `phase`-Verteilung bestätigt: `Q06` = 508 Rows, `Q05` = 1075 Rows. Es
existieren keine `P5`/`P6`-Rows für diese Gates (nur ein Alt-Rest `P2`=446 an anderer
Stelle). Für beide Gates ist der Storage-Key identisch mit dem Operator-Label.

## 2. Verdikt-Logik & reason-String-Formate (Code-Kanon)

`framework/scripts/q06_stress_harsh.py` (Z. 180–205) — Prüfreihenfolge (elif-Kaskade):

```
summary/report fehlt        -> INVALID  timeout_expired | summary_missing
invalid_summary             -> INVALID  invalid_summary:<CLASSES>
stress-input nicht lesbar   -> INVALID  stress_input_evidence_missing:...
stress-input != 0.10        -> INVALID  stress_input_not_effective:expected=0.1000:observed=...
trades < 20                 -> FAIL     trades_below_floor:trades={n}:floor=20
pf is None                  -> FAIL     missing_pf_in_summary:trades={n}
dd_money is None            -> FAIL     missing_dd_in_summary:trades={n}
pf <= 1.0                   -> FAIL     pf_below_floor:pf={pf:.3f}:floor=1.0      <-- Band lebt HIER
dd_pct > 25.0               -> FAIL     dd_above_ceiling:dd_pct={dd:.2f}:max=25.0
sonst                       -> PASS     pf={pf:.3f}:dd_pct={dd:.2f}:stress=HARSH
```

**Zentrale Konsequenz für die Band-Definition:** Der `pf`-Floor-Check (`pf <= 1.0`)
steht VOR dem `dd`-Check. Damit gilt:
- Jeder FAIL mit PF in [0.95, 1.00) ist zwangsläufig ein `pf_below_floor`-Row — und
  alle diese reason-Strings tragen `pf=`. → **Das Band ist vollständig aus `pf=`
  parsebar; keine Band-Mitglieder verstecken sich in PF-losen reason-Strings.**
- `dd_above_ceiling`-FAILs haben strukturell PF > 1.0 (den PF-Floor bereits bestanden)
  → können NIE im Band liegen, obwohl ihr reason-String kein `pf=` trägt.
- `trades_below_floor`-FAILs haben < 20 Trades → erreichen den PF-Check gar nicht
  → können nie im Band liegen.

reason-Extraktion: `pf=([0-9]+\.?[0-9]*)` auf `payload_json → verdict_reason`.

## 3. Datenquelle & Methode (strikt read-only)

```python
sqlite3.connect('file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro', uri=True)
```

Tabelle `work_items`. reason-String liegt NICHT in der `verdict`-Spalte (die hält nur das
Verdikt-Token wie `FAIL`/`INFRA_FAIL`), sondern in `payload_json` unter Schlüssel
**`verdict_reason`**. DD/Trades für die Feinabstufung stammen aus der Evidenz-
`aggregate.json` (Pfad in Spalte `evidence_path`).

Kern-Query:
```sql
SELECT id, ea_id, symbol, verdict, evidence_path, payload_json
FROM work_items WHERE phase='Q06';
```
PF je FAIL: `re.search(r'pf=([0-9]+\.?[0-9]*)', json.loads(payload_json)['verdict_reason'])`.
Band = `0.95 <= pf < 1.00`.

## 4. Kennzahlen Q06

**Verdikt-Verteilung (`phase='Q06'`, 508 Rows total):**

| Verdict | Rows |
|---|---|
| PASS | 416 |
| **FAIL (Strategie)** | **62** |
| INFRA_FAIL (INVALID-Klasse) | 28 |
| PENDING_RUNNER | 1 |
| (null) | 1 |

Denominator für das 2 %-Kriterium = **Strategie-FAILs (62)**. INFRA_FAIL (28) sind
INVALID-Klasse (summary_missing / invalid_summary / ACTIVE_TIMEOUT / stress-input) ohne
messbaren PF und gehören nicht in eine PF-Band-Statistik.

**(a) Q06-FAILs gesamt:** 62 Rows (46 distinkte (ea_id, symbol)-Paare).

**(b) davon mit parsebarem PF:** 39 (= genau die `pf_below_floor`-Rows). 23 ohne PF.

**(c) Band 0.95 ≤ PF < 1.00:**

| Bezugsgröße | Zähler | Nenner | Anteil |
|---|---|---|---|
| Band / FAIL-Rows | 25 | 62 | **40.3 %** |
| Band / FAIL-Rows (distinkte Paare) | 23 | 46 | 50.0 % |
| Band / `pf_below_floor` | 25 | 39 | 64.1 % |
| Band / (FAIL + INFRA_FAIL) [konservativster Nenner] | 25 | 90 | 27.8 % |

**(d) Aufteilung der FAIL-Gründe (62 Strategie-FAILs):**

| reason-Token | Rows | PF-parsebar? |
|---|---|---|
| `pf_below_floor` | 39 | ja (alle) |
| `dd_above_ceiling` | 15 | nein (strukturell PF > 1.0) |
| `trades_below_floor` | 7 | nein (< 20 Trades) |
| `stress_input_not_effective` | 1 | nein (INVALID-Klasse, als FAIL gespeichert) |

PF-Histogramm der `pf_below_floor`-FAILs (0.01-Buckets):
`0.75:1, 0.85:1, 0.86:1, 0.89:1, 0.91:1, 0.94:1, 0.96:5, 0.97:4, 0.98:5, 0.99:11, 1.00:8`.
(Die 8 Rows bei PF=1.000 fallen als `pf <= 1.0` durch, liegen aber korrekt AUSSERHALB
des Bands `< 1.00`.)

**(e) Einordnung Q05 (`phase='Q05'`, Kontext — Vorlage sieht für Q05 KEINE Änderung vor):**

| Kennzahl | Wert |
|---|---|
| Total Rows | 1075 |
| PASS / FAIL / INFRA_FAIL / FAIL_DD_PORTFOLIO_REVIEW / null | 446 / 416 / 177 / 31 / 5 |
| FAIL-Rows (distinkte Paare) | 416 (300) |
| FAIL-Gründe | `pf_below_floor` 281, `dd_above_ceiling` 94, `trades_below_floor` 40, `missing_pf_or_dd` 1 |
| PF-parsebar / unparsebar | 281 / 135 |
| Band 0.95 ≤ PF < 1.00 | 91 Rows (74 Paare) = **21.9 %** der FAILs (32.4 % der `pf_below_floor`) |

Das Band ist also kein Q06-Artefakt — es ist ein stabiles gate-übergreifendes Phänomen
(marginale FAILs häufen sich direkt unter PF=1.0).

## 5. Feinabstufung: echte PASS_SOFT-eligible Teilmenge (DD-Guard)

Die Vorlage definiert `PASS_SOFT` als PF ∈ [0.95,1.00) **UND** DD < 25 % **UND** ≥ 20
Trades. Weil `pf_below_floor` VOR dem DD-Check feuert, ist die DD der 25 Band-Rows
ungeprüft. Aus der Evidenz-`aggregate.json` je Band-Row nachgezogen:

| Kategorie | Rows |
|---|---|
| **PASS_SOFT-eligible** (DD < 25 % & Trades ≥ 20 & PF im Band) | **19** |
| Band, aber DD ≥ 25 % → bleibt terminal FAIL | 3 (10467/XAU 29.4 %, 10567/XAU 25.5 %, 9639/USDJPY 28.6 %) |
| DD unbekannt (aggregate.json gepurged/requeued) | 3 |

Alle 25 Band-Rows haben Trades ≥ 20 (Struktur-Garantie: PF-Check erst nach Trades-Floor).
Die echte Lieferausbeute der Regel ist also **19/62 = 30.6 %** der Q06-FAILs (untere
Schranke; die 3 DD-unbekannten könnten auf bis zu 22/62 = 35.5 % anheben). Der rohe
PF-Band-Zähler (25) überschätzt die tatsächlich weiterleitbare Kohorte um ~24 %.

## 6. Parsing-Lücken (vollständige Auflösung)

23 der 62 Q06-FAILs haben keinen extrahierbaren PF. Aufschlüsselung und Beweis, dass
**keine** davon ein verstecktes Band-Mitglied sein kann:

- **15 `dd_above_ceiling`** — reason-String trägt per Design kein `pf=`, ABER die
  elif-Ordnung garantiert PF > 1.0 (PF-Floor bereits bestanden). Strukturell außerhalb
  des Bands. (Nebenbefund: diese Rows tragen `max=15.0` → sie wurden unter der ALTEN
  15 %-DD-Decke adjudiziert, vor der Anhebung auf 25 % am 2026-07-15. Historische
  Kohorte, orthogonal zum PF-Band; PF_FLOOR=1.0 war durchgehend konstant.)
- **7 `trades_below_floor`** (jeweils trades=0) — erreichen den PF-Check nie; < 20
  Trades scheitern am harten Frequenz-Floor unabhängig vom Softpfad.
- **1 `stress_input_not_effective`** — eigentlich INVALID-Klasse (Runner emittiert
  hierfür `INVALID`), in dieser Row als `FAIL` gespeichert (Taxonomie-Nebenrauschen,
  1 Row, nicht band-relevant); kein PF.

**Fazit Parsing:** Die Parsing-Lücke verdeckt NULL Band-Mitglieder. Der Band-Zähler
**25 ist exakt**, keine untere Schranke. (INFRA_FAIL-Rows sind separat und tragen
teils leere/`invalid_summary`-reasons — korrekt aus dem PF-Nenner ausgeschlossen.)

## 7. Urteil zum 2 %-Kriterium

> **Band ≥ 2 %: JA — deutlich.**

- Rohes PF-Band: **40.3 %** der Q06-FAILs (25/62) — das **~20-fache** der 2 %-Schwelle.
- Konservativster Nenner (FAIL+INFRA_FAIL): 27.8 % (25/90) — immer noch ~14×.
- Echte PASS_SOFT-eligible Kohorte (inkl. DD<25 %-Guard): **30.6 %** (19/62) — ~15×.

Unter jeder vertretbaren Nenner-Wahl liegt das Band um mehr als eine Größenordnung über
der Aktivierungsschwelle. Das Kriterium ist erfüllt.

## 8. Empfehlung

**T10-`PASS_SOFT` aktivieren: JA** (Option A Schritt 2 der Vorlage freigeschaltet).
Die Regel würde eine reale, requeue-fähige Kohorte von **19 gesicherten (EA, Symbol)-
Paaren** (plus bis zu 3 DD-unbekannte) rückwirkend aus terminalem Q06-FAIL nach Q07
mit Flag `probation:q06_soft` heben — über XAUUSD, SP500, USDJPY, XAGUSD, XTIUSD, GDAXI,
EURJPY u. a. verteilt, also keine Ein-Symbol-Degeneration.

Umsetzungs-Caveats für Schritt 2 (nicht Teil dieses read-only-Auftrags — ROT, braucht
OWNER-Freigabe für die Gate-Kriterien-Änderung):
1. Der Q06-Runner muss die `PASS_SOFT`-Emission **nach** dem DD-Check platzieren
   (aktuell exit'et `pf_below_floor` vor dem DD-Check) — sonst würden die 3 DD ≥ 25 %-
   Rows fälschlich als PASS_SOFT durchrutschen. DD < 25 % bleibt hart.
2. Anti-Stacking (`q06_soft` + Q08 `EDGE_SOFT` = terminal) wie in der Vorlage §Anti-
   Stacking.
3. Diese Messung ist eine reine Kohorten-Größenschätzung; sie präjudiziert nicht, ob die
   19 Paare Q07/Q08 überstehen — die eigentlichen Richter bleiben unverändert.

## 9. Reproduktions-Queries

```python
import sqlite3, json, re
con = sqlite3.connect('file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro', uri=True)
cur = con.cursor()
pf_re = re.compile(r'pf=([0-9]+\.?[0-9]*)')
cur.execute("SELECT verdict, payload_json FROM work_items WHERE phase='Q06'")
band = fails = 0
for verdict, pj in cur.fetchall():
    if verdict != 'FAIL':
        continue
    fails += 1
    reason = json.loads(pj).get('verdict_reason') if pj else None
    m = pf_re.search(reason or '')
    if m and 0.95 <= float(m.group(1)) < 1.00:
        band += 1
print(band, '/', fails, '=', round(100*band/fails, 1), '%')   # 25 / 62 = 40.3 %
```
