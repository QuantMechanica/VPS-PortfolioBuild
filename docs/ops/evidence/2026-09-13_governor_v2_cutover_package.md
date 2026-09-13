# Governor v2 — deployment package for the DXZ book cutover (2026-09-13)

Status: **PREPARED — not installed, not attached, not enforcing.** Every step that
touches `C:\QM\mt5\T_Live`, a chart, AutoTrading, or the Windows scheduler is left
to OWNER / a separate authorized act. Nothing in this package can act on the live
account.

Scope: close the freeze-lift condition `GOVERNOR-HARDENING`
(`tools/strategy_farm/risk_freeze.py`:61-64, "account/portfolio governor hardened
AND actually enforcing") for the DXZ book on account `4000090541` in time for the
weekend book cutover.

## 1. What was missing, and what is missing now

| # | Item | Before today | After this package |
|---|---|---|---|
| G1 | v2 monitor **binary** | Only the 2026-07-20 v1 build was deployed AND in-tree (`8699adc7…`), while the v1.10 source is from 2026-08-22 — the STALE-EX5 class | **BUILT.** `f98523ee…`, 0 errors / 0 warnings, staged under `C:\QM\deploy\governor_v2_20260913\staging\`. **Remaining: OWNER copies it into T_Live and reloads the monitor chart.** |
| G2 | Live **v2 snapshot** observed over several timer intervals with zero uncertainties (contract required gate 2) | Live snapshot is `LEGACY_UNVERSIONED` → evaluator correctly pinned to level 1 | **BLOCKED on G1.** Acceptance criteria written into `staging/deploy_manifest.json`. |
| G3 | ONE canonical recurring dry-run **scheduled task** | Capability only; no task registered; two duplicate wrappers | **INSTALLER WRITTEN + DRY-RUN PROVEN**: `tools/strategy_farm/install_governor_dry_run_watch_scheduled_task.ps1`. **Remaining: run it (after G1) and retire the duplicate wrapper.** |
| G4 | OWNER **threshold policy** (the four account-wide limits) | Threshold-free; evaluator pinned at `ENTRY_FREEZE_POLICY_UNBOUND` | **PROPOSED with full derivation** (§3), refusal proven (§5). **Remaining: OWNER signature.** |
| G5 | **Enforce-activation artifact** under `decisions/` (the adapter's 4th gate) | Does not exist | Still does not exist — OWNER act, deliberately **not** part of cutover day. |
| G6 | The **order-management executor** (L2 cancel / L3 flatten) | Does not exist (`contract:125`); the CLI hardcodes `executor=None` (`account_governor_action_adapter.py`:534) | Still does not exist. **This is the real blocker for "actually enforcing"** — see §4 and the FTMO precedent. |
| G7 | An account-wide **entry-freeze channel the live EAs actually read** | Not verified | **DEFECT FOUND**: the adapter names `QM\halt\account_entry_freeze.signal` (`account_governor_action_adapter.py`:72-74), but the deployed kill switch only polls `QM\halt\portfolio_dd.signal` and `QM\halt\<ea_id>.halt` (`framework/include/QM/QM_KillSwitch.mqh`:495-496, :13). The adapter's named channel is **inert** with today's binaries. See §4. |
| G8 | The freeze lift itself | `GOVERNOR-HARDENING` PARTIAL; the other two conditions are BLOCKED / PARTIAL (`risk_freeze.py`:44-58) | Unchanged. No AI seat lifts the freeze, and satisfying a condition does not lift it by inference. |

## 2. Monitor binary (G1)

Artifact-only native MetaEditor compile — no terminal started, no terminal include
tree written, nothing under `C:\QM\mt5\T_Live` touched. It mirrors the governed
probe pattern of `tools/strategy_farm/monitor_compile_probe.py`:45 (portable
MetaEditor copy, `/compile` + `/include` + `/log`, `CREATE_NO_WINDOW`) but is
self-contained (no farm-DB read).

| Field | Value |
|---|---|
| Source | `framework/monitor/QM_AccountMonitor.mq5`, `#property version "1.10"`, SHA-256 `9b45983b994955c5afcf66ad5e451d2aa29a116c1d861a18ae1b75ff5ac1d961` |
| Compiler | portable copy of `D:\QM\mt5\T10\metaeditor64.exe`, SHA-256 `197ca3dd8d1971831366f54cb57bf3f120b420700e573135509d406e4e23709e` |
| Include root | `C:\QM\deploy\governor_v2_20260913\compile\MQL5` = `D:\QM\mt5\T10\MQL5\Include` overlaid with `C:\QM\repo\framework\include` |
| Result | `Result: 0 errors, 0 warnings, 1732 ms elapsed, cpu='X64 Regular'` |
| **EX5 SHA-256** | **`f98523ee82d36ad88713b554f3f270a40d79054f214f22aff9186441a0c7f7e9`** (107,780 bytes) |
| Compile log | `C:\QM\deploy\governor_v2_20260913\staging\QM_AccountMonitor.compile.log`, SHA-256 `f660f13e9e461da51cb6da9622c9df41e26c78bc3452ac6763bcda611519214c` |
| Supersedes | deployed `C:\QM\mt5\T_Live\...\Experts\QM_AccountMonitor.ex5` SHA-256 `8699adc79bc0448563b6a53d59163ec149a30b6ef767e2f99fe148e5efb4b9e5` (mtime 2026-07-20T15:25:00Z) |
| Runner / manifest | `C:\QM\deploy\governor_v2_20260913\compile_monitor_probe.py`, `compile/result.json`, `staging/deploy_manifest.json` |

The v1.10 binary emits `qm.account-monitor.snapshot/v2` with the full `positions[]`
/ `orders[]` inventory, `reconciliation_complete`, gross/net notional, planned loss
to stop and unpriced/uncovered counts (`QM_AccountMonitor.mq5`:757-795), written
`tmp -> rename` (:800-801). It contains no order-send / trade call.

## 3. Threshold policy proposal (G4)

File: `C:\QM\deploy\governor_v2_20260913\policy\account_governor_policy_dxz_4000090541_20260913.PROPOSED.json`
(repo copy: `docs/ops/evidence/2026-09-13_governor_v2_cutover_package/account_governor_policy_dxz_4000090541_20260913.PROPOSED.json`),
schema `qm.account-governor.policy/v1`, `status: PROPOSED_OWNER_RATIFICATION_REQUIRED`.

### Measured book facts (the derivation inputs)

Reconstructed from the deployed monitor's own deal export
`C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM\journal\live_deals_normalized.csv`
(248 trade deals, 2026-06-28 → 2026-09-11) by
`C:\QM\deploy\governor_v2_20260913\derive_thresholds.py` /
`derive_capacity.py` (outputs: `threshold_derivation_inputs.json`,
`capacity_model.json`):

- peak **gross leverage 3.16x** (2026-08-26T13:01Z, 4 concurrent positions);
- peak **net directional 2.60x**; peak **currency-net 2.80x** (EUR bucket);
- **max 7 of 24 sleeves concurrently in market** in 2.5 months;
- modelled **all-24-in capacity 15.48x** gross (per-sleeve max notional per 1 % of
  deployed risk, summed over the whole roster);
- equity 99,374.06, HWM 101,871.44, DD-guard halt equity 91,684.30
  (`D:\QM\reports\state\live_book_dd_guard_state.json`, 10 % rule from
  `decisions/2026-07-24_live_book_dd_guard.md`);
- deployed risk sum 9.7499 % over 24 sleeves
  (`D:\QM\reports\portfolio\portfolio_manifest_live_24sleeve_20260724.json`).

### Proposed limits

| Limit | Value | Derivation | Headroom over measured peak |
|---|---:|---|---|
| `min_free_margin_account` | **68,750 USD** | 0.75 x DD-guard halt equity (0.75 x 91,684.30 = 68,763.22): even at the worst equity the ratified 10 % book-DD guard tolerates, at most 25 % of equity may sit in margin | free margin today 99,374 (flat) |
| `max_gross_leverage` | **7.5** | 25 % margin utilisation at the Darwinex swing profile 1:30 FX (0.25 x 30) | 2.37x (peak 3.16) |
| `max_abs_currency_net_leverage` | **4.3** | family cap 57.5 % of `concentration_tail_limits.v1.json` (OWNER_RATIFIED 2026-09-13) applied to the gross ceiling: 0.575 x 7.5 = 4.3125. A currency bucket aggregates symbols (EUR = EURUSD + EURGBP + GDAXI), so the family ratio, not the symbol ratio, matches | 1.54x (peak 2.80) |
| `max_planned_stop_loss_account` | **3,650 USD** | tail rule of the same ratified policy: `maximum_fraction_of_daily_limit` 0.8 x `venue_daily_loss_limit_pct` 5.0 = 4.0 % of equity, on the conservative DD-guard floor equity (0.04 x 91,684.30 = 3,667.37) | 1.23x over the ratified joint-tail model (9.75 %/3 = 3.25 % = 2,979.74) |

`stage2_cancel_pending_authorized: true` (L2 = freeze entries + list pending
tickets to cancel). Stage 3 remains unreachable without a separate emergency
policy hash-bound to this file (`contract`:92-96).

### Two caveats the OWNER must decide before signing

1. **Account leverage is UNVERIFIED.** The 1:30 FX / 1:15 metals-oil swing profile
   is recorded as unverified (`docs/ops/OPEN_ITEMS_STATUS.md`, 2026-09-05 note; the
   Darwinex trading-symbols URL 404'd on 2026-09-04). If the account is on a
   different profile, `max_gross_leverage` moves with it.
2. **`max_planned_stop_loss_account` is deliberately below the book's own budget.**
   4.0 % of equity < the 9.7499 % that a fully deployed book would carry. A
   hypothetical all-24-sleeves-in state would breach it and freeze entries. That
   state has never occurred (max 7 of 24), and freezing there is the intended tail
   behaviour, but it is a policy choice, not a measurement.

### Validation against real book states

`C:\QM\deploy\governor_v2_20260913\validate_thresholds.py` builds two v2 snapshot
fixtures and runs the real evaluator against a scratch OWNER_SIGNED copy of the
proposed numbers (`validation/validation_result.json`):

| Fixture | gross lev | ccy net | planned stop | free margin | Decision |
|---|---:|---:|---:|---:|---|
| **PEAK** — the exact 4 positions open at the measured live maximum | 3.160 | 2.795 | 1,614.80 | 88,905.76 | **level 0 CLEAR**, no breach, no uncertainty |
| **RUNAWAY x3** — same book, every volume tripled (sizing / duplicate-dispatch defect) | 9.481 | 8.386 | 4,844.44 | 67,969.15 | **level 2 PENDING_CANCEL_AND_ENTRY_FREEZE**, all four limits breached |

The numbers are therefore inert in normal operation and trip on the defect class
the governor exists to catch.

## 4. Enforcement boundary: exactly how DISABLED becomes enforcing

Today the chain is broken in two independent places, and both are outside an AI
seat's authority:

1. **Activation gate (paper).** `run_adapter` refuses unless
   `resolve_activation()` returns a grant (`account_governor_action_adapter.py`
   :248-262, :301-303). That needs (a) a SHA-256-bound `status: OWNER_SIGNED`
   policy (§3, still a proposal) **and** (b) an activation artifact of schema
   `qm.account-governor.enforce-activation/v1` with `enforce_authorized: true`,
   `trigger_policy_sha256` == the exact policy hash, and an
   `activation_decision_ref` pointing at a `decisions/` record
   (`load_activation`, :217-232). The CLI finds it through `--activation` /
   `--trusted-activation-sha256` or the env pair
   `QM_ACCOUNT_GOVERNOR_ENFORCE_ACTIVATION[_SHA256]` (:65-66, :517-521), both
   absent in production.
2. **Executor (code that does not exist).** Even with a perfect activation the
   adapter returns `ENFORCE_REFUSED / no_execution_adapter_present`, because
   `main()` hardcodes `executor = None` (:530-534) and no
   `AccountActionExecutor` implementation exists anywhere
   (`contract`:125). Wiring one is a ROT act with its own review.

**Which executor.** It must be MQL-side, not Python: the Python governor has no
MT5 connection and must never gain one, and the write target lives under
`C:\QM\mt5\T_Live` (hard no-write for every AI seat). The template already exists
and is running: `QM5_13206_ftmo-account-governor.ex5` on the FTMO demo
(`docs/ops/evidence/2026-09-06_ftmo_demo_governor_manifest.md`) — an account-scope
governor EA that persists durable account stops and atomically creates
`MQL5/Files/QM/halt/<ea_id>.halt` per sleeve, never clearing them itself. Porting
that to the DXZ account, driven by the four account-wide limits instead of the
FTMO daily/total floors, is the concrete G6 work item (Codex, ROT review).

**G7 defect — the channel must be one the EAs actually read.** The adapter's
`DEFAULT_ENTRY_FREEZE_SIGNAL` is `QM\halt\account_entry_freeze.signal` (:72-74).
No deployed binary polls that name: `QM_KillSwitch.mqh` reads
`QM\halt\portfolio_dd.signal` (existence-trip, :426-432, default set at :495-496)
and `QM\halt\<ea_id>.halt`. Consequences for the design:

- `portfolio_dd.signal` must **not** be reused — it is a full halt, it latches, and
  it already has one writer (`live_book_dd_guard.py`:54). Two writers would race.
- The FTMO-proven per-sleeve `<ea_id>.halt` channel works with today's binaries and
  needs no recompile of the live inventory (a book-wide recompile immediately
  before a cutover would be reckless).
- **Level 1 must stay observational.** L1 is the fail-closed default (uncertainty
  or no bound policy) and it flaps with every stale or incomplete snapshot; wiring
  L1 to a halt channel would stop the whole book on a telemetry hiccup. Only L2/L3
  may reach the executor.

## 5. Measured dry runs (today, against the live snapshot)

| Run | Command | Result |
|---|---|---|
| Governor, no policy | `python tools/strategy_farm/account_portfolio_governor.py --dry-run --expected-login 4000090541` | level 1 `ENTRY_FREEZE_UNCERTAINTY`; uncertainties incl. `snapshot_schema_not_v2:LEGACY_UNVERSIONED`, `positions_inventory_missing`, `orders_inventory_missing`; `actions_executed: []` — output `C:\QM\deploy\governor_v2_20260913\dryrun_governor_live_snapshot.json` |
| Governor, PROPOSED policy bound | same + `--policy … --trusted-policy-sha256 ad7070429ff26d948f9d6e40181ed6c1a7c7103c3df7235944b552122b15e401` | refused: `policy_not_owner_signed:PROPOSED_OWNER_RATIFICATION_REQUIRED` — the proposal cannot be mistaken for a signed policy |
| Adapter, default mode | `python tools/strategy_farm/account_governor_action_adapter.py --dry-run --expected-login 4000090541 --out …\receipts` | `DRY_RUN_PLAN`, `executed=false`, `actions_executed=[]`, `enforcement_activated=false`, `execution_adapter_present=false`; receipt written only into the scratch dir |
| Adapter, enforce attempted | `… --enforce --expected-login 4000090541` | `ENFORCE_REFUSED / enforce_requires_bound_owner_policy`, nothing written |
| Scheduled-task installer | `install_governor_dry_run_watch_scheduled_task.ps1 -DryRun` | prints the full registration plan (SYSTEM, highest, PT5M, `pythonw.exe … --dry-run --snapshot … --expected-login 4000090541 --max-age-seconds 180`); **no task registered**; `existing_task_present: False` |

Snapshot producer is alive (snapshot age 10 s at run time), so the L1 verdict is a
schema verdict, not a dead-monitor verdict.

## 6. OWNER-Vorlage — Cutover-Tag (10 Schritte)

1. Ziel: Der Account-Governor wird mit dem Buch-Cutover real — v2-Snapshot, laufende Überwachung, Enforce bleibt bewusst AUS.
2. OWNER: neue `QM_AccountMonitor.ex5` (SHA-256 `f98523ee…7f7e9`) aus `C:\QM\deploy\governor_v2_20260913\staging\` nach `C:\QM\mt5\T_Live\MT5_Base\MQL5\Experts\` kopieren; die alte (`8699adc7…`) vorher wegsichern.
3. OWNER: Monitor-Chart in T_Live einmal neu laden (EA neu anhängen, Timer 60 s). AutoTrading wird dabei nicht angefasst — der Monitor handelt nicht.
4. Claude: drei Timer-Intervalle beobachten; `account_snapshot.json` muss `"schema": "qm.account-monitor.snapshot/v2"` zeigen und der Governor-Dry-Run eine LEERE `uncertainties`-Liste liefern (Vertragspflicht Gate 2).
5. Claude: Scheduled Task `QM_StrategyFarm_GovernorDryRunWatch` installieren (SYSTEM, alle 5 min, rein lesend); das Skript liegt fertig, der Dry-Run ist protokolliert. Der doppelte Alt-Wrapper wird stillgelegt.
6. OWNER: die vier Schwellen prüfen — freie Margin ≥ 68.750 USD, Brutto-Hebel ≤ 7,5, Währungs-Netto ≤ 4,3, geplanter Stop-Verlust ≤ 3.650 USD — und dabei die Kontohebel-Annahme 1:30 bestätigen oder korrigieren.
7. OWNER: Policy signieren = `status` auf `OWNER_SIGNED` setzen, `authorized_by` und Gültigkeitsfenster eintragen; Claude meldet danach den exakten SHA-256 zurück, der gebunden wird.
8. Enforce bleibt am Cutover-Tag AUS: es fehlt weiterhin der Order-Executor (MQL-Seite, ROT) — ohne ihn verweigert der Adapter jede Ausführung mit `no_execution_adapter_present`.
9. OWNER, separat und später: Enforce-Freigabe = Aktivierungs-Artefakt unter `decisions/` plus schriftliche `GOVERNOR-HARDENING`-Freigabe. Kein KI-Sitz hebt den Freeze, auch nicht durch Erfüllung einer Bedingung.
10. Wenn Schritt 2–3 ausbleiben: der Governor bleibt fail-closed auf Stufe 1, das neue Buch läuft unüberwacht, und `GOVERNOR-HARDENING` bleibt offen.

## 7. Residual risks

- **Uncovered stops pin the governor at level 1.** Any open position whose broker
  SL is missing or unpriceable adds an uncertainty
  (`account_portfolio_governor.py`:290-294), so the evaluator never reaches
  level 0. Whether all 24 sleeves carry a hard broker SL cannot be observed before
  the v2 monitor is attached — this is exactly what the multi-interval acceptance
  in §2 tests. If they do not, the four thresholds are unreachable and only the
  uncertainty freeze applies.
- **Pending-order book.** Several sleeves work with `QM_BUY_STOP` /
  `QM_SELL_STOP` entries (T_Live EA logs). An L2 pending-cancel therefore deletes
  the day's setups, not only excess risk. Correct, but OWNER should know it.
- **Shared account.** T1–T10 share login 4000090541 with T_Live (OQ-17). The
  governor is account-wide by contract, so an L3 flatten would close *everything*
  the login shows — which is why L3 needs a separate incident-scoped emergency
  policy.
- **`D:\QM\reports\state` collision.** The watcher journals into the pipeline-state
  surface (`governor_dry_run_watch.py`:51-54). Registering the task adds a writer
  there; migrating the journals to `D:\QM\reports\governor\` is a follow-up.
- **Freeze-lift arithmetic unchanged.** Even a fully enforcing governor leaves the
  other two lift conditions open (`SP-A1/A2-DEPLOY-POINTER` BLOCKED,
  `NEWS-CONTRACT-V2` PARTIAL).

## 8. Files produced

Repo:
- `tools/strategy_farm/install_governor_dry_run_watch_scheduled_task.ps1`
- `docs/ops/evidence/2026-09-13_governor_v2_cutover_package.md` (this file)
- `docs/ops/evidence/2026-09-13_governor_v2_cutover_package/account_governor_policy_dxz_4000090541_20260913.PROPOSED.json`

Outside the repo (deploy package, `C:\QM\deploy\governor_v2_20260913\`):
`staging/QM_AccountMonitor.ex5`, `staging/QM_AccountMonitor.compile.log`,
`staging/deploy_manifest.json`, `policy/…PROPOSED.json`,
`compile_monitor_probe.py`, `compile/result.json`, `derive_thresholds.py`,
`threshold_derivation_inputs.json`, `derive_capacity.py`, `capacity_model.json`,
`validate_thresholds.py`, `validation/`, `dryrun_governor_live_snapshot.json`,
`receipts/`.

No commit, no farm-DB write, no write under `C:\QM\mt5\T_Live`, no scheduled task
registered, no terminal started, no AutoTrading change.
