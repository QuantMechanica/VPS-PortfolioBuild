# Technical Requirements Documents — 3 Strategien (Codex-ready)

Autor: Claude · Datum: 2026-07-15 · Quelle-Recon:
`D:\QM\reports\research\channel_recon\FINDINGS_goshawk_shawn_mtfcs_2026-07-15.md`
(zitierte Timestamps dort). Adaptiert an QuantMechanica V5: V5-Framework-Header
(qm_ea_id, magic_slot, RISK_FIXED/RISK_PERCENT), DWX-Custom-Symbole, Model-4-Real-Tick,
Q00–Q13-Gates, KEIN ML, mechanisch/parametrisierbar, kein Grid/Martingale fürs DXZ-Buch.

Alle drei sind **OnBar-getriebene** Systeme (Entscheidung nur auf geschlossenen Bars =
kein Repaint/Lookahead — Killer #1 laut Strang-3-Recon). OnTick nur für SL/TP/Trailing-
Nachführung. Slippage/Spread-Filter: Entry skippen wenn `SymbolInfoInteger(SPREAD) >
strategy_max_spread_points` (Default pro Symbol kalibrieren; 0 = aus).

Volatilitäts-Fokus (OWNER-Vorgabe): Primär-Universum = **NDX.DWX, SP500.DWX, WS30.DWX,
GDAXI.DWX, XAUUSD.DWX** (+ BTCUSD.DWX/ETHUSD.DWX falls DWX-Historie vorhanden — sonst
GAP: Krypto-Symbol-Import-Ticket). TQQQ/3x-Semis existieren nicht als DWX-CFD → Proxy
über NDX-Hebel im Sizing, NICHT als eigenes Symbol.

Sizing-Konvention (bindend): Backtest `RISK_FIXED` (fester Geldbetrag), Live `RISK_PERCENT`.
Lot = `QM_LotsForRisk(symbol, stop_distance_price, risk_mode, risk_value)` (existiert im
Framework). Alle „%-Risk"-Formeln unten liefern den Risk-Geldbetrag, den der Sizer in Lots
übersetzt.

---

## TRD-1 — Goshawk Quant Trend Follower + Scale-In (divergent bet)

**Kernidee:** EMA-Regimefilter + Donchian-Breakout-Entry, Pyramidisierung in ATR-Schritten,
ATR-Trailing-Exit, KEIN fixer Take-Profit (kappt den Positive-Skew-Tail — Recon 1.5).
Profit-Harvesting hier = Trailing-Stop-Nachführung + optionaler Teilabbau bei Vol-Spike,
NICHT fixe TPs.

### Parameter (Inputs)
| Input | Default | Range | Quelle/Note |
|---|---|---|---|
| `tf` | PERIOD_D1 | D1/H4/H1 | Recon: daily bulk, H1 für Krypto/Intraday |
| `ema_trend_period` | 100 | 50–200 | Recon 1.1 R1 |
| `donchian_entry` | 20 | 20–55 | Recon: Donchian 20 (Gold), 50 (Krypto) |
| `atr_period` | **14** | 10–20 | ★GAP: nur On-Screen im Video → agy-Ticket; Default 14 |
| `atr_trail_mult` | **3.0** | 2.0–5.0 | ★GAP: nicht gesprochen → Default 3.0 (Turtle-Konvention) |
| `pyramid_max_adds` | 3 | 0–3 | Recon 1.1 R3 |
| `pyramid_step_atr` | 0.5 | 0.25–1.0 | Recon 1.1 R3 (0.5×ATR Abstand) |
| `risk_pct_per_unit` | 1.0 | 0.5–2.0 | Recon 1.7: Basis 1–2 %, ATR-skaliert |
| `vol_target_annual` | 0.0 | 0/0.2–0.6 | 0=aus; sonst Vol-Targeting (Recon 1.7d) |
| `harvest_atr_spike` | 0.0 | 0/2.5–4.0 | 0=aus; Teilabbau bei Impuls (s.u.) |

### Entry (boolean, auf Bar-Close von `tf`)
```
regime_long  = Close[1] > EMA(ema_trend_period)[1]
breakout_long= Close[1] >= HighestHigh(donchian_entry, shift=2)   // 20-Tage-Hoch der VORletzten Bars
ENTER_LONG   = regime_long AND breakout_long AND no_open_position(this_magic)
// short spiegelbildlich: Close[1] < EMA, Close[1] <= LowestLow(donchian_entry, shift=2)
```
Long-only-Variante (Recon-Doktrin "erstes System = long-only" + DXZ-Index-Aufwärtsbias):
`enable_short=false` als Default für Index-Symbole.

### Position Sizing
```
atr        = ATR(atr_period)[1]
risk_money = (vol_target_annual==0)
             ? equity * risk_pct_per_unit/100
             : equity * risk_pct_per_unit/100 * min(1.0, vol_target_annual / realized_vol_annual)
realized_vol_annual = stdev(returns, 20) * sqrt(252)   // sqrt(365) für Krypto-tf
stop_distance = atr_trail_mult * atr
lots = QM_LotsForRisk(sym, stop_distance, risk_mode, risk_money)
```

### Trade Management — Pyramiding (Scale-in)
```
// nach Erst-Entry, solange adds < pyramid_max_adds und Trend-Richtung hält:
if (favorable_excursion >= (adds+1) * pyramid_step_atr * atr_at_entry) {
    add_unit(lots_scaled)          // lots_scaled = gleiche risk_money-Logik auf Rest-Distanz
    adds++
    raise_trailing_stop_all_units_to(breakeven_of_prior_unit)   // Ketten-Trailing
}
```
★GAP: Pyramid-Unit-Größe (voll vs. reduziert) nicht spezifiziert → Default: volle Unit,
aber Gesamt-Risiko der offenen Kette gedeckelt auf `pyramid_risk_cap_pct` (Default 3×
risk_pct_per_unit).

### Exit / Profit Harvesting
```
// ATR-Trailing auf CLOSE (nicht Touch — Recon 1.5):
trail_stop = max(trail_stop, HighestClose_since_entry - atr_trail_mult*atr)   // long
EXIT_ALL if Close[1] < trail_stop
// optionales Profit-Harvesting bei Vol-Spike:
if (harvest_atr_spike>0 AND (High[1]-Open[1]) >= harvest_atr_spike*atr) close_partial(50%)
// KEIN fixer TP.
```

### MT5-Spezifika
- `OnBar` (neuer `tf`-Bar) für Entry/Add/Exit-Entscheidung; `OnTick` nur Trailing-SL-Modify.
- Multi-Symbol: eigenständige Instanz pro Symbol (ein magic_slot je Symbol) — kein Basket
  nötig; Diversifikation = mehrere Sleeves im Buch (Recon-Doktrin "run across asset classes").
- Spread-Filter aktiv; `qm_stress_reject_probability`-Hook respektieren (Q06).

### Gate-Risiken (V5)
- Q02-Freq: TF-Follower macht ~10–60 Trades/Jahr/Symbol → über Floor ✓.
- Q05-DD: Trend-Systeme haben lange DD-Phasen — die neue 25 %-Decke hilft.
- Q07-Seed-Varianz: pyramid/trailing ist deterministisch → niedrige Varianz erwartet.
- Q08-Korrelation: mehrere Trend-Sleeves korrelieren untereinander (alle long Momentum) →
  Admission wird nur 1–2 zulassen; bewusst diverse Symbole wählen.

---

## TRD-2 — Nick Shawn Price-Action Zone Reversal (convergent bet)

**Kernidee:** HTF-S/R-Zonen als reine RISIKOSTRUKTUR (S/R hat "null Prognosekraft" —
Recon 2.1); Edge = **Management-Asymmetrie** (Gewinner bis 1:1.1-Ziel halten, Verlierer
früh bei −0.3..−0.5R schneiden). Mechanisierungs-Herausforderung: Zonen + „2 Rejections"
müssen mechanisch definiert werden (Shawn macht das visuell → wir formalisieren).

### Zonen-Definition (mechanisch, ersetzt Shawns visuelles Zeichnen)
```
// auf DAILY (zone_tf): Swing-Level via Fraktale
swing_high[k] = High[k] > High[k±1..fractal_n]      // fractal_n=2 (5-Bar-Fraktal)
swing_low[k]  analog
// Zone = Cluster von >= touch_min Swing-Punkten innerhalb zone_width_atr*ATR(zone_tf)
zone_center = median(cluster_levels)
zone_halfwidth = zone_width_atr * ATR(zone_tf, atr_period)
// nur Zonen NAHE Preis behalten (nächste über/unter aktuellem Preis)
```
| Input | Default | Note |
|---|---|---|
| `zone_tf` | PERIOD_D1 | Recon 2.1 (daily/weekly) |
| `fractal_n` | 2 | 5-Bar-Fraktal |
| `touch_min` | **3** | ★GAP: Shawn "multiple"/2–8 → Default 3 |
| `zone_width_atr` | **0.5** | ★GAP: nur visuell → 0.5×ATR(D1); agy-Ticket |
| `entry_tf` | PERIOD_H1 | Rejection-Bestätigung |
| `confirm_tf` | PERIOD_M15 | MTF-Alignment (gleiche Zone auf M15!) |
| `rejections_required` | 2 | Recon 2.2 (min. 2 Rejections) |
| `rr_target` | 1.1 | Recon 2.2 (0.1 = Kommission) |
| `early_cut_R` | 0.4 | Recon 2.1 (−0.3..−0.5R) |
| `stop_buffer_atr` | 0.5 | Puffer hinter Zone (Wick-tolerant) |

### Entry (boolean)
```
price_in_zone      = |Close[1](entry_tf) - zone_center| <= zone_halfwidth
mtf_aligned        = zone_respected_on(confirm_tf, zone_center, zone_halfwidth)   // gleiche Zone M15
rejection_count    = count_rejections(entry_tf, zone, lookback)  // Wick-Cluster/Doppelboden
// Rejection = Bar mit langem Docht IN Zone + Close zurück aus Zonenrichtung
ENTER_LONG (at support) = price_in_zone AND mtf_aligned AND rejection_count >= rejections_required
                          AND bounce_started (erste Gegenkerze)
```

### Stop / Target / Management (Asymmetrie = der Edge)
```
stop  = zone_far_edge - stop_buffer_atr*ATR   // long: unter Zone + Puffer + recent lows
risk_price = entry - stop
target = entry + rr_target * risk_price       // fixes 1:1.1
// ASYMMETRIE:
if (in_profit) HOLD_TO_TARGET                 // ~90 % der Gewinner bis Ziel (Recon 2.1a)
if (zone_breaking OR sideways_at_zone OR pnl <= -early_cut_R*risk_price) CLOSE_EARLY
// zone_breaking = Close[1] jenseits zone_far_edge
```
Profit-Harvesting hier = das **frühe Schneiden der Verlierer** (asymmetrisch), nicht
Teil-TPs — die Gewinner werden VOLL bis Ziel gehalten (Recon-Doktrin explizit).

### MT5-Spezifika
- `OnBar(entry_tf)` für Entry-Prüfung; `OnBar(zone_tf)` für Zonen-Rebuild (1×/Tag);
  `OnTick` für SL/TP + early-cut-Trigger.
- Multi-Symbol: FX-Majors + WS30.DWX (Recon: FX majors + US30). Ein magic_slot/Symbol.
- Session-Filter: Index-Trades vor US-Open schließen (Recon 2.2) → `close_before_hour`.

### Gate-Risiken
- Q02-Freq: Zonen-Reversal ist selten (nur an klaren Zonen) → **Freq-Floor-Risiko** (>=5/yr)
  auf einzelnen Symbolen; über mehrere Symbole aggregieren.
- Q08-Korrelation: MeanRev dekorreliert gut zu unseren Trend/Breakout-Sleeves → attraktiv.
- ★Haupt-Fail-Risiko: Zonen-Mechanik ist eine Formalisierung von Shawns Diskretion — die
  `touch_min`/`zone_width_atr`-Defaults sind Hypothesen; Q03-Plateau-Grid über beide nötig.

---

## TRD-3 — MTF Trend-Alignment + Currency-Strength Bot (Filter-System)

**Kernidee:** Signale NUR bei Übereinstimmung von HTF- und LTF-Trend (Elder Triple Screen)
+ Currency-Strength-Filter (stärkste vs. schwächste Währung). Basierend auf recherchierter
Harmony-Index-Referenz (MQL5 20097) + 28Pairs-Doktrin.

### Multi-Timeframe Harmony Index (Kern)
```
// pro TF i in {M15,H1,H4,D1}, NUR geschlossene Bars:
bias_i = +1 if (High[1..3] strikt steigend AND Low[1..3] strikt steigend)   // 3-Bar-Treppe
       = -1 if (strikt fallend)
       = sign(Close[1]-Close[2]) als Fallback, sonst 0
HI = sum(bias_i * w_i) / sum(w_i)          // w: M15=0.10 H1=0.20 H4=0.30 D1=0.40
HI_smooth = EMA(HI, 8)                      // Anti-Whipsaw
```
| Input | Default | Quelle |
|---|---|---|
| `tf_set` | M15,H1,H4,D1 | Recon 3b (Harmony Index) |
| `weights` | 0.10,0.20,0.30,0.40 | Recon 3b (HTF dominiert 2.3:1) |
| `band_strong` | 0.8 | Signal-Schwelle |
| `band_hold` | 0.4 | Hysterese (Exit < Entry) |
| `hi_ema` | 8 | Anti-Flip-Flop |
| `csm_method` | ROC_BASKET | Recon 3a: ROC schnellster; RSI als Alt |
| `csm_lookback` | 20 | Bars für %-Change |
| `csm_persist_bars` | 3 | Signal muss 2–3 Bars halten |

### Currency Strength (offline in MT5, kein externer Feed)
```
// %-Change-Basket pro Währung über csm_lookback Bars (quote-Seite invertieren):
strength(ccy) = mean( %change(pair) für alle 7 Paare mit ccy ) / mean(%change all 28)
// Signal: handle Paar (strongest_ccy / weakest_ccy), Richtung = strong über weak
// dGAP-Regel (Recon 3a): nur bei ECHTER Divergenz (A schwach UND B stark), nicht "weak vs weaker"
```

### Entry (boolean)
```
mtf_long   = HI_smooth >= band_strong
csm_long   = strength(base) - strength(quote) >= csm_threshold  AND  persisted(csm_persist_bars)
ENTER_LONG = mtf_long AND csm_long AND spread_ok
// Kein Neu-Entry bei Strength-Extrem (Recon: nicht jenseits ±100; Flip abwarten, Pullback traden)
```

### Exit / Sizing
```
EXIT if |HI_smooth| < band_hold   (Hysterese)  OR  strength_direction_flip  OR  SL/TP
stop = behind structure (Swing-Low, nie fixe Pips — Recon 3a); RR >= 1:1
risk_pct 0.5–1.0 %/Trade; Lot via QM_LotsForRisk
```

### MT5-Spezifika (kritisch)
- **Multi-Symbol PFLICHT**: CSM braucht alle 28 Crosses geladen → Basket-EA-Architektur
  (`QM_BasketWarmupHistory` für 28 Symbole). ★RAM-Warnung: 28-Symbol-Load = 20–44GB-Klasse
  (Memory: launch_fault-Wedge) → im `multisymbol_eas.txt` registrieren, seriell testen.
- **Repaint-Guard (Killer #1)**: HTF-Werte NUR nach HTF-Bar-Close konsumieren; geschlossene-
  Bar-State-Machine. Backtest-Korrektheit vor allem anderen prüfen.
- `OnBar(kleinste_tf)` treibt; HTF via `iTime`-Bar-Close-Check.

### Gate-Risiken
- ★Q02-Freq-Kollision (Recon 3d.8): W1+D1+intraday-Alignment ist SELTEN → evtl. <5 Trades/yr.
  Mitigation: nur 3 TFs statt 4, oder band_strong senken; Frequenz früh messen (Pre-Screen).
- Q08: CSM-Baskets dekorrelieren stark zum Buch → hoher Orthogonalitäts-Wert WENN sie Q02
  überleben.
- RAM/Test-Kosten = größtes operatives Risiko.

---

### ★UPDATE 2026-07-15 (Recon-Nachschlag): Liquidity-Grab-GAP GESCHLOSSEN — negativ
Nick Shawn LEHNT die Sweep/Stop-Hunt-These explizit ab (`6MTdytSMB8g` 10:00–10:44:
"retail liquidity <5% of FX volume… no way to predict zone-overshoot"). → Der
Liquidity-Grab als fadebares Entry-Setup existiert bei diesem Trader NICHT; Zonen-
Overshoot ist unvorhersehbares Rauschen, gemanagt NUR durch (a) Stop-Puffer jenseits der
Zone + (b) kleine Size. **Konsequenz für TRD-2: keine separate Liquidity-Grab-Logik bauen**
— der `stop_buffer_atr`-Mechanismus oben ist bereits die korrekte (einzige) Antwort. Sein
DCA/Grid/Hedge-Variante (paid course) = Hard-Rules-Konflikt (Grid/Martingale) → NICHT bauen.

## agy / Video-Tickets (GAPs schließen — parallel)
1. **Goshawk ATR-Params** (atr_period, trail_mult, pyramid-unit-size, initial-stop) — nur
   On-Screen-Code im Seykota-Rebuild-Video (bLoBNKqUTIg). → Video-Frame-Analyse.
   (Transcript 2gMYNuIUsvA "momentum step-by-step" im Fetch — evtl. gesprochene Params.)
2. ~~Shawn Liquidity-Grab~~ — RESOLVED negativ (s. Update oben), kein Ticket nötig.
3. **Shawn Zonen-Breite** (Wicks vs. Bodies, touch_min) — nur visuell demonstriert → Q03-Grid.
4. **CSM-Lag-Benchmark** — kein öffentlicher Quant-Vergleich; selbst auf DWX messen
   (ROC vs RSI vs Z-Score Responsiveness).

## Nächster Schritt (Karten-Entwürfe)
Priorität für Strategy-Cards: **TRD-1 (Goshawk) zuerst** — höchste Regel-Dichte, geringste
GAPs, sauber mechanisch, passt auf unsere Index/Metall-Symbole, niedriges Freq-Risiko.
TRD-2 (Shawn) danach (dekorreliert, aber Zonen-Formalisierung braucht Q03-Grid). TRD-3
(MTF/CSM) zuletzt — höchster Orthogonalitäts-Wert, aber RAM- + Freq-Floor-Risiko; erst
nach OWNER-Ratifizierung des Multi-Symbol-Basket-Work-Items (siehe multicurrency_survey).
