# BASELINE_SNAPSHOT — die Basis, auf der rev2 bis rev5 stehen

**Snapshot-ID:** `3472a5d2e1b569f7ff88286b4af0a450ba1429134a80107c5bf32095747093f4`
**Kurzform (überall zitiert):** **`3472a5d2e1b5`**
**Genommen:** 2026-08-18T15:33:00Z · Work Order Runde 5 §5

| | |
|---|---|
| Manifest im Repo | `artifacts/audit_baseline_snapshot_20260818.json` |
| Off-host-Kopie | `G:\My Drive\QuantMechanica - Company Reference\_audit_baselines\audit_baseline_snapshot_20260818.json` |
| Erzeuger / Prüfer | `tools/strategy_farm/portfolio/audit_baseline_snapshot.py --write` / `--verify <pfad>` |

---

## Warum ein Hash und keine Kopie

Der Bestand ist nicht kopierbar: der Report-Baum liegt im dreistelligen Gigabyte-Bereich und die
Datenbank ist live. Eingefroren wird deshalb die **Identität** des Zustands — ein Inhalts-Hash über
genau die Größen, auf denen das Audit steht. Ein späterer Lauf reproduziert den Hash, oder er steht
nachweisbar auf anderem Grund. Beides ist entscheidbar; „ungefähr derselbe Stand" ist es nicht.

Sechs Komponenten, jede **einzeln** gehasht, damit eine Abweichung lokalisierbar ist statt nur
feststellbar. Die Snapshot-ID ist der SHA256 über die sechs Komponenten-Hashes in fester Reihenfolge.

| Komponente | Hash | Inhalt zum Zeitpunkt der Aufnahme |
|---|---|---|
| `verdict_inventory` | `c80d7ab52f94` | jüngstes Verdikt je (EA, Symbol, Phase), **24.461 Tripel** |
| `ea_metrics_coverage` | `49faa69f97fa` | **62.461 Zeilen, 43.182 `missing` (69,1 %)**, Feldbelegung je (Phase, source) |
| `sleeve_population` | `a409ee224d5f` | **21 Sleeves**, 2.128 Handelstage, Spanne 3.004 Kalendertage |
| `window_series` | `4de9948e3ae7` | **50 Fenster**, davon **36 mit vollständigem Buch** |
| `pool_population` | `63b7ddffab20` | **91 Pool-Paare** aus der eingefrorenen Kohortendatei |
| `artifacts` | `f49eb71845e9` | SHA256 von 9 Dateien: Kohortendatei, Sweep-Artefakt, rev3, rev4, Audit-Antwort, `challenge_book_60d.py`, `ea_metrics.py`, u. a. |

## Was ab jetzt gilt (§5.3)

**Jede Zahl aus rev2 bis rev5 gilt für Snapshot `3472a5d2e1b5`.** Jede Zahl aus Teil B und Teil C
trägt die Snapshot-ID, gegen die sie gerechnet wurde — die Läufe aus dem vereinten Batch tragen eine
andere und sind mit den hier festgeschriebenen Zahlen **nicht** mischbar.

Die Reihenfolge ist eingehalten worden, und zwar strenger als §4 verlangt: die Baseline wurde
genommen, **bevor** das Codex-Ticket für die Extraktor-Reparatur überhaupt erstellt wurde. Begründung
in `INVALIDATION_MATRIX.md` §3 — die Vollextraktion schreibt `ea_metrics` neu und ist damit selbst
schon eine Regenerierung, auch ohne einen einzigen Backtest.

## Prüfung

```
python tools/strategy_farm/portfolio/audit_baseline_snapshot.py \
    --verify C:\QM\repo\artifacts\audit_baseline_snapshot_20260818.json
```

Meldet komponentenweise, was sich seit der Aufnahme verändert hat. **Erwartung nach Abschluss von
Teil B:** `ea_metrics_coverage` und `verdict_inventory` weichen ab, die übrigen vier nicht. Weicht
eine der anderen vier ab, ohne dass eine Entscheidung sie erklärt, ist das ein Befund und kein
Rauschen.
