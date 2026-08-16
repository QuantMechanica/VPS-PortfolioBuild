---
name: qm-build-ea-from-card
description: >
  Use when Development is implementing a Strategy Card with an OWNER-authorized
  `g0_status: APPROVED` into an `.mq5` EA under the V5 framework. The allocated
  `ea_id` and magic rows must already exist in the deterministic registries.
  This is build-only — it does not run any pipeline phase or authorize live use.
---

# qm-build-ea-from-card

Procedure for converting an OWNER-authorized G0 V5 Strategy Card into a compiling, registry-clean V5 EA. This is the bridge between Research output and non-live pipeline execution. Strategy-card status and execution-contract approval remain separate promotion gates.

## When to use

- A Strategy Card has `g0_status: APPROVED` under the current OWNER-governed farm contract
- The card has an allocated `ea_id` that matches the deterministic EA registry
- A row exists in `framework/registry/ea_id_registry.csv` for this EA
- The required `magic_numbers.csv` rows exist for every (ea_id, symbol_slot) pair the EA will use

## When NOT to use

- `g0_status` is absent, `DRAFT`, `IN_REVIEW`, or `REJECTED`
- No `ea_id` is allocated — request an OWNER-governed registry allocation first
- Live/promotion work when `status` or `execution_contract_status` is not `APPROVED`; G0 authorizes build, instrumentation, compile, and non-live tests only
- ML-flagged strategies — V5 does **not** allow ML in EAs (entries / exits / sizing). `framework/scripts/build_check.ps1` enforces this with `EA_ML_FORBIDDEN`.
- You are running a backtest — that is `qm-run-pipeline-phase`, not this skill

## Procedure

### 1. Pre-flight verification

```text
- Card file:           an APPROVED card exists in ONE of:
                         strategy-seeds/cards/approved/<...>.md        (repo, 567 files)
                         D:/QM/strategy_farm/artifacts/cards_approved/ (runtime reservoir, 3267 files)
                       NOTE 2026-08-16: the flat path strategy-seeds/cards/<slug>_card.md
                       previously documented here is the DRAFT store (508 files), not the
                       approved store. Checking only that path produced a false FAIL on
                       2026-07-17 (evidence 9e872ce2_turn_of_month_index_build_preflight).
- Card G0 status:      APPROVED
- ea_id:               allocated, present in framework/registry/ea_id_registry.csv
- Magic registry:      framework/registry/magic_numbers.csv has rows for every (ea_id, symbol_slot) used
- Slug match:          card slug == ea folder slug == ea_id row slug   (MANDATORY, length is not)
```

If any check fails: stop and report the deterministic failed gate; do not proceed with the build.

**Ordering note (2026-08-16).** `framework/scripts/update_magic_resolver.py` keeps only
rows whose EA **directory** exists, so magic rows allocated for a card with no directory
are silently dropped at the next regeneration. When an EA is being created from scratch the
governed order is therefore: create the EA directory → allocate the magic rows → regenerate
the resolver → verify nothing was dropped → build the source → compile. The pre-flight
requirement above ("magic rows exist") applies from the build step onward, not before the
directory exists.

### 2. Scaffold the EA folder

```text
framework/EAs/QM5_<NNNN>_<slug>/
  QM5_<NNNN>_<slug>.mq5
  sets/
  docs/
    strategy_card.md       # symlink or copy of the approved card for build-time reference
```

Folder name and file name match exactly: `QM5_<ea_id>_<slug>`. Slug is lowercase kebab-case and descriptive. NOTE 2026-08-16: the former ≤16-char slug / ≤32-char folder limits were REMOVED as empirically false. 948 of the existing EA folders exceed 32 characters (longest 64) and run the full pipeline; QM5_32003_cl-pit-open-volatility-breakout (slug 31, folder 41) completed Q02 PASS and an economic Q04 verdict. The stale limits had blocked real builds twice (2026-07-17 turn-of-month, 2026-08-16 Century batch 1). Keep slugs reasonably short for readability, but do not reject a build on length alone.

### 3. Copy the skeleton

Copy `framework/templates/EA_Skeleton.mq5` to `QM5_<NNNN>_<slug>.mq5`. The skeleton contains:

- `#include` lines for `QM_Common.mqh` (umbrella) and any specific module includes
- The 5 input groups: `QuantMechanica V5 Framework`, `Risk`, `News`, `Friday Close`, `Strategy`
- Stub bodies for the 4 strategy module hooks (see step 4)

### 4. Implement the 4 strategy modules

Per the V5 framework 4-module pattern, every V5 EA has exactly four hook functions:

| Module | EA implements | Framework provides |
|---|---|---|
| **No-Trade** | (nothing — strategy uses framework defaults unless explicitly opting in) | `QM_NoTrade.mqh` orchestrates kill-switch, news, session, Friday-close, weekend, holidays, broker disconnect |
| **Trade Entry** | `bool Strategy_EntrySignal(QM_EntryRequest &req)` | Framework calls under No-Trade clearance |
| **Trade Management** | `void Strategy_ManageOpenPosition(ulong ticket)` | Framework calls every tick post-No-Trade-check |
| **Trade Close** | `QM_ExitReason Strategy_ExitSignal(ulong ticket)` | Framework wires the chosen reason through `QM_Exit` |

Implement only what the Strategy Card specifies. Do not add filters or modules the card does not authorize.

### 5. Inputs follow V5 convention

Use MT5 `input group "..."` syntax. Five groups always present:

CORRECTED 2026-08-16 — the previous block documented pre-FW1 input names that no
longer exist. Verified against a shipping EA (`QM5_1537_aa-vol-sma10`):

```mql5
input group "QuantMechanica V5 Framework"
input int    qm_ea_id               = <NNNN>;      // NOT "ea_id" — the qm_ prefix is mandatory
input int    qm_magic_slot_offset   = 0;           // NOT "magic_slot_offset"

input group "Risk"
input double RISK_PERCENT       = 0.0;             // live default set in the live setfile
input double RISK_FIXED         = 1000.0;          // backtest default
input double PORTFOLIO_WEIGHT   = 1.0;             // these three carry NO qm_ prefix

input group "News"
// FW1 2026-05-23: the news filter is TWO AXES, not one mode.
input QM_NewsTemporalMode      qm_news_temporal        = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance      = QM_NEWS_COMPLIANCE_NONE;
input int                      qm_news_stale_max_hours = 336;   // ceiling enforced by guardrails
input string                   qm_news_min_impact      = ...;
// input QM_NewsMode qm_news_mode_legacy survives ONLY for pre-FW1 back-compat.
// Writing the legacy single mode into a new EA is a defect: on 2026-08-16 QM5_11388
// accumulated 36 consecutive INFRA_FAIL/ONINIT rows because its card demanded
// "news off in P2" while the setfiles never sealed the two new axes.

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;   // NOT "friday_close_enabled"
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
// strategy-specific inputs from the Strategy Card "parameters_to_test"
```

`framework/scripts/build_check.ps1` (see `$requiredGroups`) enforces exactly these five
groups: `QuantMechanica V5 Framework`, `Risk`, `News`, `Friday Close`, `Strategy`.
An additional `input group "Stress"` (e.g. `qm_stress_reject_probability`) is common and
permitted — it is not required and its absence is not a failure.

### 6. Risk-mode contract

| Environment | Active mode | Other mode |
|---|---|---|
| `backtest` | `RISK_FIXED` (default $1000) | `RISK_PERCENT = 0` |
| `live` | `RISK_PERCENT` | `RISK_FIXED = 0` |

Both inputs always present. The `.set` file ENV (`backtest` / `demo` / `shadow` / `live`)
selects which mode is active.

CORRECTED 2026-08-16: the failure code named here previously was
`EA_INPUT_RISK_MODE_MISMATCH`, which does not exist anywhere in
`framework/scripts/build_check.ps1`. The real risk-related check emitted by build_check is
`EA_RISK_SIZER_UNCONFIGURED`. Do not quote a failure code that the tooling cannot emit —
report the code the tool actually produced.

### 7. Magic resolution

Use `QM_MagicResolver.mqh`:

```mql5
int magic = QM_Magic(ea_id, symbol_slot);
// formula: magic = ea_id * 10000 + symbol_slot
// build_check.ps1 verifies the (ea_id, symbol_slot) pair exists in magic_numbers.csv with status=active
```

Never compute magic by hand. Never reuse an `ea_id` from V4 (1-~770 reserved as legacy).

### 8. Symbol naming discipline

- Research + backtest: symbols carry `.DWX` suffix (e.g. `EURUSD.DWX`)
- Live deploy: `.DWX` stripping happens only in deploy packaging workflow (never in EA build/backtest artifacts)
- Never strip `.DWX` by hand or anywhere else in the build

### 9. Compile

```powershell
framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_<NNNN>_<slug>/QM5_<NNNN>_<slug>.mq5 -Strict
```

`-Strict` runs `build_check.ps1` after compile:

- Magic-collision check against registry
- Setfile schema check
- ML-import grep (forbidden: `tensorflow`, `torch`, `sklearn`, `keras`, `onnx`)
- Forbidden runtime imports (no external market-data API calls; Darwinex MT5 native data only)
- All 5 input groups present

Build must produce a `.ex5` and pass all checks before proceeding.

### 10. Author the canonical setfiles

For each (symbol, timeframe, env) the card calls for:

CORRECTED 2026-08-16 — the setfile name carries the **slug**, which the previous
pattern omitted:

```text
framework/EAs/QM5_<NNNN>_<slug>/sets/QM5_<NNNN>_<slug>_<SYMBOL>_<TF>_<ENV>.set
```

Examples verified on disk:
- `QM5_1537_aa-vol-sma10_AUDCAD.DWX_D1_backtest.set`
- `QM5_1537_aa-vol-sma10_XTIUSD.DWX_D1_backtest.set`

Backtest sets keep the `.DWX` suffix in the symbol segment; live sets follow the deploy
packaging rules in step 8.

Run `framework/scripts/build_check.ps1` after setfile authoring to enforce set header completeness and build-hash updates.

### 11. Submit for deterministic review

Build PR / coordination issue with:

- Commit hash with the new `.mq5` + `.ex5` + setfiles
- `compile_one.ps1 -Strict` PASS evidence
- Strategy Card link
- Filled `framework_alignment` section showing where each card rule lives in which module

The OWNER or designated code reviewer checks:
- Correct mapping card → 4 modules
- Magic + ea_id consistency with registry
- No deviation from card-authorized logic
- Risk + News + Friday-close conventions intact

Passing review permits the non-live pipeline handoff. It does not mutate card or execution-contract status implicitly and does not authorize T6/live deployment.

## Boundary

- This skill does **not** run backtests. Build PASS ≠ pipeline PASS.
- This skill does **not** modify framework includes (`include/QM_*.mqh`) unless the OWNER explicitly scopes a framework repair.
- This skill does **not** allocate `ea_id` or magic rows; those must arrive through the governed registries before this skill starts.
- This skill does **not** approve an execution contract or authorize live deployment. Those require separate deterministic evidence and OWNER approval.

## References

- `framework/V5_FRAMEWORK_DESIGN.md` — full framework spec
- `framework/templates/EA_Skeleton.mq5` — copy-from skeleton
- `framework/registry/magic_numbers.csv` — magic-allocation source of truth
- `framework/scripts/compile_one.ps1` + `build_check.ps1` — compile + validation
- `docs/ops/DWX_IMPORT_AUTOMATION.md` — `.DWX` symbol naming discipline and deploy-time boundary
- `decisions/2026-04-26_v5_framework_design.md` — V5 framework decision rationale
- ~~`lessons-learned/V4_LEARNINGS_ARCHIVE_2026-04-21.md`~~ — REMOVED 2026-08-16: this file
  does not exist in the repository. The `lessons-learned/` directory holds dated incident
  notes instead; do not cite this path as a source.
