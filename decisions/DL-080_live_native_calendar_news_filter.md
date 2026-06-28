# DL-080 — Live native MT5 economic-calendar news filter (backtest keeps CSV)

**Date:** 2026-06-28
**Status:** **RATIFIED + IMPLEMENTED (OWNER 2026-06-28, "bau einen normalen News Filter ein ... via MQL5 Kalender")**
**Supersedes:** nothing — adds a LIVE path; the CSV path (tester) is unchanged.
**Related:** [[project_qm_news_calendar_stale_2026-05-19]] (refresh task = mtime-only), news-bypass/sandbox fixes. File: `framework/include/QM/QM_NewsFilter.mqh`.

## Kontext — der Live-Blocker

Beim Go-Live-Preflight des 13-Sleeve-Buchs fiel auf: der News-Kalender (`news_calendar_2015_2025.csv`)
endet inhaltlich **2025-04-07, null 2026-Events**. Der `QM_NewsCalendar_Refresh`-Task bumpt nur die
Datei-**mtime** (sein Docstring: *"refreshes the seed CSV mtimes ... not a data-coverage one"*), und
die EA-Staleness-Prüfung (`QM_NewsFilter.mqh:462`) misst **Datei-mtime**, nicht das letzte Event-Datum.
Live hätte das geheißen: EA hält News für "frisch", findet aber keine aktuellen Events → **tradet blind
durch echte High-Impact-News** (FOMC/NFP/EZB). Verletzt News-Blackout-Hard-Rule + FTMO. **Es gab nie
einen Live-News-Feed** — nur den Backtest-Kalender.

## Entscheidung

Zwei-Pfad-Architektur nach Umgebung:
- **Strategy Tester** → CSV-Pfad (unverändert, deterministisch, gate-validiert). Calendar-API ist im
  Tester nicht verfügbar.
- **Live / Echtzeit** → **native MQL5 Economic Calendar** (`CalendarValueHistory` + `CalendarEventById`
  + `CalendarCountryById`), vom Terminal/MetaQuotes laufend aktuell gehalten.

Implementierung in `QM_NewsAllowsTrade2` (die kanonische Gate-Funktion), gated auf
`!MQLInfoInteger(MQL_TESTER)`:
- `QM_NewsLiveInWindow` prüft High-Impact-Events (≥ `g_qm_news_min_impact_upper`, default HIGH) für die
  symbol-relevanten Währungen (`QM_NewsEventAffectsSymbol`) im Blackout-Fenster der Temporal-Mode
  (Default PRE30_POST30 = 30min vor/nach).
- **FAIL-CLOSED:** ist der Kalender unerreichbar/unbefüllt (`QM_NewsLiveCalendarHealthy()` = 0 Events in
  7d) → `live_calendar_unavailable` + Handel **blockiert** (return false). Worst Case = kein Trade, NIE
  blind durch News.
- Zeitbasis: Fenster wird um die übergebene `broker_time` (Server-Zeit) zentriert und gegen
  `value.time` (gleiche Basis) verglichen — keine TZ-Konversion, kein Offset-Bug-Risiko durch Mischung.
- Compliance-Achse: das Buch nutzt `DXZ` (Firm-Window = no-op); Firm-Windows-live = TODO falls FTMO-Konten
  dazukommen.

**Attach-Verifikation:** `QM_NewsLiveSelfTest` loggt einmalig beim ersten Live-Query
`NEWS_LIVE_CALENDAR_SELFTEST` mit `healthy`, 7-Tage-Event-Count und dem **nächsten High-Impact-Event +
Zeit** für das Symbol. Da der Live-Kalender NICHT backtestbar ist (Tester hat keine API), ist das die
Verifikation: OWNER liest den Log beim Chart-Attach und gleicht das nächste Event + Zeit gegen
ForexFactory ab (bestätigt Befüllung + Zeitzone) **vor** AutoTrading-On.

## Validierung

- Alle 13 Go-Live-EAs neu kompiliert: PASS, 0 errors/warnings (Calendar-API resolved).
- Backtest-Verhalten unverändert (Tester-Pfad byte-identisch; nur `!MQL_TESTER`-Branch neu).
- D2c-Paket + T_Live re-synct, `validate_golive_package` → PASS, 0 findings.
- Sicherheit: Fehlmodus ist fail-closed (kein Trade), nicht trade-through.

## Offen

- TZ-Bestätigung via SELFTEST-Log beim ersten Live-Attach (Teil des Flip-Runbooks).
- Firm-Window-Live (FTMO/5ers) falls solche Konten dazukommen.
