# Master-EA Phase 5 — T_Live-Migration XAU (PLAN)

**Status:** PLAN (OWNER-gated). Kein Live-Schalter ohne OWNER-Freigabe. Author: Claude.
Voraussetzung erfüllt: Phase 4 behavior-neutral BEWIESEN
(`docs/ops/evidence/master_ea_phase4_integration_2026-07-13.md`).

## Ziel
Die 5 live XAU-Sleeves auf T_Live von **5 Einzel-Charts (5 Standalone-EAs)** auf **1 XAU-Master-
Chart** (`QM5_MXAU_master-xauusd`, alle 5 als Module) umstellen. Magics UNVERÄNDERT → offene
Positionen, Order-History, Live-Puls und Portfolio-Mathematik bleiben nahtlos. Buch-Gesamtrisiko
unverändert. Die anderen 18 Sleeves + **12567/XNGUSD bleiben unangetastet** (separates Symbol).

## Der Live-Preset (exakt, aus den deployten Werten)
Master läuft im **RISK_PERCENT-Live-Modus** (Dualmodus, Phase 2.5). Preset
`..._XAUUSD.DWX_LIVE.set`: `qm_ea_id=20001`, ENV=live, alle 5 Slots enabled,
`strategyN_risk_mode=1` (PERCENT), `strategyN_risk_value=` der deployte %:

| Slot | EA | Magic | RISK_PERCENT (live) |
|---|---|---|---|
| strategy1 | 10403 et-turtle20x | 104030002 | 0.2344 |
| strategy2 | 10513 mql5-ichimoku | 105130003 | 0.8366 |
| strategy3 | 12567 cum-rsi2 | 125670003 | 1.0000 |
| strategy4 | 12989 grimes (H4) | 129890003 | 0.5431 |
| strategy5 | 1556 aa-zak-mom12 | 15560004 | 0.6399 |
| | | **Summe** | **3.254 %** (= unverändertes XAU-Budget) |

`RISK_FIXED=0`. News/Friday = die geteilte Corset-Config (temporal=3, compliance=1, high, Friday 21h).

## Pre-Migration-Gates (alle vor T_Live, Factory darf aus bleiben)
1. **★NEU — Live-PERCENT-Validierungs-Gate:** die per-Modul-Gates liefen im **FIXED**-Modus.
   Live ist **PERCENT**. Master mit dem LIVE-Preset (PERCENT) im Tester über ein jüngeres Fenster
   laufen lassen → verifizieren: (a) initialisiert sauber (MASTER_INIT_OK, 5 aktive Module),
   (b) sizet je Modul in PERCENT mit dem richtigen %, (c) Summe der Sub-Risiken == 3.254 %.
   (Kein Cent-Match zum Standalone erwartet — anderes Sizing; Zweck ist Init + korrektes PERCENT-Sizing.)
2. **Build+Deploy:** Master `.ex5` gate-geprüft (board-advisor, SHA bekannt). SHA256-Match
   Factory → T_Live nach Deploy.
3. **Magic-Registry-Konsistenz auf T_Live:** die 5 Sub-Magics + Master-Identität 200010000 in
   `magic_numbers.csv`/Resolver konsistent; der Master emittiert 5 Fremd-Magics ohne Abort
   (Phase-1-Mechanik, auf T_Live verifizieren).
4. **News-Kalender** auf T_Live present + current.
5. **Preset-Check:** ENV=live, RISK_PERCENT gesetzt, RISK_FIXED=0, Slots/Magics gegen Registry.

## Cutover-Workflow (Hard-Rule, OWNER-gated)
1. **Factory bereitet:** Master `.ex5`, LIVE-Preset, Deploy-Manifest (SHA-Liste).
2. **OWNER approves das Manifest schriftlich.**
3. **Claude verifiziert:** SHA-Match, Magic-Registry, Preset ENV/Risk-Mode, News.
4. **Chart-Session (OWNER + Claude, T_Live):**
   a. **★Position-/Order-Status prüfen** (die 5 XAU-Magics): flat oder offen?
   b. Die **5 XAU-Einzel-Charts entfernen**; die 18 anderen Charts + 12567/XNG **unberührt**.
   c. **1 XAU-Master-Chart** hinzufügen, Master-EA + LIVE-Preset drauf.
   d. Da die Magics identisch sind, adoptiert der Master offene Positionen je Magic
      (`QM_ModuleOwnsPosition`) → das jeweilige Modul managt/exitet sie weiter.
5. **AutoTrading** bleibt an (Buch läuft); **OWNER oder Claude** bestätigt/toggelt auf T_Live.
6. **Claude verifiziert (post):** MASTER_INIT_OK (host_magic 200010000, 5 aktive Module), die 5
   Magics bei KillSwitch registriert, adoptierte Positionen korrekt gemanagt, Live-Puls zeigt die
   5 Magics unter dem Master. Record unter `decisions/2026-..._t_live_xau_master.md`.

## ★Migrations-Hazards + Handling
- **Offene Positionen beim Cutover:** die Module managen per Magic — eine bestehende Position
  (z.B. magic 104030002) wird vom EtTurtle-Modul adoptiert. Exit-Logik prüft Signal/Hold-Time
  auf der Position, nicht wer sie öffnete → sollte adoptieren. **Sicherste Variante: Cutover in
  einem FLAT-XAU-Moment** (alle 5 flat, bei D1/H4-Low-Freq häufig). Sonst: Adoption vorher im
  Tester verifizieren (Position vor-seeden, Master übernimmt/exitet korrekt).
- **EtTurtle-Pending-Orders (BUY_STOP/SELL_STOP):** beim Cutover bestehende Pending-Orders
  (magic 104030002) entweder canceln + Master re-etabliert sie am nächsten Bar, oder Modul
  adoptiert sie. **Empfehlung: flat + pendingfrei cutovern** (nach Friday-Close / vor Montag-Open).
- **Chart-TF des Live-Masters:** Module lesen explizite TFs → Chart-TF nominell irrelevant; live
  feuern Real-Ticks OnTick unabhängig. **Empfehlung H4** (12989 nativ; effizient). Entscheidung OWNER.
- **Risk-Modus:** live = PERCENT. Verifizieren, dass jedes Modul in PERCENT sizet (nicht FIXED),
  RISK_FIXED=0.
- **★Rollback:** bei Fehlverhalten → zurück zu den 5 Einzel-Charts (Standalone-Presets archiviert,
  Magics identisch → nahtloser Revert). Rollback-Trigger + archivierte Presets im Manifest.

## Decision-Points für OWNER (bevor ich das Manifest baue)
1. **Chart-TF** des Live-Masters — Empfehlung **H4**.
2. **Cutover-Timing** — Empfehlung **flat + pendingfrei** (Wochenende/nach Friday-Close), sonst
   Adoption-Verifikation nötig.
3. **Live-PERCENT-Validierungs-Gate** vorab — Empfehlung **ja** (billig, fängt PERCENT-Sizing-Fehler).

## Reihenfolge
Pre-Gates (1–5, non-live) → OWNER-Decisions → Manifest → OWNER-Freigabe → Chart-Session → Verify →
Record. Phase 6 (Template pro Symbol: NDX/EURUSD/…) erst nach erfolgreichem XAU-Live-Betrieb.
