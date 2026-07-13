# Phase-3-REST Delegations-Auftrag — headless Sonnet: die 4 restlichen XAU-Module

**Rolle:** headless Sonnet (Coding-Lane). **PM:** Claude. **Worktree:**
`agents/sonnet-master-ea-p3rest` (nie main, nie T_Live, nie T1/T2). **Non-live, reversibel.**
Kontext: `docs/ops/MASTER_EA_SYMBOL_CONSOLIDATION_PLAN_2026-07-13.md` (Phase 3).
Baut auf dem gemergten Pilot (12567 = slot 3, GREEN).

## ★Pattern-Vorlage (kopieren!)
Der Pilot `framework/include/QM/modules/QM_Mod_CumRsi2Commodity.mqh` + die slot-3-Wiring im
Master `framework/EAs/QM5_MXAU_master-xauusd/QM5_MXAU_master-xauusd.mq5` sind die **exakte
Vorlage**. Jedes neue Modul = dieselbe Struktur: `CQMStrategyModule`-Subklasse, TF-hart,
Original-Magic, Entry via `QM_TM_OpenPosition(req, out, (int)Magic(), RiskMode(), RiskValue())`,
nur eigene Magic (`QM_ModuleOwnsPosition`).

## Die 4 Module (Slot / Source / TF / Magic / Referenz — alle RISK_FIXED=1000)

| Slot | EA | Source-.mq5 (in framework/EAs/…) | TF | Magic | Regr.-Referenz |
|---|---|---|---|---|---|
| strategy1 | 10403 et-turtle20x | QM5_10403_et-turtle20x | D1 | 104030002 | **209 / $14.411** |
| strategy2 | 10513 mql5-ichimoku | QM5_10513_mql5-ichimoku | D1 | 105130003 | **76 / $9.649** |
| strategy4 | 12989 grimes-nested-pb-v2 | QM5_12989_grimes-nested-pb-v2 | **H4** | 129890003 | **51 / $13.878** |
| strategy5 | 1556 aa-zak-mom12 | QM5_1556_aa-zak-mom12 | D1 | 15560004 | **53 / $6.370** |

Je Modul: Entry/Exit/Manage/NoTrade **1:1** aus dem Standalone, Input-Defaults = dessen
Backtest-Set (alle `*_XAUUSD.DWX_*_backtest.set`, risk_mode FIXED). 12989 ist **H4** (TF() =
PERIOD_H4, alle Indikator-Reads auf PERIOD_H4).

## Aufgaben
1. 4 Module `framework/include/QM/modules/QM_Mod_<Name>.mqh` (Pattern wie Pilot).
2. Master-Wiring: `g_strategy1/2/4/5_module` = die echten Modul-Instanzen (slot 3 bleibt 12567).
   Slots 1/2/4/5 auf die **Dualmodus-Inputs** (`strategyN_risk_mode` + `strategyN_risk_value`)
   umstellen — wie slot 3 im Pilot (die alten `strategyN_risk_percent` ersetzen; Live-Default
   PERCENT + der deployte Sub-Risk je Slot).
3. 4 Regressions-Sets `..._XAUUSD.DWX_REGRESSION_<ea>.set`: NUR der jeweilige Slot enabled,
   `strategyN_risk_mode=2` (FIXED), `strategyN_risk_value=1000`, alle anderen disabled.
   (12989 = Period H4 im Set.)
4. `compile_one.ps1 -Strict` auf QM5_MXAU_master-xauusd → **PASS 0/0** (force-rebuild).

## ★PROZESS-PFLICHT (Pilot-Lektion — HART)
- **NICHTS backgrounden.** `claude -p` beendet die Session, bevor Hintergrund-Backtests fertig
  sind → dein Pilot-Vorgänger ging vor dem Commit raus. Führe nur *synchrone* Schritte aus.
- **COMMITTE, bevor du exit'st.** Der Deliverable ist: 4 Module + Master-Wiring + 4 Sets +
  Compile PASS 0/0, **committet** auf `agents/sonnet-master-ea-p3rest`. Auch wenn du keine
  Regression fährst — committe den kompilierenden Code + Sets. Ein uncommitteter Worktree = Fail.
- Optionale Selbst-Regression (falls synchron machbar, freies T6–T10, .ex5 VOR dem Smoke ins
  Terminal deployen): schön, aber **Claude fährt die 4 autoritativen per-Modul-Gates** danach.

## Scope-Grenzen
NUR diese 4 XAU-Strategien. KEINE Framework-Kern-Änderung (Phase 1/2.5 fertig) außer der
Slot-Risk-Inputs. KEINE T_Live-Berührung. Slot 3 (12567) unangetastet lassen.

## Deliverable
PR auf `agents/sonnet-master-ea-p3rest`: 4 Module + Wiring + 4 Sets + Compile-Beleg, Design-
Notiz je Modul (Logik-Mapping, TF, Dualmodus), **committet**. Claude fährt dann die 4 Gates
(Master mit je nur einem Slot, FIXED 1000 → Referenz centgenau + korrekte Magic), merged,
danach Phase 4 (Integration: alle 5 zusammen).
