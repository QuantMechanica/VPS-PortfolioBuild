# Balke Range-Breakout — exakt (03:00–06:00) auf USDJPY + XAU — headless Sonnet

**Rolle:** headless Sonnet. **PM:** Claude. **Worktree:** `agents/sonnet-balke-rangebreakout`
(nie main, nie T_Live, nie T1-T7). **Ad-hoc-Backtests NUR auf geparkten T8/T9/T10.** Non-live.
Kontext: OWNER-Analyse (agy) von René Balkes Range-Breakout-EA (2026-07-13).

## Balkes exaktes Konzept (OWNER-verifiziert)
- **Range-Fenster: 03:00–06:00 Broker-Serverzeit** (Broker = GMT+2/+3, DST-abhängig). Der EA
  markiert High/Low der Kerzen in diesem Fenster.
- **Nach 06:00:** Buy-Stop am Range-High, Sell-Stop am Range-Low.
- **Abend-Auflösung ~18:00 Broker-Zeit:** alle offenen Trades schließen + ausstehende Orders löschen.
- **★DST-aware:** die Fenster sind in Broker-Zeit (GMT+2 Winter / GMT+3 Sommer) — konsistent behandeln.

## ★Basis = das FUNKTIONIERENDE 9936 (nicht das kaputte 1142!)
- **1142 (kaputt):** nutzt `range_start_hour_broker=22` (22:00 abends = FALSCHES Fenster) + rohe
  Broker-Stunden. NICHT als Basis nehmen.
- **9936 `ff-range-breakout-gmt3-h1` (funktioniert, Q04 PASS PF 1.31):**
  `framework/EAs/QM5_9936_ff-range-breakout-gmt3-h1/` — nutzt **GMT-normalisierte Zeit**
  (`Strategy_Gmt3Hour`: broker_time → UTC → +3h), Fenster derzeit **01:00–06:00 GMT+3**.
  **Das ist die korrekte Zeit-Behandlung.** Kopiere sie, ändere das Fenster auf Balkes **03:00–06:00**
  und stelle den Abend-Close auf **~18:00** (prüfe 9936s cancel/close-Stunden: cancel=13, close=20 →
  auf Balkes ~18:00 anpassen).

## Aufgabe
1. Research-EA `balke-range-breakout` bauen: 9936s GMT-normalisierte Zeit-Logik + Balkes exakte
   Fenster: **Range 03:00–06:00, Stops High/Low nach 06:00, Close/Cancel ~18:00.**
   Fenster-Stunden als INPUTS (`range_start_hour`, `range_end_hour`, `exit_hour`), Defaults 3/6/18.
2. **Auf USDJPY.DWX UND XAUUSD.DWX** je einen Walkforward: **DEV 2017.01–2021.09 / OOS 2021.10–2025.12**
   (D1 oder H1 wie 9936; Model 4; RISK_FIXED=1000; freies T8/T9/T10). Metriken je Lauf: Trades, Net,
   **MaxDD**, Sharpe, PF.
3. Vergleich: die **Balke-03:00–06:00-Variante** vs. 9936 (01:00–06:00) auf USDJPY, und die
   XAU-Performance separat (Balke sagt: Gold performt gut, hat aber Drawdown-Phasen — deckt sich
   mit unserer 26-Monats-DD-Beobachtung).
- **Erfolg:** positive OOS-Performance (PF>1.1, vernünftige MaxDD) auf mind. einem Symbol → Kandidat
  für die volle Pipeline. Ehrliches Negativ ist auch valide.

## Scope + Prozess-Pflicht (HART, Headless-Lektion — 2 Sonnets sind vor dem Commit rausgegangen!)
- NUR dieser eine EA + die Walkforward-Läufe. Keine anderen EAs, kein Master, kein Framework-Kern.
- Backtests SYNCHRON, NICHTS backgrounden. .ex5 vor jedem Smoke ins Terminal deployen.
- **★COMMITTE VOR EXIT — auch bei Negativ-Ergebnis. Schreibe die Walkforward-Zahlen in eine
  Design-Notiz + committe sie. Ein uncommitteter Worktree oder leere Report-Dirs = FAIL.**
  (Die letzten zwei Sonnet-Läufe ließen leere Result-Dirs + keinen Commit zurück — das darf NICHT
  wieder passieren.)

## Deliverable
PR auf `agents/sonnet-balke-rangebreakout`: der EA, die Walkforward-Tabelle (USDJPY + XAU, DEV/OOS,
MaxDD-Fokus), Vergleich vs 9936, Design-Notiz + Verdikt (Win/kein Win je Symbol), **committet**.
Claude reviewt + entscheidet über Pipeline + evtl. Buch-Kandidatur.
