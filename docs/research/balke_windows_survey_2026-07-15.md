# René Balke Range/Time-Range Breakout — Symbol- & Fenster-Survey (2026-07-15)

Autor: Claude. Quelle: Web (bmtrading.de, mql5.com/@bmtrading) + YouTube-Transcripts
via `fetch_transcript.py`-Proxy (agy headless hat Web/YouTube NICHT erreicht — 2× auf
Lokales ausgewichen; deshalb selbst recherchiert). Transcripts:
`D:\QM\reports\research\balke_transcripts\`.

## Quellenlage
- **@ReneBalke / BM Trading GmbH** — Range Breakout EA (MT5), Go Long EA (Index-CFDs,
  long-only), Turnaround Tuesday EA. EAs bei Partner-Brokern kostenlos; Strategy-Tester
  unlimitiert.
- Autor-Doktrin (mql5-Verkäuferprofil, wörtlich): *"I never recommend settings … a
  change of an hour or even half an hour can make the difference between profit and
  getting wrecked."* → Fenster ist symbol-spezifisch, kein universeller Default.

## Belegte Fenster (alle Zeiten = Broker-/Server-Zeit; Balke DXZ-nah GMT+2/+3, DST-relevant)

| Symbol | Range-Fenster | Exit / Delete | Besonderheiten | Balkes Verdict | Quelle |
|---|---|---|---|---|---|
| **XAUUSD (Gold)** | **03:05 – 06:05** | Close+Delete **18:55** | Buy-Stop@High / Sell-Stop@Low, OCO-Cancel; ~**1 % Risiko**, SL-basiert (fixe %-Größe=0); kein TP-Fix | *"probably the most profitable strategy ever traded live … >17.000 € live in ~1 Jahr"* — sein **aktuelles Live-Setup** | YT `-_Ctg8JXaIQ` [03:02–03:38], [04:23], [05:36–05:59] |
| **XAUUSD** (früher) | M30-Chart | ~18:00 | Live auf 50k-Konto, Beispiel-Trade +$627 @4521 | Lieblingsstrategie, "läuft seit Jahren live" | bmtrading.de/en |
| **USDJPY** | 03:00 – 06:00 | 18:00 | unser verifiziertes Fenster (OOS PF 1.20) | Standard-Symbol des Autors | mql5 #87520 Reviews + unsere WF |
| **EA-Default (Template)** | **00:00 – 07:30** | Delete/Close **18:00** | Overnight-Range / "London/Morning Breakout"; Break-Even-Stop + optional TSL (%/Punkte); Close-Positions=false → Carry möglich | *"change all of these values so it fits your symbol"* — bewusst generisch | YT `mOa4dqxAh4g` [10:22–11:21] |
| **DAX / GER40** | ~09:05-Start (Frankfurt/London-Open) | offen | via **Go Long EA** (long-only, Index-CFDs); "Indizes nutzen andere Zeiten" | separate EA-Klasse | agy-Voranalyse (07-13) + BM Trading Go-Long-Beschreibung — ★ON-SCREEN-GAP: exakte DAX-Uhrzeiten nicht im Transcript belegt |

## Symbol-Universum (Nennungen in Reviews/Doku, ohne exakte Fenster)
USDJPY, EURUSD (mit angepassten Zeiten), XAUUSD, **USDCAD, USDCHF** — genannt als
funktionierende Range-Breakout-Symbole (mql5 #87520). EA-Scope laut Produktseite:
"Forex, indices, M5–H1".

## Erkenntnisse für uns
1. **Gold-Fenster 03:05–06:05 / Exit 18:55** ist NEU und belegt — nah an unserem
   USDJPY-Fenster, aber +5 min Versatz + späterer Close. Unser XAU-Test lief auf
   03:00–06:00/18:00 und war no-win (OOS PF 1.03) — **die 5-Minuten-/Close-Zeit-Differenz
   ist genau die "half an hour = wrecked"-Sensitivität, die Balke warnt.** Wert eines
   Re-Tests mit SEINEN exakten Zeiten.
2. **Default 00:00–07:30** ist ein drittes, breiteres Fenster — bisher ungetestet.
3. **USDCAD/USDCHF** sind unerschlossene Symbol-Kandidaten für das USDJPY-Fenster.

## Priorisierungs-Empfehlung (2–3 Mechanisierungen)
1. **XAU 03:05–06:05 / Close 18:55** — Balkes exakte Live-Gold-Zeiten (unser XAU-Fail
   könnte reines Fenster-Mismatch sein, s. Punkt 1). Höchste Evidenz (aktuelles Live-Setup).
2. **USDCAD + USDCHF @ 03:00–06:00/18:00** — Symbol-Transfer des funktionierenden
   USDJPY-Fensters auf die zwei anderen genannten USD-Paare (billiger Backtest, Card-Port).
3. **Default-Fenster 00:00–07:30/18:00 auf USDJPY + XAU** — testet Balkes generisches
   Template gegen die spezifischen Fenster (Robustheits-Kontrast).

## Offene Punkte
- DAX/Go-Long exakte Zeiten = **ON-SCREEN-GAP** (nur im Video-Bild, nicht im Transcript).
  Kandidat für ein agy-Video-Ticket ODER Transcript des deutschen ORB-Videos `uVaZ5lte780`
  (Proxy-Fetch bisher gescheitert).
- Alle Balke-Performance-Zahlen sind self-reported (Live-Stream-Claims), keine
  unabhängige Verifikation — für uns irrelevant, wir gaten selbst.
