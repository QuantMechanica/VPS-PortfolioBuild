# Video-Analyse — René Balke "Portfolio/Master EA" (XgfpXQzpJtk)

**Analysiert:** 2026-07-13 (Proxy-Captions, 246 Zeilen; agy erneut ohne Video-Tool —
Block-Report `VIDEO_XgfpXQzpJtk_BALKE_AGY_2026-07-13.md`). On-Screen (Dashboard-Zahlen,
GUI-Panels) = GAP.

## Kernbefund: KEINE neue Strategie — ein ARCHITEKTUR-Video

Das Video zeigt **keinen** neuen Handels-Edge, sondern **genau OWNERs Master-EA-Konzept**,
von Balke live gebaut und erprobt. Direkte Validierung des geplanten nächsten Schritts.

Balke's "Portfolio EA" (ein einziger EA statt 13 Charts × 13 EAs):
- **Ein Master-EA** hält alle Strategien; im Live-Konto läuft nur dieser eine EA `[00:43]`.
- **4 Strategie-Typen über 13 Charts**; genannt: **Range Breakout**, **Turnaround Tuesday**
  (TaT) `[01:29, 02:07]` — beides Mechaniken, die wir bereits haben (Balke-Slate
  12836/12844/12845/12846, Go-Long 13036).
- **Je Strategie eigene Magic + eigener Comment** → Zuordnung auf einen Blick `[01:23, 01:26]`.
- **Portfolio-Dashboard**: Total-P&L, Floating-P&L, Realized-P&L, High-Watermark,
  Drawdown (abs + %), #Strategien; Drill-down je Strategie (Realized, DD, Floating, Magic,
  offene Positionen) `[01:03–01:16]`.
- **Persistenter State via Dateien**: nach MT5-Neustart liest der EA aus Files, WELCHE
  Strategien er handelt, UND stellt P&L/DD/HWM wieder her `[01:44]`.
- **Runtime-Add** neuer Strategien per GUI (Symbol, Magic, Inputs) → 14. Strategie `[01:31]`.
- **"Open all"**: öffnet je Strategie einen Chart, prüft auf schon-offen (keine Dubletten)
  `[02:26]`; je Chart Strategie-Info-Block oben links, Range-Objekte / TaT-Zeiten, per-Position
  Floating-P&L im strategie-eigenen Chart visualisiert `[02:10–03:15]`.
- Settings: **1% Risk/Trade**; ein `min range percent`-Filter (0.1) als USDJPY-Anpassung
  gegen zu kleine Ranges `[03:47]`.
- Balke-Zitat: *"in the age of AI it's extremely simple to create these programs — just ask
  AI for anything"* `[00:27]` — er baut das selbst per AI-Coding.

## Ableitungen für QM

1. **Das Konzept ist bestätigt und live-erprobt.** Ein unabhängiger, erfolgreicher Trader
   nutzt exakt die Master-EA-Architektur, die OWNER will → Risiko der Idee gering.
2. **Kein neuer Strategie-Edge** (Best-Case „neue Strategien" ist nicht eingetreten — es ist
   ein Tooling/Architektur-Video). Range-Breakout + TaT haben wir bereits.
3. **Übernehmenswerte Features** (priorisiert): (a) je-Strategie Magic+Comment [haben wir via
   Magic-Formel], (b) persistenter DD/HWM-State via Files [wertvoll — koppelt an unser
   KillSwitch/Book-Halt], (c) Portfolio-Dashboard [haben wir extern], (d) Runtime-GUI-Add
   [brauchen WIR nicht — unsere Strategien sind fixe Pipeline-Survivor].
4. **QM-spezifischer Unterschied:** Balke baut runtime-konfigurierbar (GUI); QM baut besser
   **compile-time pro Symbol** (deterministische, reproduzierbare Backtests = Pipeline-Pflicht).

→ Vollständiger Umsetzungsplan: `docs/ops/MASTER_EA_SYMBOL_CONSOLIDATION_PLAN_2026-07-13.md`.
