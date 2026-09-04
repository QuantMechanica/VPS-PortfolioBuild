# OWNER-Vorlage 2026-09-05 — News-Kalender-Zeitstempeldefekt (P0, ROT)

Stand 23:10Z (lokal 01:10), CEO-Loop. Evidenz: `docs/ops/evidence/2026-09-05_news_calendar_timestamp_defect.md`
(+ Verzeichnis `…_defect/` mit summary.json, native_join_deltas.csv, stored_tod_histogram.csv).

## Lage in vier Sätzen

1. Beide Produktions-Newskalender (Primär `news_calendar_2015_2025.csv`, Sekundär `forex_factory_calendar_clean.csv`)
   speichern US-08:30-ET-Releases (NFP, CPI, PPI, Retail Sales, Claims, Unemployment Rate) rund **17 Stunden zu früh**
   (Vortag 19:30/20:30 UTC). 2018–2025: **1 176 von 1 510 Zeilen (78 %)**, NFP/Retail Sales/Unemployment Rate 100 %.
   ADP, ISM, FOMC, Fed-Zins sind korrekt. Zusätzlich fehlen **2025-05 bis 2026-06 komplett** (null Zeilen).
2. Im Tester rechnet der EA die Brokerzeit korrekt nach UTC um, vergleicht aber gegen den falschen Kalenderwert: der
   ±30-min-Blackout fällt auf **Donnerstag 22:00–23:00 Serverzeit**, der echte NFP-Druck am Freitag 15:30 läuft ungefiltert.
3. **Live ist nicht betroffen:** T_Live entscheidet aus dem nativen MT5-Kalender (DL-080); die CSVs steuern dort nur die
   Staleness-Prüfung. Die aktuellen 2026er-Zeilen (Refresh-Task) sind korrekt (31/31 bei 12:30 UTC).
4. Betroffen ist die Backtest-Evidenz: die News-Gates Q09_NEWS/Q10_NEWS (v4) haben noch **kein** PASS-Verdikt erzeugt,
   aber jede künftige Adjudikation und jeder Standard-Backtest mit aktivem Newsfilter (EA-Default PRE30_POST30) misst gegen
   den falschen Zeitpunkt. Praktisch relevant nur für Intraday-EAs; D1-Bar-Open-Einstiege sind faktisch inert.

## Was das für den Zähler 8/25 heißt

| Paar | TF | News-Modus | Exposition |
|---|---|---|---|
| 11421 EURUSD, 11422 USDCAD, 13054 XTIUSD, 1537 XAGUSD, 21505 XAGUSD, 20048 XTIUSD, 11910 NZDUSD | D1 | Default | praktisch inert (Einstieg 00:00 Server) |
| **10706 GBPUSD (tv-mon-ls)** | **H1** | explizit PRE30_POST30 | **exponiert** — Q10-v3-PASS 25.07. und Q14 KEEP_INCUMBENT gemessen mit Blackout am falschen Tag |

Die exakte Klassifikation aller Q09/Q10/Q14-Verdiktpaare (EA-Default im .mq5, Einstiegsklasse, Währungen) läuft als
Codex-Sol-Ticket **72e5884d** (nur Bericht). Q09 v3: 253 PASS / 35 FAIL; Q10 v3: 40 PASS; Q11 PASS: 31 Paare.

## Was ich bereits getan habe (GRÜN, reversibel)

- 11 bisher ungehaltene pending Q10_NEWS-Zeilen mit Hold `NEWS_CALENDAR_TIMESTAMP_DEFECT` gesperrt (Intraday-Kandidaten
  wie 10847/GDAXI H1, 13128/NDX H1, 13301/GDAXI M5 hätten sonst gegen den defekten Kalender adjudiziert). Lösen: `farmctl release-hold`.
- OOS-2026-Fensterreparatur committet (1ac9f653d8), **`--apply` vertagt**: das Fenster Jan–Apr 2026 liegt im Kalenderloch.
- Codex-Tickets: 72e5884d (Blast-Radius-Sizing), 0f61815f (Detektoren, nur Bericht: NFP-Freitag-08:30-ET-Anker,
  interne Konsistenz der abgeleiteten Spalten, Datei-zu-Datei-Vergleich, Abgleich nativer Export, Abdeckungstabelle).
- Kein Kalender, kein Gate-Kriterium, kein Verdikt, nichts an T_Live berührt.

## Entscheidungen (alle ROT — keine Auffangregel)

**E1 — Kalenderreparatur.**
- **Option A (Empfehlung): Reparatur an der Quelle für USD** aus dem ankergetesteten nativen MT5-Export
  (`T_EXPORT_USD_HIGH_2018_2025_NATIVE.csv`, 4 189 Zeilen; das private Lab hat dazu am 11.07. bereits BLS/Fed-Anker kuratiert),
  Nicht-USD mit dokumentiertem Offset-Fächer oder als erklärte Lücke; Loch 2025-05..2026-06 aus derselben Quelle backfillen.
  Neue Bundle-Identität, neuer Sha-Pin in `news_calendar_bundle_manifest.json` und Execution-Contracts (Repin-Pfad existiert).
- Option B: Konservative Union (stored ∪ native): überblockt, unterblockt nie; kein Zeilen-Wahrheitsbedarf; leicht weniger Trades.
- Option C: Nur Detektoren scharf schalten (Gate fail-closed), Kalender vorerst lassen — verhindert Wiederholung, heilt nichts.
- Rollback: alter Kalender bleibt unter Bundle-Id versiegelt; Repin ist umkehrbar. Cost of Wait: pro Tag laufen ~1–3 Standard-
  Backtests mit Newsfilter am falschen Zeitpunkt weiter (Intraday-Anteil klein); die Q10_NEWS-Kette ruht.

**E2 — Neubewertungsumfang.** Minimal: alle pending Q10_NEWS/Q09_NEWS erst nach Reparatur (schon gehalten). Mittel: zusätzlich
die von 72e5884d als EXPONIERT klassifizierten Q09-v3/Q10-v3-PASS-Verdikte append-only nachmessen (D1-Paare bleiben).
Maximal: 10706/GBPUSD aus dem Zähler nehmen, bis nachgemessen (→ 7/25). Empfehlung: **Mittel**, Entscheid über 10706 nach dem
Sizing-Bericht.

**E3 — Q02–Q08-Standardläufe:** weiterlaufen lassen (D1-dominiert, Intraday-Exposition klein) oder Fabrik auf D1-only drosseln bis E1?
Empfehlung: **weiterlaufen** — die Reparatur ändert nur die Newsfilter-Zeitpunkte, nicht die Strategieevidenz; die betroffenen
Intraday-Paare werden über E2 nachgemessen.

**E4 — OOS-2026-Kampagne:** `--apply` erst nach E1 (Backfill des Lochs), oder jetzt ohne News-Events als „news-blind" deklariert
laufen lassen? Empfehlung: **nach E1**; die FTMO-Trigger-Evidenz ohne Newsfilter wäre nicht die, die wir brauchen.

**E5 — DL-090:** `D:\QM\strategy_farm\artifacts\oos_2026_confirmation_v1\campaign_plan.json` und die nativen Export-CSVs
als aufbewahrungsgeschützt markieren (Spawn-Binding hängt daran). Empfehlung: ja.

Ein JA zu E1-A erzeugt genau einen entscheidungsgebundenen Claude-Auftrag (Reparaturplan → Codex-Implementierung → Verifikation
gegen Tick-Volumen-Footprints → Repin); E2 erzeugt einen zweiten (append-only Nachmessungen). VERTAGT erzeugt keinen.
