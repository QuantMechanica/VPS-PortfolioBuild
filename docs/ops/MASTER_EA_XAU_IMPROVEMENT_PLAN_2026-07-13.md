# XAU-Master — Verbesserungs-/Drawdown-Reduktions-Plan

**Auftraggeber:** OWNER (2026-07-13, „lange Drawdown-Phase, Entries/Exits anders kombinieren?").
**Projektleitung:** Claude. Voraussetzung: die 5 XAU-Strategien sind als separierbare Module im
Master (`QM5_MXAU_master-xauusd`) konsolidiert → Entry/Exit/NoTrade sind je Strategie
austauschbar. Das ist der Hebel, den die Konsolidierung erst geschaffen hat.

## Phase A — Diagnose (2026-07-13, GEMACHT)

### A1 — Korrelation + DD-Anatomie (Monats-PnL)
- Ø Paar-Korrelation der 5 = **0.13** (gut diversifiziert), ABER **turtle↔ichimoku = 0.54**
  (doppelte Trend-Exposure).
- Kombiniert (gross): total ~$47.9k; **Max DD −$12.191 (2022-12); längste Underwater-Phase
  = 26 Monate (2021-10 → 2023-11)**.
- Im DD-Fenster: **turtle −$2.741**, die anderen 4 ~flat. → **Regime-Lücke:** gold-direktionale
  Low-Freq-Strategien haben in der Gold-Range 2021–2023 alle keine Edge; turtle blutet.

### A2 — MAE/Hold-Gradient (Exit-Surgery-Diagnostik, aus per-Magic-q08 mae_acct)
- **turtle (DD-Treiber):** Net nach Hold — 1.2–3.2d **−$105 (win 38%)**, 4.3–18.6d **+$322
  (win 60%)**. → Verluste = **False-Breakout-Whipsaws in Ranges**; Edge real bei echten Trends.
  Fix am ENTRY (Regime-Filter), nicht am Exit. Winner enduren nur −$196 MAE (saubere Entries),
  Loser bluten auf −$623.
- **grimesPB:** hold↔net **+0.46** bei medHold **0.9d** → schneidet Gewinner zu früh ab
  (Exit-Surgery-Kandidat).
- **cumRSI2:** 68% win, negativer Hold-Gradient (schnelle MR-Exits korrekt) — gesund; als
  Range-Regime-Baustein skalierbar.
- **ichimoku/zakMom:** unauffälliger; ichimoku (Trendfolger, corr 0.54 mit turtle) in Phase A2b
  auf dasselbe Range-Whipsaw-Muster prüfen.

### A2b — offen: DD-Fenster quantitativ regime-mappen (ADX/ATR-Vola Gold 2021–2023 vs.
profitable Perioden) — bestätigt die ADX-Schwelle für den NoTrade-Filter datenbasiert.

## Phase B — Priorisierte Struktur-Hypothesen (aus A)
1. **★turtle + ichimoku: ADX/Range-NoTrade-Filter** (Entry-seitig). Höchster Hebel; eliminiert
   die Whipsaw-Verluste, die die 26-Monats-DD treiben. Strukturell (Trendfolger ⊥ Ranges).
2. **grimesPB: Exit-Surgery** (Hold verlängern / ATR-Trail) — den +0.46-Hold-Gradienten ernten.
3. **cumRSI2 als Range-Regime-Füller skalieren** — profitiert wenn die Trendfolger idle sind.
4. **(OWNER-Idee) systematische Entry×Exit-Rekombination** — der modulare Master macht es
   erstmals billig; Cross-Pairings NUR mit struktureller Begründung, OOS-validiert.
5. **turtle+ichimoku entkorrelieren/re-weighten** (0.54 redundante Trend-Exposure).

## Phase C — Bauen + VALIDIEREN (Anti-Overfit, PFLICHT)
Jede Hypothese = eine Modul-Variante (`QM_Mod_*_v2.mqh` bzw. NoTrade-Filter-Param) →
**Q02–Q10-Pipeline: Walkforward (Q04) + Stress (Q05/06) + Multiseed (Q07) + Portfolio (Q09)**.
**Nur OOS/Walkforward-validierte Verbesserungen bleiben.** Der modulare Master macht jeden Test
zu einem 1-Modul-Change. ★Gefahr: eine auf die Range 2021–2023 getunte Schwelle ist Kurven-Fit —
nur STRUKTURELL motivierte Filter (Trendfolger⊥Range) sind zulässig, Parameter via Q04 gehärtet.

## Phase D — Validierte Wins in den Master integrieren + DD neu vermessen (per-Magic + kombiniert).

## Ehrliche Erwartung
Die 26-Monats-DD ist teils **inhärent** (5 gold-direktionale Low-Freq-Edges in einer Mehrjahres-
Range) — der ultimative DD-Glätter ist die **Cross-Symbol-Diversifikation des ganzen Buchs**,
nicht mehr XAU-Tuning. Die Pipeline wird die meisten Versuche killen (gewollt). Höchste
Erfolgswahrscheinlichkeit: **Hypothesen 1 + 3** (Regime-Filter Trendfolger + Range-Modul).
