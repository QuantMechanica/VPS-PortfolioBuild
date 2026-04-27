---
name: qm-build-ea-from-card
description: Use when Development is implementing an APPROVED Strategy Card into an `.mq5` EA under the V5 framework. Don't use without an `ea_id` allocated by CEO + CTO, and don't use on a card that is not in `status: APPROVED`. This is build-only — it does not run any pipeline phase.
owner: Development (Codex)
reviewer: CTO
last-updated: 2026-04-27
basis: framework/V5_FRAMEWORK_DESIGN.md (4-module pattern + naming + magic schema)
---

# qm-build-ea-from-card

Procedure for converting an APPROVED V5 Strategy Card into a compiling, registry-clean V5 EA. This is the bridge between Research output and Pipeline execution.

## When to use

- A Strategy Card has `status: APPROVED` (CEO + Quality-Business signoff visible in the card or its issue trail)
- CEO + CTO have allocated an `ea_id` (range `1000-4999` for production, `5000-8999` for sandbox)
- A row exists in `framework/registry/ea_id_registry.csv` for this EA
- The required `magic_numbers.csv` rows exist for every (ea_id, symbol_slot) pair the EA will use

## When NOT to use

- Card is `DRAFT` / `IN_REVIEW` / `REJECTED` — wait for APPROVED
- No `ea_id` allocated — request from CEO + CTO first
- ML-flagged strategies — V5 does **not** allow ML in EAs (entries / exits / sizing). `framework/scripts/build_check.ps1` enforces this with `EA_ML_FORBIDDEN`.
- You are running a backtest — that is `qm-run-pipeline-phase`, not this skill

## Procedure

### 1. Pre-flight verification

```text
- Card file:           strategy-seeds/cards/<slug>_card.md  exists
- Card status:         APPROVED
- ea_id:               allocated, present in framework/registry/ea_id_registry.csv
- Magic registry:      framework/registry/magic_numbers.csv has rows for every (ea_id, symbol_slot) used
- Slug match:          card slug == ea folder slug == ea_id row slug
```

If any check fails: stop, file a coordination issue, do not proceed with the build.

### 2. Scaffold the EA folder

```text
framework/EAs/QM5_<NNNN>_<slug>/
  QM5_<NNNN>_<slug>.mq5
  sets/
  docs/
    strategy_card.md       # symlink or copy of the approved card for build-time reference
```

Folder name and file name match exactly: `QM5_<ea_id>_<slug>`. Slug is lowercase kebab-case, ≤ 16 chars. Compiled MT5 EA name (folder name) must be ≤ 32 chars.

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

```mql5
input group "QuantMechanica V5 Framework"
input int    ea_id              = <NNNN>;          // hard-coded to allocated ea_id
input int    magic_slot_offset  = 0;

input group "Risk"
input double RISK_PERCENT       = 0.0;             // live default 0.25 set in live setfile
input double RISK_FIXED         = 1000.0;          // backtest default
input double PORTFOLIO_WEIGHT   = 1.0;

input group "News"
input QM_NewsMode news_mode     = QM_NEWS_OFF;

input group "Friday Close"
input bool   friday_close_enabled    = true;
input int    friday_close_hour_broker = 21;

input group "Strategy"
// strategy-specific inputs from the Strategy Card "parameters_to_test"
```

`framework/scripts/build_check.ps1` enforces presence of all five groups.

### 6. Risk-mode contract

| Environment | Active mode | Other mode |
|---|---|---|
| `backtest` | `RISK_FIXED` (default $1000) | `RISK_PERCENT = 0` |
| `live` | `RISK_PERCENT` | `RISK_FIXED = 0` |

Both inputs always present. The `.set` file ENV (`backtest` / `demo` / `shadow` / `live`) selects which mode is active. Hard-fail per `EA_INPUT_RISK_MODE_MISMATCH` if mode doesn't match ENV.

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
- Live deploy: stripped only via `framework/scripts/strip_dwx_at_deploy.ps1`
- Never strip `.DWX` by hand or anywhere else in the build

### 9. Compile

```powershell
framework/scripts/compile_one.ps1 -EA QM5_<NNNN>_<slug> -Strict
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

```text
framework/EAs/QM5_<NNNN>_<slug>/sets/QM5_<NNNN>_<SYMBOL>_<TF>_<ENV>.set
```

Examples:
- `QM5_1001_EURUSD.DWX_H1_backtest.set`
- `QM5_1001_EURUSD_H1_live.set`

Run `framework/scripts/validate_setfile.ps1` on every `.set`.

### 11. Submit for CTO review

Build PR / coordination issue with:

- Commit hash with the new `.mq5` + `.ex5` + setfiles
- `compile_one.ps1 -Strict` PASS evidence
- Strategy Card link
- Filled `framework_alignment` section showing where each card rule lives in which module

CTO reviews for:
- Correct mapping card → 4 modules
- Magic + ea_id consistency with registry
- No deviation from card-authorized logic
- Risk + News + Friday-close conventions intact

CTO approves → card status moves to `IN_PIPELINE`, EA is handed to Pipeline-Operator.

## Boundary

- This skill does **not** run backtests. Build PASS ≠ pipeline PASS.
- This skill does **not** modify the framework includes (`include/QM_*.mqh`) — that is CTO + Quality-Tech.
- This skill does **not** allocate `ea_id` or magic rows — those are CEO + CTO before this skill starts.

## References

- `framework/V5_FRAMEWORK_DESIGN.md` — full framework spec
- `framework/templates/EA_Skeleton.mq5` — copy-from skeleton
- `framework/registry/magic_numbers.csv` — magic-allocation source of truth
- `framework/scripts/compile_one.ps1` + `build_check.ps1` — compile + validation
- `decisions/2026-04-26_v5_framework_design.md` — V5 framework decision rationale
- `lessons-learned/V4_LEARNINGS_ARCHIVE_2026-04-21.md` — what V4 patterns were inherited and which were rejected
