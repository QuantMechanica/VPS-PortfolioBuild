# Phase-3-PILOT Delegations-Auftrag — headless Sonnet: 12567 als erstes echtes XAU-Modul

**Rolle:** headless Sonnet (Coding-Lane, Regel 24). **PM:** Claude. **Worktree:**
`agents/sonnet-master-ea-p3pilot` (nie main, nie T_Live, nie T1/T2). **Non-live, reversibel.**
Kontext: `docs/ops/MASTER_EA_SYMBOL_CONSOLIDATION_PLAN_2026-07-13.md` (Phase 3).
Baut auf Phase 1/1.5/2/2.5 (alle gemerged).

## Ziel (PILOT — nur EINE Strategie)

Die Standalone-Strategie **QM5_12567_cum-rsi2-commodity** (XAUUSD.DWX, D1) als erstes echtes
`CQMStrategyModule` in den Master-EA portieren + als slot-3-Modul verdrahten, sodass der
Master mit NUR diesem Modul aktiv den Standalone-q08-Stream **centgenau** reproduziert. Das
beweist das Port-Pattern end-to-end, bevor die anderen 4 Strategien folgen (separater Auftrag).

## Quellen (im Repo, verifiziert nach 13.07.-Rebuild)

- **Standalone-Source (zu portierende Logik):**
  `framework/EAs/QM5_12567_cum-rsi2-commodity/QM5_12567_cum-rsi2-commodity.mq5`
  → Entry/Exit/Manage/NoTrade + Indikator-Handles 1:1 übernehmen.
- **Backtest-Set (Regressions-Config):**
  `framework/EAs/QM5_12567_cum-rsi2-commodity/sets/QM5_12567_cum-rsi2-commodity_XAUUSD.DWX_D1_backtest.set`
  → risk_mode=**FIXED**, RISK_FIXED=**1000**; alle Strategie-Inputs (RSI-Periode, Schwellen etc.)
  müssen im Modul dieselben Defaults tragen wie hier.
- **Interface:** `framework/include/QM/QM_StrategyModule.mqh` (`CQMStrategyModule`).
- **Master:** `framework/EAs/QM5_MXAU_master-xauusd/QM5_MXAU_master-xauusd.mq5`
  (slot 3 = 12567; aktuell `CQMMasterSlotModule`-Platzhalter `g_strategy3_module`).
- **Explizite Sizing-API (Phase 2.5):** `QM_TM_OpenPosition(..., explicit_magic, explicit_mode,
  explicit_value)` bzw. `QM_LotsForRisk(sym, sl, QM_RiskMode, value)`.

## Anforderungen

1. **Modul:** `framework/include/QM/modules/QM_Mod_CumRsi2Commodity.mqh` — `CQMStrategyModule`-
   Subklasse. Entry/Exit/Manage/NoTrade **1:1** aus dem Standalone. `TF()` HART = `PERIOD_D1`
   (nie PERIOD_CURRENT). `Magic()` = **125670003** (Original). Operiert AUSSCHLIESSLICH auf
   eigenen Positionen (`QM_ModuleOwnsPosition(Magic())`). Indikator-Handles in `Init()` anlegen,
   in `Deinit()` freigeben.
2. **Dualmodus-Sizing (CLAUDE.md-Pflicht):** das Modul sizet über den expliziten Phase-2.5-Pfad
   mit `(mode, value)`. Master-Inputs für slot 3 auf `(risk_mode, risk_value)` erweitern
   (statt nur `risk_percent`) — Default LIVE = `PERCENT, 0.794`. Für die Regression wird per
   Set `FIXED, 1000` gesetzt. Interface ggf. `RiskMode()`+`RiskValue()` statt `RiskPercent()`
   (backward-kompatibel für die 4 verbleibenden Platzhalter halten).
3. **Master-Verdrahtung:** `g_strategy3_module` = die echte Modul-Instanz; die anderen 4 Slots
   bleiben `CQMMasterSlotModule`-No-Op-Platzhalter. Dispatcher/Corset/Init-Guards unverändert.
4. **Entry MUSS** über `QM_TM_OpenPosition` mit `explicit_magic=125670003` + `explicit_mode/value`
   laufen. Kein globaler Risk-State.

## Acceptance-Gate (per-Modul-Regression — MUSS centgenau)

Master force-rebuilden (`compile_one -Strict`, PASS 0/0). Dann Master mit **NUR strategy3
enabled**, `strategy3_risk_mode=FIXED`, `strategy3_risk_value=1000`, alle anderen disabled,
XAUUSD.DWX **D1**, Full-History **2017–2025 Model 4** (freies T6–T10). Der q08-Stream MUSS:
1. **73 Trades / Net $4.676,76** centgenau (= der verifizierte 12567-Standalone-Stream), UND
2. jede Row `magic=125670003`.
**★Deploy-Lektion (Phase 2):** `run_smoke` deployt die `.ex5` aus `C:\QM\repo`; aus dem
Worktree VOR dem Smoke die frisch gebaute Master-`.ex5` nach
`D:\QM\mt5\T<n>\MQL5\Experts\QM\QM5_MXAU_master-xauusd.ex5` kopieren, sonst `REPORT_MISSING`.
(Claude fährt danach das autoritative centgenaue Gate.)

## Scope-Grenzen

- NUR 12567. KEINE der anderen 4 Strategien (10403/10513/12989/1556) — separater Auftrag.
- KEINE Framework-Kern-Änderungen an Sizer/Magic (Phase 1/2.5 fertig) außer der Slot-Risk-
  Input-Erweiterung im Master. KEINE T_Live-Berührung. Registry-Append nur falls nötig
  (Master ist schon registriert; 12567-Magic existiert schon).

## Deliverable

PR auf `agents/sonnet-master-ea-p3pilot`: das Modul, die Master-Verdrahtung + Slot-Risk-Inputs,
ein Regressions-Set (`..._REGRESSION.set` o.ä. mit FIXED/1000/nur-strategy3), Design-Notiz
(wie die Logik gemappt wurde, Dualmodus, TF-hart), grüner per-Modul-Gate-Beleg (73/$4676.76 +
magic). Claude reviewt + fährt das autoritative Gate + merged, dann folgen die 4 restlichen Module.
