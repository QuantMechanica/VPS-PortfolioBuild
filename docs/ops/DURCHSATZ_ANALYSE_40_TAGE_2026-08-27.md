# Durchsatz-Analyse „40 Tage" — 2026-08-27 (OWNER-Auftrag: nur analysieren, nichts ändern)

Messfenster: 72 h (24.–27.08.), farm_state read-only. Kein Prozess wurde verändert.

## 1. Kernbefunde (gemessen)

| # | Befund | Zahl |
|---|---|---|
| 1 | Slot-Auslastung: verbrauchte Terminal-h / verfügbare Slot-h | **320 / 720 = 44 %** |
| 2 | Davon Verdikt-los verbrannt (infra/invalid/REVIEW_REQUIRED) | **167 h = 52 %** |
| 3 | CPU-Admission-Sleeps (cpu_high_pause, 24 h) | **33.818 Events** ≈ 190+ Terminal-h Schlaf |
| 4 | Committetes Restvolumen (heutiger Stand) | ≈ **1.400 Terminal-h** + Zufluss |

Aufschlüsselung Restvolumen: Pattern-Zellen 3.158 × ~12 min ≈ 632 h (45 %!); Q04-Backlog
1.428 × 14 min ≈ 333 h; Q02 721 × 13 min ≈ 156 h; Q10_NEWS 47 Parents (+Expansions) ≈ 150 h;
Q03 110 × 47 min ≈ 86 h; Rest klein.

Wandzeiten (Median): Q10_NEWS 191 min · Q07 74 min · Q03 47 min · Q08 19 min · Q09 15 min ·
Q04 14 min · Q02 13 min · Compile 1,4 min.

## 2. Die wichtigste Erkenntnis: 40 Tage ist die falsche Uhr

Die ~40 Tage sind die **Queue-leer-ETA** (alles Committete abgearbeitet). Der **kritische
Pfad zu den 25** ist ein anderer, viel kürzerer Pfad:

- Reservoir: **53 (EA, Symbol)-Paare stehen mit Q09-PASS** vor dem News-Gate; 4 haben
  bereits ein konklusives News-Ergebnis.
- Fehlen: **~21 weitere konklusive News-Abschlüsse** (+ Q11-Portfolio-Checks) — bei
  ~3 h/Standard-Matrix bzw. ~6–12 h/Expansion sind das grob **100–250 Terminal-h**
  kritischer Pfad, nicht 1.400.
- **Weder die 3.158 Pattern-Zellen (Post-Q11-Optimierungszweig!) noch der Q04-Backfill
  (Universum-Erweiterung, bewusst unterste Priorität) liegen auf dem Weg zu 25.**

Vorbehalt: Der Pfad verlängert sich um die Fail-Quote am News-Gate (nicht jedes der 53
Paare wird qualifizieren — `not_qualifiable` ist ein legitimes Ergebnis) und um Q11.

## 3. Vorschläge (gereiht nach Gewinn ÷ Aufwand; Qualität = unverändertes Modell,
unveränderte Fenster, unveränderte Kriterien)

**V1 — Nichts tun, das schon Gelieferte wirken lassen (Gewinn ~2×, Kosten 0).**
Die 52 % Verbrennung stammen dominant aus der Q10_NEWS-Burn-Klasse (84 % der Phase!),
deren Ursachen 25.–27.08. behoben wurden (Reservation-Race-Fix, Claim-Guard, News-Cap).
Erwartung: Effektiv-Durchsatz nahe Verdopplung ohne jede weitere Maßnahme. Messpunkt in
48 h nachhalten.

**V2 — ETA-Anzeige auf kritischen Pfad umstellen (Gewinn: richtige Steuerung, Kosten
minimal).** Mission Control zeigt Queue-ETA; eine „ETA-zu-25"-Zeile (Reservoir 53,
konklusiv 4, Restbedarf, gemessene News-Abschlussrate) macht den echten Engpass sichtbar
und verhindert, dass wir am falschen Ende beschleunigen.

**V3 — Optimal-Concurrency-Experiment (Gewinn geschätzt +15–30 %, Kosten: 1 Messtag).**
44 % Slot-Auslastung bei 100 % CPU + 33.818 Admission-Sleeps/Tag sagen: 10 Tester auf
16 vCPU übersättigen. Hypothese: 7–8 Worker liefern mehr Netto-Verdikte/Tag als 10.
Sauberes A/B (je 24 h, gleiche Queue-Mischung), nur Messung, dann Entscheid.

**V4 — MT5-native Optimization für die Pattern-Matrix (Gewinn 3–10× auf 632 h ≈ 45 %
des Restvolumens; Kosten: Design + Validierung).** Heute ist jede Zelle ein eigener
Terminal-Launch + Voll-Backtest. Der MT5-Tester kann denselben Sweep (1 Input, 154 Werte,
identisches Fenster/Modell) nativ mit mehreren lokalen Agents, geteilter Tick-Pipeline
und ohne Relaunch-Overhead fahren — identische Läufe, identischer Determinismus je Pass.
Voraussetzung: Evidenz-Adapter (per-Pass-Receipts aus dem Optimization-Cache) +
Byte-Vergleich gegen ~20 Referenz-Zellen als Abnahme. Reine Ausführungsmechanik,
keine Kriterienänderung.

**V5 — VPS-Upgrade 16→32 vCPU (Gewinn ~2× auf alles; Kosten: Geld + Migrationsfenster;
OWNER-Kauf-Entscheid).** Die CPU ist die harte physikalische Decke (Punkt 3 in §1).
Bekannter Rahmen: 8 Kerne/63 GB; RAM ist mit 49 GB frei aktuell NICHT der Engpass,
Disk nach Purge auch nicht. Alternativ: zweite günstige Box als reine Tester-Flotte
(T11–T14-Konzept liegt vor), Custom-History-Isolation vorausgesetzt.

**V6 — Kleinvieh mit Messhebel (je +einstellige %):** Circuit-Breaker scharf schalten
(liegt dry-run bereit) gegen Retry-Endlosbelegung; Q03-Ausreißer (p90 128 min) anschauen;
Mutation-Lock-Wartezeiten (Pump-Serialisierung) im at_utc-Log jetzt messbar.

## 4. Was ich bewusst NICHT vorschlage

Fenster kürzen, Seeds reduzieren, Zellen samplen, Gates parallelisieren, die
DL-089-Matrix beschneiden — alles Qualitätsverlust bzw. ROT.
