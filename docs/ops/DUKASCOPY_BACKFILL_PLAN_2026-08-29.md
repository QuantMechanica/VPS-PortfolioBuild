# Dukascopy-Tick-Backfill bis 01.07.2026 + DWX↔Dukascopy-Abgleich — Plan (OWNER-Vorlage)

Erstellt 2026-08-29 (Orchestrator, auf OWNER-Auftrag). Entscheid-Karte:
`OWNER-DEC-DUKASCOPY-BACKFILL-20260829` in Mission Control.

## 1. Ist-Zustand (gemessen)

- 37 `.DWX`-Custom-Symbole (28 FX, 5 Indizes, 4 Metalle/Energie) per
  `framework/registry/dwx_symbol_matrix.csv`.
- **Signiertes Archiv** (`D:\QM\archive\Custom_master`, Manifest-gebunden): Jahre
  **2017–2025** (`.hcc` + `.tkc` je Symbol/Monat, Ticks bis `202512.tkc`).
- **Mutables Jahr 2026**: über die alte TDS/TDM-Automatik importiert bis
  **~06.04.2026** (verify-Tails in der Symbol-Matrix; TDS-Lizenz seit 05.05.2026
  ausgelaufen, ADR `decisions/2026-04-26_tds_renewal_skip.md`; ~30 von 37 Symbolen
  hatten 2026er-Exporte).
- **Lücke zum Ziel 01.07.2026**: je Symbol ab letztem echten DWX-Tick (meist ~06.04.,
  bei bis zu 7 Symbolen ggf. ab 01.01.2026) bis 30.06.2026 → **~90–180 Kalendertage
  je Symbol**, gesamt grob **120–220 Symbol-Monate**, Datenvolumen ≈ **2–4 GB**
  (komprimiert; Referenz: bestehende `.tkc` 2–30 MB je Symbol-Monat).

## 2. Wiederverwendbare Bausteine (alle vorhanden)

Die komplette Import-Automatik von 2026-04 existiert und bleibt der Kern
(`docs/ops/DWX_IMPORT_AUTOMATION.md`):

`prepare_import.py` (CSV → `.tick.bin` 24 B/Tick + `.m1.bin`) → MT5-Service
`Import_DWX_Queue_Service` auf T1 (`CustomTicksAdd` 500k-Chunks + `CustomRatesUpdate`)
→ `verify_import.py` (Head/Tail/Counts/TickValue vs Broker) → Task `QM_DWX_HourlyCheck`.
Neu zu bauen ist NUR die Quellstufe (Dukascopy statt TDM-Export) + der Abgleich.

## 3. Phasen

**P0 — Lücken-Inventur (½ Tag):** `build_dwx_history_ranges.py` + Tick-Tail-Probe je
Symbol → exakte Splice-Timestamps (letzter echter DWX-Tick) je Symbol als CSV.

**P1 — Dukascopy-Downloader (Codex-Build, 1–2 Tage):** bi5-Stundenfiles (UTC, LZMA,
20-Byte-Records), Symbol-Mapping: FX 1:1; GDAXI←DEU.IDX/EUR, SP500←USA500.IDX/USD,
NDX←USATECH.IDX/USD, WS30←USA30.IDX/USD, UK100←GBR.IDX/GBP, XAUUSD/XAGUSD direkt,
XTIUSD←LIGHT.CMD/USD, XNGUSD←GAS.CMD/USD. Throttled ~5–10 req/s →
**Download-Wandzeit ~6–12 h** (Nachtlauf, kein Factory-Impact). Zeitkonversion
UTC → Darwinex NY-Close **GMT+2/+3 (US-DST)** exakt nach
`docs/ops/TICK_DATA_MANAGER_DARWINEX_TIME.md`.

**P2 — Konverter (im selben Build):** Ausgabe im `prepare_import.py`-Eingangsformat
(TDM-CSV-kompatibel bzw. direkt `.bin`), **append-only ab Splice-Timestamp**, je Symbol
Source-Tag (`source=dukascopy`, Splice-Zeitpunkt) im Import-Sidecar.

**P3 — ABGLEICH (Freigabe-Gate, vor jedem Produktiv-Import):** Überlappfenster, in dem
BEIDE Quellen existieren (mind. 2025-10 → 2026-04): je Symbol Dukascopy vs DWX auf
M1-Ebene: OHLC-Delta (Median/p95 in Punkten), Tick-Dichte-Verhältnis,
Spread-Verteilung, Session-/Feiertagsdeckung, **DST-Übergangswochen mit
0-Sekunden-Offset-Kriterium** (Muster: `REPORT_2026-04-25_test_eurusd_dst_match.md`).
Acceptance-Vorschlag je Symbol: p95-M1-Close-Delta ≤ 1,5× typischer Spread,
Sessiondeckung ≥ 99 %, DST exakt. **Rechenzeit < 2 h.** Ergebnis: CSV je Symbol +
Sammelreport. Symbole, die scheitern, werden NICHT gespleißt (Bericht an OWNER).
Hinweis: TDM/TDS speist historisch selbst überwiegend Dukascopy-Daten — der Abgleich
beantwortet empirisch, ob der Splice überhaupt ein Quellenbruch ist.

**P4 — Import + Verteilung (~1 Tag):** T1-Import über die bestehende Queue
(~2–5 min je Symbol-Monat → **4–10 h Queue-Zeit**, Fabrik läuft parallel weiter);
`verify_import.py` je Symbol; danach Verteilung des mutablen 2026-Segments auf
T2–T10 in **einem kurzen OFF-Fenster (~30–60 min)** mit Receipts (das signierte
Archiv 2017–2025 wird NICHT berührt).

**P5 — Dauerbetrieb:** monatlicher Task (z. B. 3. des Monats für den Vormonat) +
Health-Check „ältester Tick je Symbol > 45 Tage = WARN". Damit läuft das
Backtestsystem rollierend aktuell statt einmalig bis 01.07.

## 4. Gesamtschätzung

| Posten | Aufwand |
|---|---|
| Codex-Build (P1+P2+P3-Harness) | 2–3 Arbeitstage, parallel zum Betrieb |
| Download alle Symbole | 6–12 h Wandzeit (Nacht) |
| Abgleich-Compute | < 2 h |
| Import T1 (120–220 Symbol-Monate) | 4–10 h (bis 18 h worst case) |
| OFF-Fenster Verteilung T2–T10 | 30–60 min |
| **Elapsed bis „testbar bis 01.07.2026"** | **~3–5 Tage** |
| Kosten | **0 €** (Dukascopy frei; Alternative TDS-Re-Buy €32,90/Monat entfällt) |

## 5. Risiken & Grenzen (bindend)

1. **Quellen-Splice = methodischer Punkt:** Dukascopy-Feed ≠ Darwinex-Feed. Jeder
   Lauf, dessen Fenster in den gespleißten Bereich reicht, trägt künftig ein
   `window_source`-Tag im Receipt. Bestehende Verdikte werden NIE verändert (ROT).
2. **Signed-Archiv unberührt:** 2026 ist das mutable Jahr. Eine spätere Versiegelung
   2026 ins Archiv ist ein separater OWNER-Manifest-Entscheid.
3. **Fail-closed je Symbol:** Kein Abgleich-PASS → kein Splice für dieses Symbol.
4. **Kein Kauf** (OWNER 27.08: „wir werden nichts kaufen").
5. Import ausschließlich über die governed T1-Queue (append-only, Receipts); keine
   manuellen Terminal-Starts.
