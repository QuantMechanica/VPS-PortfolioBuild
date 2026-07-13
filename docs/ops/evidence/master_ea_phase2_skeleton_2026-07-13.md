# Master-EA Phase 2 — XAUUSD Skeleton and Module Contract

Date: 2026-07-13
Branch: `agents/codex-master-ea-p2`

## Scope

Phase 2 adds the XAUUSD symbol-master host, its class-based strategy-module
contract, and a disabled copy template. It contains no entry, exit, trailing,
or signal logic from the five standalone XAU strategies.

The host identity is `ea_id=20001`, slot `0`, magic `200010000`. The host magic
exists for framework identity and the shared corset only; the master has no host
entry path and never opens a position under that magic. Initialization is also
fail-closed unless the chart/test symbol is exactly `XAUUSD.DWX`.

The registries mark the class with slug `master-xauusd` and strategy identity
`MASTER-XAUUSD-MULTI-MAGIC-V1`. Because the required directory name is
`QM5_MXAU_master-xauusd` rather than `QM5_<numeric-id>_<slug>`, the canonical
resolver generator and registry validator recognize named `QM5_M*_<slug>`
directories through `ea_id_registry.csv`. Normal numeric EA discovery is
unchanged.

## Interface contract

`framework/include/QM/QM_StrategyModule.mqh` defines:

```mql5
class CQMStrategyModule {
public:
   virtual bool             Init(const string symbol) { return true; }
   virtual void             Deinit() {}
   virtual bool             Enabled()      const { return false; }
   virtual long             Magic()        const = 0;
   virtual ENUM_TIMEFRAMES  TF()           const = 0;
   virtual double           RiskPercent()  const = 0;
   virtual bool             NoTrade(datetime now) { return false; }
   virtual void             ManageOpen() {}
   virtual void             CheckExit()  {}
   virtual void             CheckEntry() {}
};
```

`QM_ModuleOwnsPosition(long magic)` checks the currently selected position's
`POSITION_MAGIC`. Every real module must use it, or an equivalent exact magic
comparison, before managing or closing a position.

Every real `CheckEntry()` must open only through the Phase-1 call context:

```mql5
QM_TM_OpenPosition(req, out_ticket, (int)Magic(), RiskPercent());
```

The cast avoids an MQL long-to-int warning; the resolved registry magics are
within the API's integer range. An enabled module is rejected during master
initialization unless its risk is strictly positive, because an explicit risk
of exactly `0.0` means legacy host-risk fallback in the backward-compatible
Phase-1 API. A module is also rejected if it returns `PERIOD_CURRENT`.

`framework/include/QM/modules/QM_Mod_Template.mqh` is deliberately disabled,
uses a hard `PERIOD_D1` placeholder, and implements no lifecycle, filter,
management, exit, or entry logic.

## Five skeleton slots

All inputs default to disabled / zero risk, so the compiled default has zero
active modules.

| Slot | Inputs | Original identity | Hard TF |
|---|---|---:|---:|
| 1 | `strategy1_enabled`, `strategy1_risk_percent` | `104030002` (`10403/2`) | D1 |
| 2 | `strategy2_enabled`, `strategy2_risk_percent` | `105130003` (`10513/3`) | D1 |
| 3 | `strategy3_enabled`, `strategy3_risk_percent` | `125670003` (`12567/3`) | D1 |
| 4 | `strategy4_enabled`, `strategy4_risk_percent` | `129890003` (`12989/3`) | H4 |
| 5 | `strategy5_enabled`, `strategy5_risk_percent` | `15560004` (`1556/4`) | D1 |

The Phase-2 slot objects expose only this input/identity/TF metadata; all
inherited trading hooks remain no-ops. Phase 3 replaces them with real module
classes without changing the dispatcher.

## Lifecycle and dispatcher order

`OnInit` validates the immutable host identity, initializes the normal V5
framework, and then processes enabled modules in slot order. Each enabled
module must pass the risk, hard-TF, and closed-magic-allowlist checks; then its
`Init(_Symbol)` runs and its foreign identity is registered. A partial failure
deinitializes all modules already initialized and shuts the framework down.

`OnDeinit` calls module `Deinit()` in reverse order before
`QM_FrameworkShutdown()`. Framework shutdown performs the existing q08 history
walk and flush.

Every `OnTick` performs exactly this sequence:

1. Evaluate KillSwitch once.
2. Evaluate the shared News gate once.
3. Evaluate Friday close once.
4. Combine those results into `entries_blocked` without returning early.
5. For every enabled module, always call `ManageOpen()` and then `CheckExit()`.
6. Only when entries are not blocked, the module's hard TF has a new bar, and
   `NoTrade(now)` is false, call `CheckEntry()`.

New-bar results are cached once per distinct module TF for the current tick.
Consequently all four D1 slots see the same D1 transition and the H4 slot sees
the H4 transition; `_Period` / chart TF is never used. This avoids the shared
`QM_IsNewBar` tracker being consumed by only the first of several D1 modules.
The transition is consumed even while entries are blocked, so a corset unblock
later in that same bar cannot produce a delayed entry.

## Foreign sub-magic acceptance

The five allowed magics are a closed list in the master. For each enabled
module the master derives `(sub_ea_id, sub_slot)` from the declared original
magic and calls `QM_MagicFor(sub_ea_id, sub_slot)` after framework
initialization. This is not a resolver bypass:

- `QM_MagicFor` resolves through the generated registry and
  `QM_MagicChecked`;
- it records the original magic and symbol in `g_qm_fw_magic_contexts`;
- it calls `QM_KillSwitchRegisterMagic`, so the KillSwitch owns host plus all
  enabled sub-magics;
- `QM_Entry` accepts an explicit foreign magic only when that KillSwitch
  ownership exists;
- framework ownership walks used by Friday flattening, MAE/q08 attribution,
  trade transactions, and shutdown recognize the registered contexts;
- same-symbol positions already carrying an original sub-magic are accepted,
  while a collision carrying that magic on another symbol still aborts.

Therefore a module cannot emit an arbitrary foreign magic, and the five
approved original identities do not trigger `magic_context_not_registered` or
a foreign-magic abort.

## Verification

Resolver regeneration is idempotent at 14,911 retained rows and contains
exactly one host row: `20001/0/XAUUSD.DWX/200010000`. The registry validator
reports no issue or missing-directory warning for `20001/master-xauusd`; its
repository-wide status remains red from unrelated pre-existing registry debt.

Strict force-rebuild:

```powershell
framework/scripts/compile_one.ps1 -EALabel QM5_MXAU_master-xauusd -Strict
```

- Result: **PASS**, 0 errors / 0 warnings.
- Compile log: `C:\QM\worktrees\codex-master-ea-p2\framework\build\compile\20260713_111054\QM5_MXAU_master-xauusd.compile.log`
- Compile summary: `D:\QM\reports\compile\20260713_111054\summary.csv`

Disabled-default smoke:

```powershell
framework/scripts/run_smoke.ps1 -EAId 20001 -EALabel QM5_MXAU_master-xauusd `
  -Symbol XAUUSD.DWX -Year 2025 -Terminal T6 -Period H1 -Runs 1 `
  -MinTrades 0 -SmokeMode -TimeoutSeconds 1800
```

- Result: **PASS** (`reason_classes=[OK]`).
- Trades: **0**; net profit and drawdown both `0.00`.
- Model: 4, XAUUSD.DWX H1, 2025, T6.
- `oninit_failure_detected=false`; the master launch/session slice contains no
  `foreign magic`, `EA_MAGIC`, `magic_context_not_registered`, or OnInit-failure
  marker.
- Smoke summary: `D:\QM\reports\smoke\QM5_20001\20260713_111122\summary.json`
- MT5 report: `D:\QM\reports\smoke\QM5_20001\20260713_111122\raw\run_01\report.htm`
- Smoke evidence: `D:\QM\reports\framework\22\20260713_111122_QM5_20001_T6_XAUUSD_DWX_run_smoke.md`

The factory remained off and the smoke runner skipped its post-run pump. No
T_Live, T1, or T2 terminal was used for the smoke.
