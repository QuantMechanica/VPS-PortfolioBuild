# Wayward Bot Part 2 (nZwt57f8-oA) — Analyse + Varianten-Matrix QM5_13031

**Auftrag (OWNER 13.07.):** Video 2 der CapFree/Wayward-Linie analysieren, an die
bisherige Arbeit anschließen, weitere Tests — „vielleicht lässt sich noch was rausholen".

## Video-2-Analyse (Quelle: Proxy-Captions, 1.660 Zeilen; agy erneut ohne Video-Tool —
Block-Report `VIDEO_nZwt57f8-oA_WAYWARD2_AGY_2026-07-13.md`)

Video 2 ist wörtlich das „Part 2", auf das die Video-1-Extraktion verwies (`higher_tf`
war deklariert, aber unbenutzt). Inhalt: **wann NICHT traden** —
1. **HTF-Bollinger-Confluence**: Signal nur, wenn Preis auch das Higher-TF-Band (Default
   H4, BB 20/2.0) gebrochen hat; TF-Validierungs-Warnung.
2. **Spike-Filter**: Tick-Sprung > 0.5×ATR → Pause N Sekunden (News-Schutz für Reversals).
3. **Daily/Weekly/Monthly-Drawdown-Stops** (47:00–56:00): Prop-Firm-Plumbing — validiert
   unser KillSwitch-/Book-Halt-Design, ist aber kein Edge.
4. Visuals (HTF-Kerzen, Gradient, Dashboard); Fibonacci **explizit ungenutzt** („looks pretty").

## Anschluss-Befund

**QM5_13031 war ein leeres Skelett** (auto-generiertes Entry-TODO, `return false`) —
das Q02, auf das FTMO-Mandats-Welle 2 seit 07-07 wartete, konnte nie laufen (0 work_items).
Jetzt VOLL implementiert (Commit dieser Session): Video-1-Core (BB 20/2 Stretch + RSI 14
mit 50±30-Schwellen + Setup-Kerze >1×ATR, **Stop-Order-Entry** ±0.2×ATR mit Bar-Expiry,
SL 2×ATR, TP = BB-Mitte, Trailing 0.2×ATR, Spread-Guard, Session-Fenster) + Video-2-Filter
als Inputs (`strategy_use_htf_confluence`, `strategy_spike_veto_atr_mult`). Bar-gated-
Adaptionen im Header dokumentiert. Compile 0/0 (echter Build, post No-Op-Fix). Magics
130310000/130310001 registriert.

## Matrix (XAUUSD.DWX M15, Full-History 2017–2025, Model 4, gross, RISK_FIXED $1k)

| Variante | Trades | PF | Net | MaxDD |
|---|---|---|---|---|
| vCORE (nur Video 1) | 203 | 0.79 | −$2.255 | 3.57% |
| vSPIKE (Core + Spike-Veto 3×ATR) | 177 | 0.74 | −$2.356 | 3.42% |
| **vHTF (Core + Part-2-Confluence)** | 141 | **0.99** | −$98 | **2.07%** |
| vBOTH (HTF + Spike) | 123 | 0.97 | −$166 | 1.80% |
| vHTF auf **NDX.DWX** (Jahr 2025, kanon. run_smoke) | 69 | 0.93 | −$209 | — |

Reports: `D:/QM/mt5/T7..T10/WAYWARD_*.htm`, `D:/QM/reports/smoke/QM5_13031/`,
`D:/QM/reports/wayward_matrix_20260713/`.

## Verdikt

1. **Der rohe Wayward-Bot verliert** (PF 0.79 gross über 9 Jahre; Karte erwartete 1.15).
2. **Die Part-2-HTF-Confluence wirkt exakt wie beworben**: −30% Trades, **PF +0.20**
   (0.79→0.99), MaxDD halbiert. Die „when not to trade"-These ist mechanisch real.
3. Aber: beste Variante = Münzwurf **gross** auf beiden Karten-Zielen (XAU + NDX) —
   unter dem Q02-Floor 1.20; Kommissionen würden es weiter drücken. Kein Param-Sweep
   (wäre Curve-Fitting). **QM5_13031 = dokumentiertes Negativ** (Record bleibt, wie 13204).
4. Spike-Veto (Bar-Adaption): negativer Beitrag — verwirft auch Gewinner. Verworfen.
   (Hinweis: Original ist ein Tick-Pausen-Filter; die Bar-Adaption ist konservativer.)

## Das eine, was sich rausholen lässt (Empfehlung)

Die **HTF-BB-Confluence ist ein übertragbares Filter-Primitiv** (+0.20 PF / DD halbiert
auf einem edgelosen Kern — auf einem Kern MIT Edge könnte es Q02/Q08-Metriken real heben).
Kandidaten im Bestand mit MR-Charakter: 12567 (cum-RSI2), 10018 (BB-shadow-reversal),
12989 (nested-pb). Vorschlag: kleines Experiment „HTF-Confluence-Gate" als v2-Variante
auf 1–2 Bestands-MR-EAs — nur mit OWNER-Go (Challenger-Regeln, kein Auto-Swap).

---

## Anhang: HTF-Confluence-Transfer-Experiment (OWNER „los gehts", 2026-07-13)

Frage: Hebt das HTF-BB-Confluence-Primitiv (Wayward Part 2, +0.20 PF auf edgelosem Kern)
auch Bestands-MR-EAs MIT Edge? Getestet als Toggle (default OFF, live-neutral), HTF=D1
a priori fixiert (kein Fishing). D1-EAs (12567/11132) ausgeschlossen: W1=0 Bars auf .DWX.
Valider Vergleich = hOFF↔hON in DERSELBEN Raw-Umgebung (news-Harness fehlt bei beiden;
11165 ist news-sensitiv → Absolutwerte ≠ kanonische Referenz, aber Delta sauber).

| EA (Typ) | Symbol | hOFF | hON | Effekt |
|---|---|---|---|---|
| **10018** (pure BB-Fade) | EURUSD H1 | 1215tr / PF 0.88 / DD **80.6%** | 317tr / PF 0.83 / DD **37.7%** | −74% Trades, **DD halbiert**, PF −0.05 |
| **11165** (Trend-Pullback, LIVE) | EURUSD H1 | 224tr / PF 1.07 | **0 Trades** (Voll-Lauf, 50.681 Bars) | Gate **inkompatibel** |
| **11165** | AUDCAD H1 | 183tr / PF 1.07 | ~0 (gleiche Struktur) | Gate inkompatibel |

**Verdikt: das Primitiv transferiert NICHT nützlich.**
1. Auf **pure-Fade**-EAs (10018): zähmt den Drawdown drastisch, erzeugt aber KEINEN
   PF-Edge (0.88→0.83) — exakt wie am Wayward-Ursprung. Reiner DD-Reduzierer.
2. Auf **Trend-Pullback**-EAs (11165, der Live-Gewinner): **logisch inkompatibel** —
   „kaufe Dip im Aufwärtstrend" (Preis > SMA200) widerspricht „Preis jenseits des
   HTF-Bands"; die Confluence killt praktisch alle Trades (0 über 9 Jahre).

**Konsequenz:** kein Challenger-Kandidat. Experiment-Edits zurückgenommen (11165+10018
= HEAD, live-neutral), Karte 13031 bleibt dokumentiertes Negativ. Die HTF-Confluence ist
ein fade-spezifischer DD-Dämpfer, kein Edge-Generator — für unsere Survivor-Ökonomie
(COST-Gates selektieren, PF-Edge zählt) uninteressant.
