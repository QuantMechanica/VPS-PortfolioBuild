# Phase-2 Delegations-Auftrag — headless Codex: Master-EA-Skelett + Modul-Interface

**Rolle:** headless Codex. **PM:** Claude. **Worktree:** `agents/codex-master-ea-p2`
(nie main, nie T_Live, nie T1/T2). **Non-live, reversibel.**
Kontext: `docs/ops/MASTER_EA_SYMBOL_CONSOLIDATION_PLAN_2026-07-13.md` (Phase 2).
Baut auf Phase 1 (Multi-Magic-Framework) + Phase 1.5 (q08 per-Magic), beide bereits im
Branch-History gemerged.

## Ziel

Das **Skelett** eines Symbol-Master-EA + ein sauberes **Strategie-Modul-Interface** bauen —
OHNE echte Strategie-Logik (die ist Phase 3, Sonnet). Am Ende: kompiliert 0/0, und mit 0
aktiven Modulen ist der Backtest ein sauberer No-Op (0 Trades, kein Fehler).

## Zu bauen

### 1. Neuer EA
`framework/EAs/QM5_MXAU_master-xauusd/QM5_MXAU_master-xauusd.mq5`
- **ea_id 20001** (neue Master-Klasse; nur Framework-Identität + Corset — der Master eröffnet
  NIE unter seiner eigenen Magic). Registry-Eintrag + Resolver-Anbindung wie für einen
  normalen EA, aber gekennzeichnet als Master (mehrere fremde Sub-Magics erlaubt).
- OnInit: `QM_FrameworkInit`-Äquivalent für den Master; alle aktiven Sub-Module initialisieren;
  deren Sub-Magics beim KillSwitch registrieren (die Phase-1-Multi-Magic-Registrierung nutzen).
- OnTick = **Dispatcher** (siehe unten). OnDeinit: Module deinit + q08-Flush wie gehabt.

### 2. Strategie-Modul-Interface (das Kernstück)
Klassenbasiert (idiomatisches MQL5, saubere Per-Modul-State-Kapselung für Indikator-Handles).
Basisklasse in `framework/include/QM/QM_StrategyModule.mqh`:

```mql5
class CQMStrategyModule {
public:
   virtual bool             Init(const string symbol) { return true; } // Handles anlegen/validieren
   virtual void             Deinit() {}
   virtual bool             Enabled()      const { return false; }     // Input strategyN_enabled
   virtual long             Magic()        const = 0;                  // ORIGINAL-Sub-Magic (QM_MagicFor(sub_ea_id,sub_slot))
   virtual ENUM_TIMEFRAMES  TF()           const = 0;                  // HART, nie PERIOD_CURRENT
   virtual double           RiskPercent()  const = 0;                  // Sub-Sleeve-Risk
   virtual bool             NoTrade(datetime now) { return false; }    // Per-Strategie No-Trade-Filter
   virtual void             ManageOpen() {}                            // Trailing/BE NUR auf eigene Magic
   virtual void             CheckExit()  {}                            // Exit NUR auf eigene Magic
   virtual void             CheckEntry() {}                            // Entry auf eigenem TF-NewBar; eröffnet via Magic()/RiskPercent()
};
```
Jedes Modul operiert AUSSCHLIESSLICH auf Positionen mit `POSITION_MAGIC == Magic()`
(Helper bereitstellen: `QM_ModuleOwnsPosition(long magic)`). Entry MUSS über die Phase-1-API
`QM_TM_OpenPosition(req, out_ticket, explicit_magic=Magic(), explicit_risk_percent=RiskPercent())`
gehen — nie global.

### 3. Ein Beispiel-No-Op-Modul (Template)
`framework/include/QM/modules/QM_Mod_Template.mqh` — eine `CQMStrategyModule`-Subklasse, die
`Enabled()=false` liefert und sonst leer ist. Dient Phase 3 als Kopiervorlage. KEINE echte Logik.

### 4. Dispatcher-OnTick (verbindliche Reihenfolge)
1. **Corset EINMAL, symbolweit:** KillSwitch → News-Sperre → Friday-Flat (die bestehenden
   Framework-Helper). Ergebnis: `bool entries_blocked`.
2. Für jedes **aktive** Modul m (Enabled()):
   a. `m.ManageOpen(); m.CheckExit();`  (IMMER — Exits/Management laufen auch bei entries_blocked)
   b. wenn `!entries_blocked` und NewBar auf `m.TF()` und `!m.NoTrade(now)`: `m.CheckEntry();`
- NewBar-Erkennung je Modul-TF (nicht Chart-TF). Chart-TF ist irrelevant.

### 5. Inputs (gruppiert, `strategyN_*`)
Für 5 Slots (N=1..5): `strategyN_enabled` (default **false**), `strategyN_risk_percent`
(default 0.0). Skelett-Default: alle disabled → 0 aktive Module → No-Op.

## Rückwärtskompatibilität / Scope-Grenzen
- KEINE bestehenden EAs oder Framework-Signaturen brechen. Nur additive Dateien +
  Registry-Append (mit Tail-Recheck, Regel) + der neue Include.
- KEINE Strategie-Logik portieren (Phase 3). KEINE T_Live-Berührung.
- Magic-Registry: der Master darf die 5 XAU-Fremd-Magics emittieren — sicherstellen, dass
  Resolver/KillSwitch das ohne „foreign magic"-Abbruch akzeptieren (Phase-1-Mechanik).

## Acceptance-Gate (MUSS grün)
1. `compile_one.ps1 -Strict` auf QM5_MXAU_master-xauusd → **PASS 0/0** (force-rebuild).
2. Smoke XAUUSD.DWX (irgendein TF, freies T6–T10, ein Jahr) mit **allen Modulen disabled**
   → Terminal läuft sauber durch, **0 Trades**, kein ONINIT-Fehler, keine „foreign magic"-Abbrüche.
3. Beleg: Compile-Log-Pfad + Smoke-Report-Pfad (0 Trades) im PR.

## Deliverable
PR auf `agents/codex-master-ea-p2`: der Master-EA, das Modul-Interface + Template-Modul,
Registry/Resolver-Anbindung, Design-Notiz (Interface-Vertrag, Dispatcher-Reihenfolge,
wie Fremd-Magics akzeptiert werden), grüner No-Op-Gate-Beleg. Claude reviewt + merged.
Phase 3 (die 5 echten XAU-Module) kommt danach an headless Sonnet.
